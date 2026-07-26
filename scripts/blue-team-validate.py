#!/usr/bin/env python3
"""
blue-team-validate — deterministic post-output validator for the blue-team agent.

Why this exists: prompt-only enforcement of DETERMINISTIC invariants (the 2-header
contract, anti-theater discipline, read-only compliance) saturates under output
pressure — a probabilistic model will happily sell an input filter as a "boundary"
or slip an applied `diff` while *believing* it followed the rules. This script does
those checks in code, where they cannot be faked, and gives the judge panel a Layer-1
floor the model can't silently override.

Contract delta vs deep-researcher (drives every check below):
  * Output = `### ACHADOS` / `### PRÓXIMO PASSO` only (2 headers, not 5).
  * Severity `[CRITICAL|HIGH|MEDIUM|LOW]` (4 levels), not confidence `[HIGH|MEDIUM|LOW]`.
  * Evidence is inline `file:line` / `comando → output`, NOT a URL bibliography, so the
    automatable checks shift from URL-liveness/independence to anti-theater / read-only /
    overlap invariants.

Reads the agent's markdown output (stdin or a file path). Runs:
  BLOCKING (exit 1):
    1. CONTRACT      — first non-blank line == `### ACHADOS`, `### PRÓXIMO PASSO` present,
                       every achado tagged [CRITICAL|HIGH|MEDIUM|LOW], body within budget.
    2. ANTI-THEATER  — an input-side "theater" technique framed as a control/boundary/fix
                       with NO telemetry qualifier in the same bullet-block.
    3. READ-ONLY     — first-person applied-change language, or a fenced diff/patch block.
  NOTE (never blocks):
    4. HEDGING       — banlist of uncertainty words used as grounding.
    5. OVERLAP       — sec-reviewer hardening/audit language, or incident-responder live-triage verbs.
    6. EVIDENCE      — achados lacking a file:line / comando→output / artifact-quote anchor.

Exit code: 0 = clean, 1 = any BLOCKING violation. --json emits a structured report.
Stdlib only.
"""
import sys
import re
import json
from math import ceil

# --------------------------------------------------------------------------- #
# Section / structure helpers (reused from deep-researcher-validate.py)
# --------------------------------------------------------------------------- #

def split_sections(text: str) -> dict:
    """header (normalized '### NAME', upper) -> body text (stripped)."""
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
    """Return the body of the first section whose name startswith the target, else None."""
    target = name.replace("### ", "").upper()
    for k, v in sections.items():
        if k.replace("### ", "").startswith(target):
            return v
    return None


# Severity: bracketed form is canonical; bare-word is tolerated as a fallback.
SEVERITY_BRACKET_RE = re.compile(r"\[(CRITICAL|HIGH|MEDIUM|LOW)\]", re.I)
SEVERITY_WORD_RE = re.compile(r"\b(CRITICAL|HIGH|MEDIUM|LOW)\b")
SEVERITY_RANK = {"CRITICAL": 3, "HIGH": 2, "MEDIUM": 1, "LOW": 0}


def parse_achados(block: str):
    """list of {label, raw} — one per bullet line in the ACHADOS body."""
    out = []
    if not block:
        return out
    for line in block.splitlines():
        if not re.match(r"^\s*[-*]\s", line):
            continue
        m = SEVERITY_BRACKET_RE.search(line) or SEVERITY_WORD_RE.search(line)
        out.append({"label": m.group(1).upper() if m else None, "raw": line})
    return out


def bullet_blocks(block: str):
    """A bullet line + its continuation lines until the next bullet or header.

    Needed for ANTI-THEATER qualifier-proximity: the telemetry pardon must live in the
    SAME logical finding, not three bullets away.
    """
    if not block:
        return []
    blocks, cur = [], None
    for line in block.splitlines():
        if re.match(r"^\s*[-*]\s", line):
            if cur is not None:
                blocks.append("\n".join(cur))
            cur = [line]
        elif re.match(r"^#{2,6}\s", line):
            if cur is not None:
                blocks.append("\n".join(cur))
                cur = None
        else:
            if cur is not None:
                cur.append(line)
    if cur is not None:
        blocks.append("\n".join(cur))
    return blocks


