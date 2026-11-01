Prototype a verified relation reader for ONE of Oracle7's 161 `rel-*` specialists: `rel-novels`
(`upstream/root/specialists/rel-novels/`, class RelationOrganV2). The shipped reader needs
`names_v1.sqlite3` and `relations_v2.sqlite3`, which never shipped; only `relations_v1.sqlite3`
(schema: entity(qid,label,enwiki), fact(s,p,o,lit)) is available. Lane F already proved the exact
router's decision over fetched rows (`src/isabelle/reader/Relation_Reader.thy`, `tools/reader/`);
reuse its shape: verified decision over rows, untrusted sqlite fetch asserting completeness.

This worktree carries earlier scout lives' work and a SCOUT_REPORT.md on your branch. Read
SCOUT_REPORT.md first and continue from its "next steps"; every earlier life ended by running out
of context, so keep yours small (grep before reading, read files in parts, never print panels or
long logs), update SCOUT_REPORT.md and commit at every milestone, and prefer remote builds
(`tools/dev/remote-build hbox|persvati ...`) over local ones.
