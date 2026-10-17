Prototype a verified kernel for the part of Oracle7's head mathematics route that the core panel
exercises. On `upstream/workbench/data/core_panel.json`, 24 items are answered through
`organ:math`, 17 through `op:` (integer_sqrt, gcd_lcm, unit_convert, ...) and 6 through
`algebra:solved`; 114 are withheld by precision guards (`precision_guard:P…/G…/Q…`). The organ is
`upstream/root/wander-train/math_organ_v3.py` (516 lines, SymPy underneath) with
`math_solver_v3.py` and the guard folds in the w-chain (grep `precision_guard` under
`upstream/root/fable-content/.../self_loop/admitted/`). Build the smallest exact-rational HOL
kernel (evaluate, simplify, solve linear in one unknown, gcd/lcm/integer sqrt) plus a recognizer,
and a verified version of two or three precision guards (a decline is a theorem too). Measure on
those core-panel items: the panel records only status and path, so use lane A's head answerer
`tools/parity/answerers/oracle7.py` ONCE in one process (it redirects Oracle7's stray writes; set
`ORACLE7_STATE` under var/scout/) to get Oracle7's answer text for those items, then compare.
Report what SymPy does that an exact kernel cannot, and what the guards really check.
