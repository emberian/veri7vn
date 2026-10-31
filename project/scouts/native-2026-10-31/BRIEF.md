# Native Oracle research and design scouts

Ember requests scouts and scholars before implementation dispatch. Focus on
Oracle7/veri7vn capability, correctness and data-oriented native execution.
Mini receiving/hosting is another team's job. Do not implement runtime changes,
run builds or test suites, create worktrees, commit, or spawn other agents.

Read the current project tracker and actual relevant source. Historical plans
are leads, not current truth. The signed candidate is a checkpoint, not proof of
full native coverage. Shipped panels and independent truth cases both matter;
never preserve a known wrong answer just to match upstream.

Each lane owns only `project/scouts/native-2026-10-31/<lane>.md`, its scratch
`var/native-scouts-20261031/<lane>/`, and
`~/paperbin/oracle-native-20261031/<lane>/`. Other files are read-only. Never
modify `upstream/`; U8 materialization is also read-only. Do not touch Mini.
No edits or deletion of other sessions' papers, files or caches.

Ground research in both existing paperbin material and fresh primary sources.
Existing Oracle collection: `~/paperbin/oracle7-20261027/` and reports
`project/lanes/LITERATURE-*-2026-10-27.md`. Search paper titles/filenames before
reading broad corpora; avoid giant transcript or dataset dumps. Read relevant
paper sections, not just abstracts/search snippets. Cite precise sources and
mark reading depth. Use author/project/publisher sources for technical claims.
Distinguish established foundations, current work, hypotheses and product fit.

Search access: `tools/research_scry.py` has a bounded read-only client using
`~/.scry-key`; consult live context/schema before SQL. Kagi v1 POST search is
shown in `~/dev/allgame/claude_resident/tools/web_tools.py`; parse only
KAGI_API_KEY from `~/dev/allgame/.env` in-process, never source or print that
file, credentials, request headers, or authenticated URLs. Prior bounded
example: `~/paperbin/oracle7-20261027/nonmonotonic/search/research.py`.
Use both services when useful; record failures honestly and use web fallback.
Keep queries bounded and initially use 3–5 focused searches per service/lane;
expand only for a concrete unresolved question. No external messaging.

Save useful new open-access papers in your paperbin directory, with source URL,
title/authors/year, SHA-256, retrieval date and reading-depth manifest. Avoid
copying existing papers; reference their current paths. No paper PDFs/full texts
or credentials go into git. Notes and new search helpers belong in lane scratch.

Report (aim 1000–1800 words, prioritize substance):
1. Actual current code/data flow and limitations, with path/symbol references.
2. Two or three credible designs with representation, ownership and algorithm
   tradeoffs; avoid a crate shopping list or universal framework by default.
3. Concrete specialist/user workflows unlocked; what makes them stronger.
4. Relevant literature translated into specific design decisions and limits.
5. Phased proposal, prerequisite interfaces, reversible first experiments,
   and decisive correctness/performance tests or counterexamples. No invented
   benchmark results. Name likely negative results and ways to reject a design.
6. Dependencies on other scouts and explicit open questions.

Send root an early source-grounded finding, then a final <=300-word digest with
report path, strongest proposal, major caveat and paper additions. Coordinate
cross-lane interfaces through messages. Root owns synthesis and implementation
selection; this research round does not authorize implementation.
