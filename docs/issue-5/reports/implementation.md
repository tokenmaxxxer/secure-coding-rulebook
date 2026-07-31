# issue-5 — phase-2 record: reclaim vendored stub-check.sh

loop_state: landed

## What was done

Executed the approved `docs/issue-5/proposals/reclaim-stub-check.md` on this
branch: deleted the vendored `secure-coding/hooks/tests/stub-check.sh` copy,
confirmed `secure-coding/hooks/hooks.json` never registered it (no edit
needed), updated the one stale reference in `README.md`'s Layout section,
and reference-executed core's own `core/hooks/tests/stub-check.sh` against
this tree to a clean pass. Details below.

## Why

Upstream basis: `docs/issue-5/reports/implementation/current-state-survey.md`
and `docs/issue-5/proposals/reclaim-stub-check.md`, per issue-5, tracking
core canon issue-69: canon now forbids vendoring `stub-check.sh` itself
(`core/hooks/tests/canon-manifest.txt` lists it as a manifest file) and
requires reference execution instead
(`docs/handbooks/canon-scripts.md`, `docs/handbooks/role-gates-tests.md` in
`tokenmaxxxer-core`). The vendored copy added by the issue-2 cutover
(`docs/issue-2/proposals/core-canon-cutover.md` item 5) was itself the drift
this canon rule exists to catch.

Approval basis: role-handoff contract v3 phase-2 gate — task was issued
on the explicit premise that the phase-1 proposal had already been
Approved by a human approver.

## Executed steps

1. Deleted `secure-coding/hooks/tests/stub-check.sh` via `git rm` (vendored
   verbatim copy of core's `core/hooks/tests/stub-check.sh`).
2. Confirmed (again, directly) `secure-coding/hooks/hooks.json` has only its
   pre-existing `SessionStart` → `directive.sh` entry — `stub-check.sh` was
   never a hooks.json registration (it's a test-harness script, not a hook
   trigger), so no hooks.json edit was made.
3. Repo-wide grep for `stub-check` after the deletion found no live
   call-site referencing the deleted vendored path. The only stale mention
   was descriptive text in `README.md`'s Layout section (claiming the file
   was "vendored verbatim from core" — no longer true); updated it to
   describe the current reference-execution model instead. Historical
   records under `docs/issue-2/` that describe the (now-superseded) vendor
   step as something that happened at the time are left untouched — they
   are a record of past action, not a statement of current state.
4. Reference-executed the core canon copy directly, per the invocation
   expression in `docs/handbooks/role-gates-tests.md`
   (`"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."`),
   resolved in this sandbox to the local core checkout at
   `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core`:

```
$ cd /home/jwjung/.tokenmaxxxer/work/secure-coding-rulebook-issue-5-implementation
$ "/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/tests/stub-check.sh" "secure-coding"
stub-check: ok — no vendored 'trailer-gate.sh' under secure-coding
stub-check: ok — no vendored 'record-fields-gate.sh' under secure-coding
stub-check: ok — no vendored 'handbook-trigger-gate.sh' under secure-coding
stub-check: ok — no vendored 'parse-check.sh' under secure-coding
stub-check: ok — no vendored 'stub-check.sh' under secure-coding
stub-check: ok — secure-coding/hooks/directive.sh is a role-directive stub
$ echo $?
0
```

PASS. Note the new `stub-check: ok — no vendored 'stub-check.sh' under
secure-coding` line — this is the canon file's own self-referential check
(mirrors the manifest reasoning in the phase-1 survey) confirming the
vendored copy really is gone, run from the core installation rather than a
rulebook-local copy.

## Files touched

- Deleted: `secure-coding/hooks/tests/stub-check.sh`
- No edit: `secure-coding/hooks/hooks.json` (confirmed no entry existed)
- Edited: `README.md` (Layout section, stub-check.sh bullet updated to
  describe reference-execution instead of vendoring)
- Added: this file (`docs/issue-5/reports/implementation.md`)

## Open findings

- No permanent test-harness file (e.g. a `run-role-gates-tests.sh`
  equivalent) wraps this reference-execution invocation in this repo —
  per the proposal, out of scope for this issue; a future decision if this
  rulebook wants a durable, repeatable local entry point instead of an
  ad hoc CLI invocation.
- `CORE_PLUGIN_ROOT`/`CLAUDE_PLUGIN_ROOT` are not set in this sandbox (no
  live plugin install), so the exact canon expression's env-var default
  chain was not exercised end-to-end; the invocation was run with the
  local core checkout path resolved manually instead. Flagged for a human
  to verify against a real plugin install if that matters before this
  record is relied upon as an installed-environment proof.
