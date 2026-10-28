#!/usr/bin/env python3
"""Read-only source inventory of Oracle's active runtime inheritance graph.

This is an untrusted review aid, not a purity analysis or a complete import graph.
It parses source without importing Oracle, opening stores, or constructing an
Engine. Unresolved bases are reported explicitly. Module globals and calls are
review candidates; presence does not establish a bug and absence proves nothing.
"""
import argparse
import ast
import json
from pathlib import Path
import sys

PH = Path('root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted')
MUTATORS = {'append', 'extend', 'update', 'setdefault', 'pop', 'clear', 'add', 'discard', 'remove'}
EFFECTS = {'open', 'connect', 'write_text', 'write_bytes', 'mkdir', 'Thread',
           'ThreadPoolExecutor', 'Popen', 'run', 'load', 'loads', 'dump', 'dumps',
           'read_text', 'read_bytes', 'read', 'fetchall'}


def inventory(root, tip):
    root = Path(root).resolve()
    paths = [root / PH, root / 'root/wander-train']
    modules, rows, unresolved, visited = {}, [], [], set()

    def module(name):
        if name not in modules:
            if not name.isidentifier():
                raise ValueError('only simple local module names are resolved')
            path = next((p / (name + '.py') for p in paths if (p / (name + '.py')).is_file()), None)
            if path is None:
                raise ValueError('source module absent: ' + name)
            tree = ast.parse(path.read_text(), filename=str(path))
            classes = {n.name: n for n in tree.body if isinstance(n, ast.ClassDef)}
            imports = {}
            # Imports in a module-level try still establish inheritance aliases;
            # imports within functions do not establish module globals.
            pending = list(tree.body)
            while pending:
                n = pending.pop(0)
                if isinstance(n, ast.ImportFrom) and n.level == 0:
                    for a in n.names:
                        imports[a.asname or a.name] = (n.module, a.name)
                elif isinstance(n, ast.Try):
                    pending.extend(n.body + n.orelse + n.finalbody)
                    for h in n.handlers:
                        pending.extend(h.body)
            modules[name] = (path, tree, classes, imports)
        return modules[name]

    def visit(name, cls):
        identity = (name, cls)
        if identity in visited:
            return
        visited.add(identity)
        try:
            path, tree, classes, imports = module(name)
            node = classes[cls]
        except (ValueError, KeyError, SyntaxError) as error:
            unresolved.append({'module': name, 'class': cls, 'reason': str(error)})
            return
        methods = [n for n in node.body if isinstance(n, (ast.FunctionDef, ast.AsyncFunctionDef))]
        assignments, mutations, effects = [], [], []
        for fn in methods:
            for n in ast.walk(fn):
                if isinstance(n, (ast.Assign, ast.AnnAssign, ast.AugAssign)):
                    targets = n.targets if isinstance(n, ast.Assign) else [n.target]
                    for target in targets:
                        text = ast.unparse(target)
                        if text.startswith('self.'):
                            assignments.append({'line': n.lineno, 'method': fn.name, 'target': text})
                if isinstance(n, ast.Call):
                    text = ast.unparse(n.func)
                    leaf = text.rsplit('.', 1)[-1]
                    if text.startswith('self.') and leaf in MUTATORS:
                        mutations.append({'line': n.lineno, 'method': fn.name, 'call': text})
                    if leaf in EFFECTS:
                        effects.append({'line': n.lineno, 'method': fn.name, 'call': text})
        globals_ = []
        for n in tree.body:
            if isinstance(n, (ast.Assign, ast.AnnAssign)):
                globals_.append({'line': n.lineno, 'source': ast.unparse(n)[:350]})
        rows.append({'module': name, 'class': cls, 'path': str(path.relative_to(root)),
                     'line': node.lineno, 'methods': [n.name for n in methods],
                     'assignments': assignments, 'mutations': mutations,
                     'effect_candidates': effects, 'module_assignments': globals_})
        for base in node.bases:
            if isinstance(base, ast.Name) and base.id == 'object':
                continue
            if isinstance(base, ast.Name) and base.id in classes:
                visit(name, base.id)
            elif isinstance(base, ast.Name) and base.id in imports:
                visit(*imports[base.id])
            else:
                unresolved.append({'module': name, 'class': cls,
                                   'base': ast.unparse(base), 'reason': 'unresolved base expression'})

    _, _, classes, _ = module(tip)
    # Match oracle7.load's actual class-selection rule.
    selected = sorted(n for n in classes if n.startswith('OracleReleaseRuntimeW'))
    if not selected:
        raise ValueError('no release runtime class in tip')
    visit(tip, selected[-1])
    return {'schema': 'oracle-runtime-source-inventory-v1', 'tip': tip,
            'scope': 'Static inheritance and syntactic candidates only; no purity or isolation claim.',
            'summary': {'classes': len(rows), 'chat_overrides': sum('chat' in r['methods'] for r in rows),
                        'constructors': sum('__init__' in r['methods'] for r in rows),
                        'self_assignments': sum(len(r['assignments']) for r in rows),
                        'self_mutation_calls': sum(len(r['mutations']) for r in rows),
                        'unresolved_bases': len(unresolved)},
            'traversal': 'Depth-first inheritance graph; not Python C3 dispatch order.',
            'inheritance_graph': rows, 'unresolved': unresolved}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('source', type=Path)
    p.add_argument('--tip', default='oracle_release_runtime_w574')
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    sys.setrecursionlimit(10000)
    report = inventory(a.source, a.tip)
    with a.output.open('x') as out:
        json.dump(report, out, indent=2)
        out.write('\n')
    print(json.dumps(report['summary']))
    return 1 if report['unresolved'] else 0


if __name__ == '__main__':
    sys.exit(main())
