# rel-novels on Linux (persvati)

Build-only receipt, lane W5-04. The novels reader has no answerer binary of its own (its decision binary is built by `tools/reader-novels/build_decide.sh` from this session's export), so there is no Linux panel to score here. What was checked is that the verified session builds on Linux and generates the same code.

| | |
|---|---|
| host | persvati (Linux x86_64), Isabelle2026-RC1 |
| session | `Veri7vn_Novel_Reader`, marker `VERI7VN_NOVELS PASS` found in this run's log |
| build time | 25 s wall through `tools/dev/remote-build` (3.2 s for the session itself, heaps already warm) |
| generated SML | `novel_reader.ML`, sha1 `6edebfd1c416e1944e82325a102bc79fe3ddb0ad`, sha256 `5b1a9d2450e429ca4d83606d0f473ab5082ef2c1c58e28872d1f65ef72ead833` |
| compared with | the sha1 recorded in `project/lanes/W5-01-novels.md` (also a remote-build export): identical |

Not covered: the reader's 84/120 relations panel was not run on Linux, and the recorded sha1 is itself a Linux export, so this shows the build is repeatable, not that macOS generates the same file. The other 22 families do have that macOS check (see the README).
