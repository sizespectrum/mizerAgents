# Where the bundled skills come from.
#
# The skills are maintained in mizer itself (`inst/skills/`), where each
# `SKILL.md` doubles as the source of the matching `guide-*` article on the
# mizer website. Reading them from the *installed* mizer rather than shipping a
# copy here means the guidance an agent follows always describes the mizer the
# user is actually running: a project on CRAN mizer gets the CRAN skills, one on
# the development version gets the development skills, with no version skew
# between the two packages to keep in step by hand.
#
# Returns "" when the installed mizer is too old to ship them, which the caller
# reports rather than treating as an error - everything else `setup_mizer_agent()`
# writes is independent of mizer.
.skills_source <- function() {
    src <- system.file("skills", package = "mizer")
    if (nzchar(src) && dir.exists(src)) src else ""
}

# Files under mizer's `inst/skills/` that are not part of the skill an agent
# follows. A `quick-reference.md` is website material: mizer's guide
# generator appends it to the article as a "Quick reference" section, and no
# `SKILL.md` points at it, so an agent that is given one never reads it. Copying
# it into a project only adds a file the user has to recognise as ours.
#
# `rels` are paths relative to the skills source. Internal helper.
.skill_payload <- function(rels) rels[basename(rels) != "quick-reference.md"]

# Drop the article-only blocks from a `SKILL.md`.
#
# The mirror of the `<!-- agent-only -->` blocks that mizer's guide generator
# drops on its way to the website: content between `<!-- article-only -->` and
# `<!-- /article-only -->` belongs to the article and not to the skill. It is
# typically a worked example whose value is the output it produces, which the
# article evaluates and shows; an agent cannot see that output and would only
# have to read past the code.
#
# Filtering here rather than in mizer is what lets a topic stay one file:
# `SKILL.md` holds both halves, each side of the fence takes the half it wants.
# The markers are dropped along with the block, so a skill from a mizer that
# does not use them is returned unchanged.
.strip_article_only <- function(content) {
    open <- grepl("^\\s*<!--\\s*article-only\\s*-->\\s*$", content)
    close <- grepl("^\\s*<!--\\s*/article-only\\s*-->\\s*$", content)
    if (!any(open)) return(content)
    # cumsum of opens minus closes already consumed: inside the block whenever
    # an open has been seen and its close has not.
    inside <- cumsum(open) > cumsum(close)
    content[!(inside | close)]
}

# Where the API index comes from, on the same reasoning as `.skills_source()`.
#
# `llms.txt` lists every exported mizer function with a one-line description, so
# it describes one version of the mizer API and goes stale the moment mizer gains
# or renames a function. It is generated in mizer by `dev_scripts/build_llms.R`
# and installed there, so the index an agent greps matches the mizer the project
# actually runs.
#
# Falls back to the copy bundled here for a mizer predating that move. Unlike the
# skills there is always a source, so this never returns "": a stale index still
# names most functions correctly, and the card sends the agent to the installed
# mizer's help pages for anything it finds.
.llms_source <- function() {
    src <- system.file("llms.txt", package = "mizer")
    if (nzchar(src) && file.exists(src)) return(src)
    system.file("llms.txt", package = "mizerAgents")
}

# Extract the `description` field from a SKILL.md YAML frontmatter block.
# Handles both an inline value and a folded/literal block scalar (`>`, `>-`,
# `|`, ...), collapsing it to a single-line string. Internal helper.
.skill_description <- function(skill_md) {
    lines <- readLines(skill_md, warn = FALSE)
    idx <- grep("^description:", lines)
    if (length(idx) == 0) return("(no description)")
    idx <- idx[1]
    val <- sub("^description:[ \t]*", "", lines[idx])
    if (grepl("^[>|]", val) || !nzchar(trimws(val))) {
        # Block scalar: collect following indented (or blank) lines until the
        # next top-level key or the closing `---`.
        parts <- character(0)
        j <- idx + 1
        while (j <= length(lines) &&
               !grepl("^---", lines[j]) &&
               (grepl("^[ \t]", lines[j]) || !nzchar(lines[j]))) {
            if (nzchar(trimws(lines[j]))) parts <- c(parts, trimws(lines[j]))
            j <- j + 1
        }
        val <- paste(parts, collapse = " ")
    }
    trimws(val)
}

