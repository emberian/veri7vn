#!/usr/bin/env python3
"""Reproduce two repaired upstream boundaries; observations are not native proofs."""
import importlib.util
import json
import re
from pathlib import Path
import sys
from fractions import Fraction

ROOT = Path(__file__).resolve().parents[4]
sys.dont_write_bytecode = True


def module(family):
    directory = ROOT / 'upstream/root/specialists' / family
    sys.path.insert(0, str(directory))
    try:
        name = f'organ_{family}_v1'
        spec = importlib.util.spec_from_file_location(name, directory / f'{name}.py')
        loaded = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(loaded)
        return loaded
    finally:
        sys.path.pop(0)


def main():
    air = module('airquality')
    building = module('architecture')
    cooling = module('coldchain')
    theory = (ROOT / 'src/families/domains/policies/Versioned_Policies.thy').read_text()
    pollutants = [('PM25', 'pm25'), ('PM10', 'pm10'), ('Ozone', 'o3'),
                  ('CarbonMonoxide', 'co'), ('SulfurDioxide', 'so2'), ('NitrogenDioxide', 'no2')]
    checked_rows = 0
    for constructor, source_name in pollutants:
        table = re.search(r'aqi_rows ' + constructor + r' = \[(.*?)\]"', theory, re.S).group(1)
        native_rows = [tuple(map(int, row)) for row in re.findall(r'bp (\d+) (\d+) (\d+) (\d+)', table)]
        _, _, _, decimals, rows = air.BP[source_name]
        scale = 10 ** decimals
        expected = [(int(Fraction(str(row[0])) * scale), int(Fraction(str(row[1])) * scale), ilo, ihi)
                    for (ilo, ihi), row in zip(air.IDX, rows) if row is not None]
        assert native_rows == expected, (constructor, native_rows, expected)
        checked_rows += len(expected)
    uses = ['Business', 'Mercantile', 'Residential', 'Classroom', 'AssemblyStanding',
            'AssemblyChairs', 'AssemblyTables', 'Exercise', 'LibraryReading', 'LibraryStacks',
            'CommercialKitchen', 'Warehouse']
    for use, (_, factor, label) in zip(uses, building.LOAD):
        actual = re.search(r'occupancy_factor ' + use + r'=\((\d+),(NetArea|GrossArea)\)', theory)
        assert actual and int(actual.group(1)) == factor
        assert actual.group(2) == ('GrossArea' if 'gross' in label else 'NetArea')
    concentration = Fraction('9.09999999999')
    exact_truncated = (concentration * 10).__floor__()
    original_index, original_concentration = air.sub_index('pm25', float(concentration))
    assert exact_truncated == 90
    assert original_index == 51 and original_concentration == 9.1
    area = Fraction('150.000000001')
    q = area / 150
    exact_occupants = -(-q.numerator // q.denominator)
    original_occupants = building.ArchitectureOrgan().answer(
        'occupant load for business area 150.000000001 sq ft')['value']
    assert exact_occupants == 2 and original_occupants == 1
    total_only = cooling.ColdChainOrgan().answer('food cooled from 135 F to 41 F in 5 hours')
    assert total_only['value'] is True
    print(json.dumps({
        'assurance': 'upstream observation; native checks are separate',
        'transcription': {'aqi_rows_checked': checked_rows, 'occupancy_factors_checked': len(uses)},
        'aqi_epsilon_repair': {'input': str(concentration), 'source_index': original_index,
                              'exact_truncated_tenths': exact_truncated},
        'occupancy_epsilon_repair': {'area': str(area), 'source': original_occupants,
                                     'exact_ceiling': exact_occupants},
        'cooling_total_only': {'source_value': total_only['value'],
                               'required_native_status': 'PolicyConditionsMissing'},
    }, indent=2))


if __name__ == '__main__':
    main()
