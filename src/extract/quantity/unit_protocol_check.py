#!/usr/bin/env python3
"""Untrusted checks for optional typed quantity unit metadata, not a proof.

Run against a centrally rebuilt binary. --baseline optionally compares original
status/response/value/path/kind/id fields to an older binary, ignoring timings.
--emit-sml-checks prints typed constructor checks for central MLton compilation
AFTER generated kernel, commons, recognizer and main.sml; run with stdin at EOF.
The script never builds Isabelle or compiles binaries itself.
"""
import argparse
from decimal import Decimal
import json
from pathlib import Path
import re
import subprocess

HERE = Path(__file__).resolve().parent
# Constructor coverage independent of English recognizer reachability. Some
# legacy pressure constructors currently have no direct English dispatch.
TYPED = [
    ('Density', 'Q.Density m', 'kg/m3'),
    ('MassOf', 'Q.MassOf (m, NONE, Q.U_gram)', 'g'),
    ('VolumeOf', 'Q.VolumeOf (m, NONE, Q.U_litre)', 'L'),
    ('Floats', 'Q.Floats (m,m)', None),
    ('Convert', 'Q.Convert (one, Q.Lin Q.U_kilojoule, Q.Lin Q.U_joule)', 'J'),
    ('ConvertDelta', 'Q.ConvertDelta (one, temp_c, temp_k)', None),
    ('SpringForce', 'Q.SpringForce (NONE,NONE)', 'N'),
    ('SpringExtension', 'Q.SpringExtension (NONE,NONE)', 'm'),
    ('SpringConstant', 'Q.SpringConstant (NONE,NONE)', 'N/m'),
    ('SpringEnergy', 'Q.SpringEnergy (NONE,NONE)', 'J'),
    ('SpringPeriod', 'Q.SpringPeriod (NONE,NONE)', 's'),
    ('SpringFrequency', 'Q.SpringFrequency (NONE,NONE)', 'Hz'),
    ('PressureGauge', 'Q.PressureGauge (m,NONE)', 'Pa'),
    ('PressureAbs', 'Q.PressureAbs (m,NONE)', 'Pa'),
    ('Buoyant', 'Q.Buoyant (m,NONE)', 'N'),
    ('Submerged', 'Q.Submerged (m,m)', '1'),
    ('FuelEnergy', 'Q.FuelEnergy (f,NONE,Q.U_megajoule)', 'MJ'),
    ('FuelCO2', 'Q.FuelCO2 (f,NONE)', 'kg'),
    ('FuelMassNeeded', 'Q.FuelMassNeeded (f,(one,Q.U_joule))', 'kg'),
    ('FuelNCV', 'Q.FuelNCV f', 'MJ/kg'),
    ('Hydrostatic', 'Q.Hydrostatic (Q.ReferenceDensity m,NONE,(one,Q.G_mps2),(one,Q.U_pascal),true)', 'Pa'),
    ('FuelUsefulEnergy', 'Q.FuelUsefulEnergy (f,NONE,Q.U_kilojoule,NONE)', 'kJ'),
    ('FuelUsefulMass', 'Q.FuelUsefulMass (f,(one,Q.U_joule),NONE)', 'kg'),
    ('UnsupportedCondition', 'Q.UnsupportedCondition Q.C_moisture', None),
]
# Hand-authored English controls for actual wire behavior and fixed output units.
# No value is inferred from displayed prose, by either production or this check.
CASES = [
    ('density', 'What is the density of solid copper?', 'density', 'kg/m3'),
    ('mass', 'What is the mass of 2 litres of zinc in kg?', 'mass', 'kg'),
    ('volume', 'What is the volume of 1 kg of gold in litres?', 'volume', 'L'),
    ('conversion-j', 'Convert 1 kWh to J.', 'convert', 'J'),
    ('conversion-small', 'Convert 1 mJ to J.', 'convert', 'J'),
    ('conversion-target', 'Convert 1 J to mJ.', 'convert', 'mJ'),
    ('force', 'A spring has k = 200 N/m and extension 0.1 m. What force does it exert?', 'force', 'N'),
    ('extension', 'A spring has k = 200 N/m and force 10 N. What is the extension?', 'extension', 'm'),
    ('constant', 'A spring stretches 0.1 m under a force of 10 N. What is the spring constant?', 'spring_constant', 'N/m'),
    ('spring-energy', 'A spring has k = 200 N/m and extension 0.1 m. What is the stored energy?', 'elastic_energy', 'J'),
    ('period', 'A spring has k = 2000 N/m and a mass of 1 kg. What is its period?', 'period', 's'),
    ('frequency', 'A spring has k = 2000 N/m and a mass of 1 kg. What is its frequency?', 'frequency', 'Hz'),
    ('pressure-gauge', 'What is the gauge pressure at depth 2 m in water?', 'pressure_gauge', 'Pa'),
    ('pressure-absolute', 'What is the absolute pressure at depth 2 m in water with surface pressure 200 kPa?', 'pressure_abs', 'Pa'),
    ('buoyancy', 'What is the buoyant force on 1 m3 in water?', 'buoyant_force', 'N'),
    ('fraction', 'What fraction of floating ice is submerged in water?', 'submerged_fraction', '1'),
    ('fuel-energy', 'How much energy in J comes from burning 2 kg of wood?', 'energy', 'J'),
    ('fuel-co2', 'How much CO2 comes from burning 2 kg of wood?', 'co2', 'kg'),
    ('fuel-inverse', 'How much wood is needed to release 100 MJ of energy?', 'mass_needed', 'kg'),
    ('fuel-ncv', 'What is the energy content per kg of wood?', 'ncv', 'MJ/kg'),
    ('useful-energy', 'How much useful heat in kWh comes from burning 100 kg of wood at 50% efficiency?', 'useful_energy', 'kWh'),
    ('useful-inverse', 'How much wood is required to deliver 100 MJ of useful heat at 50% efficiency?', 'useful_mass_needed', 'kg'),
    ('temperature-point', 'Convert 10 C to K.', 'temperature', None),
    ('temperature-difference', 'Convert a temperature difference of 10 C to K.', 'temperature_difference', None),
    ('boolean', 'Does a solid block of lead float in water?', 'floats', None),
    ('decline', 'Convert 1 metre to kg.', None, None),
    ('missing', 'What is the energy stored in a spring?', None, None),
    ('unsupported', 'What is the pressure at depth 2 m in water at 100 C?', None, None),
    ('unrecognized', 'Who wrote Leaves of Grass?', None, None),
]


