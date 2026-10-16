# Installed launcher

The steward runs `package.scala`: `var/deployment-launcher/archives/ATTEMPT` contains the bootstrap JAR, shell, snapshots and receipt. It compiles only `DeploymentMain.scala`; attach with `--launcher-archive`.

```sh
python3 tests/deployment/launcher/parity.py --runtime PACKAGE/runtime --launcher-jar ARCHIVE/veri7vn-launcher.jar
```

Parity covers inventory/plans, tampered bytes/modes/links, generation identity, surfaces/tutorials, symlink containment, literal arguments and pointer switching. Buffer tests include >1MiB, partial tails, tail corruption and a following empty file. Every regular file is hashed on every invocation using a local buffer and lowercase `HexFormat`.

Recipient commands, outside the checkout:

```sh
INSTALL/current/bin/veri7vn verify
INSTALL/current/bin/veri7vn locate --tutorial CANONICAL-TUTORIAL-NAME
INSTALL/current/bin/veri7vn plan --state /absolute/mutable-state --surface source -- list
INSTALL/current/bin/veri7vn launch --state /absolute/mutable-state --surface source -- list
INSTALL/current/bin/veri7vn launch --state /absolute/mutable-state --surface workbench -- list
```

The pinned bootstrap loads only the selected surface's inventoried host JARs through a child/context classloader. Source and resident producers require separate installed trials. Recipients need neither Python nor a compiler.

Trust includes shell, verifier, packaged Isabelle/Java startup and OS. Settings execute before verification; generations must remain immutable. The shell pins selection, allowlists environment, derives USER/LOGNAME from `/usr/bin/id -un`, and uses `/usr/bin:/bin:/usr/sbin:/sbin`. Mutable state cannot enter `generations/`. Each invocation removes its private settings home on exit. Manifests require `associations.bootstrap_user_home=fresh-owned-temporary/1` and `environment.USER_HOME={bootstrap_home}`; JVM dispatch checks the binding.

`VERI7VN_LAUNCH_PROFILE=1` emits ≤32 JVM/two shell stderr JSON events prefixed `VERI7VN_LAUNCH_PHASE `. Stdout/checks remain unchanged; paths/payloads are excluded. Observer receipts include delivery delay; JVM spans use local `System.nanoTime`. Never mix clock epochs or sum nested spans/GC deltas. Hash bytes are logical reads; unsupported GC counters are null, and used heap includes dead objects.

Native `System.exit` may omit `dispatch-returned`. Shutdown markers establish neither success nor application closure: retain exit status and stdout oracle independently.
