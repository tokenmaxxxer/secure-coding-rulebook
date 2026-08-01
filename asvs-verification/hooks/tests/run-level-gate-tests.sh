#!/usr/bin/env bash
# level-gate.sh, exercised as a real subprocess over stdin JSON payloads.
# bash 3.2 compatible: no ${var^^}, no associative arrays.
#
# want: "allow" (exit 0) | "deny" (exit 2)
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
GATE="$HERE/../level-gate.sh"
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
  echo "run-level-gate-tests: cannot find core canon gate-lib.sh; set CORE_PLUGIN_ROOT (or CLAUDE_PLUGIN_ROOT_CORE) to a checkout of tokenmaxxxer-core (core issue #72) before running this suite." >&2
  exit 1
}
export CORE_PLUGIN_ROOT
: "${CLAUDE_PLUGIN_ROOT_CORE:=$CORE_PLUGIN_ROOT}"
export CLAUDE_PLUGIN_ROOT_CORE

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
  "Level L2 carried over. Checklist: V2.1.1 is a requirement we looked at.

$(python3 -c 'print("x"*250)') pass appears far away, in an unrelated paragraph. Scope covered: yes."
assert_stderr_has phase2-deny-no-passfail-near "asvs-checklist"

# Structural upgrade regression guard (gate-a-plus.md section 2.3, mandatory
# case 21/22): every requirement ID needs its OWN pass/fail token, not just
# the first one in the document.
run_write deny phase2-deny-only-first-row-labeled "$PHASE2_PATH" \
  "Level L2 carried over.
- V1.1.1 pass
- V2.1.1 is unresolved
- V3.1.1 still pending
Scope covered: partial."
assert_stderr_has phase2-deny-only-first-row-labeled "asvs-checklist"

run_write allow phase2-allow-every-row-labeled "$PHASE2_PATH" \
  "Level L2 carried over.
- V1.1.1 pass
- V2.1.1 fail
- V3.1.1 pass
Scope covered: all rows checked."

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

# malformed JSON, variant 2: syntactically valid JSON that is not an object
# (a bare array) — must also deny (gate-a-plus.md mandatory case 10).
malformed_non_object() {
  out="$(printf '["not", "an", "object"]' | env CLAUDE_PROJECT_DIR="$ROOT" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" "malformed-json-non-object-fail-closed"
}
malformed_non_object

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

# --- Edit/MultiEdit replace_all reconstruction (gate_reconstruct_write) ------

edit_replace_all_true_deny() {
  # old_string occurs twice; replace_all:true must replace BOTH occurrences.
  # If a later occurrence's replacement clobbers the requirement ID needed
  # for the checklist, the gate must deny (regression for the confirmed
  # first-occurrence-only bug).
  mktd
  mkdir -p "$td/docs/issue-10/reports"
  printf 'Level L2 carried over. Checklist: TOKEN pass. Extra TOKEN mention. Scope covered: yes.\n' \
    > "$td/docs/issue-10/reports/secure-coding.md"
  payload='{"tool_name":"Edit","tool_input":{"file_path":"docs/issue-10/reports/secure-coding.md","old_string":"TOKEN","new_string":"V9.9.9","replace_all":true}}'
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  # Resulting doc: "Checklist: V9.9.9 pass. Extra V9.9.9 mention." — the
  # second V9.9.9 occurrence has no pass/fail token in its own row -> deny.
  report deny "$got" "edit-replace-all-true-both-occurrences"
}
edit_replace_all_true_deny

