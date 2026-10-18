"""UNTRUSTED receipt-grounded dialogue state and finite English readings.

No entity is inferred from answer prose. Only accepted producer metadata can
supply identity. Numeric grounding uses explicit kernel values and bounded
unit/variable framing. This module does not call routes or write external state.
"""
from __future__ import annotations
from copy import deepcopy
from dataclasses import dataclass, field
from fractions import Fraction
import re
from runtime_contract import validate_reply_evidence


def outcome(reply):
    if 'error' in reply:
        return 'failed'
    if reply.get('status') == 'answered':
        return 'answered'
    if (reply.get('path') == 'dispatch>declined' and
            not reply.get('provenance', {}).get('taken') and
            not reply.get('provenance', {}).get('dispatch', {}).get('decisive')):
        return 'unrecognized'
    return 'refused'


@dataclass(frozen=True)
class Entity:
    qid: str
    label: str
    entity_kind: str
    entity_domain: str | None = None

    @classmethod
    def read(cls, item):
        if not isinstance(item, dict):
            return None
        qid, label, kind = (item.get(k) for k in ('qid', 'label', 'entity_kind'))
        if (isinstance(qid, str) and re.fullmatch(r'Q[1-9][0-9]*', qid) and
                isinstance(label, str) and label.strip() and len(label) <= 300 and
                not any(c in label for c in '\n\r\x00') and kind in ('person', 'thing', 'unknown')):
            return cls(qid, label, kind, item.get('entity_domain') if isinstance(item.get('entity_domain'), str) else None)
        return None

    def wire(self):
        return {'qid': self.qid, 'label': self.label, 'entity_kind': self.entity_kind}


@dataclass(frozen=True)
class Numeric:
    exact: str
    unit: str


def exact(value):
    if not isinstance(value, str) or len(value) > 256:
        return None
    if not re.fullmatch(r'[+-]?[0-9]+(?:/[1-9][0-9]*|\.[0-9]+)?', value):
        return None
    try:
        q = Fraction(value)
        return str(q.numerator) if q.denominator == 1 else str(q)
    except (ValueError, ZeroDivisionError):
        return None


@dataclass(frozen=True)
class Ground:
    source_turn: int
    query_entity: Entity | None = None
    answer_entity: Entity | None = None
    number: Numeric | None = None
    solved: dict = field(default_factory=dict)
    slot_surface: str | None = None
    standalone: str = ''
    property: str | None = None
    native_owner: str | None = None

    @classmethod
    def from_reply(cls, index, standalone, reply):
        if outcome(reply) != 'answered':
            return None
        p = reply.get('provenance', {})
        c = p.get('conversation', {})
        if not isinstance(c, dict):
            c = {}
        # Producer schema, not caller JSON or popularity-based relinking.
        query, answer = Entity.read(c.get('query_entity')), Entity.read(c.get('answer_entity'))
        dispatch = p.get('dispatch', {})
        commit = dispatch.get('commit', {}) if isinstance(dispatch, dict) else {}
        # A private committed warehouse owns an item reference, not a globally
        # identified entity. Preserve that opaque context only for its reader.
        native_path = re.fullmatch(r'specialist_call>specialist:(warehouse(?:-r2)?)>[^>]+', reply.get('path', ''))
        native_owner = (native_path[1] if native_path and p.get('kernel') == 'Stores.site_reply' and
                        p.get('preview') is False and isinstance(commit, dict) and
                        commit.get('attempted') is True
                        else None)
        number = None
        goal, decision = p.get('goal'), p.get('decision', {})
        if isinstance(goal, list) and len(goal) == 3 and goal[0] == 'dim' and isinstance(decision, dict):
            value, unit = exact(decision.get('value')), goal[2]
            if value is not None and isinstance(unit, str) and re.fullmatch(r'[A-Za-z$][A-Za-z0-9*/^ .-]{0,40}', unit):
                number = Numeric(value, unit)
        solved = {}
        packet = p.get('evidence', {}).get('checked_computation', {})
        if (isinstance(packet, dict) and packet.get('kind') == 'affine_equation' and
                p.get('request_text') == standalone and
                p.get('evidence', {}).get('consumer_validation', {}).get('status') == 'consistent' and
                validate_reply_evidence(reply).get('status') == 'consistent'):
            variable = packet.get('inputs', {}).get('variable')
            result = packet.get('result', {})
            root = result.get('root')
            value = exact(str(root.get('num')) + '/' + str(root.get('den'))) if isinstance(root, dict) else None
            if result.get('classification') == 'unique' and value is not None and variable in ('x', 'y', 'z'):
                solved[variable] = value
        slot = c.get('slot_surface')
        if not isinstance(slot, str) or not slot or standalone.count(slot) != 1:
            slot = None
        if not any((query, answer, number, solved, native_owner)):
            return None
        return cls(index, query, answer, number, solved, slot, standalone, c.get('property'), native_owner)


