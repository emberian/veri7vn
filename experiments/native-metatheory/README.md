# Native context and admission probe

Exercises locale definitions, interpretation transport, hypothesis inspection and assumption export. Zero subgoals/oracles can still conceal a hypothesis.

In a steward slot, from repository root:

```sh
USER_HOME="$PWD/experiments/native-metatheory/state" \
  /Applications/Isabelle2026-RC1.app/bin/isabelle build \
  -D experiments/native-metatheory -j 1 -o threads=2 Veri7vn_Native_Admission
```

Bundled HOL supplies the parent; `state/` isolates generated state. The successful run used approved execution because the sandbox blocked `sysctl`.

`build.log` records completion. `probe-output.log` uses `isabelle build_log -v -M 'INSTANTIATED|ASSUMPTION_PROBE|EXPORTED'` with the same `USER_HOME`. Research inputs live in `research/`; [analysis](../../docs/research/native-metatheory.md) explains the probe. Production admission is separate.
