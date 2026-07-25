# Backups

**Before creating any `.bak`, `.backup` or defensive `cp`, check whether the directory is
under git:**

```bash
git rev-parse --is-inside-work-tree 2>/dev/null
```

Under git, use git — `stash`, a commit, a tag, a throwaway branch. A `.backup-20260725`
sitting next to a versioned file is clutter that git already made unnecessary, and it
accumulates.

Two cases where a real backup is still required:

- **Database data** — `pg_dump`, `mongodump`, Redis `BGSAVE`. Git does not version data.
- **Server config outside git** — `/etc` without etckeeper, systemd units, nginx and Caddy
  config. These live on hosts covered by the production gate; back up before editing.

The Owner asking for a file backup explicitly overrides all of the above.
