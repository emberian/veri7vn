# Swarm batches (wave 4)

Every batch copies lane G's recipe (`src/extract/quantity/`): one HOL kernel per family, tables transcribed with a check script, untrusted recognizer, MLton binary, scored with `tools/parity/harness.py` on each specialist's shipped panel. Commit after each specialist lands.

| Batch | Model | Specialists |
|---|---|---|
| S01-mechanics | sonnet | physics, physics-r2, physics-r3, mechanisms, mechanisms-v2, bodies-v2, sports, fleet, fluids-r2 |
| S02-space | sonnet | orbits, planetary, spacecraft, spacecomms, astronomy, astronomy-v2, astronomy-v3, astronomy-v3-r2 |
| S03-earth | sonnet | geography, geology, seismology, hydrology, ocean, meteorology, greenhouse, greenhouse-r2 |
| S04-em-optics | sonnet | electrical, electronics, electronics-r2, wiring, optics, optics-v2, optics-v3, optics-v5, optics-v5-r2 |
| S05-climate | sonnet | airquality, carboncapture, carbonmat, climate, coldchain, coldchain-v2 |
| S06-energy | sonnet | energy-v2, energy-v3, hvac, thermo, renewables, iot |
| S07-chemistry | sonnet | chemistry, chemistry-v3, decay, labsolutions, labsolutions-r2 |
| S08-materials | sonnet | additive-v2, materials-v2, soil, soil-r2, water, water-r3 |
| S09-life | sonnet | biology, ecology, forestry, wildlife, microbiology-v2, genetics-v2 |
| S10-anatomy-agri | sonnet | anatomy, anatomy-r2, agriculture-v2, gardening, nutrition-label-v2 |
| S11-geometry-stats | sonnet | geometry, geometry-v3, geometry-v4, statistics, statistics-v2, statistics-v3 |
| S12-discrete | sonnet | algorithms, calculus, dataformats, games-v3, logic-v3 |
| S13-finance | sonnet | economics, finance, finance-v2, finance-v2-r2, retail |
| S14-trades | sonnet | architecture, crafts, printing, printing-v2, safety, woodworking |
| S15-computing | sonnet | cyber, embedded, networking, linux-v2, git, sql, python, python-r2, robotics-v2 |
| S16-humanities | sonnet | grammar, music-v2, music-v2-r2, mythology, ushistory, library, government |
| S17-variants | sonnet | densities-r2, units-v2, units-v3-r2 |
| O18-cooking-warehouse | opus | cooking, cooking-v2, cooking-v3, cooking-v3-r2, warehouse, warehouse-r2 |
| O19-facts | opus | arthistory, botany, childdev, entomology, etiquette, firesafety-v2, firstaid, javascript, law, linguistics, literature-v2, marinebio, medicine, medicine-r2, mycelial, mycology, ornithology, pets, poetry, psychology, sociology, worldhistory |

137 specialists in 19 batches; 7 already lifted; 161 `rel-*` readers wait on the missing stores.
