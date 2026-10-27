# Linux tenant pool measurements

These scripts measure the actual untrusted Oracle adapter and Engine. Tenant
headers are supplied by the host for this experiment; they are not authentication,
Mini authority, or specialist-panel scores. `baseline.py` measures one Engine;
`pool_probe.py` measures a bounded pool, durable retries, eviction and restart.
Both lease the same host slot directory supplied by the operator, keep output in
a new private workspace, and signal only their recorded adapter descendants.

`linux_memory.py` reads `/proc/*/smaps_rollup`. Sum of RSS double-counts shared
pages; PSS apportions shared pages across processes. Private and shared fields
are physical mapping classifications, not a limit guarantee. Cgroup memory also
includes file cache and other charges in the measurement scope. Periodic samples
can miss short-lived peaks; `memory.peak`, when visible, covers the cgroup.

The bwrap mode uses an existing read-only packaged root and public dataset. A
separately verified code-only candidate can be bound at `/opt/oracle`, with its
large missing files symlinked to `/opt/oracle-data`. Record both candidate receipt
and dataset inventory; never conflate an older baseline with the new candidate.
The bounded two-worker experiment is not a recommendation for a 2 GiB host.
