# Global Distinguished Engineer Orchestration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Install a portable Distinguished Software Engineer instruction set, four model-routed custom agents, and existing skills globally for Codex and Claude Code from this repository.

**Architecture:** Keep canonical instruction and agent files under `.codex/` and `.claude/`, then use one safe idempotent Bash installer to link them into the active user configuration directories. The main agent owns decisions and integration; narrow researcher, planner, implementer, and reviewer definitions encode per-role models, effort, permissions, and output contracts.

**Tech Stack:** Markdown, TOML, YAML frontmatter, POSIX-oriented Bash, Codex CLI, Claude Code CLI.

---

### Task 1: Add an installer regression harness

**Files:**
- Create: `tests/install_test.sh`
- Read: `docs/plans/2026-07-16-global-agent-orchestration-design.md`

**Step 1: Write the failing test harness**

Create an executable Bash test that runs each case in a temporary directory and cleans it with a trap. It must use explicit `HOME`, `CODEX_HOME`, and `CLAUDE_CONFIG_DIR` values so it never mutates the developer's real configuration.

The harness should provide these helpers:

```bash
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_link() {
  local destination=$1 expected=$2
  [ -L "$destination" ] || fail "$destination is not a symlink"
  [ "$(readlink "$destination")" = "$expected" ] ||
    fail "$destination does not point to $expected"
}

assert_no_path() {
  [ ! -e "$1" ] && [ ! -L "$1" ] || fail "$1 unexpectedly exists"
}
```

Test these behaviors in isolated cases:

1. `--dry-run` creates no user configuration directories.
2. A clean install links both instruction files and all eight agent definitions.
3. A second install is idempotent and produces no `*.backup-*` paths.
4. Pre-existing regular instruction files are preserved in timestamped backups and replaced by correct links.
5. Custom `CODEX_HOME` and `CLAUDE_CONFIG_DIR` destinations are honored.

Run the repository installer through:

```bash
HOME="$case_root/home" \
CODEX_HOME="$case_root/codex" \
CLAUDE_CONFIG_DIR="$case_root/claude" \
bash "$repo/install.sh" "$@"
```

**Step 2: Run the test to verify it fails**

Run:

```bash
bash tests/install_test.sh
```

Expected: FAIL because the instruction files, agent definitions, and safe installer behavior do not exist yet.

**Step 3: Checkpoint without committing**

Run:

```bash
git status --short tests/install_test.sh
```

Expected: `?? tests/install_test.sh`. Do not commit; the user did not request commits.

### Task 2: Create the shared Distinguished Engineer instructions

**Files:**
- Create: `.codex/AGENTS.md`
- Create: `.claude/CLAUDE.md`
- Reference: `docs/plans/2026-07-16-global-agent-orchestration-design.md`

**Step 1: Create `.codex/AGENTS.md`**

Keep the file below 200 lines and organize it with these exact sections:

```markdown
# Distinguished Software Engineer

## Mandate
## Decision Priorities
## Operating Method
## Orchestration
## Engineering Standards
## Verification
## Communication
## Worker Mode
```

Encode the approved observable behaviors:

- Main/root owns requirements, architecture, mutation sequencing, integration, verification, and user communication.
- Do not delegate trivial work or work whose phases share substantial context.
- Parallelize at most three independent read-only lanes.
- Use only one writer at a time and never assign overlapping files.
- Route evidence gathering to `researcher`, bounded plans to `planner`, assigned edits to `implementer`, and independent final checks to `reviewer`.
- Every delegation includes objective, scope, context, constraints, evidence, output format, and done condition.
- Workers do not recursively delegate and their reports are evidence, not decisions.
- Preserve compatibility, validate untrusted input, avoid scope creep, write deterministic tests, and verify before claiming completion.

**Step 2: Create `.claude/CLAUDE.md`**

Start with the shared import:

```markdown
@../.codex/AGENTS.md
```

Add a short `## Claude Code Integration` section that names the four custom agents, tells the main conversation to use standard subagents rather than agent teams, and reminds it that read-only roles must not receive edit authority. Do not duplicate the shared persona.

**Step 3: Validate instruction size and import**

Run:

```bash
wc -l .codex/AGENTS.md .claude/CLAUDE.md
sed -n '1,5p' .claude/CLAUDE.md
```

Expected: each file is below 200 lines and the Claude file begins with `@../.codex/AGENTS.md`.

**Step 4: Re-run the installer test**

Run:

```bash
bash tests/install_test.sh
```

Expected: still FAIL because custom agents and installer behavior are incomplete.

### Task 3: Add Codex custom agents

**Files:**
- Create: `.codex/agents/researcher.toml`
- Create: `.codex/agents/planner.toml`
- Create: `.codex/agents/implementer.toml`
- Create: `.codex/agents/reviewer.toml`

**Step 1: Create the read-only researcher**

Use this schema and approved routing:

