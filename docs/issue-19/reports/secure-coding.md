---
loop_state: landed
---

# issue-19 phase-2 record — A+ 인증 마감 (CORE_PLUGIN_ROOT wiring)

Subject: issue-19. Phase-2 record (role-handoff contract v3 s19), written
after the approver's `APPROVE issue-19/secure-coding` comment on the
issue. Verification level: **L1**, stated here before any ASVS requirement
ID below, carried over unchanged from
`docs/issue-19/proposals/secure-coding-core-plugin-root-wiring.md`.

## What was done

1. **`CORE_PLUGIN_ROOT` → `CLAUDE_PLUGIN_ROOT_CORE` forwarding** (proposal
   "Fix"). `asvs-verification/hooks/tests/run-level-gate-tests.sh` and
   `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` now seed
   `CLAUDE_PLUGIN_ROOT_CORE` from the already-discovered `CORE_PLUGIN_ROOT`
   when unset, and export both:

   ```bash
   export CORE_PLUGIN_ROOT
   : "${CLAUDE_PLUGIN_ROOT_CORE:=$CORE_PLUGIN_ROOT}"
   export CLAUDE_PLUGIN_ROOT_CORE
   ```

   Every `env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE"` call site in
   both suites now inherits `CLAUDE_PLUGIN_ROOT_CORE` — the variable
   `level-gate.sh`/`finding-gate.sh` actually read — without per-call
   edits. The `:=` form only fills the variable when unset, so the
   `missing-core-fail-closed` regression case's explicit bogus
   `CLAUDE_PLUGIN_ROOT_CORE` override still wins (verified below).

2. **Handbook update** (proposal "Handbook update").
   `docs/handbooks/asvs-verification-level-gate.md:34-39` and
   `docs/handbooks/cwe-cvss-findings-finding-gate.md:34-39` now state that
   the harness forwards its `CORE_PLUGIN_ROOT` discovery into
   `CLAUDE_PLUGIN_ROOT_CORE` automatically, replacing the prior
   "two independently-wired variables" description.

3. **Delivery evidence** (proposal "Verification plan"): both test
   suites re-run end to end from a clean-clone-equivalent environment
   (`CLAUDE_PLUGIN_ROOT_CORE` unset, only `CORE_PLUGIN_ROOT`
   auto-discovered), full-green — see Verification below.

## Why

Issue #19's 2026-08-01 인증 감사 found that `run-level-gate-tests.sh` and
`run-finding-gate-tests.sh` auto-discover a core canon checkout into
`CORE_PLUGIN_ROOT`, but every gate-invoking `env ... /bin/bash "$GATE"`
call in both suites never forwards that value into
`CLAUDE_PLUGIN_ROOT_CORE`, the variable the gate scripts themselves read
(landed by issue-16). On a clean clone with core canon only at the
auto-discovered location, the gates silently fall back to their own
relative default path, fail to source `gate-lib.sh`, and exit 1/2 instead
of running the intended cases — the exact "clean clone green" gap named
in the issue. The fix forwards the already-discovered value into the
variable the gates read, at the harness level, so no individual call site
needs editing and no gate runtime behavior changes.

## Upstream basis

- `docs/issue-19/proposals/secure-coding-core-plugin-root-wiring.md`
  (this record's direct basis, approved via the issue-level
  `APPROVE issue-19/secure-coding` comment).
- `docs/issue-19/reports/secure-coding/survey.md` (phase-1 current-state
  survey this proposal built on).
- `docs/issue-16/reports/secure-coding.md` /
  `docs/issue-16/proposals/gate-a-plus-closeout.md` — landed the
  `CLAUDE_PLUGIN_ROOT_CORE` rename on the gate scripts' own runtime source
  line that this delivery's harness-side forwarding now reaches.

## ASVS checklist

| Requirement ID | Control | pass/fail | Evidence |
|---|---|---|---|
| V14.2.4 | Configuration/dependency-location variables follow a single, consistently-resolvable convention across the codebase | pass | `CORE_PLUGIN_ROOT` (harness discovery) now forwards into `CLAUDE_PLUGIN_ROOT_CORE` (gate runtime source) at every call site in both suites; see Verification |
| V14.2.4 (regression) | Fail-closed override behavior for an explicitly bad `CLAUDE_PLUGIN_ROOT_CORE` still holds after the forwarding change | pass | `missing-core-fail-closed` still denies (exit 2) in both suites; see Verification |

## CWE/CVSS findings

N/A — none found. This is a test-harness environment-variable wiring fix,
not a weakness remediation; no new or pre-existing weakness was
identified or addressed in this change.

## Scope-covered summary