# The "task skills" index for the always-loaded reference card, generated from
# the bundled skills' own frontmatter. Claude Code discovers `.claude/skills/`
# natively; every other agent does not, so this index is how they learn which
# skills exist and when to read them. Only the index (names + descriptions +
# path) goes in the card; the skill bodies stay on disk and are read on demand,
# mirroring Claude Code's lazy loading.
#
# Returns "" when the installed mizer ships no skills, which drops the section
# from the card entirely rather than promising guides that are not there.
.skills_index_section <- function(skills_src) {
    if (!nzchar(skills_src) || !dir.exists(skills_src)) return("")
    skill_dirs <- sort(list.dirs(skills_src, recursive = FALSE))
    index_lines <- vapply(skill_dirs, function(d) {
        sprintf("- **`%s`**: %s",
                basename(d), .skill_description(file.path(d, "SKILL.md")))
    }, character(1))
    paste0(
        "## Task skills (read on demand)\n\n",
        "Step-by-step guides for common mizer tasks are installed under ",
        "`.claude/skills/<name>/SKILL.md`. Claude Code loads them ",
        "automatically; other agents should **read the matching file before ",
        "starting** such a task rather than working from memory. They are the ",
        "reference this card is not: workflows, argument tables and the ",
        "failure modes of each step. Triggers:\n\n",
        paste(index_lines, collapse = "\n"), "\n\n",
        "A skill's directory may also hold a `NOTES.md` recording what ",
        "earlier work in this project found. Read it whenever you read the ",
        "`SKILL.md`, and treat it as taking precedence. Write new ",
        "project-specific findings there, creating the file if needed.\n\n",
        "Do not edit `SKILL.md` or this card: both are installed by ",
        "`mizerAgents::setup_mizer_agent()`. Project notes that belong to no ",
        "single skill go in `AGENTS.md` / `CLAUDE.md`, outside the ",
        "`<!-- mizerAgents: ... -->` markers. A lesson that is true of mizer ",
        "in general rather than of this project belongs upstream, where every ",
        "project gets it: tell the user, and offer to report it at ",
        "<https://github.com/sizespectrum/mizerAgents/issues>."
    )
}

# The section pointing at the bundled API index, explicit about what that index
# is *not*. The index is a curated map of the API grouped by workflow stage,
# which no tool can regenerate, and it ages gracefully: a function that has been
# renamed shows up as a lookup that fails, not as a call that quietly does the
# wrong thing. Signatures and defaults are the part that rots dangerously, so
# they are deliberately not bundled: they come from the installed mizer, read
# through btw when the user's session is connected and through `Rscript` when it
# is not.
.function_lookup_section <- function(llms_src, r_session) {
    paste0(
        "## Finding the right mizer function\n\n",
        "Two steps, and they use different sources:\n\n",
        "1. **Which function do I need?** Grep the bundled API index: every\n",
        "   exported function with a one-line description, grouped by workflow\n",
        "   stage (creating a model, tuning the steady state, projecting,\n",
        "   plotting). Grep it for a keyword; do not read the whole file:\n",
        "   ", llms_src, "\n",
        "2. **How do I call it?** ",
        if (isTRUE(r_session)) {
            paste0(
                "Read the help page for the *installed* mizer with\n",
                "   `btw_tool_docs_help_page`. The index above deliberately carries no\n",
                "   argument lists, and this card is not a reference either.\n"
            )
        } else {
            paste0(
                "Read the help page for the *installed* mizer:\n",
                "   `Rscript -e 'help(name, package = \"mizer\")'`. The index above\n",
                "   deliberately carries no argument lists, and this card is not a\n",
                "   reference either.\n"
            )
        },
        "\nNever supply arguments from memory for a function you have not looked up\n",
        "in this session. Rendered documentation for the current release is at\n",
        "<https://sizespectrum.org/mizer/reference/>, but the installed version is\n",
        "what your code will run against, so prefer the local help page."
    )
}

# Substitute a generated section into the reference card.
#
# `inst/MIZER-AGENTS.md` carries `<!-- mizerAgents:<name> -->` placeholder lines
# where the generated sections go, rather than having them appended in the order
# the code happens to build them. The card is always loaded in full, but an
# agent reads it top-down under a budget, so the sections that route it
# elsewhere - the skills index, the function lookup - have to sit near the top,
# and only the card itself is in a position to say where. Adding a section means
# adding its placeholder there too.
#
# `lines` and the return value are character vectors of lines; `text` is a
# single string, possibly multi-line, and possibly empty for a section this
# project does not get (no skills installed, no R session). An empty section
# takes its placeholder and the blank line after it away with it, so that
# turning one off leaves no gap behind.
.fill_card_section <- function(lines, name, text) {
    marker <- paste0("<!-- mizerAgents:", name, " -->")
    at <- which(trimws(lines) == marker)
    if (length(at) != 1) {
        stop("MIZER-AGENTS.md needs exactly one `", marker, "` placeholder, ",
             "found ", length(at), ".", call. = FALSE)
    }
    if (!nzchar(text)) {
        drop <- if (at < length(lines) && !nzchar(lines[at + 1])) c(at, at + 1) else at
        return(lines[-drop])
    }
    append(lines[-at], strsplit(text, "\n", fixed = TRUE)[[1]], after = at - 1)
}

