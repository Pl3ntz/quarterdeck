#!/usr/bin/env python3
"""
deep-researcher-validate — deterministic post-output validator for the deep-researcher agent.

Why this exists: prompt-only enforcement of DETERMINISTIC invariants (source independence,
required headers, citation liveness, hedging) saturates — a probabilistic model under output
pressure satisfices ("triangulei 3 fontes" without doing the org-dedup). This script does the
checks in code, where they cannot be faked, and auto-downgrades HIGH labels that don't earn it.

Reads the agent's markdown report (stdin or a file path). Runs:
  1. CONTRACT  — the 5 required headers present, zero preamble, achados<=5, each ACHADO tagged.
  2. INDEPENDENCE — map each ACHADO's cited [n] indices -> FONTES URLs -> distinct ORGS;
                    HIGH requires >=3 distinct orgs. Auto-downgrades HIGH that fails (floor).
  3. HEDGING   — banlist of uncertainty words used as grounding in the body.
  4. LIVENESS  — (opt-in --liveness) curl each URL; 404/NXDOMAIN on a cited URL = fabrication flag.

Exit code: 0 = clean, 1 = violations found. --fix emits a corrected report on stdout.
Stdlib only. Org aliases load from deep-researcher-org-aliases.json next to this script if present.
"""
import sys, re, json, os, subprocess
from urllib.parse import urlparse

# --- registrable domain (eTLD+1) with a small multi-part public-suffix set ---
MULTI_SUFFIXES = {
    "co.uk", "org.uk", "gov.uk", "ac.uk", "me.uk", "com.br", "gov.br", "org.br",
    "edu.br", "net.br", "com.au", "gov.au", "org.au", "co.jp", "co.in", "co.nz",
    "com.mx", "com.ar", "co.za", "com.tr", "com.cn", "gov.cn",
}

def registrable_domain(host: str) -> str:
    host = host.lower().strip().lstrip("www.")
    parts = host.split(".")
    if len(parts) < 2:
        return host
    last2 = ".".join(parts[-2:])
    last3 = ".".join(parts[-3:]) if len(parts) >= 3 else ""
    if last2 in MULTI_SUFFIXES and len(parts) >= 3:
        return ".".join(parts[-3:])
    return last2

# org aliases: different registrable domains / code-host paths that are the SAME organization.
DEFAULT_ALIASES = {
    "platform.claude.com": "anthropic", "claude.com": "anthropic",
    "anthropic.com": "anthropic", "docs.anthropic.com": "anthropic",
    "pydantic.dev": "pydantic", "github.com/pydantic": "pydantic",
    "openai.com": "openai", "platform.openai.com": "openai",
}

def load_aliases() -> dict:
    p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "deep-researcher-org-aliases.json")
    aliases = dict(DEFAULT_ALIASES)
    if os.path.exists(p):
        try:
            aliases.update(json.load(open(p)))
        except Exception:
            pass
    return aliases

def org_of(url: str, aliases: dict) -> str:
    """Canonical organization of a URL: subdomain-collapse + code-host path-org + alias map."""
    try:
        u = urlparse(url if "//" in url else "https://" + url)
    except Exception:
        return url
    host = (u.netloc or u.path.split("/")[0]).lower().lstrip("www.")
    reg = registrable_domain(host)
    path_parts = [p for p in u.path.split("/") if p]
    # code/model hosts: the org is the first path segment
    if reg in ("github.com", "gitlab.com", "huggingface.co") and path_parts:
        key = f"{reg}/{path_parts[0].lower()}"
        return aliases.get(key, key)
    # subdomain collapse already done by registrable_domain; then alias the host and the reg
    return aliases.get(host, aliases.get(reg, reg))

REQUIRED = ["### ACHADOS", "### CONTRADIÇÕES", "### LACUNAS", "### PRÓXIMO PASSO", "### FONTES"]
HEDGES = ["provavelmente", "deve ser", "imagino que", "presumivelmente", "talvez",
          "acredito que", "parece que", "ao que tudo indica", "probably", "likely",
          "should be", "i assume", "presumably", "it seems", "appears to be", "my guess", "i believe"]

