#!/usr/bin/env python3
"""Minimal stdio LSP smoke test for openprompt-lsp."""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LSP = Path(__file__).resolve().parents[1] / "zig-out" / "bin" / "openprompt-lsp"
SAMPLE = ROOT / "tree-sitter" / "examples" / "basic.op"


def send(proc: subprocess.Popen[bytes], payload: dict) -> None:
    body = json.dumps(payload, separators=(",", ":"))
    message = f"Content-Length: {len(body)}\r\n\r\n{body}"
    assert proc.stdin is not None
    proc.stdin.write(message.encode())
    proc.stdin.flush()


def read_message(proc: subprocess.Popen[bytes]) -> dict:
    assert proc.stdout is not None
    headers = b""
    while b"\r\n\r\n" not in headers:
        chunk = proc.stdout.read(1)
        if not chunk:
            raise RuntimeError("server closed stdout before response")
        headers += chunk
    length = int(headers.decode().split("Content-Length:")[1].split("\r\n")[0].strip())
    body = proc.stdout.read(length)
    return json.loads(body)


def main() -> int:
    if not LSP.is_file():
        print(f"Build the server first: {LSP}", file=sys.stderr)
        return 1
    if not SAMPLE.is_file():
        print(f"Missing sample file: {SAMPLE}", file=sys.stderr)
        return 1

    text = SAMPLE.read_text()
    uri = SAMPLE.as_uri()

    proc = subprocess.Popen(
        [str(LSP)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )

    try:
        send(proc, {
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "processId": 4242,
                "rootUri": ROOT.as_uri(),
                "capabilities": {},
                "clientInfo": {"name": "lsp_smoke", "version": "1.0"},
            },
        })
        init = read_message(proc)
        assert init.get("result", {}).get("serverInfo", {}).get("name") == "openprompt-lsp"
        print("initialize: ok")

        send(proc, {"jsonrpc": "2.0", "method": "initialized", "params": {}})
        send(proc, {
            "jsonrpc": "2.0",
            "method": "textDocument/didOpen",
            "params": {
                "textDocument": {
                    "uri": uri,
                    "languageId": "openprompt",
                    "version": 1,
                    "text": text,
                }
            },
        })

        send(proc, {
            "jsonrpc": "2.0",
            "id": 2,
            "method": "textDocument/semanticTokens/full",
            "params": {"textDocument": {"uri": uri}},
        })
        send(proc, {
            "jsonrpc": "2.0",
            "id": 3,
            "method": "textDocument/hover",
            "params": {
                "textDocument": {"uri": uri},
                "position": {"line": 7, "character": 10},
            },
        })

        send(proc, {
            "jsonrpc": "2.0",
            "id": 4,
            "method": "textDocument/completion",
            "params": {
                "textDocument": {"uri": uri},
                "position": {"line": 3, "character": 16},
            },
        })
        send(proc, {
            "jsonrpc": "2.0",
            "id": 5,
            "method": "textDocument/completion",
            "params": {
                "textDocument": {"uri": uri},
                "position": {"line": 14, "character": 16},
            },
        })
        property_text = text.replace("Test {{$prompts[]}}", "Test {{ $prompts. }}")
        send(proc, {
            "jsonrpc": "2.0",
            "method": "textDocument/didChange",
            "params": {
                "textDocument": {"uri": uri, "version": 2},
                "contentChanges": [{"text": property_text}],
            },
        })
        send(proc, {
            "jsonrpc": "2.0",
            "id": 6,
            "method": "textDocument/completion",
            "params": {
                "textDocument": {"uri": uri},
                "position": {"line": 14, "character": 17},
            },
        })

        responses: dict[int, dict] = {}
        for expected_id in (2, 3, 4, 5, 6):
            while True:
                msg = read_message(proc)
                if msg.get("id") == expected_id:
                    responses[expected_id] = msg
                    print(f"request {expected_id}: ok")
                    break

        use_labels = {item["label"] for item in responses[4].get("result", [])}
        if not any("common.op" in label for label in use_labels):
            print("use-path completion missing common.op:", use_labels, file=sys.stderr)
            return 1
        print("use-path completion: ok")

        prompt_labels = {item["label"] for item in responses[5].get("result", [])}
        if "example" not in prompt_labels:
            print("prompt selection completion missing example:", prompt_labels, file=sys.stderr)
            return 1
        print("prompt selection completion: ok")

        property_labels = {item["label"] for item in responses[6].get("result", [])}
        if "example" not in property_labels:
            print("property completion missing example:", property_labels, file=sys.stderr)
            return 1
        print("property completion: ok")

        if proc.poll() is not None:
            stderr = proc.stderr.read().decode() if proc.stderr else ""
            print("server crashed:", stderr, file=sys.stderr)
            return 1

        print("smoke test passed")
        return 0
    finally:
        if proc.poll() is None:
            proc.terminate()
            proc.wait(timeout=2)


if __name__ == "__main__":
    raise SystemExit(main())
