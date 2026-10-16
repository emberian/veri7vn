# Protected relation-language bridge

`Veri7vn_Natural_Relation_Gate` joins the fixed whole-question reader to the
existing `Veri7vn_Row_Instance` relation recipe. The bridge is an internal native
owner API, not a public authority supplied by source IDs.

Both utterance and versioned declaration must be actual protected inputs owned by
managed provenance in the same workspace. Equal bytes in another input do not
satisfy ownership. Declaration bytes are the canonical native term serialization
of a closed `relation_language_declaration`, including the fixed native reader revision `v1` and a nonempty alias
revision. A caller cannot relabel the fixed reader with another revision. This is authored semantic data; it does not establish source truth.

`bind_declaration` binds the actual source owner and original bytes to one parent
recipe and an opaque `Veri7vn_Managed_Native_Unit` occurrence token. The handle is
required by inspection and selection. `release_declaration` retires this token;
RI checks it on all query uses. A second declaration handle over the same physical
input remains usable, so occurrence retirement does not invalidate shared bytes.
Raw `P.source_owner` has no revocation bit and is not used as one.

`inspect` returns `Unrecognized`, `Input_Budget`, or the complete list of
alternative indices. It shares the fixed reader with `select`; ambiguity is not
silently ranked. It creates no query recipe.

The captured native theory evaluates `interpret_relation_question` with
proof-producing `Code_Simp.dynamic_conv` under a five-second bound. The selected
alternative's `question_request` is passed directly to `RI.elaborate_relation`;
the returned recipe's exact `RI.relation_metadata` must equal that selected
request. `RI.restrict_relation_inputs` adds monotone literal lifecycle dependencies to
the opaque query, paired with the actual managed source owners. Acquisition
requires those owners in its confirmed input support; association liveness
rechecks support after any later restriction. Charged worker tickets must retain
the acquired input support, workspace and semantic generation. All relation
recipe access, reservation transfer, execution and
retained-result checks use them, including previously extracted query handles. Occurrence-unit restrictions are monotone too.
The returned opaque reading retains the proof, original-byte entity
slice, protected owners and independent input leases. Access checks both input
lifetimes and the parent recipe. Release is idempotent, retires the selected relation recipe and drops these
leases. Source reservations also check relation-recipe liveness, preventing
retained associations or results from surviving that retirement. A declaration invalidation prevents further recipe access.

The logical `owned_relation_reading` predicate alone remains insufficient for
physical owner assurance: its occurrence IDs are logical labels. The native
bridge performs the actual identity and byte checks instead of treating those
IDs as capability authority.

Current verification target is `Veri7vn_Natural_Relation_Gate_Tests`, including
wrong-owner equal bytes, the actual v1 Q170583/P50 label, exact source span and
invalidation. This target is pending native compilation. The composed target `Veri7vn_Source_Relation_Language_Consumer_Tests` additionally
uses the actual acquired fixture and private operation ticket, then retires
one declaration occurrence while another declaration handle and physical consumer
lease remain valid over the same input. It checks that
escaped query reservation, execution and retained result paths deny access while
the acquired source remains live. This target is also pending compilation. Joining the
reading, actual acquired source and same licensed rendering in the resident
service is outstanding. Finite snapshot absence never means world absence;
missing historical v2 source parity remains unclaimed.

## D48 versioned acquisition migration

The source kernel now dispatches the declared `required_recipe` through
`acquire_native_versioned`: compact `source-row-codec/1`, framed
`source-row-codec/2`, or explicit refusal. The compact branch retains
`snapshot_wellformed` and exact `encode_wire batch = original_bytes`. The framed
branch uses `source_stream_represents` over the independent recursive stream
specification, including original bytes, EOF/footer, row count/order and data
shape. It does not equate captured stream bytes with a compact reencoding.

The runtime acquisition entry, pipeline/operation/component refinement, relation
acquisition refinement, and admission count/relation judgments migrated together
to `versioned_source_represents`. The admitted codec contract combines the
existing compact roundtrip with the stream accumulator-to-specification
refinement. The kernel artifact revision is `veri7vn.qualified-row-kernel/2`.
The authored kernel test fixture's former `row-wire/1` label is migrated to the
canonical compact recipe. Unknown decoder recipes now reject explicitly.

This is staged implementation, pending the steward's updated Source_Stream and
source-kernel consumer checks. A full external framed-wire grammar/roundtrip,
world adoption, and missing original v2 data parity are not established by this
representation migration. The original retained SQLite v1 selected-row fixture
will consume the actual captured framed bytes through this same acquisition
path; its fixture, manifest and native caller are owned by the importer and
facts/relations family lanes.
