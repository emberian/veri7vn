#!/usr/bin/env python3
"""Untrusted recognizer, bounded candidate search, source renderer and JSON shim.

Request text is parsed as data. No eval, exec, compile, imports from a request,
user definitions or stored source are executed. The separately compiled HOL
checker evaluates the closed DSL and checks every supplied example. This is
example consistency, not a proof of the English specification or generalization.
"""
from __future__ import annotations
import argparse
import ast
import itertools
import json
import keyword
import queue
import signal
import threading
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ASK = re.compile(r'\b(?:write|make|create|build|implement|code|give me)\b.*\b(?:function|program|method|script)\b', re.I | re.S)
CALL = re.compile(r'\b([A-Za-z_][A-Za-z_0-9]*)\s*\(')
CONNECT = re.compile(r'\s*(?:==|->|→|returns?|should\s+(?:return|give|be)|gives?|is)\s*', re.I)
MAX_INTEGER = 10**30
MAX_RESULT = 10**240
MAX_CANDIDATES = 256
RESERVED_NAMES = {'sum','sorted','type','any','int','list','math','abs','len','set','enumerate','max','min','zip','TypeError','ValueError'}

class Unsupported(ValueError):
    pass

def value_type(v, limit=MAX_INTEGER):
    if type(v) is int and abs(v) <= limit:
        return 'int'
    if type(v) is bool:
        return 'bool'
    if type(v) is list and len(v) <= 256 and all(type(x) is int and abs(x) <= limit for x in v):
        return 'list'
    raise Unsupported('Examples must use bounded integers, integer lists or Boolean results.')

def _balanced_end(text, start):
    """Scan one bracket/quoted literal without interpreting or executing it."""
    stack, quote, escaped = [], None, False
    for i in range(start, len(text)):
        c = text[i]
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote: quote = None
            continue
        if c in "\"'": quote = c
        elif c in '([{': stack.append(c)
        elif c in ')]}':
            if not stack or '([{'.index(stack.pop()) != ')]}'.index(c):
                raise Unsupported('An example has unmatched brackets.')
            if not stack: return i + 1
    raise Unsupported('An example has unmatched brackets or quotes.')

def _literal_end(text, start):
    if start >= len(text): raise Unsupported('An example has no expected result.')
    if text[start] in '([{': return _balanced_end(text, start)
    # Strings are scanned so they receive an explicit typed refusal.
    if text[start] in "\"'":
        q, escaped = text[start], False
        for i in range(start + 1, len(text)):
            if escaped: escaped = False
            elif text[i] == '\\': escaped = True
            elif text[i] == q: return i + 1
        raise Unsupported('An example has an unfinished string.')
    m = re.match(r'(?:[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|True\b|False\b|None\b)', text[start:])
    if not m: raise Unsupported('An expected result is not a supported literal.')
    return start + m.end()

def prose_examples(text):
    """Read one explicit prose example as literal data, never as user code."""
    m=re.search(r'\bso\s+(?:that\s+)?',text,re.I)
    if not m: raise Unsupported('Supply at least one literal input/output example.')
    desc=text[:m.start()].rstrip(' ,:;')
    rest=text[m.end():]
    pos=0;args=[]
    while True:
        while pos<len(rest) and rest[pos].isspace():pos+=1
        end=_literal_end(rest,pos)
        try:args.append(ast.literal_eval(rest[pos:end]))
        except (ValueError,SyntaxError,TypeError,RecursionError) as exc:
            raise Unsupported('A prose example must contain literal input data.') from exc
        if len(args)>2:raise Unsupported('This code library supports one or two arguments.')
        pos=end
        sep=re.match(r'\s+(?:becomes|gives?|is|returns?|equals?)\s+',rest[pos:],re.I)
        if sep:
            pos+=sep.end();break
        both=re.match(r'\s+and\s+',rest[pos:],re.I)
        if not both:raise Unsupported('Separate prose example inputs with and, then state their result.')
        pos+=both.end()
    end=_literal_end(rest,pos)
    try:expected=ast.literal_eval(rest[pos:end])
    except (ValueError,SyntaxError,TypeError,RecursionError) as exc:
        raise Unsupported('A prose example must have a literal expected result.') from exc
    if re.sub(r'[\s.;`]', '',rest[end:]):raise Unsupported('Trailing example text is not supported.')
    shapes=[value_type(a) for a in args]
    if 'bool' in shapes:raise Unsupported('Boolean inputs are not integers in this code library.')
    value_type(expected,MAX_RESULT)
    declared=re.search(r'\bfunction\s+([A-Za-z_][A-Za-z_0-9]*)\b',desc,re.I)
    name=declared[1] if declared and declared[1].lower() not in {'that','which','to','for','returning'} else 'solution'
    if len(name)>64 or keyword.iskeyword(name) or name.startswith('__') or name in RESERVED_NAMES:
        raise Unsupported('Use a function name that does not shadow globals used by the code templates.')
    desc=re.sub(r'(\bfunction\s+)'+re.escape(name)+r'\b',r'\1 ',desc,flags=re.I)
    return name,[{'args':args,'expected':expected}],desc,shapes

