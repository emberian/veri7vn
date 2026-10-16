# Runtime dispatch and migration review

The source C3 resolver (`tools/audit/reachability/dispatch.py`) follows actual
imports/classes under oracle7.py's admitted-before-wander path order. It resolves
**361 classes across 360 modules**, including w530's private mixin, three
multiple-inheritance joins (w66,w46,w31), the evidential serving branch and 40
pre-AO ancestor modules. All 317 HEAD-listed modules are present, but HEAD's
`chain_tip_to_base` is not the C3 method order. Its w110/w114/w116 and w60 diamond
ordering differs. Python's own `type` machinery on inert source-base class shells
independently validates the resolver's class order. No upstream app is imported.
`dispatch.json` pins inspected source hashes and records 580 potentially reachable
method bodies, lexical conditions, virtual/super/explicit-base targets, module
helpers and self writes. The 63 unreached declared methods are **not excluded**:
dynamic callbacks/getattr, standalone callers and helper-mediated calls can reach
methods outside this model. Conditional branches are possible routes, not traces.

| Actual route | Source-owned semantics and state | Migration / failure boundary |
|---|---|---|
| w540.chat → cooperative chain | Final question-direction, number-readback and private-question guards run **after** inner chat | G04 arbitration before answer-derived state. Scoped test confirms w529 numeric state survives N2 rejection |
| w533.chat / _c533_part | Whole pipeline then 2–3 subquestions; `_Base.chat(self,part,#part)` explicitly bypasses w533 chat, but virtual self helpers still dispatch at tip | Keep explicit-base semantics, sub-session lineage and per-part blockers. Partial-display scope differs from whole answered |
| w530 private _C528Parts | Bodies preflight can answer before deeper chat; resolved standalone body check; body decline replaces physics-only answer. `_c528_precedence` calls super from **mixin**, not exported class | Preserve named-body gravity and supported recognition before Earth-default math; source/reader assumptions remain conditional |
| w530 relation precedence | Only designated WEAK paths may be replaced by differing verified-family answer; no decline/per-part substitute there | Reader model/quote assurance remains scoped; not global source truth. Missing families preserve parent reply |
| w525.chat | Parent first; narrowing can invalidate ocean/astronomy result, then family then typed network; deliberate suffixes protected | Local mock reproduces broad exception restoring narrowed parent; retain blocker across dependency failure |
| w480.chat | Calls virtual self._c480_dispatch after base response, logs resulting dialogue before outer guards | Actual dispatch target w503, not w480 alone; logging is transcript observation, adoption must await final arbitration |
| w503→502→500→498→496→494→492→490→488→486→482→480 _c480_dispatch | Each super call runs deeper dispatcher first; unwind adds corrections/social/self/conversation/relation/math/code behavior | Preserve useful speech acts, safety replies and scoped refusal. These are distinct outcomes, not every reply a theorem |
| w480 dispatcher base | Dialogue for unanswered/session-vessel; math directive may outrank nonmath parent; relation outranks designated weak paths | Guard inputs and scope arbitration; source-derived relation computation remains owned; failure/timeout not absence |
| w482/w486 code | V482 examples/prose check and bounded composition; V486 _Recorder and persistent library with persist=False for loop-*; wraps unconfident programs as tentative | Candidate/test artifact retained, not admitted universal program. Persistent versus in-memory exposure separate; synthesis-growth |
| w490 math | Virtual _c480_math chooses V3 then V482/V480 fallback; path pluralization only after underlying result | Preserve exact requested mathematical domain and partiality; false equivalence fixtures apply to actual chosen V3 component |
| w492 relations | Form helper or pronoun rewritten from response string; uses relation source and bounded helper timeout | Typed interpretation/adoption should replace rendering reparse; original literal and source/model premises retained |
| w494/w496/w498/w500 acts | Converse safety can survive withheld result; self-only exceptions explicit; hollow reply recognition; social response uses recent turn context | Claim scope separate from speech act, no indiscriminate fallback; operational-model/interpretation-model |
| w503/w502 corrections | Parent-first corrections reject context-only topic substitution and formula-as-wordproblem | Preserve these existing repairs while replacing heuristic guard with scoped interpretation evidence |
| w480 _receive/_register | SQLite BEGIN IMMEDIATE vessel update/weight/session counts; COMMIT then event/request JSONL; fallback to older _receive if DB not ready. Register orders top 3 and mutates session path queue | Native owned state transitions and conditional source/host persistence; postcommit journal/event failure does not prove absent update |
| w468 remember | Answered inner result updates thread/reply memory before outer transformations | Separate adopted answer state from attempted/transcript state; cancellation/outer refusal cannot silently retain authority |
| w31 serving merge | SiblingEvidentialV3→V2→SiblingEvidential extends actual core ancestor AO | These inherited source files are core runtime, not the six sibling product investigation scope |

Three synthesis mechanisms remain separate migrations: w32 catalogue/toolchain
execution, w37 ordered pipeline/differential sample search, and w482/w486 bounded
typed enumeration/library. This review follows dispatcher ownership, not a claim
that the mechanisms have been proved or subsumed by one enumerator.

Every other source route remains retained in dispatch.json and pinned inventory.
Unreviewed helper body/imported engine/background-worker semantics remain owned
work, not absence or exclusion. Read matrices together with the independent
workbench workflow dispositions. Root should dispatch source-semantic families
from `domain-profiles.json`, and use this matrix for routing/state/synthesis
integration. Full runtime activation and complete source-role closure remain open.
