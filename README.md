# secure-coding-rulebook

Rulebook for the `secure-coding` role (contract v3 role-handoff protocol), split off
per `docs/issue-160/proposals/role-taxonomy.md`'s round-3 promotion and
generated as skeleton scaffolding by issue-170.

- **decides**: 구현이 공격에 견디는가
- **use_when**: 인증/입력처리 코드 랜딩 후
- **produces**: ASVS checklist, pentest finding list w/ severity
- **write_scope**: []
- **hand-off**: 설계 단계 위협표면 재검토가 필요하면 → security-threat-model

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
- `docs/specs/approvers.md` — Approve-authority allowlist (see below)

This is scaffolding, not a finished rulebook: fill in doctrine detail,
handoff enforcement, and any role-specific progress gate before treating
it as load-bearing.