# OSINT findings are about infrastructure; their provenance floor is "verbatim command output present",
# NOT "3 independent orgs" (a single authoritative dig/whois IS the primary source).
INFRA_RE = re.compile(
    r"\b(whois|dig|nslookup|openssl|name ?servers?|registrar|\bMX\b|\bNS\b|A record|AAAA|CNAME|"
    r"TXT record|cert(ificate)?|issuer|cloudflare|webflow|akamai|fastly|\bCDN\b|\bASN\b|\bDNS\b|"
    r"\bSSL\b|\bTLS\b|\bIPv?6?\b|hospedagem|name server)\b", re.I)
# signatures that a verbatim command-output block is actually present in the report
OUTPUT_SIG_RE = re.compile(
    r"(;;\s|issuer\s*=|subject\s*=|notAfter|notBefore|^\s*server:\s|\b\d{1,3}(\.\d{1,3}){3}\b|"
    r"\bns\d|aspmx|\bIN\s+(A|AAAA|MX|NS|TXT|CNAME)\b|cf-ray|x-served-by|markmonitor|"
    r"[0-9a-f]{2}(:[0-9a-f]{2}){3,})", re.I | re.M)

def split_sections(text: str) -> dict:
    out, cur, buf = {}, None, []
    for line in text.splitlines():
        m = re.match(r"^(#{2,3})\s+(.*)$", line)
        if m:
            if cur is not None:
                out[cur] = "\n".join(buf).strip()
            cur = "### " + m.group(2).strip().upper()
            buf = []
        else:
            buf.append(line)
    if cur is not None:
        out[cur] = "\n".join(buf).strip()
    return out

def find_section(sections: dict, name: str) -> str:
    target = name.replace("### ", "").upper()
    for k, v in sections.items():
        if k.replace("### ", "").startswith(target):
            return v
    return None

def parse_fontes(block: str) -> dict:
    """index -> first URL on that numbered line."""
    fontes = {}
    if not block:
        return fontes
    for line in block.splitlines():
        m = re.match(r"^\s*(\d+)\.\s+(.*)$", line)
        if not m:
            continue
        idx = int(m.group(1))
        url = re.search(r"https?://[^\s\]\)>`*]+", line)
        if url:
            fontes[idx] = url.group(0).rstrip(".,`*)>")
    return fontes

def parse_achados(block: str):
    """list of {label, indices:[int], raw}."""
    out = []
    if not block:
        return out
    for line in block.splitlines():
        if not re.match(r"^\s*[-*]", line):
            continue
        lab = re.search(r"\b(HIGH|MEDIUM|LOW|UNVERIFIED)\b", line)
        idxs = [int(x) for x in re.findall(r"\[(\d[\d,\s]*)\]", line) for x in re.findall(r"\d+", x)]
        # the above is messy; redo cleanly:
        idxs = []
        for grp in re.findall(r"\[([\d,\s]+)\]", line):
            idxs += [int(n) for n in re.findall(r"\d+", grp)]
        out.append({"label": lab.group(1) if lab else None, "indices": sorted(set(idxs)), "raw": line})
    return out

def curl_code(url: str) -> str:
    try:
        r = subprocess.run(["curl", "-sIL", "--max-time", "10", "-o", "/dev/null",
                            "-w", "%{http_code}", url], capture_output=True, text=True, timeout=15)
        return r.stdout.strip() or "000"
    except Exception:
        return "000"

