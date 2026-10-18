# veri7vn specialists for Oracle7

Package date @DATE@. Built from veri7vn commit `@COMMIT@`. @NFOLDERS@ specialist folders in @NFAMILIES@ families.

## What this is

Every folder here, `<id>-veri7vn`, is one of your own specialists. It answers the
questions your `<id>` specialist answers, with the same panel and the same scorer
(copies of yours, see `NOTICE`). The difference is who does the work. Your organ is
Python. Here the organ is a small wrapper that hands each question to a stand-alone
program, and that program was produced from a model written and proved in Isabelle/HOL
(the proof assistant), then compiled to a native binary. Nothing of Isabelle runs when
a question is asked. One program serves a whole family (for example the `quantity`
program serves `densities`, `units`, `units-v3`, `springs`, `fluids` and `fuels`), so
the programs live once, here, in `_veri7vn/bin/`, and not in every folder.

## Install

    tar -xzf veri7vn-specialists-@DATE@.tar.gz -C /path/to/oracle7/root

That creates `root/specialists/_veri7vn/` and the `<id>-veri7vn` folders beside your
own. (`_veri7vn` has no `manifest.json`, so it is not a specialist, like your `_gate`
and `_cards`.) Nothing in your install is changed.

Two programs per family are included, `bin/darwin-arm64/` (Apple Silicon) and
`bin/linux-x86_64/`. They need the GMP library, which is not in the package:
`brew install gmp` on macOS (the macOS programs look for it under
`/opt/homebrew/opt/gmp`), `apt install libgmp10` on Linux. Anything else
(Intel Macs, ARM Linux) has no program yet.

Try it without the head, with only Python 3:

    python3 -B root/specialists/_veri7vn/smoke.py
    python3 -B root/specialists/_veri7vn/smoke.py --ids acoustics,units,git

`smoke.py` loads each folder the way your `workbench/exam.py` does, asks every question
of its panel (dev and held-out), scores the answers with your scorer and prints
right / wrong / false yes per folder. It does not run the head and records nothing.
`SHA256SUMS` lists every file (check with `cd root && sha256sum -c specialists/_veri7vn/SHA256SUMS`, or `shasum -a 256 -c` on macOS); `MANIFEST.json` and `receipts/<family>.json` say which
Isabelle session each program came from (below).

Where a folder looks for its program: `$VERI7VN_<FAMILY>_BIN` if set, else
`<folder>/bin/<family>`, else `specialists/_veri7vn/bin/<os>-<arch>/<family>`.
To remove everything, delete `_veri7vn` and the `*-veri7vn` folders.

## What is proved, and what is not

Proved in Isabelle/HOL, for every family: what each formula states (the stated value
satisfies the defining equation: mass is density times volume, a conversion composes,
and so on); exactly when the program declines (a missing amount, a unit mismatch, an
impossible input); that the answer is a function of the question; and the rounding rule
(exact decimal ties round up, with a bound on the rounding). The numbers in the tables
(unit factors, densities, constants) are copied from your organs and compared with
them by a script; that is a check, not a proof. Facts-style specialists prove less than
formula ones: for those the proved part is the lookup and the decline rules over the
stored rows. Each family's own README in veri7vn says exactly which theorems it has.

Not proved: **the recognizer**, the part that reads English (found numbers, units and
words in the question and picks the request). It is hand-ported from your organs'
regular expressions into Standard ML and is untrusted. **The wrapper** in each folder
(Python) and the program's JSON framing are untrusted too. The Isabelle code generator
and the MLton compiler are trusted. So the honest claim is: given the request the
recognizer builds, the value or decline is proved correct. Whether the recognizer
builds the right request is measured on your panels, not proved.

Measured: on your shipped panels, both splits, each family's program gives the same
counts as that family's own lane; the Linux and macOS programs gave identical replies
where both were compared. Receipts: the macOS programs name the Isabelle session check
(`session_receipt_macos`, with whether the theory files have changed since); the Linux
programs name the fresh build of the same session on a Linux host
(`session_receipt`), and the Linux and macOS kernels were generated from byte-identical
SML (`generated_sml_sha256`). For `acoustics`, `quantity` and `variants` the older
macOS session check predates a refactor onto shared numeric code (its `theory_files_changed_since` lists the
files); their macOS programs were compiled from the SML of the fresh Linux session build instead.

