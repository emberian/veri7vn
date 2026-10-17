#!/usr/bin/env python3
"""veri7vn fusion answerer (docs/contracts/answerer.md): JSON lines in, JSON lines out.

UNTRUSTED. This file reads English into typed givens, a typed goal and context facts, asks the
verified planner (var/fusion/bin/fusion, the MLton build of Fusion.qdecide) for a decision, and
renders the decision as Oracle7's network replies read. The reading is a port of
upstream/root/specialists/_gate/network_v2.py (read_givens, read_goal, normalise, the units table)
and network_v3.py (its added units and goals, read_flags_v3, attached, depth_attached), with one
change: amounts are exact fractions (Oracle7 uses floats). Nothing here decides an answer: which
plan, whether plans agree, whether a given is valid, single-conversion and echo rules, and every
node value are the binary's. What this file can get wrong is the reading of the question
(units, roles, which material an amount belongs to) and the layout of the reply text.

  answerer.py [--binary PATH] [--agree pairwise|anchor]
"""
from __future__ import annotations

import argparse
import itertools
import json
import os
import re
import subprocess
import sys
import time
from fractions import Fraction as Fr
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
BINARY = REPO / "var" / "fusion" / "bin" / "fusion"

# ---------------------------------------------------------------- dimensions & units (network_v2: SI base m kg s A K $)
BASE = ("m", "kg", "s", "A", "K", "$")


def D(**e):
    return tuple(e.get(b, 0) for b in BASE)


def dmul(a, b, k=1):
    return tuple(x + k * y for x, y in zip(a, b))


DIMLESS = D()
LEN, MASS, TIME, AREA, VOL = D(m=1), D(kg=1), D(s=1), D(m=2), D(m=3)
VEL, ACC, FREQ = D(m=1, s=-1), D(m=1, s=-2), D(s=-1)
ENERGY, POWER = D(kg=1, m=2, s=-2), D(kg=1, m=2, s=-3)
VOLT, CURR, CHARGE, MONEY = D(kg=1, m=2, s=-3, A=-1), D(A=1), D(A=1, s=1), D(**{"$": 1})
TEMP, INV_TEMP, FLOW = D(K=1), D(K=-1), D(m=3, s=-1)
PRESSURE, FORCE, STIFF = D(kg=1, m=-1, s=-2), D(kg=1, m=1, s=-2), D(kg=1, s=-2)

UNITS = {}


def _u(names, factor, dim):
    for n in names.split("|"):
        UNITS[n] = (Fr(factor), dim)


