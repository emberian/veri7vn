"""UNTRUSTED recognition of an inverse question's requested subject kind.

The HOL Relation_Request interpreter checks these constraints against supplied
class/occupation closures and exact property rows. The recognizer and Wikidata
identifiers are not proved. Labels below were checked against this checkout's
immutable relation store; gender is never guessed from a name or occupation.
"""
import re


def instance(*roots):
    return ["instance", list(roots)]


def occupation(*roots):
    return ["occupation", list(roots)]


def both(left, right):
    return ["both", left, right]


HUMAN = instance(5)
MALE = ["value", 21, ["e", 6581097]]
FEMALE = ["value", 21, ["e", 6581072]]
KINDS = {
    "person": HUMAN,
    "actor": occupation(33999),
    "actress": both(occupation(33999), FEMALE),
    "singer": occupation(177220),
    "writer": occupation(36180),
    "politician": occupation(82955),
    "man": both(HUMAN, MALE),
    "woman": both(HUMAN, FEMALE),
    "king": occupation(12097),
    "queen": occupation(16511993),
    "country": instance(6256, 3624078),
    "nation": instance(6256, 3624078),
    "island": instance(23442),
}


def recognize(prop, frame):
    """frame has the exact matched slot replaced by {target}, so names cannot
    accidentally supply a requested noun. Unknown supported-reader frames fail
    closed; callers use this only for actual inverse regex matches.
    """
    noun = None
    if prop == 26:
        if frame in ("who is married to {target}", "who was married to {target}"):
            return HUMAN
        match = re.fullmatch(r"which ([a-z]+) (?:is|was) married to \{target\}", frame)
        noun = match.group(1) if match else None
    elif prop == 36:
        patterns = (
            r"\{target\} is the capital (?:city )?of (?:which|what) ([a-z]+)",
            r"(?:which|what) ([a-z]+)'s capital is \{target\}",
            r"of (?:which|what) ([a-z]+) is \{target\} the capital",
        )
        for pattern in patterns:
            match = re.fullmatch(pattern, frame)
            if match:
                noun = match.group(1)
                break
    elif prop == 38:
        if re.fullmatch(r"(?:which|what) country(?:'s)? (?:currency is|uses) (?:the )?\{target\}", frame) or \
                re.fullmatch(r"(?:the )?\{target\} is the currency of (?:which|what) country", frame):
            noun = "country"
    return KINDS.get(noun, ["unknown"])


def property_ids(constraint):
    if constraint[0] == "value":
        return {constraint[1]}
    if constraint[0] == "both":
        return property_ids(constraint[1]) | property_ids(constraint[2])
    return set()
