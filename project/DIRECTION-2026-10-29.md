# Where the native work should go, 29 October 2026

Root's review after reading the codex handoff, the four design prototypes, the
two reader diagnoses and the architecture documents. It states what the project
has, what shape is holding it back, and what to build so that each piece of
native work earns a number on the only scoreboard the project trusts.

## What exists, in one table

| Layer | What it does today | Scoreboard number |
| --- | --- | --- |
| Oracle7 upstream (Python, 403 classes) | Answers every user question; 267 specialists; the appliance Mini hosts | 15,478 right / 14 wrong on the shipped exams |
| veri7vn extracted organs (Isabelle to SML) | 145 non-relation IDs and one relation kernel, placed in front of the Oracle7 head | 11,844 right / 14 false yes / 71 wrong on 12,247 items; zero wrong is the law |
| Native runtime (Rust, PyO3, HTTP) | 12 operations over supplied inputs plus a KQA image, programs and a learned reader | None. 233 programs, 100 reader questions and a failed 16-case cohort are component checks |
| Four design prototypes | Compile and pass their fixtures as of today | None, by design |

The native layer is the only one without a panel number, and it is where most
recent effort went. That is the shape problem. It is not a quality problem: the
native code is careful and its receipts are exact. It is that nothing a user or
a panel touches routes through it.

## The reader numbers need a control

The native reader scores 36 correct, 4 refused, 60 unknown on 100 retained
questions. Nobody has recorded what Reader7 itself scores on those same 100 or
on the 16-case cohort. Without that control, 36 is not interpretable: it could
be parity or it could be a third of upstream. The only baseline on record is the
older native whole-template reader, not upstream. The local `upstream/` checkout
answers questions through `oracle7.py`; running the same 116 questions through
it is under an hour of work and changes how every reader result should be read.
Do this before any more reader engineering is judged.

## Treat the composition explosion as a design fact, not only a storage bug

One ten-word question produces about 650 learned segment units and 1,290
distinct chain programs before any semantic check. The arena fix in flight
(lane O1) makes that affordable. It does not make it sensible. Reader7 enumerates
learned syntax and then lets execution discard it; a faithful port inherits the
enumeration. Parity with Reader7 is the right first target, because agreement or
refusal is the arbitration rule and a divergent reader cannot be scored. After
parity, the native reader should stop enumerating chains and keep a packed chart:
units shared, chains formed only when an outer demand and a viable base both
exist. That is the point where native stops copying Python and starts being
better by construction.

## The inversion: native hosts, Python works

The architecture document describes `evaluate(image, state, request, budget)`
with a shared immutable image, versioned session state and bounded workers. The
native runtime implements that boundary. The appliance, however, is still the
Python Engine with native kernels inside it. Mini cannot fit the Python appliance
(six stores exceed the SPK member limit) and pays ten seconds and 390 MB per
Engine. The native service already shares one image across cheap tenant handles.

The useful next structure is therefore a native front door with three providers
behind one arbitration rule:

1. Native programs and the learned reader, over the shared image.
2. Resident extracted organs, through the existing `KernelExecutor`.
3. The Python Engine, as one contained worker process, for everything else.

Agreement or refusal across providers is already the project's rule. The front
door would be the "complete turn" the backlog keeps naming, reached by routing
rather than by porting the remaining 370 `chat` overrides first. It also gives
Mini a small runtime package plus a shared read-only data image, which is the
design Mini's own notes recommend.

## Give every native operation a panel

The parity harness runs any answerer that speaks the answerer contract over any
specialist's own panel. Nothing stops a native operation from being wrapped as
an organ folder the way the extracted organs are. Three pairs are ready now:

| Native operation | Specialist panel | Items | Shipped organ right / false yes / wrong |
| --- | --- | --- | --- |
| `graph.shortest_path`, `graph.minimum_spanning_forest` | algorithms, networking | 42, 71 | 42 / 0 / 0; 67 / 1 / 0 |
| `statistics.linear_regression` | statistics, statistics-v2, statistics-v3 | 142, 144, 144 | 126 / 2 / 0; 132 / 2 / 7; 142 / 2 / 0 |
| `chemistry.balance_reaction` | chemistry, chemistry-v3 | 281, 281 | 223 / 0 / 15; 223 / 0 / 2 |

Chemistry is already saturated by the extracted SML kernel (281 / 0 / 0), so a
native chemistry organ earns a number but not a gain. Networking's one false yes
and statistics-v2's seven wrong are real headroom. An organ wrapper is a small
Python file that recognizes the panel's question forms, calls the operation, and
declines otherwise. Its score is a panel number, the zero-wrong law applies, and
an upstream PR carrying "this provider answers N of this specialist's own items
with zero wrong" is a different proposal from "here is a Rust library". This is
the cheapest route from native code to the scoreboard and should come before any
new library integration.

## What the four prototypes earned

| Prototype | Adopt | Park |
| --- | --- | --- |
| Streaming queries | The scalar output contract (lane O2): the reader's viability check materializes full results to learn one boolean | The integer-posting image, roaring/fst, a second executor |
| Conditional symbolics | Rational formulas with dimensions and replayed proofs inside `oracle-reasoning` (lane O4) | A separate algebra API |
| Nonmonotonic scenarios | Hosting `oracle-logic` as a profile with an operator-admitted solver and content-addressed program identity (lane O3) | Any planner or action authority |
| Maintained views | Nothing yet | All of it, until a workload shows retained views beating fresh traversal; the one retained benchmark says the opposite |

## Order of work

1. Land O1 through O4; run the 16-case and 100-question sets with the Reader7
   control beside them; produce one Linux receipt on hbox for the combined tree.
2. Retrain and re-export the reader tables with the plural-first patch; compare
   code-only, data-only and combined, as the handoff asks; post the patch
   upstream with its eight tests.
3. Wrap chemistry, graph and statistics operations as organ folders and score
   them on their specialists' panels through the parity harness.
4. Build the native front door with the Python Engine as a contained worker, and
   score it on a specialist sample through the same harness.
5. Then the library ambitions, each entering through an organ with a panel:
   astronomy (ANISE, hifitime), convex optimization (Clarabel), sequence and
   statistical models, learned readouts registered with their held-out accuracy.

## Documentation

The project has 14 top-level planning documents and 289 lane reports. Each new
checkpoint adds a chronology. Replace the chronologies with two living pages: a
scoreboard generated by the parity tool, and a plan that names the current
lanes and their consumers. Move the rest under `project/history/`. A reader who
is not an engineer should be able to find what the system answers correctly,
what it refuses, and what it cannot do yet, on one page.
