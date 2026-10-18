# Discrete continuation — 18 October 2026

The regular packet is checked and ready to integrate. Polynomial requests now
handle derivative orders 1–50 and primitives. Unsafe interpretations refuse the
turn decisively, including through the front dispatcher. Explicit anagram words
such as LETTER are accepted. No commit was made by this lane.

## Changed files and behavior

Regular packet: `src/extract/discrete/{Disc_Calc.thy,recognizer.sml,capabilities.json,
beyond.py,probes.py,README.md}` and this report. No shared source paths changed.

- Existing exact repeated differentiation now serves orders 1–50, both symbolic
  and evaluated at a point. The reply names orders above four correctly.
- “Primitive” and “anti-derivative” reach the existing antiderivative function.
- Zero denominators, conflicting explicit variables, partial numeric matches and
  unsupported orders produce taken `unsupported` refusals, with a message about
  the interpretation boundary. A conflicting variable is not declared
  mathematically impossible. Acceptance and new routing words are declared in
  capabilities.json, so dispatch does not drop those refusals and fall through.
- LETTER and other explicitly named words no longer masquerade as missing-word
  anagram requests.

The recognizer remains untrusted. These checks improve interpretation empirically;
they do not prove the English-to-request mapping. The capability declaration is
static information, not a per-answer proof.

## Actual checks

Final proof receipt:
`var/discrete/remote-attempts/20261018T063943Z-788a69334a1f/receipt.json`.
Its actual terminal log says `Finished Veri7vn_Discrete (0:01:33 elapsed time)`;
the whole session log contains `VERI7VN_DISCRETE PASS theorems=81 oracles=0`.
No cancellation occurred. Current HOL inputs match the immutable proof snapshot.
A later untrusted-recognizer correction required only MLton: the variable check
now requires `=` after from/to, so “tangent to f(t)” does not mistake f for a
requested integration variable. This was caught by ten shipped heldout cases.

Final exported SML SHA256:
`8edfe065fbdb7db7bf01a498204c09d03577bedf4da21d61c8f5ace73af0fc10`.
Final Darwin binary SHA256:
`a412cc0860f3e9d1abebb7639df74e9145081ead57f52acba76157d5783f1f98`.
`tables_check.py`: **102/102 checks pass**. Python syntax, capability validation
and `git diff --check` pass.

Shipped panels, before and after, in both specialist and family modes:

| Specialist | Dev right/wrong/false yes/valid withheld | Heldout |
|---|---|---|
| games-v3 | 51/0/0/0 | 18/0/0/0 |
| logic-v3 | 33/0/0/0 | 12/0/0/0 |
| dataformats | 93/0/0/0 | 93/0/0/0 |
| algorithms | 42/0/0/0 | 42/0/0/0 |
| calculus | 62/0/0/0 | 62/0/0/0 |

Total **508/508 right**, zero wrong/false yes/valid withheld per mode. Receipt:
`var/discrete/codex/shipped-final.json`. No claim of a fresh full six-criterion
head/core/lane/self run is made.

Fresh supplied-generator seeds 181013 and 181027 cover games, logic and formats.
Both the original organ and old binary scored **599/600 right**, zero wrong/false
yes, one valid withheld (LETTER). The new recognizer scores **600/600**. The third
seed, 181043, was untouched until those changes froze: **300/300 new vs 298/300
original organ**, zero wrong/false yes. These use their shipped independent
scorers, but share their authors' generator tables/templates. The later calculus
qualifier fix changes none of these three specialists' recognizers.

Each fresh seed has games dev51/heldout18, logic33/12, formats93/93. All are right
in the new binary. The original games dev score is50,51,49 for the three seeds;
all other original splits are perfect. Receipts:
`var/discrete/codex/fresh-before/report.json` and
`var/discrete/codex/fresh-final/report.json`. Algorithms and calculus generators
are absent from the supplied snapshot; no fresh-generator claim is made for them.

The 24 authored calculus development probes improve from **6 right / 6 wrong /
10 false yes / 2 valid withheld** to **24 right / 0 / 0 / 0**. Expectations use the
shipped polynomial/value scorer plus requested-order prose checks. All ten unsafe
cases return taken `unsupported` refusals. The author also changed the recognizer;
these probes are not independent evidence. Receipt:
`var/discrete/codex/probes-final.json`.

Consumer check: the same 24 probes plus a tangent-function regression and a
conflicting integration-variable refusal pass **26/26 pinned and 26/26 unpinned**
through actual `dispatch.py --order front --organs discrete --no-reader
--no-document --no-routes`. Refusals retain `dispatch.decisive=true`. This tests
acceptance/arbitration/fallthrough, not all-family collisions or the complete head.
Receipt: `var/discrete/codex/dispatch-final.json`. Linux refresh is still pending;
the previous family receipt does not cover this changed executable.

## Assurance statements and limits

The existing, scanned statements still support the extended computation:

```
pder_n_derivative:
  ((\<lambda>x. pev (pder_n k p) x) has_field_derivative
     pev (pder_n (Suc k) p) x) (at x)

c_deriv_at_sound:
  c_kernel (C_deriv_at p v (Suc k) x0 tg) = CAt n q val x0' tg'
  \<Longrightarrow> val = peval (pder_n (Suc k) p) x0 \<and>
    ((\<lambda>x. pev (pder_n k p) x) has_field_derivative of_rat val)
      (at (of_rat x0))

c_reply_answered:
  answered (c_reply r) \<longleftrightarrow> (\<forall>k. c_kernel r \<noteq> CNeed k)
```

There is no new theorem-count claim. The new refusal uses the existing exact
answered/declined contract. The definite integral is still connected only to the
antiderivative endpoint difference and derivative, not yet to `has_integral`.
An isolated analysis bridge draft is preserved in
`var/discrete/codex/integral-draft/{ROOT,Disc_Calc_Integral.thy}`. It is unverified,
unlaunched scratch, outside production source. Its intended guarantees are the
real integral over ascending bounds and the negative integral for reversed bounds.
A future remote attempt must restore the draft under src; remote snapshots include
src/tests only. Root has held new proof submissions while the old queue drains.

MST soundness/minimality are unchanged; `kruskal_passes_cert` remains open, with
certificate failures withheld. Digests/JSON retain their earlier tested-only
boundaries.

## Efficiency and infrastructure caveats

Final binary **904,360 bytes**. Specialist round-trip p50 ranges **0.044–0.134 ms**,
well under one tenth of the 50 ms budget. Final cold process launches were
**89.17, 4.32, 4.38, 4.13, 3.38 ms**. Thus the all-cold-starts-under 20 ms target is not
established. Baseline first launch was 80.6 ms followed by 3.5–4.2 ms; the cause of the
first-launch difference is not attributed.

Generated SML still contains eager `val st0` through `val st34` tests, although
those tests already run at build time and the driver refers to none. Removing
the export roots is a measured candidate to investigate, not a claimed speedup.
Do not hold this checked packet for that optional change.

The first request `20261018T063157Z-f26f8134c57c` had a collector SSH255 failure;
the build owner confirmed/canceled its superseded queued worker. Its recovered
result is `cancelled while queued`, no proof and no published export. Only the
later actual build cited above is accepted evidence.
