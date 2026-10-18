"""UNTRUSTED independent replay of the closed code-example DSL.

No source supplied by a producer is executed. Exact expected source is rebuilt
from a validated AST; arithmetic is replayed on supplied literal examples only.
Neither check establishes intended behavior on inputs absent from the examples.
"""
import keyword
import math
import re

LIMIT = 10**30
WORK_LIMIT = 10**240
RENDER_GLOBALS = {'type', 'any', 'int', 'list', 'TypeError', 'sorted',
                  'enumerate', 'abs', 'sum', 'math', 'len', 'set', 'max', 'min', 'zip'}


def obj(value, fields, name):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise ValueError(f'{name}: unexpected or missing fields')


def value(v, limit=LIMIT):
    if type(v) is bool:
        return 'bool'
    if type(v) is int and abs(v) <= limit:
        return 'int'
    if type(v) is list and len(v) <= 256 and all(type(x) is int and abs(x) <= limit for x in v):
        return 'list'
    raise ValueError('code value exceeds the finite integer/list domain')


def index(n, arity):
    if type(n) is not int or not 0 <= n < arity:
        raise ValueError('invalid code argument index')
    return n


def equal(a, b):
    return type(a) is type(b) and a == b


# Each entry binds the public operation to input type, independent evaluator,
# and the exact source expression that implements that operation.
UNARY = {
 'reverse': ('list', lambda x:x[::-1], '({x})[::-1]'),
 'sort': ('list', sorted, 'sorted({x})'),
 'sort_desc': ('list', lambda x:sorted(x,reverse=True), 'sorted({x}, reverse=True)'),
 'unique': ('list', lambda x:[v for i,v in enumerate(x) if v not in x[i+1:]], '[v for i, v in enumerate({x}) if v not in ({x})[i + 1:]]'),
 'square_each': ('list', lambda x:[v*v for v in x], '[v * v for v in {x}]'),
 'abs_each': ('list', lambda x:[abs(v) for v in x], '[abs(v) for v in {x}]'),
 'negate_each': ('list', lambda x:[-v for v in x], '[-v for v in {x}]'),
 'even_only': ('list', lambda x:[v for v in x if v%2==0], '[v for v in {x} if v % 2 == 0]'),
 'odd_only': ('list', lambda x:[v for v in x if v%2!=0], '[v for v in {x} if v % 2 != 0]'),
 'positive_only': ('list', lambda x:[v for v in x if v>0], '[v for v in {x} if v > 0]'),
 'negative_only': ('list', lambda x:[v for v in x if v<0], '[v for v in {x} if v < 0]'),
 'sum': ('list', sum, 'sum({x})'),
 'product': ('list', math.prod, 'math.prod({x})'),
 'length': ('list', len, 'len({x})'),
 'maximum': ('list', max, 'max({x})'),
 'minimum': ('list', min, 'min({x})'),
 'all_same': ('list', lambda x:len(set(x))<=1, '(len(set({x})) <= 1)'),
 'all_unique': ('list', lambda x:len(set(x))==len(x), '(len(set({x})) == len({x}))'),
 'is_sorted': ('list', lambda x:x==sorted(x), '({x} == sorted({x}))'),
 'absolute': ('int', abs, 'abs({x})'),
 'square': ('int', lambda x:x*x, '({x} * {x})'),
 'cube': ('int', lambda x:x*x*x, '({x} * {x} * {x})'),
 'negate': ('int', lambda x:-x, '(-{x})'),
 'is_even': ('int', lambda x:x%2==0, '({x} % 2 == 0)'),
 'is_odd': ('int', lambda x:x%2!=0, '({x} % 2 != 0)'),
}
PARAM = {
 'add_each': (lambda x,k:[v+k for v in x], '[v + {k} for v in {x}]'),
 'multiply_each': (lambda x,k:[v*k for v in x], '[v * {k} for v in {x}]'),
 'above': (lambda x,k:[v for v in x if v>k], '[v for v in {x} if v > {k}]'),
 'below': (lambda x,k:[v for v in x if v<k], '[v for v in {x} if v < {k}]'),
 'take': (lambda x,k:x[:k], '({x})[:{k}]'),
 'drop': (lambda x,k:x[k:], '({x})[{k}:]'),
}
BINARY = {
 'add': ('int', lambda a,b:a+b, '({a} + {b})'),
 'subtract': ('int', lambda a,b:a-b, '({a} - {b})'),
 'multiply': ('int', lambda a,b:a*b, '({a} * {b})'),
 'concat': ('list', lambda a,b:a+b, '({a} + {b})'),
 'zip_add': ('list', lambda a,b:[x+y for x,y in zip(a,b)], '[x + y for x, y in zip({a}, {b})]'),
 'zip_multiply': ('list', lambda a,b:[x*y for x,y in zip(a,b)], '[x * y for x, y in zip({a}, {b})]'),
}
SEMANTICS = {'integer_type':'unbounded mathematical integer; Boolean is distinct',
 'list_type':'finite list of integers','zip':'truncate to shorter input',
 'unique':'retain last occurrence','maximum_minimum_empty':'undefined; candidate rejected for an empty-list example'}
