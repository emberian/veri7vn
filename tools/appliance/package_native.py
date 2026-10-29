#!/usr/bin/env python3
"""Untrusted local distribution builder for an operator-admitted native artifact.

Copies an audited explicit Python import closure, never the checkout or data.
It does not execute/admit the extension, attest its build, install dependencies,
load a dataset, or publish a release. Central qualification verifies actual exports.
"""
from __future__ import annotations

import argparse
import ast
import ctypes
import gzip
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import stat
import subprocess
import sys
import tarfile
import tempfile
import tomllib

ROOT = Path(__file__).resolve().parents[2]
FORMAT = "oracle-native-distribution-v1"
BUILDER_VERSION = 1
PROFILES = ("reasoning", "science", "incremental", "bio", "statistics", "runtime")
# These files preserve native_service's parents[1]/oracle_components import and
# native_worker's fixed sibling native_runtime loader. No tree/glob is copied.
PYTHON_FILES = tuple("tools/appliance/" + name + ".py" for name in (
    "native_service", "native_pool", "native_worker", "native_runtime", "operations", "serve")) + tuple(
    "tools/oracle_components/" + name + ".py" for name in (
        "native_science", "native_incremental", "native_bio", "native_statistics", "native_runtime_adapter", "reasoning"))
# Shared transport/operation modules contain dormant Engine-only paths. Native
# service constructs Operations(None), never serve.main or json_value(sympy).
DORMANT_IMPORTS = {("tools/appliance/serve.py", "main", "tenant_pool"),
                   ("tools/appliance/operations.py", "json_value", "sympy")}
DYNAMIC_IMPORTS = {
    "tools/appliance/native_worker.py": "operator-admitted extension only; fixed sibling native_runtime import",
    "tools/appliance/operations.py": "load_module used only by Engine paths; native service uses Operations(None)",
    "tools/appliance/serve.py": "upstream Engine loader used only by legacy serve.main, never native_service",
}
EXPECTED_DYNAMIC_CALLS = {
    ("tools/appliance/native_worker.py", "main", "importlib.util.spec_from_file_location"),
    ("tools/appliance/operations.py", "load_module", "importlib.util.spec_from_file_location"),
    ("tools/appliance/serve.py", "import_launcher", "importlib.util.spec_from_file_location"),
}

