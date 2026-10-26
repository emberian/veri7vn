#!/usr/bin/env python3
"""UNTRUSTED narrow panel/probe runner for the Earth meteorology-v2 reader.

Official scores use the supplied pinned specialist's own panel and scorer.
Independent probes are separately authored quantity/role checks, not an
additional claim about the official panel. No files beneath the source are
written. --command supports an interpreted source check before native build.
"""
from __future__ import annotations
import argparse
import importlib.util
import json
from pathlib import Path
import shlex
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]


def module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result


def ask(command, questions):
    payload = ''.join(json.dumps({'id': i, 'q': q}) + '\n' for i, q in enumerate(questions))
    run = subprocess.run(command, input=payload, text=True, capture_output=True, check=True)
    # Poly/ML source checks print generated-code warnings before JSON replies.
    replies = [json.loads(line) for line in run.stdout.splitlines() if line.startswith('{')]
    if len(replies) != len(questions) or any('error' in r for r in replies):
        raise RuntimeError(run.stdout + run.stderr)
    return replies


def probes():
    cases = []
    def value(name, q, expected, tolerance=.01):
        cases.append({'name': name, 'q': q, 'value': expected, 'tolerance': tolerance})
    def withheld(name, q):
        cases.append({'name': name, 'q': q, 'withheld': True})
    for literal in ['3,000', '+3,000', '3e3', '6,000/2', '3000.0']:
        value('isa exact ' + literal, f'Standard atmosphere: temperature at {literal} m altitude?', -4.5)
    value('isa compact positive', 'ISA temperature at +3,000m?', -4.5)
    value('isa fractional km', 'ISA temperature at .5 km altitude?', 11.75)
    value('isa feet conversion', 'ISA temperature at 10,000 ft altitude?', -4.812)
    value('isa pressure', 'ISA pressure at 3,000 m altitude?', 701.085, .02)
    for literal in ['-3,000', '−3,000', '11,001']:
        withheld('isa domain ' + literal, f'ISA temperature at {literal} m altitude?')
    for literal in ['3,00', '30,00', '3,,000', '12,34,567', '--3,000', '- 3,000', '3e', '3e+', '3/0', '3..0', '3_000']:
        withheld('malformed ' + literal, f'ISA temperature at {literal} m altitude?')
    for suffix in ['m/s', 'm^2', 'm2', 'm per second', 'metres/second']:
        withheld('wrong altitude dimension ' + suffix, f'ISA temperature at 3,000 {suffix} altitude?')
    withheld('ambiguous altitude', 'ISA temperature at 3,000 m or 4,000 m altitude?')
    withheld('extra baseline', 'ISA pressure at 3,000 m altitude with sea-level pressure 900 hPa?')
    withheld('unused temperature', 'ISA pressure at 3,000 m altitude with temperature 20 C?')
    withheld('unused humidity', 'ISA pressure at 3,000 m altitude with 50% humidity?')
    withheld('unissued marker', 'ISA temperature at qnum0q m altitude?')
    withheld('mixed requests', 'What Beaufort force and hurricane category is a 75 mph wind?')
    withheld('forecast priority', 'What is the ISA temperature tomorrow at 3,000 m altitude?')
    for goal in ['Beaufort force', 'Saffir-Simpson category']:
        withheld('negative ' + goal, f'What {goal} is a -5 mph wind?')
        withheld('negative unicode ' + goal, f'What {goal} is a −5 mph wind?')
    withheld('negative wind chill speed', 'What is the wind chill at 32 F with -5 mph wind?')
    withheld('compound wind speed', 'What is the wind chill at 32 F with 5 mph/s wind?')
    withheld('two wind speeds', 'What is the wind chill at 32 F with 5 mph or 10 mph wind?')
    withheld('two temperatures', 'What is the heat index at 90 F or 100 F and 50% humidity?')
    withheld('compound humidity', 'What is the heat index at 90 F with relative humidity 50%/s?')
    withheld('wrong humidity dimension', 'What is the heat index at 90 F with relative humidity 50 psi?')
    withheld('two humidities', 'What is the heat index at 90 F with 50% humidity or 60% humidity?')
    withheld('below absolute zero', 'What is the wind chill at -500 F with a 5 mph wind?')
    value('negative unicode temperature', 'What is the wind chill at −5 F with a 5 mph wind?', -16.3827)
    value('fractional humidity', 'What is the heat index at 84 F with 80/2% humidity?', 83.2904)
    value('scientific temperature', 'What is the dew point at 2.7e1 C and 45% humidity?', 14.0511)
    value('dew role first', 'With a dew point of 12 C and an air temperature of 22 C, find relative humidity.', 53.0814)
    value('dew role last', 'With air temperature 22 C and dew point 12 C, find relative humidity.', 53.0814)
    value('air temperature inverse', 'What is the air temperature at dew point 12 C and 53.08138402026172% humidity?', 22)
    withheld('ambiguous dew role', 'Air 22 C, dew point 12 C, dew point 10 C: what is relative humidity?')
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--command', default=str(ROOT / 'var/earth/bin/earth'))
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    panel = json.loads((args.source / 'weather_panel_v2.json').read_text())
    scorer = module(args.source / 'weather_scorer.py', 'ap1_weather_scorer')
    command = shlex.split(args.command)
    report = {'source': str(args.source.resolve()), 'command': command, 'official': {}, 'independent': {}}
    failures = []
    for mode, argv in [('meteorology-v2', ['--specialist', 'meteorology-v2']), ('meteorology', ['--specialist', 'meteorology']), ('family', [])]:
        replies = ask(command + argv, [p['q'] for p in panel])
        stats = {split: dict(n=0, right=0, wrong=0, false_yes=0, withheld_valid=0, withheld_total=0, failures=[]) for split in ['dev', 'heldout']}
        for p, r in zip(panel, replies):
            t = stats[p['split']]
            good, asserted = scorer.ok(p, r)
            t['n'] += 1
            t['right'] += bool(good)
            t['wrong'] += bool(p['valid'] and not good and asserted)
            t['false_yes'] += bool(not p['valid'] and asserted)
            t['withheld_valid'] += bool(p['valid'] and not asserted)
            t['withheld_total'] += r.get('status') != 'answered'
            if not good:
                t['failures'].append({'q': p['q'], 'expected': p['expect'], 'reply': r})
                failures.append((mode, p['q']))
        report['official'][mode] = stats
        cases = probes()
        replies = ask(command + argv, [p['q'] for p in cases])
        results = []
        for p, r in zip(cases, replies):
            good = r.get('status') != 'answered' if p.get('withheld') else (
                r.get('status') == 'answered' and isinstance(r.get('value'), (int, float))
                and abs(r['value'] - p['value']) <= p['tolerance'])
            results.append(dict(p, passed=good, reply=r))
            if not good:
                failures.append((mode, p['name']))
        report['independent'][mode] = {'passed': sum(r['passed'] for r in results), 'n': len(results), 'cases': results}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'official': report['official'], 'independent': {k: {j:v[j] for j in ['passed','n']} for k,v in report['independent'].items()}}, indent=2))
    if failures:
        print('FAIL:', failures)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
