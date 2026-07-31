# issue-10 scout brief — enforcement-machine exemplars

Mode: batched-sequential (not parallel fan-out). Reason: the scout target
is local sibling-rulebook source under this machine's own filesystem
(`~/tokenmaxxxer/rulebooks/{implementation,pricing}-rulebook`), not web
search — reading N local files concurrently via subagents would add
coordination overhead with no latency win over sequential `Read`, and the
issue text names the two exemplars explicitly (implementation-rulebook's
hook machine, pricing-rulebook's methodology-gate.sh), so the angle set was
already scoped rather than discovered. One round, two angles read in
sequence within this turn: (1) implementation-rulebook's `coding/hooks/`
tree end-to-end, (2) pricing-rulebook's `methodology-gate.sh` end-to-end,
plus core canon's `record-fields-gate.sh` as the generic baseline both
build on top of. Stages used: 1 (no deepening round needed — the two named
exemplars plus the generic baseline already saturate: a third rulebook's
gate would very likely restate the same fail-closed/PreToolUse/role-token
shape, per judge point 1 below).

## Must-bes (what every enforcement-machine gate in this codebase has)

1. **Fail-closed trap-at-top**: `trap __fc EXIT` installed as the first
   executable line, remapping any non-{0,2} exit to 2 (deny), because a
   `PreToolUse` hook treats any non-2 exit as fail-*open*. Present in
   `coding-progress-gate.sh`, `record-fields-gate.sh`,
   `pricing/methodology-gate.sh` identically.
2. **Kill switch via named env var**, `""|0|false|no|off` reads as *not*
   killed — every other value kills. (`RECORD_FIELDS_GATE_OFF`,
   `PRICING_METHODOLOGY_GATE_OFF`.)
3. **Root resolution via `CLAUDE_PROJECT_DIR` + git toplevel fallback**,
   identical `_plausible`/`_under` helpers copy-pasted verbatim across all
   three gates (this is itself a role-token-substitution artifact core
   canon's `record-fields-gate.sh` header calls out as the exact bug class
   the "promote to canon" pass was fixing for other scripts).
4. **Target-path narrowing by regex before doing any content work** — a
   write outside the gate's own regex-matched path is `sys.exit(0)`
   immediately ("not this gate's business"), never evaluated further.
5. **New-content reconstruction across Write/Edit/MultiEdit** — the gate
   computes what the file's content *would become*, not just what changed;
   an `Edit`/`MultiEdit` whose `old_string` cannot be located in the
   current file content denies with an explicit "use Write or a matching
   Edit" message rather than silently passing.
6. **Presence checking via `has_any(*needles)` substring/keyword sets**,
   not full parsing — pragmatic, not exhaustive (e.g. pricing's `labeled`
   check is a keyword list, not a grammar).
7. **`exit 2` denial carries an actionable message**: names exactly which
   required element(s) are missing and cites the source-of-truth doc the
   requirement comes from (pricing cites `docs/issue-1/proposals/
  methodology-norms.md`).

## Performance axes the two exemplars visibly differ on

- **Scope of one gate**: pricing's `methodology-gate.sh` covers *both*
  phase-1 proposal and phase-2 record write surfaces in one script (two
  regexes, `PROPOSAL_RE` / `RECORD_RE`, shared field-check logic below).
  implementation's `coding-progress-gate.sh` is narrower in a different
  axis — it doesn't check document *content* fields at all, it checks a
  *cross-record* ordering condition (a commit is blocked until another
  role's record reaches a certain `loop_state`).
- **Ordering enforcement mechanism**: `hunt-guard.sh` + `hunt-state.sh`
  persist state *across separate tool calls in a session* (a lock file +
  count file, reset at `SessionStart`, released at `SubagentStop`) because
  the constraint they enforce ("at most one hunt in flight, at most N per
  session") cannot be recovered from a single tool-call payload.
  `coding-progress-gate.sh` instead re-derives its ordering condition by
  re-reading *both* records fresh on every `git commit` attempt — no
  persisted state file, because git history + the two records' current
  content is already a complete, replayable log of what happened.

## Adopt / skip for this role

- **Adopt**: pricing's single-script, two-regex, fail-closed,
  keyword-presence gate shape wholesale as the pattern for a new
  `secure-coding/hooks/methodology-gate.sh` — it is the closer structural
  match (this role also splits phase-1-proposal vs phase-2-record
  requirements, per `docs/issue-1/proposals/
  secure-coding-rulebook-maturation.md` parts (a) and (b), the exact same
  shape pricing's own norms doc splits on).
- **Adopt**: the "re-derive from current content, no persisted state
  file" approach from `coding-progress-gate.sh`'s ordering check, *for the
  verification-level-before-requirements constraint specifically* — see
  gap line below for why a lock/count file is not warranted here.
- **Skip**: `hunt-guard.sh`/`hunt-state.sh`'s persisted-lock pattern for
  this role's ordering constraint — that pattern exists to bound a
  cross-call *resource* (concurrent/cumulative subagent spawns), not to
  check a *document's* internal section order, which a single read of the
  in-progress write's reconstructed content already answers.
- **Skip**: `secure-coding/agents/` vendoring anything from
  `implementation-rulebook`'s `blueprint/` or `no-mock`/`no-footgun`
  sibling plugins — those are a different role's repeated-procedure
  checklists (blueprint generation, mock-ban enforcement) with no
  ASVS/CWE-CVSS analogue; issue-1's part (d)-4 already ruled out vendoring
  `warrant-hunter.md` for this exact reason (canon-reference only, never
  copy).

## Gap line (what the surveyed current state already meets vs. still
misses, against these must-bes)

- Already meets: must-be 3 (root resolution) and must-be 1 (fail-closed
  trap) are *available* to this plugin for free — they are core-canon
  shell idiom, not code this plugin has to invent; the proposal below
  reuses them verbatim rather than redesigning.
- Missing entirely: must-bes 2, 4, 5, 6, 7 — none of them exist anywhere
  in `secure-coding/` today, because no `PreToolUse` hook exists in this
  plugin at all (survey finding: `hooks.json` registers `SessionStart`
  only).
- Missing entirely: the ordering-enforcement axis — neither the
  re-derive-fresh nor the persisted-state variant exists for this role's
  "level before requirements" constraint.

## Sources

- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/coding-progress-gate.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/hunt-guard.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/implementation-rulebook/coding/hooks/hunt-state.sh`
- `/home/jwjung/tokenmaxxxer/rulebooks/pricing-rulebook/pricing/hooks/methodology-gate.sh`
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/record-fields-gate.sh`
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/core/hooks/lib/role-directive.sh`
- `/home/jwjung/tokenmaxxxer/tokenmaxxxer-core/docs/handbooks/canon-scripts.md`
- `docs/issue-1/proposals/secure-coding-rulebook-maturation.md` (this
  repo's own adopted norms — the methodology source, not an external
  exemplar, but load-bearing for what the gate must check)
