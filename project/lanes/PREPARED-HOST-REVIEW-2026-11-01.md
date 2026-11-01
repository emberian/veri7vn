# Prepared Engine host review, 1 November 2026

Reviewer: Astra, prepared hosting lane. Base: `ab82d0b`; reviewed the shared
working source before integration. This lane changed only this note. No
specialist panels were run, so this review has no panel numbers. No theorems
were added or changed. No build or test was run by the reviewer.

The consumer is the optional prepared Python Engine inside the Rust host.
Public reader tables are admitted against the materialized source before
workers start. Each ready process is initially unassigned; its first tenant
owns that whole generation. Changing tenant destroys the generation and asks
a fixed supervisor to prepare another. Private process memory never returns
to the public ready pool.

Reviewed `engine.rs`, `config.rs`, the startup path in `main.rs`, the Engine
and conversation failure paths in `service.rs`, the worker readiness and
host-death guardian in `tools/appliance/engine_worker.py`, configuration
creation, packaging, and the new focused lifecycle fixture source.

The review found these issues during implementation; the authors repaired them
and the reviewer checked the resulting source:

- Prepared/public separation used lexical paths. A private-state ancestor
  symlink could bypass it. Admission now resolves existing ancestors before
  comparing locations.
- The backoff path retained the wake mutex while reacquiring a worker slot,
  reversing retirement's lock order. It now drops the wake guard first.
- Eviction could choose an exhausted empty slot ahead of a usable later
  worker. Prepared eviction now selects existing workers; unavailable slots
  cannot hide that capacity.
- An invalid startup deadline could panic a supervisor and strand the initial
  readiness wait. Failure now marks the slot exhausted and wakes the waiter.
- Reader-thread creation failure could abandon a spawned child. Fallible
  thread creation now kills and reaps the recorded group and joins any reader
  already created.
- Startup and shutdown needed a shared gate. Spawn checks stopping while
  holding that gate; close sets stopping under it. Readiness cancellation and
  joined supervisor/reader lifetimes close the normal shutdown path.
- The termination watcher previously started after prewarming. It now runs
  before the readiness barrier and closes the service when signaled.
- Prepared admission initially repeated the complete materialization hash
  scan. The pool now performs it once before the public-artifact check.

The final source review found no remaining blocking issue in those paths.
Readiness validates the prepared scope, artifact digest, synchronous loading
policy and required components. Replacement has fixed concurrency, bounded
attempts and backoff, and cannot be rearmed by incoming requests after
exhaustion. Query uncertainty still carries its generation location, and
conversation generation checks remain in place. The legacy configuration
retains lazy startup.

This is a source review, not a hosted qualification receipt. The manufactured
workers deliberately bypass public-artifact admission and do not establish
actual U8 readiness or guardian behavior. Integration still needs actual cold
host admission, queries within the unchanged limit, replacement and restart,
and process-tree cleanup against the admitted artifacts. Ordinary OS process
and filesystem operations are not hard resource isolation. Artifact hashes
require operator-protected immutable custody for the host lifetime; this code
does not create a filesystem sandbox or shared Python object heaps.