GAL = Fr("3.785411784e-3")
FT = Fr("0.3048")
_u("w|watt|watts", 1, POWER)
_u("kw|kilowatt|kilowatts", 1000, POWER)
_u("hp|horsepower", Fr("745.69987"), POWER)
_u("v|volt|volts", 1, VOLT)
_u("a|amp|amps|ampere|amperes", 1, CURR)
_u("ah|amp-hour|amp-hours", 3600, CHARGE)
_u("s|sec|secs|second|seconds", 1, TIME)
_u("min|mins|minute|minutes", 60, TIME)
_u("h|hr|hrs|hour|hours", 3600, TIME)
_u("day|days", 86400, TIME)
_u("week|weeks", 7 * 86400, TIME)
_u("year|years", 365 * 86400, TIME)
_u("kwh|kilowatt-hour|kilowatt-hours", 3600000, ENERGY)
_u("wh|watt-hour|watt-hours", 3600, ENERGY)
_u("j|joule|joules", 1, ENERGY)
_u("kj|kilojoule|kilojoules", 1000, ENERGY)
_u("mph", Fr("0.44704"), VEL)
_u("m/s", 1, VEL)
_u("km/h|kph", 1 / Fr("3.6"), VEL)
_u("m/s^2|m/s2|m/s²|metres per second squared|meters per second squared", 1, ACC)
_u("m|metre|metres|meter|meters", 1, LEN)
_u("km|kilometre|kilometres|kilometer|kilometers", 1000, LEN)
_u("cm|centimetre|centimetres|centimeter|centimeters", Fr("0.01"), LEN)
_u("mm|millimetre|millimetres|millimeter|millimeters", Fr("0.001"), LEN)
_u("in|inch|inches", Fr("0.0254"), LEN)
_u("ft|foot|feet", FT, LEN)
_u("mile|miles", Fr("1609.344"), LEN)
_u("m2|m^2|m²|square metre|square metres|square meter|square meters", 1, AREA)
_u("sq ft|square foot|square feet|ft2", Fr("0.09290304"), AREA)
_u("m3|m^3|m³|cubic metre|cubic metres", 1, VOL)
_u("l|litre|litres|liter|liters", Fr("1e-3"), VOL)
_u("ml|millilitre|millilitres|milliliter|milliliters", Fr("1e-6"), VOL)
_u("gallon|gallons|us gallon|us gallons|gal", GAL, VOL)
_u("cfm", FT ** 3 / 60, FLOW)
_u("kg|kilogram|kilograms", 1, MASS)
_u("n|newton|newtons", 1, D(kg=1, m=1, s=-2))
_u("mpg|miles per gallon", Fr("1609.344") / GAL, D(m=-2))
_u("g|gram|grams", Fr("1e-3"), MASS)
_u("lb|lbs|pound|pounds", Fr("0.45359237"), MASS)
_u("tonne|tonnes", 1000, MASS)
_u("hz|hertz", 1, FREQ)
_u("khz", 1000, FREQ)
_u("thz", 10 ** 12, FREQ)
_u("dollar|dollars", 1, MONEY)
_u("cent|cents", Fr("0.01"), MONEY)

NUMW = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "twice": 2, "double": 2, "triple": 3, "half": Fr(1, 2)}
NUM = r"-?\d[\d,]*(?:\.\d+)?(?:\s*(?:x|×)\s*10\^?\s*-?\d+)?"


def fnum(s):
    """network_v2.fnum, exact"""
    s = s.replace(",", "").replace("×", "x")
    m = re.match(r"(-?[\d.]+)\s*x\s*10\^?\s*(-?\d+)", s)
    return Fr(m.group(1)) * Fr(10) ** int(m.group(2)) if m else Fr(s)


def unit_lookup(u):
    u = u.lower().strip().rstrip(".")
    u = re.sub(r"\s+", " ", u)
    return UNITS.get(u)


class Q:
    def __init__(self, v, dim, text="", role="", temp_point=False):
        self.v, self.dim, self.text, self.role, self.temp_point = Fr(v), dim, text, role, temp_point


