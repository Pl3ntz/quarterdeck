#!/bin/bash
# pin-mcp-servers.sh — replace the @latest MCP registrations with reviewed versions.
#
# OWASP ASI04 (agentic supply chain): `npx -y <pkg>@latest` resolves and installs the newest
# published version at every launch, with -y suppressing the install prompt. A compromised
# release of either package executes on this machine, with this user's privileges, without the
# version change ever being reviewed. Pinning does not pin integrity -- only a lockfile does --
# but it removes the silent auto-update path, which is the part that matters here.
#
# WHY THIS IS A SCRIPT AND NOT SOMETHING THE ASSISTANT RAN
#
# It cannot be run from inside a live Claude Code session. Attempted on 2026-07-25: the remove
# succeeded, the running session flushed its in-memory copy of ~/.claude.json back to disk
# before the add landed, and the add reported "already exists" against the restored @latest
# entry. The registration was silently unchanged. Every Claude Code session must be closed.
#
# USAGE
#   1. Close every Claude Code session (check: pgrep -fl "claude" | grep -v pin-mcp)
#   2. bash ~/.claude/scripts/pin-mcp-servers.sh
#   3. Start a session and confirm: claude mcp list
#
# Versions below were the resolved `latest` on 2026-07-25, so pinning to them is a
# zero-behaviour change: nothing is downgraded and no capability is lost. Both flags in use
# (--autoConnect, --caps vision,devtools) are present in these exact builds. To bump, change
# the version here and review the release diff first.

set -u

CDP_VERSION="1.6.0"
PW_VERSION="0.0.78"

if pgrep -f "claude" | grep -qv "$$" 2>/dev/null; then
  if pgrep -fl "claude" 2>/dev/null | grep -v "pin-mcp-servers" | grep -q .; then
    echo "A Claude Code process is still running. It will overwrite ~/.claude.json and this"
    echo "script will silently do nothing. Close every session first:"
    pgrep -fl "claude" 2>/dev/null | grep -v "pin-mcp-servers" | cut -c1-90 | sed 's/^/  /'
    exit 1
  fi
fi

# Warm the npx cache BEFORE re-registering. npx keys its cache on the spec string, so
# `pkg@1.6.0` is a different entry from `pkg@latest` even at the same version -- without this,
# the first launch after pinning does a cold ~13 MB + ~18 MB download and can look like a
# broken server.
echo "Warming npx cache for the pinned specs..."
npx -y "chrome-devtools-mcp@${CDP_VERSION}" --version >/dev/null 2>&1 \
  || { echo "FAILED to fetch chrome-devtools-mcp@${CDP_VERSION} — aborting, nothing changed."; exit 1; }
npx -y "@playwright/mcp@${PW_VERSION}" --version >/dev/null 2>&1 \
  || { echo "FAILED to fetch @playwright/mcp@${PW_VERSION} — aborting, nothing changed."; exit 1; }

echo "Re-registering chrome-devtools at ${CDP_VERSION}..."
claude mcp remove chrome-devtools -s user >/dev/null 2>&1
claude mcp add chrome-devtools -s user -- npx -y "chrome-devtools-mcp@${CDP_VERSION}" --autoConnect

echo "Re-registering playwright at ${PW_VERSION}..."
claude mcp remove playwright -s user >/dev/null 2>&1
claude mcp add playwright -s user -- npx -y "@playwright/mcp@${PW_VERSION}" --caps vision,devtools

echo
echo "Registered:"
for s in chrome-devtools playwright; do
  printf '  %-18s ' "$s"
  claude mcp get "$s" 2>&1 | grep -i '^ *Args' | sed 's/^ *Args: */args: /'
done

echo
if claude mcp get chrome-devtools 2>&1 | grep -q '@latest' \
   || claude mcp get playwright 2>&1 | grep -q '@latest'; then
  echo "STILL PINNED TO @latest — a session was running and overwrote the change. Close it and"
  echo "re-run. This is the documented failure mode, not a new problem."
  exit 1
fi

echo "Pinned. Takes effect on the next session start."
echo "A failed health check on first launch is most likely a cache miss, not a regression:"
echo "re-run the warm step above before concluding the pinned version is broken."