def examples(text):
    found, name, first, end = [], None, None, 0
    for m in CALL.finditer(text):
        if m.start() < end: continue
        close = _balanced_end(text, text.index('(', m.start()))
        sep = CONNECT.match(text, close)
        if not sep: continue  # optional signature in the description
        stop = _literal_end(text, sep.end())
        try:
            call = ast.parse(text[m.start():close], mode='eval').body
            if not isinstance(call, ast.Call) or not isinstance(call.func, ast.Name) or call.keywords:
                raise Unsupported('Examples must be simple function calls with literal arguments.')
            args = [ast.literal_eval(a) for a in call.args]
            expected = ast.literal_eval(text[sep.end():stop])
        except (SyntaxError, ValueError, TypeError, RecursionError) as e:
            raise Unsupported('Examples must contain literal data; expressions and calls are unsupported.') from e
        if not 1 <= len(args) <= 2: raise Unsupported('This code library supports one or two input arguments.')
        for a in args:
            if value_type(a) == 'bool': raise Unsupported('Boolean inputs are not integers in this code library.')
        value_type(expected,MAX_RESULT)
        if len(call.func.id)>64 or keyword.iskeyword(call.func.id) or call.func.id.startswith('__') or call.func.id in RESERVED_NAMES:
            raise Unsupported('Use a function name that does not shadow globals used by the code templates.')
        if name is not None and name != call.func.id:
            raise Unsupported('All examples must name the same function.')
        if first is not None:
            gap = text[end:m.start()]
            if re.sub(r'\b(?:and|assert|examples?)\b|[\s,;:.`]', '', gap, flags=re.I):
                raise Unsupported('An example contains unsupported text or an unchecked expression.')
        name = call.func.id
        first = m.start() if first is None else first
        end = stop
        found.append({'args':args, 'expected':expected})
        if len(found) > 32: raise Unsupported('At most 32 examples are supported.')
    if not found: return prose_examples(text)
    if re.sub(r'[\s,;:.`]', '', text[end:]):
        raise Unsupported('There is trailing text after the last example; every example must be checked in full.')
    shapes = [value_type(a) for a in found[0]['args']]
    if any([value_type(a) for a in ex['args']] != shapes for ex in found):
        raise Unsupported('Examples must have one consistent argument count and input types.')
    desc = text[:first]
    desc = re.sub(r'\bassert\s*$', '', desc, flags=re.I)
    desc = re.sub(r'\b' + re.escape(name) + r'\s*\([^)]*\)', ' ', desc)
    desc = re.sub(r'(\bfunction\s+)' + re.escape(name) + r'\b', r'\1 ', desc, flags=re.I)
    return name, found, desc, shapes