# The instruction files agents read at startup. None of them is a fallback for
# another: Claude Code reads `CLAUDE.md` and not `AGENTS.md`, and Gemini CLI
# reads `GEMINI.md` unless `context.fileName` says otherwise. So all three are
# handled, and an agent that reads only its own named file still finds the mizer
# context - through the block itself in a file the project already had, or
# through an `@AGENTS.md` import in one we create ourselves.
.instruction_files <- c("AGENTS.md", "CLAUDE.md", "GEMINI.md")

# Marker comments delimiting the package-managed block inside the user's
# instruction files. Everything between them is rewritten on each run;
# everything outside belongs to the user.
.shim_begin <- "<!-- mizerAgents: start - managed by setup_mizer_agent(), edits are overwritten -->"
.shim_end   <- "<!-- mizerAgents: end -->"

# The block itself is prose plus an `@` import because the two reach different
# agents: Claude Code and Gemini CLI resolve `@` and inline the reference card
# unconditionally at startup, while Codex and Copilot do not, so for them the
# sentence is the only thing that gets the file read. Keep this short:
# substantive guidance belongs in `inst/MIZER-AGENTS.md`, which is the file agents
# read as a reference.
.shim_note <- c(
    "This project uses [mizer](https://sizespectrum.org/mizer/) for size-spectrum",
    "modelling. Read `MIZER-AGENTS.md` before writing or changing mizer code; it is",
    "imported below if your tool resolves `@` imports. It is generated by",
    "`mizerAgents::setup_mizer_agent()`; don't edit it by hand.",
    "",
    "@MIZER-AGENTS.md"
)

# Locate the package-managed block in an existing instruction file, returning
# the line range to replace or `NULL` if there is nothing to update.
#
# Only two forms exist in the wild. The current one is delimited by the markers
# above. The other is from earlier versions: a bare `@MIZER-AGENTS.md`
# import line with no note and no markers, which is upgraded in place.
#
# The one-line `@AGENTS.md` shims that 0.3.2 and earlier wrote into `CLAUDE.md`
# and `GEMINI.md` are deliberately not matched: see `.write_instruction_file()`.
# Internal helper.
.shim_range <- function(lines) {
    b <- which(lines == .shim_begin)
    e <- which(lines == .shim_end)
    if (length(b) && length(e) && e[1] > b[1]) return(c(b[1], e[1]))

    at <- which(lines == "@MIZER-AGENTS.md")
    if (!length(at)) return(NULL)
    # Replace the import line alone: anything around it is the user's own prose.
    c(at[1], at[1])
}

# Write the package-managed block into one instruction file, leaving the user's
# own content alone unless `overwrite` says otherwise.
#
# Which of a project's *existing* instructions reach which agent is the user's
# business, not ours, so in a file that is already there the block is the only
# thing we add and an `@` import is never written or removed: adding one would
# feed an agent notes it was not seeing before, and dropping one would cut off
# notes it was.
#
# `defers_to` names an import that carries our block into this file from a
# neighbour - `@AGENTS.md` for `CLAUDE.md` and `GEMINI.md`, which is what the
# one-line shims written by 0.3.2 and earlier hold. It does two things. An
# existing file that already has that import is left untouched: the agent
# reading it gets the mizer context through the import, so a second copy would
# be pure duplication. And a file that does not exist yet is created holding
# that import and nothing else, rather than a second copy of the block: nothing
# in the project is relying on `CLAUDE.md` yet, so pointing it at `AGENTS.md`
# gives the project one place to keep its instructions instead of three that
# have to be kept in step by hand. Internal helper.
.write_instruction_file <- function(dest, shim, overwrite, defers_to = NULL) {
    if (!file.exists(dest) || isTRUE(overwrite)) {
        if (is.null(defers_to)) {
            writeLines(shim, dest)
            message("Created ", dest, " with shim pointing to MIZER-AGENTS.md")
        } else {
            writeLines(defers_to, dest)
            message("Created ", dest, " importing AGENTS.md")
        }
        return(invisible(dest))
    }

    existing <- readLines(dest, warn = FALSE)
    range <- .shim_range(existing)
    if (is.null(range)) {
        if (!is.null(defers_to) && any(trimws(existing) == defers_to)) {
            return(invisible(dest))
        }
        updated <- c(shim, "", existing)
        action <- "Prepended @MIZER-AGENTS.md shim to existing "
    } else {
        updated <- c(existing[seq_len(range[1] - 1)], shim,
                     existing[-seq_len(range[2])])
        action <- "Refreshed the mizer block in "
    }
    # Leave the file alone when nothing would change, so that re-running setup
    # does not dirty a tracked file or bump its mtime.
    if (!identical(updated, existing)) {
        writeLines(updated, dest)
        message(action, dest)
    }
    invisible(dest)
}

