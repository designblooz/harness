---
name: pr-autopilot
description: "Use when the user wants a GitHub PR driven all the way to merged with minimal supervision — 'merge this PR', 'get this PR merged', 'land this PR', 'autopilot', 'keep fixing until it merges'. Loops: merges the moment the PR is mergeable, otherwise runs indigo-fix-pr to clear failing CI and review comments, then re-checks. Stops when merged or when only a human can unblock it."
---

# PR Autopilot

## Overview

Drive one GitHub PR to a merged state. Each iteration: snapshot the PR; if it's mergeable, merge it; otherwise invoke the `indigo-fix-pr` skill for one fix pass (failing CI + review comments), then loop. Stop when merged, or when the only thing left needs a human (approval, merge conflict, flaky/unrelated CI, or a review comment `indigo-fix-pr` surfaced instead of acting on).

**Announce at start:** "Using pr-autopilot to drive the PR to merge, fixing CI and review comments as needed."

## Prerequisites

- `gh` CLI authenticated.
- The `indigo-fix-pr` skill is installed (from `indigo-dev-tools`).
- On the PR head branch with a clean working tree — `indigo-fix-pr` aborts on unrelated uncommitted changes; if it aborts, so does this skill.

## Inputs

- No argument → infer PR from the current branch.
- PR number or PR URL.
- Optional merge method: `--squash` (default), `--merge`, or `--rebase`.

If no PR resolves and none was given, stop and report — do not ask.

## Operating Principle

**Never prompt the user mid-loop.** Merging when the PR is mergeable is the explicit goal of invoking this skill — do it without asking. Decisions too risky to automate (resolving a conflict, marking a draft ready, approving) are surfaced in the final report, not asked about. `indigo-fix-pr` follows the same principle; trust its final report as the pass result.

## State Routing

Read `mergeStateStatus` from `gh pr view --json state,mergeable,mergeStateStatus,reviewDecision,headRefOid` and route:

| `mergeStateStatus` | Meaning | Action |
|---|---|---|
| `CLEAN` | Ready to merge (branch protection satisfied) | **Merge, then stop.** |
| `BEHIND` | Head behind base | `gh pr update-branch <pr>`, then loop. |
| `DIRTY` | Merge conflict | **Stop — surface.** Cannot resolve without a force-push (disallowed). |
| `DRAFT` | Draft PR | **Stop — surface.** Marking ready is the user's call. |
| `BLOCKED` / `UNSTABLE` / `UNKNOWN` | Failing/required checks, unresolved reviews, or still computing | Run one `indigo-fix-pr` pass, then loop. |

Merging only on `CLEAN` means branch protection (including required approvals and checks) is already satisfied — never merge over red required checks.

## Workflow

1. Resolve the PR (`gh pr view <pr-or-empty> --json number,url,state,mergeable,mergeStateStatus,reviewDecision,headRefOid`). If `state` is `MERGED`/`CLOSED`, stop and report.
2. Route on `mergeStateStatus` (table above).
   - `CLEAN` → determine an allowed merge method and merge:
     ```bash
     gh repo view --json mergeCommitAllowed,squashMergeAllowed,rebaseMergeAllowed
     gh pr merge <pr> --squash   # or the user's method / first allowed method
     ```
     Report the merge and stop.
   - `BEHIND` → `gh pr update-branch <pr>`, then go to step 1.
   - `DIRTY` / `DRAFT` → stop and surface.
   - Otherwise → capture the head SHA, then **invoke the `indigo-fix-pr` skill** (one pass: it waits for in-flight CI, fixes branch-related failures and A-bucket comments, pushes, and reports outstanding items).
3. **Loop guard.** After the `indigo-fix-pr` pass, re-snapshot. Compare the new `headRefOid` to the captured SHA:
   - SHA advanced → progress was made; go to step 1.
   - SHA unchanged **and** not `CLEAN` → the pass couldn't fix anything actionable (waiting on approval, flaky/unrelated CI, or a surfaced review comment). **Stop and surface** — looping again would repeat the same no-op.
4. Cap total passes at **5**. On the cap, stop and report the PR still isn't merged.

## Report

- PR URL and final state (merged / still open, with `mergeStateStatus`).
- Passes run, and the merge method used if merged.
- Why it stopped short of merge, carrying forward `indigo-fix-pr`'s outstanding items: reviewer approval pending, merge conflict, draft, flaky/unrelated CI (with run URL), or surfaced review comments needing a human.

## Important Rules

1. **Merge on `CLEAN` only.** That signal already encodes branch-protection satisfaction; do not merge over failing required checks or missing approvals.
2. **One fix pass per iteration via `indigo-fix-pr`.** Don't reimplement CI/review fixing here — delegate to that skill and act on its result.
3. **Loop guard is mandatory.** A pass that doesn't advance the head SHA while the PR is still not `CLEAN` means stop — never loop indefinitely.
4. **Never prompt mid-loop.** Surface human-only blockers in the final report.
5. **No destructive git.** No force-push, no conflict resolution via rewrite — surface `DIRTY` for the user.
