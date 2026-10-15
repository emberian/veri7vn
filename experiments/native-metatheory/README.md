# Native context/admission feasibility experiment

This isolated probe supports the architecture research in
`docs/research/native-metatheory.md`. It does not install a production capability
package or modify the existing prototype.

It exercises `Local_Theory.define` within a locale, theorem transport through
interpretation, theorem hypothesis inspection, and assumption export. Its key
negative check is that zero subgoals and zero oracles do not imply an unconditional
theorem: a theorem constructed by assumption retains its hypothesis.

Run from the repository root:

```sh
USER_HOME="$PWD/experiments/native-metatheory/state" \
  /Applications/Isabelle2026-RC1.app/bin/isabelle build \
  -D experiments/native-metatheory -j 1 -o threads=2 Veri7vn_Native_Admission
```

`USER_HOME` is Isabelle's supported user-state root; it leaves the user's normal
Isabelle state untouched. Bundled HOL remains the parent heap. The desktop shell
sandbox blocks Isabelle's `sysctl` startup probe, so the recorded successful run
used the normal execution environment through the approval mechanism.

`build.log` records completion. `probe-output.log` was obtained with
`isabelle build_log -v -M 'INSTANTIATED|ASSUMPTION_PROBE|EXPORTED'` using the same
workspace-local `USER_HOME`.

`research/` holds Scry query evidence and primary-source reading material. No
credential is stored in this directory. `state/` is generated local Isabelle build
state, not source code or a required distributable artifact.
