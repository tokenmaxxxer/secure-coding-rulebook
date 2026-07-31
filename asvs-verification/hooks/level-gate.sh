#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "asvs-verification: fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
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
#     level-carried-over, asvs-checklist (requirement-ID + pass/fail
#     co-occurring), scope-covered-summary
#
# This is a shape check (string/regex presence), not a semantic ASVS
# correctness check — see README.md's caveats section.
#
# Kill switch: export ASVS_VERIFICATION_OFF=1
set -uo pipefail

# case-insensitive: only ""/0/false/no/off (any case) keep the gate active;
# anything else disables it.
__av_off="$(printf '%s' "${ASVS_VERIFICATION_OFF:-}" | tr '[:upper:]' '[:lower:]')"
case "$__av_off" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

deny() { echo "asvs-verification: refused — $1" >&2; exit 2; }

command -v python3 >/dev/null 2>&1 || deny "python3 is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the ASVS gate."

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
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write("asvs-verification: refused — %s\n" % m)
        sys.exit(2)

    raw = os.environ.get("AV_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge ASVS shape on an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["AV_ROOT"].replace("\\", "/"))

    def resolve(p):
        n = p.replace("\\", "/")
        a = n if posixpath.isabs(n) else posixpath.join(root, n)
        a = posixpath.normpath(a)
        try:
            return posixpath.normpath(os.path.realpath(a).replace("\\", "/"))
        except OSError:
            return a

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)  # not a tool shape this gate understands the target of

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")

    PHASE1_RE = re.compile(r'^docs/issue-[0-9]+/proposals/.*secure-coding.*\.md$')
    PHASE2_RE = re.compile(r'^docs/issue-[0-9]+/reports/secure-coding\.md$')

    is_phase1 = bool(PHASE1_RE.match(rel))
    is_phase2 = bool(PHASE2_RE.match(rel))
    if not (is_phase1 or is_phase2):
        sys.exit(0)  # not this gate's business — allow without evaluating content

    current = None
    if os.path.isfile(r):
        try:
            with open(r, encoding="utf-8-sig") as fh:
                current = fh.read(1 << 20)
        except OSError:
            deny("%s exists but cannot be read; failing closed." % rel)

    new_text = None
    if tool == "Write":
        c = ti.get("content")
        if isinstance(c, str):
            new_text = c
    elif tool == "Edit":
        o, n = ti.get("old_string"), ti.get("new_string")
        if isinstance(o, str) and isinstance(n, str) and current is not None and o in current:
            new_text = current.replace(o, n, 1)
    elif tool == "MultiEdit":
        edits = ti.get("edits")
        text = current
        if isinstance(edits, list) and text is not None:
            ok = True
            for e in edits:
                if not isinstance(e, dict):
                    ok = False; break
                o, n = e.get("old_string"), e.get("new_string")
                if not isinstance(o, str) or not isinstance(n, str) or o not in text:
                    ok = False; break
                text = text.replace(o, n, 1)
            if ok:
                new_text = text
    else:
        deny(
            "this write targets %s but tool_input shape (tool=%r) is not understood; "
            "the resulting content could not be determined per "
            "docs/issue-10/proposals/enforcement-machine.md." % (rel, tool)
        )

    if new_text is None:
        deny(
            "this write targets %s but the gate cannot determine the resulting content "
            "from the tool input (tool=%r) — per docs/issue-10/proposals/enforcement-machine.md "
            "the resulting content could not be determined. Write the full document with Write, "
            "or use an Edit/MultiEdit whose old_string matches." % (rel, tool)
        )

    LEVEL_RE = re.compile(r'\b[Ll][123]\b')
    REQID_RE = re.compile(r'\bV\d+(?:\.\d+){1,3}\b')
    PASSFAIL_RE = re.compile(r'\b(?:pass|fail|passed|failed)\b', re.IGNORECASE)

    if is_phase1:
        missing = []
        level_m = LEVEL_RE.search(new_text)
        reqid_m = REQID_RE.search(new_text)

        if not level_m:
            missing.append("level-named")
        if not reqid_m:
            missing.append("external-id-present")
        if level_m and reqid_m and not (level_m.start() < reqid_m.start()):
            missing.append("level-before-requirements")

        has_survey_ref = (
            "current-state-survey" in new_text
            or re.search(r'docs/issue-\d+/reports/secure-coding/', new_text)
        )
        if not has_survey_ref:
            missing.append("survey-reference")

        if missing:
            deny(
                "phase-1 proposal %s is missing: %s. Per "
                "docs/issue-10/proposals/enforcement-machine.md section (iv), a proposal "
                "under docs/issue-<n>/proposals/*secure-coding*.md must state the ASVS "
                "verification level before any requirement ID, name at least one "
                "requirement ID, and cite the current-state survey." % (rel, ", ".join(missing))
            )
        sys.exit(0)

    if is_phase2:
        missing = []
        if not LEVEL_RE.search(new_text):
            missing.append("level-carried-over")

        checklist_ok = False
        for m in REQID_RE.finditer(new_text):
            window = new_text[m.end():m.end() + 200]
            if PASSFAIL_RE.search(window):
                checklist_ok = True
                break
        if not checklist_ok:
            missing.append("asvs-checklist")

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
                "docs/issue-10/proposals/enforcement-machine.md section (iv), the record must "
                "carry the ASVS level forward, give a checklist where each requirement ID has "
                "a pass/fail token within 200 characters, and state a scope-covered summary." % (rel, ", ".join(missing))
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