# --------------------------------------------------------------------------- #
# CONTRACT
# --------------------------------------------------------------------------- #

BUDGET = {"terse": 180, "design": 1500}  # tokens; tok ≈ len(body)/4, ±15% heuristic
EMPTY_ACHADOS = {"", "-", "—", "n/a", "na", "nenhum", "ok, sem problemas",
                 "ok — sem problemas", "sem problemas", "nada a reportar"}


def approx_tokens(s: str) -> int:
    return ceil(len(s) / 4)


# --------------------------------------------------------------------------- #
# ANTI-THEATER — input-side technique sold as a boundary/control with no telemetry qualifier
# --------------------------------------------------------------------------- #

THEATER_RE = re.compile(
    r"\b(input[\s-]?filter|filtro de (input|entrada)|keyword\s*(filter|block|blocklist)|"
    r"blocklist|lista de (palavras )?bloquead|regex\s*(sanitiz|dlp|filter)|\bdlp\b|"
    r"guardrail(s)?\b|"
    r"sanitiza(r|ção|cao)\s*(via\s*)?regex|spotlight(ing)?|datamark(ing)?|data[\s-]?marking|"
    r"marker[\s-]?strip(ping)?|strip(ping)?\s+(the\s+)?markers?|remove[r]?\s+(as\s+)?tags|"
    r"ignore previous instructions|prompt[\s-]?only delimiter|delimitador de prompt|"
    r"xml[\s-]?(wrap|tag)|tag[\s-]?wrap(ping)?|sandwich(\s*(prompt|defen))?|"
    r"instruction[\s-]?defen(se|ce)|prompt[\s-]?sandwich|rebuff|prompt\s*armor|"
    r"injection classifier|classificador de injeç|detector classifier|"
    r"(adversarial|guardrail)\s+classifier|"
    r"llama\s*guard|prompt\s*guard|nemo\s*guardrails?)\b", re.I)

CONTROL_FRAME_RE = re.compile(
    r"\b(control(e|es)?|boundary|fronteira|mitiga(ç|c)(ão|ao|tion)|"
    r"\bfix\b|corrig|blinda|protege como|defesa contra|previne|barra|bloqueia o ataque|"
    r"garante|impede|neutraliza|elimina o risco|é suficiente|primeira linha de defesa|"
    r"resolve (o|a)|soluç(ão|ao)|é a defesa|as (the|a) (boundary|control))\b", re.I)

QUALIFIER_RE = re.compile(
    r"\b(telemetr\w*|telemetry|não é (uma )?(fronteira|controle|barreira)|"
    r"not a (boundary|control|wall)|defense[\s-]?in[\s-]?depth|defesa em profundidade|"
    r"signal only|só sinal|apenas sinal|sinal,? não|sinal apenas|higiene|hygiene|"
    r"adaptive asr|não é um controle de fronteira|only telemetry|"
    r"não resolve|nao resolve|não previne|não barra|não impede|não basta|"
    r"insuficiente|bypass|bypassáv|contorn|falha sob ataque adaptativo|"
    r"derrota(do|da)?\s+(por|sob)|asr\s*~?\s*9\d)\b", re.I)

# Explicit demotion: a compliant achado names the REAL boundary and then says the
# theater technique is NOT it ("a fronteira é dual-LLM, não filtro de input" /
# "the boundary is X, not the input filter"). A negation word adjacent to a theater
# term is itself the anti-theater stance and must pardon the block. This does NOT
# leak into a genuine violation ("o filtro de input resolve...") because that has no
# negation preceding the technique.
NEG_THEATER_RE = re.compile(
    r"\b(não|nao|nunca|not|never)\s+"
    r"(é\s+|e\s+|is\s+|são\s+|sao\s+)?"
    r"(o\s+|a\s+|os\s+|as\s+|um\s+|uma\s+|the\s+|an?\s+)?"
    r"(filtro de (input|entrada)|input[\s-]?filter|keyword\s*(filter|block|blocklist)|"
    r"blocklist|regex\s*(sanitiz|dlp|filter)|spotlight(ing)?|datamark(ing)?|"
    r"data[\s-]?marking|injection classifier|classificador de injeç|detector classifier|"
    r"llama\s*guard|prompt\s*guard|nemo\s*guardrails?)\b", re.I)


