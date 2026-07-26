#!/bin/bash
# Auto-Learning: Resolution Detection Hook (PostToolUse on Bash)
# Detects when a previously logged error has been resolved by a successful command.
# Returns systemMessage confirming resolution was logged.
#
# I/O Contract (PostToolUse):
# - Input: JSON via stdin (tool_name, tool_input, tool_result)
# - Output: JSON with optional systemMessage (context injection)
# - Exit 0: success

input=$(cat)

# Process synchronously to return systemMessage when resolution detected
echo "$input" | python3 -c "
import sys, json, os, re
from datetime import datetime, timedelta

def exit_silent():
    print(json.dumps({}))
    sys.exit(0)

try:
    data = json.load(sys.stdin)
    tool = data.get('tool_name', data.get('tool', ''))
    tool_input = data.get('tool_input', {})

    # Claude Code envia 'tool_response' (Bash: dict com stdout/stderr/interrupted)
    tool_response = data.get('tool_response', data.get('tool_result', data.get('tool_output', data.get('result', ''))))

    interrupted = False
    if isinstance(tool_response, dict):
        stdout = tool_response.get('stdout', '') or ''
        stderr = tool_response.get('stderr', '') or ''
        interrupted = bool(tool_response.get('interrupted'))
        tool_output = (stdout + '\n' + stderr).strip()
    else:
        tool_output = str(tool_response or '')

    if tool != 'Bash':
        exit_silent()

    # Comando interrompido nao e resolucao
    if interrupted:
        exit_silent()

    command = tool_input.get('command', '')
    if not command.strip():
        exit_silent()

    # Skip known non-error commands (same as detect-errors.sh)
    skip_prefixes = [
        'git status', 'git log', 'git diff', 'git branch',
        'ls', 'pwd', 'echo', 'which', 'type', 'whoami',
        'date', 'uptime', 'df', 'du', 'wc', 'head', 'tail',
    ]
    cmd_start = command.strip().split('|')[0].strip().split('&&')[0].strip()
    for skip in skip_prefixes:
        if cmd_start.startswith(skip):
            exit_silent()

    # Strong error indicators (same list as detect-errors.sh)
    strong_patterns = [
        'Traceback (most recent call last)',
        'ModuleNotFoundError:',
        'ImportError:',
        'SyntaxError:',
        'TypeError:',
        'NameError:',
        'ValueError:',
        'KeyError:',
        'AttributeError:',
        'FileNotFoundError:',
        'ConnectionRefusedError:',
        'PermissionError:',
        'OSError:',
        'IOError:',
        'command not found',
        'No such file or directory',
        'Permission denied',
        'Connection refused',
        'ENOENT',
        'EACCES',
        'FATAL:',
        'fatal:',
        'panic:',
        'segmentation fault',
        'core dumped',
        'killed',
        'out of memory',
        'RuntimeError:',
        'AssertionError:',
        'IndentationError:',
        'ECONNREFUSED',
        'npm ERR!',
        'error TS',
    ]

    # Check if output contains ANY error pattern — if so, NOT a success
    output_lower = tool_output.lower()
    for pattern in strong_patterns:
        if pattern.lower() in output_lower:
            exit_silent()  # Command had errors, not a resolution

    # --- Command succeeded. Check if it resolves a previous error. ---

    def normalize_command(cmd):
        \"\"\"Extract the main binary from a command string.\"\"\"
        parts = cmd.strip().split()
        skip = {'timeout', 'time', 'nice', 'env', 'sudo'}
        for p in parts:
            if '=' in p:
                continue  # env var like NODE_ENV=prod
            if p in skip:
                continue
            # Handle SSH: ssh prod_server python3 -> python3
            if p == 'ssh':
                # Find the binary after the host
                found_host = False
                for sp in parts[parts.index(p)+1:]:
                    if sp.startswith('-'):
                        continue
                    if not found_host:
                        found_host = True
                        continue
                    if '=' in sp:
                        continue
                    return sp.split('/')[-1]
            return p.split('/')[-1]
        return cmd.split()[0].split('/')[-1] if parts else ''

    log_dir = os.path.expanduser('~/.claude/logs')
    os.makedirs(log_dir, exist_ok=True)

    events_file = os.path.join(log_dir, 'error-events.jsonl')
    resolutions_file = os.path.join(log_dir, 'error-resolutions.jsonl')
    history_file = os.path.join(log_dir, 'command-history.jsonl')

    if not os.path.exists(events_file):
        exit_silent()

    # Read error events
    events = []
    try:
        with open(events_file, 'r') as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    events.append(json.loads(line))
                except Exception:
                    pass
    except Exception:
        exit_silent()

    if not events:
        exit_silent()

    now = datetime.now()
    cutoff = now - timedelta(seconds=7200)  # 2 hours window
    current_binary = normalize_command(command)

    if not current_binary:
        exit_silent()

    # Find unresolved errors with same binary within 2 hours
    matched_errors = []
    for evt in events:
        if evt.get('status') != 'unresolved':
            continue
        try:
            evt_time = datetime.fromisoformat(evt['timestamp'])
        except Exception:
            continue
        if evt_time < cutoff:
            continue
        error_binary = normalize_command(evt.get('command', ''))
        error_category = evt.get('category', '')
        # Match by binary AND category to reduce false positives
        if error_binary == current_binary and error_category:
            matched_errors.append(evt)

    if not matched_errors:
        exit_silent()

    # Use the most recent matching error
    matched_errors.sort(key=lambda e: e.get('timestamp', ''), reverse=True)
    matched_error = matched_errors[0]
    error_ts = matched_error['timestamp']

    # Collect fix candidates from command-history.jsonl (if it exists)
    fix_candidates = []
    try:
        if os.path.exists(history_file):
            error_time = datetime.fromisoformat(error_ts)
            with open(history_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                        entry_time = datetime.fromisoformat(entry.get('timestamp', ''))
                        if error_time < entry_time <= now:
                            cmd_text = entry.get('command', '')
                            if cmd_text and cmd_text != command:
                                fix_candidates.append(cmd_text[:200])
                    except Exception:
                        pass
    except Exception:
        pass

    # Limit to max 5 fix candidates
    fix_candidates = fix_candidates[-5:]

    # Build error summary from matched error
    error_summary = matched_error.get('matched_pattern', '')
    snippet = matched_error.get('error_snippet', '')
    if snippet:
        # Take first line of snippet for summary
        first_line = snippet.split('\n')[0][:150]
        if error_summary:
            error_summary = error_summary + ' — ' + first_line
        else:
            error_summary = first_line

    # Write resolution entry
    resolution = {
        'timestamp': now.isoformat(),
        'original_error_timestamp': error_ts,
        'category': matched_error.get('category', 'unknown'),
        'error_summary': error_summary[:300],
        'error_snippet': matched_error.get('error_snippet', '')[:500],
        'fix_candidates': fix_candidates,
        'resolved_by_command': command[:300],
        'reusable': None,
    }

    # Rotation: if resolutions file > 200 lines, remove oldest 100
    existing_resolutions = []
    try:
        if os.path.exists(resolutions_file):
            with open(resolutions_file, 'r') as f:
                existing_resolutions = [l for l in f.readlines() if l.strip()]
            if len(existing_resolutions) > 200:
                existing_resolutions = existing_resolutions[100:]
                with open(resolutions_file, 'w') as f:
                    f.writelines(existing_resolutions)
    except Exception:
        pass

    with open(resolutions_file, 'a') as f:
        f.write(json.dumps(resolution) + '\n')

    # Mark matched errors as resolved in error-events.jsonl
    updated_events = []
    resolved_timestamps = set(e['timestamp'] for e in matched_errors)
    for evt in events:
        if evt.get('timestamp') in resolved_timestamps and evt.get('status') == 'unresolved':
            evt = dict(evt)  # immutable copy
            evt['status'] = 'resolved'
        updated_events.append(evt)

    try:
        import fcntl
        with open(events_file, 'r+') as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            f.seek(0)
            f.truncate()
            for evt in updated_events:
                f.write(json.dumps(evt) + '\n')
            fcntl.flock(f, fcntl.LOCK_UN)
    except Exception:
        pass

    # Return systemMessage confirming resolution was logged
    cat = matched_error.get('category', 'unknown')
    msg = f'[Auto-Learning] Erro resolvido ({cat}): {error_summary[:100]}. Resolucao registrada em error-resolutions.jsonl.'
    if resolution.get('fix_candidates'):
        msg += f' Fix candidates: {len(resolution[\"fix_candidates\"])} comandos intermediarios capturados.'

    # systemMessage never reaches the model (see detect-errors.sh for the full note). The
    # ask is stated explicitly: a notification with no requested action produced 189 logged
    # resolutions and zero promotions.
    msg += ' Se o fix for reutilizavel, promova para ~/.claude/logs/error-index.md.'
    print(json.dumps({
        'systemMessage': msg,
        'hookSpecificOutput': {'hookEventName': 'PostToolUse', 'additionalContext': msg}
    }))

except Exception:
    print(json.dumps({}))
" 2>/dev/null