# Appended to every deployed `SKILL.md`. The skills are package-managed and
# rewritten on every run, but a project accumulates findings of its own, and an
# agent that has just learned something writes it down wherever it happens to be
# looking - which is the skill it is following. So each skill points at a
# `NOTES.md` sibling that this package never writes, giving project-specific
# notes a home that survives the next refresh, and sends lessons that are true of
# mizer generally upstream instead of burying them in one project. Only
# `SKILL.md` is loaded automatically, so the pointer has to live there.
.skill_footer <- c(
    "",
    "---",
    "",
    "## Project notes",
    "",
    "If a `NOTES.md` file sits beside this one, read it too before you start: it",
    "records what earlier work in *this* project found, and wins over the guidance",
    "above wherever the two disagree.",
    "",
    "Write what you learn about this project into that `NOTES.md`, creating it if",
    "it is not there. Do not edit `SKILL.md`: it is installed by",
    "`mizerAgents::setup_mizer_agent()` and your edits would be reported as a",
    "conflict on the next run rather than kept.",
    "",
    "A lesson that is true of mizer in general, rather than of this project,",
    "belongs upstream where every project gets it. Tell the user, and offer to",
    "report it at <https://github.com/sizespectrum/mizerAgents/issues>."
)

# Record of what we last wrote into `.claude/skills/`, kept beside the skills
# themselves: a JSON object mapping each installed file's path, relative to that
# directory, to its MD5 sum. Without it we cannot tell a file edited in the
# project from one installed by an older version of this package, and would have
# to choose between clobbering the edits and freezing the skills at whatever
# shipped first.
.skill_manifest <- ".mizerAgents.json"

# MD5 sums of a character vector and of a file, so that the content we are about
# to write can be compared with what is already on disk. Internal helpers.
.hash_lines <- function(lines) {
    f <- tempfile()
    on.exit(unlink(f))
    writeLines(lines, f)
    unname(tools::md5sum(f))
}
.hash_file <- function(path) unname(tools::md5sum(path))

# Read the manifest, returning a named character vector of hashes, or `NULL` if
# there is none to read - which is also what an unreadable one becomes, since
# the only thing we can do without it is what every version before it did.
# Internal helper.
.read_skill_manifest <- function(path) {
    if (!file.exists(path)) return(NULL)
    entries <- tryCatch(
        jsonlite::fromJSON(path, simplifyVector = FALSE)$files,
        error = function(e) NULL
    )
    if (length(entries) == 0) return(character(0))
    # A JSON object comes back as a named list whatever `simplifyVector` says
    entries <- unlist(entries)
    if (!is.character(entries) || is.null(names(entries))) {
        warning("Could not parse ", path, "; the bundled skills will be ",
                "refreshed as if it were not there.", call. = FALSE)
        return(NULL)
    }
    entries
}

# Internal helper.
.write_skill_manifest <- function(path, hashes) {
    hashes <- hashes[order(names(hashes))]
    json <- as.character(jsonlite::toJSON(
        list(version = 1L, files = as.list(hashes)),
        auto_unbox = TRUE, pretty = TRUE
    ))
    old <- if (file.exists(path)) {
        paste(readLines(path, warn = FALSE), collapse = "\n")
    } else NA_character_
    if (!identical(old, json)) writeLines(json, path)
    invisible(path)
}

