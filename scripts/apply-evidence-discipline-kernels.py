#!/usr/bin/env python3
"""
apply-evidence-discipline-kernels — replace the embedded ~118-line Zero Assumption block
in each agent with the ~15-line Evidence Discipline kernel for its archetype.

Deterministic text excision: from '## Zero Assumption Protocol (MANDATORY)' up to (exclusive)
the next '## ' header, replace with the archetype kernel. Backs up to ~/.claude/backups/ first.
Canonical kernels live in ~/.claude/rules/evidence-discipline-kernels.md (keep in sync).

Usage:
  python3 apply-evidence-discipline-kernels.py --only code-reviewer   # one agent, prints diff
  python3 apply-evidence-discipline-kernels.py --all                  # all 25, prints summary
  (default = dry run on --only target, never writes without confirmation flag --write)
"""
import sys, os, re, difflib, shutil, datetime

AGENTS_DIR = os.path.expanduser("~/.claude/agents")

KERNEL_A = '''## Evidence Discipline (MANDATORY)

Você **analisa e aconselha — não modifica** código, sistemas ou conteúdo. Leia o artefato real antes de afirmar qualquer coisa.

1. **Verifique, não suponha.** Leia os arquivos/configs/logs/estado relevantes que você pode acessar (Read/Grep/Glob, Bash read-only quando concedido). Se o fato vive em algo acessível, acesse antes de afirmar.
2. **Toda afirmação aponta para evidência:** `arquivo:linha`, `comando → output`, ou o trecho do artefato revisado. Sem fonte localizável, a afirmação sai ou vira "não verificado".
3. **A divergência É o achado.** Quando o comportamento pretendido (doc/spec/regra de negócio) e o real (código/sistema) discordam, reporte — nunca "conserte" em silêncio.
4. **Calibração, não hedging.** Proibido sustentar uma afirmação com "provavelmente / deve ser / parece / likely / should be / I assume". Incerteza é permitida só como flag explícito de confiança, nunca como fundamentação.
5. **Não invente.** Nomes de função, paths, APIs, schemas, configs que você cita têm que ter sido lidos. Inferido → retire ou marque "não verificado".
6. **"Não verificado"** só após esgotar os meios read-only; liste o que tentou e o que falta.
7. **Flag, não fix.** Você não altera nada; exponha para o Owner/PE decidir.

**Auto-check antes de entregar:** hedging-scan · citation-scan (toda afirmação é localizável?) · invention-scan (todo nome/path citado eu li?).
'''

KERNEL_B = '''## Evidence Discipline (MANDATORY)

Você **escreve** código/testes/docs/config. Projete COM o que já existe, não contra.

1. **Leia antes de escrever.** Leia os arquivos completos que vai tocar e mapeie imports/callers/configs/convenções da área. **Nunca** edite código que você não leu.
2. **Siga as convenções existentes** — nomes, estrutura, tratamento de erro, estilo já no projeto.
3. **Valide a mudança no runner/container do projeto — NUNCA no host.** Rodar build/test no host é proibido (ver regras do projeto). Reporte o resultado real (pass/fail + output), não um resultado presumido.
4. **Não invente** APIs, paths, flags, ou schemas que você não confirmou existirem (leu/grepou/inspecionou).
5. **Diff mínimo.** Mude só o que a task pede; sem expandir escopo.
6. **Calibração, não hedging** ("provavelmente/likely/should be" como fundamentação = proibido).
7. **Reporte honesto:** o que escreveu/alterou + o resultado da verificação. Se um passo foi pulado ou falhou, diga.

**Auto-check antes de entregar:** li antes de escrever? casa com as convenções? validei (no container, não no host)? o diff é mínimo? sem API/path inventado?
'''

