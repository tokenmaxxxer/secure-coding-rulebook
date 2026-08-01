---
loop_state: landed
---

# issue-16 phase-2 record — Gate A+ final closeout (conservative repair)

Subject: issue-16. Phase-2 record (role-handoff contract v3 s19), written
after the approver's `APPROVE issue-16/secure-coding` comment on the issue.
Verification level: **L2** (standard) — stated here before any ASVS
requirement ID below, carried over from
`docs/issue-16/proposals/gate-a-plus-closeout.md` (same rationale as
issue-13: this hardens process-integrity PreToolUse gates guarding a
phase-split enforcement boundary, not a crypto/multi-tenant/regulated-data
boundary).

## What was done

1. **`||`-guard + `CLAUDE_PLUGIN_ROOT_CORE` rename** (proposal section 1).
   `asvs-verification/hooks/level-gate.sh` and
   `cwe-cvss-findings/hooks/finding-gate.sh` had their source line replaced
   with the core-canon guarded form (matching
   `core/hooks/lib/gate-lib.sh`'s own usage comment, `CLAUDE_PLUGIN_ROOT_CORE`
   with an absolute-path relative fallback, `|| { echo ...; exit 2; }` on
   source failure). `secure-coding/hooks/directive.sh` was already in the
   guarded/renamed form — confirmed unchanged, no edit needed there.
   `compliance-check.sh`'s own `CORE_PLUGIN_ROOT` (a distinct
   external-invocation variable for locating a core checkout when running
   the test suites, unrelated to the gates' own runtime source line) was
   left untouched, per the proposal's explicit scoping.
2. **Missing-core mandatory test case** (proposal section 2). Added
   `missing-core-fail-closed` to both
   `asvs-verification/hooks/tests/run-level-gate-tests.sh` and
   `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh`: each invokes
   the gate as a subprocess with `CLAUDE_PLUGIN_ROOT_CORE` pointed at a
   guaranteed-nonexistent `mktemp -u` path, run from a scratch tempdir cwd,
   and asserts exit 2 with a stderr message containing "cannot source".
   Confirmed this case fails (exit 0 / silent allow) against the
   pre-fix unguarded source line and passes after item 1 above — it is a
   real regression test for the fixed bug, not a vacuous new-text
   assertion. `run-gate-lib-tests.sh`'s own six group names in the current
   `tokenmaxxxer-core` `main` checkout do not include a literal
   `mark missing-core` group (re-checked directly against the fetched core
   canon at delivery time — the proposal's line-number citation for that
   group did not resolve in the checked-out file); this delivery's test
   shape is adapted directly from the core canon's own guarded usage
   comment and the confirmed bug behavior instead, satisfying the same
   requirement (issue-16 requirement 3, "missing-core case").
3. **hooks.json matcher / tool-coverage parity** (proposal section 3). No
   fix required — re-confirmed at phase 2: both `hooks.json` files' matcher
   (`"Write|Edit|MultiEdit"`) still exactly matches each gate's Python
   dispatch (`tool in ("Write", "Edit", "MultiEdit")`), unchanged by the
   source-line edits above.
4. **README ghost text** (proposal section 4). Root `README.md`: removed
   the "generated as skeleton scaffolding by issue-170" clause from the
   opening paragraph (kept the accurate role-split-provenance sentence);
   removed the closing "This is scaffolding, not a finished rulebook..."
   disclaimer paragraph in full; extended `## Layout` to list
   `asvs-verification/` and `cwe-cvss-findings/`'s manifest, `hooks.json`,
   gate script, `directive.sh`, and test suite, at the same level of
   detail already given for `secure-coding/`.
5. **Delivery evidence** (proposal section 5, issue-16 requirement 3):
   both gate test suites re-run full-green with the new case counted;
   `compliance-check.sh` re-run by reference against both gates'
   `hooks/` directories, recorded clean — see Evidence below.

## Why

