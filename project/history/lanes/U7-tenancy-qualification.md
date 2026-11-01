# U7 Linux tenancy qualification

The one-resident, 32-tenant real Engine run passed on dregg-build on 27 October.
It completed in 581 seconds under a 2 GiB cgroup limit, during concurrent build
activity. Both the initial pool and its restart stopped cleanly. This qualifies
the arithmetic and lifecycle workload below; it is not a Mini admission or
specialist-panel result.

The independent Linux runtime is `/build/lanes/oracle-tenancy-measure/u7-runtime`,
reconstructed from the verified code-only U7 input. The appliance receipt is
`78773bfb4ec72633332dfd67d9a466f4022f2457371fff32d3b673bcd499844c`;
the read-only public data inventory is
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
It used the existing packaged Linux Python and root filesystem, with 26 links
into that public-data mount; no large data copy or Mini Store mutation.

The runner was `tools/usage/tenancy/pool_probe.py`, with source hashes in the
[compact evidence](../../tools/usage/tenancy/u7-20261027-summary.json). It checked:

- 32 tenants completed different arithmetic questions using the same request
  and conversation IDs. All 32 exact retries returned identical bytes; all 32
  changed-body requests with the same ID refused with HTTP 409. Subsequent
  read-only inspection found 32 separate journals, each with that completed
  request ID, and 32 distinct stored replies.
- Replaying an evicted tenant's completed request left the process tree and
  resident count unchanged. A new turn in its old conversation refused with
  `conversation_reset_required`; an explicit new conversation succeeded.
- Eight concurrent requests to one tenant produced one completion and seven
  retryable HTTP 429 refusals. Sequential retries of those refusals completed.
- Restarting the pool in the same workspace replayed the exact retained reply
  and refused a stale conversation with zero resident Engines. Both shutdowns
  returned zero and left no recorded processes alive. Post-run process and
  lock listings contained no remaining tenancy-run entries.

The configured resident cap was one. Health checks stayed within that cap,
and 944 process observations saw at most one Engine worker and four total
processes. Samples were taken approximately every half-second and can miss
brief peaks; this is an observed bound, not a proof about every instant.

| Memory measurement | Peak |
| --- | ---: |
| Sampled process-tree PSS | 441,971 KiB |
| Sampled summed RSS | 455,528 KiB |
| Sampled private mappings | 434,896 KiB |
| Sampled swap | 0 KiB |
| Entire experiment's cgroup memory | 750,977,024 bytes (716 MiB) |

PSS apportions shared mapped pages; summed RSS counts shared pages repeatedly.
The cgroup figure includes the measurement process and charged file cache, so
it is not Engine RSS. The run stayed below its 2 GiB cap for this workload;
other specialists and larger queries can have different memory requirements.

First requests, including worker startup, took 7.51–103.05 seconds (median
13.84 seconds). Exact retries took 1.22–25.98 milliseconds (median 2.53 ms).
Cold retained replay took 3.76 ms; one warm new request took 118 ms. These are
contended-host observations, not a clean comparison or a throughput guarantee.
One worker avoids per-tenant resident memory but incurs cold starts when
switching tenants; evicted conversational context still needs explicit reset.

The raw receipt remains at
`dregg-build:/build/lanes/oracle-tenancy-measure/pool-u7-32-final/receipt.json`,
SHA-256 `5e76a4608cf2928dc6e8dd27d494bc9638289c43e98b1c4738875f9d4931c6af`.
The companion `pool-u7-32-final.log` records exit zero and the cgroup peak.
The runner saves its success receipt only after cleanup and rejects recorded
sampling errors; none were present. The fixture uses host-supplied tenant keys,
so it does not establish Mini authentication or hostile-code isolation. No
planted implementation fault, specialist panel, browser or agent journey ran
as part of this qualification. No repeat experiment was launched to produce
this report.
