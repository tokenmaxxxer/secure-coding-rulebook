#!/usr/bin/env bash
# Exercises hooks/finding-gate.sh as a real subprocess via stdin JSON
# payloads. bash 3.2 compatible: no ${var^^}, no associative arrays.
#
# want: "allow" (exit 0) | "deny" (exit 2)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../finding-gate.sh"
ROOT="$(cd "$HERE/../../.." && pwd -P)"

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

echo
printf 'cwe-cvss-findings: %d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
