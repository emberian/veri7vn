"""Shared runtime declarations, not a proof checker.

UNTRUSTED glue: validate explicit executable ownership and combine a shipped
manifest's acceptance rule with reviewed family extensions. Neither this file
nor an evidence declaration certifies a particular answer or its recognition.
"""
from __future__ import annotations

import copy
import importlib.util
import json
import re
from functools import lru_cache
from fractions import Fraction
from pathlib import Path


ROLES = {"specialist", "network", "guard", "word_problem", "math", "document", "relation", "dialogue", "code"}
NAME = re.compile(r"[a-z][a-z0-9_-]*\Z")


class ContractError(ValueError):
    """A runtime declaration is malformed or exceeds its family's ownership."""


def _object(value, allowed, where):
    if not isinstance(value, dict):
        raise ContractError(f"{where}: expected an object")
    extra = value.keys() - allowed
    if extra:
        raise ContractError(f"{where}: unknown fields {sorted(extra)}")


def _strings(value, where):
    if not isinstance(value, list) or any(not isinstance(x, str) or not x for x in value):
        raise ContractError(f"{where}: expected nonempty strings in a list")
    if len(set(value)) != len(value):
        raise ContractError(f"{where}: duplicate values")
    return value


def _read(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise ContractError(f"{path}: {exc}") from exc


def load_registry(repo):
    """Return validated entries; only role=specialist belongs in family fan-out."""
    data = _read(Path(repo) / "src/extract/families.json")
    _object(data, {"schema_version", "comment", "families"}, "registry")
    if type(data.get("schema_version")) is not int or data["schema_version"] != 1:
        raise ContractError("registry: expected schema_version 1")
    entries = data.get("families")
    if not isinstance(entries, list):
        raise ContractError("registry: families must be a list")
    families, specialists = set(), set()
    allowed = {"family", "role", "session", "binary", "specialists", "specialist_flag",
               "build", "note", "kind", "state_flag", "preview_flag"}
    for entry in entries:
        _object(entry, allowed, "registry entry")
        family = entry.get("family")
        if not isinstance(family, str) or not NAME.fullmatch(family) or family in families:
            raise ContractError(f"registry: invalid or duplicate family {family!r}")
        families.add(family)
        if entry.get("role") not in ROLES:
            raise ContractError(f"{family}: explicit recognized role required")
        ids = _strings(entry.get("specialists"), f"{family}.specialists")
        if (entry["role"] == "specialist") != bool(ids):
            raise ContractError(f"{family}: only specialist entries own specialist IDs")
        for sid in ids:
            if not NAME.fullmatch(sid) or sid in specialists:
                raise ContractError(f"{family}: invalid or multiply owned specialist {sid!r}")
            specialists.add(sid)
        for field in ("binary", "build"):
            value = entry.get(field)
            if not isinstance(value, str) or not value or Path(value).is_absolute() or ".." in Path(value).parts:
                raise ContractError(f"{family}.{field}: expected a relative repository path")
        for field in ("specialist_flag", "state_flag", "preview_flag"):
            if field in entry and type(entry[field]) is not bool:
                raise ContractError(f"{family}.{field}: expected boolean")
        if entry.get("preview_flag") and not entry.get("state_flag"):
            raise ContractError(f"{family}: preview_flag requires state_flag")
    return entries


def _family_capabilities(repo, entry):
    path = Path(repo) / "src/extract" / entry["family"] / "capabilities.json"
    if not path.exists():
        return {}
    data = _read(path)
    _object(data, {"schema_version", "family", "specialists"}, str(path))
    if type(data.get("schema_version")) is not int or data["schema_version"] != 1:
        raise ContractError(f"{path}: expected schema_version 1")
    if data.get("family") != entry["family"]:
        raise ContractError(f"{path}: family must match its directory")
    specs = data.get("specialists")
    if not isinstance(specs, dict):
        raise ContractError(f"{path}: specialists must be an object")
    for sid, cap in specs.items():
        if sid not in entry["specialists"]:
            raise ContractError(f"{path}: specialist {sid!r} is not owned by this family")
        where = f"{path}:{sid}"
        _object(cap, {"accept", "context_regex_additions", "evidence"}, where)
        acc = cap.get("accept", {})
        _object(acc, {"kinds", "declines_in_domain"}, where + ".accept")
        for key, values in acc.items():
            _strings(values, where + ".accept." + key)
        for pattern in _strings(cap.get("context_regex_additions", []), where + ".context_regex_additions"):
            try:
                re.compile(pattern, re.I)
            except re.error as exc:
                raise ContractError(f"{where}: invalid context pattern: {exc}") from exc
        evidence = cap.get("evidence", {})
        _object(evidence, {"computation", "assumptions", "untrusted"}, where + ".evidence")
        if "computation" in evidence and (not isinstance(evidence["computation"], str) or not evidence["computation"]):
            raise ContractError(f"{where}: computation must be a nonempty string")
        for key in ("assumptions", "untrusted"):
            if key in evidence:
                _strings(evidence[key], where + ".evidence." + key)
    return specs


def capability_for(repo, sid):
    """Return a validated specialist declaration (possibly empty), never evidence of execution."""
    for entry in load_registry(repo):
        if sid in entry["specialists"]:
            return copy.deepcopy(_family_capabilities(repo, entry).get(sid, {}))
    raise ContractError(f"unknown specialist {sid!r}")


# These five shipped JSON manifests encoded intended regex word boundaries as
# literal backspace characters. Repair only the inspected original patterns;
# valid escapes and changed upstream patterns are never normalized globally.
_BROKEN_CONTEXTS = {
    "decay": "\b(?:half[- ]?li(?:fe|ves)|decay\\w*|radioactive|isotope)\b",
    "fluids-r2": "\b(?:pressure|buoyan\\w*|upthrust|submerged|floats?)\b",
    "springs": "\b(?:springs?|hooke|spring constant)\b",
    "fluids": "\b(?:pressure|buoyan\\w*|upthrust|submerged|floats?)\b",
    "fuels": "\b(?:coal|lignite|anthracite|charcoal|wood|lpg|propane|natural gas|kerosene|jet fuel|petrol|gasoline|diesel)\b",
}


def acceptance(repo, upstream, sid):
    """Original accept object plus explicit kinds, declines, and context alternatives.

    Existing fields are preserved except five exact shipped backspace-boundary
    defects documented above. Context additions are regex alternatives, not
    replacements; families cannot silently loosen another specialist.
    """
    cap = capability_for(repo, sid)
    manifest = _read(Path(upstream) / "root/specialists" / sid / "manifest.json")
    acc = copy.deepcopy(manifest.get("accept") or {})
    if not isinstance(acc, dict):
        raise ContractError(f"{sid}: shipped accept must be an object")
    for key, additions in cap.get("accept", {}).items():
        original = _strings(acc.get(key, []), f"{sid}.accept.{key}")
        acc[key] = list(dict.fromkeys(original + additions))
    if sid in _BROKEN_CONTEXTS and acc.get("context_regex") == _BROKEN_CONTEXTS[sid]:
        acc["context_regex"] = acc["context_regex"].replace("\b", r"\b")
    patterns = cap.get("context_regex_additions", [])
    if patterns:
        original = acc.get("context_regex")
        parts = ([original] if original else []) + patterns
        acc["context_regex"] = "|".join(f"(?:{pattern})" for pattern in parts)
        try:
            re.compile(acc["context_regex"], re.I)
        except re.error as exc:
            raise ContractError(f"{sid}: combined context regex is invalid: {exc}") from exc
    return acc


def validate_capabilities(repo):
    """Validate every declared family, including declarations unused by this process."""
    entries = load_registry(repo)
    for entry in entries:
        _family_capabilities(repo, entry)
    return entries


def _evidence_rational(value):
    _object(value, {"num", "den"}, "rational")
    for key in ("num", "den"):
        text = value.get(key)
        if not isinstance(text, str) or len(text) > 256 or not re.fullmatch(r"-?[0-9]+", text):
            raise ContractError("rational components must be bounded decimal integer strings")
    if int(value["den"]) <= 0:
        raise ContractError("rational denominator must be positive")
    return Fraction(int(value["num"]), int(value["den"]))


def _validate_affine_evidence(reply, packet):
    """UNTRUSTED replay of a finite typed AST, not of the user's English."""
    if packet.get("checker") != "Mathkernel.check_affine" or packet.get("accepted") is not True:
        raise ContractError("affine kernel checker did not accept the computation")
    if reply.get("status") != "answered" or reply.get("kind") != "affine_equation":
        raise ContractError("affine packet is attached to a different decision")
    inputs = packet.get("inputs")
    _object(inputs, {"variable", "left", "right"}, "affine inputs")
    if inputs.get("variable") != "x":
        raise ContractError("unsupported affine variable")
    remaining = 128

    def bounded(pair):
        if any(max(abs(v.numerator).bit_length(), v.denominator.bit_length()) > 131072 for v in pair):
            raise ContractError("affine arithmetic exceeds the supported range")
        return pair

    def normalize(node, depth=0):
        nonlocal remaining
        remaining -= 1
        if remaining < 0 or depth > 32:
            raise ContractError("affine AST exceeds the node or depth limit")
        if not isinstance(node, dict):
            raise ContractError("affine AST node must be an object")
        op = node.get("op")
        if op == "const":
            _object(node, {"op", "value"}, "constant AST node")
            return Fraction(0), _evidence_rational(node.get("value"))
        if op == "var":
            _object(node, {"op", "name"}, "variable AST node")
            if node.get("name") != "x":
                raise ContractError("unsupported variable in affine AST")
            return Fraction(1), Fraction(0)
        if op == "neg":
            _object(node, {"op", "arg"}, "negation AST node")
            a, b = normalize(node.get("arg"), depth + 1)
            return -a, -b
        if op not in {"add", "sub", "mul", "div"}:
            raise ContractError("unsupported affine AST operation")
        _object(node, {"op", "left", "right"}, "binary AST node")
        a, b = normalize(node.get("left"), depth + 1)
        c, d = normalize(node.get("right"), depth + 1)
        if op == "add":
            return bounded((a + c, b + d))
        if op == "sub":
            return bounded((a - c, b - d))
        if op == "mul":
            if a and c:
                raise ContractError("nonlinear product in affine AST")
            return bounded((a * d + b * c, b * d))
        if c or not d:
            raise ContractError("affine divisor must normalize to a nonzero constant")
        return bounded((a / d, b / d))

    left, right = normalize(inputs.get("left")), normalize(inputs.get("right"))
    result = packet.get("result")
    _object(result, {"classification", "left_affine", "right_affine", "root"}, "affine result")
    for key, expected in (("left_affine", left), ("right_affine", right)):
        row = result.get(key)
        _object(row, {"coefficient", "constant"}, "normalized affine side")
        if (_evidence_rational(row.get("coefficient")), _evidence_rational(row.get("constant"))) != expected:
            raise ContractError("normalized coefficients disagree with the typed AST")
    a, b = left
    c, d = right
    classification = "unique" if a != c else "all" if b == d else "none"
    if result.get("classification") != classification or "root" not in result:
        raise ContractError("affine solution classification disagrees with the typed equation")
    if classification == "unique":
        root = _evidence_rational(result["root"])
        if a * root + b != c * root + d:
            raise ContractError("affine root does not satisfy the typed equation")
        value = str(root.numerator) if root.denominator == 1 else f"{root.numerator}/{root.denominator}"
        if reply.get("value") != value or reply.get("response") != f"[ev:derived] x = {value}.":
            raise ContractError("affine displayed solution disagrees with the checked root")
        explanation = f"Both typed sides normalize to affine expressions; substituting x = {value} makes them equal, and their different coefficients give one solution."
    else:
        if result["root"] is not None or "value" in reply:
            raise ContractError("nonunique affine result must not assert one numeric root")
        expected = ("Every rational value of x satisfies this equation." if classification == "all"
                    else "No rational value of x satisfies this equation.")
        if reply.get("response") != "[ev:derived] " + expected:
            raise ContractError("affine displayed classification disagrees with the checked equation")
        explanation = ("The typed sides have equal coefficients and constants." if classification == "all"
                       else "The typed sides have equal coefficients but different constants.")
    _strings(packet.get("assumptions", []), "computation assumptions")
    return {"status": "consistent", "checker": "python_exact_affine_v1",
            "checks": ["typed_AST_domain", "affine_normalization", "solution_classification", "displayed_result_matches"],
            "explanation": explanation,
            "boundary": "Checks the supplied typed equation over rational numbers, not whether it matches the user's request. This Python replay is not formally verified."}


def _validate_closed_evidence(reply, packet):
    """UNTRUSTED bounded exact replay, never evaluation of Python source."""
    if packet.get('checker') != 'Mathkernel.check_closed' or packet.get('accepted') is not True:
        raise ContractError('closed-expression kernel checker did not accept')
    if reply.get('status') != 'answered' or reply.get('kind') != 'closed_expression':
        raise ContractError('closed-expression packet is attached to a different decision')
    inputs = packet.get('inputs')
    _object(inputs, {'expression'}, 'closed-expression inputs')
    remaining = 128

    def inspect(node, depth=0):
        nonlocal remaining
        remaining -= 1
        if remaining < 0 or depth > 32:
            raise ContractError('closed-expression AST exceeds the node or depth limit')
        if not isinstance(node, dict):
            raise ContractError('closed-expression AST node must be an object')
        op = node.get('op')
        if op == 'const':
            _object(node, {'op', 'value'}, 'constant AST node')
            q = _evidence_rational(node.get('value'))
            # Conservative decimal-to-bit bound; inspect the original components
            # so cancellation cannot hide an expensive intermediate operation.
            cost = 4 * max(len(node['value']['num'].lstrip('-')), len(node['value']['den']))
            return ('const', q), cost
        if op == 'neg':
            _object(node, {'op', 'arg'}, 'negation AST node')
            child, cost = inspect(node.get('arg'), depth + 1)
            return ('neg', child), cost
        if op == 'pow':
            _object(node, {'op', 'base', 'exponent'}, 'power AST node')
            power = node.get('exponent')
            if type(power) is not int or power not in (2, 3):
                raise ContractError('only square and cube powers are supported')
            child, cost = inspect(node.get('base'), depth + 1)
            cost *= power
            if cost > 8192:
                raise ContractError('closed-expression arithmetic exceeds the work limit')
            return ('pow', child, power), cost
        if op not in {'add', 'sub', 'mul', 'div'}:
            raise ContractError('unsupported closed-expression AST operation')
        _object(node, {'op', 'left', 'right'}, 'binary AST node')
        left, lc = inspect(node.get('left'), depth + 1)
        right, rc = inspect(node.get('right'), depth + 1)
        cost = lc + rc + (1 if op in {'add', 'sub'} else 0)
        if cost > 8192:
            raise ContractError('closed-expression arithmetic exceeds the work limit')
        return (op, left, right), cost

    def compute(tree):
        op = tree[0]
        if op == 'const':
            return tree[1]
        left = compute(tree[1])
        if op == 'neg':
            return -left
        if op == 'pow':
            return left ** tree[2]
        right = compute(tree[2])
        if op == 'add': return left + right
        if op == 'sub': return left - right
        if op == 'mul': return left * right
        if not right:
            raise ContractError('closed-expression division by zero')
        return left / right

    tree, _ = inspect(inputs.get('expression'))
    result = _evidence_rational(packet.get('result'))
    if compute(tree) != result:
        raise ContractError('closed-expression result disagrees with the typed AST')
    value = str(result.numerator) if result.denominator == 1 else f'{result.numerator}/{result.denominator}'
    if reply.get('value') != value or reply.get('response') != f'[ev:derived] {value}.':
        raise ContractError('closed-expression displayed value disagrees with the checked result')
    _strings(packet.get('assumptions', []), 'computation assumptions')
    return {'status': 'consistent', 'checker': 'python_exact_closed_expression_v1',
            'checks': ['closed_typed_AST', 'bounded_exact_arithmetic', 'displayed_result_matches'],
            'explanation': f'The supplied closed rational expression evaluates exactly to {value}.',
            'boundary': "Checks the supplied expression, not whether English recognition or conversation substitution selected the intended expression. This Python replay is not formally verified."}


@lru_cache(maxsize=1)
def _code_checker():
    """Load this consumer's explicit sibling, including in relocated packages."""
    path = Path(__file__).with_name("code_evidence.py")
    try:
        spec = importlib.util.spec_from_file_location("_veri7vn_code_evidence", path)
        if spec is None or spec.loader is None:
            raise ContractError("code evidence consumer is unavailable")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.validate_code
    except (OSError, ImportError) as exc:
        raise ContractError("code evidence consumer is unavailable") from exc


def validate_reply_evidence(reply):
    """Independently recheck the supported arithmetic packet and final amount.

    This Python checker is UNTRUSTED corroboration, not a proof verifier. It
    checks the supplied typed input, not whether that input matches English.
    A producer's ``accepted`` flag is required but never accepted on its own.
    """
    boundary = "Checks typed arithmetic and the final stated amount; natural-language recognition, source meaning, and the remaining response text are not checked. This Python checker is not formally verified."
    try:
        if not isinstance(reply, dict):
            raise ContractError("answerer reply must be an object")
        provenance = reply.get("provenance", {})
        if not isinstance(provenance, dict):
            raise ContractError("present provenance must be an object")
        evidence = provenance.get("evidence", {})
        if not isinstance(evidence, dict):
            raise ContractError("present evidence must be an object")
        if "checked_computation" not in evidence:
            if reply.get("kind") in {"affine_equation", "code_program", "closed_expression"}:
                raise ContractError("this reply kind requires a checked computation packet")
            return {"status": "not_present"}
        packet = evidence["checked_computation"]
        if isinstance(packet, dict) and packet.get("kind") == "code_program":
            return _code_checker()(reply, packet)
        _object(packet, {"schema_version", "kind", "inputs", "result", "checker", "accepted", "assumptions"}, "computation packet")
        if type(packet.get("schema_version")) is not int or packet["schema_version"] != 1:
            raise ContractError("unsupported computation packet version")
        if packet.get("kind") == "affine_equation":
            return _validate_affine_evidence(reply, packet)
        if packet.get("kind") == "closed_expression":
            return _validate_closed_evidence(reply, packet)
        if packet.get("kind") != "discount_tax" or packet.get("checker") != "Finance.check_discount_tax":
            raise ContractError("unsupported computation checker")
        if packet.get("accepted") is not True:
            raise ContractError("kernel checker did not accept the computation")
        if reply.get("status") != "answered" or reply.get("kind") != "discount_tax":
            raise ContractError("computation packet is attached to a different decision")
        inputs = packet.get("inputs")
        _object(inputs, {"price", "discounts_percent", "tax_rate"}, "computation inputs")

        price, rate = _evidence_rational(inputs.get("price")), _evidence_rational(inputs.get("tax_rate"))
        discounts = inputs.get("discounts_percent")
        if not isinstance(discounts, list) or not 1 <= len(discounts) <= 64:
            raise ContractError("expected one to 64 discounts")
        discounts = [_evidence_rational(discount) for discount in discounts]
        if price < 0 or rate < 0 or any(discount < 0 or discount > 100 for discount in discounts):
            raise ContractError("inputs are outside the ordinary discount and sales-tax domain")
        expected = price
        for discount in discounts:
            expected *= 1 - discount / 100
        expected *= 1 + rate
        result = _evidence_rational(packet.get("result"))
        if result != expected:
            raise ContractError("exact result disagrees with discount-then-tax arithmetic")
        cents = (result * 100 + Fraction(1, 2)).__floor__()
        rounded = Fraction(cents, 100)
        value = reply.get("value")
        if isinstance(value, bool) or not isinstance(value, (str, int, float)) or len(str(value)) > 256:
            raise ContractError("final numeric value is missing or malformed")
        # Fraction accepts arbitrarily large scientific exponents in strings.
        # Bound the representation before constructing its integer arithmetic.
        numeric = re.fullmatch(r"-?(?:[0-9]+(?:\.[0-9]+)?)(?:[eE]([+-]?[0-9]{1,3}))?", str(value))
        if not numeric or (numeric[1] is not None and abs(int(numeric[1])) > 309):
            raise ContractError("final numeric value must be a bounded decimal")
        if Fraction(str(value)) != rounded:
            raise ContractError("final numeric value disagrees with cents rounding")
        match = re.match(r"The final price is \$((?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)\.[0-9]{2})(?=\s|\(|\.(?:\s|$)|$)", str(reply.get("response", "")))
        if not match or Fraction(match[1].replace(",", "")) != rounded:
            raise ContractError("final response amount disagrees with the checked result")
        _strings(packet.get("assumptions", []), "computation assumptions")
        shown = f"{cents // 100}.{cents % 100:02d}"
        return {"status": "consistent", "checker": "python_exact_discount_tax_v1",
                "checks": ["input_domain", "exact_discount_then_tax", "cents_rounding", "final_amount_matches"],
                "explanation": f"Applied each listed discount to the price, then applied the stated tax rate; the exact result rounds to ${shown}.",
                "boundary": boundary}
    except (ContractError, ValueError, TypeError, OverflowError) as exc:
        return {"status": "rejected", "reason": str(exc), "boundary": boundary}


def enforce_reply_evidence(reply):
    """Retain producer evidence; refuse an answer whose asserted packet fails."""
    observation = validate_reply_evidence(reply)
    if observation["status"] == "not_present":
        return reply
    result = copy.deepcopy(reply) if isinstance(reply, dict) else {"invalid_producer_reply": copy.deepcopy(reply)}
    provenance = result.get("provenance", {})
    if not isinstance(provenance, dict):
        provenance = {"invalid_producer_provenance": provenance}
    result["provenance"] = provenance
    evidence = provenance.get("evidence", {})
    if not isinstance(evidence, dict):
        evidence = {"invalid_producer_evidence": evidence}
    provenance["evidence"] = evidence
    evidence["consumer_validation"] = observation
    if observation["status"] == "rejected":
        result.update(status="withheld", response="",
                      path=str(result.get("path", "")) + ">evidence_rejected")
        result.pop("value", None)
        provenance["taken"] = True
    return result
