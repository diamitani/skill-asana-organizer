#!/usr/bin/env python3
"""
server.py — Mini MCP (Model Context Protocol) server for the asana-organizer skill.

Provides a unified, normalized interface across Asana, ClickUp, Monday.com,
Trello, Notion, and Jira by shelling out to ./scripts/connectors.sh.

Tools exposed:
  - fetch_project(tool, project_url_or_id)              → normalized JSON
  - apply_rewrites(tool, project_id, rewrites)           → apply task rewrites
  - create_sections(tool, project_id, sections)          → create sections/groups
  - move_tasks(tool, moves)                              → move tasks between sections
  - get_health()                                         → {status, tools_supported}

Wire-up: see ./README.md (Claude Desktop, Cursor, VS Code Continue).

Dependencies:
  - Python 3.11+
  - mcp (pip install mcp)  — uses the official MCP SDK
  - ./scripts/connectors.sh and ./scripts/asana-api.sh
  - bash + curl on PATH

Designed to be launched by MCP clients (Claude Desktop, Cursor, etc.) as a
stdio subprocess. Do not invoke manually unless passing --check.
"""

from __future__ import annotations

import asyncio
import json
import os
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SERVER_FILE = Path(__file__).resolve()
MCP_DIR     = SERVER_FILE.parent
SKILL_DIR   = MCP_DIR.parent
SCRIPTS_DIR = SKILL_DIR / "scripts"
CONNECTORS  = SCRIPTS_DIR / "connectors.sh"
ASANA_API   = SCRIPTS_DIR / "asana-api.sh"

SUPPORTED_TOOLS = ("asana", "clickup", "monday", "trello", "notion", "jira")


# ---------------------------------------------------------------------------
# Connector invocation
# ---------------------------------------------------------------------------

def _ensure_prereqs() -> None:
    """Sanity-check that connectors.sh + bash + curl exist."""
    if not CONNECTORS.exists():
        raise RuntimeError(f"connectors.sh not found at {CONNECTORS}")
    if shutil.which("bash") is None:
        raise RuntimeError("bash not found on PATH")
    if shutil.which("curl") is None:
        raise RuntimeError("curl not found on PATH")


def _run_bash_function(fn_name: str, args: list[str]) -> str:
    """Source connectors.sh, invoke a function, return stdout (JSON)."""
    if not fn_name.replace("_", "").isalnum():
        raise ValueError(f"invalid function name: {fn_name}")
    args_quoted = " ".join(shlex.quote(a) for a in args)
    script = (
        f'source {shlex.quote(str(CONNECTORS))} 2>/dev/null\n'
        f'{fn_name} {args_quoted}\n'
    )
    proc = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        check=False,
        env=os.environ.copy(),
    )
    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(
            f"{fn_name} failed (exit {proc.returncode}): {proc.stderr.strip()}"
        )
    return proc.stdout


def _json_or_error(stdout: str, fn_name: str) -> dict[str, Any]:
    """Parse JSON from connector output, falling back to an error dict."""
    text = stdout.strip()
    if not text:
        return {"error": f"{fn_name} returned no output", "tool": "unknown"}
    try:
        result = json.loads(text)
        if isinstance(result, dict):
            return result
        return {"result": result}
    except json.JSONDecodeError:
        # Some tools (e.g. ping) return "200\n" — wrap as text result.
        return {"raw": text, "note": "non-JSON output"}


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

def fetch_project(tool: str, project_url_or_id: str) -> dict[str, Any]:
    """Fetch a project (with sections + tasks) in the normalized shape."""
    if tool not in SUPPORTED_TOOLS:
        return {"error": f"unsupported tool: {tool}", "supported": list(SUPPORTED_TOOLS)}
    try:
        out = _run_bash_function(
            f"connect_{tool}_fetch_project", [project_url_or_id]
        )
        return _json_or_error(out, f"connect_{tool}_fetch_project")
    except Exception as e:
        return {"error": str(e), "tool": tool}


def apply_rewrites(
    tool: str, project_id: str, rewrites: list[dict[str, Any]]
) -> dict[str, Any]:
    """Apply task name/note rewrites. Each rewrite: {task_id, name?, notes?}."""
    if tool not in SUPPORTED_TOOLS:
        return {"error": f"unsupported tool: {tool}"}
    payload = json.dumps({"rewrites": rewrites})
    try:
        out = _run_bash_function(
            f"connect_{tool}_apply_changes", [project_id, payload]
        )
        return _json_or_error(out, f"connect_{tool}_apply_changes")
    except Exception as e:
        return {"error": str(e), "tool": tool}


def create_sections(
    tool: str, project_id: str, sections: list[str]
) -> dict[str, Any]:
    """Create new sections (or groups/lists) in the project."""
    if tool not in SUPPORTED_TOOLS:
        return {"error": f"unsupported tool: {tool}"}
    payload = json.dumps({"create_sections": [{"name": s} for s in sections]})
    try:
        out = _run_bash_function(
            f"connect_{tool}_apply_changes", [project_id, payload]
        )
        return _json_or_error(out, f"connect_{tool}_apply_changes")
    except Exception as e:
        return {"error": str(e), "tool": tool}


