///|
/// Crockford Base32 alphabet used by ULID (excludes I, L, O, U).
let encoding : FixedArray[Char] = [
  '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  'G', 'H', 'J', 'K', 'M', 'N', 'P', 'Q', 'R', 'S', 'T', 'V', 'W', 'X', 'Y', 'Z',
]

///|
/// Maximum Unix timestamp (ms) that fits in ULID's 48-bit time field.
pub const MAX_TIMESTAMP_MS : UInt64 = 0xFFFF_FFFF_FFFFUL

///|
/// Errors produced by ULID construction, parsing, or monotonic generation.
pub enum UlidError {
  InvalidLength(Int32)
  InvalidCharacter(Char)
  TimestampOverflow
  RandomnessLength(Int32)
  MonotonicOverflow
} derive(Eq, Debug)

///|
pub extend UlidError with Eq::{equal, not_equal}

///|
pub impl Show for UlidError with fn to_string(self) {
  match self {
    InvalidLength(n) => "InvalidLength(\{n})"
    InvalidCharacter(c) => "InvalidCharacter(\{c})"
    TimestampOverflow => "TimestampOverflow"
    RandomnessLength(n) => "RandomnessLength(\{n})"
    MonotonicOverflow => "MonotonicOverflow"
  }
}

///|
pub extend UlidError with Show::{to_string, output}

///|
pub extend UlidError with @debug.Debug::{to_repr}

///|
/// A 128-bit ULID: 48-bit timestamp (ms) + 80-bit randomness.
/// Internally stored as 16 network-order bytes.
pub struct Ulid {
  priv bytes : Bytes
} derive(Eq, Compare, Debug)

///|
pub extend Ulid with Eq::{equal, not_equal}

///|
pub extend Ulid with Compare::{compare, op_lt, op_le, op_ge, op_gt}

///|
pub extend Ulid with @debug.Debug::{to_repr}

///|
fn write_timestamp(buf : FixedArray[Byte], timestamp_ms : UInt64) -> Unit {
  buf[0] = (timestamp_ms >> 40).to_byte()
  buf[1] = (timestamp_ms >> 32).to_byte()
  buf[2] = (timestamp_ms >> 24).to_byte()
  buf[3] = (timestamp_ms >> 16).to_byte()
  buf[4] = (timestamp_ms >> 8).to_byte()
  buf[5] = timestamp_ms.to_byte()
}

///|
fn read_timestamp(bytes : Bytes) -> UInt64 {
  (bytes[0].to_uint64() << 40) |
  (bytes[1].to_uint64() << 32) |
  (bytes[2].to_uint64() << 24) |
  (bytes[3].to_uint64() << 16) |
  (bytes[4].to_uint64() << 8) |
  bytes[5].to_uint64()
}

///|
fn decode_char(c : Char) -> Result[Int32, UlidError] {
  let u = c.to_ascii_uppercase()
  match u {
    '0'..<='9' => Ok(u.to_int() - '0'.to_int())
    'A'..<='H' => Ok(u.to_int() - 'A'.to_int() + 10)
    'J' => Ok(18)
    'K' => Ok(19)
    'M' => Ok(20)
    'N' => Ok(21)
    'P'..<='T' => Ok(u.to_int() - 'P'.to_int() + 22)
    'V'..<='Z' => Ok(u.to_int() - 'V'.to_int() + 27)
    _ => Err(InvalidCharacter(c))
  }
}

///|
/// Read one bit from a 16-byte ULID. `bit_index` 0 is the MSB of byte 0.
/// Negative indexes are treated as zero padding (for the 130-bit encoding).
fn get_bit(bytes : Bytes, bit_index : Int32) -> Int32 {
  if bit_index < 0 {
    return 0
  }
  let byte_i = bit_index / 8
  let bit_in_byte = 7 - bit_index % 8
  (bytes[byte_i].to_int() >> bit_in_byte) & 1
}

///|
fn set_bit(buf : FixedArray[Byte], bit_index : Int32, bit : Int32) -> Unit {
  if bit_index < 0 || bit == 0 {
    return
  }
  let byte_i = bit_index / 8
  let bit_in_byte = 7 - bit_index % 8
  buf[byte_i] = (buf[byte_i].to_int() | (1 << bit_in_byte)).to_byte()
}

///|
fn encode_crockford(bytes : Bytes) -> String {
  let sb = StringBuilder(size_hint=26)
  for i = 0; i < 26; i = i + 1 {
    // ULID encoding uses 130 bits with 2 bits of leading zero padding.
    let mut value = 0
    for b = 0; b < 5; b = b + 1 {
      let bit_index = i * 5 + b - 2
      value = (value << 1) | get_bit(bytes, bit_index)
    }
    sb.write_char(encoding[value])
  }
  sb.to_string()
}

///|
fn decode_crockford(chars : Array[Char]) -> Result[Bytes, UlidError] {
  let buf = FixedArray::make(16, b'\x00')
  for i = 0; i < 26; i = i + 1 {
    let value = match decode_char(chars[i]) {
      Ok(v) => v
      Err(e) => return Err(e)
    }
    // Reject overflow in the 2 padding bits (first char must be 0..=7).
    if i == 0 && value > 7 {
      return Err(TimestampOverflow)
    }
    for b = 0; b < 5; b = b + 1 {
      let bit = (value >> (4 - b)) & 1
      let bit_index = i * 5 + b - 2
      set_bit(buf, bit_index, bit)
    }
  }
  Ok(Bytes::from_array(buf))
}