LAUNCHER = '''#!/usr/bin/env -S python3 -I -B -S
"""Untrusted distribution launcher; local hashes are integrity checks, not signatures."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import stat
import sys

ROOT = Path(__file__).absolute().parent.parent
FORMAT = "oracle-native-distribution-v1"

def regular(path):
    for part in (path, *path.parents):
        if part.is_symlink():
            raise ValueError("symlink in bundle or operator path")
    if not stat.S_ISREG(path.stat().st_mode):
        raise ValueError("not a regular file")
    return path

def read_json(path):
    def pairs(rows):
        result = {}
        for key, value in rows:
            if key in result:
                raise ValueError("duplicate JSON key")
            result[key] = value
        return result
    return json.loads(regular(path).read_bytes(), object_pairs_hook=pairs,
                      parse_constant=lambda _: (_ for _ in ()).throw(ValueError("non-finite JSON")))

def verify():
    if sys.version_info < (3, 12) or os.name != "posix":
        raise ValueError("requires POSIX CPython 3.12 or newer")
    if sys.implementation.name != "cpython":
        raise ValueError("requires CPython")
    manifest_path = ROOT / "MANIFEST.json"
    manifest = read_json(manifest_path)
    if manifest.get("schema") != FORMAT or not isinstance(manifest.get("files"), dict):
        raise ValueError("unsupported bundle manifest")
    for name, expected in manifest["files"].items():
        relative = PurePosixPath(name)
        if relative.is_absolute() or ".." in relative.parts or str(relative) != name:
            raise ValueError("unsafe manifest path")
        path = regular(ROOT.joinpath(*relative.parts))
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected["sha256"] or path.stat().st_size != expected["bytes"]:
            raise ValueError("bundle hash mismatch: " + name)
    expected_files = set(manifest["files"]) | {"MANIFEST.json"}
    actual_files = set()
    for path in ROOT.rglob("*"):
        if path.is_symlink():
            raise ValueError("symlink in bundle")
        if path.is_file():
            actual_files.add(path.relative_to(ROOT).as_posix())
        elif not path.is_dir():
            raise ValueError("special file in bundle")
    if actual_files != expected_files:
        raise ValueError("bundle file set differs from manifest")
    return manifest, hashlib.sha256(manifest_path.read_bytes()).hexdigest()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true", help="verify payload hashes without loading native code")
    parser.add_argument("--write-config", type=Path, help="write a new operator example with absolute bundled extension path")
    parser.add_argument("--config", type=Path, help="external operator JSON; @bundle/extension binds bundled artifact")
    args = parser.parse_args()
    if sum((args.verify, args.write_config is not None, args.config is not None)) != 1:
        parser.error("choose exactly one of --verify, --write-config, --config")
    manifest, digest = verify()
    if args.verify:
        print(json.dumps({"schema": FORMAT, "manifest_sha256": digest, "payload_verified": True,
                          "profiles_requested": manifest["profiles_requested"], "exports_qualified": False}, sort_keys=True))
        return
    if args.write_config:
        config = read_json(ROOT / "operator.example.json")
    else:
        config = read_json(args.config.absolute())
    extension = str(ROOT / manifest["extension"]["path"])
    for provider in config.get("providers", []):
        if provider.get("extension") not in ("@bundle/extension", extension):
            raise ValueError("provider must use this bundle's extension")
        if provider.get("sha256") != manifest["extension"]["sha256"]:
            raise ValueError("provider digest must match this bundle")
        if provider.get("profile") not in manifest["profiles_requested"]:
            raise ValueError("profile was not requested for this bundle")
        provider["extension"] = extension
        runtime = provider.get("runtime")
        if runtime is not None:
            for field in ("image", "state"):
                sidecar = Path(runtime[field])
                if not sidecar.is_absolute() or ".." in sidecar.parts or sidecar.is_relative_to(ROOT):
                    raise ValueError("runtime image/state must be absolute external sidecars")
    if args.write_config:
        path = args.write_config.absolute()
        for part in (path, *path.parents):
            if part.is_symlink():
                raise ValueError("symlink in config path")
        if path.is_relative_to(ROOT):
            raise ValueError("operator config belongs outside immutable bundle")
        with open(path, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
            stream.write(json.dumps(config, indent=2, sort_keys=True) + "\\n")
        print(str(path))
        return
    # The pre-import re-exec below removes environment, cwd and site packages.
    sys.path[:] = [str(ROOT / "python/appliance"), str(ROOT / "python")] + [
        p for p in sys.path if p and Path(p).is_absolute() and not Path(p).is_relative_to(ROOT)]
    # Reuse the service's exact parser through a temporary private config.
    # Runtime manifests stay exact strings and operator sidecars are not copied.
    import native_service
    original = native_service.read_config
    def read_config(_):
        import tempfile
        with tempfile.TemporaryDirectory(prefix="oracle-native-operator-") as directory:
            path = Path(directory) / "config.json"
            with open(path, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
                stream.write(json.dumps(config, allow_nan=False))
            return original(path)
    native_service.read_config = read_config
    sys.argv = [str(ROOT / "python/appliance/native_service.py"), "--config", str(args.config)]
    native_service.main()

if __name__ == "__main__":
    if not sys.flags.isolated or not sys.flags.dont_write_bytecode or not sys.flags.no_site:
        os.execv(sys.executable, [sys.executable, "-I", "-B", "-S", str(Path(__file__).absolute()), *sys.argv[1:]])
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("oracle-native: " + str(error), file=sys.stderr)
        sys.exit(2)
'''


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n").encode()


def clean_path(value):
    """Refuse traversal and symlink components before resolving anything."""
    path = Path(value)
    if ".." in path.parts:
        raise ValueError("path traversal is not permitted")
    path = path.absolute()
    for component in (path, *path.parents):
        if component.is_symlink():
            raise ValueError("symlink paths are not permitted")
    return path


