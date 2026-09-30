## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (AttackOnTyler/confluence), managed via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` plus `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Studio seat (PROTOTYPE, glacialis #185)

- The `blender` and `godot` MCP servers start through `node tools/studio/mcp.mjs`, which enters the dev shell itself.
- Run `just blender` before using the Blender server; it starts Blender under a virtual display with the vendored addon.
- Your own shell is not in the dev shell: run toolchain commands as `just <recipe>` or `direnv exec . <cmd>`. Build C# with `just build` before `run_project`.
