#!/usr/bin/env python3
"""Execute actual shipped specialists; these observations are not native proofs."""
from pathlib import Path
import importlib.util
import json
import sys
ROOT = Path(__file__).resolve().parents[3]
def load(relative, name):
    directory = ROOT / 'upstream/root/specialists' / relative
    sys.path.insert(0, str(directory.parent))
    spec = importlib.util.spec_from_file_location(name, directory)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    sys.path.pop(0)
    return module
units = load('units/organ_units_v1.py', 'original_units').UnitsOrgan()
springs = load('springs/organ_springs_v1.py', 'original_springs').SpringsOrgan()
CASES = [(units, 'Convert 94 mm to inches', 470/127),
         (units, 'Convert 435 weeks to minutes', 4384800),
         (units, 'Convert 0 Celsius to Fahrenheit', 32),
         (springs, 'A spring has k = 200 N/m and stretches 10 cm. What is the force?', 20),
         (springs, 'A spring has k = 200 N/m and stretches 10 cm. What is the energy?', 1)]
for organ, text, expected in CASES:
    result = organ.answer(text)
    assert result and result['status'] == 'answered', (text, result)
    assert abs(result['value']-expected) <= 1e-12*max(1,abs(expected)), (text,result)
    print(json.dumps({'input':text,'original':result,'native_exact_target':str(expected)}))
for text in ['A spring has k = 0 N/m and force 20 N. How far does the spring stretch?',
             'A spring stretches 0 m under 20 N. What is the spring constant?']:
    try:
        result = springs.answer(text)
    except ZeroDivisionError:
        result = {'exception':'ZeroDivisionError','repair':'native None before division'}
    print(json.dumps({'input':text,'original':result}))
