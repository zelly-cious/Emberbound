#!/usr/bin/env python3
"""Generate the Emberbound Milestone 2 Roblox Studio installer (task M2-TOOLS-001).

Reads the 24 Luau sources from the release source commit with git (never from the working
tree). Since the round 4 BigNum adoption that commit is the reviewed candidate 9a988c9. It
verifies them against the round 4 SHA-256 manifest and against Appendices A and B of
M2_STUDIO_REGRESSION_GUIDE.md, then fills tools/m2/InstallM2.template.lua and writes:

    tools/m2/InstallM2.lua             the installer to paste into the Studio Command Bar
    tools/m2/INSTALLER_MANIFEST.txt    SHA-256 of the installer and of every embedded file

Round 4 is recorded in SOURCE_HASHES.txt at HEAD, after the source commit, so the manifest is read
from HEAD. The source commit must be an ancestor of HEAD, and the round 4 heading must name it.

The output is deterministic: no timestamps, LF line endings,
ASCII only. After writing, the generated Lua is re-read and every embedded string is
decoded independently and compared byte for byte with the frozen source.

Usage (from the repository root):
    python3 tools/m2/generate_installer.py           # write the installer and manifest
    python3 tools/m2/generate_installer.py --check   # regenerate in memory; fail if files differ
"""

from __future__ import annotations

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

FROZEN_COMMIT = "9a988c9254e07ac50dcf32fe4b55ba975613390d"  # release source: SOURCE_HASHES.txt round 4
INSTALLER_VERSION = "1.2.0"
MANIFEST_SECTION = "## Round 4"
GUIDE_PATH = "M2_STUDIO_REGRESSION_GUIDE.md"

TOOLS_DIR = Path(__file__).resolve().parent
TEMPLATE_PATH = TOOLS_DIR / "InstallM2.template.lua"
OUTPUT_PATH = TOOLS_DIR / "InstallM2.lua"
MANIFEST_PATH = TOOLS_DIR / "INSTALLER_MANIFEST.txt"

# Appendix A of M2_STUDIO_REGRESSION_GUIDE.md, in its order: (Explorer path, class).
LAYOUT = [
    ("ReplicatedStorage/Shared/BigNum", "ModuleScript"),
    ("ReplicatedStorage/Shared/GameConfig", "ModuleScript"),
    ("ReplicatedStorage/Shared/ProgressionConfig", "ModuleScript"),
    ("ServerScriptService/CombatRules", "ModuleScript"),
    ("ServerScriptService/CombatService", "ModuleScript"),
    ("ServerScriptService/CurrencyService", "ModuleScript"),
    ("ServerScriptService/PlayerSessionService", "ModuleScript"),
    ("ServerScriptService/RateLimiter", "ModuleScript"),
    ("ServerScriptService/ServerInit", "Script"),
    ("ServerScriptService/UpgradeService", "ModuleScript"),
    ("ServerScriptService/Wallet", "ModuleScript"),
    ("ServerScriptService/Tests/BigNumTests", "ModuleScript"),
    ("ServerScriptService/Tests/CombatFormulaTests", "ModuleScript"),
    ("ServerScriptService/Tests/CombatRulesTests", "ModuleScript"),
    ("ServerScriptService/Tests/ProgressionTests", "ModuleScript"),
    ("ServerScriptService/Tests/RateLimiterTests", "ModuleScript"),
    ("ServerScriptService/Tests/TestKit", "ModuleScript"),
    ("ServerScriptService/Tests/TestKitTests", "ModuleScript"),
    ("ServerScriptService/Tests/TestRunner", "Script"),
    ("ServerScriptService/Tests/WalletTests", "ModuleScript"),
    ("StarterPlayer/StarterPlayerScripts/CombatClient", "LocalScript"),
    ("StarterPlayer/StarterPlayerScripts/CombatClient/ArenaView", "ModuleScript"),
    ("StarterPlayer/StarterPlayerScripts/CombatClient/CombatHud", "ModuleScript"),
    ("StarterPlayer/StarterPlayerScripts/CombatClient/UpgradePanel", "ModuleScript"),
]


class GenerationError(Exception):
    pass


