# Open-world identity experiment

Run from the repository root:

```sh
python3 -B tools/usage/relation-literature/test_possible_identity.py
```

This is an untrusted, finite executable specification. It changes no runtime or
theory. The proposed rule returns a canonical entity ID only when exactly one
candidate is positively eligible, every other candidate is positively excluded,
and the candidate universe is covered for the claim's stated scope. Missing
facts remain unknown. Explicit negative evidence or a justified local closure
premise can establish exclusion; a different positive value cannot do so by
itself.

The exhaustive check compares the rule with every completion of missing facts
for all 1,093 three-valued assignments over zero through six candidate IDs.
Seven checks exercise the model; an eighth reuses the relation semantic review's
fixture and calls the existing native binary. The native check is skipped if
the binary is absent. On 27 October it ran and reproduced an answer that becomes
ambiguous after adding a compatible fact. The proposed rule withholds in both
states.

`universe_complete=True` is an explicit experimental premise. It can describe a
covered finite snapshot query. It does not establish complete real-world
knowledge or exhaustive name linking. There is no database or linker closure
inference here. No specialist panels ran and no runtime gain is claimed.

Sources, hashes, search receipts and reading depth:
[/Users/ember/paperbin/oracle7-20261027/relations/README.md](/Users/ember/paperbin/oracle7-20261027/relations/README.md).
The implementation proposals are in
[the literature lane report](/Users/ember/dev/o7vn/project/lanes/LITERATURE-RELATIONS-2026-10-27.md).
