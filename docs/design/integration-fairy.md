# Resident workshop integration

The integration target is an actual managed native development: import → Build →
inspect captured failure → explicit repair → Build → restart → inspect both retained
results → selectively Forget. `tests/integration/workshop/check.scala` compiles the
production inventory and uses RuntimeService without mock native bridge, acknowledgement,
source recovery or artifact construction. Its first `DevelopmentOnly` profile checks
controlled source replay; it does not activate a changed specialist.

## Production joins

RuntimeMain reads the strict installed capability announcement and constructs
ResidentBuildWorkspace over the actual managed source store. The dispatcher must
advertise only joined propose/poll paths. A separate production CLI subprocess
checks launcher wiring: Isabelle `Command_Line.tool` exits its JVM, so calling it
inside the consumer would skip later assertions.

Build, kernel evidence and Search share one physical input pool and rooted native
recovery graph. Factories authenticate committed material, install identity fragments
once and retain actual owners before closing construction batches. Track restoration
targets before allocation so helper failures can roll back published targets. The
complete native authority restoration check remains the final gate; saved IDs cannot
construct contexts, theorems or permissions.

Logical-export qualification supports named native logical exports; executable
locators remain separately gated. Structural update observations do not establish
semantic reuse across sibling contexts. A candidate ID or empirical qualification
is not Search context authority; Search consumes actual owned native context views.

## Lifecycle and recovery requirements

- D74 candidate-only restoration after Cancel needs candidate-owned control material,
  not a required active request.
- Scope capsules authenticate child subsets, aggregate completeness and shared
  headers without copying all sibling sources into each capsule; selective Forget
  must preserve independent results.
- Restoration wire 4 has two inventories. The supported-profile guard explicitly
  rejects retained SessionLocal rows, effect observations and original effect
  requests/pending source registrations until typed recovery exists. Empty source
  inventory cannot stand for those consumers.
- Retained Search proof contexts do not depend on a live execution request.
- Managed source classification must be authenticated. A WorkspaceShared row's shape
  cannot identify a literal; unrelated native generations share that shape.
- Session recall, Search and MCP observation recovery use the same custody/Scope/
  verifier/transaction/cleanup spine while retaining family evidence checks.

## Qualification boundary

The parent native assembly and all 53 actual production Scala sources compile.
The current workshop consumer starts and commits native/source state, then loses
runtime authority readiness during Build progression. The lifecycle workflow has
not passed. The active investigation is the readiness/pump failure, not another
source-only compilation claim.

Evidence: parent compiler receipt
`var/native-scaffold/sessions/acd3f09f4235bc65/attempts/5e31478680df4083a67a2c65197b5d15/receipt.json`;
current runtime attempt
`var/native-scaffold/sessions/acd3f09f4235bc65/attempts/6cd75faa1a5d449e9ec39d273468d8aa/receipt.json`.
Use the exact captured native closure, not every repository ROOT. Qualification must
check class origins and the separate launcher, restart, diagnostics and selective
Forget against the real production service. Root owns status/commits; the build
steward serializes execution through `tools/dev/check-native`.
