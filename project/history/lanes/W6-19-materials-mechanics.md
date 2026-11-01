# Lane W6-19 materials and mechanics: six cross-kind laws

Files changed: `src/extract/materials/Materials.thy`, `Materials_Export.thy`,
`src/extract/mechanics/Mechanics.thy`, `Mechanics_Export.thy`. Each law relates two
kinds the family computes, or a kernel value to the real-number model; none restates
a defining equation. All six are in the export theory's oracle scan.

## Materials (Veri7vn_Materials)

    theorem classify_total:
      assumes "sa + si + cl = 100" "0 <= sa" "0 <= si" "0 <= cl"
      shows "classify (sa, si, cl) ~= None"

The texture triangle has no gap: every complete texture gets a class. (Proved
by `auto` over the negated conditions. A 0.25-step grid check in Python agrees.)

    theorem volumetric_is_gravimetric_times_bulk_density:
      assumes "kernel (VolWaterContent (Some w) (Some d) (Some bd)) = Exact k v"
        and "kernel (WaterContent (Some w) (Some d)) = Exact k' g"
      shows "v = g * bd"

    theorem mesh_vertices_faces_inverse:
      assumes "kernel (MeshVertices f g) = Exact k v"
        and "kernel (MeshFaces v g) = Exact k' f'"
      shows "f' = f"

## Mechanics (Veri7vn_Mechanics)

    theorem kinetic_energy_momentum:
      assumes "kernel (PhKE (Some m) (Some v)) = Exact c e"
        and "kernel (PhMomentum (Some m) (Some v)) = Exact c' p"
      shows "2 * e * m = p ^ 2"

    theorem drop_energy_conserved:
      assumes "0 <= h" and "kernel (PhPE (Some m) (Some h)) = Exact c e"
      shows "rl m * phys (PhImpact h) ^ 2 / 2 = (rl e :: real)"

The kinetic energy at the real-number impact speed equals the potential energy the
kernel states (stronger than the audit's form, which used `m * g0 * h` directly).

    theorem stopping_is_reaction_plus_braking:
      assumes "kernel (FvStopping (Some v) (Some mu) (Some rt)) = Exact c s"
        and "kernel (FvBraking (Some v) (Some mu)) = Exact c' b"
      shows "s = spd v * rt + b"

## Counts (audit classes, recounted with copies of tools/audit under var/w6-19/audit)

| Family | Statements | Binding before | Binding after | Vacuous | Unscanned | Marker |
|---|---|---|---|---|---|---|
| materials | 84 -> 87 | 57 | 60 | 0 | 0 | last, `theorems=67 oracles=0` |
| mechanics | 86 -> 89 | 42 | 45 | 0 | 0 | last, `theorems=67 oracles=0` |

Vacuous was already 0 and there were no `by eval` proofs, so nothing was retired.

## Checks

- Materials built on persvati, first attempt: `VERI7VN_MATERIALS PASS theorems=67 oracles=0`.
- Mechanics: three persvati builds were SIGTERMed by the shared swarm slice while the box was
  loaded (the theories had finished; no marker). Built on hbox: `VERI7VN_MECHANICS PASS
  theorems=67 oracles=0`.
- Binaries rebuilt with MLton from the new exports into `var/w6-19/{materials,mechanics}/bin/`
  (same sizes as before). Harness over all 15 specialists (both splits, 1,611 replies, 583 of
  them against the committed binaries): replies identical (id, status, response, value) to
  the committed binaries. Panels: every item answered (n=ok, 0 wrong, 0 false yes) as before.
  The older `var/mechanics/parity` files are stale (pre W5-12) and differ on 11 mechanisms
  items; the committed binary matches the new one on those.
- `water-r3` has no panel (NO PANEL) as before.

## Remaining

`var/materials/bin` and `var/mechanics/bin` were not overwritten; the code generated is the
same function set (definition order differs only). Consumer: the theorem audit table.
