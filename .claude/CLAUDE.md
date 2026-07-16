@../.codex/AGENTS.md

## Claude Code Integration

- The main Claude Code conversation is the orchestrator. Use standard custom
  subagents for bounded work; do not use agent teams unless the user explicitly
  requests peer-to-peer coordination.
- Use `researcher`, `planner`, `implementer`, and `reviewer` according to the
  shared routing rules. Prefer these custom roles over built-in Explore or Plan
  when the worker must receive the global engineering contract.
- Never add `Edit`, `Write`, or equivalent mutation tools to read-only roles.
  Only `implementer` may receive write tools, and only for an explicit scope.
- Do not pass the `Agent` tool to workers. The main conversation alone manages
  delegation and synthesis.
- Model, effort, tool, permission, and turn limits belong in each agent file.
  Do not override them casually from the delegation prompt.
