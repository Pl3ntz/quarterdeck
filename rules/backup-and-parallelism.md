# Backup Discipline + Parallelism Directive

> **Versao:** 1.0 (2026-05-27)
> **Aplica-se a:** PE main session E todos os 26 agents

## Backup Discipline

### Regra principal

**ANTES de criar qualquer backup de arquivo** (`.bak`, `.backup`, `cp`, `scp` de seguranca), o agent DEVE verificar se o diretorio/projeto esta sob controle de versao (git):

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

### Decisao baseada no resultado

| Situacao | Acao correta | Acao PROIBIDA |
|----------|-------------|---------------|
| **Git disponivel** | `git stash`, `git commit`, `git tag`, branch temporario | Criar `.bak`, `.backup`, `cp` de arquivos |
| **Sem git** | Backup de arquivo (`cp`, `.bak`) e legítimo | — |
| **Dados de banco (pg_dump, redis-cli)** | Backup SEMPRE necessario (git nao versiona dados) | Pular backup de DB |

### Anti-padroes proibidos

- Criar arquivos `.backup-YYYYMMDD-HHMMSS` em diretorios git-versionados
- Rodar `cp arquivo.conf arquivo.conf.bak` quando `git stash` ou `git commit` resolve
- Acumular backups manuais ao lado de arquivos versionados

### Excecoes legitimas

- Backup de banco de dados (pg_dump, mongodump, redis BGSAVE) — SEMPRE necessario
- Arquivos em servidores sem git (configs de sistema em /etc sem etckeeper)
- Quando o Owner pedir explicitamente backup de arquivo

## Parallelism Directive

### Regra principal

**SEMPRE maximize paralelismo de tool calls.** Quando multiplas operacoes sao independentes (sem dependencia de dados entre elas), execute-as em paralelo no mesmo bloco de resposta.

### Padroes obrigatorios

| Situacao | Acao correta | Acao PROIBIDA |
|----------|-------------|---------------|
| Ler 3 arquivos independentes | 3x `Read` em paralelo | Ler sequencialmente |
| Grep + Glob em areas distintas | Paralelo | Sequencial |
| Verificar estado (git status + docker ps + systemctl status) | Paralelo | Sequencial |
| Comando B depende do output de A | Sequencial (A depois B) | Paralelo com valor inventado |

### Checklist antes de cada resposta

1. Tenho 2+ tool calls independentes nesta resposta? Se sim, estao em paralelo?
2. Alguma tool call esta esperando resultado de outra? Se nao, paralelizar.
3. Posso agrupar reads/greps/globs independentes? Sim → mesmo bloco.