def coverage():
    source = (HERE / 'Quantity.thy').read_text()
    datatype = source.split('datatype request =', 1)[1].split('text ', 1)[0]
    constructors = set(re.findall(r'(?:^\s*|\|\s*)([A-Z][A-Za-z0-9_]*)', datatype, re.M))
    declared = {name for name, _, _ in TYPED}
    if constructors != declared or len(declared) != len(TYPED):
        raise AssertionError(f'typed cases differ from request constructors: {constructors ^ declared}')
    driver = (HERE / 'main.sml').read_text().split('fun output_unit request =', 1)[1].split('fun unit_field', 1)[0]
    handled = set(re.findall(r'^\s*(?:\|\s*)?Quantity\.([A-Z][A-Za-z0-9_]*)', driver, re.M))
    # U_ constants are arguments inside parenthesized unit_label expressions.
    handled = {name for name in handled if not name.startswith('U_')}
    if handled != constructors:
        raise AssertionError(f'driver unit mapping differs from request constructors: {handled ^ constructors}')


def emit_sml():
    print('structure UnitMetadataCheck = struct\nstructure Q = Quantity\nval one = Q.mk_rat 1 1\nval m = hd Q.material_order\nval f = hd Q.fuel_order')
    # tunit constructors are intentionally hidden by the generated signature.
    # Use the public lookup, checking that each alias retains its Tmp role.
    print('fun temperature name = case Q.lookup_unit name of SOME (u as Q.Tmp _) => u | _ => raise Fail "missing typed temperature alias"')
    print('val temp_c = temperature "c"\nval temp_k = temperature "k"')
    for name, request, unit in TYPED:
        expected = 'NONE' if unit is None else 'SOME ' + json.dumps(unit)
        print(f'val _ = if Main.output_unit ({request}) = ({expected}) then () else raise Fail "unit metadata: {name}"')
    for request in ['Q.Convert (one,temp_c,temp_k)',
                    'Q.Convert (one,Q.Lin Q.U_metre,temp_k)',
                    'Q.Convert (one,temp_k,Q.Lin Q.U_metre)']:
        print(f'val _ = if Main.output_unit ({request}) = NONE then () else raise Fail "temperature/mixed role anchor"')
    for request in ['Q.SpringEnergy (NONE,NONE)', 'Q.Floats (m,m)', 'Q.UnsupportedCondition Q.C_moisture',
                    'Q.Convert (one,temp_c,temp_k)', 'Q.ConvertDelta (one,temp_c,temp_k)']:
        print(f'val r = {request}\nval _ = if Main.unit_field r (Q.reply_of r) = "" then () else raise Fail "unsupported or nonnumeric anchor"')
    print('val _ = TextIO.print "QUANTITY_TYPED_UNIT_METADATA PASS\\n"\nend')


def run(binary):
    payload = ''.join(json.dumps({'id': i, 'q': q, 'session': 'unit-metadata'}) + '\n' for i, (_, q, _, _) in enumerate(CASES))
    result = subprocess.run([str(binary)], input=payload, text=True, capture_output=True, check=True, timeout=45)
    replies = [json.loads(line, parse_float=Decimal) for line in result.stdout.splitlines() if line.strip()]
    if len(replies) != len(CASES):
        raise AssertionError('binary did not return one reply per request')
    return replies


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path)
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--emit-sml-checks', action='store_true')
    args = parser.parse_args()
    coverage()
    if args.emit_sml_checks:
        emit_sml()
        return
    if args.binary is None:
        parser.error('--binary is required unless --emit-sml-checks is used')
    replies = run(args.binary.resolve())
    for i, ((name, _, kind, unit), reply) in enumerate(zip(CASES, replies)):
        if reply.get('id') != i or 'error' in reply:
            raise AssertionError((name, 'invalid reply', reply))
        if kind is not None and (reply.get('status') != 'answered' or reply.get('kind') != kind):
            raise AssertionError((name, 'wrong recognition/status', reply))
        if unit is None:
            if 'unit' in reply:
                raise AssertionError((name, 'unsupported anchor admitted', reply))
        elif (reply.get('unit') != unit or reply.get('status') != 'answered'
              or isinstance(reply.get('value'), bool) or not isinstance(reply.get('value'), (int, Decimal))):
            raise AssertionError((name, 'wrong or missing numeric unit', reply))
    if args.baseline:
        baseline = run(args.baseline.resolve())
        keys = ('id', 'status', 'response', 'value', 'path', 'kind')
        for (name, _, _, _), before, after in zip(CASES, baseline, replies):
            if {k: before.get(k) for k in keys} != {k: after.get(k) for k in keys}:
                raise AssertionError((name, 'existing reply fields changed', before, after))
    print(json.dumps({'protocol_cases': len(CASES), 'constructors_covered': len(TYPED),
                      'baseline_compared': bool(args.baseline), 'status': 'PASS',
                      'assurance': 'untrusted protocol checks; not a theorem or specialist panel score'}))


if __name__ == '__main__':
    main()
