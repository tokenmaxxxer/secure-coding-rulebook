# cwe-cvss-findings finding-gate

`cwe-cvss-findings/hooks/finding-gate.sh` is a `PreToolUse` gate
(Write|Edit|MultiEdit) that fires only on writes resolving to
`docs/issue-<n>/reports/secure-coding.md` (phase-2 only — this methodology
never gates phase-1 proposals); every other path is allowed without content
evaluation. It sources core canon's `gate-lib.sh`/`gate-lib.py`
(`${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh || { echo ...; exit 2; }`,
core issue #75's guarded form) for the fail-closed EXIT trap, kill switch,
malformed-JSON deny, path normalization, and full Write/Edit/MultiEdit
reconstruction — none of that machinery is re-derived locally. A failed
source (missing/misconfigured core checkout) exits 2 immediately rather
than continuing with `gate_*` functions undefined (issue-16 fix;
regression-tested by `missing-core-fail-closed`, below). Root resolution is
independent of the tool call's own `file_path`: `CLAUDE_PROJECT_DIR` if
plausible, else `git rev-parse --show-toplevel` — never derived by
`dirname`-ing the write target (symmetric with `level-gate.sh`).

Requires either an explicit "N/A — none found" (or equivalent no-findings
phrase), or every `CWE-<n>` token in the document to carry a real CVSS
vector string (`CVSS:3.0/…` or `CVSS:3.1/…` with at minimum `AV`, `AC`,
and one of `C`/`I`/`A`) or a numeric CVSS base score consistent with a
stated CVSS v3.1 severity band, within its own finding block (from the
CWE-ID's own line start to the next blank line, list-item marker, or
table row) — block-scoped, so a document with several findings where only
some carry a valid label still fails, but a single long finding whose
label sits deep in its own write-up still passes. A bare severity
adjective with no vector or score no longer satisfies this.

Kill switch: `export CWE_CVSS_FINDINGS_OFF=1` — only a recognized
on-spelling (`1`/`true`/`yes`/`on`) disables; any unrecognized value stays
active.

Run its tests (needs `CORE_PLUGIN_ROOT` pointed at a `tokenmaxxxer-core`
checkout with `gate-lib.sh` landed — the script auto-detects the common
marketplace-install location, or set it explicitly; this is a distinct,
test-harness-only variable from the gate's own `CLAUDE_PLUGIN_ROOT_CORE`
runtime source line above):

    bash cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh

22 cases (issue-13's 21 plus issue-16's `missing-core-fail-closed`
regression case: `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path,
run from a scratch cwd, must exit 2).

Basis: `docs/issue-10/proposals/enforcement-machine.md` section (iv);
`docs/issue-13/proposals/gate-a-plus.md` (Gate A+ hardening);
`docs/issue-16/proposals/gate-a-plus-closeout.md` (source-line guard
closeout); `docs/handbooks/gate-house-standard.md` (core issue #72/#75,
the referenced gate-lib contract).
