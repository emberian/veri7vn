//! Exploratory, unverified revision and explanation layer. Not a public host API.
use oracle_logic::{Operation, Request, Rule, Scope};
use serde::Serialize;
use std::collections::{BTreeMap, BTreeSet};

#[derive(Clone, Debug, Serialize)]
pub struct Entry {
    pub id: String,
    pub provenance: String,
    pub active: bool,
    pub rule: Rule,
}
#[derive(Clone, Debug, Serialize)]
pub struct Revision {
    pub number: usize,
    pub description: String,
    pub asserted: Vec<String>,
    pub withdrawn: Vec<String>,
}
#[derive(Clone, Debug)]
pub struct Program {
    tenant: String,
    topic: String,
    atoms: Vec<String>,
    ids: BTreeMap<String, usize>,
    entries: BTreeMap<String, Entry>,
    revisions: Vec<Revision>,
}
#[derive(Clone, Debug)]
pub enum Change<'a> {
    Assert {
        id: &'a str,
        atom: &'a str,
        source: &'a str,
    },
    Withdraw {
        id: &'a str,
    },
}
impl Program {
    pub fn new(tenant: &str, topic: &str) -> Self {
        Self {
            tenant: tenant.into(),
            topic: topic.into(),
            atoms: vec![],
            ids: BTreeMap::new(),
            entries: BTreeMap::new(),
            revisions: vec![],
        }
    }
    pub fn atom(&mut self, name: &str) -> usize {
        if let Some(&id) = self.ids.get(name) {
            return id;
        }
        let id = self.atoms.len();
        self.atoms.push(name.into());
        self.ids.insert(name.into(), id);
        id
    }
    pub fn rule(
        &mut self,
        id: &str,
        source: &str,
        head: Option<&str>,
        positive: &[&str],
        negative: &[&str],
    ) {
        assert!(
            !self.entries.contains_key(id),
            "rule/evidence ID must be unique"
        );
        let rule = Rule {
            head: head.map(|h| self.atom(h)),
            positive: positive.iter().map(|p| self.atom(p)).collect(),
            negative: negative.iter().map(|n| self.atom(n)).collect(),
        };
        self.entries.insert(
            id.into(),
            Entry {
                id: id.into(),
                provenance: source.into(),
                active: true,
                rule,
            },
        );
    }
    /// Atomic draft-and-replace revision. A withdrawal names one evidence token,
    /// not an atom: other evidence and rules can continue to support that atom.
    /// Evidence IDs are immutable; re-observations get a new ID.
    pub fn revise(&mut self, description: &str, changes: &[Change<'_>]) -> Result<(), String> {
        let mut draft = self.clone();
        let mut asserted = vec![];
        let mut withdrawn = vec![];
        for change in changes {
            match change {
                Change::Assert { id, atom, source } => {
                    if draft.entries.contains_key(*id) {
                        return Err(format!("evidence ID already used: {id}"));
                    }
                    draft.rule(id, source, Some(atom), &[], &[]);
                    asserted.push((*id).into());
                }
                Change::Withdraw { id } => {
                    let entry = draft
                        .entries
                        .get_mut(*id)
                        .ok_or_else(|| format!("unknown evidence ID: {id}"))?;
                    if !entry.active
                        || !entry.rule.positive.is_empty()
                        || !entry.rule.negative.is_empty()
                        || entry.rule.head.is_none()
                    {
                        return Err(format!("only an active fact token can be withdrawn: {id}"));
                    }
                    entry.active = false;
                    withdrawn.push((*id).into());
                }
            }
        }
        draft.revisions.push(Revision {
            number: draft.revisions.len() + 1,
            description: description.into(),
            asserted,
            withdrawn,
        });
        *self = draft;
        Ok(())
    }
    pub fn request(&self, queries: &[&str]) -> Request {
        // Exploratory label only: rule()/atom() do not advance this revision
        // counter. Seal construction or content-hash EVERY change before using
        // scope.snapshot as a durable identity/cache key. No cache exists here.
        let queries = queries
            .iter()
            .map(|q| *self.ids.get(*q).expect("queries must name declared atoms"))
            .collect();
        Request {
            operation: Operation::Query,
            scope: Scope {
                tenant: self.tenant.clone(),
                snapshot: format!("{}:revision-{}", self.topic, self.revisions.len()),
                complete_program: true,
            },
            atoms: self.atoms.clone(),
            rules: self
                .entries
                .values()
                .filter(|e| e.active)
                .map(|e| e.rule.clone())
                .collect(),
            queries,
        }
    }
    pub fn ledger(&self) -> Vec<&Entry> {
        self.entries.values().collect()
    }
    pub fn revisions(&self) -> &[Revision] {
        &self.revisions
    }
    pub fn names(&self, ids: &[usize]) -> Vec<&str> {
        ids.iter().map(|&id| self.atoms[id].as_str()).collect()
    }

    /// Conditional derivation trace for a supplied interpretation. This does not
    /// prove that the interpretation is stable or that all models were found.
    /// Ordered rounds record finite grounded support, never a recursive cycle
    /// as its own justification. All fired alternative supports are retained.
    pub fn explain(&self, names: &[&str]) -> serde_json::Value {
        let candidate: BTreeSet<_> = names
            .iter()
            .map(|name| *self.ids.get(*name).expect("known candidate atom"))
            .collect();
        let mut derived = BTreeSet::new();
        let mut steps = vec![];
        let mut fired = BTreeSet::new();
        let mut round = 0;
        loop {
            let before = derived.clone();
            round += 1;
            for entry in self.entries.values().filter(|e| e.active) {
                let r = &entry.rule;
                if fired.contains(&entry.id)
                    || r.negative.iter().any(|a| candidate.contains(a))
                    || !r.positive.iter().all(|a| before.contains(a))
                {
                    continue;
                }
                fired.insert(entry.id.clone());
                if let Some(head) = r.head {
                    derived.insert(head);
                    steps.push(
                        serde_json::json!({"round":round,"atom":self.atoms[head],"rule_id":entry.id,
                        "source":entry.provenance,"positive_support":self.names(&r.positive),
                        "default_assumptions_absent_from_this_model":self.names(&r.negative)}),
                    );
                } else {
                    steps.push(serde_json::json!({"round":round,"violated_constraint":entry.id,"source":entry.provenance}));
                }
            }
            if derived == before {
                break;
            }
        }
        serde_json::json!({"interpretation":names,"conditional_derivation":steps,
            "unsupported_candidate_atoms":candidate.difference(&derived).map(|&a|self.atoms[a].clone()).collect::<Vec<_>>(),
            "closure_atoms_outside_candidate":derived.difference(&candidate).map(|&a|self.atoms[a].clone()).collect::<Vec<_>>(),
            "assurance":"explanatory trace only; use existing GL checker for model admission"})
    }
}

#[derive(Serialize)]
pub struct Expectation<'a> {
    pub atom: &'a str,
    pub skeptical: Option<bool>,
    pub credulous: Option<bool>,
}
pub fn both(atom: &str, skeptical: bool, credulous: bool) -> Expectation<'_> {
    Expectation {
        atom,
        skeptical: Some(skeptical),
        credulous: Some(credulous),
    }
}

