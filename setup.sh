#!/bin/bash
#
# Quarterdeck Setup — Configure agents, rules, and hooks for your environment
#
# Usage: ./setup.sh
#
# This script:
# 1. Asks for your server and project details
# 2. Replaces placeholders in all agents, rules, and hooks
# 3. Installs everything to ~/.claude/
# 4. Configures hooks in settings.json
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Quarterdeck — Setup                         ║"
echo "║  26 agents, 8 squads, 14 hooks               ║"
echo "║  + 1 skill, 4 companion scripts              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

# ─── Step 1: Gather Configuration ───

echo "▸ Production Server Configuration"
echo "  (Leave blank to skip remote server features)"
echo ""

read -p "  SSH hostname or alias (e.g., my-server): " PROD_SERVER
read -p "  Server IP address (e.g., 1.2.3.4): " PROD_IP

if [ -n "$PROD_SERVER" ]; then
  echo ""
  echo "▸ Projects on $PROD_SERVER"
  echo "  Enter project names (leave blank to skip)"
  echo ""

  read -p "  Main project name (e.g., my-app): " PROJECT_A
  read -p "  Second project (optional): " PROJECT_B
  read -p "  Third project (optional): " PROJECT_C
  read -p "  Fourth project (optional): " PROJECT_D
  read -p "  Fifth project (optional): " PROJECT_E

  echo ""
  echo "▸ Service Names"
  echo ""

  read -p "  Main backend service (e.g., my-app-backend): " SVC_BACKEND
  read -p "  Scheduler service (optional): " SVC_SCHEDULER
  read -p "  Webhook service (optional): " SVC_WEBHOOK
  read -p "  Processor service (optional): " SVC_PROCESSOR
  read -p "  Notifier service (optional): " SVC_NOTIFIER
  read -p "  Frontend service (optional): " SVC_FRONTEND
  read -p "  Status service (optional): " SVC_STATUS

  echo ""
  read -p "  PostgreSQL version (e.g., 16, 17, 18): " PG_VERSION
fi

# ─── Step 2: Copy Files ───

echo ""
echo "▸ Installing to ~/.claude/ ..."

mkdir -p ~/.claude/agents ~/.claude/rules ~/.claude/hooks ~/.claude/skills ~/.claude/scripts

