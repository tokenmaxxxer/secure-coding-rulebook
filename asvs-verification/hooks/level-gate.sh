#!/usr/bin/env bash
# PreToolUse gate (Write|Edit|MultiEdit) for the asvs-verification plugin.
#
# Enforces the ASVS methodology's phase-split norm per
# docs/issue-10/proposals/enforcement-machine.md section (iii) row 1 and
# section (iv):
#
#   phase-1 (docs/issue-<n>/proposals/*secure-coding*.md):
#     level-named, external-id-present, level-before-requirements,
#     survey-reference
#
#   phase-2 (docs/issue-<n>/reports/secure-coding.md):
#     level-carried-over, asvs-checklist (every requirement ID carries its
#     own pass/fail token within its own row/list-item boundary),
#     scope-covered-summary
#
# Checks are section/adjacency/structural (docs/issue-13/proposals/gate-a-plus.md
# section 2), not flat substring search: level-named and survey-reference
# must sit in a line/section actually governed by the right heading or
# phrase, and asvs-checklist validates every requirement ID occurrence, not
# just the first.
#
# Fail-closed machinery (EXIT trap, kill switch, JSON parse, Write/Edit/
# MultiEdit reconstruction) is sourced from core canon, never re-derived
# locally (docs/issue-13/proposals/gate-a-plus.md section 0; core issue #72).
#
# Kill switch: export ASVS_VERIFICATION_OFF=1 — only a recognized
# on-spelling (1/true/yes/on) disables; empty, a recognized off-spelling, or
# any unrecognized value all keep the gate active.
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail

deny() { gate_deny "asvs-verification" "$1"; }

gate_kill_switch_active "${ASVS_VERIFICATION_OFF:-}" || exit 0

command -v python3 >/dev/null 2>&1 || deny "python3 is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

# Root resolution: independent of any tool-call-supplied path — never
# derived by dirname-ing the write target (gate-a-plus.md section 1b).
_plausible() { [ -n "$1" ] && [ -d "$1" ]; }

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && deny "no project root could be determined (neither CLAUDE_PROJECT_DIR nor git toplevel); failing closed."

