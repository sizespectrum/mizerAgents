# Set up an AI agent to help with your mizer project

Creates (or updates) a `MIZER-AGENTS.md` file in your project directory
containing a concise mizer reference that AI coding agents read
automatically on startup. The file includes the core mizer workflow, key
object descriptions, and the path to the bundled API index: a curated
list of every exported mizer function, grouped by workflow stage, for
finding the right function. Argument lists are deliberately not bundled:
those go stale silently, so the card sends agents to the help pages of
the mizer version you actually have installed.

## Usage

``` r
setup_mizer_agent(
  path = ".",
  overwrite = FALSE,
  r_session = TRUE,
  run_r = TRUE,
  pkg_dev = FALSE,
  rprofile = FALSE,
  agents = .agent_choices
)
```

## Arguments

- path:

  Directory in which to create or update the agent files. Defaults to
  the current working directory, which should be your R project root.

- overwrite:

  If `TRUE`, replace existing `AGENTS.md`, `CLAUDE.md` and `GEMINI.md`
  files entirely with a clean shim, discarding your project notes. If
  `FALSE` (the default), keep the rest of each file and only refresh the
  marked mizer block, adding it at the top if it is not there yet.
  `MIZER-AGENTS.md` is always overwritten to ensure it stays up-to-date.

- r_session:

  If `TRUE` (the default), configure the `r-mizer` MCP server so that
  the agent can read mizer's documentation, your global environment and,
  in RStudio or Positron, the open document. Set to `FALSE` to write no
  MCP config at all.

- run_r:

  If `TRUE` (the default), let the agent *evaluate* R code in your
  session, which is what allows it to project or calibrate a model and
  see the resulting plots. The code runs in your global environment with
  no sandboxing, so the agent can overwrite your objects; work under
  version control, or set this to `FALSE` for a read-only connection.
  Ignored when `r_session = FALSE`.

- pkg_dev:

  If `TRUE`, also expose btw's package development tools (`load_all()`,
  `document()`, `test()`, `check()` and test coverage), which run
  against the package in your session's working directory. Set this when
  the project is itself an R package, such as a mizer extension. `FALSE`
  by default, since these tools do nothing useful in an ordinary
  modelling project. Ignored when `r_session = FALSE`.

