# issue-2 current-state survey — secure-coding-rulebook vs core canon

Subject: issue-2. Phase-1 material (role-handoff contract v3 s19) — no code
changes in this commit.

## Scout note (directive compliance)

Scouting was reduced to direct inspection of the core canon repository
(`tokenmaxxxer-core`), not run as an external best-in-class sweep. Reason:
this is an internal reference-conversion task where the target shape is
fully specified by the canon repo itself (`core/hooks/lib/role-directive.sh`'s
own usage docstring, `core/hooks/tests/stub-check.sh`'s structural check, and
`core/hooks/hooks.json`'s global registration) — there is no external field to
survey. `grep -rl "role-directive.sh" tokenmaxxxer/rulebooks/` and
`grep -rl "stub-check.sh" tokenmaxxxer/rulebooks/` both returned no hits: no
sibling rulebook has completed this migration yet, so there is no in-repo
precedent to snowball from either. This satisfies the skip condition ("spec
leaves no design decision open") for the mechanical parts of the task; the
one open call (RECORD_FIELDS_TERMINAL_STATES) is addressed directly below
from the canon source, not from an exemplar.

## This repo's current vendored surface

| File | Role |
|---|---|
| `secure-coding/agents/warrant-hunter.md` | role-local copy of the hunt agent, explicitly "adapted from implementation-rulebook's `agents/warrant-hunter.md`" |
| `secure-coding/hooks/trailer-gate.sh` | role-local copy of the commit-trailer gate (`SECURE_CODING_PAYLOAD`/`SECURE_CODING_CYCLE_OFF` naming) |
| `secure-coding/hooks/record-fields-gate.sh` | role-local copy of the record required-field gate, hardcoded `REQUIRED_FIELDS = ["asvs-checklist", "pentest-finding-list"]` and hardcoded path suffix `/reports/secure-coding.md` |
| `secure-coding/hooks/handbook-trigger-gate.sh` | role-local copy, body is a bare `exit 0` placeholder ("skeleton... reassess before shipping") |
| `secure-coding/hooks/directive.sh` | role-local SessionStart directive, hand-written case/trap boilerplate + heredoc |
| `secure-coding/hooks/hooks.json` | registers all four gates above under this plugin |
| `secure-coding/.claude-plugin/plugin.json`, `README.md` | describe the above as this role's own surface |

## Core canon (`tokenmaxxxer-core`), landed per core issue #63/#66

- `core/hooks/hooks.json` — registers `board-gate.sh`, `approval-gate.sh`,
  `gh-guard.sh`, `trailer-gate.sh`, `record-fields-gate.sh`,
  `handbook-trigger-gate.sh` on `PreToolUse` with matcher `.*`, **globally,
  for every plugin install** — a rulebook needs no hooks.json entry for
  these three gates at all once its own copies are gone.
- `core/hooks/trailer-gate.sh` — role-blind, reads `CLAUDE_ROLE` from env at
  runtime; functionally a superset of this repo's copy (adds multi-tool
  tokenization, `TRAILER_GATE_OFF` kill switch, not `SECURE_CODING_CYCLE_OFF`).
- `core/hooks/record-fields-gate.sh` — reads `CLAUDE_ROLE`, derives the
  target record path as `docs/issue-<n>/reports/<role>.md` and the message
  prefix from it (fixes a documented copy-paste bug class from the pre-canon
  vendored copies). Required fields are **not** the role's `produces` list —
  canon's version checks contract §20 structural fields (what-was-done, why,
  upstream-basis, `loop_state`, open-findings, and open-state next-steps),
  not this repo's role-specific `asvs-checklist`/`pentest-finding-list`
  substrings. Terminal `loop_state` values default to `{"landed"}` via
  `RECORD_FIELDS_TERMINAL_STATES` (space-separated), overridable per rulebook
  in that rulebook's own `hooks.json` env.
- `core/hooks/handbook-trigger-gate.sh` — real implementation (pattern-match
  on staged operational-surface files, requires a paired `docs/handbooks/`
  touch), not the placeholder `exit 0` this repo currently vendors.