Not in this package: `earth` and `finance` (not committed yet), `stores` (cooking and
warehouse: its program needs veri7vn's checkout and a Python fetcher; it can be made
relocatable but is not yet). We have not run your head with these folders installed.

## What your `exam.py` will say, and why

Run on the dev panel behind the w540 head, as `exam.py` composes it (the head answers
first, the specialist only when the head declines in a way a specialist may fill), the
verdict is WOULD FAIL for every one of these folders. We measured five:

| Folder | Panel | Verdict reasons | Head alone right / false yes / wrong | With the folder |
|---|---|---|---|---|
| acoustics | 70 | DOMAIN: gain 1, needs 3 | 46 / 0 / 0 | 47 / 0 / 0 |
| units | 76 | WRONG: 14 answered wrong, cap 1 | 39 / 0 / 14 | 61 / 0 / 14 |
| git | 10 | DOMAIN: gain 0, needs 3; WRONG: 7, cap 1 | 3 / 0 / 7 | 3 / 0 / 7 |
| orbits | 35 | WRONG: 16 answered wrong, cap 1 | 1 / 2 / 16 | 10 / 2 / 16 |
| law | 9 | DOMAIN: gain 1, needs 3; WRONG: 2, cap 1 | 6 / 0 / 2 | 7 / 0 / 2 |

Two reasons, and neither is about the folder:

1. Your head at w540 already holds the original specialist (the standing nets call
   `combo_runtime_v1` families). A copy behind it is asked only about what the head
   left, so it has almost nothing to add: gain is starved.
2. The composite keeps every answer the head gave, and `exam.py` counts the
   composite's wrong answers against the cap. In every row above the folder adds no
   wrong answer and no false yes; all of the wrong ones are the head's own (the folder's
   right-answer column rises, its wrong column does not). For example, 11 of the 12
   visible units fails are your head's own right number in fraction form ("250 cm is
   12500/127 inches"), which the shipped units scorer reads as 12500. git and orbits
   fails are the head answering an adjacent fact ("Git! is a 1965 American drama film").

Put in front of the head instead (specialist first, then the head, which is how the
release composes), the same folders on your dev and held-out panels, measured with our
parity harness:

| Folder | Split | n | Head alone ok / false yes / wrong | With the folder in front |
|---|---|---|---|---|
| acoustics | dev | 70 | 46 / 0 / 0 | 70 / 0 / 0 |
| acoustics | heldout | 69 | 62 / 2 / 0 | 68 / 1 / 0 |
| units | dev | 76 | 39 / 0 / 14 | 76 / 0 / 0 |
| units | heldout | 76 | 43 / 0 / 29 | 76 / 0 / 0 |
| git | dev | 10 | 3 / 0 / 7 | 10 / 0 / 0 |
| git | heldout | 10 | 6 / 0 / 2 | 7 / 0 / 1 |
| orbits | dev | 35 | 1 / 2 / 16 | 35 / 0 / 0 |
| orbits | heldout | 35 | 3 / 1 / 23 | 35 / 0 / 0 |
| law | dev | 9 | 6 / 0 / 2 | 9 / 0 / 0 |
| law | heldout | 9 | 7 / 0 / 0 | 9 / 0 / 0 |

(Wrong here means wrong by your shipped scorer. git's one held-out wrong is "what
command brings back the stash in git?" answered `git stash`; your own git organ gives
the same text. acoustics' one held-out false yes is your `optics-v5` answering a
supersonic question that our folder correctly declined.) Those runs used a head built
from your w540 tip in our checkout; they are not re-run for this package, and only
these five folders have them so far; the board for all folders is a later piece of work.

One more thing, in your code and only noted: `exam.py` prints each failed item as
`expected: (decline)` for every item, because it reads `it.get("a")` and the shipped
panels key the answer as `expect`. It is display only (the verdict does not use it) but
it makes the fail lists misleading to read. We have not changed it.

## Questions

https://ember.software
