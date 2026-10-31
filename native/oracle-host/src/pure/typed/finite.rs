//! Allocation-free serialization-shape walk. serde_json maps nonfinite floats
//! to null, so the private checked-result constructor must reject them first.
use serde::ser::*;
use serde::Serialize;
use std::fmt;
#[derive(Debug)]
pub(super) struct Error;
impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("nonfinite typed result")
    }
}
impl std::error::Error for Error {}
impl serde::ser::Error for Error {
    fn custom<T: fmt::Display>(_: T) -> Self {
        Self
    }
}
#[derive(Clone, Copy)]
struct Walk;
pub(super) fn check<T: Serialize>(value: &T) -> Result<(), Error> {
    value.serialize(Walk)
}
impl Serializer for Walk {
    type Ok = ();
    type Error = Error;
    type SerializeSeq = Self;
    type SerializeTuple = Self;
    type SerializeTupleStruct = Self;
    type SerializeTupleVariant = Self;
    type SerializeMap = Self;
    type SerializeStruct = Self;
    type SerializeStructVariant = Self;
    fn serialize_bool(self, _: bool) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_i8(self, _: i8) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_i16(self, _: i16) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_i32(self, _: i32) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_i64(self, _: i64) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_i128(self, _: i128) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_u8(self, _: u8) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_u16(self, _: u16) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_u32(self, _: u32) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_u64(self, _: u64) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_u128(self, _: u128) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_f32(self, v: f32) -> Result<(), Error> {
        if v.is_finite() {
            Ok(())
        } else {
            Err(Error)
        }
    }
    fn serialize_f64(self, v: f64) -> Result<(), Error> {
        if v.is_finite() {
            Ok(())
        } else {
            Err(Error)
        }
    }
    fn serialize_char(self, _: char) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_str(self, _: &str) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_bytes(self, _: &[u8]) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_none(self) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_some<T: ?Sized + Serialize>(self, v: &T) -> Result<(), Error> {
        v.serialize(self)
    }
    fn serialize_unit(self) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_unit_struct(self, _: &'static str) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_unit_variant(self, _: &'static str, _: u32, _: &'static str) -> Result<(), Error> {
        Ok(())
    }
    fn serialize_newtype_struct<T: ?Sized + Serialize>(
        self,
        _: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        v.serialize(self)
    }
    fn serialize_newtype_variant<T: ?Sized + Serialize>(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        v.serialize(self)
    }
    fn serialize_seq(self, _: Option<usize>) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_tuple(self, _: usize) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_tuple_struct(self, _: &'static str, _: usize) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_tuple_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_map(self, _: Option<usize>) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_struct(self, _: &'static str, _: usize) -> Result<Self, Error> {
        Ok(self)
    }
    fn serialize_struct_variant(
        self,
        _: &'static str,
        _: u32,
        _: &'static str,
        _: usize,
    ) -> Result<Self, Error> {
        Ok(self)
    }
    fn collect_str<T: ?Sized + fmt::Display>(self, _: &T) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeSeq for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_element<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeTuple for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_element<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeTupleStruct for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeTupleVariant for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeMap for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_key<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn serialize_value<T: ?Sized + Serialize>(&mut self, v: &T) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeStruct for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(
        &mut self,
        _: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
impl SerializeStructVariant for Walk {
    type Ok = ();
    type Error = Error;
    fn serialize_field<T: ?Sized + Serialize>(
        &mut self,
        _: &'static str,
        v: &T,
    ) -> Result<(), Error> {
        v.serialize(*self)
    }
    fn end(self) -> Result<(), Error> {
        Ok(())
    }
}
