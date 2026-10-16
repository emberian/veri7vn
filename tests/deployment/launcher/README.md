# Installed recipient launcher

The sole JVM/build steward runs `package.scala` using the existing Isabelle Scala
script runner. It emits `var/deployment-launcher/archives/ATTEMPT` containing a
separate bootstrap jar, `bin/veri7vn`, source snapshots, and producer receipt.
This compiles only `src/deployment/DeploymentMain.scala`: neither application
jar is rebuilt or silently substituted. Pass that archive to deployment
packaging with `--launcher-archive`.

Run the independent development oracle with:

```sh
python3 tests/deployment/launcher/parity.py --runtime PACKAGE/runtime --launcher-jar ARCHIVE/veri7vn-launcher.jar
```

That checks inventory and launch-plan parity against `tools/deploy/stage.py`,
including changed/missing files, mode and link tampering, generation identity,
unknown tutorials/surfaces, state containment through symlinks, literal extra
arguments, paths with spaces, and pinning after a selection-pointer switch.
It is a developer test; recipient execution requires no Python or compiler.

The actual recipient commands, invoked from outside the checkout, are:

```sh
INSTALL/current/bin/veri7vn verify
INSTALL/current/bin/veri7vn locate --tutorial CANONICAL-TUTORIAL-NAME
INSTALL/current/bin/veri7vn plan --state /absolute/mutable-state --surface source -- list
INSTALL/current/bin/veri7vn launch --state /absolute/mutable-state --surface source -- list
INSTALL/current/bin/veri7vn launch --state /absolute/mutable-state --surface workbench -- list
```

A source workbench and resident workbench need not have compatible producers.
The bootstrap system classpath contains only its own jar plus the packaged
Isabelle/Scala distribution. Dispatch loads exactly the surface's inventoried
host jars into a child classloader and sets the thread context loader. It does
not put both application jars onto the system classpath. Native-resident and
source-authoring behavior still require their separate installed trials.

The shell, JVM verifier, packaged Java/Isabelle startup code, and operating
system are the bootstrap trust base. Inventory verification detects changed
bytes after that code has started; hashing the verifier's own jar is not a
proof of verifier correctness or protection against replacing the entire
bootstrap. Generation directories must remain immutable during execution.

The shell resolves the selected generation once, strips inherited startup
configuration with an environment allowlist, and rejects mutable state anywhere
under the installation's `generations` directory (including sibling generations).
The controlled PATH includes `/usr/bin:/bin:/usr/sbin:/sbin`, so macOS `sysctl`
is available; USER/LOGNAME come from `/usr/bin/id -un`, ignoring ambient spoofed
values. Every invocation gets an ephemeral private settings directory,
removed on exit; existing workspace settings are never sourced. Launcher-attached
manifests explicitly set `associations.bootstrap_user_home` to
`fresh-owned-temporary/1` and `environment.USER_HOME` to `{bootstrap_home}`.
Plans retain that allocation token; launch binds it to the owned temporary home.
The JVM checks the policy and matching shell environment before dispatch. Durable
workspace and image paths remain explicit arguments. Packaged Isabelle settings
execute before inventory verification, which is part of the bootstrap trust.
