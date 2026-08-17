# Undoing what `setup_mizer_agent()` did.
#
# The rule here is the mirror of the one setup follows: this package removes
# what this package wrote, and nothing else. Everything setup touches is either
# a whole file that only it writes (`MIZER-AGENTS.md`, the skills it installed),
# a marked block inside a file that belongs to the user (`AGENTS.md`,
# `.codex/config.toml`), or a single named entry in a config file that may hold
# entries of the user's own (`.mcp.json` and friends). Each of those comes out
# again on its own terms, and a file that is left holding nothing but our
# leavings is deleted rather than left behind empty.
#
# Two things are deliberately *not* removed: a skill file that has been edited
# in the project, which is no longer ours to delete, and any `NOTES.md`, which
# this package never wrote in the first place. Both are reported instead.

# Drop a marked block from a character vector, returning it unchanged if there
# is no block to drop. Internal helper.
.strip_block <- function(lines, begin, end) {
    b <- which(lines == begin)
    e <- which(lines == end)
    if (length(b) && length(e) && e[1] > b[1]) {
        return(c(lines[seq_len(b[1] - 1)], lines[-seq_len(e[1])]))
    }
    lines
}

# Blank lines at the start or end of a file are usually the separator setup
# inserted between its block and the user's own content, so they go with the
# block. Internal helper.
.trim_blank_edges <- function(lines) {
    keep <- which(nzchar(trimws(lines)))
    if (!length(keep)) return(character(0))
    lines[seq(keep[1], keep[length(keep)])]
}

# Write `lines` back to `dest`, or delete `dest` when the block was all it held.
# Returns the path if anything changed, otherwise `character(0)`. Internal
# helper.
.rewrite_or_remove <- function(dest, lines, original) {
    if (identical(lines, original)) return(character(0))
    if (!length(lines)) {
        unlink(dest)
        message("Removed ", dest)
    } else {
        writeLines(lines, dest)
        message("Removed the mizerAgents block from ", dest)
    }
    dest
}

# Remove `dir` if it holds nothing, then each of its parents for the same
# reason, stopping before `stop_at` so that the project directory itself is
# never a candidate. Internal helper.
.remove_empty_dirs <- function(dir, stop_at) {
    dir <- normalizePath(dir, mustWork = FALSE)
    stop_at <- normalizePath(stop_at, mustWork = FALSE)
    while (!identical(dir, stop_at) && dir.exists(dir) &&
           length(list.files(dir, all.files = TRUE, no.. = TRUE)) == 0) {
        unlink(dir, recursive = TRUE)
        dir <- dirname(dir)
    }
    invisible(NULL)
}

# Take the package-managed block out of one instruction file. The bare
# `@MIZER-AGENTS.md` import that versions before the markers wrote is removed
# too, since setup would have adopted and rewritten it. The one-line
# `@AGENTS.md` shims that 0.3.2 and earlier put in `CLAUDE.md` and `GEMINI.md`
# are left alone for the same reason setup leaves them alone: which of a
# project's instruction files import which is the user's business.
# Internal helper.
.clean_instruction_file <- function(dest) {
    if (!file.exists(dest)) return(character(0))
    existing <- readLines(dest, warn = FALSE)
    updated <- .strip_block(existing, .shim_begin, .shim_end)
    if (identical(updated, existing)) {
        at <- which(updated == "@MIZER-AGENTS.md")
        if (!length(at)) return(character(0))
        updated <- updated[-at[1]]
    }
    .rewrite_or_remove(dest, .trim_blank_edges(updated), existing)
}