///|
/// Create a ULID from a millisecond timestamp and exactly 10 random bytes.
pub fn Ulid::generate(
  timestamp_ms : UInt64,
  randomness : Bytes,
) -> Result[Ulid, UlidError] {
  if timestamp_ms > MAX_TIMESTAMP_MS {
    return Err(TimestampOverflow)
  }
  if randomness.length() != 10 {
    return Err(RandomnessLength(randomness.length()))
  }
  let buf = FixedArray::make(16, b'\x00')
  write_timestamp(buf, timestamp_ms)
  buf.blit_from_bytes(6, randomness, 0, 10)
  Ok(Ulid::{ bytes: Bytes::from_array(buf), })
}

///|
/// Parse a canonical 26-character ULID string.
/// Accepts lowercase letters; `to_string` always returns uppercase.
pub fn Ulid::parse(s : String) -> Result[Ulid, UlidError] {
  let chars = s.to_array()
  if chars.length() != 26 {
    return Err(InvalidLength(chars.length()))
  }
  match decode_crockford(chars) {
    Ok(bytes) => Ok(Ulid::{ bytes, })
    Err(e) => Err(e)
  }
}

///|
/// Build a ULID from a raw 16-byte network-order layout.
pub fn Ulid::from_bytes(bytes : Bytes) -> Result[Ulid, UlidError] {
  if bytes.length() != 16 {
    return Err(InvalidLength(bytes.length()))
  }
  Ok(Ulid::{ bytes, })
}

///|
/// Canonical Crockford Base32 encoding (uppercase, 26 characters).
pub impl Show for Ulid with fn to_string(self) {
  encode_crockford(self.bytes)
}

///|
pub extend Ulid with Show::{to_string, output}

///|
/// Unix timestamp in milliseconds encoded in this ULID.
pub fn Ulid::timestamp_ms(self : Ulid) -> UInt64 {
  read_timestamp(self.bytes)
}

///|
/// The 80-bit (10-byte) randomness component.
pub fn Ulid::randomness(self : Ulid) -> Bytes {
  self.bytes[6:16].to_owned()
}

///|
/// Full 16-byte binary layout (timestamp || randomness), network byte order.
pub fn Ulid::to_bytes(self : Ulid) -> Bytes {
  self.bytes
}

///|
/// `Ulid` implements `Compare`: order matches lexicographic string order and
/// chronological timestamp order.

///|
/// Fill `len` PRNG bytes using an injectable `@random.Rand`.
/// Useful for tests and demos when you do not want FFI for OS randomness.
pub fn random_bytes(rand : @random.Rand, len : Int32) -> Bytes {
  Bytes::makei(len, _ => rand.uint(limit=256U).to_byte())
}

///|
/// Monotonic ULID generator.
///
/// When consecutive calls share the same millisecond, the randomness component
/// is incremented by one (with carry), per the ULID specification. If
/// randomness would overflow (more than 2^80 IDs in the same ms),
/// `MonotonicOverflow` is returned — we do **not** bump the timestamp.
pub struct Generator {
  priv mut last_ms : UInt64
  priv mut last_random : Bytes
  priv mut has_last : Bool
}

///|
pub fn Generator::new() -> Generator {
  {
    last_ms: 0UL,
    last_random: b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00",
    has_last: false,
  }
}

///|
fn increment_randomness(randomness : Bytes) -> Result[Bytes, UlidError] {
  let buf = randomness.to_fixedarray()
  for i = 9; i >= 0; i = i - 1 {
    let next = buf[i].to_int() + 1
    if next < 256 {
      buf[i] = next.to_byte()
      return Ok(Bytes::from_array(buf))
    }
    buf[i] = b'\x00'
  }
  Err(MonotonicOverflow)
}

///|
/// Generate the next ULID for `timestamp_ms`.
///
/// - If `timestamp_ms` differs from the previous call's ms, use
///   `fresh_randomness` (must be 10 bytes) and reset monotonic state.
/// - If equal, ignore `fresh_randomness` and increment the previous
///   randomness (overflow => `MonotonicOverflow`).
pub fn Generator::generate(
  self : Generator,
  timestamp_ms : UInt64,
  fresh_randomness : Bytes,
) -> Result[Ulid, UlidError] {
  if timestamp_ms > MAX_TIMESTAMP_MS {
    return Err(TimestampOverflow)
  }
  if fresh_randomness.length() != 10 {
    return Err(RandomnessLength(fresh_randomness.length()))
  }
  let randomness : Bytes = if self.has_last && timestamp_ms == self.last_ms {
    match increment_randomness(self.last_random) {
      Ok(r) => r
      Err(e) => return Err(e)
    }
  } else {
    fresh_randomness
  }
  match Ulid::generate(timestamp_ms, randomness) {
    Ok(id) => {
      self.last_ms = timestamp_ms
      self.last_random = randomness
      self.has_last = true
      Ok(id)
    }
    Err(e) => Err(e)
  }
}
