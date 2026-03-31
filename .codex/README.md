# Codex Project Files

This directory is the project-local home for Codex-generated files.

Use `.codex/` for repository-specific Codex setup, shared configuration, and lightweight documentation that should live with the project instead of the repo root.

Guidelines:

- Keep tracked, human-readable Codex project files here.
- Record project-local approved command prefixes in `.codex/permissions.json`.
- Put machine-local or ephemeral data in `.codex/cache/`, `.codex/state/`, or `.codex/tmp/`.
- Do not move application source, worker code, Supabase files, or general project docs into this directory.
- Mirror existing repo conventions for hidden tooling folders such as `.claude/` and `.superpowers/`.
