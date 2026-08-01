# issue-19 secure-coding proposal — wire CORE_PLUGIN_ROOT into CLAUDE_PLUGIN_ROOT_CORE (level L1)

ASVS verification level for this proposal: **L1**.

Basis for current state: `docs/issue-19/reports/secure-coding/survey.md`
(this role's phase-1 survey), building on `docs/issue-16/reports/secure-coding.md`
and `docs/issue-16/proposals/gate-a-plus-closeout.md`.

Relevant requirement: **V14.2.4** — configuration and dependency-location
variables should follow a single, consistently-resolvable convention
across the codebase; the gap below is precisely a case where a documented
variable name (`CORE_PLUGIN_ROOT`) never reaches the code path that
actually resolves the dependency location.

## Problem (survey §"The actual wiring gap")

`run-level-gate-tests.sh` and `run-finding-gate-tests.sh` auto-discover a
core canon checkout and export it as `CORE_PLUGIN_ROOT`, but the gate
scripts they exercise (`level-gate.sh`, `finding-gate.sh`) read
`CLAUDE_PLUGIN_ROOT_CORE`, not `CORE_PLUGIN_ROOT`. Every gate-invoking
`env ... /bin/bash "$GATE"` call in both suites — the overwhelming
majority of the 31/22 cases — never forwards the discovered value, so the
gate silently falls back to its own relative default
(`.../hooks/../../core`). On a clean clone that only has core canon at the
harness's auto-discovered location (not at that relative path), this makes
the suites fail to source `gate-lib.sh` and exit 1/2 instead of running
the intended cases — exactly the "clean clone green" gap issue #19 names.

## Fix

Set **both** `CORE_PLUGIN_ROOT` (kept, for readers/CI who already export
it, and because `docs/issue-5`/`cwe-cvss-findings/README.md:42` use it for
the unrelated `stub-check.sh` invocation — out of this role's scope per
issue #19 요구 2) **and** `CLAUDE_PLUGIN_ROOT_CORE` from the same
auto-discovery block, and export both, so every existing
`env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE"` call site picks it up
via inherited environment without needing per-call edits:

```bash
if [ -z "${CORE_PLUGIN_ROOT:-}" ]; then
  for c in \
    "$HOME/.claude/plugins/marketplaces/tokenmaxxxer/runs/rulebooks/tokenmaxxxer-core/core" \
    "$ROOT/../tokenmaxxxer-core/core"; do
    if [ -f "$c/hooks/lib/gate-lib.sh" ]; then CORE_PLUGIN_ROOT="$c"; break; fi
  done
fi
[ -n "${CORE_PLUGIN_ROOT:-}" ] && [ -f "$CORE_PLUGIN_ROOT/hooks/lib/gate-lib.sh" ] || {
  echo "run-level-gate-tests: cannot find core canon gate-lib.sh; set CORE_PLUGIN_ROOT (or CLAUDE_PLUGIN_ROOT_CORE) to a checkout of tokenmaxxxer-core (core issue #72) before running this suite." >&2
  exit 1
}
export CORE_PLUGIN_ROOT
: "${CLAUDE_PLUGIN_ROOT_CORE:=$CORE_PLUGIN_ROOT}"
export CLAUDE_PLUGIN_ROOT_CORE
```

Apply the identical block to both `run-level-gate-tests.sh` (replacing
lines ~17-28) and `run-finding-gate-tests.sh` (replacing lines ~17-28).

The two call sites that already set `CLAUDE_PLUGIN_ROOT_CORE` explicitly
(the `missing-core-fail-closed` regression case, and the literal
`gate-lib.sh` source in the trap-at-top helper) are untouched: the
`:=` assignment only fills `CLAUDE_PLUGIN_ROOT_CORE` when unset, so a
call site's own explicit override (including the regression case's bogus
path) still wins.

## Handbook update

`docs/handbooks/asvs-verification-level-gate.md:34-38` and
`docs/handbooks/cwe-cvss-findings-finding-gate.md:34-38`: update the
"Run its tests" paragraph to state that the harness now forwards its
`CORE_PLUGIN_ROOT` discovery into `CLAUDE_PLUGIN_ROOT_CORE` automatically
(so a plain `set CORE_PLUGIN_ROOT` — or nothing, if auto-discovery finds a
checkout — is sufficient to get a green clean-clone run), rather than
describing the two variables as needing independent manual wiring.

## What does NOT change

- The gate scripts' own runtime source line
  (`level-gate.sh:30`, `finding-gate.sh:28`) — untouched; they keep
  reading `CLAUDE_PLUGIN_ROOT_CORE` exactly as issue-16 landed it.
- `stub-check.sh`'s own `CORE_PLUGIN_ROOT` usage
  (`cwe-cvss-findings/README.md:42`, `docs/issue-5/proposals/reclaim-stub-check.md`)
  — a distinct external-tool invocation, out of scope per issue #19 요구 2
  (gated behind core #78 landing, sales-only).
- No new test cases are required to prove the gates' own behavior (that is
  covered by the existing 31/22 cases and issue-16's
  `missing-core-fail-closed`); the fix only needs the existing suites to
  actually reach those cases on a clean clone, which is verified by
  re-running both suites end to end after the change.

## Verification plan (phase 2)

Run both suites from a genuinely clean checkout state (no stray
`CLAUDE_PLUGIN_ROOT_CORE` pre-set in the shell) with only `CORE_PLUGIN_ROOT`
provided or auto-discovered, and record the full pass/fail tallies:

    bash asvs-verification/hooks/tests/run-level-gate-tests.sh
    bash cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh

Both must report all cases passing (31 and 22 respectively) with no
"cannot source gate-lib.sh" errors, and the `missing-core-fail-closed`
case must still deny (exit 2) since its explicit
`CLAUDE_PLUGIN_ROOT_CORE=<bogus>` override is preserved by the fix.
