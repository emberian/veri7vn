"""UNTRUSTED whole-request parser for the checked query constraint consumer.

Produces a property, slot and typed query constraint; stripping a type without
executing its predicate is forbidden. Entity linking/source classes stay premises.
"""
from dataclasses import dataclass
import re

@dataclass(frozen=True)
class Query:
    prop: int
    slot: str
    query_kind: str
    canonical: str
    frame: str
    literal_slot: str

FIELDS = {
    'birthplace': (19, 'Where was {} born?'),
    'place of birth': (19, 'Where was {} born?'),
    'place of death': (20, 'Where did {} die?'),
    'instrument': (1303, 'What instrument did {} play?'),
    'capital': (36, 'What is the capital of {}?'),
    'author': (50, 'Who wrote {}?'),
    'director': (57, 'Who directed {}?'),
    'composer': (86, 'Who composed {}?'),
    'creator': (170, 'Who created {}?'),
    'publisher': (123, 'Who published {}?'),
    'inventor': (61, 'Who invented {}?'),
    'discoverer': (61, 'Who discovered {}?'),
    'country': (17, 'In which country is {}?'),
}
TYPE_ROOTS = {'film': [11424], 'novel': [8261], 'book': [571],
              'country': [6256,3624078],
              # The source omits P279 edges for several explicitly named city
              # classes. These checked class IDs are interpretation premises,
              # not invented subclass rows. Town/national-capital alone is absent.
              'city': [515,1549591,2264924,1093829,25412763,494721,11422368,1749269], 'song': [7366],
              'album': [482994], 'painting': [3305213]}
# Source ontology IDs are interpretation premises. Explicit composer and
# journalist requests are narrower than the inherited reader domains, which
# also admit conductors and television presenters respectively.
OCCUPATION_ROOTS = {
    'actor': [33999], 'chemist': [593644], 'composer': [36834],
    'graphic artist': [1925963], 'journalist': [1930187],
    'musician': [386854, 1259917, 855091, 639669, 486748],
    'painter': [1028181], 'philosopher': [4964182],
    'photographer': [33231], 'physician': [39631],
    'physicist': [169470], 'poet': [49757],
    'sculptor': [1281618], 'singer': [177220],
}
DIRECT = {
    19: r'where (?:is|was) (?P<slot>.+) born',
    20: r'where did (?P<slot>.+) die',
    1303: r'(?:what|which) instrument (?:does|did) (?P<slot>.+) play',
    36: r'what is the capital(?: city)? of (?P<slot>.+)',
    50: r'who (?:wrote|penned) (?P<slot>.+)',
    57: r'who directed (?P<slot>.+)',
    86: r'who composed (?P<slot>.+)',
    170: r'who (?:created|made|sculpted|drew) (?P<slot>.+)',
    123: r'who published (?P<slot>.+)',
}

def parse(text):
    # Only a final question/full stop is syntax, internal punctuation stays in
    # the exact entity slot. No find/search/suffix match and no clause deletion.
    if not isinstance(text,str):return None
    s=text.strip()
    if s.endswith(('?','.')):s=s[:-1].rstrip()
    if not s or '\n' in s or '\r' in s:return None
    place=re.fullmatch(r'(?:the |which |what )country in which (?:the )(?P<kind>city|country) of (?P<name>.+) (?:lies|is located)',s,re.I)
    if place:
        slot=place['name'];kind=place['kind'].lower()
        return Query(17,slot,kind,'In which country is '+slot+'?',
                     s[:place.start('name')]+'{target}'+s[place.end('name'):],slot)
    match=re.fullmatch(r'(?:(?:what|who) is |(?:tell|show) me |name )?(?:the )?(?P<field>'+ '|'.join(FIELDS)+r') of (?P<slot>.+)',s,re.I)
    prop=template=slot=frame=None
    if match:
        prop,template=FIELDS[match['field'].lower()]
        slot=match['slot'];frame=s[:match.start('slot')]+'{target}'
    else:
        for p,pattern in DIRECT.items():
            match=re.fullmatch(pattern,s,re.I)
            if match:
                prop=p;slot=match['slot'];frame=s[:match.start('slot')]+'{target}'+s[match.end('slot'):]
                template=next(t for pp,t in FIELDS.values() if pp==p);break
    if slot is None:return None
    literal_slot=slot
    typed=re.fullmatch(r'(?:the )?(?P<kind>'+ '|'.join((*TYPE_ROOTS,*OCCUPATION_ROOTS))+r') (?P<name>.+)',slot,re.I)
    kind='any'
    if typed:
        kind=typed['kind'].lower();slot=typed['name']
    # Existing person readers distinguish and sometimes deliberately drop
    # individual surface forms. Canonicalizing a bare birthplace/death/instrument
    # question would change that decision. Only explicit types use this new path.
    if prop in (19,20,1303) and kind == 'any':return None
    # Empty quoted names and adjacent punctuation cannot become a slot.
    if not slot.strip() or not any(c.isalnum() for c in slot):return None
    return Query(prop,slot,kind,template.format(slot),frame,literal_slot)


def interpret(text, lookup):
    """Keep a complete linked title as an alternative to typed decomposition.

    This finite linker boundary is untrusted. Two distinct linked readings
    clarify; no proper title is silently reduced to its trailing words.
    """
    q=parse(text)
    if q is None or q.query_kind=='any':return q
    literal={row[0] for row in lookup(q.literal_slot)}
    if not literal:return q
    stripped={row[0] for row in lookup(q.slot)}
    if stripped and literal != stripped:
        return Query(q.prop,q.literal_slot,'ambiguous',q.canonical,q.frame,q.literal_slot)
    if stripped:return q
    template=next(t for p,t in FIELDS.values() if p==q.prop)
    return Query(q.prop,q.literal_slot,'any',template.format(q.literal_slot),q.frame,q.literal_slot)


def constraint(query):
    if query is None or query.query_kind == 'any':
        return ['any']
    if query.query_kind=='ambiguous':return ['unknown']
    if query.query_kind in OCCUPATION_ROOTS:
        return ['property_class',106,OCCUPATION_ROOTS[query.query_kind]]
    roots=TYPE_ROOTS[query.query_kind]
    if query.query_kind == 'novel':
        return ['either',['instance',roots],['property_class',136,roots]]
    return ['instance',roots]


def property_ids(expression):
    if expression[0]=='property_class':return {expression[1]}
    if expression[0]=='either':return property_ids(expression[1]) | property_ids(expression[2])
    return set()
