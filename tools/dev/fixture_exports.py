"""Data-only bridge for the single native scaffold fixture; not a package loader."""
import json


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"Duplicate JSON key: {key}")
        result[key] = value
    return result


def sml_string(value):
    if not isinstance(value, str):
        raise ValueError("Native fixture names must be strings")
    # Three decimal digits per UTF-8 byte: descriptor text cannot become ML code.
    return '"' + ''.join('\\%03d' % byte for byte in value.encode('utf-8')) + '"'


def export_data(descriptor_bytes):
    descriptor = json.loads(descriptor_bytes, object_pairs_hook=unique_object)
    if descriptor["format"] != "veri7vn.package/0":
        raise ValueError("Unexpected fixture descriptor format")
    native = descriptor["native"]
    exports = []
    for capability in descriptor["capabilities"]:
        exports.append(("specification", capability["specification"]))
        exports.extend(("contract", locator) for locator in capability["contracts"])
        if "executable" in capability:
            exports.append(("executable", capability["executable"]))
    rows = ["(" + ", ".join(map(sml_string, (kind, locator["theory"], locator["name"]))) + ")"
            for kind, locator in exports]
    return ("(* Generated data from tests/scaffold/package.json; do not edit. *)\n"
            "structure Scaffold_Declared_Exports = struct\n"
            "val session = " + sml_string(native["session"]) + ";\n"
            "val theories = [" + ", ".join(map(sml_string, native["theories"])) + "];\n"
            "val exports = [" + ",\n".join(rows) + "];\nend;\n")
