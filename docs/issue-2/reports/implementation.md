# issue-2 — phase-2 record: core canon cutover executed

loop_state: landed

## What was done

Executed the approved `docs/issue-2/proposals/core-canon-cutover.md` on this
branch: removed the vendored `warrant-hunter.md` agent and the three
role-agnostic gate copies (plus their hooks.json registrations), converted
`directive.sh` to the canon stub form, vendored `stub-check.sh`, and ran it
to a clean pass. Details below.

## Why

Upstream basis: `docs/issue-2/reports/implementation/current-state-survey.md`
and `docs/issue-2/proposals/core-canon-cutover.md`, per issue-2, tracking
core canon issue-63 (warrant) and issue-66 (role-agnostic gates + directive
stub). Rationale: core now owns these role-blind mechanisms canonically;
per-rulebook vendored copies are drift risk, not intentional role behavior
— see the proposal for the 1:1 mapping to the issue's 5 items.

Approval basis: issue comment `APPROVE issue-2/implementation` by
JiwonJung94 (single-account mode, contract v3 s19). Note: at execution
time `docs/specs/approvers.md` carried no populated logins (template
comment only) — the approver allowlist itself was never filled in for this
repo. Recorded here as a gap for a human to close, not silently worked
around; execution proceeded on the explicit session-invocation instruction
naming this as approved phase-2 work, together with the exact-string
APPROVE comment.

## Executed steps

Order delete→stub→vendor→verify, per the proposal's sequencing note:

1. Deleted `secure-coding/agents/warrant-hunter.md` (dir removed, now
   empty); role's hunt agent comes from the `warrant` core plugin.
2. Deleted `secure-coding/hooks/trailer-gate.sh`,
   `secure-coding/hooks/record-fields-gate.sh`,
   `secure-coding/hooks/handbook-trigger-gate.sh`; dropped both
   `PreToolUse` blocks from `secure-coding/hooks/hooks.json` — only the
   `SessionStart` → `directive.sh` entry remains. Core's own
   `core/hooks/hooks.json` fires all three globally once `core` is
   installed.
3. Replaced `secure-coding/hooks/directive.sh` with the canon stub form:
   sources `core/hooks/lib/role-directive.sh`, assigns the four
   role-unique values to variables (`you_decide`, `use_when`, `produces`,
   `hand_off` — the last via `$'...'` ANSI-C quoting to keep the
   WRITE_SCOPE/HAND-OFF two-line value on one assignment line, since
   `stub-check.sh`'s structural check only recognizes single-line `var=`
   assignments), then calls `core_role_directive` with all four on one
   line. This shape was required to pass the structural check — a
   backslash-continued multi-line call reads as regrown boilerplate to the
   checker.
4. `RECORD_FIELDS_TERMINAL_STATES`: confirmed no override needed — this
   role defines no `loop_state` terminal-state divergence from canon's
   default (`"landed"`), matching the proposal's explicit no-diff-found
   finding. Not added to `hooks.json`.
5. Vendored `core/hooks/tests/stub-check.sh` verbatim to
   `secure-coding/hooks/tests/stub-check.sh` and ran it against this tree:

```
$ bash secure-coding/hooks/tests/stub-check.sh secure-coding
stub-check: ok — no vendored 'trailer-gate.sh' under secure-coding
stub-check: ok — no vendored 'record-fields-gate.sh' under secure-coding
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under secure-coding
stub-check: ok — no vendored 'parse-check.sh' under secure-coding
stub-check: ok — secure-coding/hooks/directive.sh is a role-directive stub
$ echo $?
0
```

PASS.

Also updated `README.md`'s Install section (note that `core` and `warrant`
must be installed alongside `secure-coding`) and Layout section (dropped
the five removed-file bullets, added the stub-form `directive.sh` and
`hooks/tests/stub-check.sh` entries).

## Open findings

- Losing `record-fields-gate.sh`'s role-specific check (`asvs-checklist` /
  `pentest-finding-list` substrings) with no canon replacement — canon's
  `record-fields-gate.sh` enforces only contract §20 structural fields, not
  per-role `produces` field names. No replacement gate proposed in this
  phase; flagged for a human call, not decided here.
- `docs/specs/approvers.md` has no populated logins (see Why, above) —
  this repo's approval mechanism has never actually been backed by a real
  allowlist entry. A human should populate it before the next issue relies
  on it.
- `directive.sh`'s actual output was not exercised end-to-end against a
  live `core` plugin install in this sandbox (no `core` plugin installed
  here); `stub-check.sh`'s structural pass is the acceptance criterion
  this issue's item 5 asks for, and that passed.
