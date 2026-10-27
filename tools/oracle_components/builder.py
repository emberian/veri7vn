"""Untrusted bounded construction tools; examples and plans confer no Mini authority.

Loads only operator-packaged source paths. Caller input is data, never source
code, commands, module names, host paths, URLs, or an installation request.
"""
from __future__ import annotations

import hashlib
import importlib.util
import inspect
import json
import math
from pathlib import Path
import sys


def _load(path, label):
    if not path.is_file():
        return None
    name = '_oracle_builder_' + label + '_' + hashlib.sha256(str(path).encode()).hexdigest()[:12]
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _object(value, required, optional=()):
    if not isinstance(value, dict) or not set(required) <= value.keys() or set(value) - set(required) - set(optional):
        raise ValueError('invalid_arguments')


def _number(value):
    # Bound arbitrary-precision JSON integers before math.isfinite converts them
    # to float; oversized inputs must refuse, not raise OverflowError.
    return type(value) in (int, float) and abs(value) <= 1_000_000 and math.isfinite(value)


def _task(arguments):
    _object(arguments, ('title', 'inputs', 'output', 'dev', 'heldout'))
    for key in ('title', 'output'):
        if not isinstance(arguments[key], str) or not 1 <= len(arguments[key]) <= 240:
            raise ValueError('invalid_' + key)
    labels = arguments['inputs']
    if not isinstance(labels, list) or not 1 <= len(labels) <= 4 or any(not isinstance(x, str) or not 1 <= len(x) <= 80 for x in labels):
        raise ValueError('invalid_inputs')
    dev_keys = set()
    for split in ('dev', 'heldout'):
        rows = arguments[split]
        if not isinstance(rows, list) or not 2 <= len(rows) <= 16:
            raise ValueError(split + '_requires_2_to_16_examples')
        seen = set()
        for row in rows:
            _object(row, ('in', 'out'))
            if not isinstance(row['in'], list) or len(row['in']) != len(labels) or not all(_number(v) for v in row['in']) or not _number(row['out']):
                raise ValueError('examples_require_bounded_finite_numbers')
            key = tuple(row['in'])
            if key in seen or (split == 'heldout' and key in dev_keys):
                raise ValueError('duplicate_or_reused_example_inputs')
            seen.add(key)
        if split == 'dev':
            dev_keys = seen
    return {'id': 'appliance-proposal', 'title': arguments['title'], 'inputs': labels,
            'output': arguments['output'], 'dev': arguments['dev']}


def _schema(properties, required):
    return {'type': 'object', 'properties': properties, 'required': required, 'additionalProperties': False}