Covered: both gate-invoking test harnesses in this rulebook
(`asvs-verification/hooks/tests/run-level-gate-tests.sh`,
`cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh`) and their
handbook documentation. Not touched, and out of scope: the gate scripts'
own runtime source lines (`level-gate.sh:30`, `finding-gate.sh:28`,
unchanged since issue-16); `stub-check.sh`'s own `CORE_PLUGIN_ROOT` usage
(`cwe-cvss-findings/README.md:42`) — explicitly deferred per issue #19
요구 2, gated behind core #78 landing, sales-only.

## Verification (clean-clone-equivalent: `env -u CLAUDE_PLUGIN_ROOT_CORE -u CORE_PLUGIN_ROOT`)

```
$ env -u CLAUDE_PLUGIN_ROOT_CORE -u CORE_PLUGIN_ROOT bash asvs-verification/hooks/tests/run-level-gate-tests.sh
ok    phase1-allow-all-present                 want=allow got=allow
ok    phase1-deny-order-violation              want=deny got=deny
ok    phase1-deny-order-violation              stderr mentions level-before-requirements
ok    phase1-deny-missing-level                want=deny got=deny
ok    phase1-deny-missing-level                stderr mentions level-named
ok    phase1-deny-missing-id                   want=deny got=deny
ok    phase1-deny-missing-id                   stderr mentions external-id-present
ok    phase1-deny-missing-survey               want=deny got=deny
ok    phase1-deny-missing-survey               stderr mentions survey-reference
ok    phase2-allow-all-present                 want=allow got=allow
ok    phase2-deny-missing-level                want=deny got=deny
ok    phase2-deny-missing-level                stderr mentions level-carried-over
ok    phase2-deny-no-passfail-near             want=deny got=deny
ok    phase2-deny-no-passfail-near             stderr mentions asvs-checklist
ok    phase2-deny-only-first-row-labeled       want=deny got=deny
ok    phase2-deny-only-first-row-labeled       stderr mentions asvs-checklist
ok    phase2-allow-every-row-labeled           want=allow got=allow
ok    phase2-deny-missing-scope                want=deny got=deny
ok    phase2-deny-missing-scope                stderr mentions scope-covered-summary
ok    non-matching-path-not-evaluated          want=allow got=allow
ok    malformed-json-fail-closed               want=deny got=deny
ok    malformed-json-non-object-fail-closed    want=deny got=deny
ok    edit-old-string-not-found                want=deny got=deny
ok    edit-replace-all-true-both-occurrences   want=deny got=deny
ok    multiedit-mixed-replace-all              want=allow got=allow
ok    absolute-path-same-verdict-as-relative   want=allow got=allow
ok    kill-switch-phase1-missing-everything    want=allow got=allow
ok    kill-switch-phase2-missing-everything    want=allow got=allow
ok    kill-switch-unrecognized-value-stays-active want=deny got=deny
ok    trap-at-top-forces-fail-closed            want=deny got=deny
ok    missing-core-fail-closed                  want=deny got=deny

== 31 passed, 0 failed ==
```

```
$ env -u CLAUDE_PLUGIN_ROOT_CORE -u CORE_PLUGIN_ROOT bash cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh
ok allow-cwe-with-cvss
ok allow-na-no-cwe
ok deny-cwe-no-cvss
ok deny-no-cwe-no-na
ok deny-block-scoped-partial-cvss
ok allow-non-matching-path
ok deny-malformed-json
ok deny-malformed-json-non-object
ok deny-edit-old-string-unmatched
ok allow-kill-switch
ok kill-switch-unrecognized-value-stays-active
ok deny-bare-adjective-only
ok allow-full-cvss-vector
ok allow-score-consistent-with-band
ok deny-score-inconsistent-with-band
ok deny-list-item-block-scoped
ok allow-long-single-finding-block
ok edit-replace-all-true-both-occurrences
ok multiedit-mixed-replace-all
ok absolute-path-same-verdict-as-relative
ok trap-at-top-forces-fail-closed
ok missing-core-fail-closed

cwe-cvss-findings: 22 passed, 0 failed
```

Both suites report all cases passing (31/31, 22/22) with no
"cannot find core canon gate-lib.sh" error, run with only
`CORE_PLUGIN_ROOT` auto-discovered and no `CLAUDE_PLUGIN_ROOT_CORE`
pre-set — the exact clean-clone condition issue #19 named.
`missing-core-fail-closed` still denies (exit 2) in both suites,
confirming the explicit-override regression case is unaffected by the
`:=` forwarding.

## Open findings

None. All A+ 인증 차단 사유 named in issue #19 are resolved: the
`CORE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT_CORE` mismatch is fixed for both
gate test harnesses and confirmed green on a clean-clone-equivalent run.
