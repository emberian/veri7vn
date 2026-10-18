# Relation answers and their source scope

This packet makes the store assumption precise and connects it to the new
relation adapter's answer provenance. It does not turn a SQLite fetch into a
verified database, and it does not claim that the linker found every sense.

## Statements

`snapshot_complete_wrt S p c` means
`set (vals p c) = S (qid c) p`: the nonblank values fetched for one entity and
property are exactly the values in the named snapshot after the adapter's
projection. Entity objects are projected to display labels. Two different
entities with the same label therefore need not be distinguished by this model.

`forward_attempt_snapshot` states that a forward attempt returning `(s,p,v)`,
under that equality premise for every candidate, has `S s p = {v}`. For every
linked candidate whose supplied class evidence puts it in the domain, its
snapshot values are a subset of `{v}`. A sense with no stored value is allowed.

`forward_answer_snapshot` lifts this statement to the actual `decide_spec`
consumer when all supplied attempts are forward attempts. The result identifies
an answering attempt and preserves the same singleton and agreement guarantees.

`omitted_snapshot_value_breaks_coverage` states that an omitted snapshot value
falsifies the equality premise. Setting the fetch's `complete` boolean does not
establish that premise. This is a conditional theorem, not an omission detector
executed against the database.

## Consumer

The relation adapter names the actual
immutable store file, its size and modification time, the candidate/property
pairs, the finite linker limit, the inverse-query limit, and whether all
attempts were forward. File metadata is explicitly not a content digest.
Recognition, domain closure, linking, row coverage and source assertions remain
untrusted. The adapter's table comparison and kernel return are actual executed
checks; they do not establish snapshot completeness.

The adapter also fixes cross-reader composition: a decisive decline from one
reader cannot be overridden by an answer from another merely because both name
the same subject and property. Their candidate pools may differ. Mixed outcomes
are kept as ambiguity. The separate adapter report owns its panel measurements.

## Validation status

Fresh hbox proof passed: `20261018T072234Z-f846774201f8`, 53 scanned
statements, no oracles; actual target finished in 8 seconds. Build completion,
uncancelled status and source stability are recorded. The four target inputs
(ROOT, reader theory, tables and export theory) match the receipt snapshot exactly.

The first managed attempt
`20261018T063203Z-6a3cd99b1a5b` was cancelled while queued after an SSH collector
failure; no proof ran. Build owner recovered that result before resubmission.
The first actual proof (`20261018T063626Z-a1d687576b46`) failed on an explicit
head-membership fact and a reserved fact name. The second
(`20261018T071137Z-121be3517bdf`) reached the snapshot subset statement but
automation did not derive nonemptiness of the fetched list from snapshot
membership. Its repair uses explicit empty/nonempty cases and the named coverage
equality, without changing the statement. The final repair is the passed hbox receipt above.
The previous generated decision code has SHA256
`c6ec7792adeb711db6f0b6b4e5b788c3b229a44c6c3124ba65ad8cb3e67462c7`;
the freshly regenerated decision has exactly that hash. No native rebuild was
needed for unchanged generated code, and no new panel score is claimed.

The adapter attaches the theorem declaration only to answered, forward-only
requests. It states the equality premise as assumed, not as an executed check.
Three actual adapter probes verify presence for The Hobbit author, absence for
an inverse actor/spouse answer, and absence for an unknown book. Six existing
cross-reader composition tests also pass. Receipt: `var/symbolic/snapshot-consumer.json`.

## Scope correction

The old eighteen-pattern reader's missing oracle scan was already repaired by
W6-21 (`a6484fa`): eighteen headline statements and eight fixtures are scanned.
Repeating that old backlog item would not add assurance. This packet instead
belongs to the current 161-specialist relation kernel.

Changed files: this report, `src/extract/relations/Relation_Reader.thy`, `src/extract/relations/Relation_Reader_Export.thy`, and
`tools/relations/answerer.py`. New requested-subject work under
`src/extract/relations/request/` and the D report is a separate, unverified packet.
