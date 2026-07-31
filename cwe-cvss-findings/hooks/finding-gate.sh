#!/usr/bin/env bash
__fc(){ rc=$?; if [ "$rc" != 0 ] && [ "$rc" != 2 ]; then echo "cwe-cvss-findings: refused — fail-closed: gate aborted (rc=$rc)" >&2; exit 2; fi; }
trap __fc EXIT
# PreToolUse gate (Write|Edit|MultiEdit) for the cwe-cvss-findings plugin.
#
# Phase-2-only: fires exclusively on writes whose resolved target matches
# docs/issue-<n>/reports/secure-coding.md. Any other path is allowed
# without content evaluation — this plugin never gates phase-1 proposals,
# per docs/issue-10/proposals/enforcement-machine.md (iv).
#
# Checks on the reconstructed resulting document text:
#   finding-list-or-na    at least one CWE-<digits> token, OR an explicit
#                         N/A-none-found marker.
#   cvss-labeled-severity (only when at least one CWE-ID is present) every
#                         CWE-ID occurrence must have a CVSS/severity-band
#                         token within 300 chars after it — block-scoped.
#
# Kill switch: export CWE_CVSS_FINDINGS_OFF=1
set -uo pipefail

deny() { echo "cwe-cvss-findings: refused — $1" >&2; exit 2; }

case "${CWE_CVSS_FINDINGS_OFF:-}" in
  ""|0|false|no|off) ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || deny "empty tool-use payload on stdin; cannot evaluate the finding gate."

_target="$(printf '%s' "$payload" | python3 -c '
import json,sys
try: e=json.loads(sys.stdin.read())
except Exception: sys.exit(0)
ti=e.get("tool_input") if isinstance(e,dict) else None
if isinstance(ti,dict):
    v=ti.get("file_path")
    if isinstance(v,str) and v: print(v)
' 2>/dev/null || true)"

_plausible() { [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }; }
_under() {
  [ -z "$2" ] && return 0
  python3 -c '
import os,posixpath,sys
r,t=sys.argv[1],sys.argv[2]
try: rr=posixpath.normpath(os.path.realpath(r).replace("\\","/"))
except Exception: sys.exit(1)
n=t.replace("\\","/"); a=n if posixpath.isabs(n) else posixpath.join(rr,n)
a=posixpath.normpath(a); real=posixpath.normpath(os.path.realpath(a).replace("\\","/"))
sys.exit(0 if (real==rr or real.startswith(rr+"/")) else 1)
' "$1" "$2"
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR" && _under "$CLAUDE_PROJECT_DIR" "$_target"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  d="$_target"; [ -n "$d" ] || d="$(pwd -P)"; [ -d "$d" ] || d="$(dirname "$d")"
  root="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && root="$(git -C "$(pwd -P)" rev-parse --show-toplevel 2>/dev/null || true)"
[ -z "$root" ] && deny "no project root could be determined; failing closed (cwe-cvss-findings gate cannot run)."

CF_PAYLOAD="$payload" CF_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import json, os, posixpath, re, sys

    def deny(m):
        sys.stderr.write(
            "cwe-cvss-findings: refused — %s "
            "(see docs/issue-10/proposals/enforcement-machine.md)\n" % m
        )
        sys.exit(2)

    raw = os.environ.get("CF_PAYLOAD", "")
    try:
        ev = json.loads(raw) if raw else {}
    except ValueError:
        deny("the tool-call payload is not valid JSON; the gate cannot judge an unparseable write.")
    if not isinstance(ev, dict):
        deny("the tool-call payload is not a JSON object; failing closed.")

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = posixpath.normpath(os.environ["CF_ROOT"].replace("\\", "/"))
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/secure-coding\.md$')

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
        sys.exit(0)

    r = resolve(path)
    if not r.startswith(root + "/"):
        sys.exit(0)
    rel = r[len(root):].lstrip("/")
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not the phase-2 secure-coding record — not this gate's business

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

    if new_text is None:
        deny(
            "this write targets %s but the resulting content could not be determined "
            "from the tool input (tool=%r). Write the full record with Write, or use an "
            "Edit/MultiEdit whose old_string matches current content." % (rel, tool)
        )

    cwe_re = re.compile(r'\bCWE-\d+\b')
    na_re = re.compile(r'n/a.{0,20}none found|no findings|none found', re.I)
    sev_re = re.compile(r'\b(?:cvss|critical|high|medium|low)\b', re.I)

    cwe_matches = list(cwe_re.finditer(new_text))

    if not cwe_matches:
        if na_re.search(new_text):
            sys.exit(0)  # N/A branch — no per-finding severity check needed
        deny(
            "record has no CWE-<id> finding and no explicit N/A/none-found marker "
            "(check: finding-list-or-na)."
        )

    # At least one CWE-ID present: every occurrence needs a nearby CVSS/band label.
    unlabeled = []
    for m in cwe_matches:
        window = new_text[m.end(): m.end() + 300]
        if not sev_re.search(window):
            unlabeled.append(m.group(0))

    if unlabeled:
        deny(
            "the following CWE-ID occurrence(s) have no CVSS/severity-band label within "
            "300 characters after them: %s (check: cvss-labeled-severity)." % ", ".join(unlabeled)
        )

    sys.exit(0)
except Exception as _fc_e:  # fail-closed-on-internal-error
    _fc_sys.stderr.write("cwe-cvss-findings: refused — fail-closed: internal error: %r\n" % (_fc_e,))
    _fc_sys.exit(2)
PY
_fc_rc=$?
if [ "$_fc_rc" -ne 0 ] && [ "$_fc_rc" -ne 2 ]; then
  echo "cwe-cvss-findings: refused — fail-closed: internal error (judge exited $_fc_rc)" >&2
  exit 2
fi
exit "$_fc_rc"
