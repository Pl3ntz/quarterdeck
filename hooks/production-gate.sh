#!/bin/bash
# Production Gate — Mechanical PreToolUse Hook
# Blocks destructive commands on production server
#
# Configuration: ~/.claude/hooks/production-gate.conf
# The conf file contains YOUR server aliases/IPs (not versioned)
#
# Strategy: ALLOWLIST for SSH to prod (default-deny)
# - Only read-only commands pass without approval
# - Everything else is BLOCKED with message to CTO
# - Also blocks scp/rsync/sftp to prod
# - Local commands are free (except catastrophic rm/git reset)
#
# I/O Contract (PreToolUse):
# - Input: JSON via stdin (tool_name, tool_input)
# - Output: JSON with permissionDecision deny to block, {} to allow
# - Exit 0 always

input=$(cat)

# Load configuration
CONF_FILE="$HOME/.claude/hooks/production-gate.conf"
if [ ! -f "$CONF_FILE" ]; then
  # No config = no protection (user hasn't set up yet)
  echo '{}'
  exit 0
fi

PROD_ALIASES=$(grep '^PROD_ALIASES=' "$CONF_FILE" | cut -d= -f2-)
PROD_GREP=$(grep '^PROD_GREP=' "$CONF_FILE" | cut -d= -f2-)

if [ -z "$PROD_ALIASES" ] || [ -z "$PROD_GREP" ]; then
  echo '{}'
  exit 0
fi

# Fast path: extract command
command=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)

if [ -z "$command" ]; then
  echo '{}'
  exit 0
fi

# Fast path: if command doesn't mention any prod alias, allow (unless catastrophic local)
if ! echo "$command" | grep -qiE "$PROD_GREP"; then
  if echo "$command" | grep -qE 'rm\s+-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*\s+(/|~|\$HOME)\b|git\s+reset\s+--hard|git\s+clean\s+-[a-zA-Z]*f'; then
    echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"PRODUCTION GATE: Comando local destrutivo detectado. Confirme com o CTO antes de executar."}'
    exit 0
  fi
  echo '{}'
  exit 0
fi

# SSH/SCP/RSYNC/SFTP to prod detected — run full Python analysis
echo "$input" | PROD_ALIASES="$PROD_ALIASES" python3 -c "
import sys, json, re, os

data = json.load(sys.stdin)
command = data.get('tool_input', {}).get('command', '')

# Read aliases from environment (passed from bash)
aliases_str = os.environ.get('PROD_ALIASES', '')
PROD_PATTERN = aliases_str if aliases_str else 'prod_server'

def deny(reason):
    msg = f'PRODUCTION GATE: {reason}. Peca aprovacao ao CTO antes de executar.'
    print(json.dumps({
        'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny'},
        'systemMessage': msg
    }))
    sys.exit(0)

def allow():
    print(json.dumps({}))
    sys.exit(0)

# --- BLOCK: scp, rsync, sftp to prod ---
if re.search(rf'^(scp|rsync|sftp)\b', command) and re.search(PROD_PATTERN, command):
    deny('Transferencia de arquivo para servidor de producao bloqueada')

# --- CHECK: SSH to prod (with optional user@ prefix) ---
ssh_match = re.search(rf'ssh\s+(?:.*\s+)?(?:\w+@)?({PROD_PATTERN})(?:\s|$)', command)
if not ssh_match:
    allow()

# Extract the remote command
remote_cmd = ''
quoted_match = re.search(rf'ssh\s+(?:.*\s+)?(?:\w+@)?(?:{PROD_PATTERN})\s+[\"\x27](.+?)[\"\x27]\s*$', command)
if quoted_match:
    remote_cmd = quoted_match.group(1)
else:
    unquoted_match = re.search(rf'ssh\s+(?:.*\s+)?(?:\w+@)?(?:{PROD_PATTERN})\s+(.+)$', command)
    if unquoted_match:
        remote_cmd = unquoted_match.group(1)