# Uninstall the bundled skills from `.claude/skills/`.
#
# What we may delete is what we know we wrote: the manifest records the hash of
# every file installed, and a file still matching its recorded hash is ours. A
# project set up before the manifest existed has no such record, so fall back to
# the hashes the current bundle *would* have written - which identifies the
# files of a project that has simply never edited them, and errs towards keeping
# a file whenever it cannot be sure.
#
# Returns a list with the paths of the files removed, the relative paths of the
# files kept, and whether there was a `.claude/skills/` to work on at all.
# Internal helper.
.remove_skills <- function(path) {
    skills_dest <- normalizePath(file.path(path, ".claude", "skills"),
                                 mustWork = FALSE)
    if (!dir.exists(skills_dest)) {
        return(list(removed = character(0), kept = character(0),
                    found = FALSE))
    }
    manifest_path <- file.path(skills_dest, .skill_manifest)
    recorded <- .read_skill_manifest(manifest_path)
    if (is.null(recorded)) recorded <- .bundled_skill_hashes()

    removed <- character(0)
    removed_rels <- character(0)
    kept <- character(0)
    for (rel in names(recorded)) {
        dest <- file.path(skills_dest, rel)
        # The `.new` sidecar is written by us in its entirety, so it goes
        # whether or not the file beside it does.
        unlink(paste0(dest, ".new"))
        if (!file.exists(dest)) next
        if (identical(.hash_file(dest), unname(recorded[rel]))) {
            unlink(dest)
            removed <- c(removed, dest)
            removed_rels <- c(removed_rels, rel)
        } else {
            kept <- c(kept, rel)
        }
    }
    if (file.exists(manifest_path)) {
        unlink(manifest_path)
        removed <- c(removed, manifest_path)
    }

    for (d in list.dirs(skills_dest, recursive = FALSE)) {
        .remove_empty_dirs(d, skills_dest)
    }
    .remove_empty_dirs(skills_dest, normalizePath(path, mustWork = FALSE))

    for (s in unique(sub("/.*$", "", removed_rels))) {
        message("Removed skill: ", s)
    }
    list(removed = removed, kept = kept, found = TRUE)
}

# The hashes the current bundle would have installed, used only when there is no
# manifest to consult. Empty when the installed mizer ships no skills, in which
# case nothing under `.claude/skills/` can be identified as ours and everything
# there is kept.
#
# Deliberately not filtered through `.skill_payload()`: a project set up by an
# older version still has the files we have since stopped installing, and with
# no manifest this is the only way left to recognise them as ours.
# Internal helper.
.bundled_skill_hashes <- function() {
    src <- .skills_source()
    if (!nzchar(src) || !dir.exists(src)) return(character(0))
    rels <- sort(list.files(src, recursive = TRUE))
    hashes <- vapply(rels, function(rel) {
        content <- readLines(file.path(src, rel), warn = FALSE)
        if (basename(rel) == "SKILL.md") {
            content <- c(.strip_article_only(content), .skill_footer)
        }
        .hash_lines(content)
    }, character(1))
    hashes
}

# Take our server out of a JSON config, leaving any other servers alone and
# deleting the file if ours was the only thing in it. Returns the path if the
# file changed. Internal helper.
.remove_mcp_json <- function(dest, key = "mcpServers") {
    if (!file.exists(dest)) return(character(0))
    cfg <- tryCatch(jsonlite::fromJSON(dest, simplifyVector = FALSE),
                    error = function(e) NULL)
    # Same reasoning as when writing: a file we cannot parse is one whose other
    # contents we cannot preserve, so we do not touch it.
    if (is.null(cfg)) {
        warning("Could not parse ", dest, ", so it was left unchanged. ",
                "Remove the `", .mcp_server_name, "` server by hand.",
                call. = FALSE)
        return(character(0))
    }
    if (!is.list(cfg[[key]]) || is.null(cfg[[key]][[.mcp_server_name]])) {
        return(character(0))
    }
    cfg[[key]][[.mcp_server_name]] <- NULL
    if (length(cfg[[key]]) == 0) cfg[[key]] <- NULL
    if (length(cfg) == 0) {
        unlink(dest)
        message("Removed ", dest)
    } else {
        writeLines(jsonlite::toJSON(cfg, auto_unbox = TRUE, pretty = TRUE),
                   dest)
        message("Removed the ", .mcp_server_name, " MCP server from ", dest)
    }
    dest
}

# The TOML counterpart: a marked block rather than a parsed entry, because that
# is how it was written. Internal helper.
.remove_codex_toml <- function(dest) {
    if (!file.exists(dest)) return(character(0))
    existing <- readLines(dest, warn = FALSE)
    updated <- .trim_blank_edges(.strip_block(existing, .codex_begin,
                                              .codex_end))
    .rewrite_or_remove(dest, updated, existing)
}

# Take the session hook back out of the project `.Rprofile`, with the comment
# that was written above it. Returns the path if the file changed. Internal
# helper.
.remove_rprofile <- function(dest) {
    if (!file.exists(dest)) return(character(0))
    existing <- readLines(dest, warn = FALSE)
    updated <- existing[!existing %in% c(.rprofile_marker, .rprofile_line)]
    .rewrite_or_remove(dest, .trim_blank_edges(updated), existing)
}

