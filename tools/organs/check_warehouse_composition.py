#!/usr/bin/env python3
"""Narrow real-Combo checks of generated warehouse wrappers; upstream stays read-only.

Usage: python3 -B tools/organs/check_warehouse_composition.py --root PACKAGE/specialists --out RECEIPT.json
Requires current stores binaries supporting --preview/--commit. No complete panel or head run.
"""
import argparse
from concurrent.futures import ThreadPoolExecutor
import importlib.util
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
REPO = Path(__file__).resolve().parents[2]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', required=True, type=Path)
    ap.add_argument('--out', required=True, type=Path)
    args = ap.parse_args()
    root = args.root.resolve()
    runtime = load('warehouse_combo_check', REPO / 'upstream/root/specialists/_gate/combo_runtime_v1.py')
    folders = [root / (sid + '-veri7vn') for sid in ('warehouse', 'warehouse-r2')]
    combo = runtime.Combo([str(f / 'manifest.json') for f in folders], [str(f) for f in folders])
    report = {'checks': [], 'mode': 'default read-only warehouse wrappers', 'full_head_checked': False}
    q = 'Reorder 5 M4 valve'
    try:
        replies = combo._ask_all(q, 'real')
        assert len(replies) == 2 and all(r['status'] == 'withheld' and r['kind'] == 'effects_disabled' and r['declined'] for r in replies), replies
        report['checks'].append('all candidates decline effects before arbitration')
        combo._dependence(replies[0], q, runtime._givens(q))
        report['checks'].append('counterfactual probe cannot create a proposal')
        combo._segment([q, 'How many?'], 'real')
        report['checks'].append('segmentation re-asks cannot create a proposal')
        combo._disagree_text(q, 'real', {'disagree': combo.order})
        report['checks'].append('disagreement re-asks cannot create a proposal')
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(lambda _: combo.reply(q, 'same-session'), range(12)))
        assert all(r and r['status'] == 'withheld' for r in results)
        assert combo.reply('yes', 'real') is None
        report['checks'].append('12 concurrent combo calls plus yes produce no order')
        for item in combo.organs:
            organ = item.organ
            assert '--preview' in organ.proc.args and '--commit' not in organ.proc.args
            assert not (Path(organ.state_dir) / 'sessions.json').exists()
        report['checks'].append('no default wrapper state file exists')
        # The opt-in is exercised directly, never through a speculative Combo.
        folder = folders[0]
        manifest = json.loads((folder / 'manifest.json').read_text())
        mod = load('warehouse_direct_check', folder / (manifest['organ']['module'] + '.py'))
        direct = getattr(mod, manifest['organ']['class'])(allow_effects=True)
        try:
            proposal = direct.answer(q, 'single-owner')
            assert proposal['kind'] == 'confirm' and proposal['status'] == 'answered'
            ordered = direct.answer('yes', 'single-owner')
            assert ordered['kind'] == 'ordered' and ordered['status'] == 'answered'
            state = json.loads((Path(direct.state_dir) / 'sessions.json').read_text())
            before = json.dumps(state, sort_keys=True)
            repeated = direct.answer('yes', 'single-owner')
            assert repeated is None or repeated['kind'] != 'ordered'
            assert json.dumps(json.loads((Path(direct.state_dir) / 'sessions.json').read_text()), sort_keys=True) == before
            report['checks'].append('explicit sequential opt-in proposes and records once; repeated yes does not record twice')
        finally:
            direct.close()
        report['status'] = 'passed'
    finally:
        for item in combo.organs:
            item.organ.close()
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
