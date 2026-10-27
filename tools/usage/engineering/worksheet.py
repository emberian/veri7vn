#!/usr/bin/env python3
"""Untrusted engineering worksheet: explicit roles -> reviewable arithmetic.

This is not a verified kernel or a natural-language parser. It retains the whole
structured request and emits a separate exact arithmetic check for Oracle7.
Its local reference result must never be represented as an Oracle answer.
"""
import argparse
import json
import re
from fractions import Fraction as F
from pathlib import Path

# Dimensions, scale to SI, offset to SI. Temperature endpoints use kelvin;
# intervals are separately tagged, so an offset cannot enter an interval.
UNITS = {
    "kg": ("mass", F(1), F(0)), "g": ("mass", F(1, 1000), F(0)),
    "m": ("length", F(1), F(0)), "cm": ("length", F(1, 100), F(0)),
    "mm": ("length", F(1, 1000), F(0)),
    "m/s^2": ("acceleration", F(1), F(0)),
    "kg/m^3": ("density", F(1), F(0)),
    "m^3/s": ("flow", F(1), F(0)), "L/min": ("flow", F(1, 60000), F(0)),
    "N/m": ("stiffness", F(1), F(0)),
    "J/(kg K)": ("specific_heat", F(1), F(0)),
    "K": ("temperature", F(1), F(0)),
    "C": ("temperature", F(1), F(27315, 100)),
    "F": ("temperature", F(5, 9), F(45967, 180)),
    "delta_K": ("interval", F(1), F(0)),
    "delta_C": ("interval", F(1), F(0)),
    "delta_F": ("interval", F(5, 9), F(0)),
    "1": ("fraction", F(1), F(0)), "%": ("fraction", F(1, 100), F(0)),
    "W": ("power", F(1), F(0)), "kW": ("power", F(1000), F(0)),
    "Wh": ("capacity", F(1), F(0)), "kWh": ("capacity", F(1000), F(0)),
}
MODELS = {
    "lift_input": ({"mass": "mass", "rise": "length", "gravity": "acceleration", "efficiency": "fraction"}, "J",
                   "Constant stated gravity; vertical lift; stated overall electrical-to-potential efficiency includes all losses."),
    "pump_input": ({"density": "density", "flow": "flow", "rise": "length", "gravity": "acceleration", "efficiency": "fraction"}, "W",
                   "Steady incompressible flow; no pipe friction; stated overall efficiency."),
    "spring_energy_change": ({"stiffness": "stiffness", "initial_extension": "length", "final_extension": "length"}, "J",
                             "Ideal linear spring; signed extensions measured from the same unstretched position; final minus initial stored energy."),
    "spring_force": ({"stiffness": "stiffness", "unstretched_length": "length", "final_length": "length"}, "N",
                     "Ideal linear spring; force magnitude uses the difference of final and unstretched lengths."),
    "sensible_heat": ({"mass": "mass", "specific_heat": "specific_heat", "initial_temperature": "temperature", "final_temperature": "temperature"}, "J",
                      "Constant supplied specific heat; no phase change or heat loss; positive heat enters the material."),
    "battery_runtime": ({"capacity": "capacity", "load": "power", "efficiency": "fraction", "depth_of_discharge": "fraction"}, "h",
                        "Constant load and nominal stored capacity; stated conversion efficiency and usable depth; no ageing, self-discharge or dynamic discharge model."),
    "flow_conversion": ({"flow": "flow"}, "m^3/s", "One litre is 0.001 cubic metre; one minute is 60 seconds."),
    "temperature_interval": ({"change": "interval"}, "delta_C", "A temperature interval, with no absolute-temperature offset."),
}


def fraction_text(value):
    return str(value.numerator) if value.denominator == 1 else f"({value.numerator} / {value.denominator})"


def quantity(role, record, dimension):
    if not isinstance(record, dict) or set(record) != {"value", "unit"}:
        raise ValueError(f"{role}: require exactly value and unit")
    value = record["value"]
    if isinstance(value, bool) or not isinstance(value, (str, int)):
        raise ValueError(f"{role}: use an integer or a quoted decimal, not a JSON floating-point number")
    value = str(value)
    if len(value) > 60 or not re.fullmatch(r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)", value):
        raise ValueError(f"{role}: require a finite decimal of at most 60 characters")
    unit = record["unit"]
    if not isinstance(unit, str) or unit not in UNITS or UNITS[unit][0] != dimension:
        raise ValueError(f"{role}: unsupported {dimension} unit {unit!r}")
    _, scale, offset = UNITS[unit]
    return F(value) * scale + offset


