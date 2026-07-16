# pkfire

Personal toolbox: skills and custom MCP servers, shared between Claude Code and Codex.

## Layout

- `skills/` — canonical skills, one dir per skill containing a `SKILL.md`. Both tools read this same format.
- `.codex/AGENTS.md` — canonical global Distinguished Software Engineer guidance for Codex.
- `.claude/CLAUDE.md` — canonical global Claude Code guidance; imports the shared Codex guidance and adds Claude-specific orchestration rules.
- `.codex/agents/` and `.claude/agents/` — matching custom definitions for the `researcher`, `planner`, `implementer`, and `reviewer` roles.
- `mcp/` — custom MCP servers, one dir per server.
- `.claude/skills` and `.codex/skills` — symlinks to `skills/`, so both tools auto-discover skills when working inside this repo.
- `.mcp.json` — Claude Code project-scoped MCP registration.
- `install.sh` — safely symlinks the global instructions, custom agents, and every skill into both tools' user configuration directories.

## Installing globally

Preview the installation without changing anything:

```bash
./install.sh --dry-run
```

Install or refresh all managed links:

```bash
./install.sh
```

Conflicting destinations are preserved as timestamped backups. The installer honors `CODEX_HOME` and `CLAUDE_CONFIG_DIR`, and it is safe to rerun. Re-run it after moving the clone or adding an agent or skill.

Machine-specific files such as `~/.codex/config.toml`, `~/.claude/settings.json`, credentials, permissions, model defaults, and MCP registrations are intentionally not managed.

## Custom agents

Keep role names and responsibilities aligned across `.codex/agents/` and `.claude/agents/`:

- `researcher` — read-only evidence gathering.
- `planner` — read-only implementation planning and compatibility analysis.
- `implementer` — bounded edits with explicit ownership.
- `reviewer` — independent read-only correctness review.

Per-role model and reasoning settings live in the agent definitions. Update both tool-specific files when changing a role contract.

## Adding a skill

Create `skills/<name>/SKILL.md`:

```markdown
---
name: my-skill
description: One line saying when to use this skill.
---

Instructions here. Extra files (scripts, references) live next to SKILL.md.
```

Then run `./install.sh`.

## Adding an MCP server

Put the server code in `mcp/<name>/`, then register it in both tools:

- **Claude Code**: add an entry to `.mcp.json` (project scope), or `claude mcp add <name> -s user -- <command>` for global.
- **Codex**: add to `~/.codex/config.toml`:

```toml
[mcp_servers.<name>]
command = "node"
args = ["/absolute/path/to/pkfire/mcp/<name>/index.js"]
```
