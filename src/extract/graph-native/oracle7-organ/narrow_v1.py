#!/usr/bin/env python3
"""narrow_v1 - the shared NARROWING rule for specialist organs (2026-09-29, from the full-core sweep):

  WORD PROBLEMS AND NARRATIVE TURNS BELONG TO THE HEAD. An organ answers a direct domain question. A turn that tells a
  story ("Justine wants to put a deck ...", "A new energy drink advertises 106 calories for 8 ounces ...") or relates
  quantities to each other ("the length is 9 inches more than the width") is a word problem, which the core's word-
  problem organ owns; organs firing on its nouns declined it or answered a different question.
  An organ may DECLINE only a short direct question (it is then refusing the domain question that was asked); on
  anything longer it says nothing and the head answers.

Narrowing only ever removes turns an organ takes, so on any input where it does not fire, the organ's reply is
byte-identical to the frozen version it wraps (checked per specialist by an invariance count before re-gating).
"""
import re

RELATION = re.compile(r"\b(?:\d+(?:\.\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\s+(?:\w+\s+){0,2}(?:more|less|fewer|longer|shorter)\s+than\b|"
                      r"\b(?:twice|three times|half)\s+(?:as\s+\w+\s+as\s+)?the\s+\w+\b", re.I)


# a RATE ("106 calories for 8 ounces", "3 apples per 2 dollars") makes the turn a proportion problem
RATE = re.compile(r"\b\d+(?:\.\d+)?\s+[a-z]+\s+(?:for|per|every)\s+(?:\d+(?:\.\d+)?|a|an|one|each)\s+[a-z]+", re.I)
NUM = re.compile(r"(?<![\w.])\d+(?:\.\d+)?(?!\w|\.\d)")     # "leg is 5." counts: a sentence-final period is not a decimal


def numbers(t):
    return len(NUM.findall(str(t or "")))


def last_sentence(t):
    parts = [s for s in re.split(r"(?<=[.!?;])\s+", str(t or "").strip()) if s.strip()]
    return parts[-1] if parts else ""


def sentences(t):
    return len([s for s in re.split(r"(?<=[.!?])\s+", str(t or "").strip()) if s.strip()])


def narrative(t):
    """a story-shaped or relational turn: 3+ sentences, 40+ words, or quantities defined relative to each other"""
    t = str(t or "")
    return sentences(t) >= 3 or len(t.split()) > 40 or RELATION.search(t) is not None or RATE.search(t) is not None


def short_direct(t):
    """a direct question an organ may decline: at most 2 sentences, at most 25 words, not narrative"""
    t = str(t or "")
    return sentences(t) <= 2 and len(t.split()) <= 25 and not narrative(t)
