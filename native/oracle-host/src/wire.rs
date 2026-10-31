//! Strict JSON decoding for untrusted request bodies and child replies.
//!
//! The reference Python service decodes with `object_pairs_hook` rejecting
//! duplicate keys and `parse_constant` rejecting NaN/Infinity, then re-encodes
//! with `allow_nan=False`, which also refuses lone surrogates and numbers that
//! overflow a binary float. This parser applies the same refusals directly.
//! Numbers keep their exact source literal (serde_json `arbitrary_precision`).

use serde::Serialize;
use serde_json::{Map, Number, Value};
use std::io::{self, Write};
use std::str::FromStr;

const MAX_DEPTH: usize = 512;

#[derive(Debug)]
pub struct JsonError(pub &'static str);

pub fn parse(bytes: &[u8]) -> Result<Value, JsonError> {
    let text = std::str::from_utf8(bytes).map_err(|_| JsonError("invalid utf-8"))?;
    let mut parser = Parser {
        text: text.as_bytes(),
        source: text,
        at: 0,
    };
    parser.whitespace();
    let value = parser.value(0)?;
    parser.whitespace();
    if parser.at != parser.text.len() {
        return Err(JsonError("trailing characters"));
    }
    Ok(value)
}

struct Parser<'a> {
    text: &'a [u8],
    source: &'a str,
    at: usize,
}

impl Parser<'_> {
    fn whitespace(&mut self) {
        while let Some(b' ' | b'\t' | b'\n' | b'\r') = self.text.get(self.at) {
            self.at += 1;
        }
    }

    fn expect(&mut self, byte: u8) -> Result<(), JsonError> {
        if self.text.get(self.at) == Some(&byte) {
            self.at += 1;
            Ok(())
        } else {
            Err(JsonError("unexpected character"))
        }
    }

    fn value(&mut self, depth: usize) -> Result<Value, JsonError> {
        if depth > MAX_DEPTH {
            return Err(JsonError("nesting too deep"));
        }
        match self.text.get(self.at) {
            Some(b'{') => self.object(depth),
            Some(b'[') => self.array(depth),
            Some(b'"') => Ok(Value::String(self.string()?)),
            Some(b't') => self.literal("true", Value::Bool(true)),
            Some(b'f') => self.literal("false", Value::Bool(false)),
            Some(b'n') => self.literal("null", Value::Null),
            Some(b'-' | b'0'..=b'9') => self.number(),
            _ => Err(JsonError("unexpected character")),
        }
    }

    fn literal(&mut self, word: &str, value: Value) -> Result<Value, JsonError> {
        if self.text[self.at..].starts_with(word.as_bytes()) {
            self.at += word.len();
            Ok(value)
        } else {
            Err(JsonError("invalid literal"))
        }
    }

    fn object(&mut self, depth: usize) -> Result<Value, JsonError> {
        self.expect(b'{')?;
        let mut map = Map::new();
        self.whitespace();
        if self.text.get(self.at) == Some(&b'}') {
            self.at += 1;
            return Ok(Value::Object(map));
        }
        loop {
            self.whitespace();
            if self.text.get(self.at) != Some(&b'"') {
                return Err(JsonError("object key must be a string"));
            }
            let key = self.string()?;
            self.whitespace();
            self.expect(b':')?;
            self.whitespace();
            let value = self.value(depth + 1)?;
            if map.insert(key, value).is_some() {
                return Err(JsonError("duplicate key"));
            }
            self.whitespace();
            match self.text.get(self.at) {
                Some(b',') => self.at += 1,
                Some(b'}') => {
                    self.at += 1;
                    return Ok(Value::Object(map));
                }
                _ => return Err(JsonError("unterminated object")),
            }
        }
    }

    fn array(&mut self, depth: usize) -> Result<Value, JsonError> {
        self.expect(b'[')?;
        let mut items = Vec::new();
        self.whitespace();
        if self.text.get(self.at) == Some(&b']') {
            self.at += 1;
            return Ok(Value::Array(items));
        }
        loop {
            self.whitespace();
            items.push(self.value(depth + 1)?);
            self.whitespace();
            match self.text.get(self.at) {
                Some(b',') => self.at += 1,
                Some(b']') => {
                    self.at += 1;
                    return Ok(Value::Array(items));
                }
                _ => return Err(JsonError("unterminated array")),
            }
        }
    }

    fn hex4(&mut self) -> Result<u32, JsonError> {
        let digits = self
            .source
            .get(self.at..self.at + 4)
            .ok_or(JsonError("short unicode escape"))?;
        let value = u32::from_str_radix(digits, 16).map_err(|_| JsonError("bad unicode escape"))?;
        if !digits.bytes().all(|b| b.is_ascii_hexdigit()) {
            return Err(JsonError("bad unicode escape"));
        }
        self.at += 4;
        Ok(value)
    }

    fn string(&mut self) -> Result<String, JsonError> {
        self.expect(b'"')?;
        let mut out = String::new();
        loop {
            let start = self.at;
            while let Some(&b) = self.text.get(self.at) {
                if b == b'"' || b == b'\\' || b < 0x20 {
                    break;
                }
                self.at += 1;
            }
            out.push_str(&self.source[start..self.at]);
            match self.text.get(self.at) {
                Some(b'"') => {
                    self.at += 1;
                    return Ok(out);
                }
                Some(b'\\') => {
                    self.at += 1;
                    let escape = *self.text.get(self.at).ok_or(JsonError("bad escape"))?;
                    self.at += 1;
                    match escape {
                        b'"' => out.push('"'),
                        b'\\' => out.push('\\'),
                        b'/' => out.push('/'),
                        b'b' => out.push('\u{8}'),
                        b'f' => out.push('\u{c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => {
                            let first = self.hex4()?;
                            let code = if (0xD800..0xDC00).contains(&first) {
                                if !self.text[self.at..].starts_with(b"\\u") {
                                    return Err(JsonError("lone surrogate"));
                                }
                                self.at += 2;
                                let second = self.hex4()?;
                                if !(0xDC00..0xE000).contains(&second) {
                                    return Err(JsonError("lone surrogate"));
                                }
                                0x10000 + ((first - 0xD800) << 10) + (second - 0xDC00)
                            } else if (0xDC00..0xE000).contains(&first) {
                                return Err(JsonError("lone surrogate"));
                            } else {
                                first
                            };
                            out.push(char::from_u32(code).ok_or(JsonError("bad code point"))?);
                        }
                        _ => return Err(JsonError("bad escape")),
                    }
                }
                _ => return Err(JsonError("control character or unterminated string")),
            }
        }
    }

    fn number(&mut self) -> Result<Value, JsonError> {
        let start = self.at;
        if self.text.get(self.at) == Some(&b'-') {
            self.at += 1;
        }
        match self.text.get(self.at) {
            Some(b'0') => self.at += 1,
            Some(b'1'..=b'9') => {
                while let Some(b'0'..=b'9') = self.text.get(self.at) {
                    self.at += 1;
                }
            }
            _ => return Err(JsonError("bad number")),
        }
        let mut float = false;
        if self.text.get(self.at) == Some(&b'.') {
            float = true;
            self.at += 1;
            let digits = self.at;
            while let Some(b'0'..=b'9') = self.text.get(self.at) {
                self.at += 1;
            }
            if self.at == digits {
                return Err(JsonError("bad number"));
            }
        }
        if let Some(b'e' | b'E') = self.text.get(self.at) {
            float = true;
            self.at += 1;
            if let Some(b'+' | b'-') = self.text.get(self.at) {
                self.at += 1;
            }
            let digits = self.at;
            while let Some(b'0'..=b'9') = self.text.get(self.at) {
                self.at += 1;
            }
            if self.at == digits {
                return Err(JsonError("bad number"));
            }
        }
        let literal = &self.source[start..self.at];
        // Python turns an overflowing float literal into infinity, which its
        // allow_nan=False re-encoding then refuses. Integers stay exact.
        if float && !literal.parse::<f64>().map(f64::is_finite).unwrap_or(false) {
            return Err(JsonError("non-finite number"));
        }
        Number::from_str(literal)
            .map(Value::Number)
            .map_err(|_| JsonError("bad number"))
    }
}

