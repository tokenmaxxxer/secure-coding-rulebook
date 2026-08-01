# asvs-verification level-gate

`asvs-verification/hooks/level-gate.sh` is a `PreToolUse` gate
(Write|Edit|MultiEdit) that fires only on writes resolving to
`docs/issue-<n>/proposals/*secure-coding*.md` (phase-1) or
`docs/issue-<n>/reports/secure-coding.md` (phase-2); every other path is
allowed without content evaluation. It sources core canon's
`gate-lib.sh`/`gate-lib.py`
(`${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh || { echo ...; exit 2; }`,
core issue #75's guarded form) for the fail-closed EXIT trap, kill switch,
malformed-JSON deny, path normalization, and full Write/Edit/MultiEdit
reconstruction (honoring `replace_all` per-edit) — none of that machinery
is re-derived locally. A failed source (missing/misconfigured core
checkout) exits 2 immediately rather than continuing with `gate_*`
functions undefined (issue-16 fix; regression-tested by
`missing-core-fail-closed`, below). Root resolution stays local:
`CLAUDE_PROJECT_DIR` if set and a real directory, else `git rev-parse
--show-toplevel` — never derived from the tool call's own `file_path`.

Phase-1 requires, in order: an ASVS level token (`L1`/`L2`/`L3`) within 60
characters of the word "level" on the same line, before the first ASVS
requirement ID (`V\d+(\.\d+){1,3}`), at least one requirement ID, and a
survey reference (the `current-state-survey` artifact token / a path
citation outright, or a generic phrase mention adjacent to a
backtick/path citation within 80 characters). Phase-2 requires the level
carried over, **every** requirement ID occurrence with its own pass/fail
token within its own row/list-item boundary (not just the first
occurrence), and a scope-covered summary phrase.

Kill switch: `export ASVS_VERIFICATION_OFF=1` — only a recognized
on-spelling (`1`/`true`/`yes`/`on`) disables; any unrecognized value stays
active.

Run its tests (needs `CORE_PLUGIN_ROOT` pointed at a `tokenmaxxxer-core`
checkout with `gate-lib.sh` landed — the script auto-detects the common
marketplace-install location, or set it explicitly; this is a distinct,
test-harness-only variable from the gate's own `CLAUDE_PLUGIN_ROOT_CORE`
runtime source line above):

    bash asvs-verification/hooks/tests/run-level-gate-tests.sh

31 cases (issue-13's 30 plus issue-16's `missing-core-fail-closed`
regression case: `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path,
run from a scratch cwd, must exit 2).

Basis: `docs/issue-10/proposals/enforcement-machine.md` section (iv);
`docs/issue-13/proposals/gate-a-plus.md` (Gate A+ hardening);
`docs/issue-16/proposals/gate-a-plus-closeout.md` (source-line guard
closeout); `docs/handbooks/gate-house-standard.md` (core issue #72/#75,
the referenced gate-lib contract).