SCOPE = 'All supplied examples match. Additional probes do not establish program equivalence or intended behavior on other inputs.'


def deduplication_note(moves):
    """Describe the composed first-occurrence macro, not its inner primitive."""
    ops = [move['op'] for move in moves]
    first = last = False
    i = 0
    while i < len(ops):
        if ops[i:i + 3] == ['reverse', 'unique', 'reverse']:
            first = True
            i += 3
        else:
            last = last or ops[i] == 'unique'
            i += 1
    if last:
        return "\nThe deduplication step keeps each value's last occurrence."
    if first:
        return "\nThe deduplication sequence keeps each value's first occurrence."
    return ''


def program_operations(program, arity):
    obj(program, {'base','moves'}, 'code program')
    base, moves = program['base'], program['moves']
    if not isinstance(base, dict) or not isinstance(base.get('op'),str):
        raise ValueError('invalid code program base')
    if base['op']=='arg':
        obj(base, {'op','index'}, 'argument base'); i=index(base['index'],arity)
        start=lambda args,i=i:args[i]; source='a'+str(i)
    else:
        obj(base, {'op','left','right'}, 'binary base')
        if base['op'] not in BINARY: raise ValueError('unknown code binary operation')
        l,r=index(base['left'],arity),index(base['right'],arity)
        typ,fn,template=BINARY[base['op']]
        def start(args, l=l, r=r, typ=typ, fn=fn):
            if value(args[l])!=typ or value(args[r])!=typ: raise ValueError('binary argument type mismatch')
            return fn(args[l],args[r])
        source=template.format(a='a'+str(l),b='a'+str(r))
    if not isinstance(moves,list) or len(moves)>4: raise ValueError('code move count exceeds four')
    steps=[]; expressions=[]
    for i,m in enumerate(moves):
        if not isinstance(m,dict) or not isinstance(m.get('op'),str): raise ValueError('invalid code move')
        op=m['op']
        if op in UNARY:
            obj(m, {'op'}, 'unary move');typ,fn,template=UNARY[op]
            steps.append((typ,fn));expressions.append(template.format(x=f'v{i}'))
        elif op in PARAM:
            obj(m, {'op','constant'}, 'parameter move');k=m['constant']
            if type(k) is not int or abs(k)>1000 or (op in ('take','drop') and k<0): raise ValueError('invalid code parameter')
            fn,template=PARAM[op];steps.append(('list',lambda x,f=fn,k=k:f(x,k)))
            expressions.append(template.format(x=f'v{i}',k=k))
        else: raise ValueError('unknown code move')
    def run(args):
        current=start(args);value(current,WORK_LIMIT)
        for typ,fn in steps:
            if value(current,WORK_LIMIT)!=typ: raise ValueError('code move type mismatch')
            current=fn(current);value(current,WORK_LIMIT)
        return current
    return run,source,expressions


