# acoustics-veri7vn: the verified acoustics kernel as an Oracle7 specialist

This folder is an Oracle7 specialist. It answers the same sound questions as
Oracle7's own `acoustics` specialist (speed of sound, wavelengths, decibels,
Doppler shift, pipes and strings, beats). The work is done by a small program
built by veri7vn, whose formulas and refusals are proved correct in Isabelle.

## Use it

1. Build the program in a veri7vn checkout (see `../README.md`); it ends up at
   `var/acoustics/bin/acoustics`.
2. Copy this folder into `root/specialists/` of an Oracle7 install.
3. Tell the folder where the program is: either put it at `bin/acoustics` inside
   this folder, or set `VERI7VN_ACOUSTICS_BIN=/path/to/acoustics`.
4. Run Oracle7's exam on the practice questions. The shipped `oracle7.py` has
   no `exam` command; the exam is `run(folder, "dev", engine)` in
   `workbench/exam.py` (the Workbench calls it). In a veri7vn checkout,
   `.venv/bin/python src/extract/acoustics/exam_dev.py` does this on a scratch
   copy of the folder, so nothing is written into the Oracle7 install.

Only use the `heldout` questions for a real admission exam, once: Oracle7 records
that they were used.

## What is in the folder

| File | What it is |
|---|---|
| `manifest.json` | Oracle7's description of the specialist: what it accepts, its budget |
| `organ_acoustics_veri7vn.py` | starts the program once and passes each question to it |
| `acoustics_panel_v1.json`, `acoustics_scorer.py` | copies of the shipped acoustics questions and scorer (see `NOTICE`) |
