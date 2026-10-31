//! Existing descriptor refinements over serde events, without a result Value.
//! This produces no alternate value tree. Provider-specific checks still inspect
//! the retained domain request/certificate; scalar bounds retain strict_valid's
//! exact integer semantics (including u128, never conversion through binary64).
use super::*;
use serde::ser::*;
use serde::Serialize;
use std::collections::BTreeSet;
use std::fmt;
#[derive(Debug)]
pub(super) struct Error;
impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("typed result contract")
    }
}
impl std::error::Error for Error {}
impl serde::ser::Error for Error {
    fn custom<T: fmt::Display>(_: T) -> Self {
        Self
    }
}
pub(super) fn check<T: ?Sized + Serialize>(v: &T, s: &Value) -> bool {
    if let Some(a) = s.get("anyOf").and_then(Value::as_array) {
        return a.iter().any(|s| check(v, s));
    }
    v.serialize(Walk { s }).is_ok()
}
#[derive(Clone, Copy)]
struct Walk<'a> {
    s: &'a Value,
}
impl<'a> Walk<'a> {
    fn scalar(self, v: Value) -> Result<(), Error> {
        strict_valid(&v, self.s).then_some(()).ok_or(Error)
    }
    fn string(self, v: &str) -> Result<(), Error> {
        if self.s.get("const").is_some_and(|x| x.as_str() != Some(v)) {
            return Err(Error);
        }
        if self
            .s
            .get("enum")
            .and_then(Value::as_array)
            .is_some_and(|a| !a.iter().any(|x| x.as_str() == Some(v)))
        {
            return Err(Error);
        }
        if self.s.get("type").and_then(Value::as_str) != Some("string") {
            return self.s.get("const").is_some().then_some(()).ok_or(Error);
        }
        let min = self
            .s
            .get("minLength")
            .and_then(Value::as_u64)
            .ok_or(Error)?;
        let max = self
            .s
            .get("maxLength")
            .and_then(Value::as_u64)
            .ok_or(Error)?;
        if !(min..=max).contains(&(v.chars().count() as u64)) {
            return Err(Error);
        }
        if let Some(p) = self.s.get("pattern").and_then(Value::as_str) {
            static CACHE: std::sync::OnceLock<
                std::sync::Mutex<std::collections::HashMap<String, regex::Regex>>,
            > = std::sync::OnceLock::new();
            let mut cache = CACHE
                .get_or_init(Default::default)
                .lock()
                .map_err(|_| Error)?;
            if !cache.contains_key(p) {
                cache.insert(
                    p.to_owned(),
                    regex::Regex::new(&format!("^(?:{p})$")).map_err(|_| Error)?,
                );
            }
            if !cache.get(p).ok_or(Error)?.is_match(v) {
                return Err(Error);
            }
        }
        Ok(())
    }
    fn compound(self, array: bool) -> Result<Compound<'a>, Error> {
        if self.s.get("type").and_then(Value::as_str)
            != Some(if array { "array" } else { "object" })
            && !self
                .s
                .get("const")
                .is_some_and(|v| if array { v.is_array() } else { v.is_object() })
        {
            return Err(Error);
        }
        Ok(Compound {
            s: self.s,
            count: 0,
            seen: BTreeSet::new(),
            key: None,
            array,
        })
    }
}
struct Compound<'a> {
    s: &'a Value,
    count: u64,
    seen: BTreeSet<String>,
    key: Option<String>,
    array: bool,
}
impl Compound<'_> {
    fn element<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        let index = self.count as usize;
        self.count += 1;
        if let Some(items) = self.s.get("const").and_then(Value::as_array) {
            let expected = items.get(index).ok_or(Error)?;
            return check(v, &json!({"const":expected}))
                .then_some(())
                .ok_or(Error);
        }
        check(v, self.s.get("items").ok_or(Error)?)
            .then_some(())
            .ok_or(Error)
    }
    fn field<T: ?Sized + Serialize>(&mut self, key: &str, v: &T) -> Result<(), Error> {
        if let Some(fields) = self.s.get("const").and_then(Value::as_object) {
            let expected = fields.get(key).ok_or(Error)?;
            if !check(v, &json!({"const":expected})) {
                return Err(Error);
            }
            self.seen.insert(key.to_owned());
            return Ok(());
        }
        let child = self
            .s
            .get("properties")
            .and_then(|p| p.get(key))
            .ok_or(Error)?;
        if !check(v, child) {
            return Err(Error);
        }
        self.seen.insert(key.to_owned());
        Ok(())
    }
    fn finish(self) -> Result<(), Error> {
        if let Some(expected) = self.s.get("const") {
            return if self.array {
                expected
                    .as_array()
                    .is_some_and(|a| a.len() as u64 == self.count)
            } else {
                expected.as_object().is_some_and(|o| {
                    o.keys().all(|k| self.seen.contains(k)) && o.len() == self.seen.len()
                })
            }
            .then_some(())
            .ok_or(Error);
        }
        if self.array {
            let max = self
                .s
                .get("maxItems")
                .and_then(Value::as_u64)
                .ok_or(Error)?;
            let min = self.s.get("minItems").and_then(Value::as_u64).unwrap_or(0);
            (min..=max).contains(&self.count).then_some(()).ok_or(Error)
        } else {
            let required = self
                .s
                .get("required")
                .and_then(Value::as_array)
                .ok_or(Error)?;
            required
                .iter()
                .all(|k| k.as_str().is_some_and(|k| self.seen.contains(k)))
                .then_some(())
                .ok_or(Error)
        }
    }
}
impl<'a> Serializer for Walk<'a> {
    type Ok = ();
    type Error = Error;
    type SerializeSeq = Compound<'a>;
    type SerializeTuple = Compound<'a>;
    type SerializeTupleStruct = Compound<'a>;
    type SerializeTupleVariant = Compound<'a>;
    type SerializeMap = Compound<'a>;
    type SerializeStruct = Compound<'a>;
    type SerializeStructVariant = Compound<'a>;
    fn serialize_bool(self, v: bool) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_i8(self, v: i8) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_i16(self, v: i16) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_i32(self, v: i32) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_i64(self, v: i64) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_i128(self, v: i128) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_u8(self, v: u8) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_u16(self, v: u16) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_u32(self, v: u32) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_u64(self, v: u64) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_u128(self, v: u128) -> Result<(), Error> {
        self.scalar(json!(v))
    }
    fn serialize_f32(self, _: f32) -> Result<(), Error> {
        Err(Error)
    }
    fn serialize_f64(self, _: f64) -> Result<(), Error> {
        Err(Error)
    }
    fn serialize_char(self, v: char) -> Result<(), Error> {
        self.string(&v.to_string())
    }
    fn serialize_str(self, v: &str) -> Result<(), Error> {
        self.string(v)
    }
    fn serialize_bytes(self, _: &[u8]) -> Result<(), Error> {
        Err(Error)
    }
    fn serialize_none(self) -> Result<(), Error> {
        self.scalar(Value::Null)
    }
    fn serialize_some<T: ?Sized + Serialize>(self, v: &T) -> Result<(), Error> {
        check(v, self.s).then_some(()).ok_or(Error)
    }
    fn serialize_unit(self) -> Result<(), Error> {
        self.scalar(Value::Null)
    }
    fn serialize_unit_struct(self, _: &'static str) -> Result<(), Error> {
        self.serialize_unit()
    }
    fn serialize_unit_variant(self, _: &'static str, _: u32, v: &'static str) -> Result<(), Error> {
        self.string(v)
    }
    fn serialize_newtype_struct<T: ?Sized + Serialize>(
        self,
        _: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        check(v, self.s).then_some(()).ok_or(Error)
    }
    fn serialize_newtype_variant<T: ?Sized + Serialize>(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: &T,
    ) -> Result<(), Error> {
        Err(Error)
    }
    fn serialize_seq(self, _: Option<usize>) -> Result<Compound<'a>, Error> {
        self.compound(true)
    }
    fn serialize_tuple(self, _: usize) -> Result<Compound<'a>, Error> {
        self.compound(true)
    }
    fn serialize_tuple_struct(self, _: &'static str, _: usize) -> Result<Compound<'a>, Error> {
        self.compound(true)
    }
    fn serialize_tuple_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Compound<'a>, Error> {
        Err(Error)
    }
    fn serialize_map(self, _: Option<usize>) -> Result<Compound<'a>, Error> {
        self.compound(false)
    }
    fn serialize_struct(self, _: &'static str, _: usize) -> Result<Compound<'a>, Error> {
        self.compound(false)
    }
    fn serialize_struct_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Compound<'a>, Error> {
        Err(Error)
    }
    fn collect_str<T: ?Sized + fmt::Display>(self, v: &T) -> Result<(), Error> {
        self.string(&v.to_string())
    }
}
impl SerializeSeq for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_element<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        self.element(v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeTuple for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_element<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        self.element(v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeTupleStruct for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        self.element(v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeTupleVariant for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        self.element(v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeMap for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_key<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        self.key = Some(
            serde_json::to_value(v)
                .map_err(|_| Error)?
                .as_str()
                .ok_or(Error)?
                .to_owned(),
        );
        Ok(())
    }
    fn serialize_value<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        let k = self.key.take().ok_or(Error)?;
        self.field(&k, v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeStruct for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(
        &mut self,
        k: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        self.field(k, v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
impl SerializeStructVariant for Compound<'_> {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(
        &mut self,
        k: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        self.field(k, v)
    }
    fn end(self) -> Result<(), Error> {
        self.finish()
    }
}
