# Lane W6-15-geostats: negative lengths, complete modes (2026-10-18)

Family `src/extract/geostats/` (geometry, geometry-v3, geometry-v4, statistics, statistics-v2,
statistics-v3). Session `Veri7vn_GeoStats`.

## The defect and the fix

`g_kernel (G_cube_volume (Some (-2)))` used to answer `-8`. The kernel now declines any request
that carries a zero or negative length with `GImpossible GR_nonpositive_length` (reply kind
`impossible`, text "A length must be positive, so I won't compute that."). Lengths a request
carries are listed by the new `glens`. A leg not shorter than the hypotenuse is still reported as
`GR_leg_ge_hyp` first, and the triangle inequality still reports Heron's three sides (it already
forces every side positive), so `leg_decline_iff` and `heron_decline_iff` are unchanged. The eight
exact `*_value` theorems (cube, box, rectangle, square, triangle) now assume positive dimensions;
before, they claimed an answer for every number, negatives included.

Recognizer: untouched. The organs' number pattern has no sign (`(\d+(?:\.\d+)?)`), so the
recognizer never builds a negative geometry length; the decline matters for the kernel's own
contract, not for the panels.

## New theorems (verbatim)

```
theorem g_lengths_positive:
  assumes "\<forall>w. g_kernel r \<noteq> GDecline w"
  shows "\<forall>l\<in>set (glens r). 0 < l"

theorem cube_volume_nonpositive_iff:
  "g_kernel (G_cube_volume (Some s)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> s \<le> 0"

theorem cube_surface_nonpositive_iff:
  "g_kernel (G_cube_surface (Some s)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> s \<le> 0"

theorem square_area_nonpositive_iff:
  "g_kernel (G_square_area s) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> s \<le> 0"

theorem square_perimeter_nonpositive_iff:
  "g_kernel (G_square_perimeter s) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> s \<le> 0"

theorem circle_area_nonpositive_iff:
  "g_kernel (G_circle_area (Some r)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> r \<le> 0"

theorem rect_area_nonpositive_iff:
  "g_kernel (G_rect_area (Some l) (Some w)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow>
     l \<le> 0 \<or> w \<le> 0"

theorem box_volume_nonpositive_iff:
  "g_kernel (G_box_volume (Some l) (Some w) (Some h)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow>
     l \<le> 0 \<or> w \<le> 0 \<or> h \<le> 0"

theorem hypotenuse_nonpositive_iff:
  "g_kernel (G_hypotenuse a b) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> a \<le> 0 \<or> b \<le> 0"

theorem leg_nonpositive_iff:
  "g_kernel (G_leg c (Some a)) = GDecline (GImpossible GR_nonpositive_length) \<longleftrightarrow> a < c \<and> a \<le> 0"

theorem box_volume_is_area_times_height:
  assumes "g_kernel (G_box_volume (Some l) (Some w) (Some h)) = GExact k v"
    and "g_kernel (G_rect_area (Some l) (Some w)) = GExact k' a"
  shows "v = a * h"

theorem cube_volume_is_area_times_edge:
  assumes "g_kernel (G_cube_volume (Some s)) = GExact k v"
    and "g_kernel (G_square_area s) = GExact k' a"
  shows "v = a * s"

theorem cube_surface_is_six_faces:
  assumes "g_kernel (G_cube_surface (Some s)) = GExact k c"
    and "g_kernel (G_square_area s) = GExact k' a"
  shows "c = 6 * a"

theorem rect_area_is_two_triangles:
  assumes "g_kernel (G_rect_area (Some b) (Some h)) = GExact k a"
    and "g_kernel (G_tri_area (Some b) (Some h)) = GExact k' t"
  shows "a = 2 * t"

theorem square_perimeter_is_rect_perimeter:
  assumes "g_kernel (G_rect_perimeter (Some s) (Some s)) = GExact k p"
    and "g_kernel (G_square_perimeter s) = GExact k' q"
  shows "p = q"

theorem angle_sum_step:
  assumes "g_kernel (G_angle_sum n) = GCount k a" and "g_kernel (G_angle_sum (n + 1)) = GCount k' b"
  shows "b = a + 180"

theorem modes_complete:
  assumes "x \<in> set xs" and "\<forall>y. count_list xs y \<le> count_list xs x"
  shows "x \<in> set (smodes xs)"

theorem cube_volume_value:
  assumes "0 < s"
  shows "g_kernel (G_cube_volume (Some s)) = GExact GK_cube_volume (s * s * s)"

theorem box_volume_value:
  assumes "0 < l" "0 < w" "0 < h"
  shows "g_kernel (G_box_volume (Some l) (Some w) (Some h)) = GExact GK_box_volume (l * w * h)"
```

Also scanned now: `leg_missing`, `circle_missing` (they were the two unscanned theorems).
New helper lemmas (not headline): `heron_sides_pos`, `glens_pos`, `foldr_max_le`.

What they say: `g_lengths_positive` says no non-declined answer carries a non-positive length (any
kind, via `glens`); the `*_nonpositive_iff` theorems state the decline exactly as inequalities on
the dimensions, separately from the code's `glens` test; the cross-kind laws tie box to
rectangle, cube to square, cube surface to six faces, rectangle to two triangles, square to
rectangle perimeter, and one more polygon side to +180 degrees; `modes_complete` says every value
tied for most frequent is reported (only soundness, `modes_value`, existed).

## Counts (audit scripts, `tools/audit/extract.py` then a per-family count over `var/audit/class/geostats.txt`)

| | statements | vacuous | definitional | binding | helper | example | unscanned theorems | marker |
|---|---|---|---|---|---|---|---|---|
| before | 110 | 0 | 30 | 45 | 35 | 0 | 2 (`leg_missing`, `circle_missing`) | last, oracles=0 |
| after | 130 | 0 | 30 | 62 | 38 | 0 | 0 | last, `theorems=90 oracles=0` |

Binding share of claims: 60% before, 67% after (62 of 92). `tools/audit/markers.py`:
`thm=86 unscanned_thm=0 marker_last=True oracle_scan=True bad=[]`. The `var/audit/class/geostats.txt`
file is lane scratch (not in git); the 17 new theorems are classed B there.

## Checks

- Remote build on persvati (shared checkout dir; first attempt was killed by the host, then three
  builds fixing my own proof slips: two glens_pos/heron_sides_pos method errors and a missing `rat`
  type; every other new theorem passed first time). Last build: `VERI7VN_GEOSTATS PASS theorems=90 oracles=0`.
- `tables_check.py`: PASS, 62 checks.
- Binary rebuilt from the persvati export of that session (`isabelle export -n -x '*:code/**'`),
  `var/geostats/bin/geostats` 613,528 bytes. Note: `remote-build` returned a stale
  `export-remote/.../geostats.ML` this time; I took the SML by hand from the session database on
  persvati into `var/geostats/export-w615/geostats.ML`.
- Harness, all six specialists, both splits, `PYTHONDONTWRITEBYTECODE=1`: ok = n on every panel
  (106/97, 100/100, 100/93, 142/142, 144/144, 144/144), wrong 0, false yes 0. Compared item by item
  with the pre-change binary over 1,456 items on status, response, kind, value, path: 0 differences.
  No item turned from a negative-length answer into a decline (none contained one).

## Remaining

- The panels have no negative or zero length, so the new decline is proved but not exercised by a
  panel item.
- `scomb`/`sperm` and other stats declines were not touched.