def read_regular(path):
    path = clean_path(path)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0)
    with os.fdopen(os.open(path, flags), "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError("input is not a regular file")
        return stream.read()


def audit_python_closure(source_root):
    """Audit every static import, including fixed dynamic runtime sibling import.

    This is an import inventory, not a Python sandbox or proof of reachability.
    The two named Engine-only imports remain dormant in the native entrypoint.
    Any newly introduced external/local import requires explicit review here.
    """
    contents = {name: read_regular(source_root / name) for name in PYTHON_FILES}
    local = {Path(name).stem for name in PYTHON_FILES if "/appliance/" in name}
    components = {Path(name).stem for name in PYTHON_FILES if "/oracle_components/" in name}
    audit = []
    dynamic_calls = set()
    for name, data in contents.items():
        tree = ast.parse(data, filename=name)
        stack = []
        class Imports(ast.NodeVisitor):
            def visit_FunctionDef(self, node):
                stack.append(node.name)
                self.generic_visit(node)
                stack.pop()
            visit_AsyncFunctionDef = visit_FunctionDef
            def visit_Call(self, node):
                call = ast.unparse(node.func)
                if call in ("__import__", "importlib.import_module", "importlib.util.spec_from_file_location"):
                    item = (name, stack[-1] if stack else "", call)
                    if item not in EXPECTED_DYNAMIC_CALLS:
                        raise ValueError("unaudited dynamic import: " + name + ": " + call)
                    dynamic_calls.add(item)
                self.generic_visit(node)
            def visit_Import(self, node):
                for item in node.names:
                    self.check(item.name, 0)
            def visit_ImportFrom(self, node):
                self.check(node.module or "", node.level)
            def check(self, module, level):
                top = module.split(".")[0]
                if (name, stack[-1] if stack else "", module) in DORMANT_IMPORTS:
                    audit.append({"file": name, "import": module, "scope": "dormant Engine path"})
                elif level:
                    if "/oracle_components/" not in name or level != 1 or module not in components:
                        raise ValueError("unbundled relative import: " + name + ": " + module)
                elif top in sys.stdlib_module_names or top == "__future__":
                    pass
                elif module in local:
                    pass
                elif top == "oracle_components" and module.partition(".")[2] in components:
                    pass
                else:
                    raise ValueError("unbundled import: " + name + ": " + module)
        Imports().visit(tree)
    if dynamic_calls != EXPECTED_DYNAMIC_CALLS:
        raise ValueError("fixed dynamic import inventory changed; review the closure")
    return contents, {"static_imports": "closed except named dormant Engine imports", "dormant_imports": audit,
                       "dynamic_loaders": DYNAMIC_IMPORTS,
                       "runtime_entrypoint": "native_service.main; Operations(None); native_worker fixed profile loader"}


def publish_directory(staged, output):
    """Atomic exclusive rename: fail if *anything* already occupies output."""
    library = ctypes.CDLL(None, use_errno=True)
    source, target = os.fsencode(staged), os.fsencode(output)
    if sys.platform == "darwin":
        rename = library.renamex_np
        rename.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint]
        result = rename(source, target, 0x00000004)  # RENAME_EXCL
    elif sys.platform.startswith("linux"):
        rename = library.renameat2
        rename.argtypes = [ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint]
        result = rename(-100, source, -100, target, 1)  # AT_FDCWD, RENAME_NOREPLACE
    else:
        raise ValueError("atomic exclusive directory publication requires Linux or macOS")
    if result:
        number = ctypes.get_errno()
        raise OSError(number, os.strerror(number), str(output))


