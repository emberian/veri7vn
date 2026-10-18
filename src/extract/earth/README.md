# Earth family kernel (lane S03-earth)

Eight Oracle7 specialists (geography, geology, seismology, hydrology, ocean,
meteorology, greenhouse, greenhouse-r2) as one verified HOL kernel exported to SML and
compiled into `var/earth/bin/earth`, which speaks the answerer contract.

What is proved: for each domain, a stated value equals the defining formula
(haversine on the 6,371 km sphere, decay law, Gutenberg-Richter, Manning, Magnus, Tetens,
heat index and wind chill regressions, ISA, and so on), declines are exactly the
underspecified / impossible / out-of-range predicates, and every printed number lies within
a proved bound of the real value (`render_x_sound`). Square roots, logs, exponentials,
powers, cosine and arctangent are enclosed with `HOL-Decision_Procs.Approximation`.
Tables are HOL constants checked by `tables_check.py` (a Python check, not a proof).
Not proved: the text layout (`render_dec`, `render_fixed`, ...), checked by the self test
and the panels.

Untrusted: `regex.sml`, `recognizer.sml` (hand port of each organ's regexes and branch
order), `main.sml` (JSON framing).

Build: `tools/dev/remote-build hbox src/extract/earth Veri7vn_Earth --expect 'VERI7VN_EARTH PASS'`,
then `sh src/extract/earth/build.sh`, `python3 -B src/extract/earth/score.py`.
Results and statements: `project/lanes/S03-earth.md`.