# Install the bundled skills into `.claude/skills/`, file by file.
#
# The unit of management is the file, not the directory: anything else in a
# skill's directory - a `NOTES.md`, or a skill of the user's own invention - is
# not ours and is left alone. A file we installed and nobody has touched since is
# refreshed; one that has been edited in the project is kept, with the new
# version written alongside as `<file>.new` for merging by hand, because a
# silently overwritten note is worse than a stale one. Files that later versions
# stop shipping are removed if unmodified, so that a dropped skill does not
# linger for ever.
#
# Returns the relative paths of the files whose local edits were kept, so the
# caller can report them. Internal helper.
.install_skills <- function(skills_src, path) {
    skills_dest <- normalizePath(file.path(path, ".claude", "skills"),
                                 mustWork = FALSE)
    dir.create(skills_dest, recursive = TRUE, showWarnings = FALSE)
    manifest_path <- file.path(skills_dest, .skill_manifest)
    recorded <- .read_skill_manifest(manifest_path)
    # A project set up before the manifest existed has nothing to compare
    # against, so this first run refreshes everything, exactly as every run did
    # then. From the next one on, edits made here are recognised and kept.
    adopting <- is.null(recorded)
    if (adopting) recorded <- character(0)

    all_rels <- sort(list.files(skills_src, recursive = TRUE))
    rels <- .skill_payload(all_rels)
    excluded <- setdiff(all_rels, rels)
    hashes <- character(0)
    installed <- character(0)
    kept <- character(0)

    for (rel in rels) {
        content <- readLines(file.path(skills_src, rel), warn = FALSE)
        if (basename(rel) == "SKILL.md") {
            content <- c(.strip_article_only(content), .skill_footer)
        }
        want <- .hash_lines(content)
        dest <- file.path(skills_dest, rel)
        side <- paste0(dest, ".new")

        if (file.exists(dest)) {
            have <- .hash_file(dest)
            if (identical(have, want)) {
                # Already current: leave it alone rather than bump its mtime
                hashes[rel] <- want
                unlink(side)
                next
            }
            if (!adopting && !identical(have, unname(recorded[rel]))) {
                if (!file.exists(side) || !identical(.hash_file(side), want)) {
                    writeLines(content, side)
                }
                kept <- c(kept, rel)
                # Keep the recorded hash, so the file is still recognised as
                # edited next time rather than adopted and then overwritten.
                if (rel %in% names(recorded)) hashes[rel] <- recorded[[rel]]
                next
            }
        }
        dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
        writeLines(content, dest)
        unlink(side)
        hashes[rel] <- want
        installed <- c(installed, sub("/.*$", "", rel))
    }

    # Files we shipped once and no longer do, including the ones that mizer
    # still ships but we have stopped installing. An unmodified one is ours to
    # remove; an edited one is not, so it stays and we stop tracking it. An
    # excluded file has no manifest entry once we have swept it, and in a
    # project set up before the manifest existed it never had one, so it is
    # matched against what we would have written for it instead.
    removed <- character(0)
    for (rel in union(setdiff(names(recorded), rels), excluded)) {
        dest <- file.path(skills_dest, rel)
        if (!file.exists(dest)) next
        want <- if (rel %in% names(recorded)) {
            unname(recorded[rel])
        } else {
            .hash_lines(readLines(file.path(skills_src, rel), warn = FALSE))
        }
        if (identical(.hash_file(dest), want)) {
            unlink(dest)
            removed <- c(removed, sub("/.*$", "", rel))
        }
    }
    # Only a directory we have emptied is a skill that has gone; removing a
    # single file from a skill we still install is not worth a message.
    removed <- setdiff(removed, sub("/.*$", "", rels))
    for (d in list.dirs(skills_dest, recursive = FALSE)) {
        if (length(list.files(d, all.files = TRUE, no.. = TRUE)) == 0) {
            unlink(d, recursive = TRUE)
        }
    }

    for (s in unique(installed)) message("Installed skill: ", s)
    for (s in unique(removed)) {
        message("Removed skill (no longer bundled): ", s)
    }
    .write_skill_manifest(manifest_path, hashes)
    invisible(kept)
}

