# Codex re-review prompt: M2-STUDIO-001 / DEFECT-001B candidate

Paste the block below into Codex. It is a **read-only** review. Do not edit, commit, push or merge.

---

You are reviewing a candidate correction on branch `candidate/m2-defect-001-ftz-subnormal` of `zelly-cious/Emberbound`.
- The head is the commit that adds `review/DEFECT-001B_REPORT.md`; its parent is `8626bc70ff905975fbc8069b4f951762f15cdefd`.
- The frozen Milestone 2 source is `e9d878d94155610558c9c6252d76f202dfd956b4`. It and `SOURCE_HASHES.txt` round 3 must stay unchanged.

Read `AGENTS.md`, then `review/DEFECT-001B_REPORT.md`, then `review/DEFECT-001_REPORT.md` (section 7 for the limitations).

**Studio evidence** (owner-reported, Edit mode, Luau 0.745.0.7451137):
- FTZ is on, with no DAZ.
- The frozen division rebuilds 5e-324 as zero.
- `string.format("%.17g", 5e-324)` returns `"0"`.
- `tostring(5e-324)` returns `"5e-324"`, which round-trips.
- `BigNum.parse(BigNum.toString(tiny)) == tiny` is false.

The Server Play-mode diagnostic has not been supplied. The candidate has not run in Studio.

**Scope of the diff:** `git diff 8626bc7 HEAD -- src` (also `git diff e9d878d HEAD -- src`).
- `src/ReplicatedStorage/Shared/BigNum.luau`:
  - new `MIN_NORMAL` constant;
  - `BigNum.toString` uses `tostring(m)` only when `e == 0 and 0 < m < MIN_NORMAL`;
  - the header and function comments.
- `src/ServerScriptService/Tests/BigNumTests.luau`:
  - additions only, compared with `e9d878d`;
  - the two DEFECT-001 tests moved after the original list and retyped;
  - four new tests;
  - fixtures built from IEEE-754 bits via `buffer`.

**Verify, citing file, function and line:**
1. Lines 364 and 374 of `BigNumTests.luau` are byte-identical to `e9d878d`, at the same line numbers. No acceptance assertion was skipped, removed, relaxed or rewritten to accept zero.
2. `BigNum.toString` output is byte-identical to `e9d878d` for zero, every normal small value and every large value. Only positive subnormals change.
   - `parse`, `eq`, `isValid`, the representation and the network contract are unchanged.
   - The DEFECT-001 change in `multiplyByPowerOfTen` is unchanged from `8626bc7`.
3. `parse(toString(x))` equals x, and `toString(parse(toString(x))) == toString(x)`, for every positive subnormal. Consider:
   - Luau's `tostring` format (`lnumprint.cpp`, shortest round trip, scientific form with `e-`);
   - the `parse` patterns `^(%d+%.?%d*)[eE]([%+%-]?%d+)$` and `MAX_TEXT_LENGTH`;
   - the one-step `tonumber(text)` path.

   Genuine underflow must still read as zero.
4. Test design:
   - The subnormal fixtures avoid FP arithmetic: `buffer.writeu32` and `readf64`, little-endian. Check the bit patterns in the report's fixture table.
   - The new serialization tests are independent of the arithmetic tests.
   - A DAZ host fails loudly instead of passing on zeros.
5. Typing: the typed records `DivisionCase`, `UnderflowCase` and `SerializationFixture`, `back :: BigNum`, `table.insert(tests, …)` against `{ TestKit.TestCase }`, and the multi-line if-expression.
6. **Run what this candidate could not** (its author's environment blocked the Luau binaries):
   1. `luau-compile` on both files;
   2. `luau-analyze src/ReplicatedStorage/Shared/BigNum.luau`;
   3. a strict analysis of `BigNumTests.luau` with Roblox definitions, or report why you could not.

   Report analyzer failures verbatim.
7. **Offline harness.** Re-run `review/ftz-harness` if you can: `run_matrix.py --modes gradual,ftz,ftz-winfmt,winfmt` for the work tree, `e9d878d` and `8626bc7`; the `--override` negative controls; `differential.py`. Compare with `review/DEFECT-001B_OFFLINE_RESULTS.txt`.
   - Expected: candidate 67/67 and 75/75 probes in every mode; prior candidate 1 failure at line 374 under `ftz-winfmt`; frozen 1 failure at line 364.
   - Better still, run the real Luau 0.745 CLI harness (`review/offline-harness`). Model the formatter by wrapping `string.format`, as `prelude.lua` does.
8. **Model validity.** Is the formatter model (subnormal `e/f/g` arguments print as 0) a sound basis, given that the evidence is one observed value? Name any Studio observation that would invalidate the fix. In particular: what if `%.17g` also misprints small *normal* values, or `tostring`/`tonumber` misbehave for other subnormals? Probe v2 (`review/ftz-harness/studio_probe.lua`) is meant to settle these. Check that it is read-only, and that its display no longer depends on `%.17g`.
9. **Remaining limitations** (report section 10): confirm they are stated accurately. That includes the native fast paths that still flush under FTZ; the candidate does not claim universal subnormal support.

**Classify findings** as:
- confirmed code defects;
- risks that need Roblox Studio tests;
- optional improvements.

Give each a severity (Critical, High, Medium or Low), the evidence, a minimal trigger and the least disruptive fix. Do not fabricate Studio or engine output.

End with one of:
- PASS: ready for Studio validation in a disposable copy;
- PASS WITH RISKS;
- FAIL: return to the author.

Do not approve merging, update manifests or parity tables, or mark Milestone 2 complete.
