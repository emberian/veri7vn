# Beyond parity

Parity was the first scoreboard: every lifted specialist answers its shipped
panel the way the shipped organ does, with 0 wrong. The second scoreboard keeps
the one law that makes the project worth anything, **0 wrong**, and moves the
other numbers up. A "beyond" lane (B-lane) takes one landed family and does five
things, in this order, measuring each.

## What the shipped folders give us

Every specialist folder ships its **panel generator** (`*_panel_v*.py`, 151 of
them): the author's own program that writes dev and held-out items from a seed,
with answers computed from a table written separately from the organ. That is
the specialist's intended domain in executable form. Running it with fresh
seeds gives new held-out panels nobody has seen, so "beyond" can be measured
without us writing the questions ourselves. (A generator shares its author's
blind spots; say so, and never tune to a fresh panel you then score on.)

## The five steps

1. **Fresh panels.** Run each specialist's generator with two new seeds into
   `var/<slug>/fresh/` (never under `upstream/`, never committed). Score the
   shipped organ and the kernel on them through the harness. Report both. This
   is the baseline: parity on questions neither saw.
2. **Reachable misses.** List every item, shipped or fresh, where the organ is
   wrong or withholds but the panel's own answer is computable from the
   kernel's existing kinds (the chemistry "(NH4)2SO4" case: the kernel computes
   the full formula, the recognizer reproduced the organ's misread). Fix the
   recognizer (untrusted, so test it on both panels) and, where the organ's
   kind set was the limit, add the kind to the kernel with its binding theorem.
   The shipped-panel number may now exceed the shipped verdict; wrong must stay 0.
3. **Coherent extension.** Read the organ's docstring, its manifest `accept`
   list and its generator: what did the author plainly intend that the organ
   never finished? (Optics v1/v2's direction defect; economics' three
   phrasings; cooking's "What's the X content" leak; genetics' phenotype
   ratios; acoustics' temperature-dependent speed everywhere.) Implement the
   smallest coherent completion, each new kind with its defining-equation
   theorem and its decline conditions, and measure it on the fresh panels and
   on 20 hand-written probes you commit with their expected values and source.
4. **Efficiency.** Cold start under 20 ms (the interval-arithmetic tables that
   cost life 230 ms and finance 270 ms at start-up must be lazy or
   precomputed), p50 within a tenth of the manifest budget, binary under 1 MB,
   no `Approximation` call above the precision the scorer needs.
5. **Assurance.** Apply A1's audit (`docs/assurance/theorem-audit.md`): add the
   missing binding theorems it names for this family; retire vacuous ones.

## The numbers a B-lane reports

| | shipped panel | fresh panels (2 seeds) | probes |
|---|---|---|---|
| shipped organ | right / wrong / withheld | same | same |
| kernel before | same | same | same |
| kernel after | same | same | same |

plus cold start, p50, size, binding theorems before/after, and the list of
items still withheld with the reason (store gap, genuine ambiguity, out of the
family's domain). Nothing is "beyond" if wrong is not 0 everywhere.

## Rules

Same as `LANE_BRIEF.md`. Remote builds. Marker last, `oracles=0`. One commit per
step with its numbers. A B-lane never edits another family. Tier: sonnet for
steps 1, 2, 4; opus when step 3 needs a new kernel kind with interval
arithmetic or a search.
