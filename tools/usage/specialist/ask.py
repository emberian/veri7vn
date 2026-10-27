#!/usr/bin/env python3
"""Untrusted consumer: real Oracle first, then one unchanged local Workbench specialist.

Preserves the raw core reply and labels the composed reply separately. Does not
install anything in the appliance or confer theorem/Mini authority. Only the
single-turn core-first Workbench composition rule is used, without dialogue memory.
"""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from examine import ROOT, RetainedCore, load_exam


def compose(exam, specialist, question, core):
    if core.get('status') == 'answered' or not exam.fillable(core.get('path')):
        return core
    candidate = specialist.reply(question, 'transfer-consumer')
    if not candidate or candidate.get('status') != 'answered':
        return core
    return {**candidate,
            'path': 'yours:data-transfer-explicit>' + candidate['path'],
            'declined_by': core.get('path')}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--admission', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('question')
    args = ap.parse_args()
    admission = args.admission.resolve()
    receipt = json.loads((admission/'receipt.json').read_text())
    exam = load_exam(admission/'workbench/exam.py')
    specialist_dir = admission/'data-transfer-explicit'
    if exam.status(specialist_dir)['state'] != 'admitted':
        ap.error('Specialist is not unchanged and admitted by this isolated Workbench exam')
    out = args.out.resolve()
    scratch = (ROOT/'var/usage-20261026/specialist').resolve()
    if scratch not in out.parents:
        ap.error('Output must be a fresh directory beneath var/usage-20261026/specialist')
    out.mkdir(parents=True, exist_ok=False)
    cases = out/'cases.json'
    cases.write_text(json.dumps([{'id': 'transfer-consumer', 'conversation_id': 'transfer-consumer', 'text': args.question}])+'\n')
    subprocess.run([sys.executable, '-B', str(ROOT/'tools/usage/run_batch.py'),
                    '--cases', str(cases), '--out', str(out/'core')], check=True)
    engine = RetainedCore(out/'core')
    if engine.capabilities != receipt['core_capabilities']:
        raise ValueError('Core capabilities changed since the local admission experiment')
    core = engine.chat(args.question, 'unused')
    result = compose(exam, exam.load_specialist(specialist_dir), args.question, core)
    record = {'scope': receipt['scope'], 'question': args.question, 'core_reply': core,
              'composed_reply': result, 'used_extension': result is not core}
    (out/'answer.json').write_text(json.dumps(record, indent=2)+'\n')
    print(result['response'])
    print('Evidence: ' + str(out/'answer.json'))


if __name__ == '__main__':
    main()
