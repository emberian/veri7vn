# U3 weather: select the registered v2 consumer

Status: source frozen; narrow registration/family checks pass. The application
lane is waiting for root's refreshed U3 runtime candidate to run one actual
Engine/catalog smoke. No immutable runtime, deployment, kernel or build changed.

The repaired v2 bundle was packaged but unreachable through the active weather
families. Fold w504 reads `standing_v1.txt`; w548, w554 and w563 read
`standing_v2.txt`. Both named only `meteorology`. The application catalogue was
correct to advertise the registered legacy reader rather than invent a live v2
operation from the presence of a folder.

Each of those two lists now replaces its single `meteorology` entry with
`meteorology-v2`. This preserves list length and position and selects one weather
owner. Adding both versions would produce two matching answers and prevent
later exactly-one-owner fallback rules from retaining a useful answer. The
legacy bundle and both network lists are preserved: their byte IDs bind learned
plans, and changing those IDs is unnecessary for direct family selection. A
registered legacy operation can still be exposed truthfully alongside the
selected v2 family operation.

Changes in the private upstream contribution checkout:

- `root/specialists/_gate/standing_v1.txt`
- `root/specialists/_gate/standing_v2.txt`
- `tests/meteorology_v2/test_weather_registration.py`

`var/u3-weather/source-snapshot.json` records source hashes, exact changed list
positions and unchanged list lengths. No w571, premise, service or original
upstream source was edited by this lane.

Validation command, exit zero:

```sh
python3 -B -m unittest discover -s var/ap1-upstream-slim/tests/meteorology_v2 -v
```

Nine test methods pass. The original legacy panel stays 98/98; v2 stays 110/110;
the actual Family/_Organ loader applied to the weather selection from each
active list scores 110/110. All official panel runs have zero wrong, zero false
yes and zero withheld-valid answers, including six correct refusals. Existing
coexistence tests check either loading order; registration tests check the
selected owner, malformed and negative ISA, ambiguous dew labels, supported
legacy behavior, and unchanged legacy network identities. These are scoped
family tests, not a claim that the whole Engine has already been checked.

This is explicit candidate registration. It does not extend a historical ADMIT
receipt or published release hash to modified code. The previous AP1 repair
record explains the legacy verdict-format mismatch and needed fresh admission
and release process. No verdict or release-hash file was rewritten here.