def prepare(request):
    """Return a worksheet; reject extra/missing roles instead of dropping them."""
    if not isinstance(request, dict) or set(request) != {"model", "quantities"}:
        raise ValueError("require exactly model and quantities; select assumptions explicitly through the model")
    model = request["model"]
    if not isinstance(model, str) or model not in MODELS:
        raise ValueError("unsupported model")
    required, unit, assumptions = MODELS[model]
    records = request["quantities"]
    if not isinstance(records, dict):
        raise ValueError("quantities must be an object of named roles")
    optional = {"inverter_rating": "power"} if model == "battery_runtime" else {}
    missing, extra = set(required) - set(records), set(records) - set(required) - set(optional)
    if missing or extra:
        raise ValueError(f"missing roles: {sorted(missing)}; unsupported roles: {sorted(extra)}")
    values = {role: quantity(role, record, (required | optional)[role]) for role, record in records.items()}
    for role, value in values.items():
        if role in {"initial_extension", "final_extension", "change"}:
            continue
        if value < 0:
            raise ValueError(f"{role} must be nonnegative (absolute temperatures cannot be below zero kelvin)")
        if role in {"density", "specific_heat", "stiffness", "load", "inverter_rating"} and value == 0:
            raise ValueError(f"{role} must be positive")
        if role in {"efficiency", "depth_of_discharge"} and value > 1:
            raise ValueError(f"{role} must be between zero and one")
    if model in {"lift_input", "pump_input"} and values["efficiency"] == 0:
        raise ValueError("positive efficiency is required to infer input energy or power")
    if "inverter_rating" in values and values["load"] > values["inverter_rating"]:
        raise ValueError("load exceeds inverter rating; the constant-load runtime model is not applicable")
    s = {key: fraction_text(value) for key, value in values.items()}
    v = values
    if model == "lift_input":
        expr = f"{s['mass']} * {s['gravity']} * {s['rise']} / {s['efficiency']}"
        result = v["mass"] * v["gravity"] * v["rise"] / v["efficiency"]
        formula = "mass * gravity * rise / efficiency"
    elif model == "pump_input":
        expr = f"{s['density']} * {s['flow']} * {s['gravity']} * {s['rise']} / {s['efficiency']}"
        result = v["density"] * v["flow"] * v["gravity"] * v["rise"] / v["efficiency"]
        formula = "density * volume_flow * gravity * rise / efficiency"
    elif model == "spring_energy_change":
        a, b = s["initial_extension"], s["final_extension"]
        expr = f"{s['stiffness']} * (({b} * {b}) - ({a} * {a})) / 2"
        result = v["stiffness"] * (v["final_extension"] ** 2 - v["initial_extension"] ** 2) / 2
        formula = "stiffness * (final_extension^2 - initial_extension^2) / 2"
    elif model == "spring_force":
        extension = abs(v["final_length"] - v["unstretched_length"])
        difference = f"({s['final_length']} - {s['unstretched_length']})"
        magnitude = difference if v["final_length"] >= v["unstretched_length"] else f"(0 - {difference})"
        expr = f"{s['stiffness']} * {magnitude}"
        result = v["stiffness"] * extension
        formula = "stiffness * abs(final_length - unstretched_length)"
    elif model == "sensible_heat":
        expr = f"{s['mass']} * {s['specific_heat']} * ({s['final_temperature']} - {s['initial_temperature']})"
        result = v["mass"] * v["specific_heat"] * (v["final_temperature"] - v["initial_temperature"])
        formula = "mass * specific_heat * (final_temperature - initial_temperature)"
    elif model == "battery_runtime":
        expr = f"{s['capacity']} * {s['efficiency']} * {s['depth_of_discharge']} / {s['load']}"
        result = v["capacity"] * v["efficiency"] * v["depth_of_discharge"] / v["load"]
        formula = "capacity_Wh * efficiency * depth_of_discharge / load_W"
    else:
        key = "flow" if model == "flow_conversion" else "change"
        # Keep the conversion operation visible: "What is 10?" is a factual
        # query to Oracle7, whereas "What is 18 * (5 / 9)?" requests arithmetic.
        raw_value = F(str(records[key]["value"]))
        scale = UNITS[records[key]["unit"]][1]
        expr, result = f"{fraction_text(raw_value)} * {fraction_text(scale)}", v[key]
        formula = "convert flow to m^3/s" if model == "flow_conversion" else "convert interval to delta_C without offset"
    return {
        "schema_version": 1,
        "trust": "Untrusted local worksheet. Selecting roles and model is the caller's responsibility. Oracle checks arithmetic only; this does not establish physical applicability or repair its natural-language engine.",
        "request": request,
        "assumptions": assumptions,
        "formula": formula,
        "normalized_roles": {key: fraction_text(value) for key, value in values.items()},
        "arithmetic_expression": expr,
        "oracle_question": f"What is {expr}?",
        "local_reference": {"origin": "engineering worksheet, not Oracle7", "numerator": result.numerator, "denominator": result.denominator, "unit": unit},
        "constraints": (["load <= inverter_rating; rating is capacity, not consumed power"] if "inverter_rating" in values else []),
    }


def unique_pairs(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate JSON field: {key}")
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="structured model and quantities JSON")
    parser.add_argument("--bundle", type=Path, help="read a map of named requests; write worksheets and runner cases to a NEW directory")
    args = parser.parse_args()
    try:
        data = json.loads(args.input.read_text(), object_pairs_hook=unique_pairs)
        if args.bundle:
            if not isinstance(data, dict) or not 1 <= len(data) <= 30:
                raise ValueError("batch input must map 1..30 case IDs to requests")
            if any(not re.fullmatch(r"[A-Za-z0-9_-]{1,64}", key) for key in data):
                raise ValueError("batch IDs must be 1..64 ASCII letters, digits, underscores or hyphens")
            result = {key: prepare(request) for key, request in data.items()}
            cases = [{"id": key, "conversation_id": "engineering-" + key,
                      "text": sheet["oracle_question"]} for key, sheet in result.items()]
            args.bundle.mkdir(parents=True, exist_ok=False)
            (args.bundle / "worksheets.json").write_text(json.dumps(result, indent=2) + "\n")
            (args.bundle / "cases.json").write_text(json.dumps(cases, indent=2) + "\n")
            print(str(args.bundle / "cases.json"))
            return
        result = prepare(data)
    except (OSError, ValueError) as exc:
        parser.exit(2, f"worksheet: {exc}\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
