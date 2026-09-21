# Bootstrap helpers used before the Shiny app and its dependencies are loaded.
# Keep package-install policy isolated from the Graph/Figure runtime.

ggplot_gui_r_minor_version <- function() {
  minor <- strsplit(as.character(R.version$minor), ".", fixed = TRUE)[[1L]][1L]
  paste(as.character(R.version$major), minor, sep = ".")
}

ggplot_gui_normalize_library_path <- function(path) {
  if (is.null(path) || !length(path)) return("")
  path <- trimws(as.character(path[[1L]]))
  if (!length(path) || !nzchar(path[[1L]])) return("")
  normalizePath(path.expand(path[[1L]]), winslash = "/", mustWork = FALSE)
}

ggplot_gui_user_library_candidates <- function() {
  configured <- Sys.getenv("R_LIBS_USER", unset = "")
  configured <- if (nzchar(configured)) {
    strsplit(configured, .Platform$path.sep, fixed = TRUE)[[1L]]
  } else {
    character()
  }
  configured <- trimws(configured)
  configured <- configured[nzchar(configured)]

  version_dir <- ggplot_gui_r_minor_version()
  fallback <- if (.Platform$OS.type == "windows") {
    base_dir <- Sys.getenv("LOCALAPPDATA", unset = "")
    if (!nzchar(base_dir)) base_dir <- path.expand("~")
    platform_dir <- if (grepl("aarch64|arm64", R.version$platform, ignore.case = TRUE)) {
      "aarch64-library"
    } else {
      "win-library"
    }
    file.path(base_dir, "R", platform_dir, version_dir)
  } else {
    file.path(path.expand("~"), "R", paste0("library-", version_dir))
  }

  candidates <- unique(c(configured, fallback))
  candidates <- vapply(candidates, ggplot_gui_normalize_library_path, character(1L))
  unique(candidates[nzchar(candidates)])
}

ggplot_gui_library_is_writable <- function(path, create = FALSE) {
  path <- ggplot_gui_normalize_library_path(path)
  if (!nzchar(path)) return(FALSE)

  if (!dir.exists(path) && isTRUE(create)) {
    suppressWarnings(dir.create(path, recursive = TRUE, showWarnings = FALSE))
  }
  if (!dir.exists(path)) return(FALSE)

  probe <- tempfile(pattern = ".ggplot_gui_write_probe_", tmpdir = path)
  ok <- suppressWarnings(file.create(probe))
  if (isTRUE(ok)) suppressWarnings(unlink(probe, force = TRUE))
  isTRUE(ok)
}

ggplot_gui_resolve_install_library <- function() {
  current <- unique(vapply(.libPaths(), ggplot_gui_normalize_library_path, character(1L)))
  current <- current[nzchar(current)]

  for (path in current) {
    if (ggplot_gui_library_is_writable(path, create = FALSE)) return(path)
  }

  for (path in ggplot_gui_user_library_candidates()) {
    if (!ggplot_gui_library_is_writable(path, create = TRUE)) next
    .libPaths(unique(c(path, .libPaths())))
    return(path)
  }

  stop(
    paste0(
      "No writable R package library is available.\n",
      "Current libraries: ", paste(.libPaths(), collapse = "; "), "\n",
      "R_LIBS_USER: ", Sys.getenv("R_LIBS_USER", unset = "<unset>")
    ),
    call. = FALSE
  )
}

ensure_package <- function(pkg, lib_path = NULL) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    if (is.null(lib_path) || !length(lib_path) || !nzchar(lib_path[[1L]])) {
      lib_path <- ggplot_gui_resolve_install_library()
    }

    message(sprintf("Installing missing package '%s' into: %s", pkg, lib_path))
    tryCatch(
      install.packages(
        pkg,
        lib = lib_path,
        repos = "https://cloud.r-project.org/",
        type = if (.Platform$OS.type == "windows") "binary" else getOption("pkgType")
      ),
      error = function(e) {
        stop(
          sprintf("Failed to install package '%s' into '%s': %s", pkg, lib_path, conditionMessage(e)),
          call. = FALSE
        )
      }
    )
  }

  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf("Package '%s' is still unavailable after installation attempt.", pkg),
      call. = FALSE
    )
  }

  suppressPackageStartupMessages(library(pkg, character.only = TRUE))
}