def validate_code(reply, packet):
    obj(packet, {'schema_version','kind','checker','accepted','program','examples','results',
        'function_name','argument_count','program_source','matching_candidates','ambiguity_probe_count',
        'assumptions','scope','semantics'}, 'code computation packet')
    if (packet['schema_version']!=1 or type(packet['schema_version']) is not int or
        packet['kind']!='code_program' or packet['checker']!='Codekernel.check_program' or packet['accepted'] is not True):
        raise ValueError('code checker did not accept the supported computation')
    if reply.get('status')!='answered' or reply.get('kind')!='code_program': raise ValueError('code packet attached to a different decision')
    name,arity=packet['function_name'],packet['argument_count']
    if not isinstance(name,str) or not re.fullmatch(r'[A-Za-z_][A-Za-z_0-9]{0,63}',name) or keyword.iskeyword(name) or name.startswith('__') or name in RENDER_GLOBALS:
        raise ValueError('invalid code function name')
    if type(arity) is not int or arity not in (1,2): raise ValueError('invalid code arity')
    cases,results=packet['examples'],packet['results']
    if not isinstance(cases,list) or not 2<=len(cases)<=32 or not isinstance(results,list) or len(results)!=len(cases): raise ValueError('incomplete code examples or results')
    run,source,expressions=program_operations(packet['program'],arity)
    shapes=None
    for case,result in zip(cases,results):
        obj(case, {'args','expected'}, 'code example');args=case['args']
        if not isinstance(args,list) or len(args)!=arity: raise ValueError('example arity mismatch')
        types=[]
        for a in args:
            typ=value(a)
            if typ=='bool' or (typ=='list' and len(a)>256): raise ValueError('invalid example input')
            types.append(typ)
        if shapes is not None and types!=shapes: raise ValueError('example input types differ')
        shapes=types;value(case['expected']);value(result)
        if any(type(v) is list and len(v)>256 for v in (case['expected'],result)):
            raise ValueError('example output exceeds the list bound')
        actual=run(args)
        if not equal(actual,case['expected']) or not equal(actual,result): raise ValueError('code replay disagrees with an example or result')
    lines=['import math'] if any(m['op']=='product' for m in packet['program']['moves']) else []
    lines += [f'def {name}('+', '.join(f'a{i}' for i in range(arity))+'):']
    for i,typ in enumerate(shapes):
        if typ=='int':
            lines.append(f"    if type(a{i}) is not int: raise TypeError('Expected integer argument a{i}')")
        else:
            lines.append(f"    if type(a{i}) is not list or any(type(v) is not int for v in a{i}): raise TypeError('Expected integer-list argument a{i}')")
    lines.append(f'    v0 = {source}')
    lines += [f'    v{i} = {e}' for i,e in enumerate(expressions,1)]
    lines += [f'    return v{len(expressions)}'];rendered='\n'.join(lines)+'\n'
    expected='```python\n'+rendered+'```\nThis candidate matches all '+str(len(cases))+' supplied examples. The examples do not determine its behavior on other inputs.'
    expected += deduplication_note(packet['program']['moves'])
    if packet['program']['base']['op'] in ('zip_add','zip_multiply'):
        expected+='\nPairwise operations stop at the shorter input list.'
    if packet['program_source']!=rendered or reply.get('response')!=expected: raise ValueError('displayed code disagrees with the validated program')
    if 'value' in reply: raise ValueError('a synthesized program is not one numeric answer')
    if packet['scope']!=SCOPE or packet['semantics']!=SEMANTICS: raise ValueError('code evidence omits required semantic limits')
    for key,low,high in [('matching_candidates',1,256),('ambiguity_probe_count',1,36)]:
        if type(packet[key]) is not int or not low<=packet[key]<=high: raise ValueError('invalid bounded search declaration')
    a=packet['assumptions']
    if not isinstance(a,list) or any(not isinstance(x,str) or not x for x in a): raise ValueError('invalid code assumptions')
    return {'status':'consistent','checker':'python_closed_code_v1',
      'checks':['typed_program_domain','every_supplied_example','reported_results','displayed_source_matches'],
      'explanation':f'Replayed the closed program on all {len(cases)} supplied examples and matched the displayed source to its operation tree.',
      'boundary':'This untrusted Python replay checks supplied examples and source rendering. It does not establish English recognition, search completeness, candidate equivalence, or behavior intended on other inputs.'}