AV_PAYLOAD="$payload" AV_ROOT="$root" python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write("asvs-verification: refused — %s\n" % m)
        sys.exit(2)

    raw = os.environ.get("AV_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = os.environ["AV_ROOT"]

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)  # not a tool shape this gate understands the target of

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)  # resolves outside root — not this gate's business

    PHASE1_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*secure-coding.*\.md$')
    PHASE2_RE = re.compile(r'^docs/issue-[0-9]+/reports/secure-coding\.md$')

    is_phase1 = bool(PHASE1_RE.match(rel))
    is_phase2 = bool(PHASE2_RE.match(rel))
    if not (is_phase1 or is_phase2):
        sys.exit(0)  # not this gate's business — allow without evaluating content

    r = posixpath.join(root, rel) if rel else root

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text, ok = gate_lib.gate_reconstruct_write(tool, ti, current)
    if not ok:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r) — the resulting content could not be determined. "
            "Write the full document with Write, or use an Edit/MultiEdit whose old_string "
            "matches." % (rel, tool)
        )

    # --- adjacency/structural checks (gate-a-plus.md section 2) ---

    LEVEL_RE = re.compile(r'\b[Ll][123]\b')
    REQID_RE = re.compile(r'\bV\d+(?:\.\d+){1,3}\b')
    PASSFAIL_RE = re.compile(r'\b(?:pass|fail|passed|failed)\b', re.IGNORECASE)

    # level-named: the L[123] token must sit within 60 characters of the
    # word "level" (in either order) on the same line — a governing
    # statement ("Verification Level: L2", "level L2 is chosen") — not a
    # bare L[123] token isolated in an unrelated footnote or code block
    # with no "level" word anywhere nearby.
    LEVEL_PROX_RE = re.compile(
        r'(?:verification\s*)?level\b[^\n]{0,60}?\b([Ll][123])\b'
        r'|\b([Ll][123])\b[^\n]{0,60}?(?:verification\s*)?level\b',
        re.IGNORECASE,
    )

    def find_level(text):
        m = LEVEL_PROX_RE.search(text)
        if not m:
            return None
        return m.start(1) if m.group(1) else m.start(2)

    # survey-reference: the canonical artifact-name token
    # (`current-state-survey`, hyphenated throughout) or an explicit path
    # citation always counts; a generic "current-state survey" mention
    # (space-separated prose, not the artifact token) counts only when
    # adjacent to a backtick/path citation within 80 characters — a bare
    # mention of the phrase with nothing cited no longer passes.
    SURVEY_RE = re.compile(
        r'\bcurrent-state-survey\b'
        r'|docs/issue-\d+/reports/secure-coding/[\w./-]+'
        r'|current-state[ ]survey[^\n]{0,80}?[`/]'
        r'|[`/][^\n]{0,80}?current-state[ ]survey',
        re.IGNORECASE,
    )

    def row_end(text, start):
        blank = text.find("\n\n", start)
        blank = blank if blank != -1 else len(text)
        li = re.search(r'\n[ \t]*(?:[-*][ \t]|\||[0-9]+\.[ \t])', text[start:blank])
        return start + li.start() if li else blank

    if is_phase1:
        missing = []
        level_off = find_level(new_text)
        reqid_m = REQID_RE.search(new_text)

        if level_off is None:
            missing.append("level-named")
        if not reqid_m:
            missing.append("external-id-present")
        if level_off is not None and reqid_m and not (level_off < reqid_m.start()):
            missing.append("level-before-requirements")

        has_survey_ref = SURVEY_RE.search(new_text) is not None
        if not has_survey_ref:
            missing.append("survey-reference")

        if missing:
            deny(
                "phase-1 proposal %s is missing: %s. Per "
                "docs/issue-10/proposals/enforcement-machine.md section (iv), a proposal "
                "under docs/issue-<n>/proposals/*secure-coding*.md must state the ASVS "
                "verification level in a level-governed statement before any requirement ID, "
                "name at least one requirement ID, and cite the current-state survey with an "
                "adjacent path/citation (not a bare mention of the word)." % (rel, ", ".join(missing))
            )
        sys.exit(0)

    if is_phase2:
        missing = []
        if not LEVEL_RE.search(new_text):
            missing.append("level-carried-over")

        # asvs-checklist: every requirement ID occurrence needs its own
        # pass/fail token within its own row/list-item boundary — not just
        # the first occurrence in the whole document.
        reqid_matches = list(REQID_RE.finditer(new_text))
        unlabeled = []
        for m in reqid_matches:
            end = row_end(new_text, m.end())
            window = new_text[m.end():end]
            if not PASSFAIL_RE.search(window):
                unlabeled.append(m.group(0))
        if not reqid_matches:
            missing.append("asvs-checklist")
        elif unlabeled:
            missing.append("asvs-checklist (unlabeled requirement ID(s): %s)" % ", ".join(unlabeled))

        scope_ok = bool(
            re.search(r'scope.{0,20}covered', new_text, re.IGNORECASE)
            or "scope-covered" in new_text.lower()
            or "coverage summary" in new_text.lower()
        )
        if not scope_ok:
            missing.append("scope-covered-summary")

        if missing:
            deny(
                "phase-2 record %s is missing: %s. Per "
                "docs/issue-10/proposals/enforcement-machine.md section (iv) and "
                "docs/issue-13/proposals/gate-a-plus.md section 2, the record must carry the "
                "ASVS level forward, give every requirement ID its own pass/fail token within "
                "its own row/list-item boundary, and state a scope-covered summary." % (rel, ", ".join(missing))
            )
        sys.exit(0)

    sys.exit(0)
except SystemExit:
    raise
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("asvs-verification: fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "asvs-verification: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
