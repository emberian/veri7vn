# Actual retained v1 source consumer

The available retained original is `upstream/root/relstore/relations_v1.sqlite3`.
`veri7vn.sources.RetainedV1Tests` uses the shared read-only SQLite observer to
select `fact WHERE s=170583 AND p=50 ORDER BY s,p,o,lit`, preserving its original
source-row/2 byte stream and shared metadata. The expected selected result is
Q170583/P50/Q36322. The current entity table labels those IDs Pride and Prejudice
and Jane Austen. No deployed v2 snapshot is available.

The producer writes its two transient files into
`tests/families/relations/native` when that directory is supplied as argv[0].
The build steward runs the producer and native consumer; family agents do not
launch independent Scala/Isabelle builds.

`Retained_V1_Relation_Consumer_Tests.thy` consumes those original files directly:
exact versioned source requirement; retained utterance and original entity span;
versioned native label declaration; same opaque relation recipe; private charged
operation ticket; native worker; typed Q36322 result; missing-language-dependency
rejection; independent occurrence release; sibling preservation; late-result denial.
It does not convert a source-row/2 stream into invented original source-row/1 bytes.

This is a native test-image caller, pending source-row/2 gate integration and first
compilation. It does not claim resident Owner deployment or licensed public emission.
The declaration is an explicit narrow fixture, not a complete label index, domain
membership proof or full original-reader migration. Acquisition time, provenance
and license of the upstream source remain unknown; the artificial local fixture
receipt is explicitly identified. Completeness is only the selected SQLite query
result, never the complete source corpus or world.

The existing direct query kernel distinguishes absence, uniqueness, multiple values,
entity ambiguity, incomplete snapshot, failed guard and unavailable source.
`Relation_Join` additionally characterizes two-edge joins by independent row-path
semantics over one finite population. This is a family kernel, not a registered
service operation. Native checks are pending. Full reader precedence, convergent
entity candidates, inverse limit-eight boundaries, domain/role evidence, missing
store behavior, scoped rendering, deployed lifecycle and source-scale measurements
remain acceptance obligations.