#' Set up an AI agent to help with your mizer project
#'
#' Creates (or updates) a `MIZER-AGENTS.md` file in your project directory: a
#' short routing card that AI coding agents read automatically on startup. It is
#' not a mizer reference, on purpose - a summary complete enough to work from is
#' a summary an agent will work from instead of reading the skill, and it goes
#' stale a release later. The card carries only what has to be said up front,
#' then an index of the task skills, the path to the bundled API index (a
#' curated list of every exported mizer function, grouped by workflow stage) and
#' how to reach your R session. Argument lists are bundled nowhere: those go
#' stale silently, so the card sends agents to the help pages of the mizer
#' version you actually have installed.
#'
#' It also creates (or updates) the instruction files agents read at startup -
#' `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` - so that agents read both the
#' project-specific instructions and the mizer reference. All three are handled,
#' because none of them is a fallback for another: Claude Code reads `CLAUDE.md`
#' and not `AGENTS.md`, and Gemini CLI reads `GEMINI.md`, so an agent that looks
#' only for its own named file still has to find something.
#'
#' `AGENTS.md` gets a short note and a `@MIZER-AGENTS.md` import. Agents that
#' resolve `@` imports (Claude Code, Gemini CLI) pick the reference up
#' automatically at startup; the note tells those that do not (Codex, Copilot)
#' to read the file themselves. The block is delimited by
#' `<!-- mizerAgents: start -->` and `<!-- mizerAgents: end -->` comments and is
#' refreshed in place on every run, so that improvements to it reach existing
#' projects. Add your own project notes outside those markers, where they will
#' be left untouched.
#'
#' `CLAUDE.md` and `GEMINI.md` are treated differently depending on whether your
#' project already has them:
#'
#' * If the file is not there, it is created containing the single line
#'   `@AGENTS.md` and nothing else. Your project instructions then have one
#'   home, `AGENTS.md`, rather than three copies to keep in step by hand.
#' * If the file is already there, it gets its own copy of the block, exactly as
#'   `AGENTS.md` does, and the rest of the file is left alone. No `@AGENTS.md`
#'   import is written into it and none is removed, so which of your own
#'   instructions reach which agent is unchanged. If it already imports
#'   `AGENTS.md`, whether you wrote that yourself or an earlier version of this
#'   package did, the file is left untouched - the block reaches the agent
#'   through the import.
#'
#' It also installs a set of Claude Code *skills* into `.claude/skills/` (one
#' sub-directory with a `SKILL.md` per skill, e.g. `analyse-and-plot` and
#' `build-model`). Claude Code loads these automatically when a
#' task matches, giving step-by-step guidance for common mizer workflows. Like
#' `MIZER-AGENTS.md`, the skills are package-managed and refreshed on every call
#' so they stay up to date.
#'
#' The skills are taken from the **installed mizer** (`inst/skills/`), not from
#' this package, so the guidance an agent follows always describes the mizer the
#' project is actually running. In mizer each `SKILL.md` is also the source of
#' the matching `guide-*` article on the mizer website, so the two are the
#' same document. Skills arrived in mizer 3.2.2; against an older mizer this
#' function still writes everything else and reports that it installed none.
#'
#' What a project learns about mizer is kept separate from them, so that neither
#' overwrites the other. Each skill's directory may hold a `NOTES.md`, which this
#' package never writes and which the `SKILL.md` tells agents to read alongside
#' it and to treat as taking precedence: that is where an agent should record
#' what it discovers about *your* model. Findings that are true of mizer in
#' general belong upstream instead, and the skills tell agents to offer to report
#' them at <https://github.com/sizespectrum/mizerAgents/issues>, so that every
#' project gets them in the next release.
#'
#' Refreshing works file by file rather than by replacing whole directories, so
#' a `NOTES.md`, or a skill of your own, is left alone. The hashes of the files
#' installed are recorded in `.claude/skills/.mizerAgents.json`; a file that has
#' since been edited is recognised, kept, and reported, with the new version
#' written beside it as `<file>.new` for you to merge, rather than silently
#' overwritten. (A project set up by version 0.3.2 or earlier has no such record,
#' so the first run after upgrading refreshes the skills as it always did and
#' starts keeping one.) Files that later versions stop shipping are removed if
#' they are unmodified.
#'
#' So that agents other than Claude Code (which do not discover `.claude/skills/`
#' natively) can use the skills too, an index of them (each skill's
#' name, one-line description, and path) is generated from the skills' own frontmatter
#' and added to `MIZER-AGENTS.md`. Those agents can then read the relevant
#' `SKILL.md` on demand when a task matches.
#'
#' Finally, unless `r_session = FALSE`, it configures an MCP server named
#' `r-mizer` so that the agent can reach your live R session. Agents have not
#' converged on where MCP servers are configured, so by default every one that
#' supports a project-level config gets its own file: Claude Code, Codex,
#' Gemini CLI, Antigravity, Cursor, VS Code and Posit Assistant. See the
#' `agents` argument for the paths and for how to narrow the list.
#' The server is provided by the
#' [btw](https://posit-dev.github.io/btw/) package, which you need to install
#' separately. This gives the agent help pages and vignettes for the mizer
#' version you actually have installed, rather than whatever mizer API it
#' remembers, along with a view of the objects in your global environment, and
#' it can run mizer code there and see the plots that come back. For the server
#' to see your session you must run [connect_mizer_agent()] in the R console
#' once per session; passing `rprofile = TRUE` adds the underlying
#' `btw::btw_mcp_session()` call to the project `.Rprofile` so that it happens
#' automatically - which needs R to be started in the project directory, as
#' RStudio and Positron do for you and a shell does not.
#' Only the `r-mizer` entry of `.mcp.json` is package-managed; other servers you
#' configure there are left alone.
#'
#' After running this function, start your AI coding agent
#' (e.g. `claude`, `codex`, `copilot` or `gemini`) from a terminal in the
#' project directory - the RStudio or Positron Terminal pane, or any other
#' terminal - and it will immediately have the mizer context it needs.
#'
#' Nothing here is tied to a particular editor. The files are read by agents
#' running in a terminal, and the session connection is a socket, so a project
#' set up this way works the same from RStudio, Positron, a bare R console, ESS
#' or the VS Code R extension. The one exception is the agent's ability to read
#' the document you have open, which needs `rstudioapi` and so works only in
#' RStudio and Positron; everything else does not.
#'
#' @param path Directory in which to create or update the agent files. Defaults
#'   to the current working directory, which should be your R project root.
#' @param overwrite If `TRUE`, replace existing `AGENTS.md`, `CLAUDE.md` and
#'   `GEMINI.md` files entirely with what a fresh setup would write, discarding
#'   your project notes: the block for `AGENTS.md` and a bare `@AGENTS.md`
#'   import for the other two. If `FALSE` (the default), keep the rest of each
#'   file and only refresh the marked mizer block, adding it at the top if it is
#'   not there yet. `MIZER-AGENTS.md` is always overwritten to ensure it stays
#'   up-to-date.
#' @param r_session If `TRUE` (the default), configure the `r-mizer` MCP server
#'   so that the agent can read mizer's documentation, your global environment
#'   and, in RStudio or Positron, the open document. Set to `FALSE` to write no
#'   MCP config at all.
#' @param agents Which agents to configure the server for. By default all of
#'   them, since the config files are small, sit in different places and do not
#'   interfere with each other, so a project set up on your machine works for a
#'   collaborator using a different agent. Any of:
#'
#'   | Value | File written |
#'   | --- | --- |
#'   | `"claude"` | `.mcp.json` |
#'   | `"codex"` | `.codex/config.toml` |
#'   | `"gemini"` | `.gemini/settings.json` |
#'   | `"antigravity"` | `.agents/mcp_config.json` |
#'   | `"cursor"` | `.cursor/mcp.json` |
#'   | `"vscode"` | `.vscode/mcp.json` |
#'   | `"posit"` | `.posit/assistant/settings.json` |
#'   | `"copilot"` | *(none; instructions printed)* |
#'
#'   `"posit"` covers Posit Assistant, which runs in RStudio as well as
#'   Positron. Copilot CLI reads MCP config only from the user-wide
#'   `~/.copilot/mcp-config.json`, so nothing is written for it; you get the
#'   snippet to paste there instead. Ignored when `r_session = FALSE`.
#' @param run_r If `TRUE` (the default), let the agent *evaluate* R code in your
#'   session, which is what allows it to project or calibrate a model and see
#'   the resulting plots. The code runs in your global environment with no
#'   sandboxing, so the agent can overwrite your objects; work under version
#'   control, or set this to `FALSE` for a read-only connection. Ignored when
#'   `r_session = FALSE`.
#' @param pkg_dev If `TRUE`, also expose btw's package development tools
#'   (`load_all()`, `document()`, `test()`, `check()` and test coverage), which
#'   run against the package in your session's working directory. Set this when
#'   the project is itself an R package, such as a mizer extension. `FALSE` by
#'   default, since these tools do nothing useful in an ordinary modelling
#'   project. Ignored when `r_session = FALSE`.
#' @param rprofile If `TRUE`, append a guarded `btw::btw_mcp_session()` call to
#'   the project `.Rprofile`, so that each new session hands itself to the MCP
#'   server automatically. `FALSE` by default, in which case you call
#'   [connect_mizer_agent()] yourself. The `.Rprofile` calls btw directly rather
#'   than going through this package, so that a project still starts cleanly
#'   without mizerAgents installed. R reads a project `.Rprofile` only when it
#'   starts in that directory, which RStudio and Positron guarantee for a
#'   project and starting R from a shell does not, so from a terminal either
#'   start R in the project root or call [connect_mizer_agent()] yourself.
#'   Ignored when `r_session = FALSE`.
#'
#' @return Invisibly returns the path to the `AGENTS.md` file.
#' @export
#'
#' @seealso [connect_mizer_agent()] to hand your session to the server this
#'   configures, [update_mizer_agent()], which refreshes the files a project
#'   already has while keeping the settings it was set up with, and
#'   [remove_mizer_agent()], which undoes all of this.
#'
#' @examples
#' \dontrun{
#' # Run once in your mizer project to set up AI agent support
#' setup_mizer_agent()
#'
#' # In a mizer extension package, add the package development tools and
#' # connect the session automatically on startup
#' setup_mizer_agent(pkg_dev = TRUE, rprofile = TRUE)
#'
#' # A read-only connection: documentation and inspection, but no execution
#' setup_mizer_agent(run_r = FALSE)
#' }
setup_mizer_agent <- function(path = ".", overwrite = FALSE,
                              r_session = TRUE, run_r = TRUE,
                              pkg_dev = FALSE, rprofile = FALSE,
                              agents = .agent_choices) {
    agents <- match.arg(agents, .agent_choices, several.ok = TRUE)
    # How the project is set up now, read before we change it, so that the
    # summary can say which settings this run is re-declaring. The arguments
    # here describe the setup the user wants and default to the ones for a new
    # project, so a re-run meant as a refresh can turn a setting back over
    # without meaning to; `update_mizer_agent()` is the way to avoid that.
    before <- .detect_options(path)
    mizer_src     <- system.file("MIZER-AGENTS.md", package = "mizerAgents")
    llms_src      <- .llms_source()
    skills_src    <- .skills_source()
    mizer_dest    <- normalizePath(file.path(path, "MIZER-AGENTS.md"), mustWork = FALSE)
    agents_dest   <- normalizePath(file.path(path, "AGENTS.md"),       mustWork = FALSE)

    # The card is the static prose plus three generated sections, substituted
    # into the placeholders it carries rather than appended, so that the card
    # decides where each one goes. `.fill_card_section()` explains why that
    # matters; the section builders are just above it.
    card <- readLines(mizer_src, warn = FALSE)
    card <- .fill_card_section(card, "skills", .skills_index_section(skills_src))
    card <- .fill_card_section(
        card, "r-session",
        if (isTRUE(r_session)) .r_session_section(run_r, pkg_dev) else "")
    card <- .fill_card_section(card, "function-lookup",
                               .function_lookup_section(llms_src, r_session))

    # Always write/overwrite the package-managed MIZER-AGENTS.md file
    writeLines(card, mizer_dest)
    message("Created ", mizer_dest)

    # Handle the instruction files. Unlike MIZER-AGENTS.md these belong to the
    # user, so only the marked block is package-managed: it is refreshed in
    # place on every run, wherever in the file it sits, and the rest is left
    # untouched. `CLAUDE.md` and `GEMINI.md` are created as a bare `@AGENTS.md`
    # import when the project has none, so that an agent reading only its own
    # named file still finds the block without the project having to maintain
    # three copies of its instructions.
    shim <- c(.shim_begin, .shim_note, .shim_end)
    for (f in .instruction_files) {
        .write_instruction_file(
            normalizePath(file.path(path, f), mustWork = FALSE),
            shim, overwrite,
            defers_to = if (f != "AGENTS.md") "@AGENTS.md"
        )
    }

    # Deploy the bundled Claude skills into `.claude/skills/`. Each skill is a
    # sub-directory containing a `SKILL.md` file. These are package-managed, so
    # they are refreshed (like `MIZER-AGENTS.md`) to stay up to date - but only
    # file by file, and only where nothing has edited them here.
    kept <- character(0)
    if (nzchar(skills_src) && dir.exists(skills_src)) {
        kept <- .install_skills(skills_src, path)
    } else {
        message("No skills installed: the installed mizer does not ship them.\n",
                "  They arrived in mizer 3.2.2; upgrade mizer and re-run to ",
                "get them.")
    }

    # Configure the MCP server that connects the agent to the user's R session,
    # in each agent's own project-level config format. Like the block in
    # `AGENTS.md`, only our own entry is managed; anything else in those files
    # belongs to the user.
    if (isTRUE(r_session)) {
        written <- .write_agent_configs(path, agents, run_r, pkg_dev)
        for (i in seq_along(written)) {
            message("Configured the ", .mcp_server_name, " MCP server for ",
                    names(written)[i], " in ", written[i])
        }
        if (isTRUE(rprofile)) {
            rprofile_dest <- normalizePath(file.path(path, ".Rprofile"),
                                           mustWork = FALSE)
            if (.write_rprofile(rprofile_dest)) {
                message("Added btw::btw_mcp_session() to ", rprofile_dest)
            }
        }
    }

    message(
        "\nMizer API documentation for AI agents:",
        "\n  API index: ", llms_src,
        if (nzchar(skills_src) && dir.exists(skills_src)) {
            "\n  Skills:    .claude/skills/ (loaded automatically by Claude Code)"
        } else "",
        if (length(kept)) {
            paste0(
                "\n\nThese skill files have been edited in this project, so they",
                "\nwere kept and the new version of each was written beside it:\n  ",
                paste(paste0(kept, "  ->  ", basename(kept), ".new"),
                      collapse = "\n  "),
                "\nMerge what you want to keep, then delete the .new file.",
                "\nNotes that belong to this project are better kept in the",
                "\nskill's NOTES.md, which is never overwritten."
            )
        } else "",
        if (isTRUE(r_session)) {
            paste0(.r_session_message(run_r, rprofile, pkg_dev, agents),
                   if ("copilot" %in% agents) .copilot_snippet(run_r, pkg_dev))
        } else "",
        .setting_changes(before, r_session, run_r, pkg_dev, agents),
        "\n\nStart your AI coding agent from the terminal, e.g.:\n",
        "  claude    (Claude Code)\n",
        "  codex     (Codex CLI)\n",
        "  gemini    (Gemini CLI)\n",
        "  agy       (Antigravity CLI)\n",
        "  copilot   (GitHub Copilot CLI)"
    )

    invisible(agents_dest)
}
