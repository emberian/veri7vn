#!/usr/bin/env python3
"""Validate the project ledger and print derived, read-only coordination views.

Usage: python3 tools/project.py {check,ready,board} [--ledger project/tasks.json]
Overlap warnings are conservative hints, not filesystem locks. Evidence entries
are references for human review; this tool does not certify their claims.
"""

import argparse
from datetime import date
from fnmatch import fnmatchcase
import json
from pathlib import Path, PurePosixPath
import posixpath
import sys


STATUSES = ("planned", "ready", "active", "blocked", "review", "done")
LIST_FIELDS = ("depends_on", "paths", "deliverables", "acceptance", "checks", "evidence")


def strings(value):
    return isinstance(value, list) and all(isinstance(x, str) and x.strip() for x in value)


def paths_may_overlap(left, right):
    """Compare path prefixes and glob segments, intentionally over-approximating.

    A plain prefix may name a directory. Two wildcard segments may intersect;
    ** may absorb any remaining suffix. No filesystem traversal is performed.
    """
    a = PurePosixPath(posixpath.normpath(left)).parts
    b = PurePosixPath(posixpath.normpath(right)).parts
    for x, y in zip(a, b):
        if x == "**" or y == "**":
            return True
        x_glob = any(c in x for c in "*?[")
        y_glob = any(c in y for c in "*?[")
        if x_glob and y_glob:
            continue
        if x_glob and fnmatchcase(y, x):
            continue
        if y_glob and fnmatchcase(x, y):
            continue
        if x != y:
            return False
    return True


def validate(ledger):
    """Return (errors, warnings); accept optional top-level/task metadata."""
    errors, warnings = [], []
    if not isinstance(ledger, dict):
        return ["ledger must be an object"], warnings
    if type(ledger.get("schema_version")) is not int or ledger["schema_version"] != 1:
        errors.append("schema_version must be 1")
    try:
        updated = ledger.get("updated")
        if not isinstance(updated, str) or date.fromisoformat(updated).isoformat() != updated:
            raise ValueError
    except ValueError:
        errors.append("updated must be an ISO date (YYYY-MM-DD)")
    tasks = ledger.get("tasks")
    if not isinstance(tasks, list):
        return errors + ["tasks must be a list"], warnings

    by_id = {}
    for index, task in enumerate(tasks):
        label = f"tasks[{index}]"
        if not isinstance(task, dict):
            errors.append(f"{label}: task must be an object")
            continue
        for field in ("id", "title", "area"):
            if not isinstance(task.get(field), str) or not task[field].strip():
                errors.append(f"{label}: {field} must be a nonempty string")
        task_id = task.get("id")
        if isinstance(task_id, str) and task_id.strip():
            label = task_id
            if task_id in by_id:
                errors.append(f"duplicate task ID: {task_id}")
            else:
                by_id[task_id] = task
        status = task.get("status")
        if status not in STATUSES:
            errors.append(f"{label}: invalid status {status!r}")
        for field in LIST_FIELDS:
            if not strings(task.get(field)):
                errors.append(f"{label}: {field} must be a list of nonempty strings")
        owner = task.get("owner")
        if "owner" not in task or (owner is not None and (not isinstance(owner, str) or not owner.strip())):
            errors.append(f"{label}: owner must be null or a nonempty string")
        if status in ("active", "review") and not (isinstance(owner, str) and owner.strip()):
            errors.append(f"{label}: {status} requires an owner")
        if not isinstance(task.get("notes"), str):
            errors.append(f"{label}: notes must be a string")
        if status == "blocked" and not (isinstance(task.get("notes"), str) and task["notes"].strip()):
            errors.append(f"{label}: blocked task requires a blocker in notes")
        if status == "done" and not (strings(task.get("evidence")) and task["evidence"]):
            errors.append(f"{label}: done requires evidence references")

    graph = {}
    for task_id, task in by_id.items():
        deps = task.get("depends_on")
        graph[task_id] = deps if strings(deps) else []
        for dependency in graph[task_id]:
            if dependency not in by_id:
                errors.append(f"{task_id}: missing dependency {dependency}")
            elif task.get("status") == "done" and by_id[dependency].get("status") != "done":
                errors.append(f"{task_id}: done but dependency {dependency} is not done")
        if len(graph[task_id]) != len(set(graph[task_id])):
            errors.append(f"{task_id}: duplicate dependencies")

    # Iterative DFS reports back edges without imposing a recursion-depth limit.
    visited, active = set(), set()
    for task_id in graph:
        if task_id in visited:
            continue
        stack = [(task_id, iter(graph[task_id]))]
        active.add(task_id)
        while stack:
            current, dependencies = stack[-1]
            dependency = next(dependencies, None)
            if dependency is None:
                stack.pop()
                active.remove(current)
                visited.add(current)
            elif dependency in active:
                route = [node for node, _ in stack]
                start = route.index(dependency)
                errors.append("dependency cycle: " + " -> ".join(route[start:] + [dependency]))
            elif dependency in graph and dependency not in visited:
                active.add(dependency)
                stack.append((dependency, iter(graph[dependency])))

    active_tasks = [t for t in by_id.values() if t.get("status") == "active" and strings(t.get("paths"))]
    for index, left in enumerate(active_tasks):
        for right in active_tasks[index + 1:]:
            for a in left["paths"]:
                for b in right["paths"]:
                    if paths_may_overlap(a, b):
                        warnings.append(f"possible active edit overlap: {left['id']} ({a}) / {right['id']} ({b})")
    for task_id, task in by_id.items():
        if task.get("status") in ("ready", "active", "review"):
            unresolved = [d for d in graph[task_id] if d not in by_id or by_id[d].get("status") != "done"]
            if unresolved:
                warnings.append(f"{task_id}: status {task['status']} with unresolved dependencies: {', '.join(unresolved)}")
    return errors, warnings


