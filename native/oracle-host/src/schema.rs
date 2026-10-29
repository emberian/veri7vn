//! The two bounded JSON-schema subsets the reference adapters use.
//!
//! `validate` ports `tools/appliance/operations.py` `validate` (input
//! arguments; permissive defaults). `strict_valid` ports `reasoning.py`
//! `_valid` (native output shape; every bound is required). Neither evaluates
//! `$ref`, formats or any keyword outside the subset; providers check meaning.

use crate::wire::{as_f64, as_i128, is_integer, numbers_equal};
use regex::Regex;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::{Mutex, OnceLock};

fn pattern(source: &str) -> Option<Regex> {
    static CACHE: OnceLock<Mutex<HashMap<String, Option<Regex>>>> = OnceLock::new();
    let cache = CACHE.get_or_init(|| Mutex::new(HashMap::new()));
    let mut cache = cache.lock().unwrap_or_else(|e| e.into_inner());
    cache
        .entry(source.to_owned())
        .or_insert_with(|| Regex::new(source).ok())
        .clone()
}

fn type_matches(kind: &str, value: &Value) -> bool {
    match kind {
        "object" => value.is_object(),
        "array" => value.is_array(),
        "string" => value.is_string(),
        "number" => value.is_number(),
        "integer" => is_integer(value),
        "boolean" => value.is_boolean(),
        "null" => value.is_null(),
        _ => false,
    }
}

/// Python equality for `const`/`enum`: same JSON type and equal value.
fn python_equal(a: &Value, b: &Value) -> bool {
    match (a, b) {
        (Value::Number(_), Value::Number(_)) => {
            is_integer(a) == is_integer(b) && numbers_equal(a, b)
        }
        (Value::Array(x), Value::Array(y)) => {
            x.len() == y.len() && x.iter().zip(y).all(|(p, q)| python_equal(p, q))
        }
        (Value::Object(x), Value::Object(y)) => {
            x.len() == y.len()
                && x.iter()
                    .all(|(k, v)| y.get(k).is_some_and(|w| python_equal(v, w)))
        }
        _ => a == b,
    }
}

/// `value in enum`: Python `in` uses `==`, so 1 == 1.0 and True == 1.
fn python_in(value: &Value, options: &[Value]) -> bool {
    options.iter().any(|option| match (value, option) {
        (Value::Number(_), Value::Number(_)) => numbers_equal(value, option),
        (Value::Bool(b), Value::Number(_)) | (Value::Number(_), Value::Bool(b)) => {
            let n = if value.is_number() { value } else { option };
            as_i128(n) == Some(i128::from(*b))
        }
        _ => python_equal(value, option),
    })
}

fn compare_bound(value: &Value, bound: &Value) -> Option<std::cmp::Ordering> {
    match (as_i128(value), as_i128(bound)) {
        (Some(a), Some(b)) => Some(a.cmp(&b)),
        _ => as_f64(value)?.partial_cmp(&as_f64(bound)?),
    }
}

fn chars(text: &str) -> usize {
    text.chars().count()
}

fn usize_field(schema: &Value, key: &str, default: usize) -> usize {
    schema
        .get(key)
        .and_then(Value::as_u64)
        .map_or(default, |n| n as usize)
}

/// Port of `operations.validate`; `Err(field)` names the failing location.
pub fn validate(value: &Value, schema: &Value, at: &str) -> Result<(), String> {
    let fail = || Err(at.to_owned());
    if let Some(kind) = schema.get("type") {
        let ok = match kind {
            Value::Array(kinds) => kinds
                .iter()
                .any(|k| k.as_str().is_some_and(|k| type_matches(k, value))),
            Value::String(k) => type_matches(k, value),
            _ => false,
        };
        if !ok {
            return fail();
        }
    }
    if let Some(expected) = schema.get("const") {
        if !python_equal(value, expected) {
            return fail();
        }
    }
    if let Some(Value::Array(options)) = schema.get("enum") {
        if !python_in(value, options) {
            return fail();
        }
    }
    match value {
        Value::Object(map) => {
            let empty = serde_json::Map::new();
            let properties = schema
                .get("properties")
                .and_then(Value::as_object)
                .unwrap_or(&empty);
            if let Some(Value::Array(required)) = schema.get("required") {
                if required
                    .iter()
                    .any(|k| k.as_str().is_none_or(|k| !map.contains_key(k)))
                {
                    return fail();
                }
            }
            let additional = schema.get("additionalProperties");
            if additional == Some(&Value::Bool(false))
                && map.keys().any(|k| !properties.contains_key(k))
            {
                return fail();
            }
            for (key, item) in map {
                let where_ = format!("{at}.{key}");
                if let Some(child) = properties.get(key) {
                    validate(item, child, &where_)?;
                } else if let Some(child @ Value::Object(_)) = additional {
                    validate(item, child, &where_)?;
                }
            }
        }
        Value::String(text) => {
            let n = chars(text);
            if n < usize_field(schema, "minLength", 0)
                || n > usize_field(schema, "maxLength", 1_000_000)
            {
                return fail();
            }
            if let Some(Value::String(source)) = schema.get("pattern") {
                if !source.is_empty() && !pattern(source).is_some_and(|re| re.is_match(text)) {
                    return fail();
                }
            }
        }
        Value::Array(items) => {
            if items.len() < usize_field(schema, "minItems", 0)
                || items.len() > usize_field(schema, "maxItems", 100_000)
            {
                return fail();
            }
            let empty = Value::Object(Default::default());
            let child = schema.get("items").unwrap_or(&empty);
            for item in items {
                validate(item, child, &format!("{at}[]"))?;
            }
        }
        Value::Number(_) => {
            if let Some(minimum) = schema.get("minimum") {
                if compare_bound(value, minimum) == Some(std::cmp::Ordering::Less) {
                    return fail();
                }
            }
            if let Some(maximum) = schema.get("maximum") {
                if compare_bound(value, maximum) == Some(std::cmp::Ordering::Greater) {
                    return fail();
                }
            }
        }
        _ => {}
    }
    if let Some(Value::Array(choices)) = schema.get("anyOf") {
        if !choices
            .iter()
            .any(|choice| validate(value, choice, at).is_ok())
        {
            return fail();
        }
    }
    Ok(())
}

