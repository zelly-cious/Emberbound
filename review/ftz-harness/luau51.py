#!/usr/bin/env python3
"""Translate the Luau used by Emberbound into plain Lua 5.1 (review tooling only, not game code).

Purpose: run the shipped unit tests and the offline review probes under a plain Lua 5.1
interpreter, so the CPU's floating-point mode (gradual underflow vs flush-to-zero) can be
controlled with an LD_PRELOAD helper. Numbers are C doubles in both Luau and Lua 5.1, so the
arithmetic is the same machine arithmetic; only the syntax is translated:

  - type aliases (`type` / `export type`), `::` casts, parameter / return / local / for-variable
    annotations and generic parameter lists are removed;
  - `if c then a else b` expressions become `(c and {a} or {b})[1]` (lazy, single value);
  - backtick strings become concatenations through __tostr (Luau's tostring);
  - compound assignments (`x += e`) become `x = x + (e)`;
  - generalized iteration (`for k, v in t do`) goes through __iter.

It is a translator for this code base, not for all of Luau. It refuses constructs it does not
handle (continue, //, attributes) instead of guessing. Whether the translation is faithful is
checked by the harness itself: with gradual underflow it must reproduce the known Luau results
(61/61 unit tests, all review probes), and with flush-to-zero the reported Studio result.
"""

from __future__ import annotations

import re
import sys

KEYWORDS = {
    "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "if", "in",
    "local", "nil", "not", "or", "repeat", "return", "then", "true", "until", "while",
}
OPS = ["...", "..=", "//=", "..", "==", "~=", "<=", ">=", "->", "::", "+=", "-=", "*=", "/=", "%=", "^=", "//"]
COMPOUND = {"+=": "+", "-=": "-", "*=": "*", "/=": "/", "%=": "%", "^=": "^", "..=": ".."}
OPEN, CLOSE = "([{", ")]}"


class Tok:
    __slots__ = ("kind", "text")

    def __init__(self, kind: str, text: str):
        self.kind = kind
        self.text = text

    def __repr__(self) -> str:
        return f"{self.kind}:{self.text!r}"


class TranslateError(Exception):
    pass


def long_bracket_end(src: str, i: int) -> int | None:
    """If src[i] starts a long bracket [=*[, return the index just after its closing bracket."""
    m = re.match(r"\[(=*)\[", src[i:])
    if not m:
        return None
    close = "]" + m.group(1) + "]"
    end = src.find(close, i + len(m.group(0)))
    if end < 0:
        raise TranslateError("unterminated long bracket")
    return end + len(close)


def scan_backtick(src: str, i: int) -> int:
    """Index just after the backtick string starting at src[i] (handles {expr} nesting)."""
    j = i + 1
    while j < len(src):
        c = src[j]
        if c == "\\":
            j += 2
        elif c == "`":
            return j + 1
        elif c == "{":
            j = scan_braced_expr(src, j)
        else:
            j += 1
    raise TranslateError("unterminated backtick string")


def scan_braced_expr(src: str, i: int) -> int:
    """src[i] == '{'; return the index just after the matching '}' (skipping strings)."""
    depth, j = 0, i
    while j < len(src):
        c = src[j]
        if c in "\"'":
            j = scan_quoted(src, j)
            continue
        if c == "`":
            j = scan_backtick(src, j)
            continue
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                return j + 1
        j += 1
    raise TranslateError("unterminated interpolation")


def scan_quoted(src: str, i: int) -> int:
    quote, j = src[i], i + 1
    while j < len(src):
        if src[j] == "\\":
            j += 2
        elif src[j] == quote:
            return j + 1
        elif src[j] == "\n":
            raise TranslateError("newline in string")
        else:
            j += 1
    raise TranslateError("unterminated string")


