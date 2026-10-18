"""UNTRUSTED exact numeric spans for the Fusion English reader.

The decimal/fraction grammar and malformed-run boundaries follow
src/extract/commons/numeric.sml (ExactNumeric). Spans here use Python character
offsets, not SML byte offsets. No failed run is retried from an interior suffix.
Fusion additionally accepts a complete ``2 x 10^3`` scientific literal. Tokens
carry exact Fraction values; role readers may only resolve markers issued by
this invocation. This is ordinary Python, not a proved parser.
"""
from dataclasses import dataclass
from fractions import Fraction
import re

MAX_DIGITS = 4096
MAX_EXPONENT = 10000
MARKER = r"qnum[0-9]+q"


@dataclass(frozen=True)
class Number:
    start: int
    stop: int
    value: Fraction


@dataclass(frozen=True)
class Malformed:
    start: int
    stop: int
    reason: str


def _digit(c):
    return '0' <= c <= '9'


def _alpha(c):
    return 'a' <= c <= 'z' or 'A' <= c <= 'Z'


def _decimal(s):
    s = s.replace('−', '-')
    match = re.fullmatch(r'([+-]?)(?:(\d{1,3}(?:,\d{3})+|\d+)(?:\.(\d+))?|\.(\d+))(?:[eE]([+-]?\d+))?', s, re.ASCII)
    if not match:
        raise ValueError('malformed decimal or comma grouping')
    sign, whole, fractional, leading_fractional, exponent = match.groups()
    exp = int(exponent or '0')
    if abs(exp) > MAX_EXPONENT:
        raise ValueError('exponent exceeds resource limit')
    whole = (whole or '0').replace(',', '')
    fractional = fractional or leading_fractional or ''
    numerator = int(whole + fractional) * (-1 if sign == '-' else 1)
    scale = len(fractional) - exp
    return Fraction(numerator, 10 ** scale) if scale >= 0 else Fraction(numerator * 10 ** -scale)


def value(literal):
    if len(literal) > MAX_DIGITS * 2 + 16 or sum(_digit(c) for c in literal) > MAX_DIGITS:
        raise ValueError('digit count exceeds resource limit')
    scientific = re.fullmatch(r'(.+?)\s*[x×]\s*10\^?\s*([+−-]?\d+)', literal, re.ASCII)
    if scientific:
        base, exponent = scientific.groups()
        exp = int(exponent.replace('−', '-'))
        if abs(exp) > MAX_EXPONENT:
            raise ValueError('exponent exceeds resource limit')
        return _decimal(base.rstrip()) * Fraction(10) ** exp
    parts = literal.split('/')
    if len(parts) == 1:
        return _decimal(parts[0])
    if len(parts) != 2:
        raise ValueError('multiple fraction slashes')
    numerator, denominator = (_decimal(p.strip()) for p in parts)
    if denominator == 0:
        raise ValueError('zero denominator')
    return numerator / denominator


def _skip_space(text, i):
    while i < len(text) and text[i].isspace():
        i += 1
    return i


def _numeric_ahead(text, i):
    while i < len(text):
        c = text[i]
        if _digit(c):
            return True
        if c == '.':
            i += 1
        elif c in '+-−':
            i = _skip_space(text, i + 1)
        else:
            return False
    return False


def _run_end(text, start):
    i = start
    while i < len(text):
        c = text[i]
        if c == '/' and _unit_after_slash(text, i):
            break
        if c == '-' and i > start and i + 1 < len(text) and _alpha(text[i + 1]):
            break  # 10-second is a quantity followed by a unit.
        if _digit(c) or c in '.,+-−/_':
            i += 1
        elif c in 'eE' and not (i + 1 < len(text) and _alpha(text[i + 1])):
            i += 1  # eV is a unit; bare e and e+ are malformed exponents.
        else:
            break
    return i


def _unit_after_slash(text, i):
    rhs = _skip_space(text, i + 1)
    return rhs < len(text) and _alpha(text[rhs])


def at(text, start):
    if start >= len(text):
        return None
    if start:
        left = text[start - 1]
        if _alpha(left) or _digit(left) or left in '_.,+-/~)]}^' or ord(left) >= 128:
            return None
    if not _numeric_ahead(text, start):
        return None
    signed = text[start] in '+-−'
    first = _skip_space(text, start + 1) if signed else start
    spaced_sign = signed and first != start + 1
    stop = _run_end(text, first if spaced_sign else start)
    while True:
        slash = _skip_space(text, stop)
        if stop > start and text[stop - 1] == '/' and slash > stop:
            end = _run_end(text, slash)
            if end <= slash:
                break
            stop = end
            continue
        if slash >= len(text) or text[slash] != '/':
            break
        if _unit_after_slash(text, slash):
            break
        rhs = _skip_space(text, slash + 1)
        end = _run_end(text, rhs)
        stop = end if end > rhs else rhs
        if end <= rhs:
            break
    # Preserve the legacy scientific form as one typed span. Its exponent is
    # validated as an integer, never captured as a numeric prefix.
    power = re.match(r'\s*[x×]\s*10\^?\s*', text[stop:])
    if power:
        stop = _run_end(text, stop + power.end())
    raw_stop = stop
    if stop > start and text[stop - 1] in '.,':
        stop -= 1
    try:
        if spaced_sign:
            raise ValueError('space after sign')
        return Number(start, stop, value(text[start:stop]))
    except (ValueError, ZeroDivisionError) as error:
        return Malformed(start, raw_stop, str(error))


def scan(text):
    tokens = []
    i = 0
    while i < len(text):
        token = at(text, i)
        if token is None:
            i += 1
        else:
            tokens.append(token)
            i = token.stop
    return tokens


def parse(text):
    token = at(text, 0)
    return token.value if isinstance(token, Number) and token.stop == len(text) else None


def mask(text):
    """Return masked text, issued marker->(literal,value), and malformed spans."""
    tokens = scan(text)
    errors = [t for t in tokens if isinstance(t, Malformed)]
    if errors:
        return text, {}, errors
    parts, numbers, pos, index = [], {}, 0, 0
    folded = text.lower()
    for token in tokens:
        while 'qnum%dq' % index in folded:
            index += 1
        marker = 'qnum%dq' % index
        index += 1
        parts.extend((text[pos:token.start], marker))
        numbers[marker] = (text[token.start:token.stop], token.value)
        pos = token.stop
    return ''.join(parts) + text[pos:], numbers, []
