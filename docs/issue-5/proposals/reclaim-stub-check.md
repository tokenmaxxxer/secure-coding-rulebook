# issue-5 proposal — reclaim vendored stub-check.sh copy

Subject: issue-5. Phase-1 proposal (role-handoff contract v3 s19) — no code
changes in this commit; execution starts only after Approve. Basis: see
`docs/issue-5/reports/implementation/current-state-survey.md`.

## Change set

**1. Delete the vendored copy.**
Delete `secure-coding/hooks/tests/stub-check.sh` outright. It is a verbatim
copy of core canon (`core/hooks/tests/canon-manifest.txt` lists
`stub-check.sh` itself); canon requires reference execution only
(`docs/handbooks/canon-scripts.md`).

**2. hooks.json — no change needed.**
`secure-coding/hooks/hooks.json` has a single `SessionStart` →
`directive.sh` entry; it never registered `stub-check.sh` (not a hook
trigger, a test-harness script). Nothing to remove here — recorded
explicitly so a later reader doesn't have to re-derive it.

**3. Reference-execute instead, per canon's stated invocation model.**
`docs/handbooks/role-gates-tests.md` ("Canon invocation from a rulebook")
gives the exact expression:

```sh
"${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/tests/stub-check.sh" "$(dirname "$0")/.."
```

This repo has no existing test-harness file that called the vendored copy
(survey found none), so phase 2 has no call-site to rewrite — only to run
this invocation once directly against `secure-coding/` and record the
command + pass/fail output in `docs/issue-5/reports/implementation.md`, per
the issue's own instruction ("core 참조 실행으로 stub-check 통과를 record에
기록하라").

## Files touched (phase 2, post-Approve)

- Delete: `secure-coding/hooks/tests/stub-check.sh`
- No edit to `secure-coding/hooks/hooks.json` (confirmed no entry exists)
- Record only: `docs/issue-5/reports/implementation.md` (invocation command
  + result)

## Not in scope

- Building a permanent test-harness file (e.g. a `run-role-gates-tests.sh`
  equivalent) to wrap the reference call — the issue asks only for the
  copy's removal and a recorded reference-execution pass, not a new
  harness script. Left as a future decision if this rulebook later wants
  one.