def check_anti_theater(blocks):
    """A block trips ONLY when it names a theater technique AND frames it as a
    control/boundary/fix AND has no telemetry qualifier in the same block. Requiring
    all three co-occurrences is the false-positive guard: 'datamarking — telemetria,
    não é fronteira; a fronteira é o dual-LLM' has the qualifier and no control-frame
    on the theater term, so it stays clean. A block that explicitly negates the theater
    technique ('a fronteira é dual-LLM, não filtro de input') is likewise pardoned."""
    hits = []
    for b in blocks:
        if (THEATER_RE.search(b) and CONTROL_FRAME_RE.search(b)
                and not QUALIFIER_RE.search(b) and not NEG_THEATER_RE.search(b)):
            hits.append(b)
    return hits


# --------------------------------------------------------------------------- #
# READ-ONLY — applied-change language / diff-patch block
# --------------------------------------------------------------------------- #

# First-person past-tense "I did it" verbs (pt-BR + English). Recommend-framed forms
# (recomendo, sugiro, deveria, projete, handoff, "o devops aplica", infinitive "aplicar")
# are deliberately NOT matched — a recommended command in backticks is a valid design
# handoff, not an applied change.
APPLIED_RE = re.compile(
    r"\b(apliquei|modifiquei|editei|criei o arquivo|criei o|removi|deletei|apaguei|"
    r"alterei|configurei|instalei|reiniciei|executei|rodei o comando|rodei|commitei|"
    r"fiz o (deploy|commit|patch|push)|dei push|subi (a|o|para)|patchei|"
    r"purguei|isolei|revoguei|fiz (o )?rollback|revert[ií] a memória|"
    r"já (apliquei|corrigi|rodei|mudei|ajustei)|corrigi (o|a|no)|ajustei o|"
    r"i (applied|modified|removed|deleted|created|ran|restarted|patched|fixed|"
    r"rolled back|purged|revoked|committed|deployed)|"
    r"(applied|restarted|patched|removed|deleted|revoked|purged|rolled back) (the|it))\b",
    re.I)

DIFF_RE = re.compile(
    r"(^```(diff|patch)\b|^diff --git |^--- a/|^\+\+\+ b/|^@@ .+ @@|^index [0-9a-f]{7})",
    re.I | re.M)


# --------------------------------------------------------------------------- #
# HEDGING (NOTE)
# --------------------------------------------------------------------------- #

HEDGES = ["provavelmente", "deve ser", "imagino que", "presumivelmente", "talvez",
          "acredito que", "parece que", "ao que tudo indica", "probably", "likely",
          "should be", "i assume", "presumably", "it seems", "appears to be",
          "my guess", "i believe"]


# --------------------------------------------------------------------------- #
# OVERLAP (NOTE) — two flavors: sec-reviewer audit, incident-responder live triage
# --------------------------------------------------------------------------- #

SECREVIEW_RE = re.compile(
    r"(\.env\b.*\b(600|640|644|permiss|chmod)|chmod\s*0?6[0-4]0\b|"
    r"permitrootlogin\s*(no|yes)|passwordauthentication\s*(no|yes)|"
    r"\bCVE-\d{4}-\d+|deve ser (0?600|0?640)|OWASP.*(audit|top[\s-]?10 gap)|audite? (o|a|os))",
    re.I)

INCIDENT_RE = re.compile(
    r"\b(isolei|matei o processo|bani o ip|erradiquei|contive (agora|já)|"
    r"kill\s+-9|root cause|fiz o root[\s-]?cause|purguei (a memória|agora)|"
    r"revoguei (a|as) credenc\w*|isolei o host)\b", re.I)


# --------------------------------------------------------------------------- #
# EVIDENCE (NOTE) — anchor presence per achado; optional invented-path proxy
# --------------------------------------------------------------------------- #

