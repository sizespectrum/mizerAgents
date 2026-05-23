#' Set up an AI agent to help with your mizer project
#'
#' Creates (or updates) a `MIZER-AGENTS.md` file in your project directory
#' containing a concise mizer reference that AI coding agents read
#' automatically on startup. The file includes the core mizer workflow,
#' key object descriptions, and the path to the full mizer API documentation
#' bundled with the package.
#'
#' It also creates (or updates) an `AGENTS.md` file with a `@MIZER-AGENTS.md`
#' shim so that agents read both the project-specific instructions and the mizer
#' reference. It also creates `CLAUDE.md` and `GEMINI.md` shim files (each
#' containing just `@AGENTS.md`) so that agent-specific tools that look for
#' their own named file also pick up the shared context. These shims are only
#' created if the files do not already exist.
#'
#' After running this function, start your AI coding agent
#' (e.g. `claude`, `codex`, `copilot` or `gemini`) from the RStudio Terminal
#' and it will immediately have the mizer context it needs.
#'
#' @param path Directory in which to create or update the agent files. Defaults
#'   to the current working directory, which should be your R project root.
#' @param overwrite If `TRUE`, replace an existing `AGENTS.md` entirely with a
#'   clean shim. If `FALSE` (the default), preserve any custom content in
#'   `AGENTS.md` while prepending the `@MIZER-AGENTS.md` shim if not already
#'   present. `MIZER-AGENTS.md` is always overwritten to ensure it stays
#'   up-to-date.
#'
#' @return Invisibly returns the path to the `AGENTS.md` file.
#' @export
#'
#' @examples
#' \dontrun{
#' # Run once in your mizer project to set up AI agent support
#' setup_mizer_agent()
#' }
setup_mizer_agent <- function(path = ".", overwrite = FALSE) {
    agents_src    <- system.file("AGENTS.md",     package = "mizerAgents")
    llms_src      <- system.file("llms.txt",      package = "mizerAgents")
    llms_full_src <- system.file("llms-full.txt", package = "mizerAgents")
    mizer_dest    <- normalizePath(file.path(path, "MIZER-AGENTS.md"), mustWork = FALSE)
    agents_dest   <- normalizePath(file.path(path, "AGENTS.md"),       mustWork = FALSE)

    mizer_section <- paste(readLines(agents_src, warn = FALSE), collapse = "\n")

    # Append local paths to both documentation files
    mizer_section <- paste0(
        mizer_section,
        "\n\n## API documentation (local copies)\n\n",
        "Concise overview of the mizer API (start here):\n",
        llms_src, "\n\n",
        if (nzchar(llms_full_src)) {
            paste0(
                "Full API documentation with complete details on every function:\n",
                llms_full_src, "\n",
                "Grep or search this file for specific function names - do not read the whole file.\n"
            )
        } else {
            "Full API documentation: see https://sizespectrum.org/mizer/reference/\n"
        }
    )

    # Always write/overwrite the package-managed MIZER-AGENTS.md file
    writeLines(mizer_section, mizer_dest)
    message("Created ", mizer_dest)

    # Handle AGENTS.md
    if (file.exists(agents_dest) && !overwrite) {
        existing <- readLines(agents_dest, warn = FALSE)
        # Prepend the @MIZER-AGENTS.md shim if not already present
        if (!any(grepl("MIZER-AGENTS.md", existing, fixed = TRUE))) {
            writeLines(c("@MIZER-AGENTS.md", existing), agents_dest)
            message("Prepended @MIZER-AGENTS.md shim to existing ", agents_dest)
        }
    } else {
        writeLines("@MIZER-AGENTS.md", agents_dest)
        message("Created ", agents_dest, " with shim pointing to MIZER-AGENTS.md")
    }

    # Create agent-specific shim files that forward to AGENTS.md.
    # Only written if the file does not already exist (may contain custom content).
    shims <- c("CLAUDE.md", "GEMINI.md")
    for (shim in shims) {
        shim_dest <- normalizePath(file.path(path, shim), mustWork = FALSE)
        if (!file.exists(shim_dest)) {
            writeLines("@AGENTS.md", shim_dest)
            message("Created ", shim_dest)
        }
    }

    message(
        "\nMizer API documentation for AI agents:",
        "\n  Overview:  ", llms_src,
        if (nzchar(llms_full_src)) paste0("\n  Full docs: ", llms_full_src) else "",
        "\n\nStart your AI coding agent from the terminal, e.g.:\n",
        "  claude    (Claude Code)\n",
        "  codex     (Codex CLI)\n",
        "  gemini    (Gemini CLI)\n",
        "  agy       (Antigravity CLI)\n",
        "  copilot   (GitHub Copilot CLI)"
    )

    invisible(agents_dest)
}
