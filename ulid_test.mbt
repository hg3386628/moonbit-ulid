///|
fn zero10() -> Bytes {
  b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
}

///|
fn ones10() -> Bytes {
  b"\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff"
}

///|
fn sample_random() -> Bytes {
  b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a"
}

///|
test "generate and round-trip" {
  let id = @ulid.Ulid::generate(0x018D_6F1A_7F00UL, sample_random()).unwrap()
  let s = id.to_string()
  assert_eq(s.length(), 26)
  let parsed = @ulid.Ulid::parse(s).unwrap()
  assert_eq(parsed, id)
  assert_eq(parsed.timestamp_ms(), 0x018D_6F1A_7F00UL)
  assert_eq(parsed.randomness(), sample_random())
  assert_eq(parsed.to_bytes().length(), 16)
}

///|
test "parse accepts lowercase" {
  let id = @ulid.Ulid::generate(1UL, zero10()).unwrap()
  let upper = id.to_string()
  let lower = upper.to_lower()
  let parsed = @ulid.Ulid::parse(lower).unwrap()
  assert_eq(parsed, id)
  assert_eq(parsed.to_string(), upper)
}

///|
test "parse rejects bad length" {
  assert_true(@ulid.Ulid::parse("") is Err(@ulid.InvalidLength(0)))
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FA")
    is Err(@ulid.InvalidLength(_)),
  )
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FAVV")
    is Err(@ulid.InvalidLength(_)),
  )
}

///|
test "parse rejects invalid characters" {
  // I, L, O, U are excluded from Crockford alphabet for ULID
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FAI")
    is Err(@ulid.InvalidCharacter(_)),
  )
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FAL")
    is Err(@ulid.InvalidCharacter(_)),
  )
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FAO")
    is Err(@ulid.InvalidCharacter(_)),
  )
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FAU")
    is Err(@ulid.InvalidCharacter(_)),
  )
  assert_true(
    @ulid.Ulid::parse("01ARZ3NDEKTSV4RRFFQ69G5FA!")
    is Err(@ulid.InvalidCharacter(_)),
  )
}

///|
test "parse rejects timestamp overflow encoding" {
  // Largest valid ULID is 7ZZZZZZZZZZZZZZZZZZZZZZZZZ
  let max = @ulid.Ulid::parse("7ZZZZZZZZZZZZZZZZZZZZZZZZZ").unwrap()
  assert_eq(max.timestamp_ms(), @ulid.MAX_TIMESTAMP_MS)
  assert_true(
    @ulid.Ulid::parse("8ZZZZZZZZZZZZZZZZZZZZZZZZZ")
    is Err(@ulid.TimestampOverflow),
  )
}

///|
test "generate validates inputs" {
  assert_true(
    @ulid.Ulid::generate(@ulid.MAX_TIMESTAMP_MS + 1UL, zero10())
    is Err(@ulid.TimestampOverflow),
  )
  assert_true(
    @ulid.Ulid::generate(0UL, b"\x00\x00") is Err(@ulid.RandomnessLength(2)),
  )
}

///|
test "lexicographic order matches timestamp order" {
  let a = @ulid.Ulid::generate(100UL, sample_random()).unwrap()
  let b = @ulid.Ulid::generate(101UL, zero10()).unwrap()
  let c = @ulid.Ulid::generate(200UL, ones10()).unwrap()
  assert_true(a < b)
  assert_true(b < c)
  assert_true(a.to_string() < b.to_string())
  assert_true(b.to_string() < c.to_string())
  assert_true(a.compare(b) < 0)
  assert_true(c.compare(a) > 0)
  assert_eq(a.compare(a), 0)
}

///|
test "same timestamp order follows randomness" {
  let low = @ulid.Ulid::generate(50UL, zero10()).unwrap()
  let high = @ulid.Ulid::generate(50UL, ones10()).unwrap()
  assert_true(low < high)
  assert_true(low.to_string() < high.to_string())
}

///|
test "known vector from ulid/javascript style" {
  // Timestamp 1469918176385 -> 01ARYZ6S41
  // With randomness all 0xFF... for remaining — check encode of time portion
  let id = @ulid.Ulid::generate(1469918176385UL, zero10()).unwrap()
  let s = id.to_string()
  assert_eq(s[:10], "01ARYZ6S41")
  assert_eq(s[10:], "0000000000000000")
}

///|
test "monotonic non-decreasing in same ms" {
  let gen = @ulid.Generator::new()
  let seed = b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\xfe"
  let a = gen.generate(999UL, seed).unwrap()
  let b = gen.generate(999UL, ones10()).unwrap() // fresh ignored
  let c = gen.generate(999UL, zero10()).unwrap()
  assert_eq(a.timestamp_ms(), 999UL)
  assert_eq(b.timestamp_ms(), 999UL)
  assert_eq(c.timestamp_ms(), 999UL)
  assert_true(a < b)
  assert_true(b < c)
  assert_eq(a.randomness(), seed)
  assert_eq(b.randomness(), b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff")
  assert_eq(c.randomness(), b"\x00\x00\x00\x00\x00\x00\x00\x00\x01\x00")
}

///|
test "monotonic overflow returns error" {
  let gen = @ulid.Generator::new()
  let _ = gen.generate(1UL, ones10()).unwrap()
  assert_true(gen.generate(1UL, zero10()) is Err(@ulid.MonotonicOverflow))
}

///|
test "monotonic resets when ms advances" {
  let gen = @ulid.Generator::new()
  let a = gen.generate(10UL, ones10()).unwrap()
  let b = gen.generate(11UL, sample_random()).unwrap()
  assert_true(a < b)
  assert_eq(b.randomness(), sample_random())
}

///|
test "from_bytes round-trip" {
  let id = @ulid.Ulid::generate(42UL, sample_random()).unwrap()
  let again = @ulid.Ulid::from_bytes(id.to_bytes()).unwrap()
  assert_eq(again, id)
  assert_true(@ulid.Ulid::from_bytes(b"\x00") is Err(@ulid.InvalidLength(1)))
}

///|
test "random_bytes helper length" {
  let rand = @random.Rand::chacha8(seed=b"ABCDEFGHIJKLMNOPQRSTUVWXYZ123456")
  let bytes = @ulid.random_bytes(rand, 10)
  assert_eq(bytes.length(), 10)
  let id = @ulid.Ulid::generate(123456789UL, bytes).unwrap()
  assert_eq(id.timestamp_ms(), 123456789UL)
}

///|
test "zero and max edge timestamps" {
  let z = @ulid.Ulid::generate(0UL, zero10()).unwrap()
  assert_eq(z.to_string(), "00000000000000000000000000")
  let m = @ulid.Ulid::generate(@ulid.MAX_TIMESTAMP_MS, ones10()).unwrap()
  assert_eq(m.to_string(), "7ZZZZZZZZZZZZZZZZZZZZZZZZZ")
}