# The complete renderer is public so a consumer can compare AST and shown source.
# Unique follows HOL remdups: keep the LAST occurrence. This differs from
# dict.fromkeys; the displayed program and packet declare the choice explicitly.
UNARY = {
 'reverse':lambda x:f'({x})[::-1]',
 'sort':lambda x:f'sorted({x})',
 'sort_desc':lambda x:f'sorted({x}, reverse=True)',
 'unique':lambda x:f'[v for i, v in enumerate({x}) if v not in ({x})[i + 1:]]',
 'square_each':lambda x:f'[v * v for v in {x}]',
 'abs_each':lambda x:f'[abs(v) for v in {x}]',
 'negate_each':lambda x:f'[-v for v in {x}]',
 'even_only':lambda x:f'[v for v in {x} if v % 2 == 0]',
 'odd_only':lambda x:f'[v for v in {x} if v % 2 != 0]',
 'positive_only':lambda x:f'[v for v in {x} if v > 0]',
 'negative_only':lambda x:f'[v for v in {x} if v < 0]',
 'sum':lambda x:f'sum({x})',
 'product':lambda x:f'math.prod({x})',
 'factorial':lambda x:f'math.factorial({x})',
 'length':lambda x:f'len({x})',
 'maximum':lambda x:f'max({x})',
 'minimum':lambda x:f'min({x})',
 'all_same':lambda x:f'(len(set({x})) <= 1)',
 'all_unique':lambda x:f'(len(set({x})) == len({x}))',
 'is_sorted':lambda x:f'({x} == sorted({x}))',
 'absolute':lambda x:f'abs({x})',
 'square':lambda x:f'({x} * {x})',
 'cube':lambda x:f'({x} * {x} * {x})',
 'negate':lambda x:f'(-{x})',
 'is_even':lambda x:f'({x} % 2 == 0)',
 'is_odd':lambda x:f'({x} % 2 != 0)',
}
PARAM = {
 'add_each':lambda x,k:f'[v + {k} for v in {x}]',
 'multiply_each':lambda x,k:f'[v * {k} for v in {x}]',
 'above':lambda x,k:f'[v for v in {x} if v > {k}]',
 'below':lambda x,k:f'[v for v in {x} if v < {k}]',
 'take':lambda x,k:f'({x})[:{k}]',
 'drop':lambda x,k:f'({x})[{k}:]',
}
BINARY = {
 'add':lambda a,b:f'({a} + {b})',
 'subtract':lambda a,b:f'({a} - {b})',
 'multiply':lambda a,b:f'({a} * {b})',
 'gcd':lambda a,b:f'math.gcd({a}, {b})',
 'concat':lambda a,b:f'({a} + {b})',
 'zip_add':lambda a,b:f'[x + y for x, y in zip({a}, {b})]',
 'zip_multiply':lambda a,b:f'[x * y for x, y in zip({a}, {b})]',
}

def render(name, arity, program, shapes):
    base = program['base']
    if base['op'] == 'arg': expr = 'a' + str(base['index'])
    else: expr = BINARY[base['op']]('a'+str(base['left']), 'a'+str(base['right']))
    # Sequential bindings ensure repeated subexpressions are evaluated once and
    # make empty maximum/minimum behavior match the partial DSL exactly.
    lines = ['import math'] if program['base']['op']=='gcd' or any(m['op'] in {'product','factorial'} for m in program['moves']) else []
    lines += [f'def {name}(' + ', '.join(f'a{i}' for i in range(arity)) + '):']
    for i, shape in enumerate(shapes):
        if shape=='int':
            lines.append(f"    if type(a{i}) is not int: raise TypeError('Expected integer argument a{i}')")
        else:
            lines.append(f"    if type(a{i}) is not list or any(type(v) is not int for v in a{i}): raise TypeError('Expected integer-list argument a{i}')")
    lines.append(f'    v0 = {expr}')
    for i, move in enumerate(program['moves'], 1):
        op = move['op']
        if op=='factorial':
            lines.append(f"    if not 0 <= v{i-1} <= 100: raise ValueError('Factorial input must be between 0 and 100')")
        expr = UNARY[op](f'v{i-1}') if op in UNARY else PARAM[op](f'v{i-1}',move['constant'])
        lines.append(f'    v{i} = {expr}')
    lines.append(f'    return v{len(program["moves"])}')
    return '\n'.join(lines) + '\n'