/// Integer in Python's sense: a JSON number literal with no fraction or exponent.
pub fn is_integer(value: &Value) -> bool {
    matches!(value, Value::Number(n) if !n.to_string().contains(['.', 'e', 'E']))
}

pub fn as_i128(value: &Value) -> Option<i128> {
    match value {
        Value::Number(n) if is_integer(value) => n.to_string().parse().ok(),
        _ => None,
    }
}

pub fn as_f64(value: &Value) -> Option<f64> {
    match value {
        Value::Number(n) => n.to_string().parse().ok(),
        _ => None,
    }
}

/// Python `type(v) in (int, float)` equality for small numeric comparisons.
pub fn numbers_equal(a: &Value, b: &Value) -> bool {
    match (as_i128(a), as_i128(b)) {
        (Some(x), Some(y)) => x == y,
        _ => match (as_f64(a), as_f64(b)) {
            (Some(x), Some(y)) => x == y,
            _ => false,
        },
    }
}

/// Compact encoding identical to `json.dumps(..., separators=(",", ":"),
/// ensure_ascii=False)` for the values this host produces.
pub fn encode(value: &Value) -> Vec<u8> {
    serde_json::to_vec(value).expect("serde_json::Value always encodes")
}

/// A fully encoded response. HTTP writes these bytes directly, after the whole
/// bounded serialization succeeds. This is transport ownership, not a proof or
/// a checked-provider token; external bytes cannot construct one publicly.
#[derive(Debug)]
pub struct EncodedReply {
    status: u16,
    bytes: Vec<u8>,
}

