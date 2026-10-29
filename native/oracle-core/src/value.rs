//! Bounded exact values for structured Oracle programs.
//!
//! This is handwritten runtime code, not an extracted or verified kernel. Years
//! use astronomical numbering in a proleptic Gregorian calendar: 0 is 1 BCE and
//! -1 is 2 BCE. A year is a whole-year precision value, never an invented January
//! 1. Cross-precision comparisons can therefore overlap. Source type tags are
//!    authoritative; a source `date` on January 1 remains a day-precision date.

use crate::{Error, Result};
use num_bigint::BigInt;
use num_rational::BigRational;
use num_traits::{One, Signed, Zero};
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;
use std::{cmp::Ordering, fmt};

/// Per-scalar limits. Callers must also meter the number of values they process.
/// Absolute ceilings prevent a permissive configuration from admitting an
/// arbitrarily expensive integer parse, GCD, comparison, or display operation.
#[derive(Clone, Debug, Deserialize, Serialize)]
#[serde(default, deny_unknown_fields)]
pub struct ValueLimits {
    pub max_text_bytes: usize,
    pub max_numeric_digits: usize,
    pub max_exponent: u32,
    pub max_unit_bytes: usize,
}

impl Default for ValueLimits {
    fn default() -> Self {
        Self {
            max_text_bytes: 4096,
            max_numeric_digits: 256,
            max_exponent: 1024,
            max_unit_bytes: 256,
        }
    }
}

impl ValueLimits {
    pub fn validate(&self) -> Result<()> {
        if self.max_text_bytes == 0
            || self.max_text_bytes > 16_384
            || self.max_numeric_digits == 0
            || self.max_numeric_digits > 1024
            || self.max_exponent > 2048
            || self.max_unit_bytes == 0
            || self.max_unit_bytes > 1024
        {
            return Err(invalid("invalid value limits"));
        }
        Ok(())
    }

    fn check_text(&self, text: &str) -> Result<()> {
        self.validate()?;
        if text.len() > self.max_text_bytes {
            return Err(Error::Limit("value text bytes"));
        }
        Ok(())
    }
}

fn invalid(message: &str) -> Error {
    Error::Invalid(message.into())
}

/// A reduced rational admitted only through a bounded parse. No binary float
/// participates in parsing, comparison, known-unit conversion, or formatting.
#[derive(Clone, Debug)]
pub struct ExactNumber(BigRational, String);

impl PartialEq for ExactNumber {
    fn eq(&self, other: &Self) -> bool {
        self.0 == other.0
    }
}
impl Eq for ExactNumber {}
impl PartialOrd for ExactNumber {
    fn partial_cmp(&self, other: &Self) -> Option<Ordering> {
        Some(self.cmp(other))
    }
}
impl Ord for ExactNumber {
    fn cmp(&self, other: &Self) -> Ordering {
        self.0.cmp(&other.0)
    }
}
impl std::hash::Hash for ExactNumber {
    fn hash<H: std::hash::Hasher>(&self, state: &mut H) {
        std::hash::Hash::hash(&self.0, state);
    }
}

