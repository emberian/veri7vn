# Copied Store opcode 55 qualification — passed

No commits, new theorem claims or specialist panel scores. Root integrates the named files.
Scope: dregg-build operator **UID/GID 1000**, owned 0700 copied-fixture sockets; **controller UID 100064 and its ACL/peer admission were not tested**.
Final [qualification manifest](/Users/ember/dev/o7vn/tools/usage/op55-probe/evidence/qualification.json), SHA-256 `3929ee2c454984427ba8df005719ce14569cd3497bd32d3f1a2a4896a51a6e2d`.
Frozen Host: `bbf797b4c1b51dae0b4f6fcba292d5f15717885b6925a36f3384de670d3b9bac`; public/candidate Mini: `e024af5de27bb09856c832bb27eb00b2a99d53b9715c44b40f81440c64d82a9e`; original recipient Mini: `68f8eefadfb0d7bfa9a8bc69f7656a362e32688553ac7114b32cfd07bd9a1d48`.
Exact ingress `1811bf42e6dc1f4ba238700480727050cf547714d38b695e3cc7df4d6e2c55da` matches the latest final controller export, not an old handoff export.
Both recipient clients returned the same original confirmed/replayed receipt at **acceptedCount 29** through the new public proxy; the four expected historical fields matched.
Canonical final-byte change: native transaction-identity conflict; truncated ingress: native malformed; empty frame: relay refusal; exact lookup after refusals: identical receipt bytes.
Wrong expected transaction ID refused in the recipient CLI. Public opcodes **54/72/84/152/155** refused before forwarding.
Original logical Store and 794,624-byte copied Store: DB/anchor/config/key hashes unchanged; durable_log count/max **40/40 → 40/40**, archive_journal **0 → 0**. Historical receipt 29 is distinct from current prefix length 40.
Final run: **178 s**, cold exact lookup **172.924 s**, cgroup peak **644,280,320 bytes**. All owned operator/proxy/Host/helper processes stopped by recorded PID identities.
Final [raw report](/Users/ember/dev/o7vn/tools/usage/op55-probe/evidence/final-run.json) SHA-256 `5bae66bbc3f344c0f409cce23638c5bd8cc872d0e66a4e1e07f14f7dae662741`; remote fixture: `dregg-build:/build/lanes/oracle-op55-probe`.
Earlier instrument expectation and concurrent-client queue-deadline failures remain recorded; the sequential final original-client control passed. Neither failure changed either Store.
Read source: `Host/Main.lean:applicationGrainShareIssueLookupSession` returns the verified original receipt; `Kernel/ApplicationShareIssueGrainLookup.lean:lookupVerified` checks exact ingress, full encoded intent, same-walk certificate and receipt; `ApplicationShareIssueGrainSource` binds canonical decoded bytes. No proof/build changes were needed.
Files: this report, `tools/usage/op55-probe/probe.py`, `README.md`, and metadata-only `evidence/*.json`; no Store, ingress, checkpoint key or signed-call payload enters Git.
Retained namespace d4090a0c4c356d31 stayed stopped; no original restart, admission write, foreground13 resubmit, ACK or public application effect.
BATCH FOR THE PARENT: pin the separately qualified runtime artifact from operator_socket and use this scoped evidence in the guarded retained-controller trial; actual controller UID/ACL behavior remains that trial's obligation.
