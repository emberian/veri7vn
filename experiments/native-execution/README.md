# Native staging feasibility probe

This isolated experiment measures staged generated ML and theorem acquisition
from a saved Isabelle2026-RC1 heap. It is not the proposed veri7vn IR and is not
an application throughput benchmark. `probe-output.txt` is the successful run.

Run from `/Users/ember/dev/o7vn`:

```sh
USER_HOME=/Users/ember/dev/o7vn/experiments/native-execution/state \
  /Applications/Isabelle2026-RC1.app/bin/isabelle build \
  -b -D experiments/native-execution -j 1 -o threads=2 Native_Execution_Probe

USER_HOME=/Users/ember/dev/o7vn/experiments/native-execution/state \
  /Applications/Isabelle2026-RC1.app/bin/isabelle ML_process \
  -d experiments/native-execution -l Native_Execution_Probe -o threads=2 \
  -e 'ML_Context.eval_source_in (SOME (Proof_Context.init_global (Build.get_theory "Native_Execution_Probe.Native_Execution_Probe"))) ML_Compiler.flags (Input.string "Native_Execution_Probe.run (Context.the_local_context ());");'

.venv/bin/python experiments/native-execution/measure_startup.py
```

The per-command `USER_HOME` is Isabelle's configuration root override. It does
not change `$HOME` or global settings. HOL is loaded from the bundled application;
the additional heap and build database are under this directory's ignored
`state/` tree. No HOL-Analysis build is involved.

The startup probe samples aggregate RSS of the launched process and descendants
every 100 ms and holds the ML process alive one second after its ready marker.
RSS can double-count shared pages. This is not a measurement of the fully
packaged resident server or a cold OS cache. Sampling itself adds overhead.

The Scry query files are reproducible literature-discovery inputs. Retrieved
metadata and full papers named `scry-*.json` are ignored local research material,
not distribution content. See `docs/research/native-execution.md` for synthesis
and primary-source links.
