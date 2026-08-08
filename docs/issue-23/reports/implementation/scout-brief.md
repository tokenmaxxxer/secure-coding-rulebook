# Scout brief — issue-23

Skip record (mandatory per scout-directive): scouting skipped this pass.
Reason (skip condition: spec leaves no design decision open): the
marketplace spec (`roles/specs/secure-coding.spec.json`, issue #521) is a
closed, already-landed artifact — its required-field names, enums, and
loop_state vocabulary are fixed by that spec, not by this session's
judgment. The task is to make this rulebook's existing docs/hooks contain
that fixed vocabulary and cross-reference the fixed marketplace gate
(`role-spec-reference-guard.sh`), per the issue's explicit instruction to
mirror execution-observation-rulebook #63's already-completed pattern
(no re-derivation of that pattern's design is open either — it is named
as the template to follow). There is no exemplar field, no product-shaped
choice, and no external "best-in-class" comparison applicable here: this
is doc-alignment against a fixed upstream artifact within one rulebook
repo, not a market-facing deliverable.
