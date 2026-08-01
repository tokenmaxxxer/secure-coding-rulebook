# cwe-cvss-findings

CWE Top 25 + CVSS methodology plugin for the secure-coding role. Decides:
every weakness finding the secure-coding role records must be CWE-ID-tagged
and CVSS/severity-band-scored, with reproduction and remediation status —
or, if no weakness was found, an explicit "N/A — none found" instead of a
silent empty section.

This is a phase-2-only norm. Findings are a record artifact, not a proposal
artifact (issue-1 (a)-2): a phase-1 proposal enumerates requirements, not
findings, so this plugin never gates `docs/issue-<n>/proposals/*`. See
`docs/issue-10/proposals/enforcement-machine.md` for the full plugin-set
design this plugin is one piece of.

## What it decides

- **`finding-list-or-na`** — the phase-2 record must contain at least one
  `CWE-<digits>` token, or an explicit N/A marker ("N/A ... none found",
  "no findings", "none found").
- **`cvss-labeled-severity`** — whenever at least one CWE-ID is present,
  every single CWE-ID occurrence must carry either a real CVSS vector
  string (`CVSS:3.0/…` or `CVSS:3.1/…`, at minimum `AV`, `AC`, and one of
  `C`/`I`/`A` present) or a numeric CVSS base score consistent with a
  stated CVSS v3.1 severity band (`None`/`Low`/`Medium`/`High`/`Critical`,
  score and band must agree with the official band table) — within its
  own finding block (from the CWE-ID's own line start to the next blank
  line, list-item marker, or table row). A bare severity adjective with no
  vector or score no longer satisfies this. This is block-scoped: a
  document with two findings where only one carries a valid label still
  fails, even though the document as a whole contains a CVSS-shaped token
  somewhere; a single long finding whose label happens to sit far into its
  own write-up is unaffected, since the boundary is structural, not a
  fixed character count.
- The N/A branch, when it is what satisfies `finding-list-or-na`, needs no
  per-finding severity label — an empty finding list has no findings to
  score.

## How it works

- A `PreToolUse` gate, `hooks/finding-gate.sh`, fires on `Write`/`Edit`/
  `MultiEdit` calls. It sources core canon's `gate-lib.sh`/`gate-lib.py`
  (`${CLAUDE_PLUGIN_ROOT_CORE:-$CLAUDE_PLUGIN_ROOT/../core}/hooks/lib/gate-lib.sh`,
  core issue #72) for the fail-closed EXIT trap, the kill switch
  (`gate_kill_switch_active`), malformed-JSON deny
  (`gate_parse_json_or_deny`), path normalization (`gate_normalize_path`),
  and full `Write`/`Edit`/`MultiEdit` reconstruction honoring
  `replace_all` per-edit (`gate_reconstruct_write`) — none of that
  machinery is re-derived locally.
- It fires ONLY on writes whose resolved target matches
  `docs/issue-<n>/reports/secure-coding.md` (the phase-2 record). This
  methodology never gates phase-1 proposals — there is no phase-1 branch
  in this gate at all. Any other path passes through untouched, without
  the gate reading its content.
- Root resolution is independent of the tool call's own `file_path`:
  `CLAUDE_PROJECT_DIR` if it is a plausible project root, else
  `git rev-parse --show-toplevel` — never derived by `dirname`-ing the
  write target, closing the asymmetry a prior version of this gate had
  against `asvs-verification/hooks/level-gate.sh`.
- For a matching write, the gate reconstructs the full resulting document
  text via `gate_lib.gate_reconstruct_write` and checks it against the two
  rules above.
- Fails closed: a malformed or non-object JSON payload, an unresolvable
  project root, an `Edit`/`MultiEdit` whose `old_string` cannot be located
  in the current file, or any unexpected internal error all deny (exit 2)
  rather than allow.
- `hooks/directive.sh` (not evaluated by this README's gate description
  but shipped alongside it) contributes the finding-capture directive
  fragment consumed by `secure-coding`'s own directive per
  `docs/issue-10/proposals/enforcement-machine.md` (v).

## Install

    claude plugin marketplace add tokenmaxxxer/secure-coding-rulebook
    claude plugin install cwe-cvss-findings@tokenmaxxxer-secure-coding

(marketplace name per this repo's `.claude-plugin/marketplace.json`.)

## Disable

    export CWE_CVSS_FINDINGS_OFF=1

## Caveats — scope of evidence

This is a shape check only: string/regex presence of a `CWE-<digits>`
token and a nearby CVSS/severity-band token. It does not verify that the
CWE ID actually classifies the described weakness correctly, that the
CVSS score or band is numerically or semantically accurate, or that the
reproduction/remediation status claimed is true. It catches an omitted
finding shape, not a wrong one.