def validate(text: str, do_liveness=False):
    aliases = load_aliases()
    sections = split_sections(text)
    violations, downgrades, notes = [], [], []

    # 1. CONTRACT
    first = next((l for l in text.splitlines() if l.strip()), "")
    if not first.startswith("### "):
        violations.append(("CONTRACT", "preâmbulo: primeira linha não é um header '### '"))
    for h in REQUIRED:
        if find_section(sections, h) is None:
            violations.append(("CONTRACT", f"seção obrigatória ausente: {h}"))

    fontes = parse_fontes(find_section(sections, "### FONTES") or "")
    achados = parse_achados(find_section(sections, "### ACHADOS") or "")
    if len(achados) > 5:
        violations.append(("CONTRACT", f"achados={len(achados)} > 5"))
    for a in achados:
        if a["label"] is None:
            violations.append(("CONTRACT", f"achado sem label [HIGH|MEDIUM|LOW]: {a['raw'][:70]}"))

    # 2. INDEPENDENCE — auto-downgrade HIGH that doesn't earn it.
    # OSINT/infra claims use a DIFFERENT floor: verbatim command output present (not 3 orgs).
    has_output_evidence = bool(OUTPUT_SIG_RE.search(text))
    for a in achados:
        if a["label"] != "HIGH":
            continue
        if INFRA_RE.search(a["raw"]):  # OSINT mode
            if not has_output_evidence:
                downgrades.append((a, "MEDIUM", "OSINT HIGH sem output verbatim de comando no relatório -> rebaixar"))
            continue
        if not a["indices"]:
            downgrades.append((a, "MEDIUM", "HIGH sem índices [n] mapeáveis -> independência inverificável"))
            continue
        urls = [fontes[i] for i in a["indices"] if i in fontes]
        orgs = sorted(set(org_of(u, aliases) for u in urls))
        if len(orgs) < 3:
            new = "LOW" if len(orgs) <= 1 else "MEDIUM"
            downgrades.append((a, new, f"HIGH com {len(orgs)} org(s) distinta(s) {orgs} (<3) -> rebaixar"))

    # 3. HEDGING (body only: exclude FONTES / OPEN QUESTIONS / APÊNDICE)
    body = "\n".join(v for k, v in sections.items()
                     if not any(k.startswith("### " + x) for x in ("FONTES", "OPEN", "APÊNDICE", "APENDICE")))
    for h in HEDGES:
        if re.search(r"\b" + re.escape(h) + r"\b", body, re.I):
            notes.append(("HEDGING", f"'{h}' no corpo — confirme se é grounding (proibido) ou label calibrado"))

    # 4. LIVENESS (opt-in)
    liveness = {}
    if do_liveness:
        for i, u in sorted(fontes.items()):
            code = curl_code(u)
            liveness[u] = code
            if code in ("404", "000") and any(i in a["indices"] for a in achados):
                violations.append(("LIVENESS", f"[{i}] {u} -> {code} (cited/load-bearing) — possível fabricação"))

    return {"sections": list(sections.keys()), "violations": violations,
            "downgrades": downgrades, "notes": notes, "liveness": liveness,
            "n_achados": len(achados), "n_fontes": len(fontes)}

def apply_fix(text: str, res) -> str:
    out = text
    for a, new, _why in res["downgrades"]:
        fixed = re.sub(r"\b(HIGH)\b", new, a["raw"], count=1)
        out = out.replace(a["raw"], fixed + f"  <!-- auto-downgraded: {_why} -->")
    return out

def main():
    args = sys.argv[1:]
    do_live = "--liveness" in args
    do_fix = "--fix" in args
    as_json = "--json" in args
    paths = [a for a in args if not a.startswith("--")]
    text = open(paths[0]).read() if paths else sys.stdin.read()

    res = validate(text, do_liveness=do_live)
    if do_fix:
        sys.stdout.write(apply_fix(text, res))
        return 0 if not res["violations"] else 1
    if as_json:
        print(json.dumps({k: (v if k != "downgrades" else
              [{"label_was": d[0]["label"], "to": d[1], "why": d[2], "achado": d[0]["raw"][:90]} for d in v])
              for k, v in res.items()}, ensure_ascii=False, indent=2))
    else:
        print(f"sections: {res['n_achados']} achados, {res['n_fontes']} fontes, headers={res['sections']}")
        if res["violations"]:
            print("\nVIOLATIONS (block):")
            for cat, msg in res["violations"]:
                print(f"  [{cat}] {msg}")
        if res["downgrades"]:
            print("\nAUTO-DOWNGRADES (independence floor):")
            for a, new, why in res["downgrades"]:
                print(f"  HIGH -> {new}: {why}\n      {a['raw'][:90]}")
        if res["notes"]:
            print("\nNOTES (review):")
            for cat, msg in res["notes"]:
                print(f"  [{cat}] {msg}")
        if res["liveness"]:
            print("\nLIVENESS:")
            for u, c in res["liveness"].items():
                print(f"  {c}  {u}")
        if not (res["violations"] or res["downgrades"] or res["notes"]):
            print("\nCLEAN — passes the deterministic floor.")
    return 1 if (res["violations"] or res["downgrades"]) else 0

if __name__ == "__main__":
    sys.exit(main())
