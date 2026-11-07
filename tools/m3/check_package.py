#!/usr/bin/env python3
"""Check the pinned M3 package and execute its installer/verifier in the fake engine.

Requires Python 3.10+ and Lua 5.1 (lua5.1 on PATH). This is offline evidence.
"""
from __future__ import annotations

import importlib.util
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import generate_package as gen

spec = importlib.util.spec_from_file_location("historical_checker", HERE.parent / "m2/tests/check_release_package.py")
old = importlib.util.module_from_spec(spec)
spec.loader.exec_module(old)


def main() -> None:
    outputs = gen.build()
    assert outputs == gen.build(), "generation is not deterministic"
    for path, data in outputs.items():
        assert path.read_bytes() == data, f"stale package: {path}"
    files = gen.load_sources()
    assert {f["path"]: f["data"] for f in files} == {
        f["path"]: (gen.REPO / f"src/{f['path']}.luau").read_text(encoding="utf-8").encode() for f in files
    }, "working source differs from the pin"
    print("PASS deterministic package, independent payload decoding, and 34 pinned source files")

    # Preserve the adversarial cases; adapt the counts, prefix and capped conflict report.
    cases = (HERE.parent / "m2/tests/installer_tests.lua").read_text()
    cases = re.sub(r"\b24\b", "34", cases)
    cases = re.sub(r"\b33\b", "43", cases).replace("[M2 Installer]", "[M3 Installer]")
    cases = cases.replace("The embedded payload has 23 files", "The embedded payload has 33 files")
    containers = ("ReplicatedStorage", "ServerScriptService", "StarterPlayer/StarterPlayerScripts")
    paths = [f["path"] for f in files] + ["ReplicatedStorage/Shared", "ReplicatedStorage/Remotes", "ServerScriptService/Tests"]
    reserved = {(c, p[len(c) + 1:].split("/")[0]) for c in containers for p in paths if p.startswith(c + "/")}
    # With more modules the first 15 details are all named-object collisions. Verify that
    # the total also counts every existing script rather than requiring a hidden detail.
    cases = cases.replace('has(world, "Existing script")',
                          f'has(world, "Existing objects: {len(reserved) + len(files)} conflict(s).")')
    with tempfile.TemporaryDirectory() as temp:
        tmp = Path(temp)
        (tmp / "installer_tests.lua").write_text(cases)
        shutil.copyfile(HERE.parent / "m2/tests/mock_roblox.lua", tmp / "mock_roblox.lua")
        (tmp / "layout.txt").write_text("".join(f"{f['path']}\t{f['className']}\n" for f in files))
        for index, file in enumerate(files, 1):
            (tmp / f"{index:02d}.luau").write_bytes(file["data"])
        dump = tmp / "installed.dump"
        result = subprocess.run(["lua5.1", str(tmp / "installer_tests.lua"), str(HERE / "InstallM3.lua"),
                                 str(tmp), str(dump)], capture_output=True, text=True, timeout=45)
        output = result.stdout + result.stderr
        summary = re.search(r"\[installer tests\] (\d+) passed, (\d+) failed, (\d+) declared", output)
        if result.returncode != 0 or not summary or summary.group(2) != "0" or summary.group(1) != summary.group(3):
            raise AssertionError(output)
        print("PASS", summary.group(0))
        installed = {}
        installed_files = []
        for row in dump.read_text().splitlines():
            parts = row.split("\t")
            if parts[0] == "SCRIPT":
                _, path, kind, enabled, context, payload = parts
                assert enabled == ("-" if kind == "ModuleScript" else "true")
                assert context == ("Enum.RunContext.Legacy" if kind == "Script" else "-")
                installed[path] = bytes.fromhex(payload).decode()
                installed_files.append(dict(path=path, className=kind))
        assert installed == {f["path"]: f["data"].decode() for f in files}, "installed source differs"
        # Parent scripts must precede their child modules in the fake place.
        installed_files.sort(key=lambda f: f["path"])
        snippet = (HERE / "VerifyM3.lua").read_text()
        code, output = old.run_checker(snippet, installed, installed_files)
        assert code == 0 and "[Parity] RESULT: PASS" in output, output
        assert "scripts matching: 34 / 34, remotes: 6 / 6, extra scripts: 0" in output, output
        print("PASS real VerifyM3 text on installed source: 34/34, 6 remotes, 0 extras")

        changed = dict(installed)
        changed[files[0]["path"]] += "-- changed\n"
        code, output = old.run_checker(snippet, changed, installed_files)
        assert code == 0 and "[Parity] RESULT: FAIL" in output and "content differs" in output, output
        print("PASS changed-source negative control")

        # Extra disabled scripts still fail parity. They are not shipped in the release place.
        changed = dict(installed, **{"ServerScriptService/EmberboundStatQA": "-- helper\n"})
        extra_files = installed_files + [dict(path="ServerScriptService/EmberboundStatQA", className="Script")]
        negative = snippet.replace("local E = {", 'game:GetService("ServerScriptService"):FindFirstChild("EmberboundStatQA").Enabled = false\nlocal E = {', 1)
        code, output = old.run_checker(negative, changed, extra_files)
        assert code == 0 and "[Parity] RESULT: FAIL" in output and "extra scripts: 1" in output, output
        print("PASS disabled-helper negative control")

    # The default arguments leave the frozen M2 installer exactly reproducible.
    historical = gen.base.git(gen.REPO, "show", f"{gen.HISTORICAL_RELEASE}:tools/m2/InstallM2.lua").decode()
    old_files = []
    for path, kind in gen.base.LAYOUT:
        data = gen.base.git(gen.REPO, "show", f"{gen.base.FROZEN_COMMIT}:src/{path}.luau")
        import hashlib
        old_files.append(dict(path=path, className=kind, data=data, sha256=hashlib.sha256(data).hexdigest(),
                              bytes=len(data), lines=data.count(b"\n"), adler32=gen.base.adler32(data)))
    assert gen.base.render((HERE.parent / "m2/InstallM2.template.lua").read_text(), old_files) == historical
    print("PASS frozen M2 installer remains byte-identical")


if __name__ == "__main__":
    main()
