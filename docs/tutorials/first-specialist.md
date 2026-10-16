# Import, inspect and revise your first specialist

For the packaged source interface, start with the [installed workshop](installed-source-workshop.md).
This companion imports original Oracle7 source through that same installed launcher.

This tutorial starts with the original Oracle7 paint specialist, then opens an
editable native candidate. The current result is a retained source revision;
turning that revision into an admitted deployed capability still needs the native
build/admission work described below. See the [rehearsal record](../handoff/recipient-rehearsal.md)
for what has actually been exercised.

The original fixture lives in the ignored `upstream/` checkout and is absent from
a fresh veri7vn clone. Obtain the pinned Oracle7 source checkout before the paint
steps (this downloads source from its original public repository):

```sh
GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/psiloceyeben/oracle7 upstream
git -C upstream checkout c5d6a29d5bc5e2525078e5a53afa1abf659e4d69
```

Use an existing checkout only after checking its revision and local changes; do
not overwrite it. The paint example consists of small source/JSON files and needs
no large corpus download, unpacking or Python execution. `tools/unpack.py` is a
separate large-store verification utility, not a prerequisite for this tutorial.
The recognized `organ_paint_coverage.py` SHA256 is
`35ca95a96df508b215eab49a74b0350d1cb8d7b4f2606c58ada81dcaf016609c`.
If acquisition is unavailable, the native identity steps remain usable, but they
do not satisfy the original-specialist rehearsal requirement.

Use `V7_COMMAND` and `V7_STATE` from the installed workshop. Set `V7_ORIGINAL`
to the physical absolute path of the downloaded paint example directory. Source
imports reject symbolic links in that path or its ancestors.

```sh
V7_ORIGINAL=/absolute/path/to/upstream/workbench/examples/paint-coverage
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-original paint "$V7_ORIGINAL" tutorial-paint-import-1
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- list
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- inspect paint
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- migration paint
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- source paint organ_paint_coverage.py
```

Keep the source revision and edit token printed by `inspect`. These identify the
exact imported source, rather than certifying its behavior. `migration` reports
what the importer recognizes and the remaining work. For paint, recognizing a
scalar formula leaves parser, units, rounding, domain, native execution and
evaluation obligations. The historical eighteen panel cases remain attributed
examples; they do not become fresh private tests by being imported. Importing
Python source does not execute it.

Now locate and import the bundled zero-export native identity candidate. If you
already imported `identity` in this workspace, inspect it rather than importing again:

```sh
V7_IDENTITY=$("$V7_COMMAND" locate --tutorial retained-identity)
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-native identity "$V7_IDENTITY" tutorial-identity-import-1
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- inspect identity
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- serve
```

Open the printed loopback URL. Inspect `identity`, open `Retained_Identity.thy`,
and read `OBLIGATIONS.md` before changing source. Add a harmless explanatory comment
in the theory editor and Save. Save a second comment to check that editing continues
from the new revision. The source is canonical: preserve expert proof blocks unless
you intend to revise them. A conflict means another revision won; retain your
proposed text, reopen the current file and reconcile it before saving again.

Press Enter in the launching terminal to close the browser workspace. Then run
`inspect identity` and `source identity Retained_Identity.thy` with the same launcher
and workspace. Check that the revision changed and the comments survived reopening.
Only one writer can own this workspace: close `serve` before opening a separate
CLI process against it.

The identity candidate proposes `Parameter 0`, with zero→zero and one→one examples.
The universal identity obligation, empirical qualification and active publication
are distinct. It uses the existing mathematical operation language, so candidate
reuse should not require compiling a new bundle. New carriers, kernels or code
setup do require a new qualified executable bundle.

Continue to the [current operation reference](../reference/recipient-operations.md)
for resident execution, request inspection and recovery. There is currently no
complete recipient command sequence from this edited draft through build,
diagnosis, admission, profile/refinement, package export and deployed activation.
Those are product requirements, not steps to replace with an implementer manually
loading the theory or a successful source import.