class BuilderOperations:
    """Pure-input construction and inspection; no automatic install or publication."""
    def __init__(self, runtime, workspace):
        self.runtime, self.workspace = Path(runtime), Path(workspace)
        self.paths = {
            'composer': self.runtime / 'workbench/swarm/composer_v3.py',
            'microfold': self.runtime / 'components/chameleon/source/packages/core/chameleon_core/microfold.py',
            'contract': self.runtime / 'components/chameleon/source/packages/core/chameleon_core/browser_contract.py',
        }
        self.modules = {}

    def _module(self, name):
        if name not in self.modules:
            self.modules[name] = _load(self.paths[name], name)
        module = self.modules[name]
        if module is None:
            raise ValueError('component_unavailable:' + name)
        return module

    def _ready(self, name):
        try:
            module = self._module(name)
            if name == 'composer':
                return {'max_size', 'bank_cap', 'allow_fitted'} <= inspect.signature(module.compose).parameters.keys()
            return callable(getattr(module, 'search' if name == 'microfold' else 'validate_contract', None))
        except (OSError, ValueError, AttributeError, ImportError):
            return False

    def catalog(self):
        example = _schema({'in': {'type': 'array', 'items': {'type': 'number'}, 'minItems': 1, 'maxItems': 4}, 'out': {'type': 'number'}}, ['in', 'out'])
        names = {'type': 'array', 'items': {'type': 'string', 'minLength': 1, 'maxLength': 80}, 'maxItems': 63}
        operator = _schema({'id': {'type': 'string', 'minLength': 1, 'maxLength': 100},
                            'requires': names, 'forbids': names, 'adds': names, 'removes': names,
                            'cost': {'type': 'integer', 'minimum': 1, 'maximum': 1000000}},
                           ['id', 'requires', 'forbids', 'adds', 'removes', 'cost'])
        model_schema = _schema({'version': {'type': 'string', 'enum': ['microfold-model-v1']},
                                'evidence_digest': {'type': 'string', 'minLength': 64, 'maxLength': 64},
                                'facts': names, 'initial': names,
                                'goal': _schema({'all': names, 'none': names}, ['all', 'none']),
                                'operators': {'type': 'array', 'items': operator, 'maxItems': 128}},
                               ['version', 'evidence_digest', 'facts', 'initial', 'goal', 'operators'])
        contract_schema = _schema({'version': {'type': 'string', 'enum': ['browser-contract-v1', 'browser-contract-v2']},
                                   'name': {'type': 'string', 'minLength': 1, 'maxLength': 120},
                                   'steps': {'type': 'array', 'minItems': 1, 'maxItems': 12,
                                             'items': {'type': 'object', 'description': 'Exact fields depend on op: visible(selector), text(selector,equals), count(selector,equals), click(selector), fill(selector,value). At least one assertion required.'}}},
                                  ['version', 'name', 'steps'])
        examples = {
            'builder.compose': [{'arguments': {'title': 'Double distance', 'inputs': ['distance (m)'], 'output': 'distance (m)',
                                'dev': [{'in': [2], 'out': 4}, {'in': [3], 'out': 6}],
                                'heldout': [{'in': [7], 'out': 14}, {'in': [11], 'out': 22}]}}],
            'chameleon.plan': [{'arguments': {'model': {'version': 'microfold-model-v1', 'evidence_digest': '0'*64,
                                  'facts': ['ready'], 'initial': [], 'goal': {'all': ['ready'], 'none': []},
                                  'operators': [{'id': 'build', 'requires': [], 'forbids': [], 'adds': ['ready'], 'removes': [], 'cost': 1}]}}}],
            'chameleon.validate_contract': [{'arguments': {'contract': {'version': 'browser-contract-v1', 'name': 'Result visible',
                                             'steps': [{'op': 'visible', 'selector': '#result'}]}}}],
        }
        specs = [
            ('builder.compose', 'composer', 'Construct a bounded arithmetic program from labeled examples, then check separate examples.',
             _schema({'title': {'type': 'string', 'maxLength': 240}, 'inputs': {'type': 'array', 'items': {'type': 'string'}, 'minItems': 1, 'maxItems': 4},
                      'output': {'type': 'string', 'maxLength': 240}, 'dev': {'type': 'array', 'items': example, 'minItems': 2, 'maxItems': 16},
                      'heldout': {'type': 'array', 'items': example, 'minItems': 2, 'maxItems': 16}}, ['title', 'inputs', 'output', 'dev', 'heldout'])),
            ('chameleon.plan', 'microfold', 'Search an explicit transition model and independently replay its conditional plan; does not act on a website.',
             _schema({'model': model_schema, 'rounds': {'type': 'integer', 'minimum': 1, 'maximum': 10}}, ['model'])),
            ('chameleon.validate_plan', 'microfold', 'Check a proposed plan against its exact supplied transition model.',
             _schema({'model': model_schema, 'report': {'type': 'object'}}, ['model', 'report'])),
            ('chameleon.validate_contract', 'contract', 'Validate a declarative browser contract and return canonical bytes digest; does not run a browser.',
             _schema({'contract': contract_schema}, ['contract'])),
        ]
        return [{'id': ident, 'name': ident, 'component': ident.split('.')[0], 'description': description,
                 'input_schema': schema, 'availability': 'live_direct' if self._ready(module) else 'unavailable',
                 'available': self._ready(module),
                 'side_effects': 'Bounded generated-program execution in temporary files; no installation.' if module == 'composer' else 'none',
                 'required_capabilities': ['query'], 'output_schema': {'type': 'object'}, 'units': {},
                 'sources': [{'path': str(self.paths[module].relative_to(self.runtime)), 'sha256': hashlib.sha256(self.paths[module].read_bytes()).hexdigest() if self.paths[module].is_file() else None}], 'examples': examples.get(ident, []),
                 'implementation': {'kind': 'upstream_function', 'module': module},
                 'limitations': ['Finite supplied data only; no browser execution or specialist installation.', 'Composer matching uses upstream 0.5% relative tolerance; heldout examples are caller supplied, not sealed.'],
                 'assurance': 'Executable upstream computation; no Mini permission or formal correctness claim.'}
                for ident, module, description, schema in specs]

    def invoke(self, operation_id, arguments):
        if len(json.dumps(arguments, ensure_ascii=True, allow_nan=False)) > 16000:
            raise ValueError('arguments_too_large')
        if operation_id == 'builder.compose':
            task = _task(arguments)
            composer = self._module('composer')
            # No caller-supplied source, library, or coefficients. The module is
            # private to this component; previous construction cannot expand it.
            composer.LIBRARY = []
            proposal = composer.compose(task, max_size=3, bank_cap=128, allow_fitted=False)
            if proposal['status'] != 'composed':
                return {'status': 'withheld', 'proposal': proposal, 'installed': False}
            held = arguments['heldout']
            passed, note = composer.read_back(proposal['python'], [r['in'] for r in held], [r['out'] for r in held])
            return {'status': 'answered' if passed else 'withheld', 'proposal': proposal,
                    'heldout': {'passed': passed, 'count': len(held), 'detail': note},
                    'installed': False, 'admitted': False,
                    'limits': {'expression_bank': 128, 'bank_expression_size': 3, 'fitted_constants': 0, 'relative_tolerance': composer.TOL},
                    'scope': 'Finite examples only; no six-criterion specialist exam, source truth, generalization or Mini admission claim.'}
        if operation_id == 'chameleon.plan':
            _object(arguments, ('model',), ('rounds',))
            result = self._module('microfold').search(arguments['model'], backend='python', rounds=arguments.get('rounds', 10), batch_size=1000)
            return {'status': 'answered' if result['status'] == 'PLAN_FOUND' else 'withheld', 'result': result}
        if operation_id == 'chameleon.validate_plan':
            _object(arguments, ('model', 'report'))
            return {'status': 'answered', 'valid': self._module('microfold').validate_plan(arguments['model'], arguments['report']), 'executed': False}
        if operation_id == 'chameleon.validate_contract':
            _object(arguments, ('contract',))
            value, digest = self._module('contract').validate_contract(arguments['contract'])
            return {'status': 'answered', 'contract': value, 'sha256': digest, 'browser_executed': False}
        raise ValueError('unknown_operation')
