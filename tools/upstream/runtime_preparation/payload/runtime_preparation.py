"""Operator-admitted public reader artifacts for the explicit prepared-serving mode.

Pickle is trusted executable input: hashes do not make arbitrary pickle safe.
Protect artifacts and matching source/data against writes throughout serving.
"""
import hashlib
import json
import os
from pathlib import Path
import pickle
import re
import stat
import sys

SCHEMA = 'oracle-public-reader-preparation-v1'
MAX_ARTIFACT_BYTES = 512 * 1024 * 1024
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
OPTIONS = {'O7_SUPPORT':'5','O7_CONF':'0.8','O7_MINSKEL':'2','O7_TERMOPS':'1',
           'O7_FORM_SUPPORT':'200','O7_MINIMAL':'1','O7_NESTED':'1','O7_POSS':'1',
           'O7_PLURAL':'1','O7_FALLBACK':'seg,outer,frag','O7_GLUE':'20','O7_DOM':'0.5',
           'O7_ALLREP':'0','O7_ASKING':'1','O7_SHAPE':'1','O7_FORM':'1','O7_OUTREP':'1',
           'O7_AN_K':'10','O7_AN_AGREE':'2','O7_AN_SIM':'0.3','O7_AN_COMBOS':'20',
           'O7_ANALOGY':'1','O7_CL_DEPTH':'2','O7_CL_MIN':'2','O7_CL_CONJ':'1',
           'O7_CL_FREE':'0','O7_CL_DATES':'1'}


def enabled():
    return os.environ.get('ORACLE7_PREPARED_SERVING') == '1'


def sha(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1048576), b''):
            h.update(block)
    return h.hexdigest()


def regular(path):
    path = Path(path)
    if not path.is_absolute() or '..' in path.parts or any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('prepared artifact path must be absolute without symlinks/traversal')
    if not stat.S_ISREG(path.stat().st_mode):
        raise ValueError('prepared artifact must be a regular file')
    return path


def identity(tree):
    """Public inputs only; never include state, lessons, ledger or tenant files."""
    tree = Path(tree).resolve()
    swarm = tree / 'workbench/swarm'
    root = Path(os.environ.get('ORACLE7_ROOT', str(tree / 'root'))).resolve()
    if root != (tree / 'root').resolve():
        raise ValueError('prepared-serving requires its materialized public root, not a private overlay')
    if os.environ.get('PYTHONHASHSEED') != '0':
        raise ValueError('public reader preparation requires PYTHONHASHSEED=0 before Python starts')
    sources = {str(p.relative_to(tree)): sha(p) for p in sorted(swarm.rglob('*.py'))}
    if not sources or not (swarm / 'runtime_preparation.py').is_file():
        raise ValueError('patched public reader source closure required')
    # APPLIANCE is independently admitted by the host; this binds the cache to
    # that declared deployment, in addition to hashing actual reader source/data.
    return {'materialization_sha256': sha(tree / 'APPLIANCE.json'),
            'source_sha256': sources,
            'data_sha256': {name: sha(root / 'organs10/kqa' / name) for name in ('train.json', 'kb.json')},
            'python': {'implementation': sys.implementation.name, 'version': list(sys.version_info[:3]),
                       'cache_tag': sys.implementation.cache_tag, 'pickle_protocol': pickle.HIGHEST_PROTOCOL},
            'hash_seed': '0', 'reader_options': {k:os.environ.get(k,v) for k,v in OPTIONS.items()}}


def public_inputs(tree, train, kb=None):
    root = Path(os.environ.get('ORACLE7_ROOT', str(Path(tree) / 'root'))).resolve()
    if root != (Path(tree) / 'root').resolve():
        raise ValueError('prepared-serving refuses alternate/private root overlays')
    if not isinstance(train, str) or Path(train).resolve() != (root / 'organs10/kqa/train.json').resolve():
        raise ValueError('prepared-serving refuses private or alternate training inputs')
    if kb is not None and Path(kb).resolve() != (root / 'organs10/kqa/kb.json').resolve():
        raise ValueError('prepared-serving refuses private or alternate knowledge inputs')


def admitted_manifest(tree):
    expected = os.environ.get('ORACLE7_READER_ARTIFACT_SHA256', '')
    if not re.fullmatch('[0-9a-f]{64}', expected):
        raise ValueError('operator-admitted public reader manifest SHA256 required')
    directory = Path(os.environ.get('ORACLE7_READER_ARTIFACT', ''))
    path = regular(directory / 'MANIFEST.json')
    if path.stat().st_size > MAX_MANIFEST_BYTES:
        raise ValueError('public reader manifest too large')
    with path.open('rb') as f:
        raw = f.read(MAX_MANIFEST_BYTES + 1)
    if len(raw) > MAX_MANIFEST_BYTES:
        raise ValueError('public reader manifest actual bytes exceed limit')
    if hashlib.sha256(raw).hexdigest() != expected:
        raise ValueError('public reader manifest digest mismatch')
    m = json.loads(raw)
    if set(m) != {'schema', 'identity', 'files', 'assurance'} or m['schema'] != SCHEMA or m['identity'] != identity(tree):
        raise ValueError('public reader artifact source/data/Python identity mismatch')
    files = m['files']
    if not isinstance(files, dict) or len(files) != 2 or sum(n.startswith('reader90_') for n in files) != 1 or sum(n.startswith('clause101_') for n in files) != 1:
        raise ValueError('exact reader90 and clause101 artifact pair required')
    for name, row in files.items():
        if not re.fullmatch(r'(reader90_[0-9a-f]{24}|clause101_[0-9a-f]{20})\.pickle', name):
            raise ValueError('invalid public reader artifact filename')
        if not isinstance(row, dict) or set(row) != {'sha256', 'bytes'} or not re.fullmatch('[0-9a-f]{64}', row['sha256']) or type(row['bytes']) is not int or not 0 < row['bytes'] <= MAX_ARTIFACT_BYTES:
            raise ValueError('invalid public reader artifact declaration')
    if set(p.name for p in directory.iterdir()) != set(files) | {'MANIFEST.json'}:
        raise ValueError('unexpected public reader artifact file')
    return directory, m


def load(tree, filename):
    directory, manifest = admitted_manifest(tree)
    if filename not in manifest['files']:
        raise ValueError('required public reader artifact missing')
    path = regular(directory / filename)
    row = manifest['files'][filename]
    if path.stat().st_size != row['bytes']:
        raise ValueError('public reader artifact size mismatch')
    # Decode the exact bounded byte string whose digest was checked. A file
    # rewrite/growth after this read cannot substitute unchecked executable data.
    with path.open('rb') as f:
        raw = f.read(MAX_ARTIFACT_BYTES + 1)
    if len(raw) != row['bytes'] or len(raw) > MAX_ARTIFACT_BYTES:
        raise ValueError('public reader artifact actual byte count mismatch')
    if hashlib.sha256(raw).hexdigest() != row['sha256']:
        raise ValueError('public reader artifact digest mismatch')
    return pickle.loads(raw)
