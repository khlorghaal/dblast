# blastd

blastd is A's extracted peer-to-peer core. Host applications provide transport
and policy hooks; peer authentication and identity remain host responsibilities.

Keep code compact and data-oriented. Preserve purposeful column alignment and
visible ownership and mutation. For important code, render it, revise a local
region of about 3–20 lines, then render again. Widen review when local changes
do not settle the file.

Sources live in `src/`; tests live in `tests/`. Run `make test` after changes.
Keep docs human-readable, organized by topic, and use tree notation for concise
architecture and todo notes. Keep generated output out of Git and use LF endings.

Todo order expresses priority; independent tasks may be done in any order. A
standalone `defer>>>` or `Deferred>>>` line defers all following entries. Do not
work on deferred tasks until explicitly brought back into scope.

Comment markers:

- `#!!`: hacky code that was not supposed to commit.
- `#?`, `#????`, and similar: confusion; explain the line in a comment.
- `#todo`: unimplemented behavior.
- `#fixme`: unintended or broken behavior.

Avoid semantic-only wrapper functions. For compact locals, use `v` for
number-like values, `x` for scalars, `i` for integers, and `s` for symbols when
context is clear.
