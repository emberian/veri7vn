#!/usr/bin/env python3
"""Untrusted narrow regression checks for private reach-router repairs, not panel scores.

Loads only three router modules and their lightweight dependencies. Uses immutable
read-only real stores; never starts an engine, builds indexes, or writes runtime.
"""
import argparse
from contextlib import ExitStack
import importlib.util
import json
import os
from pathlib import Path
import sys
from unittest.mock import patch


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--runtime', type=Path, required=True)
    p.add_argument('--source', type=Path, required=True, help='Directory containing reach_router_v1/2/3.py')
    args = p.parse_args()
    os.environ['ORACLE7_ROOT'] = str(args.runtime.resolve() / 'root')
    sys.path.insert(0, str(args.runtime.resolve() / 'root/wander-train'))
    results = []
    def check(name, passed, observed=None):
        results.append({'check': name, 'passed': bool(passed), 'observed': observed})
    modules = []
    for version in (1, 2, 3):
        spec = importlib.util.spec_from_file_location(f'coverage_router_v{version}', args.source/f'reach_router_v{version}.py')
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        modules.append(m)
        for name, question, expected in [
            ('unicode_partial_name', 'Where was Maria Skłodowska born?', None),
            ('short_partial_name', 'Where was Maria X born?', None),
            ('distinct_entity_same_word', 'In which constellation is the Andromeda Galaxy?', (2469, 59, [9256])),
            ('catalog_alias', 'In which constellation is M31?', (2469, 59, [9256])),
            ('legitimate_pen_name', 'Where was Mark Twain born?', (7245, 19, [537803])),
        ]:
            answer = m.answer(question)
            actual = (answer['subject_qid'], answer['property'], answer['raw']) if answer else None
            check(f'v{version}:{name}', actual == expected, answer)
        # The two identity cases have the same label and differ only in QID.
        # Literal restatement must retain the old behavior.
        for name, value, expect_answer in [('self_identity', 1, False), ('same_label_distinct_id', 2, True), ('literal_restatement', 'Andromeda', False)]:
            with ExitStack() as stack:
                for target, attr, replacement in [
                    (m.L, 'link', lambda *a, **kw: [('Andromeda', [(1, 100, 'Andromeda')])]),
                    (m.XR, 'hop', lambda *a: False), (m.XR, 'subject_ok', lambda *a: True),
                    (m, '_routes', lambda *a: [((50, 'fwd'), 'pattern', 'test')]),
                    (m, '_agree', lambda *a: (frozenset([value]), 1)),
                    (m, 'fits', lambda *a: True), (m, '_show', lambda *a: 'Andromeda'),
                ]:
                    stack.enter_context(patch.object(target, attr, replacement))
                check(f'v{version}:{name}', bool(m.answer('What is Andromeda?')) == expect_answer)
    m = modules[-1]
    for name, question, prop, raw in [
        ('language_creator', 'Who created Python?', 287, [30942]),
        ('original_language_creator', 'Who originally created Python?', 287, [30942]),
        ('developer_preserved', 'Who developed Python?', 178, [30942, 83818]),
        ('designer_preserved', 'Who designed the Python programming language?', 287, [30942]),
        ('art_creator_preserved', 'Who created Mona Lisa?', 170, [762]),
        ('author_preserved', 'Who wrote Leaves of Grass?', 50, [81438]),
        ('founders_preserved', 'Who founded Microsoft?', 112, [162005, 5284]),
    ]:
        answer = m.answer(question)
        check('v3:'+name, answer and answer['property'] == prop and answer['raw'] == raw, answer)
    check('v3:developer_is_not_creator', not m._creation_property_allowed(178, [(1, 0, 'x')]))
    with patch.object(m, 'has', return_value=True), patch.object(m, '_programming_language', return_value=False):
        check('v3:untyped_designer_not_creator', not m._creation_property_allowed(287, [(1, 0, 'x')]))
    with patch.object(m, 'has', return_value=True), patch.object(m, '_programming_language', side_effect=lambda qid: qid == 1):
        check('v3:mixed_candidate_types_not_narrowed', not m._creation_property_allowed(287, [(1, 0, 'x'), (2, 0, 'y')]))
    failed = [r for r in results if not r['passed']]
    print(json.dumps({'scope': 'Direct router checks; no engine composition or specialist panel claim.',
                      'source': str(args.source.resolve()), 'checks': len(results), 'failed': len(failed), 'results': results}, ensure_ascii=False, indent=2))
    return bool(failed)


if __name__ == '__main__':
    raise SystemExit(main())