# Clean escaped quotes
remote_cmd = remote_cmd.replace('\\\\\"', '\"').replace(\"\\\\\\\\\\'\" , \"'\").replace('\\\\\\\\', '\\\\')

# No remote command = interactive SSH = BLOCK
if not remote_cmd.strip():
    deny('SSH interativo para producao bloqueado')

# --- DENY OVERRIDES: always block these patterns ---
DENY_OVERRIDES = [
    # Shell redirect: > or >> followed by path-like target.
    # Matches /, ~/, ./, ../, \$VAR, or filename with known extension.
    # Does NOT match SQL operators (x > 5, name > 'foo') or stderr redirects (2>&1).
    (r'\s>\s*(?:/|~/|\./|\.\./|\$[A-Za-z_]|[\w.-]+\.(?:log|txt|out|err|conf|cfg|json|yaml|yml|env|sh|py|md|csv|dat|bak|tmp|pid|sock|sql))', 'Redirecionamento de output para arquivo'),
    (r'\s>>\s*(?:/|~/|\./|\.\./|\$[A-Za-z_]|[\w.-]+\.(?:log|txt|out|err|conf|cfg|json|yaml|yml|env|sh|py|md|csv|dat|bak|tmp|pid|sock|sql))', 'Append para arquivo'),
    (r'\|\s*tee\s', 'Pipe to tee (escrita em arquivo)'),
    (r'\|\s*sudo\s', 'Pipe to sudo'),
    (r'\|\s*bash', 'Pipe to bash (execucao arbitraria)'),
    (r'\|\s*sh\b', 'Pipe to sh (execucao arbitraria)'),
    (r'base64.*\|\s*(bash|sh)', 'Execucao via base64 decode'),
    (r'\beval\s', 'eval (execucao arbitraria)'),
    (r'\bbash\s+-c\s', 'bash -c (execucao indireta)'),
    (r'\bsh\s+-c\s', 'sh -c (execucao indireta)'),
    (r'\bpython3?\s+-c\s', 'python -c (execucao indireta)'),
    (r'\bperl\s+-e\s', 'perl -e (execucao indireta)'),
    (r'\bnohup\s', 'nohup (execucao em background)'),
]

for pattern, reason in DENY_OVERRIDES:
    if re.search(pattern, remote_cmd):
        deny(f'{reason} em producao')

# --- ALLOWLIST: only these read-only commands pass ---
READ_ONLY = [
    r'^cat\s+\S',
    r'^less\s',
    r'^head\s',
    r'^tail\s',
    r'^ls(\s|$)',
    r'^find\s+\S+.*(?!-exec)',
    r'^stat\s',
    r'^wc\s',
    r'^du\s',
    r'^df(\s|$)',
    r'^tree(\s|$)',
    r'^ps(\s|$)',
    r'^top\s+-bn',
    r'^free(\s|$)',
    r'^uptime(\s|$)',
    r'^uname(\s|$)',
    r'^whoami(\s|$)',
    r'^hostname(\s|$)',
    r'^id(\s|$)',
    r'^w(\s|$)',
    r'^lsof\s',
    r'^ss\s',
    r'^netstat\s',
    r'^curl\s+(?!.*(-X\s*(POST|PUT|DELETE|PATCH)|--data|-d\s)).*https?://',
    r'^systemctl\s+(status|show|is-active|is-enabled|list-units|list-timers)',
    r'^journalctl\s',
    r'^timedatectl(\s|$)',
    r'^git\s+(status|log|diff|branch|show|remote\s+-v|stash\s+list|rev-parse)',
    r'^grep\s',
    r'^egrep\s',
    r'^fgrep\s',
    r'^rg\s',
    r'^ag\s',
    r'^(sudo\s+-u\s+postgres\s+)?psql\s.*-c\s+[\"\x27]?\s*(SELECT|SHOW|EXPLAIN|\\\\d|\\\\l|\\\\c|\\\\x|\\\\timing)',
    r'^echo\s',
    r'^date(\s|$)',
    r'^env(\s|$)',
    r'^printenv(\s|$)',
    r'^which\s',
    r'^type\s',
    r'^test\s',
    r'^pg_isready',
    r'^redis-cli\s+(ping|INFO|DBSIZE|CONFIG\s+GET)',
    r'^nginx\s+-[tT]',
    r'^openssl\s+s_client',
    r'^certbot\s+certificates',
]

# Handle command chains
chain_ops = re.split(r'\s*(?:&&|\|\||;)\s*', remote_cmd)

for sub_cmd in chain_ops:
    sub_cmd = sub_cmd.strip()
    if not sub_cmd:
        continue
    if re.match(r'^cd\s+\S+$', sub_cmd):
        continue
    if re.match(r'^set\s+[+-][a-z]$', sub_cmd):
        continue
    if re.match(r'^source\s+\S+\.env', sub_cmd):
        continue
    if re.match(r'^\.\s+\S+\.env', sub_cmd):
        continue

    allowed = False
    for pattern in READ_ONLY:
        if re.match(pattern, sub_cmd, re.IGNORECASE):
            allowed = True
            break

    if not allowed:
        first_word = sub_cmd.split()[0] if sub_cmd.split() else sub_cmd
        deny(f'Comando \"{first_word}\" nao esta na allowlist de comandos read-only para producao. Comando completo: {sub_cmd[:100]}')

allow()
" 2>/dev/null
python_exit=$?

if [ $python_exit -eq 0 ]; then
  exit 0
fi

# Fallback: if Python fails, BLOCK (fail-closed)
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny"},"systemMessage":"PRODUCTION GATE: Erro interno no hook de seguranca. Comando bloqueado por precaucao."}'
exit 0
