# codeorgan (scout prototype)

A HOL model of the code organ's typing: the library of moves with their
argument slots and output types, the pool composition rule of the search, and
the theorem that every program the rule can compose is well typed at every
node. Exported to SML, it is an executable type checker for composed programs:
given an argument signature and a program tree, it prints the candidate output
types or rejects the program as one the composition rule could never form.

This is a scout prototype, not a lifted family: the move table transcribes 31
of the organ's 146 moves (chosen to cover every slot shape and all nine
any-slot moves), the organ itself was not rewritten, and nothing here is
scored on a panel (the code organ has no panel in the drop; see
`SCOUT_REPORT.md` at the worktree root).

## What is proved

`Codeorgan.thy`, in one breath:

- `tys sig u`: the candidate base types of program `u` under argument
  signature `sig` (empty list = rejected).
- `slots_ok sig ws ts`: the search's pool admission, slot by slot: children
  pair with slots, and every child's candidate types all connect to its slot
  (`connects` = the organ's `fits(t, want) or t == "any"`).
- `enum sig u`: the composition rule as an inductive predicate — exactly the
  programs the organ's bottom-up search can build from a request's arguments
  and constants.
- `enum_well_typed` and `enum_nodes_typed`: every program the rule composes
  has a nonempty candidate-type set, at the root and at every node inside.
- `tys_app`: the composition step, stated as an equivalence — a formed
  application is typed exactly when the pools admitted its children slot by
  slot.
- Rejections as instances: `upper(3)` and `sorted(3)` are never formable.

## Run

    tools/dev/remote-build hbox src/extract/codeorgan Veri7vn_Codeorgan \
      --expect 'VERI7VN_CODEORGAN PASS'
    sh src/extract/codeorgan/build.sh
    var/codeorgan/bin/codeorgan --self
    var/codeorgan/bin/codeorgan --check list '(app at (app sorted_desc (arg 0)) (const 1))'
    PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/codeorgan/tables_check.py

`tables_check.py` asserts the binary's table (from the HOL constants) equals
the organ's own `P_` table for every transcribed move, and that the group
lists equal the organ's `GROUP` sets, so the two cannot drift.

## Honest status

- The organ types terms by observed values while the search runs them on the
  examples; this model types statically from the signature, admitting a child
  only when ALL its possible types connect (sound, slightly more
  conservative than the organ's optimistic observation).
- Output types transcribe the organ's declared column, which is wider than
  the real semantics in places (e.g. `fdiv` declared `num` but returning
  float on floats); the search never reads the declared column for typing, so
  this matches what the organ does, not what its table says.
- The execution check (running the rendered source against the examples) and
  the STORE layer (verified programs becoming library moves, typed by
  observed argument and output types) are not modelled here. The stored
  library's fifteen programs all have exact base-type signatures, which is
  the shape this model gives library entries.
- Untrusted parts: `main.sml` (parsing and printing) and `build.sh`; the
  generated checker is the only trusted code in the binary.