@dataclass(frozen=True)
class Turn:
    index: int
    question: str
    standalone: str
    reply: dict


@dataclass(frozen=True)
class Plan:
    question: str | None
    construction: str
    source_turn: int | None
    bound_query_entity: dict | None = None
    refusal: str | None = None


class Ledger:
    """Session-local final events. Evaluation has no method that appends a turn."""
    def __init__(self):
        self.turns = {}
        self.ground = {}

    def append(self, session, question, standalone, reply, recall=False):
        rows = self.turns.setdefault(session, [])
        index = len(rows) + 1
        rows.append(Turn(index, question, standalone, deepcopy(reply)))
        if not recall:
            # A substantive non-answer or ungrounded answer prevents stale reuse.
            self.ground[session] = Ground.from_reply(index, standalone, reply)
        return index

    def recall(self, session, question):
        q = question.strip().rstrip('?.!').lower()
        rows = self.turns.get(session, [])
        factual = False
        named = re.fullmatch(r'what did you (?:last )?say about (.{1,150})', q)
        if named:
            label = named[1].strip().strip('\"\'')
            matching = []
            for turn in rows:
                if outcome(turn.reply) != 'answered':
                    continue
                c = turn.reply.get('provenance', {}).get('conversation', {})
                if not isinstance(c, dict):
                    continue
                entities = [Entity.read(c.get(k)) for k in ('query_entity', 'answer_entity')]
                if any(e and e.label.casefold() == label.casefold() for e in entities):
                    matching.append(turn)
            row, field, factual = (matching[-1] if matching else None), 'response', True
        elif q in ('what was my last question', 'what did i just ask', 'repeat my last question'):
            row, field = (rows[-1] if rows else None), 'question'
        elif q in ('what was my first question', 'what did i ask first'):
            row, field = (rows[0] if rows else None), 'question'
        elif q in ('what did you just say', 'repeat your last answer', 'what was your last answer'):
            row, field = (rows[-1] if rows else None), 'response'
        elif q in ('what was the last fact you told me', 'repeat the last fact', 'what fact did you last tell me'):
            prior = [r for r in rows if outcome(r.reply) == 'answered' and
                     not r.reply.get('provenance', {}).get('dialogue', {}).get('recall')]
            row, field, factual = (prior[-1] if prior else None), 'response', True
        else:
            return None
        if row is None:
            return {'status': 'clarify', 'response': ('There is no earlier accepted answer about that name to quote in this session.' if named
                                                         else 'There is no earlier turn to quote in this session.'),
                    'path': 'dialogue>no_history', 'provenance': {'taken': True, 'dialogue': {'recall': True}}}
        quoted = row.question if field == 'question' else row.reply.get('response', '')
        return {'status': 'answered', 'response': ('You asked: ' if field == 'question' else 'I said: ') + quoted,
                'path': 'dialogue>recall', 'provenance': {'taken': True, 'dialogue': {
                    'recall': True, 'source_turn': row.index, 'quoted_field': field,
                    'source_status': row.reply.get('status'), 'source_path': row.reply.get('path'),
                    'source_provenance': deepcopy({k: v for k, v in row.reply.get('provenance', {}).items() if k != 'dialogue'}),
                    'quoted_text': quoted, 'fact_request': factual,
                    'boundary': 'Literal record of the final reply; recall does not establish that its claims are true.'}}}


