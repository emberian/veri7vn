//! Empty-stage obligations for explicit supplied-record counts.
//! This is an untrusted admission policy, not source-completeness evidence.
use crate::query::{CheckedPlanView, Node, Projection};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum EmptyPolicy {
    Existing,
    SnapshotCount,
    SnapshotFragment,
    Strict,
}

/// One obligation per original occurrence, including dead stages. Only the
/// actual Count projection authorizes snapshot emptiness in a complete reading.
/// Fragment staging may defer live emptiness to that complete reading; omitted
/// children are independently checked with Strict before composition.
pub(crate) fn refusals(plan: &dyn CheckedPlanView, policy: EmptyPolicy) -> Vec<bool> {
    let count = matches!(plan.projection(), Projection::Count);
    if policy == EmptyPolicy::Existing {
        return vec![!count; plan.node_count()];
    }
    if policy == EmptyPolicy::Strict || (policy == EmptyPolicy::SnapshotCount && !count) {
        return vec![true; plan.node_count()];
    }
    let mut live = vec![false; plan.node_count()];
    live[plan.output()] = true;
    for index in (0..plan.node_count()).rev() {
        if !live[index] {
            continue;
        }
        if let Some(stage) = plan.checked_stage(index) {
            for &dependency in stage.dependencies {
                live[dependency] = true;
            }
        } else {
            match plan.node(index).as_ref() {
                Node::Relate { input, .. }
                | Node::FilterConcept { input, .. }
                | Node::FilterAttribute { input, .. }
                | Node::FilterQualifier { input, .. } => live[*input] = true,
                Node::And { left, right } | Node::Or { left, right } => {
                    live[*left] = true;
                    live[*right] = true;
                }
                Node::Find { .. } | Node::Id { .. } | Node::All | Node::Previous => {}
            }
        }
    }
    live.into_iter().map(|is_live| !is_live).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::Plan;

    #[test]
    fn snapshot_obligations_follow_output_ancestry_and_actual_count() {
        let mut plan = Plan {
            nodes: vec![
                Node::All,
                Node::Find {
                    name: "missing".into(),
                },
                Node::Find {
                    name: "Germany".into(),
                },
                Node::Or { left: 1, right: 2 },
            ],
            output: 3,
            projection: Projection::Count,
        };
        assert_eq!(refusals(&plan, EmptyPolicy::Existing), vec![false; 4]);
        assert_eq!(
            refusals(&plan, EmptyPolicy::SnapshotCount),
            [true, false, false, false]
        );
        assert_eq!(refusals(&plan, EmptyPolicy::Strict), vec![true; 4]);
        plan.projection = Projection::Names;
        assert_eq!(refusals(&plan, EmptyPolicy::SnapshotCount), vec![true; 4]);
        assert_eq!(
            refusals(&plan, EmptyPolicy::SnapshotFragment),
            [true, false, false, false]
        );
        assert_eq!(refusals(&plan, EmptyPolicy::Existing), vec![true; 4]);
    }
}