# regexes compiled at network_v2's import time use v2's unit alternation; network_v3 recompiles RX_QTY and RX_GOAL_UNIT
UNIT_ALT_V2 = "|".join(sorted((re.escape(k) for k in UNITS), key=len, reverse=True))
RX_RANGE = re.compile(r"\bfrom\s+(%s)\s*(%s)?\s+(?:up\s+)?to\s+(%s)\s*(%s)(?![a-z])" % (NUM, UNIT_ALT_V2, NUM, UNIT_ALT_V2), re.I)
RX_MONEY = re.compile(r"\$\s*(%s)" % NUM)
RX_PRICE = re.compile(r"(?:\$\s*(%s)|(%s)\s*cents?)\s*(?:per|a|/)\s*(kwh|kilowatt-hour|wh)" % (NUM, NUM), re.I)
RX_TEMP = re.compile(r"(-?\d+(?:\.\d+)?)\s*(?:°\s*|degrees?\s+)?(c|f|celsius|fahrenheit)\b", re.I)
RX_PER_DAY = re.compile(r"(%s)\s*(hours?|minutes?|hrs?|mins?)\s+(?:a|per|each|every)\s+(day|week)" % NUM, re.I)
RX_DAYS_PER_WEEK = re.compile(r"(%s)\s*days?\s+(?:a|per|each)\s+week" % NUM, re.I)
RX_DAYS_SPAN = re.compile(r"(?:for\s+|a\s+|over\s+)?(%s)[- ]days?(?:\s+month)?" % NUM, re.I)
RX_YEAR = re.compile(r"\b(?:for|over)\s+a\s+year\b", re.I)
RX_RATIO = re.compile(r"\b(twice|double|triple|half|\d+(?:\.\d+)?\s*times)\s+(?:the\s+)?earth'?s\s+(mass|radius)", re.I)
RX_RATIO_UNITS = re.compile(r"\b(\d+(?:\.\d+)?)\s+earth\s+(mass|masses|radius|radii)\b", re.I)
RX_RATIO_ITS = re.compile(r"\b(twice|double|triple|half|\d+(?:\.\d+)?\s*times)\s+(?:the\s+|its\s+)(mass|radius)", re.I)
RX_EMIT = re.compile(r"(?:each|every|per)\s+kwh\s+(?:releases|emits|produces)\s+(%s)\s*(kg|g|grams?|kilograms?)" % NUM, re.I)
RX_EMIT2 = re.compile(r"(%s)\s*(kg|g)\s+(?:of\s+)?co2\s+per\s+kwh" % NUM, re.I)
RX_COEF = re.compile(r"(?:coefficient|expansion)[^.?]*?(%s)\s*(?:per|/)\s*(?:degree|°)\s*c" % NUM, re.I)
RX_SPECHEAT = re.compile(r"specific heat\s*(?:of\s*)?(%s)\s*j\s*/\s*kg" % NUM, re.I)
RX_ACROSS = re.compile(r"(%s)\s*(m|metres?|meters?|ft|feet)\s+(?:across|in diameter|wide)\b" % NUM, re.I)
RX_ACH = re.compile(r"(%s)\s*(?:air changes per hour|ach)\b" % NUM, re.I)
RX_TALL = re.compile(r"(%s)\s*(m|metres?|meters?|ft|feet|cm)\s+(?:tall|high|deep|long)\b" % NUM, re.I)
MATERIALS = r"water|ice|aluminium|aluminum|copper|iron|steel|glass|lead|gold|silver|concrete|oil|brass|granite"
RX_MATERIAL = re.compile(r"\bkg\s+of\s+(%s)\b" % MATERIALS, re.I)
RX_NIGHTS = re.compile(r"how many\s+(%s)[- ](hours?|minutes?)\s+(\w+)" % NUM, re.I)
TOWARD = re.compile(r"\b(?:toward|towards|approach\w*|coming (?:at|toward)|comes? toward)\b", re.I)
AWAY = re.compile(r"\b(?:away|reced\w*|leaving)\b", re.I)

# network_v3's units, then its recompiled patterns
_u("pa|pascal|pascals", 1, PRESSURE)
_u("kpa|kilopascal|kilopascals", 1000, PRESSURE)
_u("bar|bars", 10 ** 5, PRESSURE)
_u("atm|atmosphere|atmospheres", 101325, PRESSURE)
_u("n/m|newtons per metre|newtons per meter", 1, STIFF)
_u("mj|megajoule|megajoules", 10 ** 6, ENERGY)
_u("gj|gigajoule|gigajoules", 10 ** 9, ENERGY)
UNIT_ALT = "|".join(sorted((re.escape(k) for k in UNITS), key=len, reverse=True))
RX_QTY = re.compile(r"(?<![\w.])(%s)\s*[- ]?\s*(%s)(?![a-z])" % (NUM, UNIT_ALT), re.I)
RX_GOAL_UNIT = re.compile(r"\b(?:how many|in|into|as|to)\s+(?:us\s+)?(%s)(?![a-z])" % UNIT_ALT, re.I)


