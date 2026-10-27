# Linux tenant-pool measurements, 2026-10-27

The subsequent [U7 qualification](../../../project/lanes/U7-tenancy-qualification.md)
completed the 32-tenant workload with one resident worker, durable retries,
conflict and stale-context refusals, bounded contention and clean restart/shutdown.
Its 944 process samples saw at most one Engine; peak sampled PSS was 441,971 KiB
and summed RSS 455,528 KiB. The whole experiment's cgroup peak was 750,977,024
bytes (716 MiB) under a 2 GiB limit, including charged cache and the harness.
First requests took 7.51–103.05 seconds under concurrent host activity; this is
not a clean latency comparison. The [compact evidence](u7-20261027-summary.json)
identifies the retained raw receipt and exact checks. This supersedes the
earlier incomplete 32-tenant lifecycle attempt below, without extending its
scope to Mini authentication, all specialists or simultaneous tenant throughput.

The two-resident design bounds running Engines, but switching to an evicted
 tenant still costs a cold start. This measurement is development evidence,
not a specialist-panel score or Mini authentication claim.

One installed v5/U3 Engine, warmed by a real arithmetic question, used 476,743
KiB PSS (496,608 KiB RSS; 464,772 KiB private). Startup took 12.42 s and the
query 0.351 s. Its cgroup peak was 701,353,984 bytes, including file cache.
Receipt: `dregg-build:/build/lanes/oracle-tenancy-measure/baseline-v5/receipt.json`,
SHA256 `c846ce95dbf35d20031c7fa230ae6ec549d51984c2b31effa14cad03dc89f1b2`.
The original measurement harness initially stopped bubblewrap instead of its
adapter; the owned adapter was subsequently stopped by its recorded PID.

The final U6-v2 code receipt was
`65d0391ee109d7f2873391d7f71cb0991d806b922f73c932764169e3cab90dd8`,
using the existing data inventory
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
Its three-tenant two-resident run sampled at most 887,603 KiB PSS, 954,120 KiB
RSS and 841,244 KiB private; cgroup peak was 905,158,656 bytes. Three cold
requests took 25.29, 18.63 and 18.81 s; exact retained retries took 3.4–4.9 ms.
A later restart of the same private workspace returned the exact durable reply
in 7.2 ms and refused a stale conversation in 5.5 ms, with zero Engine
allocations for either. The restart adapter exited cleanly.

The focused run's measurement harness failed during shutdown instrumentation
because a `/proc` process vanished between reads. Its persistent samples and
initial request records remain usable, but warm and burst timings were not
persisted; the restart is a separate continuation. The sampler now handles that
race and binds signals to PID start time and argv. Six focused utility tests
pass. No additional Engine was launched to turn the partial receipt green.

An earlier v5-plus-pool run reached 32 registered tenants. Read-only inspection
found 32 separate journals, each with the same request ID completed and 32
distinct response byte strings. Its harness failed at shutdown and did not save
its volatile timings or assertions, so it does not establish a complete
32-tenant behavioral pass. Forensic receipt SHA256
`dd416f20ad61462b6af588ac11a62dbc5176f4017d2b254f6224776290d9811d`.

The combined machine-readable summary is
`dregg-build:/build/lanes/oracle-tenancy-measure/summary.json`, SHA256
`0c14dfaf852d16446df5c73bc7d33c03b50532773b5ad4d446439da818a29a51`.
PSS apportions mapped shared pages; summing RSS double-counts them. Cgroup
memory includes other charged memory and page cache. Periodic samples can miss
short peaks. This run does not prove a two-worker budget for a 2 GiB host or
provide per-stage attribution for startup costs.