def tokenize(src: str) -> list[Tok]:
    toks: list[Tok] = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "\n":
            toks.append(Tok("nl", c))
            i += 1
        elif c in " \t\r":
            j = i
            while j < n and src[j] in " \t\r":
                j += 1
            toks.append(Tok("ws", src[i:j]))
            i = j
        elif src.startswith("--", i):
            end = long_bracket_end(src, i + 2)
            if end is None:
                end = src.find("\n", i)
                end = n if end < 0 else end
            toks.append(Tok("comment", src[i:end]))
            i = end
        elif c in "\"'":
            j = scan_quoted(src, i)
            toks.append(Tok("string", src[i:j]))
            i = j
        elif c == "`":
            j = scan_backtick(src, i)
            toks.append(Tok("interp", src[i:j]))
            i = j
        elif c == "[" and long_bracket_end(src, i) is not None:
            j = long_bracket_end(src, i)
            toks.append(Tok("string", src[i:j]))
            i = j
        elif c.isdigit() or (c == "." and i + 1 < n and src[i + 1].isdigit()):
            m = re.match(r"0[xX][0-9a-fA-F]+|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?", src[i:])
            if src[i:i + 2] in ("0b", "0B") or "_" in src[i:i + m.end() + 1]:
                raise TranslateError("binary or underscored number literal not supported")
            toks.append(Tok("number", m.group(0)))
            i += m.end()
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_][A-Za-z0-9_]*", src[i:])
            word = m.group(0)
            if word == "continue":
                raise TranslateError("continue is not supported")
            toks.append(Tok("kw" if word in KEYWORDS else "name", word))
            i += m.end()
        else:
            for op in OPS:
                if src.startswith(op, i):
                    if op in ("//", "//="):
                        raise TranslateError("floor division is not supported")
                    toks.append(Tok("op", op))
                    i += len(op)
                    break
            else:
                if c == "@":
                    raise TranslateError("attributes are not supported")
                toks.append(Tok("op", c))
                i += 1
    return toks


def text(toks: list[Tok]) -> str:
    return "".join(t.text for t in toks)


def is_trivia(t: Tok) -> bool:
    return t.kind in ("ws", "nl", "comment")


def next_sig(toks: list[Tok], i: int) -> int:
    while i < len(toks) and is_trivia(toks[i]):
        i += 1
    return i


def prev_sig(toks: list[Tok], i: int) -> int:
    i -= 1
    while i >= 0 and is_trivia(toks[i]):
        i -= 1
    return i


def match_close(toks: list[Tok], i: int) -> int:
    """toks[i] opens a bracket; return the index just after the matching close."""
    depth = 0
    for j in range(i, len(toks)):
        t = toks[j]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in CLOSE:
            depth -= 1
            if depth == 0:
                return j + 1
    raise TranslateError("unbalanced brackets")


def match_angle(toks: list[Tok], i: int) -> int:
    depth = 0
    for j in range(i, len(toks)):
        t = toks[j].text if toks[j].kind == "op" else None
        if t == "<":
            depth += 1
        elif t == ">":
            depth -= 1
            if depth == 0:
                return j + 1
        elif t in OPEN:
            pass
    raise TranslateError("unbalanced generic list")


# --------------------------------------------------------------------- types

def skip_primary_type(toks: list[Tok], i: int) -> int:
    i = next_sig(toks, i)
    t = toks[i]
    if t.kind == "op" and t.text == "(":
        j = match_close(toks, i)
        k = next_sig(toks, j)
        if k < len(toks) and toks[k].text == "->":
            return skip_type(toks, k + 1)
        return skip_postfix(toks, j)
    if t.kind == "op" and t.text == "{":
        return skip_postfix(toks, match_close(toks, i))
    if t.kind == "op" and t.text == "<":
        return skip_primary_type(toks, match_angle(toks, i))
    if t.kind == "op" and t.text == "...":
        k = next_sig(toks, i + 1)
        if k < len(toks) and (toks[k].kind == "name" or toks[k].text in ("(", "{")):
            return skip_type(toks, i + 1)
        return i + 1
    if t.kind == "string" or (t.kind == "kw" and t.text in ("nil", "true", "false")):
        return skip_postfix(toks, i + 1)
    if t.kind == "name" and t.text == "typeof":
        return skip_postfix(toks, match_close(toks, next_sig(toks, i + 1)))
    if t.kind == "name":
        j = i + 1
        while j + 1 < len(toks) and toks[j].text == "." and toks[j + 1].kind == "name":
            j += 2
        if j < len(toks) and toks[j].text == "<":
            j = match_angle(toks, j)
        return skip_postfix(toks, j)
    raise TranslateError(f"unexpected token in type: {t!r}")


def skip_postfix(toks: list[Tok], j: int) -> int:
    while j < len(toks) and toks[j].text == "?":
        j += 1
    return j


def skip_type(toks: list[Tok], i: int) -> int:
    k = next_sig(toks, i)
    if toks[k].text in ("|", "&"):
        i = k + 1
    j = skip_primary_type(toks, i)
    while True:
        k = next_sig(toks, j)
        if k < len(toks) and toks[k].kind == "op" and toks[k].text in ("|", "&"):
            j = skip_primary_type(toks, k + 1)
        else:
            return j


def newlines(toks: list[Tok]) -> list[Tok]:
    """The line breaks inside a removed or rewritten range, kept so line numbers stay the same."""
    return [Tok("nl", "\n") for t in toks if t.kind == "nl" or (t.kind in ("comment", "string") and "\n" in t.text) for _ in range(t.text.count("\n"))]