def read_givens(text):
    """network_v2.read_givens, exact amounts. Consumed spans are masked so one number is read once."""
    t = str(text)
    used = [False] * len(t)
    out = []

    def take(m, grp=0):
        a, b = m.span(grp)
        if any(used[a:b]):
            return False
        for i in range(a, b):
            used[i] = True
        return True

    for m in RX_RANGE.finditer(t):
        u = unit_lookup(m.group(4))
        if not u or u[1] == TEMP or (m.group(2) and unit_lookup(m.group(2)) != u):
            continue
        if take(m):
            out.append(Q(abs(fnum(m.group(3)) - fnum(m.group(1))) * u[0], u[1], m.group(0), "delta"))
    for m in RX_PRICE.finditer(t):
        if take(m):
            v = fnum(m.group(1)) if m.group(1) else fnum(m.group(2)) / 100
            per = UNITS[m.group(3).lower()][0]
            out.append(Q(v / per, dmul(MONEY, ENERGY, -1), m.group(0), "price"))
    for rx in (RX_EMIT, RX_EMIT2):
        for m in rx.finditer(t):
            if take(m):
                f = UNITS[m.group(2).lower().rstrip("s") if m.group(2).lower() not in UNITS else m.group(2).lower()][0]
                out.append(Q(fnum(m.group(1)) * f / 3600000, dmul(MASS, ENERGY, -1), m.group(0), "emission"))
    for m in RX_COEF.finditer(t):
        if take(m, 1):
            out.append(Q(fnum(m.group(1)), INV_TEMP, m.group(0), "coefficient"))
    for m in RX_SPECHEAT.finditer(t):
        if take(m, 1):
            out.append(Q(fnum(m.group(1)), D(m=2, s=-2, K=-1), m.group(0), "specific_heat"))
    for m in RX_PER_DAY.finditer(t):
        if take(m):
            dur = fnum(m.group(1)) * UNITS[m.group(2).lower()][0]
            span = UNITS[m.group(3).lower()][0]
            out.append(Q(dur / span, DIMLESS, m.group(0), "duty"))
    for m in RX_DAYS_PER_WEEK.finditer(t):
        if take(m):
            out.append(Q(fnum(m.group(1)) / 7, DIMLESS, m.group(0), "duty"))
    for m in RX_RATIO.finditer(t):
        if take(m):
            w = m.group(1).lower()
            v = NUMW.get(w, None) or fnum(w.split()[0])
            out.append(Q(v, DIMLESS, m.group(0), "earth_" + m.group(2).lower()))
    for m in RX_RATIO_UNITS.finditer(t):
        if take(m):
            kind = "mass" if m.group(2).lower().startswith("mass") else "radius"
            out.append(Q(fnum(m.group(1)), DIMLESS, m.group(0), "earth_" + kind))
    for m in RX_RATIO_ITS.finditer(t):
        if take(m):
            w = m.group(1).lower()
            v = NUMW.get(w, None) or fnum(w.split()[0])
            out.append(Q(v, DIMLESS, m.group(0), "earth_" + m.group(2).lower()))
    for m in RX_ACH.finditer(t):
        if take(m):
            out.append(Q(fnum(m.group(1)) / 3600, FREQ, m.group(0), "ach"))
    for m in RX_TALL.finditer(t):
        if take(m):
            f = unit_lookup(m.group(2))[0]
            out.append(Q(fnum(m.group(1)) * f, LEN, m.group(0), "height"))
    for m in RX_ACROSS.finditer(t):
        if take(m):
            f = unit_lookup(m.group(2))[0]
            out.append(Q(fnum(m.group(1)) * f, LEN, m.group(0), "diameter"))
    for m in RX_NIGHTS.finditer(t):
        if take(m, 1) and take(m, 2):
            out.append(Q(fnum(m.group(1)) * UNITS[m.group(2).lower()][0], TIME, m.group(0), "per_unit_" + m.group(3).lower()))
    for m in RX_YEAR.finditer(t):
        if take(m):
            out.append(Q(365 * 86400, TIME, m.group(0), "span"))
    temps = []
    for m in RX_TEMP.finditer(t):
        a, b = m.span()
        if any(used[a:b]):
            continue
        u = m.group(2).lower()[0]
        v = fnum(m.group(1))
        k = (v + Fr("273.15")) if u == "c" else ((v - 32) * 5 / 9 + Fr("273.15"))
        for i in range(a, b):
            used[i] = True
        temps.append(Q(k, TEMP, m.group(0), "temp", temp_point=True))
    out.extend(temps)
    for m in RX_MONEY.finditer(t):
        if take(m):
            out.append(Q(fnum(m.group(1)), MONEY, m.group(0), "money"))
    for m in RX_QTY.finditer(t):
        a, b = m.span()
        if any(used[a:b]):
            continue
        u = unit_lookup(m.group(2))
        if not u:
            continue
        for i in range(a, b):
            used[i] = True
        out.append(Q(fnum(m.group(1)) * u[0], u[1], m.group(0), ""))
    for m in RX_DAYS_SPAN.finditer(t):
        a, b = m.span(1)
        if any(used[a:b]):
            continue
        for i in range(m.start(), m.end()):
            used[i] = True
        out.append(Q(fnum(m.group(1)) * 86400, TIME, m.group(0), "span"))
    flags = {"toward": bool(TOWARD.search(t)), "away": bool(AWAY.search(t))}
    mm = RX_MATERIAL.search(t)
    flags["material"] = mm.group(1).lower().replace("aluminum", "aluminium") if mm else ""
    flags["gasoline"] = bool(re.search(r"\b(?:gasoline|petrol|gas)\b|\bmpg\b|miles per gallon", t, re.I))
    flags["melt"] = bool(re.search(r"\bmelt\w*\b", t, re.I)) and bool(re.search(r"\bice\b", t, re.I))
    unread = [m.group(0) for m in re.finditer(r"(?<![A-Za-z^\d.,])\d+(?:[.,]\d+)*", t) if not all(used[m.start():m.end()])]
    flags["unread_numbers"] = unread
    return out, flags