impl ExactNumber {
    /// Decimal/scientific syntax, or a ratio of two signed decimal integers.
    /// Spaces around a scalar are allowed; commas, NaN, infinity and suffixes
    /// are not. Rational denominators must be nonzero.
    pub fn parse(input: &str, limits: &ValueLimits) -> Result<Self> {
        limits.check_text(input)?;
        let text = input.trim();
        let digits = text.bytes().filter(u8::is_ascii_digit).count();
        if digits > limits.max_numeric_digits {
            return Err(Error::Limit("numeric digits"));
        }
        if let Some((numerator, denominator)) = text.split_once('/') {
            let numerator = parse_integer(numerator)?;
            let denominator = parse_integer(denominator)?;
            if denominator.is_zero() {
                return Err(invalid("zero rational denominator"));
            }
            return Ok(Self(BigRational::new(numerator, denominator), text.into()));
        }
        let (mantissa, exponent) = if let Some(index) = text.find(['e', 'E']) {
            let exponent_text = &text[index + 1..];
            let magnitude = exponent_text
                .strip_prefix(['+', '-'])
                .unwrap_or(exponent_text);
            if magnitude.is_empty() || !magnitude.bytes().all(|b| b.is_ascii_digit()) {
                return Err(invalid("invalid decimal exponent"));
            }
            // Checked digit accumulation rejects huge exponents without an
            // intermediate big integer or a power-of-ten allocation.
            let mut exponent: u32 = 0;
            for digit in magnitude.bytes() {
                exponent = exponent
                    .checked_mul(10)
                    .and_then(|value| value.checked_add(u32::from(digit - b'0')))
                    .ok_or(Error::Limit("decimal exponent"))?;
                if exponent > limits.max_exponent {
                    return Err(Error::Limit("decimal exponent"));
                }
            }
            let exponent = if exponent_text.starts_with('-') {
                -(exponent as i32)
            } else {
                exponent as i32
            };
            (&text[..index], exponent)
        } else {
            (text, 0)
        };
        let (negative, unsigned) = strip_sign(mantissa);
        let mut coefficient = String::with_capacity(unsigned.len());
        let mut point = false;
        let mut fractional_digits = 0_i32;
        for byte in unsigned.bytes() {
            match byte {
                b'0'..=b'9' => {
                    coefficient.push(char::from(byte));
                    if point {
                        fractional_digits += 1;
                    }
                }
                b'.' if !point => point = true,
                _ => return Err(invalid("invalid exact decimal")),
            }
        }
        if coefficient.is_empty() {
            return Err(invalid("empty exact decimal"));
        }
        let mut numerator = BigInt::parse_bytes(coefficient.as_bytes(), 10)
            .ok_or_else(|| invalid("invalid exact decimal"))?;
        if negative {
            numerator = -numerator;
        }
        let scale = fractional_digits - exponent;
        let ten = BigInt::from(10_u8);
        let number = if scale >= 0 {
            BigRational::new(numerator, ten.pow(scale as u32))
        } else {
            BigRational::from_integer(numerator * ten.pow((-scale) as u32))
        };
        Ok(Self(number, text.into()))
    }

    pub fn numerator(&self) -> &BigInt {
        self.0.numer()
    }

    pub fn denominator(&self) -> &BigInt {
        self.0.denom()
    }

    /// The admitted exact text, useful for persistence without expanding a
    /// small scientific literal into thousands of decimal digits.
    pub fn source_literal(&self) -> &str {
        &self.1
    }

    /// Explicit exact agreement policy. Every input was admitted through a
    /// bounded parse; this fixed expression cannot grow through repeated public
    /// arithmetic. The floor has the same scalar dimension as the values.
    pub fn within_relative(
        &self,
        other: &Self,
        tolerance: &Self,
        floor: &Self,
        limits: &ValueLimits,
    ) -> Result<bool> {
        limits.validate()?;
        // Re-admit original bounded literals under this caller's budget,
        // without expanding a scientific literal merely to check its size.
        for number in [self, other, tolerance, floor] {
            Self::parse(number.source_literal(), limits)?;
        }
        if tolerance.0.is_negative() || tolerance.0 >= BigRational::one() || floor.0.is_negative() {
            return Err(invalid(
                "relative tolerance needs 0 <= tolerance < 1 and floor >= 0",
            ));
        }
        let scale = self.0.abs().max(other.0.abs()).max(floor.0.clone());
        Ok((&self.0 - &other.0).abs() <= &tolerance.0 * scale)
    }
}

fn strip_sign(text: &str) -> (bool, &str) {
    if let Some(unsigned) = text.strip_prefix('-') {
        (true, unsigned)
    } else {
        (false, text.strip_prefix('+').unwrap_or(text))
    }
}

fn parse_integer(text: &str) -> Result<BigInt> {
    let (negative, unsigned) = strip_sign(text);
    if unsigned.is_empty() || !unsigned.bytes().all(|b| b.is_ascii_digit()) {
        return Err(invalid("invalid rational integer"));
    }
    let integer = BigInt::parse_bytes(unsigned.as_bytes(), 10)
        .ok_or_else(|| invalid("invalid rational integer"))?;
    Ok(if negative { -integer } else { integer })
}

