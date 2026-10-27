"""Untrusted Python specialist: constant-throughput transfer estimates, no proof authority.

Only complete recognized questions are answered. Explicit utilization includes all
throughput losses; startup delays, contention and changing rates are outside scope.
Exact rational arithmetic precedes a decimal display rounded to 12 significant digits.
"""
from decimal import Decimal, localcontext
from fractions import Fraction
import re

NUMBER = r"-?\d{1,18}(?:\.\d{1,12})?"
PREFIX = r"(?:How long does it take to|How many seconds to)\s+(?:transfer|download|upload)\s+"
QUESTION = re.compile(
    PREFIX + rf"(?P<size>{NUMBER})\s+(?P<size_unit>[A-Za-z]+)\s+"
    rf"(?:at|over a)\s+(?P<rate>{NUMBER})\s+(?P<rate_unit>[A-Za-z/]+)"
    rf"(?:\s+connection)?\s+with\s+(?P<util>{NUMBER})%\s+utili[sz]ation\??", re.I
)
INTENT = re.compile(PREFIX, re.I)
BYTE_UNITS = {"B": 1, "kB": 1000, "MB": 1000**2, "GB": 1000**3, "TB": 1000**4,
              "KiB": 1024, "MiB": 1024**2, "GiB": 1024**3, "TiB": 1024**4}
BIT_RATES = {"bps": 1, "kbps": 1000, "Mbps": 1000**2, "Gbps": 1000**3, "Tbps": 1000**4}
RATE_UNITS = {**BIT_RATES, **{unit + "/s": factor * 8 for unit, factor in BYTE_UNITS.items()}}


def fmt(value):
    with localcontext() as ctx:
        ctx.prec = 12
        return format(Decimal(value.numerator) / Decimal(value.denominator), "g")


def decline(message):
    return {"kind": "transfer_input", "status": "withheld", "response": message}


class Organ:
    def answer(self, text, session):
        if not isinstance(text, str) or len(text) > 4096:
            return None
        text = text.strip()
        if not INTENT.match(text):
            return None
        match = QUESTION.fullmatch(text)
        if not match:
            return decline("Give one size, one sustained rate, and explicit utilization, for example: "
                           "How long does it take to transfer 1 GB at 100 Mbps with 80% utilization? "
                           "Extra delays, changing rates and additional conditions need a different model.")
        su, ru = match['size_unit'], match['rate_unit']
        if su not in BYTE_UNITS or ru not in RATE_UNITS:
            return decline("Use case-sensitive units: B means bytes, b means bits; GB/MB are decimal, "
                           "GiB/MiB binary. Supported rates include Mbps, Gbps, MB/s and MiB/s.")
        size, rate, util = (Fraction(match[key]) for key in ('size', 'rate', 'util'))
        if size < 0 or rate <= 0 or not 0 < util <= 100:
            return decline("Size must be nonnegative, rate positive, and utilization greater than 0% and at most 100%.")
        bits = size * BYTE_UNITS[su] * 8
        effective = rate * RATE_UNITS[ru] * util / 100
        seconds = bits / effective
        return {
            "kind": "transfer_seconds", "status": "answered",
            "response": f"Estimated transfer time: {fmt(seconds)} seconds. "
                        f"{fmt(bits)} bits / {fmt(effective)} effective bits per second. "
                        f"Uses the supplied {match['util']}% utilization throughout, with no startup delay. "
                        "Decimal units use powers of 1000; binary units powers of 1024; 8 bits = 1 byte.",
            "calculation": {"seconds_numerator": seconds.numerator,
                            "seconds_denominator": seconds.denominator,
                            "source": "user-supplied size, sustained rate and utilization"},
        }