multiedit_mixed_replace_all() {
  # MultiEdit with one replace_all:true entry and one replace_all:false (the
  # default) entry in the same call — each entry's own flag must govern
  # only that entry's substitution (gate-a-plus.md mandatory case 16).
  mktd
  mkdir -p "$td/docs/issue-10/reports"
  printf 'Level L2 carried over. AAA AAA. BBB BBB. Scope covered: yes.\n' \
    > "$td/docs/issue-10/reports/secure-coding.md"
  payload='{"tool_name":"MultiEdit","tool_input":{"file_path":"docs/issue-10/reports/secure-coding.md","edits":[{"old_string":"AAA","new_string":"V1.1.1 pass","replace_all":true},{"old_string":"BBB BBB","new_string":"V2.2.2 fail","replace_all":false}]}}'
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  # Resulting doc: "V1.1.1 pass V1.1.1 pass. V2.2.2 fail. Scope covered:
  # yes." — every requirement ID has its own pass/fail token -> allow.
  report allow "$got" "multiedit-mixed-replace-all"
}
multiedit_mixed_replace_all

# --- absolute vs relative path resolve to the same verdict -------------------

absolute_path_variant() {
  mktd
  mkdir -p "$td/docs/issue-10/proposals"
  payload="$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/docs/issue-10/proposals/enforcement-machine-secure-coding.md","content":"Level L2 chosen per current-state-survey. Requirement V2.1.1 applies."}}' "$td")"
  out="$(printf '%s' "$payload" | env CLAUDE_PROJECT_DIR="$td" /bin/bash "$GATE" 2>"$TMPDIR_ERR")"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report allow "$got" "absolute-path-same-verdict-as-relative"
}
absolute_path_variant

# --- kill switch --------------------------------------------------------------

run_write_env allow kill-switch-phase1-missing-everything \
  "$PHASE1_PATH" "no level, no id, no survey ref here at all" \
  ASVS_VERIFICATION_OFF=1

run_write_env allow kill-switch-phase2-missing-everything \
  "$PHASE2_PATH" "no level, no checklist, no scope summary here at all" \
  ASVS_VERIFICATION_OFF=1

# unrecognized kill-switch value must NOT disable the gate (gate-a-plus.md
# mandatory case 13 — the confirmed fail-open bug).
run_write_env deny kill-switch-unrecognized-value-stays-active \
  "$PHASE2_PATH" "no level, no checklist, no scope summary here at all" \
  ASVS_VERIFICATION_OFF=maybe

# --- trap-at-top: a forced internal crash still exits 2 ----------------------

trap_at_top() {
  out="$(env CORE_PLUGIN_ROOT="$CORE_PLUGIN_ROOT" /bin/bash -c '
    . "$CORE_PLUGIN_ROOT/hooks/lib/gate-lib.sh"
    gate_trap_fail_closed
    set -uo pipefail
    false  # simulated internal crash: non-0, non-2 exit
  ' 2>&1)"
  rc=$?
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" "trap-at-top-forces-fail-closed"
  case "$out" in
    *"fail-closed"*) : ;;
    *) fail=$((fail + 1)); printf 'FAIL   trap-at-top-message missing "fail-closed" (got: %s)\n' "$out" ;;
  esac
}
trap_at_top

# --- missing-core: CLAUDE_PLUGIN_ROOT_CORE points at a nonexistent path -----
# and no relative ../../core fallback is reachable (run from a scratch cwd) —
# the gate must fail closed (exit 2) with a source-failure message, not
# silently allow (regression for the confirmed unguarded-source bug).

missing_core() {
  mktd
  bogus="$(mktemp -u)/no-such-core"
  out="$(cd "$td" && printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"garbage"}}' "$PHASE1_PATH" | env CLAUDE_PROJECT_DIR="$td" CLAUDE_PLUGIN_ROOT_CORE="$bogus" /bin/bash "$GATE" 2>&1 1>/dev/null)"
  rc=$?
  rm -rf "$td"
  case "$rc" in 0) got=allow ;; 2) got=deny ;; *) got="exit-$rc" ;; esac
  report deny "$got" "missing-core-fail-closed"
  case "$out" in
    *"cannot source"*) : ;;
    *) fail=$((fail + 1)); printf 'FAIL   missing-core-message missing "cannot source" (got: %s)\n' "$out" ;;
  esac
}
missing_core

printf '\n== %d passed, %d failed ==\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