```toml
name = "researcher"
description = "Read-only evidence gathering across repositories and primary external sources. Use for bounded research that can return a concise report."
model = "gpt-5.6-luna"
model_reasoning_effort = "xhigh"
sandbox_mode = "read-only"
developer_instructions = """
Gather only the evidence needed for the assigned question.
Prefer repository evidence and current primary sources.
Separate verified facts, inference, and unresolved uncertainty.
Return concise findings with file and line references or direct source URLs.
Do not edit files, broaden the task, make final decisions, or spawn subagents.
"""
```

**Step 2: Create the read-only planner**

Use `model = "gpt-5.6-sol"`, `model_reasoning_effort = "low"`, and `sandbox_mode = "read-only"`. Require exact files, ordered steps, tests, compatibility risks, rollback considerations, and explicit uncertainties. Forbid edits, final architecture decisions, and delegation.

**Step 3: Create the bounded implementer**

Use `model = "gpt-5.6-sol"`, `model_reasoning_effort = "medium"`, and `sandbox_mode = "workspace-write"`. Limit edits to assigned files and behavior, preserve unrelated changes, require focused tests, and require the worker to stop when broader authority or conflicting ownership is needed.

**Step 4: Create the read-only reviewer**

Use `model = "gpt-5.6-sol"`, `model_reasoning_effort = "high"`, and `sandbox_mode = "read-only"`. Require review of the actual diff and tests, severity-ordered actionable findings with file/line evidence, and an explicit no-findings result when appropriate. Forbid edits and style-only noise.

**Step 5: Parse every TOML file**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import tomllib

for path in sorted(Path('.codex/agents').glob('*.toml')):
    with path.open('rb') as handle:
        data = tomllib.load(handle)
    required = {'name', 'description', 'developer_instructions'}
    missing = required - data.keys()
    assert not missing, f'{path}: missing {sorted(missing)}'
    print(f'valid {path}')