#' Undo what `setup_mizer_agent()` did
#'
#' Removes the mizer agent support that [setup_mizer_agent()] installed in a
#' project: the `MIZER-AGENTS.md` reference card, the mizer block in the
#' instruction files, the bundled skills in `.claude/skills/`, the `r-mizer` MCP
#' server in each agent's config, and the `btw::btw_mcp_session()` call in the
#' project `.Rprofile`. Use it when you no longer want the agent support in a
#' project, or to get back to a clean slate before setting it up differently.
#'
#' Only what this package wrote is removed, following the same boundary
#' `setup_mizer_agent()` respects when writing:
#'
#' * `MIZER-AGENTS.md` is deleted. It is package-managed and rewritten on every
#'   setup, so there is nothing of yours in it.
#' * In `AGENTS.md`, `CLAUDE.md` and `GEMINI.md` only the block between the
#'   `<!-- mizerAgents: start -->` and `<!-- mizerAgents: end -->` markers is
#'   deleted; your own notes stay. A file that held nothing but the block is
#'   deleted with it. An `@AGENTS.md` import is never removed, just as it is
#'   never written: which of your instruction files import which is your
#'   business.
#' * Under `.claude/skills/`, a file is removed only if it still matches the
#'   hash recorded in `.claude/skills/.mizerAgents.json` when it was installed.
#'   One that has been edited here is kept and reported, as is any `NOTES.md`,
#'   which this package never writes. Directories left empty are removed. (In a
#'   project set up by version 0.3.2 or earlier there is no record, so files are
#'   identified by comparing them with what the installed mizer's skills would
#'   have produced; anything that does not match is kept.)
#' * In each agent's MCP config only the `r-mizer` entry is removed; other
#'   servers you configured there stay, and the file is deleted only if that
#'   entry was all it held. A config file that cannot be parsed is left alone
#'   with a warning rather than risking your other servers.
#' * In `.Rprofile` only the guarded `btw::btw_mcp_session()` call and its
#'   comment are removed.
#'
#' The `btw` package is not touched: it is an ordinary R package you installed,
#' and other projects may be using it. Uninstall it yourself with
#' `remove.packages("btw")` if you want it gone.
#'
#' @param path Directory to clean up. Defaults to the current working
#'   directory, which should be your R project root.
#'
#' @return Invisibly, a character vector of the paths that were removed or
#'   changed.
#' @export
#'
#' @seealso [setup_mizer_agent()], which this undoes, and
#'   [update_mizer_agent()] if you only want to refresh the files.
#'
#' @examples
#' \dontrun{
#' # Remove the mizer agent support from the current project
#' remove_mizer_agent()
#' }
remove_mizer_agent <- function(path = ".") {
    if (!dir.exists(path)) {
        stop("`path` does not exist: ", path, call. = FALSE)
    }
    changed <- character(0)

    mizer_dest <- normalizePath(file.path(path, "MIZER-AGENTS.md"),
                                mustWork = FALSE)
    if (file.exists(mizer_dest)) {
        unlink(mizer_dest)
        message("Removed ", mizer_dest)
        changed <- c(changed, mizer_dest)
    }

    for (f in .instruction_files) {
        changed <- c(changed, .clean_instruction_file(
            normalizePath(file.path(path, f), mustWork = FALSE)))
    }

    skills <- .remove_skills(path)

    for (agent in names(.agent_configs)) {
        spec <- .agent_configs[[agent]]
        dest <- normalizePath(file.path(path, spec$path), mustWork = FALSE)
        changed <- c(changed, if (identical(agent, "codex")) {
            .remove_codex_toml(dest)
        } else {
            .remove_mcp_json(dest, spec$key)
        })
        .remove_empty_dirs(dirname(dest), normalizePath(path, mustWork = FALSE))
    }

    changed <- c(changed, .remove_rprofile(
        normalizePath(file.path(path, ".Rprofile"), mustWork = FALSE)))

    changed <- c(changed, skills$removed)
    if (!length(changed) && !length(skills$kept)) {
        message("Nothing to remove: no mizerAgents files found in ",
                normalizePath(path, mustWork = FALSE))
        return(invisible(character(0)))
    }

    message(
        "\nRemoved the mizer agent support from ",
        normalizePath(path, mustWork = FALSE), ".",
        if (length(skills$kept)) {
            paste0(
                "\n\nThese skill files have been edited in this project, so they",
                "\nwere kept rather than removed:\n  ",
                paste(skills$kept, collapse = "\n  "),
                "\nDelete them yourself if you do not want them."
            )
        } else "",
        if (isTRUE(skills$found)) {
            paste0(
                "\n\nAnything else under .claude/skills/, such as a NOTES.md",
                "\nrecording what earlier work in this project found, was left",
                "\nwhere it was."
            )
        } else "",
        "\n\nRun setup_mizer_agent() to set the agent support up again."
    )

    invisible(changed)
}
