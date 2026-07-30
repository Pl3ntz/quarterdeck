#!/usr/bin/env python3
"""pii_secrets_scan.py — layered pt-BR PII + secret detector for the leak-guard.

Reads text on stdin (a file's staged blob, a commit message, or a path list) and
reports sensitive findings. Hardened against the false-positives that would make a
daily-use guard get disabled: pt-BR documents are check-digit validated, known test
fixtures are allow-listed, and localhost/dummy credentials are ignored.

Exit codes:
  0  clean (no HARD findings)
  1  at least one HARD finding (caller must BLOCK)
WARN findings are printed but never change the exit code.

Usage:
  <text> | pii_secrets_scan.py [--json] [--source LABEL]

--source carries the file path so test/fixture files can relax the FP-prone rules.
"""
from __future__ import annotations

import argparse
import base64
import binascii
import json
import math
import re
import sys


# ---------------------------------------------------------------------------
# Redaction — a finding never prints the full value (avoids a second leak).
# ---------------------------------------------------------------------------
def redact(value: str) -> str:
    v = value.strip()
    if len(v) <= 4:
        return "*" * len(v)
    if len(v) <= 8:
        return v[0] + "*" * (len(v) - 2) + v[-1]
    return v[:2] + "*" * (len(v) - 4) + v[-2:]


def _digits(s: str) -> str:
    return re.sub(r"\D", "", s)


def shannon(s: str) -> float:
    if not s:
        return 0.0
    counts = {}
    for c in s:
        counts[c] = counts.get(c, 0) + 1
    n = len(s)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


# ---------------------------------------------------------------------------
# pt-BR document validators (check digit) — turn broad number regexes into
# high-precision HARD rules, exactly like CPF/CNPJ.
# ---------------------------------------------------------------------------
def valid_cpf(raw: str) -> bool:
    d = _digits(raw)
    if len(d) != 11 or d == d[0] * 11:
        return False
    n = [int(c) for c in d]
    for k in (9, 10):
        chk = sum(n[i] * ((k + 1) - i) for i in range(k)) * 10 % 11 % 10
        if chk != n[k]:
            return False
    return True


def valid_cnpj(raw: str) -> bool:
    d = _digits(raw)
    if len(d) != 14 or d == d[0] * 14:
        return False
    n = [int(c) for c in d]
    for k, w in ((12, [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]),
                 (13, [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2])):
        chk = 11 - (sum(n[i] * w[i] for i in range(k)) % 11)
        chk = 0 if chk >= 10 else chk
        if chk != n[k]:
            return False
    return True


def luhn(raw: str) -> bool:
    d = _digits(raw)
    if len(d) < 13 or len(d) > 19 or d == d[0] * len(d):
        return False
    total, alt = 0, False
    for c in reversed(d):
        x = int(c)
        if alt:
            x *= 2
            if x > 9:
                x -= 9
        total += x
        alt = not alt
    return total % 10 == 0


