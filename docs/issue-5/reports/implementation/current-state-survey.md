# issue-5 current-state survey — stub-check.sh vendored copy

Scout skip record: skipped. Spec leaves no design decision open — core #69
canon (`docs/handbooks/canon-scripts.md`, `docs/handbooks/role-gates-tests.md`
in `tokenmaxxxer-core`) fully dictates the required end state (reference
execution, exact invocation expression) and the manifest already lists
`stub-check.sh` as a file no rulebook may vendor. No comparable-product
research question exists here.

## What exists in this repo

- `secure-coding/hooks/tests/stub-check.sh` — vendored verbatim copy of
  core's `core/hooks/tests/stub-check.sh` (added by the issue-2 cutover,
  `docs/issue-2/proposals/core-canon-cutover.md` item 5, at a time when
  vendoring was the stated canon shape).
- `secure-coding/hooks/hooks.json` — only one entry, `SessionStart` →
  `directive.sh`. No `stub-check.sh` registration exists here (it is not a
  hook trigger, just a test-harness script), so no hooks.json edit is
  needed for removal — confirmed by reading the file directly.
- No `run-role-gates-tests.sh` or equivalent test harness file exists yet
  under `secure-coding/hooks/tests/` — `stub-check.sh` is the only test
  script vendored in this rulebook's tree today.
- No `docs/handbooks/canon-scripts.md` copy exists in this repo (correctly
  not vendored) — the canon doc lives only in `tokenmaxxxer-core`.

## Canon requirement (core #69)

- `core/hooks/tests/canon-manifest.txt` lists `stub-check.sh` itself as a
  manifest file — a vendored copy of it is exactly the drift the file's own
  header (self-referentially) is built to catch.
- `docs/handbooks/role-gates-tests.md` "Canon invocation from a rulebook"
  gives the exact reference-execution expression:
  `"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."`
  — first arg is the rulebook directory to scan; the script binary is never
  copied.

## Gap

This repo's `secure-coding/hooks/tests/stub-check.sh` is the vendored copy
canon now forbids. It must be deleted; nothing else in this tree currently
invokes it (no test harness file calls it yet), so removal has no
call-site to update — only the file itself goes.