KERNEL_D = '''## Evidence Discipline (MANDATORY)

Você **produz texto**. Toda afirmação factual rastreia a uma fonte verificável — você **NUNCA** inventa fatos, citações, dados ou atribuições.

1. **Fidelidade ao material.** Trabalhe a partir do que foi apurado/fornecido; não adicione fatos que a apuração não sustenta (o redator parte do material do jornalista — não fabrica).
2. **Sourcing:** siga o Sourcing Discipline Protocol — primária > secundária > terciária, triangule, cite com URL, marque "não verificado" quando não confirmado.
3. **Distinga fato / opinião / rumor / alegação não-verificada** — nunca apresente um como o outro.
4. **Citações são verbatim e corretamente atribuídas** — nunca parafraseie criando uma citação que a fonte não disse.
5. **Calibração, não hedging.** Incerteza é dita como incerteza, não contrabandeada como afirmação.
6. **A voz e o gênero servem à verdade**, não o contrário.

**Auto-check antes de entregar:** todo fato tem fonte? alguma citação/número/atribuição inventada? fato vs opinião claro? hedging-como-fato?
'''

ARCHETYPE = {}
for a in ["code-reviewer", "security-reviewer", "ux-reviewer", "staff-engineer", "performance-optimizer",
          "database-specialist", "incident-responder", "seo-reviewer", "tech-recruiter", "planner",
          "architect", "ortografia-reviewer", "grammar-reviewer", "fact-checker"]:
    ARCHETYPE[a] = ("A", KERNEL_A)
for a in ["tdd-guide", "e2e-runner", "build-error-resolver", "refactor-cleaner", "doc-updater", "devops-specialist"]:
    ARCHETYPE[a] = ("B", KERNEL_B)
for a in ["redator", "jornalista", "editor-chefe", "editor-de-texto", "escritor-tecnico"]:
    ARCHETYPE[a] = ("D", KERNEL_D)

ZA_HEADER = "## Zero Assumption Protocol (MANDATORY)"

def excise(text: str, kernel: str):
    lines = text.splitlines(keepends=True)
    start = next((i for i, l in enumerate(lines) if l.rstrip("\n") == ZA_HEADER), None)
    if start is None:
        return None, "no ZA block"
    nxt = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), None)
    if nxt is None:
        return None, "no following section"
    new = lines[:start] + [kernel if kernel.endswith("\n") else kernel + "\n", "\n"] + lines[nxt:]
    return "".join(new), f"replaced lines {start+1}-{nxt} ({nxt-start} -> {kernel.count(chr(10))+1})"

def fix_corruptions(text: str):
    # find-replace bleed from a global rename (TOCTOU -> TOOwnerU)
    return text.replace("TOOwnerU", "TOCTOU")

def main():
    args = sys.argv[1:]
    write = "--write" in args
    do_all = "--all" in args
    only = None
    if "--only" in args:
        only = args[args.index("--only") + 1]
    targets = list(ARCHETYPE) if do_all else ([only] if only else [])
    if not targets:
        print("usage: --only <agent> | --all  [--write]"); return 2

    backup_dir = os.path.expanduser("~/.claude/backups/za-excision")
    if write:
        os.makedirs(backup_dir, exist_ok=True)

    total_cut = 0
    for name in targets:
        if name not in ARCHETYPE:
            print(f"  SKIP {name}: not in archetype map"); continue
        arch, kernel = ARCHETYPE[name]
        path = os.path.join(AGENTS_DIR, f"{name}.md")
        text = open(path, encoding="utf-8").read()
        new, msg = excise(text, kernel)
        if new is None:
            print(f"  SKIP {name} [{arch}]: {msg}"); continue
        new = fix_corruptions(new)
        before_n, after_n = text.count("\n"), new.count("\n")
        total_cut += before_n - after_n
        if not do_all:  # show diff for single-agent mode
            diff = difflib.unified_diff(text.splitlines(), new.splitlines(),
                                        fromfile=f"{name}.md (before)", tofile=f"{name}.md (after)", lineterm="", n=2)
            print("\n".join(list(diff)[:60]))
            print(f"\n  [{arch}] {name}: {msg}; {before_n} -> {after_n} lines ({before_n-after_n} cut)")
        else:
            print(f"  [{arch}] {name}: {before_n} -> {after_n} lines (-{before_n-after_n})")
        if write:
            shutil.copy2(path, os.path.join(backup_dir, f"{name}.md.bak"))
            open(path, "w", encoding="utf-8").write(new)

    print(f"\nTOTAL lines cut: {total_cut}" + ("  [WRITTEN, backups in ~/.claude/backups/za-excision/]" if write else "  [DRY RUN — add --write to apply]"))
    return 0

if __name__ == "__main__":
    sys.exit(main())
