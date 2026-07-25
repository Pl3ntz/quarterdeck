# Git

Conventional commits: `<type>: <description>`, types `feat|fix|refactor|docs|test|chore|perf|ci`.

Attribution trailers are disabled — do not add `Co-Authored-By` or "Generated with" lines.

**Never `git add -A` in the quarterdeck mirror.** It is a public repo behind a leak guard;
stage explicit paths. See the leak-guard memory for what the guard blocks and why.

For PRs, diff the whole branch (`git diff <base>...HEAD`), not just the last commit.
