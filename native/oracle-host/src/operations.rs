//! Operation discovery registry: a port of `tools/appliance/operations.py`
//! `Operations.add/discover` for host-registered providers only.

use crate::wire::encode;
use crate::Failure;
use serde_json::{json, Value};
use std::collections::BTreeMap;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Route {
    Runtime,
    Pure(&'static str),
}

pub struct Registry {
    pub items: BTreeMap<String, Value>,
    pub routes: BTreeMap<String, Route>,
    request_bytes: usize,
    reply_bytes: usize,
}

pub fn valid_operation_id(id: &str) -> bool {
    let bytes = id.as_bytes();
    !bytes.is_empty()
        && bytes.len() <= 160
        && bytes[0].is_ascii_alphanumeric()
        && bytes
            .iter()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(b))
}

/// `operations.descriptor(...)` defaults, overlaid by the declaration.
fn descriptor(declaration: &Value) -> Value {
    let id = declaration["id"].clone();
    let name = declaration
        .get("name")
        .cloned()
        .unwrap_or_else(|| id.clone());
    let mut item = json!({
        "id": id, "name": name, "description": name, "availability": "unavailable",
        "input_schema": {"type": "object", "properties": {"text": {"type": "string", "minLength": 1, "maxLength": 12000}},
                         "required": ["text"], "additionalProperties": false},
        "output_schema": {"type": "object", "description": "Complete implementation result, including evidence and refusal fields."},
        "units": {"input": "explicit in text", "output": "declared by implementation"},
        "sources": [], "examples": [], "implementation": {}, "limitations": []
    });
    if let (Some(target), Some(source)) = (item.as_object_mut(), declaration.as_object()) {
        for (key, value) in source {
            if key != "id" && key != "name" {
                target.insert(key.clone(), value.clone());
            }
        }
    }
    item
}

impl Registry {
    pub fn new(request_bytes: usize, reply_bytes: usize) -> Self {
        Self {
            items: BTreeMap::new(),
            routes: BTreeMap::new(),
            request_bytes,
            reply_bytes,
        }
    }

    pub fn add(&mut self, declaration: &Value, route: Route) -> Result<(), String> {
        let mut item = descriptor(declaration);
        item["transport_limits"] = json!({
            "request_body_bytes": self.request_bytes, "reply_bytes": self.reply_bytes,
            "scope": "Whole JSON envelope; input-schema ceilings do not override transport bounds."});
        let id = item["id"].as_str().unwrap_or("").to_owned();
        if !valid_operation_id(&id) || self.items.contains_key(&id) {
            return Err(format!("invalid/duplicate operation identity {id:?}"));
        }
        if item["availability"] != "live_direct" {
            return Err(format!("{id}: only live operations are registered"));
        }
        if encode(&item).len() > 24000 {
            return Err(format!("{id}: operation descriptor exceeds 24 KiB"));
        }
        self.items.insert(id.clone(), item);
        self.routes.insert(id, route);
        Ok(())
    }

    fn page_limit(&self) -> usize {
        (self.reply_bytes.saturating_sub(128)).min(32768)
    }

    pub fn detail(&self, operation_id: &str) -> Result<Value, Failure> {
        let item = self
            .items
            .get(operation_id)
            .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        if encode(item).len() > self.page_limit() {
            return Err(Failure::plain(413, "discovery_reply_too_large"));
        }
        Ok(item.clone())
    }

    pub fn list(
        &self,
        offset: usize,
        limit: usize,
        q: &str,
        availability: Option<&str>,
    ) -> Result<Value, Failure> {
        let needle = q.to_lowercase();
        let rows: Vec<&Value> = self
            .items
            .values()
            .filter(|item| availability.is_none_or(|a| item["availability"] == a))
            .filter(|item| {
                needle.is_empty()
                    || format!(
                        "{} {} {}",
                        item["id"].as_str().unwrap_or(""),
                        item["name"].as_str().unwrap_or(""),
                        item["description"].as_str().unwrap_or("")
                    )
                    .to_lowercase()
                    .contains(&needle)
            })
            .collect();
        let mut page = json!({"protocol": "oracle-operations-v1", "total": rows.len(), "offset": offset,
            "next_offset": null, "operations": [],
            "limits": {"request_body_bytes": self.request_bytes, "reply_bytes": self.page_limit()}});
        let end = (offset + limit).min(rows.len());
        for index in offset..end {
            let mut candidate = page.clone();
            candidate["operations"]
                .as_array_mut()
                .expect("array")
                .push(rows[index].clone());
            candidate["next_offset"] = if index + 1 < rows.len() {
                json!(index + 1)
            } else {
                Value::Null
            };
            if encode(&candidate).len() > self.page_limit() {
                if page["operations"].as_array().is_some_and(Vec::is_empty) {
                    return Err(Failure::plain(413, "discovery_reply_too_large"));
                }
                break;
            }
            page = candidate;
        }
        Ok(page)
    }

    /// Structural argument check before any provider work (400 on failure).
    pub fn check_arguments(&self, operation_id: &str, arguments: &Value) -> Result<Route, Failure> {
        let item = self
            .items
            .get(operation_id)
            .ok_or_else(|| Failure::plain(404, "unknown_operation"))?;
        crate::schema::validate(arguments, &item["input_schema"], "arguments")
            .map_err(|field| Failure::new(400, "invalid_arguments", json!({"field": field})))?;
        Ok(self.routes[operation_id])
    }
}
