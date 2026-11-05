# blastd

## Index

- Rules: `~/.codex/AGENTS.md`; repo exceptions: repo `AGENTS.md`.
- Skills: `/workspace/agent-state/skills/README.md`; todo: repo `docs/todo.txt`.
- Memory: `~/.optmem/memo`; shared notes: `/workspace/agent-state/notes/`.

Extracted A peer-to-peer core: `src/` code, `tests/` checks, `docs/` architecture
and todo. Host provides transport/policy hooks, authentication and identity.

Compact data-oriented Nim; preserve aligned columns, visible ownership/mutation.
For important code render, revise ~3–20 lines, render again; widen if unsettled.
Run `make test` after changes. Human-readable topical docs and tree notation;
keep generated output out of Git. LF text.

Todo order = priority, not sequence. Independent work may proceed in any order.
Standalone `defer>>>` / `Deferred>>>` defers every following entry; leave
explicitly deferred work untouched until user reopens it. Comment tags: `#!!`
uncommitted hack; `#?`/`#????` confusion, explain line; `#todo` unimplemented
block; `#fixme` unintended/broken behavior. Avoid trivial semantic wrappers;
compact locals: v number-like, x scalar, i integer, s symbol when clear.

Preserve quotes verbatim. Shared skills and personal notes: `/workspace/agent-state`;
repo-specific exceptions stay here. Prefer VM-local rules for personal preferences;
user instructions win. Shared vacation/dream skills use increased allowance.