/// Default is a design trace with handwritten expected results. Explicit
/// --solver /absolute/operator-admitted/clingo opts into the existing API.
/// Authoring these demos did not execute either mode or any solver.
pub fn emit(
    program: &mut Program,
    title: &str,
    queries: &[&str],
    expected_status: &str,
    expected: &[Expectation<'_>],
    expected_models: &[Vec<&str>],
    note: &str,
) {
    let request = program.request(queries);
    let traces: Vec<_> = expected_models.iter().map(|m| program.explain(m)).collect();
    let mut output = serde_json::json!({"scenario":title,"request":request,"evidence_ledger":program.ledger(),
        "revisions":program.revisions(),"handwritten_expected_status":expected_status,
        "handwritten_expected_answers":expected,"handwritten_expected_models_with_conditional_traces":traces,
        "design_note":note,"qualification":"new demo layer authored only; not runtime checked"});
    let args: Vec<_> = std::env::args().collect();
    if args.len() == 3 && args[1] == "--solver" {
        let input = serde_json::to_string(&request).expect("serialize request");
        let limits = oracle_logic::Limits {
            milliseconds: 3000,
            ..oracle_logic::Limits::default()
        };
        let result = oracle_logic::process::call(
            &input,
            std::path::Path::new(&args[2]),
            &limits,
            &std::sync::atomic::AtomicBool::new(false),
        );
        output["actual_solver_reply"] = match result {
            Ok(s) => serde_json::from_str(&s).expect("reply JSON"),
            Err(e) => serde_json::json!({"error":e.to_string()}),
        };
    } else {
        assert!(
            args.len() == 1,
            "usage: reasoning_lab [--solver /absolute/operator-admitted/clingo]"
        );
    }
    println!(
        "{}",
        serde_json::to_string_pretty(&output).expect("serialize trace")
    );
}