# ---------------------------------------------------------------- goal (network_v2.GOALS + network_v3's "op" goals)
GOALS = [
    (r"\bis (?:that|it|this) (?:compliant|safe|okay|ok)\b.*\bcold[- ]holding\b|\bcold[- ]holding\b.*\bis (?:that|it)\b", ("bool", "cold_hold")),
    (r"\bhow many\s+(?:kilowatt-hours|kwh)\b|\bin kwh\b|\bkilowatt-hours of\b", ("dim", ENERGY, "kWh", Fr(3600000))),
    (r"\bhow many\s+kilojoules\b|\bin kilojoules\b|\bin kj\b", ("dim", ENERGY, "kJ", Fr(1000))),
    (r"\bin horsepower\b|\bhow many horsepower\b", ("dim", POWER, "hp", Fr("745.69987"))),
    (r"\bwhat (?:does|do|would|will)\b.*\bcost\b|\bcost (?:in dollars|how much)\b|\bhow much does .* cost\b", ("dim", MONEY, "$", Fr(1))),
    (r"\bwhat frequency\b|\bwhat pitch\b", ("dim", FREQ, "Hz", Fr(1))),
    (r"\bhow many seconds\b|\bhow long\b.*\bfall\b", ("dim", TIME, "s", Fr(1))),
    (r"\bacceleration\b", ("dim", ACC, "m/s²", Fr(1))),
    (r"\bhow much (?:does|would|will) .* weigh\b|\bwhat (?:does|would|will) .* weigh\b", ("dim", D(kg=1, m=1, s=-2), "N", Fr(1))),
    (r"\bhow many litres\b|\bhow many liters\b|\bin litres\b", ("dim", VOL, "L", Fr("1e-3"))),
    (r"\bhow many (?:us )?gallons\b", ("dim", VOL, "US gallons", GAL)),
    (r"\bhow many kilograms\b|\bhow many kg\b|\bin kilograms\b", ("dim", MASS, "kg", Fr(1))),
    (r"\bhow many millimetres\b|\bhow many millimeters\b|\bin mm\b", ("dim", LEN, "mm", Fr("1e-3"))),
    (r"\bhow many cfm\b|\bcfm of airflow\b", ("dim", FLOW, "CFM", FT ** 3 / 60)),
    (r"\bwhat (?:is the |would be the )?pressure\b|\bhow much pressure\b", ("dim", PRESSURE, "Pa", Fr(1), "op")),
    (r"\bbuoyant force\b|\bupthrust\b|\bwhat force\b|\bhow much force\b", ("dim", FORCE, "N", Fr(1), "op")),
    (r"\bwhat (?:is|would be) (?:the|its) mass\b|\bhow heavy\b", ("dim", MASS, "kg", Fr(1), "op")),
]
RX_COLD_BOOL = re.compile(r"\bcold[- ]holding\b", re.I)
RX_BOOL_ASK = re.compile(r"\b(?:is|are)\b[^?]*\b(?:compliant|safe|okay|ok|acceptable|allowed|within)\b|\b(?:compliant|safe|okay|acceptable)\b[^?]*\?", re.I)
RX_MONEY_ASK = re.compile(r"\b(?:cost|costs|bill|spend|pay)\b", re.I)


