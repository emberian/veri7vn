# Relation consumer audit, 27 October

No shipped specialist panels were run. These checks are source-reader checks,
not a new panel score or proof that the full Engine returns either reply.

The U5-v2 appliance's `root/wander-train/relation_spec_v1.py` and the mutable
`var/ap1-upstream-slim` copy were byte-identical when checked. Its untrusted
composer parser recognizes “the film”, strips it for title lookup, and then
checks work types by searching the *whole* question for kind words. This lets a
word in a title admit another domain. With the actual U5-v2 store, the question
“Who composed the film The Song Remains the Same?” produced P86 answers from
both the film Q510381 (Led Zeppelin) and the song Q152753 (Jimmy Page). The
requested film cannot be satisfied by the song reader.

A second bounded example uses two same-domain candidates: the first has a 1977
publication date and one composer, and the second has no publication date and
a different composer. Before the patch the reader removes the undated candidate
and answers from the first. An absent date does not establish that the second
candidate is from a different year, so the correct result is to withhold.

`tools/usage/relation-audit-consumers/composer-guard.patch` is a source patch
against that appliance source, not an installed change. It binds the explicit
film qualifier to the films domain and withholds a year-qualified answer when
an eligible candidate lacks a parseable date. It retains candidates with the
requested year and may exclude candidates with only parseable different years.
This is still an untrusted recognizer and assumes the finite linker, domain
membership and source dates are adequate. It does not establish identity or
source completeness, or that P577 alone captures every release.

Reproduction and checks:

- `RELATION_SOURCE=var/ap1-upstream-slim/root/wander-train/relation_spec_v1.py python3 -B -m unittest discover -s tools/usage/relation-audit-consumers -p 'test*.py' -v`: four fixtures, two failures before the patch, exactly the two issues above; the two controls passed.
- `python3 -B -m unittest discover -s tools/usage/relation-audit-consumers -p 'test*.py' -v`: 4/4 pass after applying the patch to a temporary source copy.
- `ORACLE7_ROOT=$PWD/var/usage-20261027/candidate-u5-v2/root .venv/bin/python -B tools/usage/relation-audit-consumers/check_live.py`: actual store reproduced both P86 outputs before; after, film output unchanged and song reader returned None.
- The older `tests/usage/research/test_relation_semantics.py` fixture has an obsolete two-argument `_show` and lacks `DATE` for the current source. Running it against the patched copy produced seven errors, not a meaningful regression receipt. It needs updating before reuse.

Consumer integration remains: root must apply the patch to an appliance overlay,
update the older fixture, check actual Engine arbitration and relevant shipped
panels, and establish whether other explicit kinds and title words need the same
treatment. This patch does not repair the general `kind_conflict` behavior for
non-composer relations. Equal projected labels can still hide distinct value
identities; forward source/row coverage and linker limits remain assumptions.