FILELINE_RE = re.compile(r"\S+:\d+")
ARROW_RE = re.compile(r"→|->")
BACKTICK_RE = re.compile(r"`[^`]+`")


def achado_has_anchor(raw: str) -> bool:
    return bool(FILELINE_RE.search(raw) or ARROW_RE.search(raw) or BACKTICK_RE.search(raw))


# --------------------------------------------------------------------------- #
# Validate
# --------------------------------------------------------------------------- #

def validate(text: str, mode="terse", artifact=None):
    sections = split_sections(text)
    violations, notes = [], []

    body = find_section(sections, "### ACHADOS") or ""
    prox = find_section(sections, "### PRÓXIMO PASSO") or ""
    achados = parse_achados(body)

    # 1. CONTRACT (BLOCKING) ------------------------------------------------- #
    first = next((l for l in text.splitlines() if l.strip()), "")
    if not first.strip().startswith("### ACHADOS"):
        violations.append(("CONTRACT", "preâmbulo: primeira linha não-vazia não é '### ACHADOS'"))

    if find_section(sections, "### PRÓXIMO PASSO") is None:
        violations.append(("CONTRACT", "seção obrigatória ausente: '### PRÓXIMO PASSO'"))

    for a in achados:
        if a["label"] is None:
            violations.append(("CONTRACT",
                               f"achado sem severidade [CRITICAL|HIGH|MEDIUM|LOW]: {a['raw'][:70]}"))

    # 4-level severity ordering — NOTE, not blocking. Full non-increasing check
    # (monotonic), not just first==max, so [CRITICAL, LOW, HIGH] is flagged too.
    labeled = [a["label"] for a in achados if a["label"]]
    ranks = [SEVERITY_RANK[l] for l in labeled]
    if ranks and any(ranks[i] < ranks[i + 1] for i in range(len(ranks) - 1)):
        notes.append(("CONTRACT-ORDER",
                      f"achados fora de ordem de severidade (deve ser não-crescente): "
                      f"{labeled}"))

    # Token budget on BODY only. Empty/trivial ACHADOS skips the budget.
    body_empty = (not achados) and (body.strip().lower() in EMPTY_ACHADOS)
    n_tok = approx_tokens(body)
    cap = BUDGET.get(mode, BUDGET["terse"])
    if not body_empty and n_tok > cap:
        violations.append(("CONTRACT",
                           f"corpo ACHADOS ~{n_tok} tok > orçamento {mode} ({cap} tok)"))

    # 2. ANTI-THEATER (BLOCKING) — scan BODY and PRÓXIMO PASSO --------------- #
    blocks = bullet_blocks(body) + bullet_blocks(prox)
    theater_hits = check_anti_theater(blocks)
    for b in theater_hits:
        one = " ".join(b.split())
        violations.append(("ANTI-THEATER",
                           f"técnica de teatro vendida como fronteira/controle sem "
                           f"qualificador de telemetria: {one[:90]}"))

    # 3. READ-ONLY (BLOCKING) — whole output -------------------------------- #
    m_applied = APPLIED_RE.search(text)
    if m_applied:
        violations.append(("READ-ONLY",
                           f"linguagem de mudança aplicada ('{m_applied.group(0)}'): "
                           f"o agente executou em vez de recomendar"))
    if DIFF_RE.search(text):
        violations.append(("READ-ONLY",
                           "bloco diff/patch presente: o agente entregou mudança aplicada, não design"))

    # 5. HEDGING (NOTE) — BODY + PRÓXIMO PASSO ------------------------------ #
    hedge_scope = body + "\n" + prox
    for h in HEDGES:
        if re.search(r"\b" + re.escape(h) + r"\b", hedge_scope, re.I):
            notes.append(("HEDGING",
                          f"'{h}' no corpo — confirme se é grounding (proibido) ou label calibrado"))

    # 6. OVERLAP (NOTE) — two flavors --------------------------------------- #
    if SECREVIEW_RE.search(text):
        notes.append(("OVERLAP",
                      "achado estilo hardening/audit — pertence ao security-reviewer; "
                      "mapeie ao controle detectivo, não re-audite"))
    if INCIDENT_RE.search(text):
        notes.append(("OVERLAP",
                      "verbo de triage ao vivo — pertence ao incident-responder; "
                      "autore a prontidão, não execute"))

    # 7. EVIDENCE (NOTE) — anchor presence + optional invented-path proxy --- #
    art_text = None
    if artifact:
        try:
            with open(artifact, encoding="utf-8", errors="replace") as fh:
                art_text = fh.read()
        except OSError as e:
            notes.append(("EVIDENCE", f"--artifact ilegível ({e}); pulando proxy de path inventado"))
    for a in achados:
        if not achado_has_anchor(a["raw"]):
            notes.append(("EVIDENCE",
                          f"achado sem âncora file:line / comando→output / citação do artefato: "
                          f"{a['raw'][:70]}"))
        elif art_text is not None:
            for fl in FILELINE_RE.findall(a["raw"]):
                fname = fl.rsplit(":", 1)[0]
                base = fname.split("/")[-1]
                if base and base not in art_text and fname not in art_text:
                    notes.append(("EVIDENCE",
                                  f"âncora file:line '{fl}' ausente do artefato — "
                                  f"possível path inventado (verificação profunda = Layer-2)"))

    return {
        "mode": mode,
        "sections": list(sections.keys()),
        "n_achados": len(achados),
        "n_tokens_body": n_tok,
        "budget": cap,
        "theater_hits": theater_hits,
        "violations": violations,
        "notes": notes,
    }


