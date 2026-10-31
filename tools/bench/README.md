# Native foundation measurement

`native_foundation.py` is an untrusted Linux HTTP observer. It starts only the
supplied host binaries, measures fixed `/invoke` requests, samples their process
trees, and terminates/reaps the host PID it started. It never builds or changes
source. Fixture inputs are supplied data, not specialist panels.

Prepare immutable snapshots with `git archive REV native` and a second archive
of `src/extract/discrete-certificate/main.sml` (a compile-time include). Extract
each under its own directory. Build serially, then copy the resulting binary
before compiling the other revision:

```
CARGO_BUILD_JOBS=2 CARGO_TARGET_DIR=/warm/target cargo build --release --manifest-path SNAPSHOT/native/Cargo.toml -p oracle-host --all-features
```

Put copied binaries at `ROOT/pre-host` and `ROOT/foundation-host`, and a real
Linux clingo at `ROOT/clingo`. A supplied reader image is admitted by its SHA256;
state databases are created separately per run. Run in both orders:

```
python3 tools/bench/native_foundation.py --root ROOT --fixtures tools/bench/native_foundation_fixtures.json --image IMAGE --out AB.json
python3 tools/bench/native_foundation.py --root ROOT --fixtures tools/bench/native_foundation_fixtures.json --image IMAGE --reverse --out BA.json
```

Use `--versions foundation,sol` with correspondingly named retained binaries to
compare a later snapshot. Read all outcomes: a quick refusal is not faster
successful computation. Complete normalized replies are retained; the outer
host identity, top-level runtime/resource identities and provider build_us/search_us/check_us/elapsed_us timing fields are excluded from the comparison. Raw replies are retained separately.
Startup means a fresh owned process and warm OS cache, not cache eviction or a
fresh machine. The monitor samples `/proc` with a nominal 2ms wait; scans and
scheduler delays add time and may miss short peaks or solver children. Summed
RSS counts shared pages more than once. PSS and private bytes are separately
reported. Neither is a hard memory bound. Other machine workloads remain a
confounder. Numerical libraries are pinned to one thread via the recorded
OMP/OpenBLAS/MKL/Rayon environment; the science kernel also uses sequential SVD.

`native_foundation_allocations.rs` is a separate Rust executable with a counting
global allocator. Build it against the **foundation snapshot** science path and
the snapshot's Cargo.lock, with serde_json `arbitrary_precision,float_roundtrip`.
Its argument is the same fixture JSON. For small/large integer-valued science
inputs it asserts identical replies, then measures 100 warmed calls per mode.
Both begin with an existing `Value` and end with a `Value`: typed input decoding
and output conversion versus envelope serialization, provider string API and
reply parsing. It includes the common kernel and counts Rust allocation calls
and requested allocation bytes, including realloc's new size. It excludes C
allocators, mappings, live/retained memory, the host's admission/checking and
HTTP. Its measurements cannot be substituted for end-to-end host measurements.

The smaller `native_foundation_memory_fixtures.json` adds a deterministic
1,024-fact actual-solver case. Use it with `--repeats 20 --skip-concurrency`
for the separate tree-memory probe. Keep this cohort distinct from reader-inclusive
steady RSS; its lower peak does not replace the larger workload's peak.