def unresolved_dependencies(task, by_id):
    return [d for d in task["depends_on"] if by_id[d]["status"] != "done"]


def ready_tasks(ledger):
    by_id = {t["id"]: t for t in ledger["tasks"]}
    return [t for t in ledger["tasks"]
            if t["status"] in ("planned", "ready") and not unresolved_dependencies(t, by_id)]


def cell(value):
    return str(value).replace("\n", " ").replace("|", "\\|")


def board(ledger, warnings):
    """Stable Markdown, following the manually chosen ledger task order."""
    by_id = {t["id"]: t for t in ledger["tasks"]}
    ready = {t["id"] for t in ready_tasks(ledger)}
    lines = ["# Project board", "", f"Ledger updated: {ledger['updated']}.", "",
             "Generated from the task ledger. Edit the ledger, then regenerate this view.", "",
             "Readiness is derived from completed dependencies for planned/ready tasks. "
             "Evidence references require review; path overlap warnings are advisory.", "",
             "| ID | Task | Area | Status | Owner | Outstanding dependencies |",
             "| --- | --- | --- | --- | --- | --- |"]
    for task in ledger["tasks"]:
        status = task["status"]
        if task["id"] in ready:
            status += " (dispatchable)"
        fields = (task["id"], task["title"], task["area"], status, task["owner"] or "—",
                  ", ".join(unresolved_dependencies(task, by_id)) or "—")
        lines.append("| " + " | ".join(cell(f) for f in fields) + " |")
    lines.extend(["", "## Ready to dispatch", ""])
    lines.extend(f"- **{cell(t['id'])}** — {cell(t['title'])}" for t in ready_tasks(ledger))
    if not ready:
        lines.append("None.")
    blocked = [t for t in ledger["tasks"] if t["status"] == "blocked"]
    if blocked:
        lines.extend(["", "## Blockers", ""])
        lines.extend(f"- **{cell(t['id'])}** — {cell(t['notes'])}" for t in blocked)
    if warnings:
        lines.extend(["", "## Coordination warnings", ""])
        lines.extend(f"- {cell(warning)}" for warning in warnings)
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("check", "ready", "board"))
    parser.add_argument("--ledger", type=Path, default=Path("project/tasks.json"))
    args = parser.parse_args(argv)
    try:
        ledger = json.loads(args.ledger.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as error:
        print(f"error: cannot read ledger: {error}", file=sys.stderr)
        return 1
    errors, warnings = validate(ledger)
    for error in errors:
        print(f"error: {error}", file=sys.stderr)
    if errors:
        return 1
    if args.command == "board":
        print(board(ledger, warnings), end="")
    else:
        for warning in warnings:
            print(f"warning: {warning}", file=sys.stderr)
        if args.command == "check":
            print(f"Ledger valid: {len(ledger['tasks'])} tasks, {len(ready_tasks(ledger))} dispatchable, {len(warnings)} warnings.")
        else:
            for task in ready_tasks(ledger):
                print(f"{task['id']}\t{task['title']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
