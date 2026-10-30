///|
fn main {
  // ChaCha8 seed must be exactly 32 bytes.
  let rand = @random.Rand::chacha8(seed=b"0123456789abcdef0123456789abcdef")
  let randomness = @ulid.random_bytes(rand, 10)
  // Injectable timestamp: use a fixed demo value (no OS clock FFI).
  let now_ms = 1_700_000_000_000UL
  match @ulid.Ulid::generate(now_ms, randomness) {
    Ok(id) => {
      println("ulid = \{id}")
      println("timestamp_ms = \{id.timestamp_ms()}")
    }
    Err(e) => println("error: \{e}")
  }
}