def git(repo: Path, *args: str) -> bytes:
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True)
    if result.returncode != 0:
        raise GenerationError(f"git {' '.join(args)} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def repo_file(path: str) -> str:
    """Repository path of an Explorer path, e.g. ServerScriptService/Wallet -> src/ServerScriptService/Wallet.luau."""
    return f"src/{path}.luau"


def normalize(data: bytes) -> bytes:
    """The Appendix B checker's normalization: CRLF -> LF, strip trailing whitespace, one final LF."""
    return data.replace(b"\r\n", b"\n").rstrip(b" \t\n\r\x0b\x0c") + b"\n"


def adler32(data: bytes) -> int:
    """Same loop as the Appendix B checker (equal to zlib.adler32)."""
    a, b = 1, 0
    for byte in data:
        a = (a + byte) % 65521
        b = (b + a) % 65521
    return b * 65536 + a


def lua_escape(data: bytes) -> str:
    """Escape bytes as the body of a double-quoted Lua string: ASCII output only, no raw newlines or tabs."""
    out = []
    for byte in data:
        if byte == 0x0A:
            out.append("\\n")
        elif byte == 0x09:
            out.append("\\t")
        elif byte == 0x22:
            out.append('\\"')
        elif byte == 0x5C:
            out.append("\\\\")
        elif 0x20 <= byte <= 0x7E:
            out.append(chr(byte))
        else:
            out.append(f"\\{byte:03d}")  # always three digits, so a following digit is never absorbed
    return "".join(out)


def lua_unescape(body: str) -> bytes:
    """Independent decoder for the escapes lua_escape produces (and plain Lua 5.1/Luau rules for them)."""
    out = bytearray()
    i = 0
    simple = {"n": 0x0A, "t": 0x09, '"': 0x22, "\\": 0x5C, "'": 0x27, "r": 0x0D, "a": 0x07, "b": 0x08, "f": 0x0C, "v": 0x0B}
    while i < len(body):
        ch = body[i]
        if ch != "\\":
            if ch in "\r\n" or ord(ch) > 0x7E:
                raise GenerationError(f"raw control or non-ASCII character in a string literal at offset {i}")
            out.append(ord(ch))
            i += 1
            continue
        nxt = body[i + 1]
        if nxt in simple:
            out.append(simple[nxt])
            i += 2
        elif nxt.isdigit():
            digits = re.match(r"\d{1,3}", body[i + 1 :]).group(0)
            value = int(digits)
            if value > 255:
                raise GenerationError("decimal escape above 255")
            out.append(value)
            i += 1 + len(digits)
        else:
            raise GenerationError(f"unsupported escape \\{nxt}")
    return bytes(out)


def read_manifest(repo: Path) -> dict[str, str]:
    if subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", FROZEN_COMMIT, "HEAD"]).returncode != 0:
        raise GenerationError(f"the source commit {FROZEN_COMMIT} is not an ancestor of HEAD")
    text = git(repo, "show", "HEAD:SOURCE_HASHES.txt").decode()
    lines = text.splitlines()
    starts = [i for i, line in enumerate(lines) if line.startswith(MANIFEST_SECTION)]
    if len(starts) != 1:
        raise GenerationError(f"SOURCE_HASHES.txt at HEAD must have exactly one '{MANIFEST_SECTION}' section")
    start = starts[0]
    if FROZEN_COMMIT[:7] not in lines[start] or "current" not in lines[start]:
        raise GenerationError(f"the '{MANIFEST_SECTION}' heading must name the source commit {FROZEN_COMMIT[:7]} and be marked current")
    manifest: dict[str, str] = {}
    for line in lines[start + 1 :]:
        if line.startswith("## "):
            break
        match = re.fullmatch(r"([0-9a-f]{64})  (src/\S+)", line.strip())
        if match:
            if match.group(2) in manifest:
                raise GenerationError(f"duplicate manifest entry {match.group(2)}")
            manifest[match.group(2)] = match.group(1)
    return manifest


def check_guide(repo: Path, files: list[dict]) -> None:
    """Cross-check Appendices A and B of the committed regression guide against the computed values."""
    guide = git(repo, "show", f"HEAD:{GUIDE_PATH}").decode()
    if FROZEN_COMMIT not in guide:
        raise GenerationError(f"{GUIDE_PATH} at HEAD is not pinned to the frozen commit")
    entries = re.findall(r'\{ "([^"]+)", "(\w+)", (\d+), (\d+), (\d+) \}', guide)
    computed = [(f["path"], f["className"], str(f["bytes"]), str(f["lines"]), str(f["adler32"])) for f in files]
    if entries != computed:
        raise GenerationError("Appendix B checker table does not match the frozen sources")
    rows = re.findall(r"^\| (\d+) \| ([^|]+) \| `(\w+)` \| \*\*(\w+)\*\* \| \[`(src/[^`]+)`\]", guide, re.M)
    expected_rows = []
    for index, f in enumerate(files, 1):
        parent, name = f["path"].rsplit("/", 1)
        expected_rows.append((str(index), parent.replace("/", " > "), name, f["className"], repo_file(f["path"])))
    if [(r[0], r[1].strip(), r[2], r[3], r[4]) for r in rows] != expected_rows:
        raise GenerationError("Appendix A table does not match the installer layout")
    shas = re.findall(r"^\| \d+ \| `(\w+)` \| \d+ \| \d+ \| \d+ \| `([0-9a-f]{64})` \|", guide, re.M)
    if shas != [(f["path"].rsplit("/", 1)[1], f["sha256"]) for f in files]:
        raise GenerationError("Appendix A SHA-256 table does not match the manifest")


def load_sources(repo: Path) -> list[dict]:
    resolved = git(repo, "rev-parse", "--verify", f"{FROZEN_COMMIT}^{{commit}}").decode().strip()
    if resolved != FROZEN_COMMIT:
        raise GenerationError(f"frozen commit resolved to {resolved}")
    tree = sorted(git(repo, "ls-tree", "-r", "--name-only", FROZEN_COMMIT, "src").decode().split())
    expected_tree = sorted(repo_file(path) for path, _ in LAYOUT)
    if len(LAYOUT) != 24 or len(set(p for p, _ in LAYOUT)) != 24:
        raise GenerationError("layout must list 24 distinct files")
    if tree != expected_tree:
        raise GenerationError(f"src/ at the frozen commit holds {len(tree)} files that do not match the 24 expected files")
    manifest = read_manifest(repo)
    if sorted(manifest) != expected_tree:
        raise GenerationError("the round 4 manifest does not list exactly the 24 expected files")
    files = []
    for path, class_name in LAYOUT:
        data = git(repo, "cat-file", "blob", f"{FROZEN_COMMIT}:{repo_file(path)}")
        sha = hashlib.sha256(data).hexdigest()
        if sha != manifest[repo_file(path)]:
            raise GenerationError(f"{repo_file(path)}: SHA-256 {sha} does not match the manifest")
        if normalize(data) != data:
            raise GenerationError(f"{repo_file(path)} is not in normalized form; refusing to alter the source")
        files.append(
            {
                "path": path,
                "className": class_name,
                "data": data,
                "sha256": sha,
                "bytes": len(data),
                "lines": data.count(b"\n"),
                "adler32": adler32(data),
            }
        )
    counts = {c: sum(1 for f in files if f["className"] == c) for c in ("Script", "LocalScript", "ModuleScript")}
    if counts != {"Script": 2, "LocalScript": 1, "ModuleScript": 21}:
        raise GenerationError(f"unexpected class counts {counts}")
    return files


def render(template: str, files: list[dict]) -> str:
    layout = "\n".join(f'\t{{ path = "{f["path"]}", className = "{f["className"]}" }},' for f in files)
    blocks = []
    for index, f in enumerate(files, 1):
        lines = f["data"].split(b"\n")[:-1]  # data ends with exactly one LF
        text = "\n".join(f'\t\t"{lua_escape(line + b"\n")}",' for line in lines)
        blocks.append(
            f"FILES[{index}] = {{\n"
            f'\tpath = "{f["path"]}",\n'
            f'\tclassName = "{f["className"]}",\n'
            f"\tbytes = {f['bytes']},\n"
            f"\tlines = {f['lines']},\n"
            f"\tadler32 = {f['adler32']},\n"
            f'\tsha256 = "{f["sha256"]}",\n'
            f"\ttext = {{\n{text}\n\t}},\n"
            f"}}"
        )
    values = {
        "INSTALLER_VERSION": INSTALLER_VERSION,
        "FROZEN_COMMIT": FROZEN_COMMIT,
        "FILE_COUNT": str(len(files)),
        "LAYOUT": layout,
        "FILES": "\n".join(blocks),
    }
    output = template
    for key, value in values.items():
        placeholder = "{{" + key + "}}"
        if placeholder not in output:
            raise GenerationError(f"template is missing {placeholder}")
        output = output.replace(placeholder, value)
    if re.search(r"\{\{[A-Z_]+\}\}", output):
        raise GenerationError("unfilled placeholder in template")
    return output


def lex_check(lua: str) -> list[bytes]:
    """Scan the generated Lua: every comment must be a --[[ ]] block, no statement line may start
    with '(', no raw control characters; returns the decoded bodies of all double-quoted strings."""
    strings = []
    i, n = 0, len(lua)
    while i < n:
        ch = lua[i]
        if ch == "-" and lua.startswith("--", i):
            if not lua.startswith("--[[", i):
                line = lua.count("\n", 0, i) + 1
                raise GenerationError(f"line comment at line {line}: only --[[ ]] block comments survive joined lines")
            end = lua.find("]]", i + 4)
            if end < 0:
                raise GenerationError("unterminated block comment")
            i = end + 2
        elif ch == '"':
            j = i + 1
            while lua[j] != '"':
                if lua[j] == "\\":
                    j += 2
                elif lua[j] == "\n":
                    raise GenerationError("raw newline inside a string literal")
                else:
                    j += 1
            strings.append(lua_unescape(lua[i + 1 : j]))
            i = j + 1
        elif ch == "'" or lua.startswith("[[", i) or lua.startswith("[=", i):
            line = lua.count("\n", 0, i) + 1
            raise GenerationError(f"single-quoted or long-bracket string at line {line}; the installer uses double quotes only")
        else:
            i += 1
    for number, line in enumerate(lua.split("\n"), 1):
        if line.lstrip().startswith("("):
            raise GenerationError(f"line {number} starts with '(' (ambiguous if lines are joined)")
    if not lua.isascii() or "\r" in lua:
        raise GenerationError("installer must be ASCII-only with LF line endings")
    return strings


def verify_output(lua: str, files: list[dict]) -> None:
    """Independently rebuild every embedded file from the generated text and compare."""
    lex_check(lua)
    for index, f in enumerate(files, 1):
        start = lua.index(f"FILES[{index}] = {{\n")
        end = lua.index("\n}", start)
        block = lua[start:end]
        header = re.search(
            r'path = "([^"]+)",\n\tclassName = "(\w+)",\n\tbytes = (\d+),\n\tlines = (\d+),\n\tadler32 = (\d+),\n\tsha256 = "([0-9a-f]{64})",\n\ttext = \{\n',
            block,
        )
        if header is None:
            raise GenerationError(f"FILES[{index}] header not found")
        if header.groups() != (f["path"], f["className"], str(f["bytes"]), str(f["lines"]), str(f["adler32"]), f["sha256"]):
            raise GenerationError(f"FILES[{index}] header differs from the frozen source")
        body = block[header.end() :]
        literals = re.findall(r'^\t\t"((?:[^"\\]|\\.)*)",$', body, re.M)
        rebuilt = b"".join(lua_unescape(s) for s in literals)
        if rebuilt != f["data"] or hashlib.sha256(rebuilt).hexdigest() != f["sha256"]:
            raise GenerationError(f"FILES[{index}] ({f['path']}) does not rebuild to the frozen bytes")
        if adler32(normalize(rebuilt)) != f["adler32"]:
            raise GenerationError(f"FILES[{index}] Adler-32 mismatch")
    if lua.count("\nFILES[") != len(files):
        raise GenerationError("unexpected number of FILES entries")


def render_manifest(lua: str, files: list[dict]) -> str:
    data = lua.encode("ascii")
    lines = [
        "# Emberbound M2 installer manifest (generated by tools/m2/generate_installer.py; do not edit)",
        "",
        f"installer_version {INSTALLER_VERSION}",
        f"frozen_commit {FROZEN_COMMIT}",
        f"installer_file tools/m2/InstallM2.lua",
        f"installer_bytes {len(data)}",
        f"installer_sha256 {hashlib.sha256(data).hexdigest()}",
        "",
        "# Embedded files: sha256, bytes, lines, adler32, class, Explorer path",
    ]
    for f in files:
        lines.append(f"{f['sha256']}  {f['bytes']}  {f['lines']}  {f['adler32']}  {f['className']}  {f['path']}")
    return "\n".join(lines) + "\n"


def build(repo: Path) -> tuple[str, str, list[dict]]:
    files = load_sources(repo)
    check_guide(repo, files)
    template = TEMPLATE_PATH.read_text(encoding="ascii")
    lua = render(template, files)
    verify_output(lua, files)
    return lua, render_manifest(lua, files), files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="regenerate in memory and compare with the committed files")
    args = parser.parse_args()
    repo = Path(git(TOOLS_DIR, "rev-parse", "--show-toplevel").decode().strip())
    try:
        lua, manifest, files = build(repo)
    except GenerationError as error:
        print(f"GENERATION FAILED: {error}", file=sys.stderr)
        return 1
    if args.check:
        same = OUTPUT_PATH.exists() and OUTPUT_PATH.read_bytes() == lua.encode("ascii")
        same_manifest = MANIFEST_PATH.exists() and MANIFEST_PATH.read_bytes() == manifest.encode("ascii")
        print(f"installer {'matches' if same else 'DIFFERS FROM'} a fresh generation")
        print(f"manifest {'matches' if same_manifest else 'DIFFERS FROM'} a fresh generation")
        return 0 if same and same_manifest else 1
    OUTPUT_PATH.write_bytes(lua.encode("ascii"))
    MANIFEST_PATH.write_bytes(manifest.encode("ascii"))
    data = lua.encode("ascii")
    print(f"source commit {FROZEN_COMMIT}: {len(files)} files, all SHA-256 match SOURCE_HASHES.txt round 4 (at HEAD)")
    print("Appendix A and B of the regression guide match the computed values")
    print(f"wrote {OUTPUT_PATH.relative_to(repo)} ({len(data)} bytes, sha256 {hashlib.sha256(data).hexdigest()})")
    print(f"wrote {MANIFEST_PATH.relative_to(repo)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