PY
```

Expected: four `valid` lines and no exception.

### Task 4: Add Claude Code custom agents

**Files:**
- Create: `.claude/agents/researcher.md`
- Create: `.claude/agents/planner.md`
- Create: `.claude/agents/implementer.md`
- Create: `.claude/agents/reviewer.md`

**Step 1: Create the researcher**

Use this frontmatter and the same narrow contract as the Codex researcher:

```markdown
---
name: researcher
description: Use proactively for bounded read-only repository or primary-source research that can return a concise evidence report.
tools: Read, Grep, Glob, Bash, WebSearch, WebFetch
model: sonnet
effort: xhigh
permissionMode: plan
maxTurns: 20
---
```

The body must prohibit edits, mutating shell commands, final decisions, and subagent spawning.

**Step 2: Create the planner**

Use `model: opus`, `effort: low`, `permissionMode: plan`, `maxTurns: 15`, and the read-oriented tool list. Require a minimal implementation plan with exact files, validation, risks, and rollback notes. Prohibit edits and delegation.

**Step 3: Create the implementer**

Use `model: opus`, `effort: medium`, `permissionMode: default`, `maxTurns: 40`, and:

```yaml
tools: Read, Grep, Glob, Edit, Write, Bash
```

Require bounded edits, preservation of unrelated work, focused tests, and escalation on conflicts or scope expansion. Do not include the `Agent` tool.

**Step 4: Create the reviewer**

Use `model: opus`, `effort: high`, `permissionMode: plan`, `maxTurns: 20`, and read-oriented tools. Require actual-diff review, severity ordering, file/line evidence, and no style-only findings. Do not include `Edit`, `Write`, or `Agent`.

**Step 5: Inspect every frontmatter block**

Run:

```bash
for file in .claude/agents/*.md; do
  awk 'NR == 1 { if ($0 != "---") exit 1 } /^---$/ { count++ } END { if (count < 2) exit 1 }' "$file" || exit 1
  rg -q '^name: ' "$file" || exit 1
  rg -q '^description: ' "$file" || exit 1
  rg -q '^model: ' "$file" || exit 1
  rg -q '^effort: ' "$file" || exit 1
  printf 'valid %s\n' "$file"
done
```

Expected: four `valid` lines.

### Task 5: Replace the installer with safe global linking

**Files:**
- Modify: `install.sh`
- Test: `tests/install_test.sh`

**Step 1: Add argument parsing and destinations**

Accept only zero arguments or `--dry-run`; unknown arguments must print usage and exit non-zero.

Derive paths without assuming the clone location:

```bash
repo="$(cd "$(dirname "$0")" && pwd)"
codex_home="${CODEX_HOME:-${HOME:?HOME is required}/.codex}"
claude_home="${CLAUDE_CONFIG_DIR:-${HOME:?HOME is required}/.claude}"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
```

**Step 2: Implement safe idempotent linking**

Add a `link_path SOURCE DESTINATION` function with this behavior:

1. Fail if the source is absent.
2. Return successfully when the destination is already a symlink to the exact source.
3. Create the destination parent directory.
4. Move any conflicting path to a unique `${destination}.backup-${timestamp}` path, adding a numeric suffix on collision.
5. Create the new link.
6. If link creation fails, restore the backup before returning non-zero.
7. In dry-run mode, print the same operations without mutating anything.

Use `[ -e "$path" ] || [ -L "$path" ]` so broken symlinks count as conflicts.

**Step 3: Link instructions and agents**

Link the exact instruction files first, then every agent file:

```bash
link_path "$repo/.codex/AGENTS.md" "$codex_home/AGENTS.md"
link_path "$repo/.claude/CLAUDE.md" "$claude_home/CLAUDE.md"

for agent in "$repo"/.codex/agents/*.toml; do
  link_path "$agent" "$codex_home/agents/$(basename "$agent")"
done

for agent in "$repo"/.claude/agents/*.md; do
  link_path "$agent" "$claude_home/agents/$(basename "$agent")"
done
```

**Step 4: Preserve per-skill installation**

For each directory under `skills/` containing `SKILL.md`, call `link_path` for both global skill destinations. Do not replace either entire skills directory.

**Step 5: Run focused installer checks**

Run:

```bash
bash -n install.sh tests/install_test.sh
bash tests/install_test.sh
```

Expected: syntax checks succeed and all installer tests report PASS.

**Step 6: Run shell lint when available**

Run:

```bash
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck install.sh tests/install_test.sh
else
  printf 'shellcheck not installed; skipped\n'
fi
```

Expected: no shellcheck findings, or a clear skipped message.

### Task 6: Update repository documentation

**Files:**
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

**Step 1: Document the expanded layout**

Update both root project-instruction files so they describe:

- `.codex/AGENTS.md` and `.claude/CLAUDE.md` as canonical global instruction sources;
- `.codex/agents/` and `.claude/agents/` as canonical custom-agent definitions;
- the four shared role names;
- `install.sh` installing instructions, agents, and skills;
- `./install.sh --dry-run` for inspection;
- the fact that machine-specific tool settings are intentionally not managed.

Keep the existing skill and MCP instructions intact unless wording must change for accuracy.

**Step 2: Avoid duplicated root documentation**

Because root `AGENTS.md` and root `CLAUDE.md` currently contain the same project description, apply the same narrow factual update to both. Do not import the global persona into the root project docs; global discovery already supplies it after installation.

**Step 3: Review documentation consistency**

Run:

```bash
rg -n 'AGENTS.md|CLAUDE.md|agents/|dry-run|config.toml|settings.json' AGENTS.md CLAUDE.md
```

Expected: both files describe the same repository behavior and do not claim that machine-specific settings are installed.

### Task 7: Verify and install globally

**Files:**
- Verify: `.codex/AGENTS.md`
- Verify: `.codex/agents/*.toml`
- Verify: `.claude/CLAUDE.md`
- Verify: `.claude/agents/*.md`
- Verify: `install.sh`
- Verify: `tests/install_test.sh`
- Verify: `AGENTS.md`
- Verify: `CLAUDE.md`

**Step 1: Run the complete local verification suite**

Run:

```bash
bash -n install.sh tests/install_test.sh
bash tests/install_test.sh
```

Expected: all checks pass.

Repeat the TOML and Claude frontmatter validation commands from Tasks 3 and 4. Expected: all eight agent files validate.

**Step 2: Inspect the real installation dry run**

Run:

```bash
./install.sh --dry-run
```

Expected: it reports backups for the current regular global instruction files and new links for all agent definitions without changing the home directories.

**Step 3: Install into the current user directories**

Run:

```bash
./install.sh
```

Expected: existing global instruction files are preserved as timestamped backups; global instructions, agents, and repository skills resolve to this clone.

**Step 4: Verify installed links**

Run:

```bash
readlink "${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
readlink "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md"
find "${CODEX_HOME:-$HOME/.codex}/agents" -maxdepth 1 -type l -print | sort
find "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents" -maxdepth 1 -type l -print | sort
```

Expected: instruction links point into this repository and each agent directory contains four managed links.

**Step 5: Run client diagnostics**

Run non-mutating diagnostics supported by the installed clients:

```bash
codex doctor
claude doctor
```

If a diagnostic is interactive or reports unrelated pre-existing configuration, record that limitation instead of changing machine-specific settings.

**Step 6: Perform the final quality gate**

Run:

```bash
git diff --check
git status --short
```

Inspect every new and modified file. Confirm:

- no debug output or accidental files;
- no secrets, absolute home paths, or machine-specific configuration were added;
- agent names and models match the approved matrix exactly;
- read-only roles lack edit tools or writable Codex sandboxes;
- only the implementer is write-capable;
- installer backups are outside the repository;
- documentation matches actual behavior.

Do not commit unless the user explicitly asks.