def valid_pis(raw: str) -> bool:
    d = _digits(raw)
    if len(d) != 11 or d == d[0] * 11:
        return False
    w = [3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    r = sum(int(d[i]) * w[i] for i in range(10)) % 11
    dv = 0 if r < 2 else 11 - r
    return dv == int(d[10])


def valid_titulo(raw: str) -> bool:
    d = _digits(raw)
    if len(d) != 12 or d == d[0] * 12:
        return False
    seq, uf = d[:8], int(d[8:10])
    if uf < 1 or uf > 28:
        return False
    dv1 = sum(int(seq[i]) * (i + 2) for i in range(8)) % 11
    dv1 = 0 if dv1 == 10 else dv1
    dv2 = ((uf // 10) * 7 + (uf % 10) * 8 + dv1 * 9) % 11
    dv2 = 0 if dv2 == 10 else dv2
    return dv1 == int(d[10]) and dv2 == int(d[11])


# ---------------------------------------------------------------------------
# Allow-lists — never block these (well-known fixtures / dummy creds).
# ---------------------------------------------------------------------------
TEST_DOCS = {"11144477735", "12345678909", "00000000191", "11222333000181"}

_PLACEHOLDER = re.compile(
    r"(?i)(example|xxxx+|placeholder|your[-_]|change[-_]?(me|it)|redacted|dummy|"
    r"sample|foobar|<[^>]+>|\$\{|\{\{|process\.env|os\.environ|import\.meta\.env|"
    r"getenv|0{6,}|1234567|deadbeef|noreply|test@|user@example|"
    r"^(postgres|redis|root|admin|password|passwd|secret|user|guest|keyboard.?cat)$)"
)

_DUMMY_CREDS = {
    ("postgres", "postgres"), ("root", "root"), ("user", "password"),
    ("admin", "admin"), ("guest", "guest"), ("root", ""), ("postgres", ""),
}
_LOCAL_HOSTS = re.compile(r"^(localhost|127\.0\.0\.1|0\.0\.0\.0|::1|\[::1\]|"
                          r"host\.docker\.internal|[a-z0-9_-]+\.local|db|redis|"
                          r"postgres|mysql|mongo|cache|queue)(:\d+)?$", re.I)

_TEST_SOURCE = re.compile(r"(?i)(^|/)(tests?|__tests__|fixtures?|spec|specs|mocks?|"
                          r"seeds?|factor(y|ies)|examples?|samples?|stub)s?(/|\.|$)|"
                          r"\.(example|sample|test|spec|fixture)(\.|$)|\.md$")

_ADDR_KW = re.compile(r"(?i)\b(rua|r\.|av\.|avenida|alameda|al\.|travessa|"
                      r"logradouro|pra[çc]a|rodovia|estrada|n[ºo°]|n[uú]mero)\b")


def is_placeholder(value: str) -> bool:
    return bool(_PLACEHOLDER.search(value.strip()))


# ---------------------------------------------------------------------------
# Detector rules. Each rule is a dict:
#   name, sev ("HARD"/"WARN"), rx, group (which capture is the value),
#   validator (bool fn), context (regex the LINE must also match),
#   postfilter (fn(match, line) -> "HARD"/"WARN"/None to override/drop).
# ---------------------------------------------------------------------------
def _conn_filter(m, line):
    # Shape: proto :// <user> : <pass> @ host  — ignore localhost + dummy creds.
    # Written spaced out on purpose: as a contiguous string this comment matches the very rule
    # it documents, and the scanner blocked its own file from being committed.
    inner = m.group(0)
    mm = re.search(r"://([^:@/\s]+):([^:@/\s]+)@([^/\s:]+)", inner)
    if not mm:
        return "HARD"
    user, pw, host = mm.group(1), mm.group(2), mm.group(3)
    if _LOCAL_HOSTS.match(host) or (user, pw) in _DUMMY_CREDS or is_placeholder(pw):
        return None
    return "HARD"


def _entropy_filter(m, line):
    val = m.group(0)
    if is_placeholder(line):
        return None
    d = _digits(val)
    if len(d) == len(val):                       # all digits (ids, timestamps)
        return None
    if re.fullmatch(r"[0-9a-f]{40}", val, re.I):  # git sha
        return None
    if re.fullmatch(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", val, re.I):
        return None
    if "sha512-" in line or "sha256-" in line or "integrity" in line.lower():
        return None  # lockfile hashes
    # Git merge metadata: "Merge pull request #2 from owner/long-descriptive-branch-name".
    # The branch reference is generated by git/GitHub, never typed, and a long hyphenated
    # branch name trips the mixed-class entropy test every time. Scoped to the reference
    # itself, so a secret elsewhere on the line is still caught.
    if re.match(r"\s*Merge (?:pull request|branch|remote-tracking branch)\b", line):
        ref = re.search(r"\b(?:from|of)\s+(\S+)", line)
        if ref and val in ref.group(1):
            return None
    if not (re.search(r"[A-Z]", val) and re.search(r"[a-z]", val) and re.search(r"\d", val)):
        return None  # require mixed classes
    return "HARD" if shannon(val) >= 4.3 else "WARN"


RULES = [
    # ---- secrets (high-confidence, prefix-anchored) ----
    dict(name="private-key", sev="HARD",
         rx=re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH |PGP |DSA |ENCRYPTED )?PRIVATE KEY-----")),
    dict(name="aws-access-key", sev="HARD", rx=re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{16}\b")),
    dict(name="github-token", sev="HARD", rx=re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b")),
    dict(name="github-pat", sev="HARD", rx=re.compile(r"\bgithub_pat_[A-Za-z0-9_]{60,}\b")),
    dict(name="google-api-key", sev="HARD", rx=re.compile(r"\bAIza[0-9A-Za-z_\-]{35}\b")),
    dict(name="slack-token", sev="HARD", rx=re.compile(r"\bxox[baprs]-[0-9A-Za-z-]{10,}\b")),
    dict(name="slack-webhook", sev="HARD",
         rx=re.compile(r"https://hooks\.slack\.com/services/[A-Za-z0-9/_+-]{40,}")),
    dict(name="stripe-key", sev="HARD", rx=re.compile(r"\b(?:sk|rk)_live_[0-9A-Za-z]{20,}\b")),
    dict(name="openai-key", sev="HARD", rx=re.compile(r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}\b")),
    dict(name="anthropic-key", sev="HARD", rx=re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}\b")),
    dict(name="sendgrid-key", sev="HARD",
         rx=re.compile(r"\bSG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}\b")),
    dict(name="jwt", sev="WARN",
         rx=re.compile(r"\beyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b")),
    dict(name="password-hash", sev="WARN",
         rx=re.compile(r"(\$2[aby]\$\d\d\$[./A-Za-z0-9]{53}|\$argon2[id]{1,2}\$[^\s\"']+|"
                       r"\$6\$[./A-Za-z0-9]{8,}\$[./A-Za-z0-9]{43,}|\{SSHA\}[A-Za-z0-9+/=]{20,})")),
    dict(name="conn-string-creds", sev="HARD",
         rx=re.compile(r"\b[a-z][a-z0-9+.\-]*://[^\s:@/]+:[^\s:@/]{3,}@[^\s/]+"),
         postfilter=_conn_filter),
    dict(name="generic-secret-assign", sev="HARD",
         rx=re.compile(r"""(?ix)
            (?:password|passwd|pwd|secret|api[_-]?key|access[_-]?token|
               auth[_-]?token|client[_-]?secret|private[_-]?key)
            \s*[:=]\s*["']?([^\s"'#,;)]{8,})["']?
         """), group=1),
    dict(name="high-entropy-token", sev="HARD",
         rx=re.compile(r"\b[A-Za-z0-9+/_-]{32,}={0,2}\b"), postfilter=_entropy_filter),

    # ---- pt-BR PII (check-digit validated -> high precision) ----
    dict(name="cpf", sev="HARD", rx=re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"), validator=valid_cpf),
    dict(name="cnpj", sev="HARD", rx=re.compile(r"\b\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}\b"), validator=valid_cnpj),
    dict(name="pis-pasep", sev="HARD", rx=re.compile(r"\b\d{3}\.?\d{5}\.?\d{2}-?\d\b"), validator=valid_pis),
    dict(name="titulo-eleitor", sev="HARD", rx=re.compile(r"\b\d{4}\.?\d{4}\.?\d{4}\b"), validator=valid_titulo),
    dict(name="credit-card", sev="HARD", rx=re.compile(r"\b(?:\d[ -]?){13,19}\b"), validator=luhn),
    dict(name="phone-br", sev="HARD",
         rx=re.compile(r"(?:\+55[\s-]?)?(?:\(\d{2}\)[\s-]?9\d{4}-?\d{4}|"
                       r"\+55[\s-]?\d{2}[\s-]?9\d{4}[\s-]?\d{4}|\b\d{2}[\s-]9\d{4}-\d{4}\b)")),
    dict(name="cnh", sev="WARN", rx=re.compile(r"\b\d{11}\b"),
         context=re.compile(r"(?i)\b(cnh|habilita[çc][ãa]o|carteira de motorista)\b")),
    dict(name="rg", sev="WARN", rx=re.compile(r"\b\d{1,2}\.?\d{3}\.?\d{3}-?[0-9Xx]\b"),
         context=re.compile(r"(?i)\b(rg|registro geral|identidade|c[ée]dula de identidade)\b")),
    dict(name="email", sev="WARN", rx=re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b")),
    dict(name="cep", sev="WARN", rx=re.compile(r"\b\d{5}-?\d{3}\b")),
]


def _decode_candidates(line: str):
    """Yield decoded strings from long base64/hex tokens (catches encoded secrets)."""
    for tok in re.findall(r"\b[A-Za-z0-9+/]{20,}={0,2}\b", line):
        try:
            dec = base64.b64decode(tok, validate=True).decode("utf-8", "ignore")
            if dec and sum(c.isprintable() for c in dec) / len(dec) > 0.8:
                yield dec
        except (binascii.Error, ValueError):
            pass
    for tok in re.findall(r"\b[0-9a-fA-F]{32,}\b", line):
        try:
            dec = bytes.fromhex(tok).decode("utf-8", "ignore")
            if dec and sum(c.isprintable() for c in dec) / len(dec) > 0.8:
                yield dec
        except ValueError:
            pass


_EPOCH_MS_KEY = re.compile(
    r'"[^"]*(?:at|time|timestamp|ts|date|ms|millis|duration|start|end|created|updated|'
    r'queued|expires|issued)[^"]*"\s*:\s*\d{13}\b', re.I)


def _scan_line(line: str, lineno: int, test_src: bool, decoded: bool):
    out = []
    for r in RULES:
        for m in r["rx"].finditer(line):
            value = m.group(r["group"]) if r.get("group") and m.group(r.get("group")) else m.group(0)
            if r.get("validator") and not r["validator"](value):
                continue
            if r.get("context") and not r["context"].search(line):
                continue
            # A bare 13-digit JSON number under a time-shaped key is a millisecond epoch,
            # not a card. Luhn passes on some by coincidence, and eval/telemetry artifacts are
            # full of "queuedAt": 1782586459184. Deliberately narrow: the key must name a time,
            # the value must carry no separators, and it must sit inside the epoch-ms range for
            # 2001-2033. A card written any other way still matches.
            if r["name"] == "credit-card" and _EPOCH_MS_KEY.search(line):
                d = _digits(value)
                if len(d) == 13 and value == d and 1_000_000_000_000 <= int(d) <= 2_000_000_000_000:
                    continue
            sev = r["sev"]
            pf = r.get("postfilter")
            if pf:
                sev = pf(m, line)
                if sev is None:
                    continue
            if sev == "HARD" and r["name"] in ("generic-secret-assign", "high-entropy-token") \
                    and is_placeholder(m.group(0)):
                continue
            # allow-list well-known test documents
            if r["name"] in ("cpf", "cnpj", "pis-pasep") and _digits(value) in TEST_DOCS:
                continue
            # relax FP-prone PII in obvious test/fixture/doc files
            if test_src and r["name"] in ("cpf", "cnpj", "credit-card", "phone-br", "generic-secret-assign"):
                sev = "WARN"
            # address escalation: a CEP on an address line is HARD
            if r["name"] == "cep" and _ADDR_KW.search(line):
                sev = "HARD"
            out.append({"class": r["name"] + ("+b64" if decoded else ""),
                        "severity": sev, "redacted": redact(value), "line": lineno})
    return out


def scan_text(text: str, source: str = ""):
    test_src = bool(_TEST_SOURCE.search(source)) if source else False
    findings = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        findings += _scan_line(line, lineno, test_src, decoded=False)
        for dec in _decode_candidates(line):
            findings += _scan_line(dec, lineno, test_src, decoded=True)
    return findings


def main() -> int:
    ap = argparse.ArgumentParser(description="Layered pt-BR PII + secret detector.")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--source", default="")
    args = ap.parse_args()

    try:
        text = sys.stdin.buffer.read().decode("utf-8", "replace")
    except OSError as exc:
        print(f"leak-guard: cannot read stdin: {exc}", file=sys.stderr)
        return 1  # fail-closed

    findings = scan_text(text, args.source)
    hard = [f for f in findings if f["severity"] == "HARD"]
    warn = [f for f in findings if f["severity"] == "WARN"]

    if args.json:
        print(json.dumps({"source": args.source, "hard": hard, "warn": warn}, ensure_ascii=False))
    else:
        src = f" [{args.source}]" if args.source else ""
        for f in hard:
            print(f"  [BLOCK]{src} {f['class']} (line {f['line']}): {f['redacted']}", file=sys.stderr)
        for f in warn:
            print(f"  [WARN]{src} {f['class']} (line {f['line']}): {f['redacted']}", file=sys.stderr)

    return 1 if hard else 0


if __name__ == "__main__":
    sys.exit(main())