# Deliberately bounded description vocabulary: unsupported qualifications are
# terminal refusals rather than silently erased. Recognition remains untrusted.
GENERIC = set('write make create build implement code give me a an the function program method script python that returns return returning of to and then for from in with input output examples example assert given integer integers number numbers list lists array arrays sequence sequences value values elements items each every all two by their its it is are check checks whether computes compute calculate calculates result using takes accepts first last occurrence occurrences keeping keep remove removed duplicates duplicate distinct deduplicate deduplicated unique order ordered ascending descending sorted sort reverse reversed sum total product length count size maximum minimum largest smallest biggest absolute abs square squares squared cube cubed negate negated negation even odd positive negative only filter filters filtered add adds addition plus subtract subtracts subtraction difference minus multiply multiplies multiplication times concatenate concatenates concatenation concat combine combined zip elementwise pairwise same identical above below greater less than take drop skip' .split())

def ranked_moves(low):
    """A named order statistic expands to existing checked list operations."""
    rx=re.compile(r'\b(first|second|third|fourth|\d+(?:st|nd|rd|th))[-\s]+'
                  r'(?:(distinct)\s+)?(largest|smallest)(?:\s+(distinct))?'
                  r'(?:\s+(?:number|integer|element))?'
                  r'(?:\s+((?:including|counting|without)\s+duplicates))?\b')
    matches=list(rx.finditer(low))
    if not matches:return low,[],False
    if len(matches)!=1:raise Unsupported('Name one ranked target quantity.')
    m=matches[0]
    words={'first':1,'second':2,'third':3,'fourth':4}
    rank=words.get(m[1])
    if rank is None:rank=int(re.match(r'\d+',m[1])[0])
    if not 1<=rank<=1000:raise Unsupported('Rank must be between 1 and 1000.')
    qualifier=m[5] or ''
    distinct=bool(m[2] or m[4] or qualifier.startswith('without'))
    repeated=qualifier.startswith(('including','counting'))
    if distinct and repeated:raise Unsupported('State whether duplicate values count separately.')
    order='sort_desc' if m[3]=='largest' else 'sort'
    extreme='maximum' if m[3]=='largest' else 'minimum'
    core=[{'op':order},{'op':'drop','constant':rank-1},{'op':extreme}]
    choices=([{'macro':[{'op':'unique'}]+core}] if distinct else
             [{'macro':core}] if repeated else [{'macro':core},{'macro':[{'op':'unique'}]+core}])
    return low[:m.start()]+' '+low[m.end():],choices,not distinct and not repeated

