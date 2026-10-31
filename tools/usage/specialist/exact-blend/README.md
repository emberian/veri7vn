# Supplied blend feasibility

This separate panel asks whether supplied stocks can make a requested kg batch
with one solute fraction interval. Fractions mean kg solute per kg stock.
Nonnegative stock quantities, availability, exact batch mass and both fraction
bounds become original rows `a*x <= b`. Equalities become two inequalities.
All quantities are exact rational strings. Stock completeness and exact fractions
are caller assumptions. There is no claim about safety or chemical compatibility.

With the native host running and exact reasoning enabled:

```
python3 tools/usage/specialist/exact-blend/examine.py --url http://127.0.0.1:8765
python3 tools/usage/exact_blend.py supplied-stocks.json --url http://127.0.0.1:8765
```

The client discovers the operation, calls the host, and independently substitutes
its feasible point or nonnegative Farkas multipliers into the original rows.
The proposer searches feasibility only. It does not minimize cost. Search limits
return unknown. Hand-derived cases cover a 50/50 blend, unavailable mass,
unattainable concentration and a rational stock boundary.

No panel numbers yet. These cases are separate from the shipped specialist
panels and cannot stand in for their scores. No Isabelle theorem is claimed.