#[derive(Debug, PartialEq, Eq)]
pub enum EncodeError {
    TooLarge,
    Serialization,
}

struct BoundedWriter {
    bytes: Vec<u8>,
    maximum: usize,
    oversized: bool,
}

impl Write for BoundedWriter {
    fn write(&mut self, bytes: &[u8]) -> io::Result<usize> {
        if bytes.len() > self.maximum.saturating_sub(self.bytes.len()) {
            self.oversized = true;
            return Err(io::Error::other("reply byte limit"));
        }
        let needed = self.bytes.len() + bytes.len();
        if needed > self.bytes.capacity() {
            // Keep amortized growth while never requesting capacity above the
            // reply ceiling. Reserving exactly every serde token is quadratic.
            let target = needed
                .max(self.bytes.capacity().max(64).saturating_mul(2))
                .min(self.maximum);
            self.bytes
                .try_reserve_exact(target - self.bytes.len())
                .map_err(io::Error::other)?;
        }
        self.bytes.extend_from_slice(bytes);
        Ok(bytes.len())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

impl EncodedReply {
    pub(crate) fn encode<T: Serialize + ?Sized>(
        status: u16,
        value: &T,
        maximum: usize,
    ) -> Result<Self, EncodeError> {
        let mut writer = BoundedWriter {
            bytes: Vec::new(),
            maximum,
            oversized: false,
        };
        serde_json::to_writer(&mut writer, value).map_err(|_| {
            if writer.oversized {
                EncodeError::TooLarge
            } else {
                EncodeError::Serialization
            }
        })?;
        Ok(Self {
            status,
            bytes: writer.bytes,
        })
    }

    // Journal admission already checked the byte bound and strict JSON. Keeping
    // its original buffer preserves the authoritative retained encoding.
    pub(crate) fn retained(status: u16, bytes: Vec<u8>) -> Self {
        Self { status, bytes }
    }
    pub fn status(&self) -> u16 {
        self.status
    }
    pub fn body(&self) -> &[u8] {
        &self.bytes
    }

    /// Legacy direct-library adapter; the HTTP path never materializes this Value.
    pub fn into_value(self) -> (u16, Value) {
        (
            self.status,
            parse(&self.bytes).expect("internally serialized JSON reply"),
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refuses_what_the_reference_decoder_refuses() {
        for bad in [
            &br#"{"a":1,"a":2}"#[..],
            b"[NaN]",
            b"[Infinity]",
            b"[1e400]",
            br#"["\ud800"]"#,
            br#"["\udc00x"]"#,
            b"[01]",
            b"[1.]",
            b"{\"a\":\"\x01\"}",
            b"[1] x",
            b"\xff",
        ] {
            assert!(parse(bad).is_err(), "{:?}", String::from_utf8_lossy(bad));
        }
    }

    #[test]
    fn keeps_exact_literals_and_pairs() {
        let value =
            parse(br#" {"big":123456789012345678901234567890,"f":0.1,"s":"\ud83d\ude00\n"} "#)
                .unwrap();
        assert_eq!(value["big"].to_string(), "123456789012345678901234567890");
        assert!(is_integer(&value["big"]));
        assert!(!is_integer(&value["f"]));
        assert_eq!(value["s"], "\u{1F600}\n");
    }
}

#[cfg(test)]
mod encoded_tests {
    use super::*;

    #[test]
    fn bounded_encoding_preserves_exact_bytes_and_rejects_one_byte_over() {
        let value = parse(r#"{"decimal":51.248178375505404,"large":123456789012345678901234567890,"text":"☃\n\""}"#.as_bytes()).unwrap();
        let bytes = encode(&value);
        let reply = EncodedReply::encode(200, &value, bytes.len()).unwrap();
        assert_eq!(reply.body(), bytes);
        assert_eq!(reply.into_value(), (200, value.clone()));
        assert_eq!(
            EncodedReply::encode(200, &value, bytes.len() - 1).unwrap_err(),
            EncodeError::TooLarge
        );
    }

    #[test]
    fn tiny_writes_use_bounded_geometric_growth_and_never_append_over_limit() {
        let mut writer = BoundedWriter {
            bytes: Vec::new(),
            maximum: 65536,
            oversized: false,
        };
        let mut growths = 0;
        for _ in 0..65536 {
            let before = writer.bytes.capacity();
            writer.write_all(b"x").unwrap();
            if writer.bytes.capacity() != before {
                growths += 1;
            }
            assert!(writer.bytes.capacity() <= writer.maximum);
        }
        assert!(growths <= 16, "{growths} reallocations for tiny writes");
        assert_eq!(writer.bytes.len(), 65536);
        assert!(writer.write_all(b"x").is_err());
        assert_eq!(writer.bytes.len(), 65536);
        assert!(writer.oversized);
    }
}