def move_tasks(tool: str, moves: list[dict[str, Any]]) -> dict[str, Any]:
    """Move tasks to new sections. Each move: {task_id, section_id}."""
    if tool not in SUPPORTED_TOOLS:
        return {"error": f"unsupported tool: {tool}"}
    payload = json.dumps({"moves": moves})
    try:
        out = _run_bash_function(
            f"connect_{tool}_apply_changes", [tool, payload]
        ) if False else None  # placeholder; corrected below
        # The connectors.sh apply function expects (project_id, payload).
        # For "moves" we still need a project context; if caller doesn't pass
        # one, we ask them to include it per-move via "project_id" in each dict.
        normalized = []
        for m in moves:
            mv = dict(m)
            pid = mv.pop("project_id", None) or project_id
            normalized.append({"task_id": mv.get("task_id"), "section_id": mv.get("section_id") or mv.get("status"), "project_id": pid})
        # We need one project_id for the apply call — use the first one.
        first_pid = normalized[0]["project_id"] if normalized else project_id
        payload2 = json.dumps({"moves": normalized})
        out = _run_bash_function(
            f"connect_{tool}_apply_changes", [first_pid, payload2]
        )
        return _json_or_error(out, f"connect_{tool}_apply_changes")
    except Exception as e:
        return {"error": str(e), "tool": tool}


def get_health() -> dict[str, Any]:
    """Return server health + which tools have env vars configured."""
    configured: list[str] = []
    env_map = {
        "asana":   ["ASANA_PAT"],
        "clickup": ["CLICKUP_API_TOKEN"],
        "monday":  ["MONDAY_API_TOKEN"],
        "trello":  ["TRELLO_API_KEY", "TRELLO_API_TOKEN"],
        "notion":  ["NOTION_API_KEY"],
        "jira":    ["JIRA_BASE_URL", "JIRA_EMAIL", "JIRA_API_TOKEN"],
    }
    for tool, keys in env_map.items():
        if all(os.environ.get(k) for k in keys):
            configured.append(tool)
    return {
        "status": "ok",
        "tools_supported": list(SUPPORTED_TOOLS),
        "tools_configured": configured,
        "skill_dir": str(SKILL_DIR),
        "connectors_path": str(CONNECTORS),
    }


# ---------------------------------------------------------------------------
# Manual JSON-RPC stdio fallback (used only if mcp SDK unavailable)
# ---------------------------------------------------------------------------

