//! Request-owned checked operations over the chart's persistent syntax recipes.
//! This is an untrusted compiler. Syntax occurrences (including dead/repeated
//! steps) retain their original admission limits; semantic nodes only share work.
use crate::grammar;
use crate::program::{
    lower_operation, validate_operation, Lowered, Operation, ProgramStep, ProgramType,
};
use crate::query::{CheckedPlanView, Node, Projection};
use crate::{Budget, Error, Limits, Result};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::borrow::Cow;
use std::cell::{Cell, RefCell};
use std::collections::HashMap;
use std::sync::{Arc, OnceLock};

pub(crate) struct PackedStep<'a> {
    pub function: &'a str,
    pub inputs: &'a [Value],
    pub dependencies: &'a [usize],
}
pub(crate) trait PackedProgramSource: Send + Sync {
    fn step_count(&self) -> usize;
    fn visit_steps(&self, visitor: &mut dyn FnMut(PackedStep<'_>) -> Result<()>) -> Result<()>;
}
pub(crate) type OwnedPackedProgram = Arc<dyn PackedProgramSource>;
#[derive(Clone, Copy)]
pub(crate) struct PackedProgramRef<'a> {
    source: &'a OwnedPackedProgram,
}
impl<'a> PackedProgramRef<'a> {
    pub fn new(source: &'a OwnedPackedProgram) -> Self {
        Self { source }
    }
    pub fn source(self) -> &'a dyn PackedProgramSource {
        self.source.as_ref()
    }
    pub fn owned(self) -> OwnedPackedProgram {
        Arc::clone(self.source)
    }
    pub fn step_count(self) -> usize {
        self.source.step_count()
    }
    pub fn visit_steps(self, visitor: &mut dyn FnMut(PackedStep<'_>) -> Result<()>) -> Result<()> {
        self.source.visit_steps(visitor)
    }
}
struct FlatSource {
    program: grammar::Program,
    _memory: Option<Arc<crate::budget::MemoryReservation>>,
}
impl PackedProgramSource for FlatSource {
    fn step_count(&self) -> usize {
        self.program.len()
    }
    fn visit_steps(&self, visitor: &mut dyn FnMut(PackedStep<'_>) -> Result<()>) -> Result<()> {
        for step in &self.program {
            visitor(PackedStep {
                function: &step.function,
                inputs: &step.inputs,
                dependencies: &step.dependencies,
            })?;
        }
        Ok(())
    }
}
pub(crate) fn from_flat(program: grammar::Program) -> OwnedPackedProgram {
    Arc::new(FlatSource {
        program,
        _memory: None,
    })
}
pub(crate) fn from_flat_retained(
    program: grammar::Program,
    memory: Arc<crate::budget::MemoryReservation>,
) -> OwnedPackedProgram {
    Arc::new(FlatSource {
        program,
        _memory: Some(memory),
    })
}
thread_local! { static MATERIALIZATIONS: Cell<usize> = const { Cell::new(0) }; }
pub(crate) fn materialization_count() -> usize {
    MATERIALIZATIONS.with(Cell::get)
}
/// Explicit public-diagnostics/compatibility expansion; never called by checking.
pub(crate) fn materialize(source: PackedProgramRef<'_>) -> Result<grammar::Program> {
    MATERIALIZATIONS.with(|count| count.set(count.get().saturating_add(1)));
    let mut output = Vec::with_capacity(source.step_count());
    source.visit_steps(&mut |step| {
        output.push(grammar::Step {
            function: step.function.to_owned(),
            inputs: step.inputs.to_vec(),
            dependencies: step.dependencies.to_vec(),
        });
        Ok(())
    })?;
    Ok(output)
}
#[derive(Serialize)]
struct EncodedStep<'a> {
    function: &'a str,
    dependencies: &'a [usize],
    inputs: &'a [Value],
}
/// Exact original wire bytes without constructing any flat Step/Value vector.
pub(crate) fn source_bytes(source: PackedProgramRef<'_>, limit: usize) -> Result<usize> {
    source_bytes_budget(source, limit, None)
}
fn source_bytes_budget(
    source: PackedProgramRef<'_>,
    limit: usize,
    budget: Option<&Budget>,
) -> Result<usize> {
    let mut bytes = 2usize;
    let mut count = 0usize;
    source.visit_steps(&mut |step| {
        if let Some(budget) = budget {
            budget.check()?;
        }
        let size = crate::query::encoded_size(
            &EncodedStep {
                function: step.function,
                dependencies: step.dependencies,
                inputs: step.inputs,
            },
            limit,
        )?;
        if let Some(budget) = budget {
            budget.spend(size as u64 + 1)?;
        }
        bytes = bytes
            .checked_add(size)
            .and_then(|n| n.checked_add(usize::from(count != 0)))
            .ok_or(Error::Limit("request bytes"))?;
        if bytes > limit {
            return Err(Error::Limit("encoded bytes"));
        }
        count += 1;
        Ok(())
    })?;
    if bytes > limit {
        return Err(Error::Limit("encoded bytes"));
    }
    if count != source.step_count() {
        return Err(Error::Invalid("packed occurrence count".into()));
    }
    Ok(bytes)
}
#[derive(Clone, Copy)]
pub(crate) enum CompileOrigin {
    Fragment,
    Whole,
    Composed,
    Complete,
}
#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct WorkspaceStats {
    pub fragment_checks: usize,
    pub complete_checks: usize,
    pub whole_checks: usize,
    pub composed_checks: usize,
    pub fragment_materializations: usize,
    pub resident_roots: usize,
    pub syntax_specs: usize,
    pub validation_failures: usize,
    pub lowered_operations: usize,
    pub root_cache_hits: usize,
    pub rejected_cache_hits: usize,
    pub checked_roots: usize,
    pub materializations: usize,
}
#[derive(Clone, PartialEq, Eq, Hash)]
struct Occurrence {
    spec: usize,
    dependencies: Box<[usize]>,
}
#[derive(PartialEq, Eq, Hash)]
struct OperationKey {
    spec: usize,
    dependencies: Box<[usize]>,
}
struct Spec {
    step: Option<ProgramStep>,
    _memory: crate::budget::MemoryReservation,
}
struct CheckedOperation {
    id: usize,
    output_type: ProgramType,
    lowered: Lowered,
    node: Option<Node>,
    _memory: crate::budget::MemoryReservation,
}
struct EntityOccurrence {
    operation: Arc<CheckedOperation>,
    inputs: Box<[usize]>,
}
/// Every entity-producing occurrence remains in order, even when two refer to
/// the same checked semantic node. The syntax source separately preserves every
/// scalar/dead/duplicate occurrence for diagnostics and original byte/step caps.
pub(crate) struct CheckedProgram {
    pub terminal: Operation,
    source: OwnedPackedProgram,
    entities: Vec<EntityOccurrence>,
    output: usize,
    projection: Arc<Projection>,
    pub execution: OnceLock<Option<crate::reader::SharedExecution>>,
    syntax: OnceLock<crate::reader::ReaderShared<grammar::Program>>,
    _memory: crate::budget::MemoryReservation,
}
impl CheckedProgram {
    pub fn syntax(&self, budget: &Budget) -> Result<crate::reader::ReaderShared<grammar::Program>> {
        if let Some(syntax) = self.syntax.get() {
            return Ok(syntax.clone());
        }
        let source = PackedProgramRef::new(&self.source);
        let bytes = source_bytes(source, usize::MAX)?
            .saturating_mul(16)
            .saturating_add(128);
        // Reserve before expanding the diagnostic payload, and coown its guard.
        let memory = budget.reserve_memory(bytes)?;
        let syntax = crate::reader::ReaderShared::with_reservation(materialize(source)?, memory);
        let _ = self.syntax.set(syntax.clone());
        Ok(syntax)
    }
}
fn rebase_node(node: &mut Node, inputs: &[usize]) {
    match node {
        Node::Relate { input, .. }
        | Node::FilterConcept { input, .. }
        | Node::FilterAttribute { input, .. }
        | Node::FilterQualifier { input, .. } => *input = inputs[0],
        Node::And { left, right } | Node::Or { left, right } => {
            *left = inputs[0];
            *right = inputs[1];
        }
        _ => {}
    }
}
impl CheckedPlanView for CheckedProgram {
    fn node_count(&self) -> usize {
        self.entities.len()
    }
    fn node(&self, index: usize) -> Cow<'_, Node> {
        let occurrence = &self.entities[index];
        let node = occurrence
            .operation
            .node
            .as_ref()
            .expect("entity occurrence");
        if occurrence.inputs.is_empty() {
            Cow::Borrowed(node)
        } else {
            let mut node = node.clone();
            rebase_node(&mut node, &occurrence.inputs);
            Cow::Owned(node)
        }
    }
    fn output(&self) -> usize {
        self.output
    }
    fn projection(&self) -> &Projection {
        &self.projection
    }
}
enum RootEntry {
    Checked(Arc<CheckedProgram>),
    Rejected(crate::budget::MemoryReservation),
}
#[derive(Default)]
struct Storage {
    spec_keys: HashMap<String, usize>,
    specs: Vec<Spec>,
    operation_keys: HashMap<OperationKey, usize>,
    operations: Vec<Arc<CheckedOperation>>,
    roots: HashMap<Box<[Occurrence]>, RootEntry>,
}
pub(crate) struct ProgramWorkspace {
    limits: Limits,
    budget: Budget,
    storage: RefCell<Storage>,
    stats: Cell<WorkspaceStats>,
    initial_materializations: usize,
}
#[derive(Clone)]
enum LocalResult {
    Entity(usize),
    Scalar {
        output: usize,
        projection: Arc<Projection>,
    },
}
impl LocalResult {
    fn output(&self) -> usize {
        match self {
            Self::Entity(i) | Self::Scalar { output: i, .. } => *i,
        }
    }
}
struct FragmentMaterializationScope<'a> {
    stats: &'a Cell<WorkspaceStats>,
    initial: usize,
}
impl Drop for FragmentMaterializationScope<'_> {
    fn drop(&mut self) {
        let mut stats = self.stats.get();
        stats.fragment_materializations = stats
            .fragment_materializations
            .saturating_add(materialization_count().saturating_sub(self.initial));
        self.stats.set(stats);
    }
}
impl ProgramWorkspace {
    pub fn new(limits: &Limits, budget: &Budget) -> Self {
        Self {
            limits: limits.clone(),
            budget: budget.clone(),
            storage: RefCell::new(Storage::default()),
            stats: Cell::new(WorkspaceStats::default()),
            initial_materializations: materialization_count(),
        }
    }
    pub fn stats(&self) -> WorkspaceStats {
        let mut stats = self.stats.get();
        stats.resident_roots = self.storage.borrow().roots.len();
        stats.materializations =
            materialization_count().saturating_sub(self.initial_materializations);
        stats
    }
    fn update(&self, f: impl FnOnce(&mut WorkspaceStats)) {
        let mut stats = self.stats.get();
        f(&mut stats);
        self.stats.set(stats);
    }
    fn intern_spec(&self, source: &PackedStep<'_>) -> Result<usize> {
        // This is a content key for one raw operation specification, not a flat
        // program. Exact literal spellings stay distinct even if values agree.
        let key = serde_json::to_string(&(source.function, source.inputs))?;
        if let Some(id) = self.storage.borrow().spec_keys.get(&key) {
            return Ok(*id);
        }
        let memory = self
            .budget
            .reserve_memory(key.len().saturating_mul(8).saturating_add(256))?;
        let step = (|| -> Result<ProgramStep> {
            let function = Operation::deserialize(serde::de::value::StrDeserializer::<
                serde::de::value::Error,
            >::new(source.function))
            .map_err(|e| Error::Invalid(e.to_string()))?;
            let inputs = source
                .inputs
                .iter()
                .map(|v| {
                    v.as_str()
                        .map(str::to_owned)
                        .ok_or_else(|| Error::Invalid("program literal must be a string".into()))
                })
                .collect::<Result<Vec<_>>>()?;
            let step = ProgramStep {
                function,
                inputs,
                dependencies: vec![],
            };
            validate_operation(0, &step, &function.contract().dependencies)?;
            Ok(step)
        })();
        let step = match step {
            Ok(step) => Some(step),
            Err(Error::Invalid(_) | Error::Json(_)) => None,
            Err(error) => return Err(error),
        };
        self.update(|s| {
            s.syntax_specs += 1;
            s.validation_failures += usize::from(step.is_none());
        });
        let mut storage = self.storage.borrow_mut();
        let id = storage.specs.len();
        storage.specs.push(Spec {
            step,
            _memory: memory,
        });
        storage.spec_keys.insert(key, id);
        Ok(id)
    }
    pub fn compile(
        &self,
        source: PackedProgramRef<'_>,
        origin: CompileOrigin,
    ) -> Result<Option<Arc<CheckedProgram>>> {
        self.budget.check()?;
        let _fragment_materializations = match origin {
            CompileOrigin::Fragment => Some(FragmentMaterializationScope {
                stats: &self.stats,
                initial: materialization_count(),
            }),
            _ => None,
        };
        self.update(|s| match origin {
            CompileOrigin::Fragment => s.fragment_checks += 1,
            CompileOrigin::Whole => {
                s.complete_checks += 1;
                s.whole_checks += 1;
            }
            CompileOrigin::Composed => {
                s.complete_checks += 1;
                s.composed_checks += 1;
            }
            CompileOrigin::Complete => s.complete_checks += 1,
        });
        if source.step_count() > self.limits.plan_nodes {
            return Err(Error::Limit("reader program steps"));
        }
        // Always reassess occurrence admission before consulting any cache.
        source_bytes_budget(source, self.limits.request_bytes, Some(&self.budget))?;
        let mut occurrences = Vec::with_capacity(source.step_count());
        source.visit_steps(&mut |step| {
            self.budget.spend(1)?;
            occurrences.push(Occurrence {
                spec: self.intern_spec(&step)?,
                dependencies: step.dependencies.into(),
            });
            Ok(())
        })?;
        if let Some(cached) = self.storage.borrow().roots.get(occurrences.as_slice()) {
            return Ok(match cached {
                RootEntry::Checked(root) => {
                    self.update(|s| s.root_cache_hits += 1);
                    Some(Arc::clone(root))
                }
                RootEntry::Rejected(_) => {
                    self.update(|s| s.rejected_cache_hits += 1);
                    None
                }
            });
        }
        let memory = self.budget.reserve_memory(
            occurrences
                .len()
                .saturating_mul(256)
                .saturating_add(
                    occurrences
                        .iter()
                        .map(|o| o.dependencies.len().saturating_mul(16))
                        .fold(0usize, usize::saturating_add),
                )
                .saturating_add(512),
        )?;
        let checked = self.check_occurrences(source, &occurrences, memory)?;
        match checked {
            Some(root) => {
                let root = Arc::new(root);
                self.storage.borrow_mut().roots.insert(
                    occurrences.into_boxed_slice(),
                    RootEntry::Checked(Arc::clone(&root)),
                );
                self.update(|s| s.checked_roots += 1);
                Ok(Some(root))
            }
            None => {
                let memory = self
                    .budget
                    .reserve_memory(occurrences.len().saturating_mul(128).saturating_add(128))?;
                self.storage
                    .borrow_mut()
                    .roots
                    .insert(occurrences.into_boxed_slice(), RootEntry::Rejected(memory));
                Ok(None)
            }
        }
    }
    fn check_occurrences(
        &self,
        source: PackedProgramRef<'_>,
        occurrences: &[Occurrence],
        memory: crate::budget::MemoryReservation,
    ) -> Result<Option<CheckedProgram>> {
        if occurrences.is_empty() {
            return Ok(None);
        }
        let mut semantic = Vec::<Arc<CheckedOperation>>::with_capacity(occurrences.len());
        let mut local = Vec::<LocalResult>::with_capacity(occurrences.len());
        let mut entities = Vec::new();
        let mut terminal = Operation::FindAll;
        for (index, occurrence) in occurrences.iter().enumerate() {
            let storage = self.storage.borrow();
            let Some(step) = storage.specs[occurrence.spec].step.as_ref() else {
                return Ok(None);
            };
            terminal = step.function;
            let contract = step.function.contract();
            if occurrence.dependencies.len() != contract.dependencies.len()
                || occurrence.dependencies.iter().any(|&d| d >= index)
                || occurrence
                    .dependencies
                    .iter()
                    .zip(&contract.dependencies)
                    .any(|(&d, expected)| semantic[d].output_type != *expected)
            {
                return Ok(None);
            }
            let key = OperationKey {
                spec: occurrence.spec,
                dependencies: occurrence
                    .dependencies
                    .iter()
                    .map(|&d| semantic[d].id)
                    .collect(),
            };
            let operation = if let Some(&id) = storage.operation_keys.get(&key) {
                Arc::clone(&storage.operations[id])
            } else {
                let dependencies = occurrence
                    .dependencies
                    .iter()
                    .map(|&d| semantic[d].lowered.clone())
                    .collect::<Vec<_>>();
                let (node, scalar) = lower_operation(step.function, &step.inputs, &dependencies)?;
                let id = storage.operations.len();
                let lowered = if node.is_some() {
                    Lowered::Entities(id)
                } else {
                    let (output, projection) = scalar.expect("checked lowering");
                    Lowered::Scalar { output, projection }
                };
                let size = match &node {
                    Some(node) => crate::query::encoded_size(node, usize::MAX)?,
                    None => match &lowered {
                        Lowered::Scalar { projection, .. } => {
                            crate::query::encoded_size(projection, usize::MAX)?
                        }
                        _ => 0,
                    },
                };
                let reservation = self
                    .budget
                    .reserve_memory(size.saturating_mul(8).saturating_add(256))?;
                let operation = Arc::new(CheckedOperation {
                    id,
                    output_type: contract.output,
                    lowered,
                    node,
                    _memory: reservation,
                });
                drop(storage);
                let mut storage = self.storage.borrow_mut();
                storage.operation_keys.insert(key, id);
                storage.operations.push(Arc::clone(&operation));
                self.update(|s| s.lowered_operations += 1);
                operation
            };
            let inputs = occurrence
                .dependencies
                .iter()
                .map(|&d| local[d].output())
                .collect::<Vec<_>>();
            let result = if operation.node.is_some() {
                let local_index = entities.len();
                entities.push(EntityOccurrence {
                    operation: Arc::clone(&operation),
                    inputs: inputs.into_boxed_slice(),
                });
                LocalResult::Entity(local_index)
            } else {
                let Lowered::Scalar { projection, .. } = &operation.lowered else {
                    unreachable!("scalar lowering")
                };
                let mut projection = projection.clone();
                match &mut projection {
                    Projection::Relation { target, .. }
                    | Projection::RelationQualifier { target, .. }
                    | Projection::SelectBetween { target, .. } => *target = inputs[1],
                    Projection::Verify { source, .. } => {
                        let LocalResult::Scalar { projection, .. } =
                            &local[occurrence.dependencies[0]]
                        else {
                            unreachable!("value dependency")
                        };
                        *source = Box::new((**projection).clone());
                    }
                    _ => {}
                }
                LocalResult::Scalar {
                    output: inputs[0],
                    projection: Arc::new(projection),
                }
            };
            semantic.push(operation);
            local.push(result);
        }
        let last = local.last().expect("nonempty");
        let root = CheckedProgram {
            terminal,
            source: source.owned(),
            entities,
            output: last.output(),
            projection: match last {
                LocalResult::Entity(_) => Arc::new(Projection::Entities),
                LocalResult::Scalar { projection, .. } => Arc::clone(projection),
            },
            execution: OnceLock::new(),
            syntax: OnceLock::new(),
            _memory: memory,
        };
        root.validate_plan_bytes(&self.limits)?;
        Ok(Some(root))
    }
    pub fn syntax(
        &self,
        root: &CheckedProgram,
    ) -> Result<crate::reader::ReaderShared<grammar::Program>> {
        root.syntax(&self.budget)
    }
}
impl CheckedProgram {
    fn validate_plan_bytes(&self, limits: &Limits) -> Result<()> {
        // Same serialized Plan envelope as the explicit adapter, counted from
        // borrowed occurrence nodes rather than a materialized Vec<Node>.
        let mut bytes = "{\"nodes\":[],\"output\":,\"projection\":}"
            .len()
            .saturating_add(self.output.to_string().len())
            .saturating_add(crate::query::encoded_size(self.projection(), usize::MAX)?);
        for i in 0..self.node_count() {
            bytes = bytes
                .saturating_add(crate::query::encoded_size(
                    self.node(i).as_ref(),
                    usize::MAX,
                )?)
                .saturating_add(usize::from(i != 0));
        }
        fn omitted(p: &Projection) -> usize {
            match p {
                Projection::UniqueAttribute {
                    condition: None, ..
                } => ",\"condition\":null".len(),
                Projection::Relation {
                    direction: None, ..
                }
                | Projection::RelationQualifier {
                    direction: None, ..
                } => ",\"direction\":null".len(),
                Projection::Verify { source, .. } => omitted(source),
                _ => 0,
            }
        }
        if bytes
            > limits
                .materialized_bytes
                .saturating_add(omitted(self.projection()))
        {
            return Err(Error::Limit("encoded bytes"));
        }
        Ok(())
    }
}

#[cfg(test)]
#[path = "packed_program_tests.rs"]
mod tests;
