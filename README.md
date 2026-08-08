# secure-coding-rulebook

Rulebook for the `secure-coding` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion.

- **decides**: 구현이 공격에 견디는가
- **use_when**: 인증/입력처리 코드 랜딩 후
- **produces**: ASVS checklist, pentest finding list w/ severity
- **write_scope**: []
- **hand-off**: 설계 단계 위협표면 재검토가 필요하면 → security-threat-model
- **upstream spec**: `roles/specs/secure-coding.spec.json`
  (`tokenmaxxxer/on-the-record` issue #521) — required fields, loop_state,
  and use_when.board_condition basis; see `secure-coding/README.md`.

## Install

```
claude plugin marketplace add tokenmaxxxer/tokenmaxxxer-core
claude plugin install core
claude plugin install warrant
claude plugin marketplace add tokenmaxxxer/secure-coding-rulebook
claude plugin install secure-coding
```

`core` supplies the role-agnostic gates (trailer/record-fields/handbook-trigger,
registered globally by `core/hooks/hooks.json`) and the `role-directive.sh`
stub library. `warrant` supplies the rotating-stance hunt agent. Both must be
installed alongside `secure-coding` — this rulebook no longer vendors either.

## Layout

- `secure-coding/.claude-plugin/plugin.json` — plugin manifest
- `secure-coding/hooks/hooks.json` — SessionStart wiring (core's own hooks.json
  fires the role-agnostic gates globally; nothing to register here)
- `secure-coding/hooks/directive.sh` — SessionStart role directive, canon stub
  form (sources `core/hooks/lib/role-directive.sh`)
- `stub-check.sh` — no longer vendored here; reference-executed from
  core (`core/hooks/tests/stub-check.sh`) against `secure-coding/`, per
  `docs/handbooks/canon-scripts.md` (see `docs/issue-5/reports/implementation.md`)
- `asvs-verification/.claude-plugin/plugin.json` — plugin manifest
- `asvs-verification/hooks/hooks.json` — PreToolUse wiring for `level-gate.sh`
  (`Write|Edit|MultiEdit`)
- `asvs-verification/hooks/level-gate.sh` — PreToolUse gate enforcing the
  ASVS phase-split norm on `docs/issue-<n>/proposals/*secure-coding*.md`
  and `docs/issue-<n>/reports/secure-coding.md`
- `asvs-verification/hooks/directive.sh` — UserPromptSubmit reminder,
  canon stub form (sources `core/hooks/lib/role-directive.sh`)
- `asvs-verification/hooks/tests/run-level-gate-tests.sh` — gate test suite
- `cwe-cvss-findings/.claude-plugin/plugin.json` — plugin manifest
- `cwe-cvss-findings/hooks/hooks.json` — PreToolUse wiring for
  `finding-gate.sh` (`Write|Edit|MultiEdit`)
- `cwe-cvss-findings/hooks/finding-gate.sh` — PreToolUse gate enforcing
  CWE-tagged, CVSS-scored findings on `docs/issue-<n>/reports/secure-coding.md`
- `cwe-cvss-findings/hooks/directive.sh` — UserPromptSubmit reminder,
  canon stub form (sources `core/hooks/lib/role-directive.sh`)
- `cwe-cvss-findings/hooks/tests/run-finding-gate-tests.sh` — gate test suite
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)