def write_archive(bundle, destination):
    """Deterministic gzip/tar metadata, atomic exclusive publication."""
    bundle, destination = clean_path(bundle), clean_path(destination)
    if destination.exists():
        raise FileExistsError(destination)
    if not destination.parent.is_dir():
        raise ValueError("archive parent must already exist")
    with tempfile.NamedTemporaryFile(prefix=".oracle-native-archive-", dir=destination.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            with gzip.GzipFile(filename="", mode="wb", fileobj=stream, mtime=0) as compressed:
                with tarfile.open(fileobj=compressed, mode="w", format=tarfile.USTAR_FORMAT) as archive:
                    for path in sorted(bundle.rglob("*")):
                        if path.is_symlink() or not (path.is_dir() or path.is_file()):
                            raise ValueError("archive input contains symlink or special file")
                        name = "oracle-native/" + path.relative_to(bundle).as_posix()
                        info = tarfile.TarInfo(name + ("/" if path.is_dir() else ""))
                        info.uid = info.gid = 0
                        info.uname = info.gname = ""
                        info.mtime = 0
                        info.mode = 0o755 if path.is_dir() or path.relative_to(bundle).as_posix() == "bin/oracle-native" else 0o644
                        if path.is_dir():
                            info.type = tarfile.DIRTYPE
                            archive.addfile(info)
                        else:
                            data = read_regular(path)
                            info.size = len(data)
                            import io
                            archive.addfile(info, io.BytesIO(data))
            stream.flush()
            os.fsync(stream.fileno())
            os.link(temporary, destination)  # exclusive, same filesystem
        finally:
            temporary.unlink(missing_ok=True)


def build_distribution(extension, sha256, output, profiles, *, archive=None, source_root=ROOT):
    """Create a local immutable payload; selected profiles remain unqualified."""
    if sys.version_info < (3, 12) or sys.platform not in ("darwin", "linux") or sys.implementation.name != "cpython":
        raise ValueError("builder requires Linux/macOS CPython 3.12 or newer")
    if not isinstance(sha256, str) or not re.fullmatch(r"[0-9a-f]{64}", sha256):
        raise ValueError("expected lowercase SHA-256 is required")
    profiles = tuple(profiles)
    if not profiles or len(set(profiles)) != len(profiles) or any(profile not in PROFILES for profile in profiles):
        raise ValueError("choose unique explicit profiles")
    profiles = tuple(profile for profile in PROFILES if profile in profiles)
    extension, output = clean_path(extension), clean_path(output)
    if output.exists() or not output.parent.is_dir():
        raise ValueError("output must be absent with an existing parent")
    archive_path = clean_path(archive) if archive is not None else None
    if archive_path is not None and (archive_path.exists() or not archive_path.parent.is_dir()
                                     or archive_path == output or archive_path.is_relative_to(output)):
        raise ValueError("archive must be absent, outside output, with an existing parent")
    extension_data = read_regular(extension)
    if digest(extension_data) != sha256:
        raise ValueError("extension SHA-256 mismatch")
    if extension.suffix not in (".so", ".dylib"):
        raise ValueError("expected Linux/macOS shared library (.so or .dylib)")
    source_root = clean_path(source_root)
    contents, audit = audit_python_closure(source_root)
    cargo_data = read_regular(source_root / "native/Cargo.toml")
    version = tomllib.loads(cargo_data.decode())["workspace"]["package"]["version"]
    python_export_data = read_regular(source_root / "native/oracle-python/src/lib.rs")
    api_match = re.search(r'module\.add\("API_VERSION",\s*"([^"]+)"\)', python_export_data.decode())
    if api_match is None:
        raise ValueError("native API version declaration changed; review distribution metadata")
    api_version = api_match.group(1)
    # Never imply that checkout revision proves which sources produced the input.
    revision = None
    try:
        result = subprocess.run(["git", "-C", str(source_root), "rev-parse", "HEAD"], capture_output=True, text=True, check=True)
        if re.fullmatch(r"[0-9a-f]{40}\n?", result.stdout):
            revision = result.stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        pass
    payload = {"python/" + name.removeprefix("tools/"): data for name, data in contents.items()}
    payload["lib/oracle_native.so"] = extension_data
    payload["bin/oracle-native"] = LAUNCHER.encode()
    config = {"schema": 1, "port": 7071, "limits": {"workers": 2, "timeout_seconds": 5.0}, "providers": []}
    for profile in profiles:
        row = {"id": profile, "profile": profile, "extension": "@bundle/extension", "sha256": sha256}
        if profile == "runtime":
            row["runtime"] = {"image": "/operator/data/image.sqlite", "image_sha256": "REPLACE_WITH_IMAGE_SHA256",
                "state": "/operator/state/sessions.sqlite", "manifest_json": "REPLACE_WITH_COMPLETE_EXACT_RELEASE_JSON",
                "release_identity": "REPLACE_WITH_RELEASE_IDENTITY", "core_limits": {"workers": 1, "result_bytes": 262144},
                "state_file_bytes": 268435456}
        config["providers"].append(row)
    payload["operator.example.json"] = json_bytes(config)
    payload["README.txt"] = ("Oracle native appliance distribution\n\n"
        "Requires trusted Linux/macOS CPython >=3.12, matching extension architecture/OS and system dynamic libraries.\n"
        "No interpreter, dataset, private operator config or persistent state is included.\n"
        "python3 -I -B -S bin/oracle-native --verify\n"
        "python3 -I -B -S bin/oracle-native --write-config /operator/native.json\n"
        "Edit external config; runtime profile requires a complete admitted release and external image/state.\n"
        "python3 -I -B -S bin/oracle-native --config /operator/native.json\n"
        "Service listens on private loopback. Routing header is not authentication.\n"
        "Profiles are requested, not qualified. Startup admits actual exports/catalogs.\n"
        "Hashes bind included files only, not Python/system libraries or build provenance.\n"
        "Manifest is not signed; protect the bundle, manifest and sidecars from untrusted writes.\n").encode()
    manifest = {"schema": FORMAT, "builder_version": BUILDER_VERSION,
        "code": {"native_workspace_version_declaration": version, "checkout_revision": revision,
                 "checkout_is_build_provenance": False, "cargo_toml_sha256": digest(cargo_data),
                 "python_export_source_sha256": digest(python_export_data),
                 "builder_sha256": digest(read_regular(Path(__file__)))},
        "extension": {"path": "lib/oracle_native.so", "sha256": sha256,
                      "api_version_expected_from_source": api_version, "api_version_observed": None,
                      "version_verified": False, "build_provenance_verified": False},
        "profiles_requested": list(profiles), "profiles_export_qualified": [],
        "requirements": {"interpreter": "CPython >=3.12; abi3-py312 extension expected, not inspected",
             "builder_system": platform.system(), "builder_machine": platform.machine(),
             "extension_target": "operator must verify input OS/architecture/ABI and linked system libraries",
             "system_dynamic_dependencies": "not bundled; inspect admitted artifact with ldd (Linux) or otool -L (macOS)",
             "hermetic": False, "third_party_python": "none on native entrypoint",
             "host_features": "POSIX fcntl/resource/process groups; Linux renameat2 or Darwin renamex_np for builder"},
        "externals": ["CPython interpreter and standard library", "system dynamic libraries", "operator configuration",
                      "optional admitted runtime image/release", "optional durable journal and retained state"],
        "import_audit": audit,
        "files": {name: {"sha256": digest(data), "bytes": len(data)} for name, data in sorted(payload.items())}}
    with tempfile.TemporaryDirectory(prefix=".oracle-native-package-", dir=output.parent) as temporary:
        staged = Path(temporary) / "payload"
        staged.mkdir(mode=0o755)
        for name, data in payload.items():
            path = staged / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            path.chmod(0o755 if name == "bin/oracle-native" else 0o644)
        (staged / "MANIFEST.json").write_bytes(json_bytes(manifest))
        (staged / "MANIFEST.json").chmod(0o644)
        # If archive was requested, manufacture it before publishing the directory.
        # Each destination is atomic/exclusive; two-path publication is not a transaction.
        if archive_path is not None:
            write_archive(staged, archive_path)
        publish_directory(staged, output)
    return {"output": str(output), "manifest_sha256": digest(json_bytes(manifest)),
            "extension_sha256": sha256, "archive": str(archive_path) if archive_path else None,
            "profiles_requested": list(profiles), "profiles_export_qualified": []}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--extension", type=Path, required=True)
    parser.add_argument("--sha256", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--profile", choices=PROFILES, action="append", required=True)
    parser.add_argument("--archive", type=Path)
    args = parser.parse_args()
    try:
        result = build_distribution(args.extension, args.sha256, args.output, args.profile, archive=args.archive)
    except (OSError, ValueError, SyntaxError) as error:
        parser.exit(2, "package_native: " + str(error) + "\n")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main()