def read_goal(text):
    t = str(text).lower()
    q = [s for s in re.split(r"(?<=[.?!])\s+", t.strip()) if s]
    ask = q[-1] if q else t
    m = RX_NIGHTS.search(text)
    if m:
        return ("count", m.group(3).lower())
    if RX_COLD_BOOL.search(t) and RX_BOOL_ASK.search(t):
        return ("bool", "cold_hold")
    m = RX_GOAL_UNIT.search(ask)
    if m:
        u = unit_lookup(m.group(1))
        if u:
            return ("dim", u[1], m.group(1), u[0])
    for rx, gl in GOALS:
        if gl[0] != "bool" and re.search(rx, ask):
            return gl
    if RX_MONEY_ASK.search(ask) and re.search(r"\b(?:what|how much|what's)\b", ask):
        return ("dim", MONEY, "$", Fr(1))
    return None


WORDNUM = {"one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
           "eleven": 11, "twelve": 12, "fifteen": 15, "twenty": 20, "thirty": 30}
RX_WORDNUM = re.compile(r"\b(%s)\b(?=\s+(?:hours?|hrs?|minutes?|mins?|days?|weeks?|years?|seconds?|nights?)\b)" % "|".join(WORDNUM), re.I)


def normalise(text):
    return RX_WORDNUM.sub(lambda m: str(WORDNUM[m.group(1).lower()]), str(text))


# ---------------------------------------------------------------- context facts (network_v3.read_flags_v3, attached)
SUBSTANCES = {"water": "water", "fresh water": "water", "sea water": "sea water", "seawater": "sea water", "ice": "ice",
              "aluminium": "aluminium", "aluminum": "aluminium", "steel": "steel", "iron": "iron", "copper": "copper",
              "gold": "gold", "silver": "silver", "lead": "lead", "concrete": "concrete", "glass": "glass", "petrol": "petrol",
              "gasoline": "petrol", "diesel": "diesel", "ethanol": "ethanol", "mercury": "mercury", "granite": "granite",
              "brass": "brass", "olive oil": "olive oil", "honey": "honey", "milk": "milk"}
FLUIDS = {"water": "fresh water", "fresh water": "fresh water", "sea water": "sea water", "seawater": "sea water",
          "mercury": "mercury", "olive oil": "olive oil", "ethanol": "ethanol"}
FUELS = {"coal": "coal", "lignite": "lignite", "anthracite": "anthracite", "charcoal": "charcoal", "wood": "wood",
         "firewood": "wood", "lpg": "LPG", "propane": "LPG", "natural gas": "natural gas", "diesel": "diesel",
         "petrol": "petrol", "gasoline": "petrol", "kerosene": "jet fuel", "jet fuel": "jet fuel"}
FLUID_IN = re.compile(r"\b(?:in|into)\s+(?:the\s+)?(sea ?water|salt water|fresh water|water|mercury|olive oil|ethanol)\b", re.I)
FULL_OF = re.compile(r"\b(?:full of|filled with|holds?|holding|contains?)\b", re.I)


