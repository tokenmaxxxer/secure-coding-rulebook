# issue-19 secure-coding — current-state survey (phase 1)

## Scope

issue #19 body (2026-08-01 인증 감사): the sole remaining A+ certification
blocker is a variable-name mismatch between the test harness/handbooks and
the gates' own runtime source line — "테스트 하네스/핸드북의 CORE_PLUGIN_ROOT를
CLAUDE_PLUGIN_ROOT_CORE로 정합", cited at `run-level-gate-tests.sh:17-28`, the
cwe-cvss-findings equivalent, and handbook line 34 — "so that the documented
invocation makes clean clone green."

## Scouting note

This is a narrow, previously-diagnosed follow-on to issue-16's closeout
(single-variable wiring gap, not a new design decision), so scouting was
brief: skimmed `docs/issue-16/proposals/gate-a-plus-closeout.md` and
`docs/issue-13/proposals/gate-a-plus.md` for structure/rigor precedent
(numbered fix sections citing survey findings, before/after diff quotes,
explicit "what does NOT change" callouts) and followed the same shape
below rather than inventing a new proposal format.

## What issue-16 landed (docs/issue-16/reports/secure-coding.md)

issue-16 intentionally kept two distinct variables:

- **`CLAUDE_PLUGIN_ROOT_CORE`** — the gate's own runtime source line
  (`level-gate.sh:30`, `finding-gate.sh:28`):
  `. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/gate-lib.sh" || { echo ...; exit 2; }`
- **`CORE_PLUGIN_ROOT`** — described as a "distinct, test-harness-only"
  variable used only by the test runners to *locate* a core canon checkout
  before running the suite (`run-level-gate-tests.sh:17-28`,
  `run-finding-gate-tests.sh:17-28`), documented as intentionally not
  renamed (issue-16 report line 99, V14.2.4 row).

## The actual wiring gap (confirmed by reading the harness end to end)

`run-level-gate-tests.sh` and `run-finding-gate-tests.sh` each:

1. Auto-discover a core checkout and assign it to `CORE_PLUGIN_ROOT`
   (lines 17-23).
2. `export CORE_PLUGIN_ROOT` (line 28).
3. But the bulk of the gate-invoking calls in the file are plain
   `env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE"` (e.g.
   `run-level-gate-tests.sh:53,65,154,164,178,198,217,233` and the
   `run_write`/`run_write_env` helpers built on them) — `CLAUDE_PLUGIN_ROOT_CORE`
   is never set in that subprocess's environment.

Because `level-gate.sh`/`finding-gate.sh` read **`CLAUDE_PLUGIN_ROOT_CORE`**,
not `CORE_PLUGIN_ROOT`, the exported `CORE_PLUGIN_ROOT` from step 2 is
invisible to the gate. The gate instead falls back to its own default,
`"$(dirname "${BASH_SOURCE[0]}")/../../core"` — a path relative to the
plugin's own location, not to whatever checkout the harness discovered.

- Only two call sites in each suite explicitly set `CLAUDE_PLUGIN_ROOT_CORE`:
  the `missing-core-fail-closed` regression case (deliberately, to a bogus
  path — `run-level-gate-tests.sh:284`, `run-finding-gate-tests.sh:231`) and
  a literal `. "$CORE_PLUGIN_ROOT/hooks/lib/gate-lib.sh"` sourced directly
  in a helper subshell (`run-level-gate-tests.sh:260-261`,
  `run-finding-gate-tests.sh:206-207`) that bypasses the gate script
  entirely.
- Every other case in both suites relies on the gate's own relative
  fallback resolving to a real core checkout. That only happens to work in
  an environment where a `tokenmaxxxer-core` checkout is physically present
  at `<repo>/../../core` relative to `asvs-verification/hooks/` /
  `cwe-cvss-findings/hooks/` — not guaranteed on a clean clone, and not the
  location the harness's own auto-discovery (`$ROOT/../tokenmaxxxer-core/core`
  or the marketplace install path) resolves to.

Net effect: on a clean clone where core canon is installed only at the
locations the harness auto-detects (not at the gate's hardcoded relative
default), most of the 31/22 cases either spuriously fail (gate exits 2,
"cannot source gate-lib.sh") or spuriously pass by resolving to whatever
happens to sit at the relative fallback path — the harness's own
discovery logic is dead code for every case except the two explicit ones
above.

## Handbook text affected

`docs/handbooks/asvs-verification-level-gate.md:34` and
`docs/handbooks/cwe-cvss-findings-finding-gate.md:34` both instruct readers
to `set it explicitly` via `CORE_PLUGIN_ROOT` to run the suites, describing
it as "a distinct, test-harness-only variable from the gate's own
`CLAUDE_PLUGIN_ROOT_CORE` runtime source line" — accurate as a description
of current (broken) behavior, but it documents the two-variable split as
an intentional, working design rather than flagging that the harness never
forwards its discovery into the variable the gate actually reads.

## Not in scope

- `docs/issue-5/reports/implementation.md`,
  `docs/issue-5/proposals/reclaim-stub-check.md`, and
  `cwe-cvss-findings/README.md:42` also reference `CORE_PLUGIN_ROOT` for
  `stub-check.sh` invocation, a genuinely distinct external-tool-location
  use — issue #19's `요구 2.` explicitly gates any `sales`/core #78 stub-check
  work behind landing elsewhere and out of scope for this role's phase 1.
- No other blocking reason is named in the issue #19 body.