/// Port of `reasoning._valid`: native results must match exactly, with no
/// coercion. Missing bounds in the schema make the value invalid.
pub fn strict_valid(value: &Value, schema: &Value) -> bool {
    if let Some(Value::Array(choices)) = schema.get("anyOf") {
        return choices.iter().any(|choice| strict_valid(value, choice));
    }
    if let Some(expected) = schema.get("const") {
        if !python_equal(value, expected) {
            return false;
        }
    }
    if let Some(Value::Array(options)) = schema.get("enum") {
        if !python_in(value, options) {
            return false;
        }
    }
    let in_range = |value: &Value| -> bool {
        match (schema.get("minimum"), schema.get("maximum")) {
            (Some(lo), Some(hi)) => {
                compare_bound(value, lo).is_some_and(|o| o != std::cmp::Ordering::Less)
                    && compare_bound(value, hi).is_some_and(|o| o != std::cmp::Ordering::Greater)
            }
            _ => false,
        }
    };
    match schema.get("type").and_then(Value::as_str) {
        Some("object") => {
            let (Some(map), Some(Value::Array(required)), Some(Value::Object(properties))) = (
                value.as_object(),
                schema.get("required"),
                schema.get("properties"),
            ) else {
                return false;
            };
            required
                .iter()
                .all(|k| k.as_str().is_some_and(|k| map.contains_key(k)))
                && map.iter().all(|(k, v)| {
                    properties
                        .get(k)
                        .is_some_and(|child| strict_valid(v, child))
                })
        }
        Some("array") => {
            let (Some(items), Some(max)) = (
                value.as_array(),
                schema.get("maxItems").and_then(Value::as_u64),
            ) else {
                return false;
            };
            let min = schema.get("minItems").and_then(Value::as_u64).unwrap_or(0);
            let Some(child) = schema.get("items") else {
                return false;
            };
            (min..=max).contains(&(items.len() as u64))
                && items.iter().all(|item| strict_valid(item, child))
        }
        Some("integer") => is_integer(value) && in_range(value),
        Some("boolean") => value.is_boolean(),
        Some("null") => value.is_null(),
        Some("string") => {
            let (Some(text), Some(min), Some(max)) = (
                value.as_str(),
                schema.get("minLength").and_then(Value::as_u64),
                schema.get("maxLength").and_then(Value::as_u64),
            ) else {
                return false;
            };
            let n = chars(text) as u64;
            (min..=max).contains(&n)
                && match schema.get("pattern").and_then(Value::as_str) {
                    // Python re.fullmatch.
                    Some(source) => {
                        pattern(&format!("^(?:{source})$")).is_some_and(|re| re.is_match(text))
                    }
                    None => true,
                }
        }
        _ => schema.get("const").is_some(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn validate_matches_reference_subset() {
        let schema = json!({"type":"object","properties":{"n":{"type":"integer","minimum":0,"maximum":3},
            "s":{"type":"string","minLength":1,"maxLength":2,"pattern":"^[ab]+$"}},
            "required":["n"],"additionalProperties":false});
        assert!(validate(&json!({"n":2,"s":"ab"}), &schema, "arguments").is_ok());
        assert!(validate(&json!({"n":2.0}), &schema, "arguments").is_err());
        assert!(validate(&json!({"n":4}), &schema, "arguments").is_err());
        assert!(validate(&json!({"n":1,"x":1}), &schema, "arguments").is_err());
        assert!(validate(&json!({"n":1,"s":"abc"}), &schema, "arguments").is_err());
        assert!(validate(&json!({"n":1,"s":"c"}), &schema, "arguments").is_err());
        assert!(validate(&json!({"s":"a"}), &schema, "arguments").is_err());
        assert!(validate(&json!({"n":true}), &schema, "arguments").is_err());
    }

    #[test]
    fn strict_valid_requires_declared_bounds() {
        let schema =
            json!({"type":"array","items":{"type":"integer","minimum":0,"maximum":9},"maxItems":2});
        assert!(strict_valid(&json!([1, 2]), &schema));
        assert!(!strict_valid(&json!([1, 2, 3]), &schema));
        assert!(!strict_valid(&json!([1, 10]), &schema));
        assert!(!strict_valid(
            &json!([1]),
            &json!({"type":"array","items":{"type":"integer"}})
        ));
    }
}