cp "$SCRIPT_DIR"/agents/*.md ~/.claude/agents/
cp "$SCRIPT_DIR"/rules/*.md ~/.claude/rules/
cp "$SCRIPT_DIR"/hooks/*.sh ~/.claude/hooks/
chmod 700 ~/.claude/hooks/*.sh

# Skills (vendored from borghei/Claude-Skills, see NOTICE.md)
if [ -d "$SCRIPT_DIR/skills" ]; then
  cp -R "$SCRIPT_DIR"/skills/* ~/.claude/skills/ 2>/dev/null || true
  echo "  Copied: $(find ~/.claude/skills -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') skills"
fi

# Utility scripts (vendored from borghei/Claude-Skills, see NOTICE.md)
if [ -d "$SCRIPT_DIR/scripts/borghei" ] || [ -d "$SCRIPT_DIR/scripts/improvement" ]; then
  [ -d "$SCRIPT_DIR/scripts/borghei" ] && mkdir -p ~/.claude/scripts/borghei && cp "$SCRIPT_DIR"/scripts/borghei/* ~/.claude/scripts/borghei/
  [ -d "$SCRIPT_DIR/scripts/improvement" ] && mkdir -p ~/.claude/scripts/improvement && cp "$SCRIPT_DIR"/scripts/improvement/* ~/.claude/scripts/improvement/
  find ~/.claude/scripts -name '*.py' -exec chmod +x {} +
  echo "  Copied: $(find ~/.claude/scripts/borghei ~/.claude/scripts/improvement -name '*.py' 2>/dev/null | wc -l | tr -d ' ') vendored scripts"
fi

echo "  Copied: $(ls "$SCRIPT_DIR"/agents/*.md | wc -l | tr -d ' ') agents"
echo "  Copied: $(ls "$SCRIPT_DIR"/rules/*.md | wc -l | tr -d ' ') rules"
echo "  Copied: $(ls "$SCRIPT_DIR"/hooks/*.sh | wc -l | tr -d ' ') hooks"

# ─── Step 3: Replace Placeholders ───

if [ -n "$PROD_SERVER" ]; then
  echo ""
  echo "▸ Configuring for $PROD_SERVER ..."

  # Server
  [ -n "$PROD_SERVER" ] && find ~/.claude/agents ~/.claude/rules ~/.claude/hooks -type f \( -name '*.md' -o -name '*.sh' \) -exec sed -i '' "s/prod_server/$PROD_SERVER/g" {} +
  [ -n "$PROD_IP" ] && find ~/.claude/hooks -type f -name '*.sh' -exec sed -i '' "s/<PROD_IP>/$PROD_IP/g" {} +

  # Projects
  [ -n "$PROJECT_A" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<project>/$PROJECT_A/g" {} +
  [ -n "$PROJECT_B" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<project-b>/$PROJECT_B/g" {} +
  [ -n "$PROJECT_C" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<project-c>/$PROJECT_C/g" {} +
  [ -n "$PROJECT_D" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<project-d>/$PROJECT_D/g" {} +
  [ -n "$PROJECT_E" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<project-e>/$PROJECT_E/g" {} +

  # Services
  [ -n "$SVC_BACKEND" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-backend>/$SVC_BACKEND/g" {} +
  [ -n "$SVC_SCHEDULER" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-scheduler>/$SVC_SCHEDULER/g" {} +
  [ -n "$SVC_WEBHOOK" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-webhook>/$SVC_WEBHOOK/g" {} +
  [ -n "$SVC_PROCESSOR" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-processor>/$SVC_PROCESSOR/g" {} +
  [ -n "$SVC_NOTIFIER" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-notifier>/$SVC_NOTIFIER/g" {} +
  [ -n "$SVC_FRONTEND" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-frontend>/$SVC_FRONTEND/g" {} +
  [ -n "$SVC_STATUS" ] && find ~/.claude/agents ~/.claude/rules -type f -name '*.md' -exec sed -i '' "s/<service-status>/$SVC_STATUS/g" {} +

  # PostgreSQL version
  [ -n "$PG_VERSION" ] && find ~/.claude/agents -type f -name '*.md' -exec sed -i '' "s/<version>/$PG_VERSION/g" {} +

  # Production gate hook — add server aliases
  if [ -n "$PROD_IP" ]; then
    sed -i '' "s|r'prod_server'|r'$PROD_SERVER'|; s|r'prod'|r'$(echo $PROD_SERVER | cut -d_ -f1)'|; s|r'<PROD_IP>'|r'$(echo $PROD_IP | sed 's/\./\\\\./g')'|" ~/.claude/hooks/production-gate.sh 2>/dev/null || true
  fi

  echo "  Replacements applied"
fi

# ─── Step 4: Configure Hooks in settings.json ───

echo ""
echo "▸ Configuring hooks in settings.json ..."

SETTINGS="$HOME/.claude/settings.json"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

python3 -c "
import json

with open('$SETTINGS') as f:
    s = json.load(f)

hooks = s.setdefault('hooks', {})

# PreToolUse hooks
pre = hooks.setdefault('PreToolUse', [])

# Bash hooks (production-gate, test-gate, block-build)
bash_entry = next((e for e in pre if e.get('matcher') == 'Bash'), None)
if not bash_entry:
    bash_entry = {'matcher': 'Bash', 'hooks': []}
    pre.append(bash_entry)

bash_hooks = bash_entry['hooks']
for cmd in [
    'bash $HOME/.claude/hooks/block-build.sh',
    'bash $HOME/.claude/hooks/production-gate.sh',
    'bash $HOME/.claude/hooks/test-gate.sh',
]:
    if not any(cmd in h.get('command', '') for h in bash_hooks):
        bash_hooks.append({'type': 'command', 'command': cmd})

# Task hooks (agent-recall-auto)
task_pre = next((e for e in pre if e.get('matcher') == 'Task'), None)
if not task_pre:
    task_pre = {'matcher': 'Task', 'hooks': []}
    pre.append(task_pre)
task_hooks = task_pre['hooks']
recall_cmd = 'bash $HOME/.claude/hooks/agent-recall-auto.sh'
if not any(recall_cmd in h.get('command', '') for h in task_hooks):
    task_hooks.append({'type': 'command', 'command': recall_cmd})

# PostToolUse hooks
post = hooks.setdefault('PostToolUse', [])

# Task tracking
task_post = next((e for e in post if e.get('matcher') == 'Task'), None)
if not task_post:
    task_post = {'matcher': 'Task', 'hooks': []}
    post.append(task_post)
tp_hooks = task_post['hooks']
track_cmd = 'bash $HOME/.claude/hooks/track-agent-spawn.sh'
if not any(track_cmd in h.get('command', '') for h in tp_hooks):
    tp_hooks.append({'type': 'command', 'command': track_cmd})

# Bash error detection
bash_post = next((e for e in post if e.get('matcher') == 'Bash'), None)
if not bash_post:
    bash_post = {'matcher': 'Bash', 'hooks': []}
    post.append(bash_post)
bp_hooks = bash_post['hooks']
for cmd in [
    'bash $HOME/.claude/hooks/detect-errors.sh',
    'bash $HOME/.claude/hooks/detect-resolutions.sh',
]:
    if not any(cmd in h.get('command', '') for h in bp_hooks):
        bp_hooks.append({'type': 'command', 'command': cmd})

# Stop hooks
stop = hooks.setdefault('Stop', [])
stop_entry = next((e for e in stop if e.get('matcher') == '*'), None)
if not stop_entry:
    stop_entry = {'matcher': '*', 'hooks': []}
    stop.append(stop_entry)
s_hooks = stop_entry['hooks']
for cmd in [
    'bash $HOME/.claude/hooks/verify-completion.sh',
    'bash $HOME/.claude/hooks/update-error-index.sh',
]:
    if not any(cmd in h.get('command', '') for h in s_hooks):
        s_hooks.append({'type': 'command', 'command': cmd})

with open('$SETTINGS', 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')

print('  Hooks configured in settings.json')
"

# ─── Step 5: Summary ───

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Setup Complete!                              ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Installed:"
echo "    $(ls ~/.claude/agents/*.md 2>/dev/null | wc -l | tr -d ' ') agents  → ~/.claude/agents/"
echo "    $(ls ~/.claude/rules/*.md 2>/dev/null | wc -l | tr -d ' ') rules   → ~/.claude/rules/"
echo "    $(ls ~/.claude/hooks/*.sh 2>/dev/null | wc -l | tr -d ' ') hooks   → ~/.claude/hooks/"
echo "    $(find ~/.claude/skills -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ') skills  → ~/.claude/skills/"
echo "    $(find ~/.claude/scripts/borghei ~/.claude/scripts/improvement -name '*.py' 2>/dev/null | wc -l | tr -d ' ') vendored scripts → ~/.claude/scripts/{borghei,improvement}/"
echo ""
echo "  Next steps:"
echo "    1. Start a new Claude Code session"
echo "    2. The PE (Principal Engineer) will orchestrate automatically"
echo "    3. Install local-mind plugin for shared agent memory:"
echo "       claude /install-plugin https://github.com/Pl3ntz/local-mind"
echo ""
echo "  Optional:"
echo "    - Edit ~/.claude/agents/*.md to customize agent behavior"
echo "    - Edit ~/.claude/rules/*.md to adjust team rules"
echo "    - Remaining <placeholder> values can be replaced as needed"
echo ""
