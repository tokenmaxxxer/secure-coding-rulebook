#!/usr/bin/env bash
# level-gate.sh, exercised as a real subprocess over stdin JSON payloads.
# bash 3.2 compatible: no ${var^^}, no associative arrays.
#
# want: "allow" (exit 0) | "deny" (exit 2)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../level-gate.sh"
ROOT="$(cd "$HERE/../../.." && pwd -P)"

pass=0
fail=0

report() {
  # report <want> <got> <name>
  if [ "$2" = "$1" ]; then
    pass=$((pass + 1)); printf 'ok    %-40s want=%s got=%s\n' "$3" "$1" "$2"
  else
    fail=$((fail + 1)); printf 'FAIL  %-40s want=%s got=%s\n' "$3" "$1" "$2"
  fi
}

mktd() { td="$(mktemp -d "${TMPDIR:-/tmp}/asvs-gate-test.XXXXXX")"; }

# json_str <raw>: JSON-encode a string via python3 (avoids shell-escaping bugs).
json_str() { python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$1"; }

# run_write <want> <name> <file_path> <content>
run_write() {
  want="$1"; name="$2"; fp="$3"; content="$4"
  fp_json="$(json_str "$fp")"
  content_json="$(json_str "$content")"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":%s,"content":%s}}' "$fp_json" "$content_json")"
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report "$want" "$got" "$name"
}

# run_write_env <want> <name> <file_path> <content> <extra-env-var=val ...>
run_write_env() {
  want="$1"; name="$2"; fp="$3"; content="$4"; shift 4
  fp_json="$(json_str "$fp")"
  content_json="$(json_str "$content")"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":%s,"content":%s}}' "$fp_json" "$content_json")"
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$ROOT" "$@" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report "$want" "$got" "$name"
}

assert_stderr_has() {
  # assert_stderr_has <name> <needle>
  if grep -q "$2" "$TMPDIR_ERR" 2>/dev/null; then
    pass=$((pass + 1)); printf 'ok    %-40s stderr mentions %s\n' "$1" "$2"
  else
    fail=$((fail + 1)); printf 'FAIL  %-40s stderr missing %s (got: %s)\n' "$1" "$2" "$(cat "$TMPDIR_ERR" 2>/dev/null)"
  fi
}

TMPDIR_ERR="$(mktemp "${TMPDIR:-/tmp}/asvs-gate-test-stderr.XXXXXX")"
trap 'rm -f "$TMPDIR_ERR"' EXIT

PHASE1_PATH="docs/issue-10/proposals/enforcement-machine-secure-coding.md"
PHASE2_PATH="docs/issue-10/reports/secure-coding.md"

# --- phase-1 ---------------------------------------------------------------

run_write allow phase1-allow-all-present "$PHASE1_PATH" \
  "Level L2 chosen per current-state-survey. Requirement V2.1.1 applies."
[ "$?" = 0 ] || true

run_write deny phase1-deny-order-violation "$PHASE1_PATH" \
  "Requirement V2.1.1 applies, and separately level L2 is chosen. See current-state-survey."
assert_stderr_has phase1-deny-order-violation "level-before-requirements"

run_write deny phase1-deny-missing-level "$PHASE1_PATH" \
  "Requirement V2.1.1 applies. See current-state-survey for basis."
assert_stderr_has phase1-deny-missing-level "level-named"

run_write deny phase1-deny-missing-id "$PHASE1_PATH" \
  "Level L2 is chosen for this work. See current-state-survey for basis."
assert_stderr_has phase1-deny-missing-id "external-id-present"

run_write deny phase1-deny-missing-survey "$PHASE1_PATH" \
  "Level L2 chosen. Requirement V2.1.1 applies."
assert_stderr_has phase1-deny-missing-survey "survey-reference"

# --- phase-2 -----------------------------------------------------------------

run_write allow phase2-allow-all-present "$PHASE2_PATH" \
  "Level L2 carried over. Checklist: V2.1.1 pass. Scope covered: all L2 rows checked."

run_write deny phase2-deny-missing-level "$PHASE2_PATH" \
  "Checklist: V2.1.1 pass. Scope covered: all rows checked."
assert_stderr_has phase2-deny-missing-level "level-carried-over"

run_write deny phase2-deny-no-passfail-near "$PHASE2_PATH" \
  "Level L2 carried over. Checklist: V2.1.1 is a requirement we looked at. $(python3 -c 'print("x"*250)') pass appears far away. Scope covered: yes."
assert_stderr_has phase2-deny-no-passfail-near "asvs-checklist"

run_write deny phase2-deny-missing-scope "$PHASE2_PATH" \
  "Level L2 carried over. Checklist: V2.1.1 pass."
assert_stderr_has phase2-deny-missing-scope "scope-covered-summary"

# --- non-matching path -------------------------------------------------------

run_write allow non-matching-path-not-evaluated \
  "docs/issue-10/proposals/unrelated.md" \
  "this is garbage content with no level no id no survey ref at all !!!"

# --- malformed JSON -----------------------------------------------------------

malformed() {
  out="$(printf '{not valid json' | env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" "malformed-json-fail-closed"
}
malformed

# --- Edit whose old_string does not match on-disk content --------------------

edit_no_match() {
  mktd
  mkdir -p "$td/docs/issue-10/reports"
  printf 'Level L2 carried over. Checklist: V2.1.1 pass. Scope covered: yes.\n' > "$td/docs/issue-10/reports/secure-coding.md"
  payload='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-10/reports/secure-coding.md","old_string":"this string does not exist in the file","new_string":"replacement"}}'
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" "edit-old-string-not-found"
}
edit_no_match

# --- kill switch --------------------------------------------------------------

run_write_env allow kill-switch-phase1-missing-everything \
  "$PHASE1_PATH" "no level, no id, no survey ref here at all" \
  ASVS_VERIFICATION_OFF=1

run_write_env allow kill-switch-phase2-missing-everything \
  "$PHASE2_PATH" "no level, no checklist, no scope summary here at all" \
  ASVS_VERIFICATION_OFF=1

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