impl fmt::Display for ExactNumber {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.0.is_integer() {
            return write!(formatter, "{}", self.0.numer());
        }
        let mut denominator = self.0.denom().clone();
        let mut twos = 0_u32;
        let mut fives = 0_u32;
        while (&denominator % 2_u8).is_zero() {
            denominator /= 2_u8;
            twos += 1;
        }
        while (&denominator % 5_u8).is_zero() {
            denominator /= 5_u8;
            fives += 1;
        }
        if !denominator.is_one() {
            return write!(formatter, "{}/{}", self.0.numer(), self.0.denom());
        }
        let scale = twos.max(fives);
        let coefficient = self.0.numer().abs()
            * BigInt::from(2_u8).pow(scale - twos)
            * BigInt::from(5_u8).pow(scale - fives);
        let digits = coefficient.to_string();
        if self.0.is_negative() {
            formatter.write_str("-")?;
        }
        let scale = scale as usize;
        if digits.len() <= scale {
            formatter.write_str("0.")?;
            for _ in digits.len()..scale {
                formatter.write_str("0")?;
            }
            formatter.write_str(&digits)
        } else {
            let point = digits.len() - scale;
            write!(formatter, "{}.{}", &digits[..point], &digits[point..])
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ValueKind {
    String,
    Quantity,
    Year,
    Date,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
pub enum ComparisonOp {
    #[default]
    #[serde(rename = "=", alias = "eq")]
    Eq,
    #[serde(rename = "!=", alias = "ne")]
    Ne,
    #[serde(rename = "<", alias = "lt")]
    Lt,
    #[serde(rename = "<=", alias = "le")]
    Le,
    #[serde(rename = ">", alias = "gt")]
    Gt,
    #[serde(rename = ">=", alias = "ge")]
    Ge,
}

/// `Equal` means equal values at the same precision. `Overlap` retains missing
/// precision, such as 2000 versus 2000-06-01, without declaring equality.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum ValueComparison {
    Less,
    Equal,
    Greater,
    /// Known unequal, with no admitted ordering (for example two strings).
    Unequal,
    Overlap,
    Incomparable,
}

impl From<Ordering> for ValueComparison {
    fn from(ordering: Ordering) -> Self {
        match ordering {
            Ordering::Less => Self::Less,
            Ordering::Equal => Self::Equal,
            Ordering::Greater => Self::Greater,
        }
    }
}

impl ValueComparison {
    /// None is an unknown predicate, never an automatic false or a "no" answer.
    /// Overlap is conservatively unknown even at interval endpoints.
    pub fn test(self, operation: ComparisonOp) -> Option<bool> {
        use ComparisonOp::*;
        match self {
            Self::Overlap | Self::Incomparable => None,
            Self::Unequal => match operation {
                Eq => Some(false),
                Ne => Some(true),
                _ => None,
            },
            Self::Less => Some(matches!(operation, Ne | Lt | Le)),
            Self::Equal => Some(matches!(operation, Eq | Le | Ge)),
            Self::Greater => Some(matches!(operation, Ne | Gt | Ge)),
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum UnitPolicy {
    /// Only identical case-sensitive labels are compatible, including unknown
    /// labels. No alias, physical dimension, or conversion is guessed.
    #[default]
    ExactLabel,
    /// Additionally convert an explicit small linear SI table. This policy is
    /// opt-in and does not support offsets such as Celsius/Fahrenheit.
    KnownSi,
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Quantity {
    amount: ExactNumber,
    unit: String,
}

impl Quantity {
    pub fn new(amount: ExactNumber, unit: &str, limits: &ValueLimits) -> Result<Self> {
        limits.validate()?;
        if unit.is_empty() || unit.trim() != unit || unit.chars().any(char::is_control) {
            return Err(invalid("unit must be a nonempty clean label"));
        }
        if unit.len() > limits.max_unit_bytes {
            return Err(Error::Limit("unit bytes"));
        }
        Ok(Self {
            amount,
            unit: unit.into(),
        })
    }

    pub fn amount(&self) -> &ExactNumber {
        &self.amount
    }

    pub fn unit(&self) -> &str {
        &self.unit
    }

    pub fn compare(&self, other: &Self, policy: UnitPolicy) -> ValueComparison {
        if self.unit == other.unit {
            return self.amount.cmp(&other.amount).into();
        }
        if policy == UnitPolicy::KnownSi {
            if let (Some((left_dimension, left_scale)), Some((right_dimension, right_scale))) =
                (known_unit(&self.unit), known_unit(&other.unit))
            {
                if left_dimension == right_dimension {
                    return (self.amount.0.clone() * left_scale)
                        .cmp(&(other.amount.0.clone() * right_scale))
                        .into();
                }
            }
        }
        ValueComparison::Incomparable
    }
}

fn known_unit(unit: &str) -> Option<(&'static str, BigRational)> {
    let (dimension, numerator, denominator): (&str, i64, i64) = match unit {
        "1" => ("dimensionless", 1, 1),
        "metre" => ("length", 1, 1),
        "kilometre" => ("length", 1000, 1),
        "centimetre" => ("length", 1, 100),
        "millimetre" => ("length", 1, 1000),
        "mile" => ("length", 201168, 125),
        "foot" => ("length", 381, 1250),
        "yard" => ("length", 1143, 1250),
        "inch" => ("length", 127, 5000),
        "nautical mile" => ("length", 1852, 1),
        "kilogram" => ("mass", 1, 1),
        "gram" => ("mass", 1, 1000),
        "tonne" => ("mass", 1000, 1),
        "pound" => ("mass", 45359237, 100000000),
        "second" => ("time", 1, 1),
        "minute" => ("time", 60, 1),
        "hour" => ("time", 3600, 1),
        "day" => ("time", 86400, 1),
        "square metre" => ("area", 1, 1),
        "square kilometre" => ("area", 1000000, 1),
        "hectare" => ("area", 10000, 1),
        "metre per second" => ("speed", 1, 1),
        "kilometre per hour" => ("speed", 5, 18),
        _ => return None,
    };
    Some((
        dimension,
        BigRational::new(numerator.into(), denominator.into()),
    ))
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct CalendarYear(i64);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Era {
    Bce,
    Ce,
}

impl CalendarYear {
    /// Every signed 64-bit astronomical year is representable. Calendar
    /// validation uses remainders and field comparisons, never a day-count
    /// multiplication that could overflow for very old source records.
    pub const fn new(year: i64) -> Self {
        Self(year)
    }

    /// Explicit conversion for historical labels, which have no year zero.
    pub fn from_common_era(era: Era, year_of_era: u64) -> Result<Self> {
        if year_of_era == 0 {
            return Err(invalid("invalid historical year"));
        }
        let astronomical = match era {
            Era::Ce => i128::from(year_of_era),
            Era::Bce => 1 - i128::from(year_of_era),
        };
        let year = i64::try_from(astronomical).map_err(|_| Error::Limit("calendar year range"))?;
        Ok(Self::new(year))
    }

    pub fn number(self) -> i64 {
        self.0
    }

    pub fn is_leap(self) -> bool {
        self.0.rem_euclid(4) == 0 && (self.0.rem_euclid(100) != 0 || self.0.rem_euclid(400) == 0)
    }

    pub fn parse(text: &str, limits: &ValueLimits) -> Result<Self> {
        limits.check_text(text)?;
        let text = text.trim();
        let (_, unsigned) = strip_sign(text);
        if unsigned.is_empty() || !unsigned.bytes().all(|b| b.is_ascii_digit()) {
            return Err(invalid("invalid calendar year"));
        }
        let year: i64 = text
            .parse()
            .map_err(|_| Error::Limit("calendar year range"))?;
        Ok(Self::new(year))
    }
}

impl fmt::Display for CalendarYear {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(formatter, "{}", self.0)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct GregorianDate {
    year: CalendarYear,
    month: u8,
    day: u8,
}

impl GregorianDate {
    pub fn new(year: CalendarYear, month: u8, day: u8) -> Result<Self> {
        let days = match month {
            1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
            4 | 6 | 9 | 11 => 30,
            2 if year.is_leap() => 29,
            2 => 28,
            _ => return Err(invalid("invalid Gregorian month")),
        };
        if day == 0 || day > days {
            return Err(invalid("invalid Gregorian day"));
        }
        Ok(Self { year, month, day })
    }

    pub fn parse(text: &str, limits: &ValueLimits) -> Result<Self> {
        limits.check_text(text)?;
        let text = text.trim();
        let (_, unsigned) = strip_sign(text);
        let separator = if unsigned.contains('/') { '/' } else { '-' };
        let mut pieces = unsigned.split(separator);
        let year = pieces.next().unwrap_or("");
        let month = pieces.next().ok_or_else(|| invalid("missing date month"))?;
        let day = pieces.next().ok_or_else(|| invalid("missing date day"))?;
        if pieces.next().is_some()
            || year.is_empty()
            || !(1..=2).contains(&month.len())
            || !(1..=2).contains(&day.len())
            || !month.bytes().all(|b| b.is_ascii_digit())
            || !day.bytes().all(|b| b.is_ascii_digit())
        {
            return Err(invalid("invalid Gregorian date syntax"));
        }
        let year_end = text.len() - unsigned.len() + year.len();
        Self::new(
            CalendarYear::parse(&text[..year_end], limits)?,
            month
                .parse()
                .map_err(|_| invalid("invalid Gregorian month"))?,
            day.parse().map_err(|_| invalid("invalid Gregorian day"))?,
        )
    }

    pub fn year(self) -> CalendarYear {
        self.year
    }
    pub fn month(self) -> u8 {
        self.month
    }
    pub fn day(self) -> u8 {
        self.day
    }
}

impl fmt::Display for GregorianDate {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        if self.year.number() < 0 {
            write!(
                formatter,
                "-{:04}-{:02}-{:02}",
                self.year.number().unsigned_abs(),
                self.month,
                self.day
            )
        } else {
            write!(
                formatter,
                "{:04}-{:02}-{:02}",
                self.year.number(),
                self.month,
                self.day
            )
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum TypedValue {
    String(String),
    Quantity(Quantity),
    Year(CalendarYear),
    Date(GregorianDate),
}

/// Exact key for the structured reader's case-insensitive string equality.
/// Source whitespace is significant; literal trimming belongs to parse_literal.
pub(crate) fn string_equality_key(text: &str) -> String {
    text.to_lowercase()
}

impl TypedValue {
    pub fn kind(&self) -> ValueKind {
        match self {
            Self::String(_) => ValueKind::String,
            Self::Quantity(_) => ValueKind::Quantity,
            Self::Year(_) => ValueKind::Year,
            Self::Date(_) => ValueKind::Date,
        }
    }

    pub fn from_kqa(source: &JsonValue, limits: &ValueLimits) -> Result<Self> {
        limits.validate()?;
        let object = source
            .as_object()
            .ok_or_else(|| invalid("typed value must be an object"))?;
        let kind = object
            .get("type")
            .and_then(JsonValue::as_str)
            .ok_or_else(|| invalid("missing typed value type"))?;
        let value = object
            .get("value")
            .ok_or_else(|| invalid("missing typed value payload"))?;
        match kind {
            "string" => {
                let text = value
                    .as_str()
                    .ok_or_else(|| invalid("string payload must be text"))?;
                limits.check_text(text)?;
                Ok(Self::String(text.into()))
            }
            "quantity" => {
                let amount = ExactNumber::parse(&scalar_text(value)?, limits)?;
                let unit = match object.get("unit") {
                    None => "1",
                    Some(value) => value.as_str().ok_or_else(|| invalid("unit must be text"))?,
                };
                Ok(Self::Quantity(Quantity::new(amount, unit, limits)?))
            }
            "year" => Ok(Self::Year(CalendarYear::parse(
                &scalar_text(value)?,
                limits,
            )?)),
            "date" => Ok(Self::Date(GregorianDate::parse(
                value
                    .as_str()
                    .ok_or_else(|| invalid("date payload must be text"))?,
                limits,
            )?)),
            _ => Err(invalid("unknown typed value type")),
        }
    }

    pub fn from_json(source: &JsonValue, limits: &ValueLimits) -> Result<Self> {
        Self::from_kqa(source, limits)
    }

    /// Parses an entire literal. Quantity syntax is `<number> [unit]`, where
    /// the unit must be separated by whitespace and defaults to dimensionless
    /// `1`. Date contexts additionally accept a year-only precision literal.
    pub fn parse_literal(text: &str, kind: ValueKind, limits: &ValueLimits) -> Result<Self> {
        limits.check_text(text)?;
        let text = text.trim();
        match kind {
            ValueKind::String => Ok(Self::String(text.into())),
            ValueKind::Quantity => {
                let split = text.find(char::is_whitespace);
                let (number, unit) = match split {
                    Some(index) => (&text[..index], text[index..].trim()),
                    None => (text, "1"),
                };
                Ok(Self::Quantity(Quantity::new(
                    ExactNumber::parse(number, limits)?,
                    unit,
                    limits,
                )?))
            }
            ValueKind::Year => Ok(Self::Year(CalendarYear::parse(text, limits)?)),
            ValueKind::Date => {
                if let Ok(year) = CalendarYear::parse(text, limits) {
                    Ok(Self::Year(year))
                } else {
                    Ok(Self::Date(GregorianDate::parse(text, limits)?))
                }
            }
        }
    }

    pub fn compare(&self, other: &Self) -> ValueComparison {
        self.compare_with_units(other, UnitPolicy::ExactLabel)
    }

    pub fn compare_with_units(&self, other: &Self, units: UnitPolicy) -> ValueComparison {
        match (self, other) {
            (Self::String(left), Self::String(right)) => {
                // Case-insensitive text equality matches the structured reader;
                // lexical ordering is intentionally not a numeric/date cast.
                if string_equality_key(left) == string_equality_key(right) {
                    ValueComparison::Equal
                } else {
                    ValueComparison::Unequal
                }
            }
            (Self::Quantity(left), Self::Quantity(right)) => left.compare(right, units),
            (Self::Year(left), Self::Year(right)) => left.cmp(right).into(),
            (Self::Date(left), Self::Date(right)) => left.cmp(right).into(),
            (Self::Year(left), Self::Date(right)) => compare_year_day(*left, right.year()),
            (Self::Date(left), Self::Year(right)) => compare_year_day(left.year(), *right),
            _ => ValueComparison::Incomparable,
        }
    }

    pub fn year(&self) -> Option<CalendarYear> {
        match self {
            Self::Year(year) => Some(*year),
            Self::Date(date) => Some(date.year()),
            _ => None,
        }
    }

    /// Explicit projection for year predicates. This compares the year field,
    /// so a day and its year compare equal *at year precision*.
    pub fn compare_at_year(&self, other: &Self) -> ValueComparison {
        match (self.year(), other.year()) {
            (Some(left), Some(right)) => left.cmp(&right).into(),
            _ => ValueComparison::Incomparable,
        }
    }

    /// Exact portable representation. Quantity values are strings because JSON
    /// has no rational scalar; this also prevents a downstream float round trip.
    pub fn to_kqa(&self) -> JsonValue {
        match self {
            Self::String(text) => serde_json::json!({"type":"string","value":text}),
            Self::Quantity(quantity) => serde_json::json!({
                "type":"quantity", "value":quantity.amount().source_literal(), "unit":quantity.unit()
            }),
            Self::Year(year) => serde_json::json!({"type":"year","value":year.number()}),
            Self::Date(date) => serde_json::json!({"type":"date","value":date.to_string()}),
        }
    }
}

impl Serialize for TypedValue {
    fn serialize<S: serde::Serializer>(
        &self,
        serializer: S,
    ) -> std::result::Result<S::Ok, S::Error> {
        self.to_kqa().serialize(serializer)
    }
}

impl<'de> Deserialize<'de> for TypedValue {
    fn deserialize<D: serde::Deserializer<'de>>(
        deserializer: D,
    ) -> std::result::Result<Self, D::Error> {
        let source = JsonValue::deserialize(deserializer)?;
        Self::from_kqa(&source, &ValueLimits::default()).map_err(serde::de::Error::custom)
    }
}

fn compare_year_day(left: CalendarYear, right: CalendarYear) -> ValueComparison {
    if left == right {
        ValueComparison::Overlap
    } else {
        left.cmp(&right).into()
    }
}

fn scalar_text(value: &JsonValue) -> Result<String> {
    match value {
        JsonValue::String(text) => Ok(text.clone()),
        JsonValue::Number(number) => Ok(number.to_string()),
        _ => Err(invalid("numeric payload must be a number or exact text")),
    }
}

impl fmt::Display for TypedValue {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::String(text) => formatter.write_str(text),
            Self::Quantity(quantity) if quantity.unit() == "1" => {
                write!(formatter, "{}", quantity.amount())
            }
            Self::Quantity(quantity) => {
                write!(formatter, "{} {}", quantity.amount(), quantity.unit())
            }
            Self::Year(year) => write!(formatter, "{year}"),
            Self::Date(date) => write!(formatter, "{date}"),
        }
    }
}
