# issue-1 current-state survey — secure-coding rulebook maturity baseline

Scout: ran (not skipped) — the issue asks for a broad domain survey with no
single canon doc dictating the end state, so an external methodology sweep
was required. Mode: 3 parallel Agent-tool subagents in one batch (stage 1
sweep, by-standard-family angle: OWASP ASVS/SAMM; CWE/STRIDE/PASTA;
NIST SSDF/BSIMM). One deepening judge point was run after the sweep;
results converged strongly across all three angles (see scout-brief.md), so
saturation was reached after stage 1 — no further deepening stage was run.
Total: 1 stage, well under the 5-stage/3-minute budget.

## What exists in this repo today

- `secure-coding/.claude-plugin/plugin.json` — role identity only (name,
  description, authors). No methodology or record-field content.
- `secure-coding/hooks/hooks.json` — single `SessionStart` → `directive.sh`
  hook, nothing else registered.
- `secure-coding/hooks/directive.sh` — sources core's
  `role-directive.sh` and calls `core_role_directive` with four strings:
  `you_decide` ("구현이 공격에 견디는가"), `use_when` ("인증/입력처리 코드
  랜딩 후"), `produces` ("ASVS checklist, pentest finding list w/
  severity" — already names ASVS and a severity-tagged finding list, but as
  a one-line directive string, not a governed record schema), and
  `hand_off` (WRITE_SCOPE empty — report-only role; HAND-OFF to
  security-threat-model for design-stage threat-surface review).
- No `secure-coding/agents/` directory exists yet in this rulebook's tree
  (no vendored or referenced `warrant-hunter.md`).
- No `docs/handbooks/`, `docs/decisions/`, `docs/specs/` content beyond
  `docs/specs/approvers.md` (JiwonJung94 registered as sole approver).
- Prior sibling issues in this repo (issue-2, issue-5) both followed the
  two-phase pattern this issue also requires: phase-1 commit = survey +
  proposal only, phase-2 commit (after Approve) = the actual plugin
  edits + `docs/issue-<n>/reports/secure-coding.md` record. Their proposals
  (`docs/issue-2/proposals/core-canon-cutover.md`,
  `docs/issue-5/proposals/reclaim-stub-check.md`) are short (~40-90 line),
  cite exact file paths and exact invocation expressions, and end with a
  "Files touched (phase 2)" list plus a "Not in scope" section — this
  format is adopted below as house style for issue-1's own proposal.

## Gap this issue is meant to close

The directive's `produces` line already gestures at ASVS-shaped content
("ASVS checklist... w/ severity") but nothing in the repo defines: (a) what
methodology a phase-1 proposal itself must follow before code work starts,
(b) what a phase-2 security-review record must structurally contain beyond
a free-text finding list, (c) why any of it should look that way rather
than some other shape, (d) how it gets enforced (directive wording, record
required fields, a gate). This issue's proposal (see
`docs/issue-1/proposals/`) supplies all four, grounded in the external
survey below rather than invented from scratch.

## Core canon constraint carried into the proposal

Per `docs/handbooks/canon-scripts.md` in `tokenmaxxxer-core` ("Canon
scripts are referenced, never copied") and the issue's own constraint,
`warrant-hunter` must be referenced against the core plugin's install root,
never vendored into `secure-coding/agents/`. The proposal's plugin
reflection plan (section d) does not introduce a vendored copy.
