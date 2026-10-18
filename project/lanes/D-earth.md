# D-earth: model boundaries after the C packet

Status: active implementation, no D proof or final D panel claim yet. C results
remain in the C report. These rows are actual binary probes, not a completeness
claim; passing one boundary does not establish the full model. Raw replies:
`var/earth/d-domain/ledger-probes.json`.

| Specialist | Model boundary exercised | Actual result | Next concrete work |
|---|---|---|---|
| geography | Latitudes must lie in [-90,90]. | 95°N now produces impossible; composed dispatcher retains it. | Study longitude normalization and coincident/antipodal conditioning without reducing interval precision. |
| geology | A remaining fraction cannot be negative. | -25% is silently read as +25%, answered age 11460 y. | Shared exact numeric lexer; bind accepted fraction to full signed source token and retain existing kernel range guard. |
| seismology | Supplied coefficients retain their sign. | b=-1 is treated as absent, yielding underspecified. | Preserve typed signed Gutenberg–Richter coefficients; distinguish mathematically defined model from plausible calibrated parameters. |
| hydrology | Runoff fraction C is in [0,1] under the simple precipitation-partition model. | C=1.5 becomes 1 and answers 0.5556 m3/s. | Consume complete number; add kernel coefficient feasibility and conservation bound Q<=i*A (with units). |
| ocean | Echo duration is nonnegative; sound speed is positive. | -2 seconds becomes +2, answering depth1500m. | First D implementation: shared numeric lexer + complete typed feasibility for all six requests + model-bound conservation/nonnegative laws. |
| meteorology | RH must be positive and <=100 for dew-point inversion. | -50% produces impossible. | Check empirical model applicability separately from algebraic poles; high/low RH proof does not establish calibration range. |
| greenhouse | A daily light integration duration lies within a day. | 30h/day gives DLI54 without qualification. | Bound daily duration to [0,24], positive duration for PPFD inversion; preserve zero-light case and bind DLI/PPFD inversion. |
| greenhouse-r2 | Same daily duration semantics as greenhouse. | Same DLI54 response. | Shared kernel repair, both specialist consumers. |

## First implementation: ocean physical feasibility

Keep the current six computations and declared constants. Make complete signed
inputs reach the typed kernel, with guards:

- Echo: elapsed time >=0 and sound speed >0.
- Gauge/absolute pressure: depth >=0 and density >0.
- Shallow wave speed: depth >=0 (zero depth gives zero model speed).
- Tsunami travel: depth >0 and travel distance >=0.
- Deep-water speed/wavelength: period >0.

These are assumptions of the existing scalar models, not a general description
of every wave or ocean state. Bind successful output to physical feasibility,
round-trip echo distance, pressure increment, and wave distance/time laws already
connected to the computation. Add explicit impossible equivalences and scan every
new theorem. Negative tests cover each independent argument, zero boundaries,
and full source token consumption. Ordinary shipped/fresh panels must retain
scores; composed refusals need explicit accepted domain context.

The shared lexer is being implemented by /root/natural/chemistry_parser under
commons/numeric.sml. This lane will adopt it selectively after Earth C captures
and freezes. No new lasting numeric regex helper belongs here.

## Work prepared while C finishes

Prepared files are `var/earth/d-domain/Earth_Ocean.thy` and `recognizer.sml`,
with 20 boundary and lexical probes in `ocean-probes.json`. Current family source
is still the C proof candidate. The scratch reader compiled against the previous
checked kernel: .5, 1/2 and 5e-1 seconds all yield 375m; malformed 1.2.3 and a forged
qnum0q marker are not taken. Negative -2s now reaches the old kernel as -1500m,
showing why lexer preservation and kernel feasibility are both required.

Initial scratch reader shipped scoring: dev 23/23, heldout 20/23, wrong 0, false yes 0.
All three misses are hyphenated wave periods (10-second, 8-second, 12-second);
the shared lexer owner fixed the token-boundary issue. Rebuilt scoped consumer
now passes 46/46 (23 dev, 23 heldout), zero wrong/false yes. The new physical kernel
still needs to be checked after C capture.

## Further model-selection counterexample

The current Ocean reader answers "What is the group velocity of a deep-water
wave with period 10 seconds?" with 15.61 m/s. That is the phase speed. Under the
same deep-water dispersion model, omega²=g*k, the derivative d(omega)/dk gives
group speed g*T/(4*pi), about 7.80655 m/s. This is an actual wrong answer outside
the shipped panel (`var/earth/d-domain/group-speed-gap.json`). After completing
the feasibility packet, the next algorithmic extension should distinguish phase
and group requests and bind the group computation to that dispersion law; merely
adding physical-domain guards will not fix this selection error.

A second full-token counterexample affects Gutenberg–Richter: with a=6, b=1 and
magnitude threshold 10, the current reader takes only the digit 1 and answers
100000/year instead of the declared model's 0.0001/year. Exact reply:
`var/earth/d-domain/magnitude-gap.json`. The shared lexer should consume the full
threshold and signed regional coefficients; an arbitrary one-digit magnitude
restriction is not a domain property of the exponential count model.

The group-speed implementation is now prepared separately in
`var/earth/e-group/Earth_Ocean.thy` and `recognizer.sml`; it has not been promoted
or checked. It adds a distinct `ODeepGroupSpeed` request and `deep_group_speed`
kind, evaluates g*T/(4*pi), and proposes a theorem connecting a successful answer
to the derivative of omega(k)=sqrt(g*k) whenever the supplied period satisfies
omega*T=2*pi. A second law ties group speed to half the successful phase speed.
This extends the pending Ocean feasibility source and keeps current C source
frozen. The new runtime kind will need explicit capability acceptance when promoted.
