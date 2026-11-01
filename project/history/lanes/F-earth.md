# F-earth: exact integer powers of ten

Scratch implementation over the checked Earth E snapshot. Live Earth D, staged
Earth E, live Climate F and staged Climate G are unchanged. Scoped proof, immutable diagnostic native and official panels pass; independent
actual dispatcher checks pass 4/4.

Seismology's energy ratio, amplitude ratio, inverse moment and GR count all use
powers of ten. The old kernel always evaluates them with interval exponentiation,
even when the exponent is an integer. A shared `ten_value` now chooses an exact
rational power (or its reciprocal) for integer exponents with absolute value at
most 256. It retains the existing precision and interval path otherwise. The
bounded fast path avoids introducing unbounded exponent work; it is not a new
scientific validity limit.

The checked semantic theorem states `xsem (ten_value e) = 10 powr rl e` for every
rational input. Separate actual-output equations prove the integer branch and the
unchanged fallback. Existing seismology model laws and renderer error laws continue to check against this changed implementation. The exact path also feeds
the energy/amplitude comparison in the clarification response.

First attempt 614a09fe267a failed only a propositional simplification in the false
branch after an integer-membership rewrite; retry 0ac448b85563 passed using `auto` to close
the remaining logical contradiction with the same statement.

Boundary probes cover 15 exponents including -257/-256/-255 and 255/256/257,
zero, positive/negative integers and two fractional exponents. Prior E answers
15/15 correctly. This is a performance improvement candidate, not an invented
new-answer claim. The paired benchmark will separately measure exact count,
negative-power count, exact energy/amplitude and fractional fallback routes.

The stage native helper was refreshed with the build owner's shared-lock fix.
It must record the main Git-common compiler lock and preserve all live family
convenience manifests. No extra outer lock is used.


## Checked diagnostic results

Proof: persvati `20261018T092247Z-0ac448b85563`,
`VERI7VN_EARTH PASS theorems=131 oracles=0`.
Generated SML: `aa6ba5e85d3853460b6b5c3c09320233006426a4318e05922f2b77bc7fe52a34`.
Native: `dfb4f3cf683040f98928c2f375db7abac33650ea1e13e2b6adce9ff8415c31be`,
929000 bytes (2864 bytes smaller than E).
Actual manifest: `var/earth/f-exact-powers/stage/var/earth/native-attempts/20261018T092709Z-90ee292c29c3/compile-inputs.json`.
The manifest records `/Users/ember/dev/o7vn/var/native-compile.lock`; the refreshed
shared helper preserves the stage's source context and metadata while serializing
compilation against other families. Frozen live convenience pointers are intact.

| Official scorer panel | Right | Wrong / false yes | Valid withheld |
|---|---:|---:|---:|
| All Earth shipped | 554 / 554 | 0 / 0 | 0 |
| Fresh offset 28701 | 354 / 354 | 0 / 0 | 0 |
| Reserved offset 33701 | 358 / 358 | 0 / 0 | 0 |
| Seismology shipped | 68 / 68 | 0 / 0 | 0 |
| Seismology fresh | 68 / 68 | 0 / 0 | 0 |
| Seismology reserved | 68 / 68 | 0 / 0 | 0 |

Fresh generators remain absent for hydrology and meteorology; these have shipped
evidence only. All 50 original Earth policies, all 29 E policies and all 15
exponent boundary answers pass. The latter 15 already passed on E; they are not
new capabilities. E's valid unsupported and malformed cases retain their separate
classification. The separate official seismology parity harness also scores 68/68; it remains
INCOMPLETE because head/core/self and admission checks were not run. This report
claims no six-criterion family admission.

| Paired local case | E median ms | F median ms |
|---|---:|---:|
| Integer GR count | 17.768 | 0.067 |
| Negative-integer GR power | 17.780 | 0.083 |
| Integer energy power | 17.755 | 0.126 |
| Integer amplitude power | 17.538 | 0.109 |
| Fractional GR fallback | 17.906 | 17.728 |
| Fractional energy fallback | 17.712 | 17.870 |

Each paired case used five timed repetitions after one warmup, with status, kind
and value equality checked. These are local measurements, not universal latency
promises. Shipped seismology median is 9.009 ms (E's preceding panel run was
17.765 ms); fractional work remains, so the full specialist is not below 5 ms.
Cold median is 3.625 ms. Other slow family panels are unchanged.

Evidence: `var/earth/f-exact-powers/panels/report.json`, `benchmark.json`,
`f-probes.json`, and `e-regression.json`. Four exact staged dispatcher prompts
are in `runtime-probes.json`. Root integration release, promotion of the exact
owned closure, immutable runtime capture remain.


Independent actual consumer: `var/C-runtime-consumers/staged-F-earth.json`
passes 4/4, binding exact native/capability/runtime hashes. It checks GR 0.0001,
energy 1000, amplitude 100, and fractional energy 177.8 with their expected kinds.
This is next-only staged composition; no production selection or independent
performance claim is implied.