- rprofile:

  If `TRUE`, append a guarded
  [`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
  call to the project `.Rprofile`, so that each new session hands itself
  to the MCP server automatically. `FALSE` by default, in which case you
  call
  [`connect_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/connect_mizer_agent.md)
  yourself. The `.Rprofile` calls btw directly rather than going through
  this package, so that a project still starts cleanly without
  mizerAgents installed. R reads a project `.Rprofile` only when it
  starts in that directory, which RStudio and Positron guarantee for a
  project and starting R from a shell does not, so from a terminal
  either start R in the project root or call
  [`connect_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/connect_mizer_agent.md)
  yourself. Ignored when `r_session = FALSE`.

- agents:

  Which agents to configure the server for. By default all of them,
  since the config files are small, sit in different places and do not
  interfere with each other, so a project set up on your machine works
  for a collaborator using a different agent. Any of:

  |                 |                                  |
  |-----------------|----------------------------------|
  | Value           | File written                     |
  | `"claude"`      | `.mcp.json`                      |
  | `"codex"`       | `.codex/config.toml`             |
  | `"gemini"`      | `.gemini/settings.json`          |
  | `"antigravity"` | `.agents/mcp_config.json`        |
  | `"cursor"`      | `.cursor/mcp.json`               |
  | `"vscode"`      | `.vscode/mcp.json`               |
  | `"posit"`       | `.posit/assistant/settings.json` |
  | `"copilot"`     | *(none; instructions printed)*   |

  `"posit"` covers Posit Assistant, which runs in RStudio as well as
  Positron. Copilot CLI reads MCP config only from the user-wide
  `~/.copilot/mcp-config.json`, so nothing is written for it; you get
  the snippet to paste there instead. Ignored when `r_session = FALSE`.

## Value

Invisibly returns the path to the `AGENTS.md` file.

## Details

It also creates (or updates) the instruction files agents read at
startup - `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` - adding to each a
short note and a `@MIZER-AGENTS.md` import, so that agents read both the
project-specific instructions and the mizer reference. Agents that
resolve `@` imports (Claude Code, Gemini CLI) pick the reference up
automatically at startup; the note tells those that do not (Codex,
Copilot) to read the file themselves. All three files are handled alike,
because none of them is a fallback for another: Claude Code reads
`CLAUDE.md` and not `AGENTS.md`, and Gemini CLI reads `GEMINI.md`, so an
agent that looks only for its own named file still finds the block. The
block is delimited by `<!-- mizerAgents: start -->` and
`<!-- mizerAgents: end -->` comments and is refreshed in place on every
run, so that improvements to it reach existing projects. Add your own
project notes outside those markers, where they will be left untouched.

The block is the only thing added: no `@AGENTS.md` import is ever
written or removed, so which of your own instructions reach which agent
is unchanged. If one of these files already imports `AGENTS.md`, whether
you wrote that yourself or an earlier version of this package did, it is
left untouched - the block reaches the agent through the import.

It also installs a set of Claude Code *skills* into `.claude/skills/`
(one sub-directory with a `SKILL.md` per skill, e.g. `analyse-and-plot`
and `build-multispecies-model`). Claude Code loads these automatically
when a task matches, giving step-by-step guidance for common mizer
workflows. Like `MIZER-AGENTS.md`, the skills are package-managed and
refreshed on every call so they stay up to date.

The skills are taken from the **installed mizer** (`inst/skills/`), not
from this package, so the guidance an agent follows always describes the
mizer the project is actually running. In mizer each `SKILL.md` is also
the source of the matching `cheatsheet-*` article on the mizer website,
so the two are the same document. Skills arrived in mizer 3.2.2; against
an older mizer this function still writes everything else and reports
that it installed none.

What a project learns about mizer is kept separate from them, so that
neither overwrites the other. Each skill's directory may hold a
`NOTES.md`, which this package never writes and which the `SKILL.md`
tells agents to read alongside it and to treat as taking precedence:
that is where an agent should record what it discovers about *your*
model. Findings that are true of mizer in general belong upstream
instead, and the skills tell agents to offer to report them at
<https://github.com/sizespectrum/mizerAgents/issues>, so that every
project gets them in the next release.

Refreshing works file by file rather than by replacing whole
directories, so a `NOTES.md`, or a skill of your own, is left alone. The
hashes of the files installed are recorded in
`.claude/skills/.mizerAgents.json`; a file that has since been edited is
recognised, kept, and reported, with the new version written beside it
as `<file>.new` for you to merge, rather than silently overwritten. (A
project set up by version 0.3.2 or earlier has no such record, so the
first run after upgrading refreshes the skills as it always did and
starts keeping one.) Files that later versions stop shipping are removed
if they are unmodified.

So that agents other than Claude Code (which do not discover
`.claude/skills/` natively) can use the skills too, an index of them
(each skill's name, one-line description, and path) is generated from
the skills' own frontmatter and added to `MIZER-AGENTS.md`. Those agents
can then read the relevant `SKILL.md` on demand when a task matches.

Finally, unless `r_session = FALSE`, it configures an MCP server named
`r-mizer` so that the agent can reach your live R session. Agents have
not converged on where MCP servers are configured, so by default every
one that supports a project-level config gets its own file: Claude Code,
Codex, Gemini CLI, Antigravity, Cursor, VS Code and Posit Assistant. See
the `agents` argument for the paths and for how to narrow the list. The
server is provided by the [btw](https://posit-dev.github.io/btw/)
package, which you need to install separately. This gives the agent help
pages and vignettes for the mizer version you actually have installed,
rather than whatever mizer API it remembers, along with a view of the
objects in your global environment, and it can run mizer code there and
see the plots that come back. For the server to see your session you
must run
[`connect_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/connect_mizer_agent.md)
in the R console once per session; passing `rprofile = TRUE` adds the
underlying
[`btw::btw_mcp_session()`](https://posit-dev.github.io/btw/reference/mcp.html)
call to the project `.Rprofile` so that it happens automatically - which
needs R to be started in the project directory, as RStudio and Positron
do for you and a shell does not. Only the `r-mizer` entry of `.mcp.json`
is package-managed; other servers you configure there are left alone.

After running this function, start your AI coding agent (e.g. `claude`,
`codex`, `copilot` or `gemini`) from a terminal in the project
directory - the RStudio or Positron Terminal pane, or any other
terminal - and it will immediately have the mizer context it needs.

Nothing here is tied to a particular editor. The files are read by
agents running in a terminal, and the session connection is a socket, so
a project set up this way works the same from RStudio, Positron, a bare
R console, ESS or the VS Code R extension. The one exception is the
agent's ability to read the document you have open, which needs
`rstudioapi` and so works only in RStudio and Positron; everything else
does not.

## See also

[`connect_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/connect_mizer_agent.md)
to hand your session to the server this configures,
[`update_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/update_mizer_agent.md),
which refreshes the files a project already has while keeping the
settings it was set up with, and
[`remove_mizer_agent()`](https://sizespectrum.github.io/mizerAgents/reference/remove_mizer_agent.md),
which undoes all of this.

## Examples

``` r
if (FALSE) { # \dontrun{
# Run once in your mizer project to set up AI agent support
setup_mizer_agent()

# In a mizer extension package, add the package development tools and
# connect the session automatically on startup
setup_mizer_agent(pkg_dev = TRUE, rprofile = TRUE)

# A read-only connection: documentation and inspection, but no execution
setup_mizer_agent(run_r = FALSE)
} # }
```