def delete(toks: list[Tok], start: int, end: int) -> list[Tok]:
    return toks[:start] + newlines(toks[start:end]) + toks[end:]


def strip_type_aliases(toks: list[Tok]) -> list[Tok]:
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "name" and t.text == "type":
            k = next_sig(toks, i + 1)
            p = prev_sig(toks, i)
            prev = toks[p].text if p >= 0 else ""
            if k < len(toks) and toks[k].kind == "name" and prev not in (".", ":", "local", "function"):
                j = k + 1
                if toks[j].text == "<":
                    j = match_angle(toks, j)
                e = next_sig(toks, j)
                if toks[e].text == "=":
                    start = p if prev == "export" else i
                    end = skip_type(toks, e + 1)
                    toks = delete(toks, start, end)
                    i = start
                    continue
        i += 1
    return toks


def strip_casts(toks: list[Tok]) -> list[Tok]:
    i = 0
    while i < len(toks):
        if toks[i].kind == "op" and toks[i].text == "::":
            end = skip_type(toks, i + 1)
            start = i
            while start > 0 and toks[start - 1].kind == "ws":
                start -= 1
            toks = delete(toks, start, end)
            i = start
            continue
        i += 1
    return toks


def strip_annotations(toks: list[Tok]) -> list[Tok]:
    """Parameter, return, local and for-variable annotations; generic parameter lists."""
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "kw" and t.text == "function":
            j = next_sig(toks, i + 1)
            while toks[j].kind == "name" or toks[j].text in (".", ":"):
                j += 1
            j = next_sig(toks, j)
            if toks[j].text == "<":
                end = match_angle(toks, j)
                toks = delete(toks, j, end)
                j = next_sig(toks, j)
            if toks[j].text != "(":
                raise TranslateError(f"expected parameter list after function, got {toks[j]!r}")
            close = match_close(toks, j) - 1
            k = j + 1
            depth = 0
            while k < close:
                x = toks[k]
                if x.kind == "op" and x.text in OPEN:
                    depth += 1
                elif x.kind == "op" and x.text in CLOSE:
                    depth -= 1
                elif depth == 0 and x.kind == "op" and x.text == ":":
                    end = skip_type(toks, k + 1)
                    toks = delete(toks, k, end)
                    close -= end - k
                    continue
                k += 1
            after = next_sig(toks, close + 1)
            if toks[after].text == ":":
                end = skip_type(toks, after + 1)
                toks = delete(toks, after, end)
        elif t.kind == "kw" and t.text in ("local", "for"):
            j = next_sig(toks, i + 1)
            if toks[j].text != "function":
                while toks[j].kind == "name":
                    k = next_sig(toks, j + 1)
                    if toks[k].text == ":":
                        end = skip_type(toks, k + 1)
                        toks = delete(toks, k, end)
                        k = next_sig(toks, k)
                    if toks[k].text == ",":
                        j = next_sig(toks, k + 1)
                    else:
                        break
        i += 1
    return toks


# --------------------------------------------------------------- expressions

EXPR_PREV = {"=", "(", ",", "{", "[", "..", "+", "-", "*", "/", "%", "^", "==", "~=", "<", ">", "<=", ">=", "#"}
EXPR_PREV_KW = {"return", "and", "or", "not"}
CONTINUATION = {"..", "+", "-", "*", "/", "%", "^", "==", "~=", "<", ">", "<=", ">=", "and", "or", ".", ":", "(", "[", "{"}


def expression_end(toks: list[Tok], i: int, stops: set[str]) -> int:
    """Index of the first depth-0 token at or after i that ends the expression."""
    depth = 0
    j = i
    while j < len(toks):
        t = toks[j]
        if t.kind == "op" and t.text in OPEN:
            depth += 1
        elif t.kind == "op" and t.text in CLOSE:
            if depth == 0:
                return j
            depth -= 1
        elif depth == 0:
            if (t.kind == "op" and t.text in (",", ";")) or (t.kind == "kw" and t.text in stops):
                return j
            if t.kind == "nl":
                p, q = prev_sig(toks, j), next_sig(toks, j)
                if q >= len(toks):
                    return j
                if toks[p].text not in CONTINUATION and toks[q].text not in CONTINUATION:
                    return j
        j += 1
    return j