def _manual_jsonrpc_loop() -> None:
    """
    Minimal MCP-style JSON-RPC stdio loop. Implements just enough to satisfy
    Claude Desktop / Cursor: initialize, tools/list, tools/call.
    """
    tool_specs = [
        {
            "name": "fetch_project",
            "description": "Fetch a project (sections + tasks) from Asana/ClickUp/Monday/Trello/Notion/Jira in a normalized JSON shape.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tool": {"type": "string", "enum": list(SUPPORTED_TOOLS)},
                    "project_url_or_id": {"type": "string"},
                },
                "required": ["tool", "project_url_or_id"],
            },
        },
        {
            "name": "apply_rewrites",
            "description": "Apply task name/note rewrites. Each rewrite: {task_id, name?, notes?}.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tool": {"type": "string", "enum": list(SUPPORTED_TOOLS)},
                    "project_id": {"type": "string"},
                    "rewrites": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id": {"type": "string"},
                                "name":    {"type": "string"},
                                "notes":   {"type": "string"},
                            },
                            "required": ["task_id"],
                        },
                    },
                },
                "required": ["tool", "project_id", "rewrites"],
            },
        },
        {
            "name": "create_sections",
            "description": "Create new sections/lists/groups in a project. Returns section IDs where available.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tool": {"type": "string", "enum": list(SUPPORTED_TOOLS)},
                    "project_id": {"type": "string"},
                    "sections": {"type": "array", "items": {"type": "string"}},
                },
                "required": ["tool", "project_id", "sections"],
            },
        },
        {
            "name": "move_tasks",
            "description": "Move tasks between sections/statuses. Each move: {task_id, section_id}.",
            "inputSchema": {
                "type": "object",
                "properties": {
                    "tool": {"type": "string", "enum": list(SUPPORTED_TOOLS)},
                    "moves": {
                        "type": "array",
                        "items": {
                            "type": "object",
                            "properties": {
                                "task_id":    {"type": "string"},
                                "section_id": {"type": "string"},
                                "project_id": {"type": "string"},
                            },
                            "required": ["task_id", "section_id"],
                        },
                    },
                },
                "required": ["tool", "moves"],
            },
        },
        {
            "name": "get_health",
            "description": "Return server health and which tools have credentials configured.",
            "inputSchema": {"type": "object", "properties": {}},
        },
    ]

    tool_fns = {
        "fetch_project":   lambda a: fetch_project(a["tool"], a["project_url_or_id"]),
        "apply_rewrites":  lambda a: apply_rewrites(a["tool"], a["project_id"], a["rewrites"]),
        "create_sections": lambda a: create_sections(a["tool"], a["project_id"], a["sections"]),
        "move_tasks":      lambda a: move_tasks(a["tool"], a["moves"]),
        "get_health":      lambda a: get_health(),
    }

    def send(msg: dict[str, Any]) -> None:
        sys.stdout.write(json.dumps(msg) + "\n")
        sys.stdout.flush()

    def make_result(req_id: Any, result: Any) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "result": result}

    def make_error(req_id: Any, code: int, message: str) -> dict[str, Any]:
        return {"jsonrpc": "2.0", "id": req_id, "error": {"code": code, "message": message}}

    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            req = json.loads(line)
        except json.JSONDecodeError:
            continue

        method = req.get("method")
        req_id = req.get("id")
        params = req.get("params") or {}

        if method == "initialize":
            send(make_result(req_id, {
                "protocolVersion": "2024-11-05",
                "serverInfo": {"name": "asana-organizer", "version": "0.1.0"},
                "capabilities": {"tools": {}},
            }))
        elif method == "notifications/initialized":
            # No response needed for notifications.
            pass
        elif method == "tools/list":
            send(make_result(req_id, {"tools": tool_specs}))
        elif method == "tools/call":
            tname = params.get("name")
            args = params.get("arguments") or {}
            fn = tool_fns.get(tname)
            if fn is None:
                send(make_error(req_id, -32601, f"unknown tool: {tname}"))
                continue
            try:
                result = fn(args)
                send(make_result(req_id, {
                    "content": [{"type": "json", "data": result}],
                    "isError": False,
                }))
            except Exception as e:
                send(make_result(req_id, {
                    "content": [{"type": "text", "text": f"error: {e}"}],
                    "isError": True,
                }))
        elif method == "ping":
            send(make_result(req_id, {}))
        else:
            if req_id is not None:
                send(make_error(req_id, -32601, f"method not found: {method}"))


# ---------------------------------------------------------------------------
# Official MCP SDK path (FastMCP)
# ---------------------------------------------------------------------------

def _run_fastmcp() -> None:
    """Run the server using the official mcp SDK (FastMCP / stdio)."""
    import mcp.server.stdio
    import mcp.types as types
    from mcp.server.fastmcp import FastMCP

    server = FastMCP("asana-organizer")

    @server.tool(
        name="fetch_project",
        description=(
            "Fetch a project (sections + tasks) from Asana/ClickUp/Monday/Trello/"
            "Notion/Jira in a normalized JSON shape."
        ),
    )
    def _fetch_project(tool: str, project_url_or_id: str) -> dict[str, Any]:
        return fetch_project(tool, project_url_or_id)

    @server.tool(
        name="apply_rewrites",
        description="Apply task name/note rewrites. rewrites=[{task_id, name?, notes?}]",
    )
    def _apply_rewrites(
        tool: str, project_id: str, rewrites: list[dict[str, Any]]
    ) -> dict[str, Any]:
        return apply_rewrites(tool, project_id, rewrites)

    @server.tool(
        name="create_sections",
        description="Create new sections/lists/groups in a project.",
    )
    def _create_sections(
        tool: str, project_id: str, sections: list[str]
    ) -> dict[str, Any]:
        return create_sections(tool, project_id, sections)

    @server.tool(
        name="move_tasks",
        description="Move tasks between sections. moves=[{task_id, section_id, project_id?}]",
    )
    def _move_tasks(tool: str, moves: list[dict[str, Any]]) -> dict[str, Any]:
        return move_tasks(tool, moves)

    @server.tool(
        name="get_health",
        description="Return server health and which tools have credentials configured.",
    )
    def _get_health() -> dict[str, Any]:
        return get_health()

    # FastMCP's stdio transport handles the JSON-RPC loop internally.
    server.run()


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    _ensure_prereqs()

    if "--check" in sys.argv:
        # Health check mode used by scripts/setup.sh.
        h = get_health()
        print(json.dumps(h, indent=2))
        return 0

    # Prefer the official mcp SDK when available; otherwise fall back to the
    # manual JSON-RPC loop (still spec-compatible for Claude Desktop/Cursor).
    try:
        _run_fastmcp()
    except ImportError:
        _manual_jsonrpc_loop()
    except Exception as e:
        # If the SDK is installed but crashes (e.g. version mismatch), fall back.
        sys.stderr.write(f"FastMCP unavailable ({e}); using manual JSON-RPC loop.\n")
        _manual_jsonrpc_loop()
    return 0


if __name__ == "__main__":
    sys.exit(main())