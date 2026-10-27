# Oracle startup experiment

These tools measure a copied appliance adapter on the designated Linux build
host. They are not part of the deployed adapter, and make no theorem, specialist
panel, tenant-isolation or Mini admission claim.

`instrument.py` creates a new scratch copy of an adapter and inserts wall time,
process CPU, faults, memory and I/O measurements at startup boundaries. It also
counts Python compile calls and time. The `source_bytes` field counts bytes for
byte inputs and characters for string inputs; it is not an exact source byte
inventory. `--detailed` times catalog construction and its nested stages; nested
times overlap and must not be added together.

`--lazy-operations --detailed` is an experimental behavior change: it defers
catalog construction until the first discovery or direct invocation. Query
dispatch still calls the real Engine. Capabilities explicitly returns unknown
counts and a prototype note, even after initialization. This is not a finished
capabilities protocol or production patch.

`run.py` leases one of the designated host Engine slots, runs the copied adapter
inside read-only runtime/data mounts, measures a real arithmetic query and its
exact retry, and stops its recorded process. It depends on the neighboring
`tools/usage/tenancy/linux_memory.py` utility. Copy that utility beside the script
when staging the standalone runner on the host. Each run requires new output
and workspace directories. It records host and cgroup CPU pressure, load, CPU
ticks, process memory, and full synthetic replies; telemetry never records
tenant text. The synthetic request itself is fixed in the runner.

Use `--exercise-discovery` for the lazy experiment: it captures capabilities
before discovery, initializes the real catalog, invokes Fahrenheit-to-Celsius,
then sends a fresh arithmetic request and compares complete response bytes
before and after catalog construction. Retries are also checked byte for byte.
The optional `--pycache` mount exists for future experiments but was not used in
this batch. No bytecode-cache benefit is claimed.

`--production-source --exercise-discovery` qualifies an uninstrumented source
overlay. Its separate `QUALIFICATION.json` must declare `instrumented: false`
and `adapter_files_sha256` (filenames mapped to SHA256 hashes). The runner
verifies those bytes and records the mode as `production_source_scratch_overlay`,
not a signed or deployed candidate. It checks deferred/null counts after the
first query and ready/actual counts after discovery.

Adapter selection uses the shared `linux_memory.is_adapter_identity` helper:
the executable must be Python and the script must occupy Python's script
argument position. A bwrap command containing the same script elsewhere, or a
Python `-c`/`-m` child, does not qualify. The runner retains descendant start
times and argv, checks the original tree stopped, and requires wrapper exit 0.
The first production-source run exposed this selection mistake; its separate
cleanup correction is retained rather than rewriting the original receipt.

Example, after resolving the actual installed rootfs and public-data paths:

```sh
python3 -B instrument.py --source-adapter "$runtime/adapter" \
  --output "$scratch/adapter-lazy" --detailed --lazy-operations
python3 -B run.py --runtime "$runtime" --rootfs "$rootfs" \
  --shared-data "$data" --adapter "$scratch/adapter-lazy" \
  --output "$scratch/run-lazy" --slots "$engine_slots" \
  --receipt-sha256 "$receipt_sha256" --exercise-discovery
```

The runner hashes the deployment receipt and compares accessible runtime file
sizes/mtimes before and after. This is an immutability observation, not a fresh
hash verification of every corpus file. The read-only mounts enforce the
runtime write boundary during this experiment. Existing installed candidate
files are never rewritten.

Narrow instrumentation checks, requiring the retained U6-v2 local adapter:

```sh
python3 -m unittest discover -s tools/usage/startup-profile -p test_instrument.py -v
```

Measured results and limits: `project/lanes/U6-startup-profile.md`.
