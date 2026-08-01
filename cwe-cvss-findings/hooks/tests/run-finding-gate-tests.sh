#!/usr/bin/env bash
# Exercises hooks/finding-gate.sh as a real subprocess via stdin JSON
# payloads. bash 3.2 compatible: no ${var^^}, no associative arrays.
#
# want: "allow" (exit 0) | "deny" (exit 2)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../finding-gate.sh"
ROOT="$(cd "$HERE/../../.." && pwd -P)"

# gate-lib.sh/gate-lib.py are core canon (docs/issue-13/proposals/gate-a-plus.md
# section 0) — referenced, never vendored. This harness runs the gate as a
# bare subprocess with no Claude Code plugin context, so CORE_PLUGIN_ROOT
# must be pointed at a real core canon checkout; the gate itself still
# falls back to "$CLAUDE_PLUGIN_ROOT/../core" at real runtime.
if [ -z "${CORE_PLUGIN_ROOT:-}" ]; then
  for c in \
    "$HOME/.claude/plugins/marketplaces/tokenmaxxxer/runs/rulebooks/tokenmaxxxer-core/core" \
    "$ROOT/../tokenmaxxxer-core/core"; do
    if [ -f "$c/hooks/lib/gate-lib.sh" ]; then CORE_PLUGIN_ROOT="$c"; break; fi
  done
fi
[ -n "${CORE_PLUGIN_ROOT:-}" ] && [ -f "$CORE_PLUGIN_ROOT/hooks/lib/gate-lib.sh" ] || {
  echo "run-finding-gate-tests: cannot find core canon gate-lib.sh; set CORE_PLUGIN_ROOT (or CLAUDE_PLUGIN_ROOT_CORE) to a checkout of tokenmaxxxer-core (core issue #72) before running this suite." >&2
  exit 1
}
export CORE_PLUGIN_ROOT
: "${CLAUDE_PLUGIN_ROOT_CORE:=$CORE_PLUGIN_ROOT}"
export CLAUDE_PLUGIN_ROOT_CORE

pass=0
fail=0

report() {
  # report <want> <got> <name>
  if [ "$1" = "$2" ]; then
    pass=$((pass + 1)); printf 'ok %s\n' "$3"
  else
    fail=$((fail + 1)); printf 'FAIL %s (want=%s got=%s)\n' "$3" "$1" "$2"
  fi
}

# run_case <name> <want-rc> <payload-json> [expect-stderr-substring]
run_case() {
  name="$1"; want="$2"; payload="$3"; expect="${4:-}"
  out="$(printf '%s' "$payload" | CLAUDE_PROJECT_DIR="$ROOT" "$GATE" 2>&1 1>/dev/null)"
  got=$?
  report "$want" "$got" "$name"
  if [ -n "$expect" ]; then
    case "$out" in
      *"$expect"*) : ;;
      *) fail=$((fail + 1)); printf 'FAIL %s-stderr (missing %s) got=%s\n' "$name" "$expect" "$out" ;;
    esac
  fi
}

json_write() {
  # json_write <file_path> <content>
  python3 -c '
import json,sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))
' "$1" "$2"
}

REC="docs/issue-10/reports/secure-coding.md"
PROPOSAL="docs/issue-10/proposals/enforcement-machine.md"

# 1. phase-2 allow: one CWE finding with CVSS label in the same block.
p1="$(json_write "$REC" 'Findings: CWE-79 (CVSS 7.5 High) reproduced via XSS payload; remediation: escaped output.')"
run_case "allow-cwe-with-cvss" 0 "$p1"

# 2. phase-2 allow: explicit N/A, no CWE token anywhere.
p2="$(json_write "$REC" 'Findings: N/A — none found. No weaknesses identified in this scope.')"
run_case "allow-na-no-cwe" 0 "$p2"

# 3. phase-2 deny: CWE present, no CVSS/band label nearby.
p3="$(json_write "$REC" 'Findings: CWE-89 SQL injection reproduced; remediation status: fixed.')"
run_case "deny-cwe-no-cvss" 2 "$p3" "cvss-labeled-severity"

# 4. phase-2 deny: no CWE and no N/A marker at all.
p4="$(json_write "$REC" 'Findings: we looked around and things seem okay.')"
run_case "deny-no-cwe-no-na" 2 "$p4" "finding-list-or-na"