def _named(table, t):
    hits = sorted({v for k, v in table.items() if re.search(r"\b%s\b" % re.escape(k), t, re.I)})
    if "sea water" in hits and len(hits) == 2 and ("water" in hits or "fresh water" in hits):
        hits = ["sea water"]
    return hits[0] if len(hits) == 1 else ""


def attached(text, qtext, name):
    if not qtext or not name:
        return False
    alts = [k for k, v in list(SUBSTANCES.items()) + list(FUELS.items()) + list(FLUIDS.items()) if v == name] + [name]
    rx = r"%s\s+(?:(?:solid|pure|block|blocks|piece|pieces|bar|bars|lump|lumps|statue|chunk|sample|tank|drum|can|barrel)\s+)*(?:of\s+(?:solid\s+|pure\s+)?)?(?:%s)\b" % (
        re.escape(qtext), "|".join(re.escape(a) for a in sorted(set(alts), key=len, reverse=True)))
    return re.search(rx, text, re.I) is not None


def depth_attached(text, qtext):
    return re.search(r"%s\s+(?:deep|down|below|under|beneath)\b|depth of\s+%s" % (re.escape(qtext), re.escape(qtext)), text, re.I) is not None


def read_ctx(text):
    """network_v3.read_flags_v3: the facts its operations' render functions read"""
    f = {}
    f["substance"] = _named(SUBSTANCES, text)
    fm = FLUID_IN.search(text)
    f["fluid"] = FLUIDS.get(re.sub(r"\s+", " ", fm.group(1).lower()).replace("salt water", "sea water"), "") if fm else _named(FLUIDS, text)
    hits = sorted({v for k, v in SUBSTANCES.items() if re.search(r"\b%s\b" % re.escape(k), text, re.I)})
    base = {"fresh water": "water"}.get(f["fluid"], f["fluid"])
    others = [h for h in hits if h != base and not (base == "sea water" and h == "water")]
    f["object"] = others[0] if f["fluid"] and len(others) == 1 else (f["substance"] if not f["fluid"] else "")
    f["fuel"] = _named(FUELS, text)
    f["burn"] = bool(re.search(r"\bburn\w*|combust\w*", text, re.I))
    f["spring"] = bool(re.search(r"\bsprings?\b", text, re.I))
    f["asks_co2"] = bool(re.search(r"\bco2\b|carbon dioxide|\bemi(?:t|ts|tted|ssions?)\b", text, re.I))
    f["full_of"] = bool(FULL_OF.search(text))
    return f


# ---------------------------------------------------------------- typed request for the binary
def frac(x):
    x = Fr(x)
    return "%d/%d" % (x.numerator, x.denominator)


def typed(text, givens, goal, ctx, mode):
    mat = ctx["object"] or ctx["substance"]
    gs = []
    for q in givens:
        marks = []
        if attached(text, q.text, mat):
            marks.append("material")
        if attached(text, q.text, ctx["fuel"]):
            marks.append("fuel")
        if depth_attached(text, q.text):
            marks.append("depth")
        gs.append({"v": frac(q.v), "dim": list(q.dim), "role": q.role, "marks": marks})
    if goal[0] == "dim":
        g = {"kind": "dim", "dim": list(goal[1]), "factor": frac(goal[3]), "op": len(goal) > 4 and goal[4] == "op"}
    elif goal[0] == "bool":
        g = {"kind": "bool"}
    else:
        g = {"kind": "count", "unit": goal[1]}
    c = {k: (ctx[k] or None) for k in ("object", "substance", "fluid", "fuel")}
    c.update({k: ctx[k] for k in ("burn", "asks_co2", "spring", "full_of")})
    return {"mode": mode, "goal": g, "givens": gs, "ctx": c}


# ---------------------------------------------------------------- rendering (network_v2/v3's reply text)
def g6(v):
    v = float(v)
    return ("%.6g" % v) if abs(v) >= 1e-4 else ("%.4e" % v)


