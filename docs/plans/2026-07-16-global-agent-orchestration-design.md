# Global Distinguished Engineer Orchestration Design

**Date:** 2026-07-16  
**Status:** Approved

## Context

This repository is the canonical, portable source for personal Codex and Claude Code instructions, custom agents, skills, and MCP servers. A new machine should require only a clone and `./install.sh` to expose the repository-managed assets globally.

The current installer links skills only. The requested `.codex/AGENTS.md` and `.claude/CLAUDE.md` files would not, by themselves, both be global: Codex reads global guidance from `$CODEX_HOME/AGENTS.md`, while Claude Code reads global guidance from `~/.claude/CLAUDE.md`. Per-role model selection also belongs in custom agent definitions rather than either instruction file.

## Goals

- Make this repository the single source of truth for global Codex and Claude Code behavior.
- Install instructions, custom agents, and skills globally with one idempotent command.
- Give the main agent a Distinguished Software Engineer operating model and explicit orchestration responsibility.
- Provide researcher, planner, implementer, and reviewer agents with user-selected model and reasoning settings.
- Keep research, planning, and review bounded; prevent recursive or conflicting delegation.
- Preserve machine-specific credentials, MCP registrations, permissions, and primary-model settings.
- Back up pre-existing global files before replacing them.

## Non-goals

- Managing `~/.codex/config.toml`, `~/.claude/settings.json`, authentication, or provider configuration.
- Enabling recursive agent trees or experimental agent-team workflows.
- Running multiple write-capable agents against the same checkout.
- Supporting native Windows outside WSL or another Unix-compatible shell.
- Keeping machine-specific instructions whose referenced assets are absent from this repository.

## Repository Architecture

The repository will contain these managed assets:

```text
.codex/
  AGENTS.md
  agents/
    researcher.toml
    planner.toml
    implementer.toml
    reviewer.toml
  skills -> ../skills
.claude/
  CLAUDE.md
  agents/
    researcher.md
    planner.md
    implementer.md
    reviewer.md
  skills -> ../skills
docs/plans/
install.sh
skills/
tests/
  install_test.sh
```

The installer maps canonical repository files to the active user configuration directories:

