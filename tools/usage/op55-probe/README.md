# Copied-Store opcode 55 qualification

`probe.py` is an untrusted test driver. The pinned native Host owns receipt
verification and outcome interpretation. The driver sends only historical
lookup opcode 55; denied submission opcodes are tested only at the public
proxy, which must refuse them before forwarding. No submit or ACK command is
available in the driver.

The isolated remote fixture is `/build/lanes/oracle-op55-probe` on `dregg-build`.
It contains a 794,624-byte copy of the stopped logical Store, its anchor and
checkpoint key, and a configuration changing only `storageRoot` and
`checkpointKey`. The credential stays remote and is never part of this source
directory or its report. The prior prepared fixture and original Store remain
untouched.

Copy this repository's `probe.py` to a new remote script filename; the completed
qualification uses `probe-compat.py`. Run a fresh output label. The input manifest pins the Host; the report records
the client and proxy binary hashes for comparison with their qualified release:

```sh
env SWARM_MEM_MAX=8G swarm-build python3 -B probe-compat.py \
  --root /build/lanes/oracle-op55-probe \
  --mini /build/lanes/oracle-session-lookup/target/release/mini \
  --proxy /build/lanes/oracle-session-lookup/target/release/mini \
  --compat-mini /build/lanes/oracle-acceptance-u3-r3/run-v5/bin/mini \
  --label NEW-UNUSED-LABEL --deadline 900
```

Launch it detached with a PID file under the fixture, as required by Mini's
coordination rules. Existing output labels refuse; nothing is overwritten.
The driver records its operator/proxy PIDs, records descendant identities before
cleanup, stops only those exact identities, and compares original and copied
database/anchor/config/key hashes plus database row counts before and after.

Controls cover the exact original receipt, a canonical last-byte mutation,
truncated input, an empty relay frame, exact lookup after refusals, public exact
and changed lookups, recipient CLI success, wrong expected transaction refusal,
and denial of private opcodes 54/72/84/152/155. Empty input is a relay refusal;
truncation exercises the native malformed-ingress result.

`--compat-mini` checks the original frozen controller client through the new
proxy after the Host is warm. An earlier concurrent compatibility attempt hit
the operator's queue residence deadline behind the cold lookup; its failed
report and driver remain preserved remotely. The sequential control tests
client compatibility without conflating it with cold queue contention.

This is copied-data qualification, not permission or evidence to restart the
retained controller, resend foreground operation 13, ACK it, or launch an app.