- `core/hooks/lib/role-directive.sh` — sourceable `core_role_directive()`
  taking four args (`you_decide`, `use_when`, `produces`, `hand_off`); reads
  `CLAUDE_ROLE`, honors `<ROLE>_CYCLE_OFF` (role name uppercased via `tr`,
  not bash 4 `${var^^}`), emits the same directive shape this repo's
  `directive.sh` currently hand-writes, plus the closing `RECORD:` line.
- `core/hooks/tests/stub-check.sh` — the compliance check named in the
  issue's item 5. Two check shapes:
  - **absence-based** for the three gates (`trailer-gate.sh`,
    `record-fields-gate.sh`, `handbook-trigger-gate.sh`) plus
    `parse-check.sh`: any file with these names anywhere under the target
    dir (maxdepth 3) is a FAIL — a vendored copy, however byte-identical,
    is drift by presence alone.
  - **structural** for `directive.sh`: must source `role-directive.sh`, must
    call `core_role_directive`, and every other non-blank/non-comment line
    must be either that source line, a plain `VAR=value` assignment, or the
    call itself — any case/trap/guard/heredoc line fails it.
- `warrant/agents/warrant-hunter.md`, `warrant/hooks/*` — the canon hunt
  agent + its own hooks.json (`state.sh`, `hunt-state.sh`,
  `scope-gate.sh`, `hunt-guard.sh`, own `directive.sh`). The canon agent body
  is role-blind by design (three fixed finding kinds: silent-failure,
  composition-regression, plain-design-error) — it carries no per-role
  mandate text. Ships as its own plugin (`warrant`, in
  `tokenmaxxxer-core`'s marketplace.json), installed alongside a rulebook's
  own plugin rather than referenced by path from it.

## Consequence for this repo's 5 work items

1. `agents/warrant-hunter.md` has no per-role content worth preserving —
   canon's copy is intentionally generic. Deleting it and depending on the
   `warrant` plugin is a straight removal, not a merge.
2. All three gate `.sh` files are pure vendored copies once canon's global
   registration is relied on; `hooks.json`'s three matching entries drop too
   (only the `SessionStart` → `directive.sh` entry stays, since
   `directive.sh` itself is not eliminated, only stubbed).
3. `directive.sh` converts to the stub form `stub-check.sh` requires: source
   `role-directive.sh`, four `VAR=...` assignments carrying this role's
   actual `YOU DECIDE`/`USE_WHEN`/`PRODUCES`/`HAND-OFF` text (currently
   embedded in the heredoc), one `core_role_directive` call. The
   `SECURE_CODING_CYCLE_OFF` kill switch and `CLAUDE_ROLE` guard are already
   handled inside `role-directive.sh` itself and must NOT be re-added in the
   stub (that would fail stub-check's "no other lines" check).
4. Real per-role difference found: this repo's `record-fields-gate.sh`
   currently checks role-specific field names
   (`asvs-checklist`/`pentest-finding-list`), which canon's version does not
   check at all (canon checks contract §20 structural fields uniformly).
   There is **no `loop_state` terminal-state divergence** to preserve here —
   this repo defines no terminal states of its own anywhere (no
   `roles/secure-coding.json` or equivalent found in this repo or in core);
   canon's default `RECORD_FIELDS_TERMINAL_STATES="landed"` is unchanged
   behavior, not a new restriction, so no override is needed in this role's
   `hooks.json`. (The `asvs-checklist`/`pentest-finding-list` field
   requirement itself has no canon equivalent to move into — it was this
   repo's own gate, not derived from a shared mechanism args can migrate
   into. Whether to preserve it via a different mechanism is a proposal
   decision, not a survey fact.)
5. `core/hooks/tests/stub-check.sh` does not exist under this repo yet; it
   must be vendored (per its own header: "distributed to every rulebook the
   way parse-check.sh already is... every rulebook copies this file
   verbatim") and run against `secure-coding/` before the record claims item
   5 done.

## Untouched (role-unique, per issue's preservation clause)

- `secure-coding/.claude-plugin/plugin.json`'s name/description.
- `docs/specs/approvers.md` (role-agnostic contract file, not part of this
  issue's scope).
- The `YOU DECIDE`/`USE_WHEN`/`PRODUCES`/`HAND-OFF` text content itself
  (moves into the stub's variables, not deleted or altered).
