# moonbit-ulid

[English](#english) | [中文](#中文)

---

<a id="english"></a>

## English

Pure [MoonBit](https://www.moonbitlang.com/) implementation of
[ULID](https://github.com/ulid/spec) (Universally Unique Lexicographically
Sortable Identifier).

Built for the [MoonBit Hackathon · October 2026](https://moonbitlang.github.io/Hackathon2026/).

### Why

ULIDs are 128-bit IDs that stay sortable by time, encode as a compact 26-character
Crockford Base32 string, and avoid the fragmentation issues of random UUIDs.
This library is a small, dependency-light toolkit for MoonBit programs that need
sortable unique IDs.

### Features

- Spec-compliant layout: 48-bit timestamp (ms) + 80-bit randomness
- Crockford Base32 encode / decode (canonical uppercase; parse accepts lowercase)
- `Eq` + `Compare` (binary order = lexicographic string order = chronological order)
- Monotonic generator (same-ms randomness increment; overflow returns an error)
- Injectable time / RNG — pass `timestamp_ms` and randomness yourself; helpers
  for `@random.Rand` are included (no fragile OS clock FFI)

### Monotonic overflow policy

When generating multiple ULIDs in the same millisecond, randomness is incremented
by 1 (with carry), as in the official ULID specification. If randomness would
overflow past `2^80 - 1`, generation returns `MonotonicOverflow`. **We do not
bump the timestamp.**

### Install / use

```bash
moon add hg3386628/ulid   # once published to mooncakes.io
```

Or depend on this repository as a path / git dependency.

```mbt check
///|
test "readme example" {
  let randomness : Bytes = b"\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a"
  let id = @ulid.Ulid::generate(1_700_000_000_000UL, randomness).unwrap()
  let s = id.to_string()
  assert_eq(s.length(), 26)
  assert_eq(@ulid.Ulid::parse(s).unwrap(), id)
  assert_eq(id.timestamp_ms(), 1_700_000_000_000UL)
}
```

### Public API (summary)

| API | Role |
| --- | --- |
| `Ulid` | 128-bit ULID value |
| `Ulid::generate(timestamp_ms, randomness)` | Build from ms + 10 random bytes |
| `Ulid::parse(s)` | Parse 26-char string → `Result` |
| `id.to_string()` | Canonical uppercase Crockford string |
| `id.timestamp_ms()` | Extract timestamp |
| `id.randomness()` / `id.to_bytes()` | Components / 16-byte layout |
| `Ulid::from_bytes(bytes)` | From 16 network-order bytes |
| `Generator` / `Generator::generate` | Monotonic generator |
| `random_bytes(rand, len)` | Helper using `@random.Rand` |
| `UlidError` | Typed errors |
| `MAX_TIMESTAMP_MS` | `2^48 - 1` |

### Develop

```bash
moon check
moon test
moon run cmd/main
```

### License

Apache-2.0

### Attribution

AI-assisted implementation; library design, API surface, monotonic policy, and
test plan are owned by the project author for the MoonBit October 2026 hackathon.

---

<a id="中文"></a>

## 中文

纯 [MoonBit](https://www.moonbitlang.com/) 实现的
[ULID](https://github.com/ulid/spec)（Universally Unique Lexicographically
Sortable Identifier）库。

为 [MoonBit 黑客松 · 十月赛](https://moonbitlang.github.io/Hackathon2026/) 准备。

### 为什么做

ULID 是 128 位、按时间可排序、用 26 个 Crockford Base32 字符表示的 ID，比纯随机
UUID 更适合作为数据库主键 / 排序键。本库提供边界清晰、易测试的 MoonBit 工具实现。

### 特性

- 符合规范：48 位毫秒时间戳 + 80 位随机数
- Crockford Base32 编解码（规范输出为大写；解析接受小写）
- `Eq` + `Compare`（二进制序 = 字符串字典序 = 时间先后）
- 单调生成器（同一毫秒递增随机数；溢出返回错误）
- 时间与随机源可注入：自行传入 `timestamp_ms` 与随机字节；另提供基于
  `@random.Rand` 的辅助函数（无需脆弱的系统时钟 FFI）

### 单调溢出策略

同一毫秒内连续生成时，按官方规范对随机部分 +1（带进位）。若随机部分溢出，返回
`MonotonicOverflow`，**不会**自动把时间戳 +1。

### 开发

```bash
moon check
moon test
moon run cmd/main
```

### 许可证

Apache-2.0

### 说明

本仓库在 AI 辅助下完成实现；库的设计、API、单调策略与测试方案由参赛作者负责，
用于 MoonBit 2026 十月黑客松。
