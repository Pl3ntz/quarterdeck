#!/bin/bash
# Auto-Learning: Error Detection Hook (PostToolUse on Bash)
# Detects command errors from output patterns, logs to error-events.jsonl
# Returns systemMessage to inject error context into Claude's conversation
#
# I/O Contract (PostToolUse):
# - Input: JSON via stdin (tool_name, tool_input, tool_result)
# - Output: JSON with optional systemMessage (context injection)
# - Exit 0: success

input=$(cat)

# Process synchronously to return systemMessage when error detected
echo "$input" | python3 -c "
import sys, json, os
from datetime import datetime

try:
    data = json.load(sys.stdin)
    tool = data.get('tool_name', data.get('tool', ''))
    tool_input = data.get('tool_input', {})

    # Claude Code envia 'tool_response' (Bash: dict com stdout/stderr/interrupted)
    # Fallbacks mantidos para compat futura
    tool_response = data.get('tool_response', data.get('tool_result', data.get('tool_output', data.get('result', ''))))

    interrupted = False
    stdout, stderr = '', ''
    if isinstance(tool_response, dict):
        stdout = tool_response.get('stdout', '') or ''
        stderr = tool_response.get('stderr', '') or ''
        interrupted = bool(tool_response.get('interrupted'))
        tool_output = (stdout + '\n' + stderr).strip()
    else:
        tool_output = str(tool_response or '')
        stdout = tool_output  # legacy fallback

    if tool != 'Bash':
        print(json.dumps({}))
        sys.exit(0)

    command = tool_input.get('command', '')

    # Detecta se o comando e' um log/file read — nesses casos NUNCA flaggar com base
    # em stdout (o conteudo lido pode conter texto de erros antigos).
    # stderr ainda e' checado (read pode falhar com 'Permission denied' real).
    cmd_start = command.strip().split('|')[0].strip().split('&&')[0].strip().split(';')[0].strip()
    log_read_prefixes = ('cat ', 'tail ', 'head ', 'less ', 'more ', 'grep ', 'rg ', 'ag ', 'view ')
    is_log_read = any(cmd_start.startswith(p) for p in log_read_prefixes)

    # Strong error indicators (high confidence only)
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

    is_error = False
    matched_pattern = ''

    log_dir = os.path.expanduser('~/.claude/logs')
    os.makedirs(log_dir, exist_ok=True)

    # Interrupted (timeout / user cancel) = erro forte
    if interrupted:
        is_error = True
        matched_pattern = 'interrupted'

    # Match patterns: stderr first (erros reais — tracebacks, npm ERR!, bash errors).
    # Stdout fallback APENAS se stderr vazio E nao for um log-read (evita matchar
    # texto de erro em arquivos de log que estamos apenas lendo).
    if not is_error:
        if stderr.strip():
            primary = stderr
        elif not is_log_read:
            primary = stdout
        else:
            primary = ''
        if primary:
            for pattern in strong_patterns:
                if pattern.lower() in primary.lower():
                    is_error = True
                    matched_pattern = pattern
                    break

    # Log ALL commands to command-history.jsonl (for resolution detection)
    history_file = os.path.join(log_dir, 'command-history.jsonl')
    try:
        hist_entry = json.dumps({
            'timestamp': datetime.now().isoformat(),
            'command': command[:300],
            'success': not is_error,
        })
        with open(history_file, 'a') as hf:
            hf.write(hist_entry + '\n')
        # Rotate: keep last 200 lines
        try:
            with open(history_file, 'r') as hf:
                lines = hf.readlines()
            if len(lines) > 200:
                with open(history_file, 'w') as hf:
                    hf.writelines(lines[-200:])
        except Exception:
            pass
    except Exception:
        pass

    if not is_error:
        print(json.dumps({}))
        sys.exit(0)

    # Extract error snippet (first 500 chars)
    error_snippet = tool_output[:500].strip()

    # Classify error category
    category = 'unknown'
    category_map = {
        'config': ['KeyError:', 'environment', 'env', '.env', 'config'],
        'syntax': ['SyntaxError:', 'IndentationError:'],
        'dependency': ['ModuleNotFoundError:', 'ImportError:', 'No module named'],
        'permission': ['Permission denied', 'EACCES', 'PermissionError:'],
        'connection': ['Connection refused', 'ConnectionRefusedError:', 'ECONNREFUSED'],
        'file': ['No such file or directory', 'ENOENT', 'FileNotFoundError:'],
        'type': ['TypeError:', 'AttributeError:', 'NameError:'],
        'memory': ['out of memory', 'OOMKilled'],
        'logic': ['ValueError:', 'AssertionError:', 'IndexError:'],
        'tooling': ['command not found', 'core dumped', 'segmentation fault', 'killed', 'npm ERR!', 'error TS'],
    }

    output_lower = tool_output.lower()
    for cat, indicators in category_map.items():
        for ind in indicators:
            if ind.lower() in output_lower:
                category = cat
                break
        if category != 'unknown':
            break

    # Log to JSONL
    log_file = os.path.join(log_dir, 'error-events.jsonl')

    entry = {
        'timestamp': datetime.now().isoformat(),
        'tool': 'Bash',
        'command': command[:300],
        'matched_pattern': matched_pattern,
        'category': category,
        'error_snippet': error_snippet,
        'status': 'unresolved',
    }

    with open(log_file, 'a') as f:
        f.write(json.dumps(entry) + '\n')

    # Gatilho event-driven: erro novo logado -> dispara a ponte erro->regra.
    # Detached/non-blocking (nao atrasa o hook); single-flight via lock fcntl
    # dentro da propria ponte garante que disparos concorrentes nao se atropelem.
    try:
        import subprocess
        bridge_path = os.path.join(
            os.path.expanduser('~/.claude/scripts/improvement'),
            'error_to_rule_bridge.py',
        )
        if os.path.exists(bridge_path):
            bridge_log = open(os.path.join(log_dir, 'bridge.log'), 'a')
            subprocess.Popen(
                ['python3', bridge_path],
                stdout=bridge_log,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
    except Exception:
        pass

    # Check error-index for known solution
    index_file = os.path.join(log_dir, 'error-index.md')
    known_fix = ''
    if os.path.exists(index_file):
        try:
            with open(index_file, 'r') as f:
                index_content = f.read()
            # Search for category section and matching pattern
            if '## ' + category in index_content:
                section = index_content.split('## ' + category)[1].split('## ')[0] if '## ' + category in index_content else ''
                for line in section.split('\n'):
                    if matched_pattern.lower().split(':')[0].lower() in line.lower() and line.strip().startswith(('1.', '2.', '3.', '4.', '5.', '6.', '7.', '8.', '9.', '10.')):
                        known_fix = line.strip()
                        break
        except Exception:
            pass

    # Return systemMessage with error context
    msg = f'[Auto-Learning] Erro detectado ({category}): {matched_pattern}'
    if known_fix:
        msg += f' | Solucao conhecida: {known_fix}'
    else:
        msg += ' | Consulte ~/.claude/logs/error-index.md antes de tentar resolver.'

    print(json.dumps({
        'systemMessage': msg
    }))

except Exception:
    print(json.dumps({}))
" 2>/dev/null