Issue-16's 2026-08-01 re-audit found: the two gates' `gate-lib.sh` source
line lacked the `||`-guard and used the pre-rename `CORE_PLUGIN_ROOT`
variable against a house convention that had since moved to
`CLAUDE_PLUGIN_ROOT_CORE` (core issue #75), meaning a missing/misconfigured
core checkout would silently continue past the failed `.` (source) instead
of failing closed; no regression test existed proving the fail-closed
behavior; and the root `README.md` still carried the pre-promotion
"skeleton scaffolding" disclaimer text and omitted the two landed plugins
from its own Layout section. All four items are repaired here by
mechanical re-application of the already-landed core-canon form, per the
proposal's "reference-adopt, do not reimplement" constraint — no new guard
shape, kill-switch semantics, or test harness idiom was invented.

## Upstream basis

- `docs/issue-16/proposals/gate-a-plus-closeout.md` (this record's
  direct basis).
- `docs/issue-16/reports/secure-coding/survey.md` (current-state survey,
  phase-1 research this proposal built on).
- `core/hooks/lib/gate-lib.sh`'s own usage comment (`tokenmaxxxer-core`,
  core issue #75) — the guarded source-line form this delivery copies.
- `docs/issue-13/reports/secure-coding.md` — the prior Gate A+ hardening
  delivery this closeout follows the same evidence pattern from.

## ASVS checklist

| Requirement ID | Control | pass/fail | Evidence |
|---|---|---|---|
| V1.14.6 | The application/library does not continue to operate when a required dependency fails to load | pass | Both gates' `gate-lib.sh` source line now carries `\|\| { echo ...; exit 2; }`; `missing-core-fail-closed` (new, both suites) confirms exit 2 with a "cannot source" stderr message when `CLAUDE_PLUGIN_ROOT_CORE` resolves to a nonexistent path and no relative fallback is reachable. |
| V3.1.1 | The application fails closed / securely on an unhandled internal error | pass | `trap-at-top-forces-fail-closed` (pre-existing, both suites) still passes unchanged after the source-line edit — the fail-closed trap is unaffected since it is installed only after a successful source. |
| V5.1.1 | Input is validated using positive/allow-list validation before being trusted | pass | Unchanged from issue-13's delivery — re-confirmed still passing (both suites' malformed-JSON cases). |
| V14.2.4 | Configuration and dependency-location variables follow a single, consistently-named convention across the codebase | pass | `CLAUDE_PLUGIN_ROOT_CORE` is now the sourcing variable in all three gate-adjacent scripts (`level-gate.sh`, `finding-gate.sh`, `directive.sh`); `CORE_PLUGIN_ROOT` (test-harness-only, external invocation) is confirmed the sole remaining distinct-purpose variable, documented as such and not renamed. |

## CWE/CVSS findings

- **CWE-252 (Unchecked Return Value)** — CVSS 3.1: 3.1 (Low,
  `AV:L/AC:L/PR:N/UI:N/S:U/C:N/I:L/A:N`) — **fixed in this delivery**.
  Both `level-gate.sh` and `finding-gate.sh` sourced `gate-lib.sh` without
  checking the `.` (source) command's return value; on a missing/relocated
  core checkout the script would continue with `gate_*` functions
  undefined, degrading the gate's later behavior in an unverified way
  instead of failing closed immediately at the dependency boundary.
  Remediated by the `||`-guard in proposal section 1; proven by the new
  `missing-core-fail-closed` regression case in both suites (confirmed
  failing pre-fix, passing post-fix).
- No other CWE-classed findings from this delivery's scope. The
  carried-forward **CWE-22** (Improper Limitation of a Pathname to a
  Restricted Directory, CVSS 3.1: 3.1 Low) item from
  `docs/issue-13/reports/secure-coding.md`'s "Open findings" is unchanged
  and explicitly out of scope here (issue-16's proposal "Not in scope"
  section; `CLAUDE_PROJECT_DIR` trustworthiness is a separate, already-
  tracked follow-up, not part of this closeout's required fix list).

## Scope-covered summary

All five proposal sections covered: source-line guard/rename applied to
the two files that needed it (the third, `directive.sh`, confirmed
already-fixed); missing-core regression case added to both suites;
hooks.json/dispatch parity re-confirmed with no change needed;
README ghost text removed and Layout extended; compliance-check and
full test-suite evidence recorded below. No item from the proposal's
"Files touched (phase 2)" list was dropped. Not in scope, unchanged from
the proposal: the ASVS/CWE-CVSS methodology itself, the two plugin
READMEs and manifests (survey found no defect in them), hooks.json
matcher changes, and landing `gate-lib.sh`/`gate-lib.py`/
`compliance-check.sh`/`spawn.py` themselves (already-landed, out-of-repo
deliverables this closeout only references).

## Compliance detector evidence (reference execution, never vendored)

```
$ "${CORE_PLUGIN_ROOT}/hooks/tests/compliance-check.sh" asvs-verification/hooks
compliance-check: ok — asvs-verification/hooks/level-gate.sh

$ "${CORE_PLUGIN_ROOT}/hooks/tests/compliance-check.sh" cwe-cvss-findings/hooks
compliance-check: ok — cwe-cvss-findings/hooks/finding-gate.sh
```

## Test suite evidence

```
$ bash asvs-verification/hooks/tests/run-level-gate-tests.sh
== 31 passed, 0 failed ==

$ bash cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh
cwe-cvss-findings: 22 passed, 0 failed
```

(31 = issue-13's 30 plus this delivery's `missing-core-fail-closed`; 22 =
issue-13's 21 plus the same new case.)

## Not in scope (unchanged from proposal)

Re-deciding the ASVS/CWE-CVSS methodology (issue-1); any change to
`asvs-verification/README.md`, `cwe-cvss-findings/README.md`, or any
`.claude-plugin/plugin.json` (survey found no defect); hooks.json matcher
changes or new Bash-tool coverage (no gap exists); landing
`core/hooks/lib/gate-lib.sh` / `gate-lib.py` / `compliance-check.sh` or
`on-the-record`'s `spawn.py` (already-landed, out-of-repo deliverables).