def candidates(desc, shapes):
    low = desc.lower()
    inflections = {'sums':'sum','counts':'count','keeps':'keep','doubles':'double','merges':'merge','removes':'remove','reverses':'reverse','sorts':'sort','negates':'negate','removing':'remove','concatenates':'concatenate','adds':'add','subtracts':'subtract','multiplies':'multiply'}
    low = re.sub(r'\b(?:'+ '|'.join(inflections) +r')\b',lambda m:inflections[m[0]],low)
    low = re.sub(r'\bwhile\s+remove\b','remove',low)
    parameter_groups = []
    patterns = [
      ('add_each', r'\badd\s+([-+]?\d+)\s+to\s+each\b'),
      ('multiply_each', r'\bmultiply\s+each\s+by\s+([-+]?\d+)\b'),
      ('above', r'\b(?:greater\s+than|above)\s+([-+]?\d+)\b'),
      ('below', r'\b(?:less\s+than|below)\s+([-+]?\d+)\b'),
      ('take', r'\b(?:take|first)\s+(\d+)\b'),
      ('drop', r'\b(?:drop|skip)\s+(\d+)\b'),
    ]
    for op, rx in patterns:
        matches = list(re.finditer(rx, low))
        if len(matches)>1: raise Unsupported('Repeated parameter operations need a more explicit recipe.')
        for m in matches:
            k = int(m[1])
            if abs(k)>1000: raise Unsupported('Description parameters are limited to magnitude 1000.')
            parameter_groups.append([{'op':op,'constant':k}])
        low = re.sub(rx,' ',low)
    if re.search(r'\b(double|doubled|twice)\b',low):
        parameter_groups.append([{'op':'multiply_each','constant':2}])
        low=re.sub(r'\b(double|doubled|twice)\b',' ',low)
    low,rank_choices,rank_ambiguous=ranked_moves(low)
    if rank_choices:parameter_groups.append(rank_choices)
    words = set(re.findall(r'[a-zA-Z_]+', low))
    unknown = words - GENERIC - {'preserve','preserves','preserving','original','after','them','double','doubled','twice','merge','gcd','greatest','common','divisor','factorial','so'}
    if unknown: raise Unsupported('The bounded code vocabulary does not cover: ' + ', '.join(sorted(unknown)) + '.')
    if re.search(r'\b(?:first|last)\b', low) and not re.search(r'\b(?:first|last)\s+occurrences?\b', low):
        raise Unsupported('Positional qualifiers need an explicit supported operation.')
    groups = parameter_groups
    def group(*ops): groups.append([{'op':op} for op in ops])
    has = lambda pattern: re.search(pattern, low) is not None
    bases = [{'op':'arg','index':0}]
    if len(shapes)==2:
        if shapes==['int','int']:
            options = [('add',r'\b(add|adds|addition|sum|plus|total)\b'),('subtract',r'\b(subtract|subtracts|subtraction|difference|minus)\b'),('multiply',r'\b(multiply|multiplies|multiplication|product|times)\b'),('gcd',r'\bgcd\b|\bgreatest common divisor\b')]
        elif shapes==['list','list']:
            options = [('concat',r'\b(concatenate|concatenation|concat|combine|merge)\b'),('zip_add',r'\b(add|sum|plus)\b'),('zip_multiply',r'\b(multiply|product|times)\b')]
        else: raise Unsupported('The current binary library needs two integers or two integer lists.')
        bases = [{'op':op,'left':0,'right':1} for op,rx in options if has(rx)]
        if len(bases)!=1: raise Unsupported('Name one supported binary operation for two arguments.')
        # Binary operation words belong to the base, not another unary reducer.
        low = re.sub(options[[x[0] for x in options].index(bases[0]['op'])][1], '', low)
    if has(r'\b(sum|total)\b'): group('sum')
    if has(r'\bproduct\b'): group('product')
    if has(r'\bfactorial\b'): group('factorial')
    if has(r'\b(length|count|size)\b|\bnumber of\b'): group('length')
    if has(r'\b(maximum|largest|biggest)\b'): group('maximum')
    if has(r'\b(minimum|smallest)\b'): group('minimum')
    if has(r'\b(same|identical)\b'): group('all_same')
    if has(r'\b(unique|distinct|deduplicate|deduplicated|duplicates?)\b'):
        if has(r'\b(check|checks|whether)\b'): group('all_unique')
        else:
            first_requested=has(r'\bfirst\s+occurrences?\b|\b(?:preserv(?:e|es|ing)|keep(?:ing)?)\s+(?:the\s+)?(?:original\s+)?order\b')
            last_requested=has(r'\blast\s+occurrences?\b')
            if (first_requested and last_requested) or (has(r'\bfirst\b') and has(r'\blast\b')):
                raise Unsupported('Choose first-occurrence or last-occurrence deduplication.')
            first=[{'op':'reverse'},{'op':'unique'},{'op':'reverse'}]
            last=[{'op':'unique'}]
            if first_requested:
                groups.append([{'macro':first}])
            elif last_requested:
                groups.append([{'macro':last}])
            else: groups.append([{'macro':first},{'macro':last}])
    if has(r'\b(sort|sorted|ascending|descending|ordered)\b'):
        group('is_sorted' if has(r'\b(check|checks|whether)\b') else ('sort_desc' if has(r'\bdescending\b') else 'sort'))
    if has(r'\b(reverse|reversed)\b'): group('reverse')
    if has(r'\b(square|squares|squared)\b'): group('square_each','square')
    if has(r'\b(cube|cubed)\b'): group('cube')
    if has(r'\b(absolute|abs)\b'): group('abs_each','absolute')
    if has(r'\b(negate|negated|negation)\b'): group('negate_each','negate')
    if has(r'\beven\b'): group('even_only','is_even')
    if has(r'\bodd\b'): group('odd_only','is_odd')
    if has(r'\bpositive\b'): group('positive_only')
    if has(r'\bnegative\b'): group('negative_only')
    if re.search(r'\d',low): raise Unsupported('Numeric description parameters are not supported by this recognizer yet.')
    if not groups and bases[0]['op']=='arg': raise Unsupported('Name a supported library operation in the description.')
    if len(groups)>4: raise Unsupported('At most four named unary operations are supported.')
    if rank_ambiguous and len(groups)>1:
        raise Unsupported('State whether duplicate values count separately before composing a ranked target.')
    programs=[]
    for choice in itertools.product(*groups):
        for moves in itertools.permutations(choice):
            for base in bases:
                expanded=[piece for m in moves for piece in m.get('macro',[m])]
                if len(expanded)>4: continue
                programs.append({'base':base,'moves':expanded})
                if len(programs)>MAX_CANDIDATES: raise Unsupported('The named operation combinations exceed the bounded search budget.')
    return programs

