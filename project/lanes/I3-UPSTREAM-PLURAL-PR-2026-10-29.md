# I3-UPSTREAM-PLURAL-PR: plural-first patch posted upstream

Owner: lane I3-UPSTREAM-PLURAL-PR. Consumer: root. No specialist panels run; no panel numbers.

## Posted

[Upstream PR 10](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/10), "Prefer canonical concept plurals over learned aliases in Reader7.align". PR commit `9aaea6d55c2932c24ffab268cfa587db4ef5866b`, base `c473d28914e480425adb29b4f7f42485b8cfb4e3`. It is open; no acceptance is claimed. Mechanism as for PRs 8 and 9: `huggingface_hub` `create_commit(create_pr=True, parent_commit=<base>)` from the hf CLI's Python (`/opt/homebrew/Cellar/hf/1.29.0/libexec/bin/python`), script `var/i3-upstream-pr/post.py`, receipt `var/i3-upstream-pr/published-pr.json`. Discussion 5 and all other threads were not edited.

Files in the PR: `workbench/swarm/reader_v7.py` (patched) and `tests/reader/test_canonical_plural_first.py`. Upstream's swarm directory has no tests directory, and PRs 8 and 9 put tests under `tests/<topic>/`, so the tests are in `tests/reader/`. The one change to the test file from `tools/reader_audit/`: with no `--source-dir` it defaults to the repository's `workbench/swarm` (so `python3 -B tests/reader/test_canonical_plural_first.py` works from the root). Its SHA-256 differs from the frozen `269a27c8...` for that reason.

## Checks before posting

* Fresh `main` of the upstream repo: commit `c473d28914e480425adb29b4f7f42485b8cfb4e3`; `workbench/swarm/reader_v7.py` SHA-256 `f37f687e8190f08ff862738543790d6bcd56185a1a807ffdbd5cf8340da85354` (matches the pin).
* Open discussions listed: 1 to 9 (PRs 1, 2, 8, 9; issues 3 to 7). None on this topic.
* Patch applied to a snapshot of the 67 `workbench/swarm` files; patched `reader_v7.py` SHA-256 `03e43e4e742b1bc6093fb67d00425ab47b679278fe1519b799b8cab91b90e57f`.
* Tests with `/Users/ember/dev/o7vn/.venv/bin/python -I -B`: patched tree 8 pass (both default and explicit `--source-dir`); unpatched snapshot 2 fail (`test_count_cue_not_consumed_by_album_alias`, `test_exact_two_training_examples_no_longer_replicate_wrong_outer`), 6 pass.
* Uploaded files re-fetched from `refs/pr/10`: `reader_v7.py` `03e43e4e742b1bc6093fb67d00425ab47b679278fe1519b799b8cab91b90e57f` and the test file `e321631f046d49c1798f1612e721e2588134bc93df53e93fdf527868e41039ee`, both equal to the local copies.

## Notes

A blobless sparse git clone of the HF repo failed to fetch blobs ("expected 'packfile'"), so no git working copy was used; a `snapshot_download` of `workbench/swarm/*.py` at the base commit served as the checkout. Work files are in `var/i3-upstream-pr/` (`tree` unpatched, `patched`, `description.md`, `post.py`, `published-pr.json`, `verify`).

## What remains

Upstream review. Re-export of the learned tables with the patched source (their pipeline), `Reader6.learn6` alignment, and our own retrain and 16-case cohort stay as listed in the S2-PLURAL-FIRST note. The PR description says all of this.
