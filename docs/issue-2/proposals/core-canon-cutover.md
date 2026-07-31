# issue-2 proposal — cut over to core canon, drop vendored copies

Subject: issue-2. Phase-1 proposal (role-handoff contract v3 s19) — no code
changes in this commit; execution starts only after Approve. Basis: see
`docs/issue-2/reports/implementation/current-state-survey.md`.

## Change set, mapped 1:1 to the issue's 5 items

**1. Remove `secure-coding/agents/warrant-hunter.md`.**
Delete the file outright. README's "Layout" section drops that bullet and
gains an "Install" note that the `warrant` plugin (from `tokenmaxxxer-core`'s
marketplace) supplies the hunt agent; no role-specific replacement text is
needed since canon's agent is deliberately role-blind (survey, "Core canon"
§`warrant/agents/warrant-hunter.md`).

**2. Remove the three gate copies and their hooks.json entries.**
Delete `secure-coding/hooks/trailer-gate.sh`,
`secure-coding/hooks/record-fields-gate.sh`,
`secure-coding/hooks/handbook-trigger-gate.sh`. In
`secure-coding/hooks/hooks.json`, drop the `PreToolUse` block that wires
them (both the `Write|Edit|MultiEdit` matcher entry and the `Bash` matcher
entry), keeping only the `SessionStart` → `directive.sh` entry. Core's own
`core/hooks/hooks.json` already fires all three globally with matcher `.*`
once the `core` plugin is installed alongside `secure-coding` — no
per-rulebook registration is needed or wanted (a local registration would
double-fire the gate, not just duplicate the file).

**3. Convert `directive.sh` to the canon stub form.**
Replace the current hand-written trap/case/heredoc body with:

```sh
#!/usr/bin/env bash
. "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../core" && pwd -P)}/hooks/lib/role-directive.sh"
core_role_directive \
  "YOU DECIDE: 구현이 공격에 견디는가" \
  "USE_WHEN: 인증/입력처리 코드 랜딩 후" \
  "PRODUCES (required record fields): ASVS checklist, pentest finding list w/ severity" \
  "WRITE_SCOPE: [] (report-only role — no code/doc write outside the record itself)
HAND-OFF: 설계 단계 위협표면 재검토가 필요하면 → security-threat-model"
```

The `WRITE_SCOPE`/boundary-case/hand-off text that doesn't fit
`core_role_directive`'s 4-arg shape folds into the `hand_off` argument as
shown (matches `role-directive.sh`'s own doc comment: "its four genuinely
role-unique values" — it does not mandate exactly one line per value). This
is the only shape that passes `stub-check.sh`'s structural check (source
line + `core_role_directive` call + nothing else); the current file's
`trap`, `case ... SECURE_CODING_CYCLE_OFF`, and `[ "$CLAUDE_ROLE" = ... ]`
guard lines are exactly the boilerplate `role-directive.sh` now owns and
must not be reintroduced.

**4. `RECORD_FIELDS_TERMINAL_STATES` — no override needed, decide explicitly
and record why.**
Survey found no `loop_state` terminal-state divergence for this role: this
repo defines none of its own, so canon's default (`"landed"`) applies
unchanged. Proposal: do **not** add a `RECORD_FIELDS_TERMINAL_STATES`
setting to `hooks.json` — adding one that just repeats the default would be
unexplained divergence-risk for a future reader, not preservation of a real
difference. Record this explicitly (not silently) in the phase-2 record per
the issue's own item 4 wording ("역할별 실차이가 있으면... 명시적 보존" —
the converse, no-diff-found, is recorded too so a later reader doesn't have
to re-derive it).

Separately, this role's *current* `record-fields-gate.sh` checks
`asvs-checklist`/`pentest-finding-list` substrings — a real role-specific
check with no canon mechanism to move into (canon's gate checks contract
§20 structural fields only, not per-role `produces` field names). This
proposal accepts losing that specific check as the cost of cutover: the
issue's item 2 explicitly calls for removing this file, and canon's design
puts role-`produces` enforcement out of `record-fields-gate.sh`'s scope
entirely (§20 fields are role-blind by construction). No replacement gate
is proposed in this phase — flagged here as an open item for a human call,
not decided unilaterally.

**5. Vendor and pass `stub-check.sh`.**
Copy `core/hooks/tests/stub-check.sh` verbatim to
`secure-coding/hooks/tests/stub-check.sh` (matches its own header: every
rulebook carries its own copy, run against its own tree — `stub-check.sh
secure-coding` after the above changes land). Phase-2 record documents the
pass (command + output), per the issue's item 5.

## Files touched (phase 2, post-Approve)

- Delete: `secure-coding/agents/warrant-hunter.md`,
  `secure-coding/hooks/trailer-gate.sh`,
  `secure-coding/hooks/record-fields-gate.sh`,
  `secure-coding/hooks/handbook-trigger-gate.sh`
- Edit: `secure-coding/hooks/hooks.json` (drop 2 `PreToolUse` blocks),
  `secure-coding/hooks/directive.sh` (replace with stub), `README.md`
  (Layout section + Install section: note `core` and `warrant` plugin
  install alongside `secure-coding`)
- Add: `secure-coding/hooks/tests/stub-check.sh` (vendored verbatim from
  core)

## Not in scope for this issue

- Any replacement for the lost `asvs-checklist`/`pentest-finding-list`
  field check (flagged above, left to a human decision).
- Installing/declaring the `scout`/`freelunch`/`terse` core-family plugins
  — the issue's 5 items name only `warrant` + the three role-agnostic gates
  + `directive.sh`'s stub form.
- This repo's "rulebook maturation" phase 2 issue, which the issue text
  states must follow this cutover, not precede it.

## Sequencing note

Phase 2 execution order should be delete-then-stub-then-vendor-then-verify
(items 1→2→3→5 in that order), since `stub-check.sh` (item 5) is the
acceptance check for items 2 and 3 and should run last, against the
post-cutover tree, not before it.