class Kernel:
    def __init__(self, path):
        self.proc=subprocess.Popen([str(path)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)
        self.lines=queue.Queue()
        proc, lines=self.proc,self.lines
        def pump():
            try:
                for line in proc.stdout: lines.put(line)
            finally: lines.put(None)
        self.reader=threading.Thread(target=pump,daemon=True)
        self.reader.start()
    def check(self, program, cases):
        self.proc.stdin.write(json.dumps({'program':program,'examples':cases},separators=(',',':'))+'\n')
        self.proc.stdin.flush()
        try: line=self.lines.get(timeout=5)
        except queue.Empty:
            self.close(terminate=True)
            raise RuntimeError('code checker timed out; request was not replayed')
        if line is None: raise RuntimeError('code checker exited')
        def bounded_integer(s):
            if len(s.lstrip('-'))>241: raise Unsupported('A program intermediate exceeds the runtime integer bound.')
            n=int(s)
            if abs(n)>10**240: raise Unsupported('A program intermediate exceeds the runtime integer bound.')
            return n
        result=json.loads(line,parse_int=bounded_integer)
        for v in result.get('results',[]):
            if type(v) is list and len(v)>256:
                raise Unsupported('A program intermediate exceeds the runtime list bound.')
        return result
    def close(self,terminate=False):
        # Only this exact Popen child is signalled; never search for processes.
        proc=getattr(self,'proc',None)
        if proc is None: return
        self.proc=None
        if terminate and proc.poll() is None: proc.terminate()
        try: proc.stdin.close()
        except (OSError,ValueError): pass
        try: proc.wait(timeout=0.4)
        except subprocess.TimeoutExpired:
            proc.terminate()
            try: proc.wait(timeout=0.3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait(timeout=0.3)
        self.reader.join(timeout=0.1)
        proc.stdout.close()


def probe_cases(shapes):
    # These are observations for ambiguity detection, never a proof of equivalence.
    vals={'int':[-7,-2,0,1,4,9], 'list':[[],[0],[-3,1,2,-3,0,4],[4,1,4,2],[-5,-2],list(range(-3,4))]}
    return [{'args':list(args),'expected':0} for args in itertools.product(*(vals[t] for t in shapes))]

def deduplication_note(moves):
    """Describe recognized macro steps without mislabeling other primitives."""
    ops=[m['op'] for m in moves]
    first_count=bare_count=0
    i=0
    while i<len(ops):
        if ops[i:i+3]==['reverse','unique','reverse']:
            first_count+=1;i+=3
        else:
            bare_count+=ops[i]=='unique';i+=1
    if bare_count:
        return "\nThe deduplication step keeps each value's last occurrence."
    if first_count:
        return "\nThe deduplication sequence keeps each value's first occurrence."
    return ''

def answer(request, kernel):
    q=request.get('q')
    rid=request.get('id')
    if not isinstance(q,str): return {'id':rid,'error':'request has no string q'}
    if not ASK.search(q): return {'id':rid,'status':'withheld','path':'','response':'','provenance':{'taken':False}}
    try:
        if len(q)>16000: raise Unsupported('Code requests are limited to 16000 characters.')
        name, cases, desc, shapes=examples(q)
        programs=candidates(desc,shapes)
        matches=[]
        for p in programs:
            checked=kernel.check(p,cases)
            if checked.get('accepted') is True:
                # Check every sequential intermediate against the consumer's
                # work bounds using the native evaluator, rather than letting
                # a large product disappear behind a later predicate.
                for prefix in range(len(p['moves'])):
                    kernel.check({'base':p['base'],'moves':p['moves'][:prefix]},cases)
                matches.append((p,checked))
        if not matches: raise Unsupported('No program using every named operation matches all supplied examples.')
        signatures={}
        probes=probe_cases(shapes)
        for p,checked in matches:
            signature=json.dumps(kernel.check(p,probes).get('results'),sort_keys=True)
            signatures.setdefault(signature,(p,checked))
        if len(signatures)>1:
            raise Unsupported('Several named programs fit the examples but disagree on additional inputs. Add examples that distinguish the intended order of operations.')
        program,checked=next(iter(signatures.values()))
        source=render(name,len(shapes),program,shapes)
        packet={'schema_version':1,'kind':'code_program','checker':'Codekernel.check_program','accepted':True,
                'program':program,'examples':cases,'results':checked['results'],
                'function_name':name,'argument_count':len(shapes),'program_source':source,
                'matching_candidates':len(matches),'ambiguity_probe_count':len(probes),
                'assumptions':['Examples are the requested literal data.','The bounded description recognizer selected the intended named operations.'],
                'scope':'All supplied examples match. Additional probes do not establish program equivalence or intended behavior on other inputs.',
                'semantics':{'integer_type':'unbounded mathematical integer; Boolean is distinct',
                  'list_type':'finite list of integers','zip':'truncate to shorter input',
                  'unique':'retain last occurrence','maximum_minimum_empty':'undefined; candidate rejected for an empty-list example'}}
        claim=('This candidate matches the supplied example. The example does not determine its behavior on other inputs.' if len(cases)==1 else 'This candidate matches all '+str(len(cases))+' supplied examples. The examples do not determine its behavior on other inputs.')
        response='```python\n'+source+'```\n'+claim
        response += deduplication_note(program['moves'])
        if program['base']['op'] in {'zip_add','zip_multiply'}:
            response += '\nPairwise operations stop at the shorter input list.'
        return {'id':rid,'status':'answered','path':'organ:code>checked_examples','kind':'code_program','response':response,
                'provenance':{'taken':True,'request_text':q,'recognition_trusted':False,'source_rendering_trusted':False,
                  'kernel':'Codekernel.check_program','session':'Veri7vn_CodeOrgan','evidence':{'checked_computation':packet}}}
    except Unsupported as e:
        return {'id':rid,'status':'withheld','path':'organ:code>unsupported','kind':'code_program_refusal','response':str(e),
                'provenance':{'taken':True,'recognition_trusted':False}}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--kernel',type=Path,default=ROOT/'var/codeorgan/bin/codeorgan-kernel')
    args=parser.parse_args()
    kernel=None
    stopping=False
    def stop(signum,frame):
        nonlocal stopping
        stopping=True
        raise SystemExit(128+signum)
    signal.signal(signal.SIGTERM,stop)
    try:
        kernel=Kernel(args.kernel)
        for line in sys.stdin:
            if not line.strip(): continue
            try: reply=answer(json.loads(line),kernel)
            except Exception as e: reply={'id':None,'error':str(e)}
            print(json.dumps(reply,separators=(',',':')),flush=True)
    finally:
        if kernel is not None: kernel.close(terminate=stopping)
if __name__=='__main__': main()