def convert_if_expressions(toks: list[Tok]) -> list[Tok]:
    i = len(toks) - 1
    while i >= 0:
        t = toks[i]
        if t.kind == "kw" and t.text == "if":
            p = prev_sig(toks, i)
            prev = toks[p] if p >= 0 else None
            if prev is not None and ((prev.kind == "op" and prev.text in EXPR_PREV) or (prev.kind == "kw" and prev.text in EXPR_PREV_KW)):
                parts = []  # (cond, value) pairs, then the else value
                j = i + 1
                while True:
                    then_at = expression_end(toks, j, {"then"})
                    if toks[then_at].text != "then":
                        raise TranslateError("if-expression without then")
                    cond = toks[j:then_at]
                    value_end = expression_end(toks, then_at + 1, {"else", "elseif"})
                    parts.append((cond, toks[then_at + 1:value_end]))
                    if toks[value_end].text == "elseif":
                        j = value_end + 1
                        continue
                    if toks[value_end].text != "else":
                        raise TranslateError("if-expression without else")
                    final_end = expression_end(toks, value_end + 1, {"end", "else", "elseif", "then", "do", "until", "local", "return"})
                    otherwise = toks[value_end + 1:final_end]
                    break
                out = "("
                for cond, value in parts:
                    out += f"({text(cond).strip()}) and {{{text(value).strip()}}} or "
                out += f"{{{text(otherwise).strip()}}})[1]"
                kept = newlines(toks[i:final_end])
                out_toks = tokenize(" ".join(out.split("\n")))
                toks = toks[:i] + out_toks + kept + toks[final_end:]
        i -= 1
    return toks


def convert_compound(toks: list[Tok]) -> list[Tok]:
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "op" and t.text in COMPOUND:
            start = i
            while start > 0 and not (toks[start - 1].kind == "nl" or toks[start - 1].text == ";" or (toks[start - 1].kind == "kw" and toks[start - 1].text in ("then", "do", "else"))):
                start -= 1
            lhs = text(toks[start:i]).strip()
            end = expression_end(toks, i + 1, {"end", "else", "elseif"})
            rhs = text(toks[i + 1:end]).strip()
            lead = text(toks[start:i])[: len(text(toks[start:i])) - len(text(toks[start:i]).lstrip())]
            replacement = tokenize(f"{lead}{lhs} = {lhs} {COMPOUND[t.text]} ({' '.join(rhs.split(chr(10)))})") + newlines(toks[i:end])
            toks = toks[:start] + replacement + toks[end:]
            i = start + len(replacement)
            continue
        i += 1
    return toks


def convert_generic_for(toks: list[Tok]) -> list[Tok]:
    i = 0
    while i < len(toks):
        t = toks[i]
        if t.kind == "kw" and t.text == "for":
            j = i + 1
            while j < len(toks) and not (toks[j].kind == "kw" and toks[j].text in ("in", "do")) and toks[j].text != "=":
                j += 1
            if toks[j].text == "in":
                end = expression_end(toks, j + 1, {"do"})
                if toks[end].text != "do":
                    raise TranslateError("for-in without do")
                explist = text(toks[j + 1:end]).strip()
                replacement = tokenize(f" __iter({' '.join(explist.split(chr(10)))}) ") + newlines(toks[j + 1:end])
                toks = toks[:j + 1] + replacement + toks[end:]
        i += 1
    return toks


def convert_interpolation(toks: list[Tok]) -> list[Tok]:
    out: list[Tok] = []
    for t in toks:
        if t.kind != "interp":
            out.append(t)
            continue
        body = t.text[1:-1]
        pieces, literal, k = [], "", 0
        while k < len(body):
            c = body[k]
            if c == "\\":
                nxt = body[k + 1]
                literal += nxt if nxt in "`{}" else "\\" + nxt
                k += 2
            elif c == "{":
                end = scan_braced_expr(body, k)
                if literal:
                    pieces.append('"' + literal + '"')
                    literal = ""
                pieces.append(f"__tostr({translate(body[k + 1:end - 1]).strip()})")
                k = end
            else:
                literal += '\\"' if c == '"' else c
                k += 1
        if literal or not pieces:
            pieces.append('"' + literal + '"')
        out.extend(tokenize("(" + " .. ".join(pieces) + ")"))
    return out


def translate(src: str) -> str:
    toks = tokenize(src)
    toks = convert_interpolation(toks)
    toks = strip_type_aliases(toks)
    toks = strip_casts(toks)
    toks = strip_annotations(toks)
    toks = convert_if_expressions(toks)
    toks = convert_compound(toks)
    toks = convert_generic_for(toks)
    return text(toks)


if __name__ == "__main__":
    sys.stdout.write(translate(open(sys.argv[1], encoding="utf-8").read()))
