# Context from final answers

The dispatcher keeps a separate in-memory ledger for each session in its own
process. It records the user's question, the standalone question actually used,
and the final reply after guards and any selected warehouse commit. A new
connection starts with no history. A refusal or an answer without supported
structured context clears the reusable subject/value, so an unrelated turn
cannot silently resurrect an old referent. Literal recall does not change that
context.

A successful committed warehouse receipt can preserve an opaque native context
owner for finite inventory/location follow-ups. It must match the actual CLI
pin and session. No item name or global entity ID is inferred. Preview replies,
failed commits, other sessions/pins, and stale final history cannot authorize
this delegation.

Query entities and answer entities are separate. The relation adapter must
supply an explicit entity ID and source-derived type; the dialogue adapter does
not infer identities from answer text or link a popular matching name. A person
pronoun with two different possible people asks for a name, including an
unknown-typed competing entity. Ordinary `it` prefers the prior query thing;
an unknown query entity cannot silently yield to a known answer thing.
`That thing` uses the answer thing. A country or city reference additionally
requires an explicitly supplied matching entity domain; a generic thing is
insufficient. Missing source facts remain refusals after a successful
reference resolution.

Numeric context comes from exact structured Fusion output, or a solved-variable
Math receipt. It does not mean the first number in the answer. The finite reader
supports result conversion, result cost, and the square/cube of a solved
variable. Predicate ellipsis and swapping a named subject use the previous
relation slot. These English readings are untrusted and deliberately bounded.

A turn first selects its question. A complete finite follow-up uses the prior
accepted receipt and the typed resolver; ambiguity or missing context asks for
clarification. An explicit title such as `It`, or a quoted title, keeps its
ordinary reading. An incidental pronoun inside a self-contained question does
not trigger rewriting. Only one selected question reaches the routes, and its
answer, captured refusal, or failure is final. There is no literal-question
retry after a contextual refusal. Evaluation uses warehouse preview children;
only the selected guarded result can reach the private committing child, once.
The ledger is appended only afterward, including a failed commit's actual
uncertain result. Neither a preview nor a failed result creates a grounded fact.

Recall quotes stored text and identifies the source turn/status/path. Calling it
"the last fact" does not convert that text into a new truth claim. Incoming JSON
cannot supply context identities: the dispatcher creates a bound relation hint
only from a stored final receipt and the relation adapter must match its exact
rewritten slot.

The small `Converse` HOL kernel resolves typed references and requires a
resolved slot before selecting a contextual question. Its laws require no
English oracle, but assume supplied IDs, types, and completeness of the
recognized follow-up. Older result-selection protocol laws remain available;
the dispatcher now uses question selection before evaluation. List laws describe one final ledger append
and other-session preservation; they do not prove Python dictionaries or the
warehouse filesystem. Focused integration tests exercise those boundaries.

`--no-dialogue` disables history and follow-ups. When the registry enables the
stage, `var/converse/bin/converse` is required; a missing executable is a startup
error. Build its standalone proof with the managed build driver, then run
`src/extract/converse/build.sh RECEIPT` to compile that exact successful export.
No specialist-panel score is claimed by this component.