# --------------------------------------------------------------------------- #
# --fix — demote flagged theater bullets (mirror of deep-researcher apply_fix)
# --------------------------------------------------------------------------- #

FIX_COMMENT = "  <!-- anti-theater: rotule como telemetria, não fronteira -->"


def apply_fix(text: str, res) -> str:
    out = text
    for b in res["theater_hits"]:
        first_line = b.splitlines()[0]
        if first_line in out and FIX_COMMENT not in out:
            out = out.replace(first_line, first_line + FIX_COMMENT, 1)
    return out


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _arg_value(args, flag, default):
    if flag in args:
        i = args.index(flag)
        if i + 1 < len(args):
            return args[i + 1]
    return default


def main():
    args = sys.argv[1:]
    as_json = "--json" in args
    do_fix = "--fix" in args
    mode = _arg_value(args, "--mode", "terse")
    if mode not in BUDGET:
        mode = "terse"
    artifact = _arg_value(args, "--artifact", None)

    consumed_values = set()
    for flag in ("--mode", "--artifact"):
        if flag in args:
            i = args.index(flag)
            if i + 1 < len(args):
                consumed_values.add(i + 1)
    paths = [a for i, a in enumerate(args)
             if not a.startswith("--") and i not in consumed_values]

    text = open(paths[0], encoding="utf-8", errors="replace").read() if paths else sys.stdin.read()

    res = validate(text, mode=mode, artifact=artifact)

    if do_fix:
        sys.stdout.write(apply_fix(text, res))
        return 1 if res["violations"] else 0

    if as_json:
        report = {
            "mode": res["mode"],
            "sections": res["sections"],
            "n_achados": res["n_achados"],
            "n_tokens_body": res["n_tokens_body"],
            "budget": res["budget"],
            "violations": [{"check": c, "msg": m} for c, m in res["violations"]],
            "notes": [{"check": c, "msg": m} for c, m in res["notes"]],
        }
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"mode={res['mode']}  achados={res['n_achados']}  "
              f"body~{res['n_tokens_body']}tok/{res['budget']}  headers={res['sections']}")
        if res["violations"]:
            print("\nVIOLATIONS (block):")
            for cat, msg in res["violations"]:
                print(f"  [{cat}] {msg}")
        if res["notes"]:
            print("\nNOTES (review):")
            for cat, msg in res["notes"]:
                print(f"  [{cat}] {msg}")
        if not (res["violations"] or res["notes"]):
            print("\nCLEAN — passes the deterministic floor.")

    return 1 if res["violations"] else 0


if __name__ == "__main__":
    sys.exit(main())