def fr_of(s):
    a, b = s.split("/")
    return Fr(int(a), int(b))


INVALID_TEXT = {1: "a duty of %s is more than the whole day", 2: "%s is not a physical amount",
                3: "%s is not a physical power", 4: "%s is not a physical amount", 5: "%s is not a physical body"}


def nodes_of(plan, goal):
    out = []
    for st in plan:
        out += ["core_math" for a in st["args"] if len(a) == 2]
        out.append(st["node"])
    if goal[0] != "bool":
        out.append("core_math")
    return out


class Fusion:
    def __init__(self, binary=BINARY, mode="pairwise"):
        self.mode = mode
        self.proc = subprocess.Popen([str(binary)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True, bufsize=1)

    def ask(self, req):
        self.proc.stdin.write(json.dumps(req) + "\n")
        self.proc.stdin.flush()
        return json.loads(self.proc.stdout.readline())

    def reply(self, q):
        text = normalise(q)
        givens, flags = read_givens(text)
        goal = read_goal(text)
        base = {"provenance": {"goal": None if goal is None else [str(x) for x in goal[:3]],
                               "givens": ["%s %s %s" % (q.text, q.role or "-", frac(q.v)) for q in givens]}}
        if goal is None:
            return dict(base, status="withheld", response="", path="veri7vn:fusion>declined:no_goal", kind="no_goal")
        if not givens:
            return dict(base, status="withheld", response="", path="veri7vn:fusion>declined:no_givens", kind="no_givens")
        ctx = read_ctx(text)
        req = typed(text, givens, goal, ctx, self.mode)
        req["id"] = 0
        t0 = time.perf_counter()
        out = self.ask(req)
        base["provenance"].update(binary_ms=round(1000 * (time.perf_counter() - t0), 3), decision=out, ctx=ctx,
                                  kernel="Fusion.qdecide", session="Veri7vn_Fusion", agree=self.mode)
        oc = out.get("outcome")
        if oc == "invalid":
            qq = givens[int(out["given"])]
            reason = INVALID_TEXT[int(out["rule"])] % qq.text
            return dict(base, status="withheld", path="veri7vn:fusion>validity", kind="validity",
                        response="I can't work that out as asked: %s." % reason)
        if flags.get("unread_numbers"):
            return dict(base, status="withheld", response="", path="veri7vn:fusion>declined:unread_numbers", kind="unread_numbers")
        if oc != "answer":
            return dict(base, status="withheld", response="", path="veri7vn:fusion>declined:%s" % oc, kind=oc or "error")
        plan = out["plan"]
        nodes = nodes_of(plan, goal)
        path = "veri7vn:fusion>" + " ".join(nodes)
        if "bool" in out:
            say = "yes" if out["bool"] else "no"
            return dict(base, status="answered", response="%s (path: %s)" % (say, " → ".join(nodes)), path=path, kind="fusion")
        val = fr_of(out["value"])
        if goal[0] == "count":
            sentence = "That is %s %s." % (g6(round(float(val), 4)), goal[1])
        else:
            unit = goal[2]
            say = ("$%.2f" % float(val)) if unit == "$" else "%s %s" % (g6(round(float(val), 6)), unit)
            sentence = "The answer is %s." % say
        return dict(base, status="answered", response="%s (path: %s)" % (sentence, " → ".join(nodes)), path=path,
                    value=float(val), kind="fusion")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--binary", default=str(BINARY))
    ap.add_argument("--agree", choices=["pairwise", "anchor"], default="pairwise")
    a = ap.parse_args()
    fz = Fusion(a.binary, a.agree)
    for line in sys.stdin:
        if not line.strip():
            continue
        req = json.loads(line)
        try:
            out = fz.reply(str(req.get("q", "")))
        except Exception as e:  # noqa: BLE001 - recorded, scored as withheld
            out = {"error": "%s: %s" % (type(e).__name__, e), "response": "", "path": ""}
        out["id"] = req.get("id")
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    main()