class Dialogue:
    def __init__(self, policy, native_owners=()):
        self.policy = policy
        self.ledger = Ledger()
        self.native_owners = frozenset(native_owners)

    def call(self, **fields):
        out = self.policy.ask_payload({'id': 'dialogue-policy', **fields})
        if 'error' in out:
            raise RuntimeError('conversation policy: ' + str(out['error']))
        return out

    def select(self, raw, candidate=None):
        return self.call(op='select', raw=outcome(raw), candidate=None if candidate is None else outcome(candidate))['selection']

    def plan(self, session, text):
        ground = self.ledger.ground.get(session)
        q = text.strip()
        # These item-location/inventory questions are interpreted by the native
        # producer that owns the committed session reference. No QID or item
        # name is guessed, and an unrelated reference still clarifies below.
        native_followup = re.fullmatch(r'(?:where\s+(?:is it|are they)|(?:which|what)\s+bin\s+is\s+it\s+in|'
                                     r'how\s+many\s+(?:are\s+left|do\s+we\s+have)|when\s+will\s+(?:it|we)\s+run\s+out)[?.!]*', q, re.I)
        if ground and ground.native_owner in self.native_owners and native_followup:
            return Plan(q, 'native_warehouse_context', ground.source_turn)
        # A complete finite request is recognized before any replacement occurs.
        variable = re.fullmatch(r'(?:what is|calculate)\s+([xyz])\s+(squared|cubed)[?.!]*', q, re.I)
        cost = re.fullmatch(r'(?:what does|how much does)\s+(that|it)\s+cost\s+(at\s+.+?)[?.!]*', q, re.I)
        convert = re.fullmatch(r'convert\s+(that|it|the result)\s+to\s+([A-Za-z][A-Za-z0-9/^ .-]{0,40})[?.!]*', q, re.I)
        predicates = {
            'capital': 'What is the capital of {}?', 'currency': 'What is the currency of {}?',
            'continent': 'On which continent is {}?', 'official language': 'What is the official language of {}?',
            'birthplace': 'Where was {} born?', 'mother': "Who is {}'s mother?",
            'father': "Who is {}'s father?", 'spouse': "Who is {}'s spouse?",
            'author': 'Who wrote {}?',
        }
        predicate = re.fullmatch(r'(?:and|what about)\s+(?:(its|his|her|the)\s+)?(' + '|'.join(predicates) + r')[?.!]*', q, re.I)
        swap = re.fullmatch(r'(?i:and|what about)\s+(?i:of\s+)?([A-Z][\w -]{0,100})[?.!]*', q)
        pronouns = list(re.finditer(r'\b(that country|that city|that thing|that person|he|she|him|his|her|it|its)\b', q, re.I))
        if variable:
            ref = 'variable'
        elif cost or convert:
            ref = 'number'
        elif predicate:
            ref = ('person' if (predicate[1] or '').lower() in ('his', 'her') or predicate[2].lower() in ('birthplace', 'mother', 'father', 'spouse')
                   else 'thing' if (predicate[1] or '').lower() == 'its' else 'subject')
        elif swap and ground and ground.slot_surface:
            new = swap[1].strip()
            if new.lower() in ('him', 'her', 'it', 'that', 'he', 'she'):
                return None
            ref = 'subject'
        elif len(pronouns) == 1:
            # Explicitly capitalized work title It and quoted names keep their
            # ordinary reading. Lowercase it in a complete follow-up is context.
            if pronouns[0][1].lower() in ('it', 'its') and pronouns[0][1] != pronouns[0][1].lower():
                return None
            # A pronoun in a relative clause is not an unresolved primary slot:
            # "When was the UN renovated after it was founded?" is standalone.
            # Recognize complete finite follow-up shapes rather than searching
            # arbitrary English for a token that could be replaced.
            referent = r"(?:he|she|him|her|it|that person|that thing|that country|that city)"
            possessive = r"(?:his|her|its)"
            prop = r"(?:mother|father|spouse|wife|husband|child|daughter|son|name|birthplace|capital|currency|continent|official language|author|population|height|mass|density)"
            shape = (r"(?:(?:where|when)\s+(?:is|was|are|were)\s+" + referent +
                     r"(?:\s+(?:born|located|founded|established|discovered|built))?|"
                     r"(?:who|what)\s+(?:is|was|are|were)\s+" + possessive + r"\s+" + prop + r"|"
                     r"(?:who|what)\s+(?:wrote|discovered|founded|created|built)\s+" + referent + r"|"
                     r"what\s+(?:is|was)\s+(?:the\s+)?" + prop + r"\s+of\s+" + referent + r"|"
                     r"(?:who|what)\s+(?:is|was)\s+" + referent + r"|"
                     r"(?:what about|and)\s+" + possessive + r"\s+" + prop + r")")
            if not re.fullmatch(shape + r"[?.!]*", q, re.I):
                return None
            token = pronouns[0][1].lower()
            ref = 'answer_thing' if token in ('that country', 'that city', 'that thing') else ('thing' if token in ('it', 'its') else 'person')
        else:
            return None
        if pronouns and pronouns[0][1].lower() in ('that country', 'that city'):
            domain = 'country' if pronouns[0][1].lower() == 'that country' else 'city'
            if not ground or not ground.answer_entity or ground.answer_entity.entity_domain != domain:
                return Plan(None, 'missing_reference_type', ground.source_turn if ground else None,
                            refusal='Please name the ' + domain + ' you mean; the previous answer does not identify one.')
        policy = self.call(op='interpret', complete=True, reference=ref,
            query=None if not ground or not ground.query_entity else ground.query_entity.wire(),
            answer=None if not ground or not ground.answer_entity else ground.answer_entity.wire(),
            number=bool(ground and ground.number),
            variable=bool(ground and variable and variable[1].lower() in ground.solved))
        result = policy['resolution']
        expected = 'clarify' if result in ('missing', 'ambiguous') else 'context'
        if policy.get('interpretation') != expected:
            raise ValueError('conversation policy returned an inconsistent interpretation')
        source = ground.source_turn if ground else None
        if result in ('missing', 'ambiguous'):
            message = ('More than one entity in the previous answer could be the ' + ('person' if ref == 'person' else 'subject') + ' you mean. Please name it.' if result == 'ambiguous'
                       else 'Please name the subject or value you mean; the previous answer does not identify it.')
            return Plan(None, result + '_reference', source, refusal=message)
        if result == 'variable':
            value = ground.solved[variable[1].lower()]
            return Plan('What is (' + value + ')^' + ('2' if variable[2].lower() == 'squared' else '3') + '?', 'solved_variable', source)
        if result == 'number':
            amount = ground.number.exact + ' ' + ground.number.unit
            rewritten = ('What does ' + amount + ' cost ' + cost[2] + '?') if cost else ('Convert ' + amount + ' to ' + convert[2].rstrip(' .') + '.')
            return Plan(rewritten, 'numeric_result', source)
        entity = ground.query_entity if result == 'query' else ground.answer_entity
        if swap and not predicate:
            return Plan(ground.standalone.replace(ground.slot_surface, swap[1].strip(), 1), 'entity_ellipsis', source)
        if predicate:
            rewritten = predicates[predicate[2].lower()].format(entity.label)
        else:
            pronoun = pronouns[0]
            possessive = pronoun[1].lower() in ('his', 'its') or (pronoun[1].lower() == 'her' and
                         re.match(r'\s+(?:mother|father|spouse|birthplace|name|wife|husband|child|daughter|son)\b', q[pronoun.end():], re.I))
            rewritten = q[:pronoun.start()] + entity.label + ("'s" if possessive else '') + q[pronoun.end():]
        return Plan(rewritten, 'predicate_ellipsis' if predicate else ref + '_pronoun', source,
                    {'qid': entity.qid, 'surface': entity.label})
