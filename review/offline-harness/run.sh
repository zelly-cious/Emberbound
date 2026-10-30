#!/usr/bin/env bash
# Offline review harness for Emberbound (NOT part of the game; never install it in Studio).
#
# Bundles the server-side ModuleScripts from src/ with a minimal fake Roblox engine
# (roblox_shim.luau) and an entry script, then runs the bundle with the Luau CLI.
# Client scripts (StarterPlayer) are not executed: they need real GUI/camera APIs.
#
# Usage:  review/offline-harness/run.sh unit   [path/to/luau]   # runs the shipped TestRunner (48 tests)
#         review/offline-harness/run.sh probes [path/to/luau]   # runs the extra review probes
# The Luau CLI comes from https://github.com/luau-lang/luau/releases (luau / luau.exe).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
MODE="${1:?usage: run.sh unit|probes [path/to/luau]}"
LUAU="${2:-${LUAU:-luau}}"
M1_BASELINE="730218a" # verified Milestone 1 baseline, used only for formula-compatibility probes

case "$MODE" in
	unit | probes) ;;
	*) echo "unknown mode: $MODE (expected unit or probes)" >&2; exit 2 ;;
esac

OUT_DIR="$(mktemp -d)"
OUT="$OUT_DIR/bundle_$MODE.luau"

{
	echo "local SOURCES = {}"
	# Each source is embedded verbatim; the newline after the opening bracket is skipped by Luau,
	# so error messages report the original file name and line numbers.
	for f in $(cd "$ROOT/src" && find ReplicatedStorage ServerScriptService -name '*.luau' | sort); do
		printf 'SOURCES["%s"] = [==========[\n' "${f%.luau}"
		tr -d '\r' < "$ROOT/src/$f"
		printf ']==========]\n'
	done
	if git -C "$ROOT" cat-file -e "$M1_BASELINE^{commit}" 2>/dev/null; then
		printf 'SOURCES["M1/ReplicatedStorage/Shared/GameConfig"] = [==========[\n'
		git -C "$ROOT" show "$M1_BASELINE:src/ReplicatedStorage/Shared/GameConfig.luau" | tr -d '\r'
		printf ']==========]\n'
	fi
	tr -d '\r' < "$HERE/roblox_shim.luau"
	tr -d '\r' < "$HERE/$MODE.luau"
} > "$OUT"

"$LUAU" "$OUT"
