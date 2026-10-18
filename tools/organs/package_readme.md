# veri7vn specialists for Oracle7

Package date @DATE@. Source checkout commit `@COMMIT@`. @NFOLDERS@ specialist
folders in @NFAMILIES@ families. `MANIFEST.json` lists the included platforms,
excluded families and exact binary hashes. A source checkout commit does not
by itself establish which sources produced a binary.

Each `<id>-veri7vn` folder wraps one family program. Its panel and scorer are
copies of the original specialist's, and its acceptance rule includes reviewed
extensions for new answer kinds. The family program contains code extracted
from Isabelle/HOL and compiled to native code; Isabelle does not run when a
question is asked. One binary serves all the specialists in its family.

## Install and try

    tar -xzf veri7vn-specialists-@DATE@.tar.gz -C /path/to/oracle7/root
    python3 -B root/specialists/_veri7vn/smoke.py --ids acoustics,units,git

Choose IDs present in this package. The archive adds `_veri7vn` and specialist
folders beside the originals. Check for existing folders before extracting;
extracting over an earlier package replaces its files.

The programs need GMP: `brew install gmp` on Apple Silicon macOS, or
`apt install libgmp10` on Debian/Ubuntu Linux. Available platform directories
are under `_veri7vn/bin/`; other platforms are unsupported. The Linux build's
library requirements are recorded where available; compatibility with older
glibc releases has not been established.

`smoke.py` applies the manifest's acceptance rule, then uses each copied scorer
to count right / wrong / false yes on both panel splits. It runs no head and
records no admission exam. Right includes correct declines. Use `--dump FILE`
to save results and `--compare FILE` to require the same folders, splits and
(status, response) replies as another run. Counts are measured results, not
proofs of English understanding.

`SHA256SUMS` covers the package files. Check from the extraction root with:

    shasum -a 256 -c specialists/_veri7vn/SHA256SUMS

The wrapper finds its program using `$VERI7VN_<FAMILY>_BIN`, a `bin/<family>`
beside the wrapper, or `_veri7vn/bin/<os>-<arch>/<family>`. A checkout-local
fallback is available for development. Smoke rejects a packaged run that uses
an outside binary unless explicitly allowed for diagnosis.

If stores is included, `_veri7vn/stores/` contains its untrusted Python fetcher
and copies of the nutrition and warehouse databases. SQLite files are opened
read-only. Warehouse wrappers also default to `--preview`: speculative host
calls cannot create proposals or log orders. Recognized create/confirm/cancel
requests return a truthful refusal (`effects_disabled`), rather than claiming
an action happened. Read-only queries remain available. Preview does not save
conversation references, so context-dependent followups can decline.

A custom **sequential, single-owner host** may construct a warehouse wrapper
with `allow_effects=True`. It must select the owner before calling, never call
it for arbitration/counterfactual/segmentation probes, and never automatically
replay an uncertain request. This opt-in logs requests in the wrapper's private
temporary state file, removed on `close()`; it is not a durable inventory
service. Do not enable it in unmodified Oracle7 Combo, which probes and reasks
organs before choosing. The veri7vn dispatcher's own commit hook is a separate
consumer and does not protect external Oracle7 installations.

## What the evidence means

The Isabelle theories prove specified relationships about typed requests,
values and declines. The guarantees differ by family; the source family
README gives the statements and assumptions. Database answers depend on the
source rows and on coverage assumptions where absence or completeness matters.
The package does not establish the truth of outside facts or database contents.

English recognition, Python wrappers, JSON framing, acceptance declarations,
the Isabelle code generator and the native compiler are outside those proofs.
A reply's provenance names its kernel and declared theorems; it is not an
independently checked proof certificate for that individual answer. For the
supported discount-and-tax computation packet, the shared Python consumer
recomputes exact arithmetic, checks the domain and rounding, and checks that
the final stated amount matches. A mismatch becomes a decisive refusal. This
checker is untrusted corroboration; it does not check English recognition.

`receipts/<family>.json` records binary hashes, the packaging-time source
snapshot, historical native session checks and Linux receipts whose binary
hash matches the copied artifact. Read each receipt's original commit, note
and result: a matching old receipt is not a fresh build of current sources.
Missing receipts remain missing. Generated-SML comparisons concern exported
files, and alone do not bind a binary to them. No panel or cross-platform
success is inferred merely by creating this archive.

The wrapper preserves an in-domain decline when the binary reports it took
the question. The copied acceptance rule still determines whether Oracle7
uses that reply. Head composition is a separate check: a head may answer after
a specialist declines, and its answers can introduce errors. Historical
head-first admission and front-composition results are described in veri7vn's
`project/lanes/W5-11-front-board.md`; they are not fresh package results.