# 5. phase-2 deny: two findings, only one has a CVSS label in its own block.
long_gap="$(python3 -c 'print("x"*400)')"
p5="$(json_write "$REC" "Finding A: CWE-79 (CVSS High) reproduced. Finding B: CWE-89 reproduced. $long_gap")"
run_case "deny-block-scoped-partial-cvss" 2 "$p5" "cvss-labeled-severity"

# 6. non-matching path: allow without evaluating content (deliberately invalid content).
p6="$(json_write "$PROPOSAL" 'this has no CWE and no N/A marker at all, garbage content')"
run_case "allow-non-matching-path" 0 "$p6"

# 7. malformed JSON payload → fail-closed deny.
run_case "deny-malformed-json" 2 '{not valid json'

# 7b. syntactically valid JSON that is not an object (bare array) → deny
# (gate-a-plus.md mandatory case 10).
run_case "deny-malformed-json-non-object" 2 '["not", "an", "object"]'

# 8. Edit whose old_string does not match existing file content → deny.
p8="$(python3 -c '
import json
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"'"$REC"'","old_string":"this string does not exist in the file at all zzz","new_string":"CWE-79 CVSS High"}}))
')"
run_case "deny-edit-old-string-unmatched" 2 "$p8"

# 9. kill-switch: content missing everything, but gate is off → allow regardless.
p9="$(json_write "$REC" 'no cwe, no na marker, nothing at all')"
out9="$(printf '%s' "$p9" | CLAUDE_PROJECT_DIR="$ROOT" CWE_CVSS_FINDINGS_OFF=1 "$GATE" 2>&1 1>/dev/null)"
got9=$?
report 0 "$got9" "allow-kill-switch"

# 9b. unrecognized kill-switch value must NOT disable the gate (gate-a-plus.md
# mandatory case 13 — the confirmed fail-open bug).
out9b="$(printf '%s' "$p9" | CLAUDE_PROJECT_DIR="$ROOT" CWE_CVSS_FINDINGS_OFF=maybe "$GATE" 2>&1 1>/dev/null)"
got9b=$?
report 2 "$got9b" "kill-switch-unrecognized-value-stays-active"

# --- severity/CVSS shape upgrade (gate-a-plus.md section 1a, mandatory cases 1-4) ---

# 10. bare severity adjective only, no vector/score → FAIL (closes the
# literal audit finding: a prose word alone used to satisfy this check).
p10="$(json_write "$REC" 'Findings: CWE-90 (this is a high severity bug) reproduced.')"
run_case "deny-bare-adjective-only" 2 "$p10" "cvss-labeled-severity"

# 11. full CVSS vector string → PASS.
p11="$(json_write "$REC" 'Findings: CWE-91 (CVSS:3.1/AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H) reproduced.')"
run_case "allow-full-cvss-vector" 0 "$p11"

# 12. numeric base score consistent with its stated band word → PASS.
p12="$(json_write "$REC" 'Findings: CWE-92 (7.5, High) reproduced.')"
run_case "allow-score-consistent-with-band" 0 "$p12"

# 13. numeric score inconsistent with the stated band word → FAIL.
p13="$(json_write "$REC" 'Findings: CWE-93 (2.0, Critical) reproduced.')"
run_case "deny-score-inconsistent-with-band" 2 "$p13" "cvss-labeled-severity"

# --- block-boundary scoping (gate-a-plus.md mandatory cases 23-24) -----------

# 14. two adjacent list-item findings; only the second has a CVSS label in
# its own block → FAIL naming the first (unlabeled) CWE-ID.
p14="$(json_write "$REC" $'Findings:\n- Finding A: CWE-94 reproduced\n- Finding B: CWE-95 (CVSS High) reproduced')"
run_case "deny-list-item-block-scoped" 2 "$p14" "CWE-94"

# 15. a single long finding write-up (>300 chars) whose CVSS label appears
# after character 300 but still within the same finding's block → PASS
# (must not regress under the block-boundary check; this was a false-FAIL
# risk under the old fixed-window check).
pad="$(python3 -c 'print("word " * 70)')"
p15="$(json_write "$REC" "Findings: CWE-96 reproduced via a long write-up. $pad CVSS 7.5 High.")"
run_case "allow-long-single-finding-block" 0 "$p15"

# --- Edit/MultiEdit replace_all reconstruction --------------------------------