| Repository source | Global destination |
|---|---|
| `.codex/AGENTS.md` | `${CODEX_HOME:-$HOME/.codex}/AGENTS.md` |
| `.codex/agents/*.toml` | `${CODEX_HOME:-$HOME/.codex}/agents/` |
| `.claude/CLAUDE.md` | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/CLAUDE.md` |
| `.claude/agents/*.md` | `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/agents/` |
| `skills/*/` | Both tools' global `skills/` directories |

Absolute symlink targets are intentional. The repository may be cloned anywhere, and `install.sh` derives its own location. Moving the clone requires rerunning the installer.

## Instruction Design

`.codex/AGENTS.md` is the shared, vendor-neutral operating contract. It defines observable Distinguished Software Engineer behavior instead of a fictional biography:

- Own system-level correctness, simplicity, compatibility, security, operability, and maintainability.
- Establish goal, context, constraints, and completion criteria.
- Inspect entry points, invariants, callers, tests, and blast radius before changing code.
- Keep plans and diffs proportional to task risk.
- Treat public interfaces, configuration, schemas, persisted data, and userspace behavior as contracts.
- Validate untrusted input, protect secrets and PII, and escalate high-risk boundaries.
- Measure performance before optimizing while avoiding obvious algorithmic and I/O footguns.
- Add deterministic tests appropriate to the change.
- Verify with fresh command output and inspect the final diff before claiming success.
- Report the outcome, rationale, risks, and only useful follow-ups.

`.claude/CLAUDE.md` imports the shared contract using `@../.codex/AGENTS.md` and adds only Claude-specific agent invocation and tool-boundary notes. This avoids maintaining two copies of the persona.

Repository-specific build commands and architecture stay in each repository's own root instruction files. The global contract remains concise and portable.

## Orchestration Model

The main agent is the decision owner, not a passive dispatcher. It owns user interaction, scope, architecture choices, mutation sequencing, integration, finding adjudication, final verification, and the final response.

Delegation follows this sequence when useful:

1. Keep trivial tasks and context-heavy iterative work in the main thread.
2. Delegate independent research or inspection lanes in parallel.
3. Ask the planner for bounded decomposition after relevant context is known.
4. Use at most one implementer at a time; never overlap file ownership.
5. Run focused verification, then request an independent review.
6. Let the main agent adjudicate findings and decide whether another bounded fix/review cycle is warranted.

At most three read-only agents may run concurrently. Workers do not recursively delegate. Each delegation must include the objective, relevant context, scope and non-goals, constraints, expected evidence, output format, and completion condition. Worker output is evidence, not authority.

Auth, permissions, payments, PII, destructive migrations, and major architecture decisions remain under direct main-agent control.

## Agent Roles and Models

| Role | Authority | Codex | Claude Code |
|---|---|---|---|
| Researcher | Read-only code and source research | `gpt-5.6-luna`, `xhigh` | `sonnet`, `xhigh` |
| Planner | Read-only plan, risks, and compatibility analysis | `gpt-5.6-sol`, `low` | `opus`, `low` |
| Implementer | Assigned, bounded workspace edits | `gpt-5.6-sol`, `medium` | `opus`, `medium` |
| Reviewer | Read-only correctness and regression gate | `gpt-5.6-sol`, `high` | `opus`, `high` |

The main model is intentionally not managed by this repository. The user selects it through each tool's machine-specific configuration.

### Researcher Contract

- Gather repository evidence and current primary sources.
- Separate verified facts from inference and uncertainty.
- Return concise findings with file/line references or direct source URLs.
- Do not edit files or expand into planning or implementation.

### Planner Contract

- Inspect existing patterns before proposing work.
- Produce a minimal, ordered implementation plan with exact files, compatibility risks, tests, and rollback notes.
- Surface missing information and competing approaches.
- Do not edit files or silently make architecture decisions reserved for the main agent.

### Implementer Contract

- Modify only the assigned files and behavior.
- Preserve unrelated user changes and existing conventions.
- Add or update focused tests and run the requested checks.
- Stop and report when the assignment requires broader authority or conflicting edits.

### Reviewer Contract

- Review the actual diff and relevant tests, not the implementation summary.
- Prioritize correctness, regressions, security, data integrity, concurrency, and missing coverage.
- Report actionable findings ordered by severity with file/line evidence.
- Avoid style-only noise and explicitly state when no substantive findings remain.

## Installer Behavior

`install.sh` will retain `set -euo pipefail` and add a common link function used by instructions, agents, and skills.

- `./install.sh --dry-run` prints planned operations without changing the filesystem.
- Missing canonical sources fail before destination mutation.
- A destination already linked to the expected source is left unchanged.
- A conflicting file, directory, or incorrect symlink is moved to a unique timestamped backup.
- If replacement-link creation fails, the installer restores the backup.
- Successful operations print the source and destination.
- All path expansions are quoted.
- `CODEX_HOME` and `CLAUDE_CONFIG_DIR` overrides are honored.

The existing global Codex and Claude instruction files on this machine will be backed up during the real installation. The current Claude-only `/graphify` instruction is machine-specific and references a skill absent from this repository, so it is not migrated into the portable global contract.

## Error Handling and Rollback

Installer errors must identify the failed source or destination and the next corrective action. Pre-existing data is never deleted. A failed replacement restores the original destination when possible; otherwise the printed backup path provides manual recovery.

To roll back an installed file, remove the managed symlink and rename its printed backup to the original destination. To repair links after moving the repository, rerun `./install.sh` from the new location.

## Verification Strategy

`tests/install_test.sh` will run the installer against temporary user directories and verify:

- dry-run makes no changes;
- a clean install creates every expected symlink;
- a second install is idempotent and creates no backups;
- conflicting destinations are preserved in backups;
- non-default `CODEX_HOME` and `CLAUDE_CONFIG_DIR` work;
- every installed link resolves to the canonical repository file.

Additional verification:

- `bash -n install.sh tests/install_test.sh`;
- `shellcheck` when installed;
- TOML parsing for all Codex agents;
- YAML-frontmatter inspection for all Claude agents;
- actual installation into the current user directories;
- `codex doctor` and `claude doctor` where non-interactive diagnostics are safe;
- final `git diff --check`, status inspection, and strict diff review.

No network model run is required merely to validate the user-selected model identifiers. `gpt-5.6-luna` availability remains account-dependent and will surface when that agent is first invoked.

## Compatibility and Risk Notes

- Symlinks make repository updates immediate but depend on the clone remaining at the same path.
- Custom-agent schemas and model catalogs can evolve; each model selection is isolated to one small definition for easy updates.
- Claude aliases (`sonnet`, `opus`) intentionally follow the tool's current alias resolution.
- The installer does not overwrite machine-specific configuration files.
- Parallel write-heavy work is deliberately excluded to avoid shared-worktree conflicts.
- Global instructions are behavioral guidance, not a security enforcement boundary; tool restrictions and existing client permission systems remain authoritative.

## Source Basis

- [OpenAI: Custom instructions with AGENTS.md](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
- [OpenAI: Subagents](https://learn.chatgpt.com/docs/agent-configuration/subagents)
- [OpenAI: Codex best practices](https://learn.chatgpt.com/guides/best-practices)
- [Anthropic: How Claude remembers your project](https://code.claude.com/docs/en/memory)
- [Anthropic: Create custom subagents](https://code.claude.com/docs/en/sub-agents)
- [Anthropic: Model configuration](https://code.claude.com/docs/en/model-config)
