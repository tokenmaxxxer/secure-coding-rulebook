# issue-16 phase-1 current-state survey — Gate A+ final closeout residuals

Subject: issue-16 ("게이트 A+ 최종 마감: 재감사 잔여 결함 보수", 2026-08-01
re-audit, grade A). Scope: the residual defects the re-audit named, after
confirming the two named preconditions are landed on `tokenmaxxxer-core`'s
`main`.

**Scout directive: skipped.** This is a bounded defect-remediation task —
the issue enumerates the exact residual defects (source guard, var-name
mismatch, matcher/coverage parity, missing-core test, README/manifest
ghost text) and the fix shape for the "공통" (common) items is dictated by
already-landed core canon (core issue #75, PR #77), not an open design
choice. No product/UX surface to scout against.

## 0. Precondition check (both confirmed landed)

- **core issue #75** (`tokenmaxxxer-core`, closed) — "gate-lib 하우스 표준
  결함 2건: source 무가드 fail-open + gate_bash_write_targets py 부재".
  Landed via PR #76 (propose) + PR #77 (deliver), commits `24eb5ed` /
  `52bdc15` on `main`. Verified by cloning `tokenmaxxxer-core` fresh
  (`git log --oneline`, `main` HEAD includes `52bdc15`).
- **on-the-record issue #182** (closed) — "spawn.py: role 세션에
  CLAUDE_PLUGIN_ROOT_CORE 주입". Verified via `gh issue view 182 -R
  tokenmaxxxer/on-the-record` — `state: CLOSED`. Not this rulebook's file
  surface (`spawn.py` lives in `on-the-record`); noted only as the
  confirmed precondition per issue-16's own text.

## 1. What core issue #75 actually landed (reference basis for the fixes below)

Read from the fresh `tokenmaxxxer-core` clone at `main` (`52bdc15`):

- `core/hooks/lib/gate-lib.sh`'s own usage comment (top of file) now shows
  the **mandatory-guarded** source line:
  ```
  . "${CLAUDE_PLUGIN_ROOT_CORE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)}/hooks/lib/gate-lib.sh" || { echo "<gate-name>.sh: cannot source gate-lib.sh" >&2; exit 2; }
  ```
  Every one of core's own gates (`approval-gate.sh`, `board-gate.sh`,
  `gh-guard.sh`, `trailer-gate.sh`, `record-fields-gate.sh`,
  `handbook-trigger-gate.sh`, `directive.sh`) sources exactly this guarded
  line, using **`CLAUDE_PLUGIN_ROOT_CORE`** as the env var name — confirmed
  by grep across `core/hooks/*.sh`.
- `docs/handbooks/gate-house-standard.md` states the guard is "mandatory"
  and explains why: an unguarded source that fails leaves no `gate_*`
  function defined; the resulting "command not found" (rc 127) is read by
  every `gate_kill_switch_active ... || { exit 0; }` call site as "kill
  switch off," silently allowing everything.
- `core/hooks/tests/compliance-check.sh` (line ~58) now has a rule that
  flags "sources gate-lib.sh with no `||` guard on the same line."
- `core/hooks/tests/run-gate-lib-tests.sh` documents seven **mandatory**
  case groups (`gate-house-standard.md` "Mandatory test coverage"
  section), group 7 being: "`gate-lib.sh` sourced with
  `CLAUDE_PLUGIN_ROOT_CORE` pointed at a nonexistent path and no valid
  relative fallback — must assert **deny** (exit 2), not the pre-issue-75
  silent-allow bug" (`mark missing-core` in the suite, lines 230-246).
- `gate-lib.py` (line 159-171) now has `gate_bash_write_targets`,
  sh/py-parity-tested (issue-75's second fix). Note: this rulebook's two
  gates only ever call `gate_lib.gate_reconstruct_write` on `Write`/
  `Edit`/`MultiEdit` tool_input — neither calls `gate_bash_write_targets`
  (see §3) — so the py-parity fix has no direct call site here; it is
  reference context only, not a file this rulebook must touch.

`CORE_PLUGIN_ROOT` (distinct from `CLAUDE_PLUGIN_ROOT_CORE`) remains the
correct, unchanged name for a *different* purpose in core canon: locating
a `tokenmaxxxer-core` checkout to invoke `compliance-check.sh`/
`stub-check.sh` as external CLI tools from a rulebook's own test runner
(`core/hooks/tests/compliance-check.sh`'s own invocation-comment still
uses `${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}`). This is not the
variable this issue's "하우스 불일치" complaint targets — see §2.

## 2. This rulebook's two gates against the landed contract (confirmed defects)

`asvs-verification/hooks/level-gate.sh:30` and
`cwe-cvss-findings/hooks/finding-gate.sh:28` both currently read:

```sh
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
```

Two confirmed defects against §1's landed contract:

1. **No `||` guard at all** — exactly the issue-75 fail-open shape: if
   this source fails (core unreachable), no trap installs and no `gate_*`
   function is defined; the very next line, `gate_trap_fail_closed`,
   itself becomes "command not found" (the script has no `set -e`, so
   execution continues); `gate_kill_switch_active` two lines later is
   also undefined → rc 127 → `|| exit 0` silently allows the write. Live,
   reproducible bug, identical mechanism to the one issue-75 fixed in
   core's own gates.
2. **Wrong env var name** — `CORE_PLUGIN_ROOT` where the landed contract
   (all seven of core's own gates, the handbook, the mandatory test
   group 7) uses `CLAUDE_PLUGIN_ROOT_CORE`. This is issue-16's own
   "CORE_PLUGIN_ROOT 변수명 하우스 불일치" line. Concretely: `on-the-record`
   issue #182 (confirmed landed, §0) makes `spawn.py` inject
   `CLAUDE_PLUGIN_ROOT_CORE` into every role session's environment — a
   gate reading `CORE_PLUGIN_ROOT` never sees that injected value at all
   and always falls through to the relative `$CLAUDE_PLUGIN_ROOT/../core`
   guess, defeating the very fix #182 shipped.

`secure-coding/hooks/directive.sh:2` already sources
`role-directive.sh` via the correct `CLAUDE_PLUGIN_ROOT_CORE` name — but
without the `||` guard either (`. "${CLAUDE_PLUGIN_ROOT_CORE:-...}/hooks/lib/role-directive.sh"`,
no `|| { ... exit 2; }`). This is a SessionStart steering hook, not a
PreToolUse enforcement gate, so an unguarded failure here degrades to "no
directive banner printed" rather than "every write silently allowed" —
lower severity, but still the same unguarded-source shape flagged by
`compliance-check.sh`; in scope for the same fix for consistency and to
keep `compliance-check.sh` clean end-to-end (issue-16 requirement 3).

`asvs-verification/hooks/directive.sh` and
`cwe-cvss-findings/hooks/directive.sh` are UserPromptSubmit steering hooks
only (methodology reminder banners) — they do not source `gate-lib.sh` at
all (confirmed by reading both files in full) and are out of scope for
this defect class.

## 3. hooks.json matcher vs. code tool-coverage parity

- `asvs-verification/hooks/hooks.json` — `PreToolUse` matcher
  `"Write|Edit|MultiEdit"`. `level-gate.sh`'s Python payload dispatches on
  `tool in ("Write", "Edit", "MultiEdit")` (line 79) and `sys.exit(0)` for
  anything else (line 83-84) — **matches exactly**.
- `cwe-cvss-findings/hooks/hooks.json` — same matcher; `finding-gate.sh`
  dispatches identically (`tool in ("Write", "Edit", "MultiEdit")`,
  confirmed by reading the file). **Matches exactly.**
- Neither gate calls `gate_lib.gate_bash_write_targets` or matches
  `Bash` in its matcher — by design: both gates reconstruct a **full
  document diff** (`gate_reconstruct_write`) to run structural/adjacency
  checks against the resulting text, a shape `Bash` tool calls (arbitrary
  shell) cannot supply the way `Write`/`Edit`/`MultiEdit` do. Core's own
  `record-fields-gate.sh` documents the identical scope call ("a Bash
  write to the record is out of this gate's scope ... board-gate/
  scope-gate handle Bash", `core/hooks/record-fields-gate.sh:122-123`) —
  this rulebook has no board-gate/scope-gate equivalent (core's
  role-agnostic `board-gate.sh`/`approval-gate.sh` already cover Bash
  globally per `core/hooks/hooks.json`'s `matcher: ".*"`). **No coverage
  gap found** here — the matcher-vs-code parity is already correct; this
  is confirmed, not assumed.
- `secure-coding/hooks/hooks.json` registers only `SessionStart` →
  `directive.sh`; correct, this plugin has no `PreToolUse` gate of its
  own (the two methodology plugins carry the gates).

## 4. Mandatory test-suite coverage vs. core canon's seven groups

`docs/handbooks/gate-house-standard.md`'s "Mandatory test coverage"
section lists seven groups a rulebook gate's test suite must exercise.
Checked both `run-level-gate-tests.sh` (30 cases) and
`run-finding-gate-tests.sh` (21 cases) for each:

| Group | level-gate suite | finding-gate suite |
|---|---|---|
| 1. malformed JSON denies | present (`malformed-json`, non-object variant) | present |
| 2. kill-switch unrecognized value stays active | present | present |
| 3. `Edit`/`MultiEdit` `replace_all` per-edit | present | present |
| 4. trap-at-top forced-crash fail-closed | present | present |
| 5. absolute vs. relative path same verdict | present | present |
| 6. Bash-tool write reaching a target `Write` would hit, + sh/py `gate_bash_write_targets` parity | **not applicable** — neither gate has a Bash-tool code path at all (§3); nothing to test | **not applicable**, same reason |
| 7. `gate-lib.sh` sourced with `CLAUDE_PLUGIN_ROOT_CORE` pointed nowhere and no relative fallback → must **deny** | **missing** — no such case in either suite (confirmed by grep for `nonexistent`/`no-such-core`/`missing-core`, zero hits) | **missing**, same |

Group 7 ("missing-core") is a genuine, confirmed gap in both suites — the
gate's own confirmed unguarded-source bug (§2) has never been
regression-tested. Group 6 is not a gap: it presumes a Bash-tool code
path this design does not have, matching core's own precedent
(`record-fields-gate.sh`) for content-diffing gates that scope out Bash.

## 5. README / manifest ghost text ("옛 역할명·유령 파일 잔재")

Grepped the whole tree (`grep -rn "scaffolding\|CORE_PLUGIN_ROOT"`) plus a
manual read of all three `.claude-plugin/plugin.json` manifests and all
three plugin `README.md`s (root, `asvs-verification/`,
`cwe-cvss-findings/`):

- Root `README.md`:
  - Line 5: "생성됨 as skeleton scaffolding by issue-170" — vestigial
    scaffold-generation language from before this rulebook had real
    content (issue-1/5/10/13 all landed since).
  - Line 40: "This is scaffolding, not a finished rulebook: fill in
    doctrine detail, handoff enforcement, and any role-specific progress
    gate before treating it as load-bearing." — same; the rulebook now
    has a landed methodology-plugin set (issue-10/13), so this disclaimer
    is stale and directly matches issue-16's named complaint.
  - `## Layout` section (lines 30-38) lists only `secure-coding/`'s own
    four items (manifest, hooks.json, directive.sh, stub-check.sh
    reference note) plus `docs/specs/approvers.md`. It never mentions
    `asvs-verification/` or `cwe-cvss-findings/` at all — the two
    plugins that carry every PreToolUse gate in this rulebook are absent
    from the layout list. This is the "Layout에 게이트 플러그인 누락"
    defect named in the issue.
- Role names/handoff: `README.md`'s `hand-off` line points to
  `security-threat-model` — verified as a real, current role
  (`security-threat-model-rulebook` exists in the `tokenmaxxxer` org,
  confirmed via `gh repo list tokenmaxxxer`). Not a ghost/renamed role.
- File references: `secure-coding/README.md`'s "no longer vendored"
  claims for `stub-check.sh` and its `core`/`warrant` install
  instructions were checked against the actual `secure-coding/hooks/`
  directory listing (`directive.sh`, `hooks.json` only) — no stray
  vendored copy exists; this line is accurate, not ghost text.
- No stale/renamed-role references or nonexistent file paths found in
  `asvs-verification/README.md` or `cwe-cvss-findings/README.md`, or in
  any of the three `.claude-plugin/plugin.json` manifests (all three
  `name`/`description` fields match the actual plugin they describe and
  the actual gate files that exist).

## 6. Scope for phase 1's proposal

Confirmed, in-scope fixes: (a) `||`-guard + `CLAUDE_PLUGIN_ROOT_CORE`
rename on all three source lines that currently lack one
(`level-gate.sh`, `finding-gate.sh`, `secure-coding/hooks/directive.sh`);
(b) add the missing-core mandatory test case (group 7) to both gate test
suites; (c) strip the two stale "scaffolding" lines from the root
`README.md` and extend its `## Layout` section to list
`asvs-verification/` and `cwe-cvss-findings/`; (d) re-run
`compliance-check.sh` against both gates' hooks dirs and record clean.
Confirmed NOT in scope (no gap found): hooks.json matcher/code parity
(§3, already correct), Bash-tool coverage (§4 group 6, not applicable by
design), any ghost role name or ghost file reference (§5, none found
beyond the two literal README items already listed under (c)).
