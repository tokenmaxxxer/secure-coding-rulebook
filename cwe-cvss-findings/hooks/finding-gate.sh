#!/usr/bin/env bash
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
#                         CWE-ID occurrence must carry a real CVSS vector
#                         string, or a numeric CVSS base score consistent
#                         with a stated severity band, within its own
#                         finding block (from the CWE-ID's line start to
#                         the next blank line / list item / table row) —
#                         a bare severity adjective with no vector or score
#                         does not satisfy this (gate-a-plus.md section 1a).
#
# Fail-closed machinery (EXIT trap, kill switch, JSON parse, Write/Edit/
# MultiEdit reconstruction) is sourced from core canon, never re-derived
# locally (docs/issue-13/proposals/gate-a-plus.md section 0; core issue #72).
#
# Kill switch: export CWE_CVSS_FINDINGS_OFF=1 — only a recognized
# on-spelling (1/true/yes/on) disables; empty, a recognized off-spelling, or
# any unrecognized value all keep the gate active.
. "${CORE_PLUGIN_ROOT:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh"
gate_trap_fail_closed
set -uo pipefail

deny() { gate_deny "cwe-cvss-findings" "$1"; }

gate_kill_switch_active "${CWE_CVSS_FINDINGS_OFF:-}" || exit 0

command -v python3 >/dev/null 2>&1 || deny "requires python3, which is not on PATH; denying rather than guessing."

payload="$(cat 2>/dev/null || true)"

# Root resolution: independent of any tool-call-supplied path — never
# derived by dirname-ing the write target (gate-a-plus.md section 1b; this
# was the confirmed asymmetry vs. level-gate.sh, now closed).
_plausible() {
  [ -n "$1" ] && [ -d "$1" ] && { [ -e "$1/.git" ] || [ -f "$1/docs/specs/role-handoff-contract.md" ]; }
}

root=""
if [ -n "${CLAUDE_PROJECT_DIR:-}" ] && _plausible "$CLAUDE_PROJECT_DIR"; then
  root="$(cd "$CLAUDE_PROJECT_DIR" 2>/dev/null && pwd -P)"
fi
if [ -z "$root" ]; then
  root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
[ -z "$root" ] && deny "no project root could be determined (neither CLAUDE_PROJECT_DIR nor git toplevel); failing closed (cwe-cvss-findings gate cannot run)."

CF_PAYLOAD="$payload" CF_ROOT="$root" \
python3 <<'PY'
import sys as _fc_sys  # fail-closed-on-internal-error
try:
    import importlib.util, os, posixpath, re, sys

    _spec = importlib.util.spec_from_file_location("gate_lib", os.environ["GATE_LIB_PY"])
    gate_lib = importlib.util.module_from_spec(_spec)
    _spec.loader.exec_module(gate_lib)

    def deny(m):
        sys.stderr.write(
            "cwe-cvss-findings: refused — %s "
            "(see docs/issue-10/proposals/enforcement-machine.md)\n" % m
        )
        sys.exit(2)

    raw = os.environ.get("CF_PAYLOAD", "")
    ev = gate_lib.gate_parse_json_or_deny(raw, deny)

    tool = ev.get("tool_name")
    ti = ev.get("tool_input")
    if not isinstance(ti, dict):
        deny("tool_input is missing or not a JSON object; the gate cannot judge a write it cannot parse.")

    root = os.environ["CF_ROOT"]
    RECORD_RE = re.compile(r'^docs/issue-[0-9]+/reports/secure-coding\.md$')

    path = None
    if tool in ("Write", "Edit", "MultiEdit"):
        p = ti.get("file_path")
        if isinstance(p, str) and p:
            path = p
    if path is None:
        sys.exit(0)

    rel = gate_lib.gate_normalize_path(root, path)
    if rel is None:
        sys.exit(0)  # resolves outside root
    if not RECORD_RE.match(rel):
        sys.exit(0)  # not the phase-2 secure-coding record — not this gate's business

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
            "this write targets %s but the resulting content could not be determined "
            "from the tool input (tool=%r). Write the full record with Write, or use an "
            "Edit/MultiEdit whose old_string matches current content." % (rel, tool)
        )

    cwe_re = re.compile(r'\bCWE-\d+\b')
    na_re = re.compile(r'n/a.{0,20}none found|no findings|none found', re.I)

    # CVSS v3.1 official base-score band table (gate-a-plus.md section 1a).
    BAND_TABLE = (
        ("critical", 9.0, 10.0),
        ("high", 7.0, 8.9),
        ("medium", 4.0, 6.9),
        ("low", 0.1, 3.9),
        ("none", 0.0, 0.0),
    )
    VECTOR_RE = re.compile(r'CVSS:3\.[01](?:/[A-Za-z]{1,2}:[A-Za-z])+')
    NUM_BAND_RE = re.compile(r'\b(\d+(?:\.\d+)?)\b[^A-Za-z0-9]{0,15}(critical|high|medium|low|none)\b', re.I)
    BAND_NUM_RE = re.compile(r'\b(critical|high|medium|low|none)\b[^A-Za-z0-9]{0,15}(\d+(?:\.\d+)?)\b', re.I)

    def _band_ok(score, band):
        for name, lo, hi in BAND_TABLE:
            if name == band.lower() and lo <= score <= hi:
                return True
        return False

    def cvss_label_present(window):
        for vm in VECTOR_RE.finditer(window):
            v = vm.group(0)
            if "AV:" in v and "AC:" in v and any(t in v for t in ("C:", "I:", "A:")):
                return True
        for m in NUM_BAND_RE.finditer(window):
            try:
                if _band_ok(float(m.group(1)), m.group(2)):
                    return True
            except ValueError:
                pass
        for m in BAND_NUM_RE.finditer(window):
            try:
                if _band_ok(float(m.group(2)), m.group(1)):
                    return True
            except ValueError:
                pass
        return False

    def block_end(text, cwe_start):
        blank = text.find("\n\n", cwe_start)
        blank = blank if blank != -1 else len(text)
        li = re.search(r'\n[ \t]*(?:[-*][ \t]|\||[0-9]+\.[ \t])', text[cwe_start:blank])
        return cwe_start + li.start() if li else blank

    cwe_matches = list(cwe_re.finditer(new_text))

    if not cwe_matches:
        if na_re.search(new_text):
            sys.exit(0)  # N/A branch — no per-finding severity check needed
        deny(
            "record has no CWE-<id> finding and no explicit N/A/none-found marker "
            "(check: finding-list-or-na)."
        )

    # At least one CWE-ID present: every occurrence needs a CVSS vector or a
    # band-consistent numeric score within its own finding block.
    unlabeled = []
    for m in cwe_matches:
        end = block_end(new_text, m.start())
        window = new_text[m.end():end]
        if not cvss_label_present(window):
            unlabeled.append(m.group(0))

    if unlabeled:
        deny(
            "the following CWE-ID occurrence(s) have no CVSS vector string, or numeric "
            "score consistent with a stated severity band, within their own finding block: "
            "%s (check: cvss-labeled-severity)." % ", ".join(unlabeled)
        )

    sys.exit(0)
except SystemExit:
    raise
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
