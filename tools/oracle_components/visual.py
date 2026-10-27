"""Untrusted adapters to pinned Oracle7 Vision/Artist code, not Mini authority.

Inputs are supplied bytes; no client path or URL is opened. Descriptor similarity,
caller labels/citations, and Artist self-checks are not independent truth proofs.
"""
from __future__ import annotations

import base64
import binascii
import hashlib
import importlib
import importlib.util
import io
import json
from pathlib import Path
import sys

PINS = {"vision": "271c1832780c25980253fd4816f8e812b064325c",
        "artist": "df155c6a96626f9d3bc4146c9d4a516a0b8a2ba8"}
MAX_IMAGE_BYTES = 262144
MAX_IMAGE_BASE64 = 4 * ((MAX_IMAGE_BYTES + 2) // 3)
MAX_IMAGE_PIXELS = 65536
MAX_INPUT_BASE64 = 1048576
MAX_OUTPUT_BYTES = 24576
MAX_RESULT_BYTES = 61440


def _object(properties, required):
    return {"type": "object", "properties": properties, "required": required,
            "additionalProperties": False}


IMAGE = {"type": "string", "contentEncoding": "base64", "maxLength": MAX_IMAGE_BASE64,
         "description": "PNG or JPEG; <=262144 decoded bytes, <=65536 pixels, one frame; also subject to appliance request limit."}
PROMPT = {"type": "string", "minLength": 1, "maxLength": 512,
          "description": "One or two COCO-named object groups; counts 1–5; named colours; optionally left of/right of/above/below."}
EXAMPLE = _object({"image_base64": IMAGE, "label": {"type": "string", "minLength": 1, "maxLength": 80},
                   "citation": {"type": "string", "minLength": 1, "maxLength": 256}},
                  ["image_base64", "label", "citation"])
SPRITE = _object({"image_base64": IMAGE, "class": {"type": "string", "minLength": 1, "maxLength": 80},
                  "citation": {"type": "string", "minLength": 1, "maxLength": 256}},
                 ["image_base64", "class", "citation"])


def _load(root, name, modules):
    """Check receipt-bound source bytes before importing the fixed package.

    The receipt itself is untrusted metadata until the host verifies its signed
    package. This establishes byte agreement, not source or benchmark truth.
    """
    source = root / "components" / name / "source"
    if not source.is_dir():
        raise ImportError(f"packaged {name} source is absent")
    receipt_path = root / "APPLIANCE.json"
    with receipt_path.open("rb") as stream:
        raw = stream.read(4 * 1024 * 1024 + 1)
    if len(raw) > 4 * 1024 * 1024:
        raise ValueError("component receipt exceeds 4 MiB")
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError("duplicate component receipt key")
            result[key] = value
        return result
    receipt = json.loads(raw, object_pairs_hook=pairs)
    if not isinstance(receipt, dict) or not isinstance(receipt.get("components"), dict):
        raise ValueError("component receipt must contain an object of components")
    entry = receipt["components"].get(name)
    if not isinstance(entry, dict) or entry.get("source_root") != f"components/{name}/source":
        raise ValueError("component source root missing or different from fixed package root")
    info = entry.get("source", {})
    if not isinstance(info, dict) or info.get("revision") != PINS[name]:
        raise ValueError("unsupported component base revision")
    files = info.get("files")
    if not isinstance(files, dict) or not 1 <= len(files) <= 128:
        raise ValueError("component source file inventory is missing or exceeds bounds")
    for relative, expected in files.items():
        part = Path(relative)
        if not isinstance(relative, str) or part.is_absolute() or not part.parts or any(p in (".", "..") for p in part.parts) or part.as_posix() != relative:
            raise ValueError("invalid component source path")
        path = source / part
        if path.resolve() != path.absolute() or not path.is_file():
            raise ValueError("component source is absent or symlinked")
        size = expected.get("size") if isinstance(expected, dict) else None
        digest = expected.get("sha256") if isinstance(expected, dict) else None
        if type(size) is not int or not 0 <= size <= 2 * 1024 * 1024 or path.stat().st_size != size:
            raise ValueError("component source size differs from receipt")
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError("component source hash differs from receipt")
    actual_python = {str(path.relative_to(source)) for path in source.rglob("*.py")}
    if actual_python != {path for path in files if path.endswith(".py")}:
        raise ValueError("component has unlisted Python source")
    if f"{name}/__init__.py" not in files or any(f"{name}/{module}.py" not in files for module in modules):
        raise ValueError("component module is outside receipt inventory")
    path = source / name
    identity = hashlib.sha256(json.dumps(info, sort_keys=True).encode()).hexdigest()
    alias = "_oracle_component_" + name + "_" + identity[:16]
    if alias not in sys.modules:
        spec = importlib.util.spec_from_file_location(alias, path / "__init__.py", submodule_search_locations=[str(path)])
        package = importlib.util.module_from_spec(spec)
        sys.modules[alias] = package
        try:
            spec.loader.exec_module(package)
        except BaseException:
            sys.modules.pop(alias, None)
            raise
    loaded = {module: importlib.import_module(alias + "." + module) for module in modules}
    return loaded, {"component": name, "upstream_revision": info["revision"],
        "repository": info.get("repository"), "patches": info.get("patches", []),
        "source_manifest_sha256": identity, "appliance_receipt_sha256": hashlib.sha256(raw).hexdigest(),
        "verification": "Source bytes agree with receipt; host verification of the package remains required.",
        "license": "Apache-2.0"}


def _keys(args, required, optional=()):
    if not isinstance(args, dict) or not set(required) <= args.keys() or args.keys() - set(required) - set(optional):
        raise ValueError("incorrect operation arguments")


def _string(value, maximum, name):
    if not isinstance(value, str) or not value.strip() or len(value) > maximum:
        raise ValueError(f"{name} must be a nonempty string of at most {maximum} characters")
    return value


def _image(encoded):
    from PIL import Image
    if not isinstance(encoded, str) or not encoded or len(encoded) > MAX_IMAGE_BASE64:
        raise ValueError("image_base64 exceeds encoded image limit")
    try:
        data = base64.b64decode(encoded, validate=True)
    except (ValueError, binascii.Error) as error:
        raise ValueError("image_base64 must be strict base64") from error
    if len(data) > MAX_IMAGE_BYTES:
        raise ValueError("decoded image exceeds 262144 bytes")
    try:
        with Image.open(io.BytesIO(data)) as im:
            if im.format not in ("PNG", "JPEG") or getattr(im, "n_frames", 1) != 1:
                raise ValueError("only single-frame PNG and JPEG are supported")
            if im.width < 1 or im.height < 1 or im.width * im.height > MAX_IMAGE_PIXELS or max(im.size) > 512:
                raise ValueError("image dimensions exceed limits")
            im.load()
            result = im.convert("RGBA")
    except (OSError, Image.DecompressionBombError) as error:
        raise ValueError("invalid or excessive image") from error
    return result, hashlib.sha256(data).hexdigest()


def _budget(encoded):
    if any(not isinstance(s, str) for s in encoded) or sum(map(len, encoded)) > MAX_INPUT_BASE64:
        raise ValueError("combined image base64 exceeds 1048576 characters")


class VisualOperations:
    def __init__(self, runtime: Path, workspace: Path):
        self.runtime, self.workspace = Path(runtime).resolve(), Path(workspace).resolve()
        self.modules, self.errors, self.identities = {}, {}, {}
        for name, modules in (("vision", ("features", "exemplar")), ("artist", ("core",))):
            try:
                self.modules[name], self.identities[name] = _load(self.runtime, name, modules)
            except (ImportError, OSError, ValueError, TypeError, KeyError, RecursionError) as error:
                self.errors[name] = str(error)

    def catalog(self):
        operations = [
            ("vision.describe", "Describe supplied image", "Measure fixed 32×32 HOG, LBP, colour and thumbnail descriptors; returns a normalized HRR vector, not an object label.",
             _object({"image_base64": IMAGE}, ["image_base64"])),
            ("vision.classify_examples", "Compare supplied labelled examples", "Classify against only the supplied examples and cite their indices; vote margin is not calibrated probability.",
             _object({"image_base64": IMAGE, "examples": {"type": "array", "minItems": 1, "maxItems": 8, "items": EXAMPLE},
                      "k": {"type": "integer", "minimum": 1, "maximum": 8},
                      "min_margin": {"type": "number", "minimum": 0, "maximum": 1}}, ["image_base64", "examples"])),
            ("artist.parse_layout", "Plan an object composition", "Parse supported scene wording and return every requested object's rectangle. No image or object-recognition claim.",
             _object({"prompt": PROMPT}, ["prompt"])),
            ("artist.compose", "Compose a cited sprite preview", "Render and self-check at 512×512 using supplied sprites; return a 128×128 palette preview. Labels/citations are caller assertions. Checks concern the full render, not the reduced preview.",
             _object({"prompt": PROMPT, "sprites": {"type": "array", "minItems": 1, "maxItems": 8, "items": SPRITE},
                      "seed": {"type": "integer", "minimum": 0, "maximum": 2147483647}}, ["prompt", "sprites"]))]
        result = []
        for identity, name, description, schema in operations:
            component = identity.split(".")[0]
            result.append({"id": identity, "name": name, "description": description,
                "availability": "live_direct" if component in self.modules else "unavailable",
                "reason": self.errors.get(component), "input_schema": schema,
                "output_schema": {"type": "object"}, "units": {"coordinates": "pixels"},
                "sources": [self.identities[component]] if component in self.identities else [],
                "examples": [{"arguments": {"prompt": "two cats left of a dog"}}] if identity == "artist.parse_layout" else [],
                "implementation": "existing upstream functions through bounded untrusted adapter",
                "limitations": ["No independent proof of image labels or supplied citations.",
                    "Combined image base64 <=1048576 characters; source images <=262144 bytes and <=65536 pixels each. The configured appliance request limit also applies.",
                    "Packaged recognition exemplars, OCR fonts and COCO sprite assets are not included.",
                    "Replies <=60KiB; rendered image is a <=24KiB PNG preview. Full image artifact delivery is not implemented."]})
        for identity, name, reason in [
                ("vision.recognize", "Recognize against packaged benchmark store", "Missing labelled exemplar store: upstream publishes source/results, not its 410–490 MB store."),
                ("vision.read_text", "Read text using rendered font exemplars", "No pinned open-license font inventory or rendered glyph store is provisioned."),
                ("vision.chart_qa", "Answer chart questions", "Upstream chart rules require OCR output; no pinned font/glyph store is provisioned. Published chart accuracy does not qualify arbitrary answers."),
                ("vision.ground_screen", "Locate screen text", "Upstream screen grounding requires the unprovisioned glyph reader; does not itself click or operate a UI."),
                ("artist.build_library", "Build a COCO sprite library", "Requires an explicit dataset-import/build job with COCO photographs and segmentation annotations; not exposed by the query profile."),
                ("artist.render_library", "Render from packaged COCO sprites", "Missing COCO sprite library/index; upstream's recorded index hash is 4b1d83af4ab12424822ce58129fd044283fa77d216bac789784c80f062187f4d.")]:
            result.append({"id": identity, "name": name, "description": reason, "availability": "unavailable",
                           "reason": reason, "input_schema": _object({}, []), "output_schema": {"type": "object"},
                           "units": {}, "sources": [], "examples": [], "implementation": "not provisioned", "limitations": [reason]})
        return result

    def _vectors(self, images):
        import numpy as np
        from PIL import Image
        arrays = []
        for im in images:
            background = Image.new("RGBA", im.size, "white")
            background.alpha_composite(im)
            arrays.append(np.asarray(background.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS)))
        features = self.modules["vision"]["features"]
        groups = features.groups(np.stack(arrays))
        return features.encode(groups, {key: 1.0 for key in groups}), groups

    def invoke(self, identity, args):
        result = self._invoke(identity, args)
        if len(json.dumps(result, ensure_ascii=False, allow_nan=False, separators=(",", ":")).encode()) > MAX_RESULT_BYTES:
            return {"status": "withheld", "reason": "result_requires_larger_response_profile", "max_result_bytes": MAX_RESULT_BYTES}
        return result

    def _invoke(self, identity, args):
        available = {row["id"]: row for row in self.catalog()}
        if identity not in available:
            raise ValueError("unknown visual operation")
        if available[identity]["availability"] != "live_direct":
            return {"status": "withheld", "reason": "component_unavailable", "detail": available[identity]["reason"]}
        if identity == "vision.describe":
            _keys(args, ("image_base64",))
            _budget([args["image_base64"]])
            im, digest = _image(args["image_base64"])
            vectors, groups = self._vectors([im])
            return {"status": "answered", "image_sha256": digest, "original_size": list(im.size),
                    "normalization": "composite on white, resize RGB to 32x32 with Lanczos; equal group weights",
                    "descriptor_dimensions": {key: int(value.shape[1]) for key, value in groups.items()},
                    "vector": vectors[0].tolist(), "evidence": "fixed image measurements; no recognition performed"}
        if identity == "vision.classify_examples":
            import math
            import numpy as np
            _keys(args, ("image_base64", "examples"), ("k", "min_margin"))
            examples = args["examples"]
            if not isinstance(examples, list) or not 1 <= len(examples) <= 8:
                raise ValueError("provide one through eight labelled examples")
            for item in examples:
                _keys(item, ("image_base64", "label", "citation"))
                _string(item["label"], 80, "label"); _string(item["citation"], 256, "citation")
            _budget([args["image_base64"], *[item["image_base64"] for item in examples]])
            k, margin = args.get("k", min(3, len(examples))), args.get("min_margin", 0.1)
            if type(k) is not int or not 1 <= k <= len(examples):
                raise ValueError("k must not exceed supplied example count")
            if type(margin) not in (int, float) or not math.isfinite(margin) or not 0 <= margin <= 1:
                raise ValueError("min_margin must be finite in [0,1]")
            decoded = [_image(value) for value in [args["image_base64"], *[item["image_base64"] for item in examples]]]
            vectors, _ = self._vectors([pair[0] for pair in decoded])
            labels = list(dict.fromkeys(item["label"] for item in examples))
            store = self.modules["vision"]["exemplar"].ExemplarStore(vectors[1:], np.array([labels.index(item["label"]) for item in examples]), len(labels))
            indices, similarities = store.neighbours(vectors[:1], k)
            winners, margins, votes = store.vote(indices, similarities, k)
            accepted = float(margins[0]) >= margin
            return {"status": "answered" if accepted else "withheld", "label": labels[int(winners[0])] if accepted else None,
                    "reason": None if accepted else "insufficient_vote_margin", "vote_margin": float(margins[0]),
                    "votes": dict(zip(labels, votes[0].tolist())), "query_sha256": decoded[0][1],
                    "neighbours": [{"index": int(index), "label": examples[index]["label"], "citation": examples[index]["citation"],
                                    "image_sha256": decoded[index+1][1], "similarity": float(similarities[0][position])}
                                   for position, index in enumerate(indices[0])],
                    "evidence": "Comparison only against caller-supplied labelled examples; labels and citations are not independently verified."}
        core = self.modules["artist"]["core"]
        if identity == "artist.parse_layout":
            _keys(args, ("prompt",))
            spec = core.parse(_string(args["prompt"], 512, "prompt"))
            return {"status": "answered", "specification": spec, "boxes": core.layout(spec), "canvas_size": [512, 512],
                    "evidence": "Parsed scene and planned rectangles; no rendered image or recognition claim."}
        _keys(args, ("prompt", "sprites"), ("seed",))
        spec = core.parse(_string(args["prompt"], 512, "prompt"))
        sprites, seed = args["sprites"], args.get("seed", 0)
        if not isinstance(sprites, list) or not 1 <= len(sprites) <= 8 or type(seed) is not int or not 0 <= seed <= 2147483647:
            raise ValueError("provide one through eight sprites and a bounded integer seed")
        for item in sprites:
            _keys(item, ("image_base64", "class", "citation"))
            _string(item["citation"], 256, "citation")
            if item["class"] not in core.COCO:
                raise ValueError("sprite class is outside Artist vocabulary")
        _budget([item["image_base64"] for item in sprites])
        items = []
        for item in sprites:
            im, digest = _image(item["image_base64"])
            if not im.getchannel("A").getbbox():
                raise ValueError("sprite has no visible pixels")
            items.append({"class": item["class"], "image": im, "image_sha256": digest,
                          "cite": {"supplied": item["citation"], "image_sha256": digest}})
        if any(not any(item["class"] == obj["class"] for item in items) for obj in spec["objects"]):
            raise ValueError("a requested object class has no supplied sprite")
        class SuppliedLibrary:
            def pick(self, cls, rng, k=1, color=None):
                choices = [item for item in items if item["class"] == cls]
                return rng.sample(choices, k) if len(choices) >= k else [rng.choice(choices) for _ in range(k)]
            def load(self, item):
                return item["image"].copy()
        image, placed = core.render(spec, SuppliedLibrary(), seed)
        verified, clauses = core.verify(spec, image, placed)
        from PIL import Image
        full = io.BytesIO(); image.save(full, format="PNG")
        full_digest = hashlib.sha256(full.getvalue()).hexdigest()
        preview = image.resize((128, 128), Image.Resampling.LANCZOS).quantize(colors=256)
        out = io.BytesIO(); preview.save(out, format="PNG")
        data = out.getvalue()
        if len(data) > MAX_OUTPUT_BYTES:
            return {"status": "withheld", "reason": "preview_exceeds_output_limit", "max_image_bytes": MAX_OUTPUT_BYTES}
        return {"status": "answered" if verified else "withheld", "reason": None if verified else "composition_self_check_failed",
                "specification": spec, "self_check": {"passed": bool(verified), "clauses": clauses, "canvas_size": [512, 512]},
                "full_render_sha256": full_digest, "placement_coordinate_space": [512, 512],
                "image": {"mime_type": "image/png", "sha256": hashlib.sha256(data).hexdigest(),
                          "base64": base64.b64encode(data).decode(), "width": preview.width, "height": preview.height,
                          "kind": "preview", "transform": "512x512 render reduced with Lanczos to128x128 and quantized to256 colours; full render is not retained as an artifact"},
                "placed": [{key: value for key, value in item.items() if key != "alpha"} for item in placed],
                "evidence": "Caller-supplied class/citation claims; original Artist rendering and pixel/layout self-check, not independent recognition."}