# 16. Edit with replace_all:true against a multiply-occurring old_string —
# both occurrences must be replaced (regression for the confirmed
# first-occurrence-only bug).
p16="$(python3 -c '
import json
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":"'"$REC"'","old_string":"TOKEN","new_string":"CWE-97","replace_all":True}}))
')"
mktd16="$(mktemp -d "${TMPDIR:-/tmp}/cf-gate-test.XXXXXX")"
mkdir -p "$mktd16/docs/issue-10/reports"
printf 'Findings: TOKEN reproduced. Second TOKEN mention with no severity.\n' > "$mktd16/docs/issue-10/reports/secure-coding.md"
out16="$(printf '%s' "$p16" | CLAUDE_PROJECT_DIR="$mktd16" "$GATE" 2>&1 1>/dev/null)"
got16=$?
rm -rf "$mktd16"
# Result: "Findings: CWE-97 reproduced. Second CWE-97 mention with no
# severity." — neither occurrence has a CVSS label -> deny.
report 2 "$got16" "edit-replace-all-true-both-occurrences"

# 17. MultiEdit mixing replace_all:true and replace_all:false in one call —
# each entry's own flag governs only that entry's substitution.
p17="$(python3 -c '
import json
edits = [
  {"old_string": "AAA", "new_string": "CWE-98 (CVSS High)", "replace_all": True},
  {"old_string": "BBB BBB", "new_string": "CWE-99 no severity here", "replace_all": False},
]
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":"'"$REC"'","edits":edits}}))
')"
mktd17="$(mktemp -d "${TMPDIR:-/tmp}/cf-gate-test.XXXXXX")"
mkdir -p "$mktd17/docs/issue-10/reports"
printf 'Findings: AAA AAA. BBB BBB.\n' > "$mktd17/docs/issue-10/reports/secure-coding.md"
out17="$(printf '%s' "$p17" | CLAUDE_PROJECT_DIR="$mktd17" "$GATE" 2>&1 1>/dev/null)"
got17=$?
rm -rf "$mktd17"
# Result: "Findings: CWE-98 (CVSS High) CWE-98 (CVSS High). CWE-99 no
# severity here." — CWE-99 has no CVSS label -> deny.
report 2 "$got17" "multiedit-mixed-replace-all"

# --- absolute vs relative path resolve to the same verdict -------------------

mktd18="$(mktemp -d "${TMPDIR:-/tmp}/cf-gate-test.XXXXXX")"
mkdir -p "$mktd18/docs/issue-10/reports"
p18="$(python3 -c '
import json, sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path": sys.argv[1] + "/docs/issue-10/reports/secure-coding.md","content":"Findings: N/A — none found."}}))
' "$mktd18")"
out18="$(printf '%s' "$p18" | CLAUDE_PROJECT_DIR="$mktd18" "$GATE" 2>&1 1>/dev/null)"
got18=$?
rm -rf "$mktd18"
report 0 "$got18" "absolute-path-same-verdict-as-relative"

# --- trap-at-top: a forced internal crash still exits 2 ----------------------

trap_at_top_out="$(env CORE_PLUGIN_ROOT="$CORE_PLUGIN_ROOT" /bin/bash -c '
  . "$CORE_PLUGIN_ROOT/hooks/lib/gate-lib.sh"
  gate_trap_fail_closed
  set -uo pipefail
  false  # simulated internal crash: non-0, non-2 exit
' 2>&1)"
trap_at_top_rc=$?
report 2 "$trap_at_top_rc" "trap-at-top-forces-fail-closed"
case "$trap_at_top_out" in
  *"fail-closed"*) : ;;
  *) fail=$((fail + 1)); printf 'FAIL trap-at-top-message missing "fail-closed" (got: %s)\n' "$trap_at_top_out" ;;
esac

# --- missing-core: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent path -----
# and no relative ../../core fallback is reachable (run from a scratch cwd) —
# the gate must fail closed (exit 2) with a source-failure message, not
# silently allow (regression for the confirmed unguarded-source bug).

missing_core() {
  td="$(mktemp -d)"
  bogus="$(mktemp -u)/no-such-core"
  p="$(python3 -c '
import json, sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path": sys.argv[1] + "/docs/issue-10/reports/secure-coding.md","content":"Findings: N/A — none found."}}))
' "$td")"
  out="$(cd "$td" && printf '%s' "$p" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$bogus" "$GATE" 2>&1 1>/dev/null)"
  rc=$?
  rm -rf "$td"
  report 2 "$rc" "missing-core-fail-closed"
  case "$out" in
    *"cannot source"*) : ;;
    *) fail=$((fail + 1)); printf 'FAIL missing-core-message missing "cannot source" (got: %s)\n' "$out" ;;
  esac
}
missing_core

echo
printf 'cwe-cvss-findings: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
