# Native staging probe

From repository root, in a steward slot:

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

`probe-output.txt` records staged ML/theorem acquisition; bundled HOL and local `state/` supply heaps. Startup samples descendant RSS every100ms, holding one second after readiness. Shared pages/sampling overhead remain; neither cold-cache nor application throughput is measured. Research synthesis: `docs/research/native-execution.md`; retrieved Scry material stays local.
