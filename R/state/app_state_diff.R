# ============================================================
# Canonical state diff helpers
# ============================================================
# Pure helpers used only for diagnostics/contracts.  They do not mutate Shiny
# state and are safe to call from Graph/Figure transaction boundaries.

app_state_diff_paths <- function(old, new, prefix = "", max_depth = 32L) {
  max_depth <- suppressWarnings(as.integer(max_depth)[1])
  if (!is.finite(max_depth) || max_depth < 1L) max_depth <- 32L

  walk <- function(a, b, path, depth) {
    if (identical(a, b)) return(character(0))
    if (depth >= max_depth) return(if (nzchar(path)) path else "<root>")

    a_list <- is.list(a)
    b_list <- is.list(b)
    if (!(a_list && b_list)) return(if (nzchar(path)) path else "<root>")

    aa <- attributes(a) %||% list()
    ba <- attributes(b) %||% list()
    aa$names <- NULL
    ba$names <- NULL
    if (!identical(aa, ba)) {
      return(if (nzchar(path)) paste0(path, ".<attributes>") else "<attributes>")
    }

    an <- names(a) %||% character(0)
    bn <- names(b) %||% character(0)
    # Unnamed lists are treated as one leaf.  State collections whose element
    # identity matters should use names; recursing by numeric position would
    # produce noisy diagnostics for recipes/style vectors.
    if (!length(an) && !length(bn)) return(if (nzchar(path)) path else "<root>")

    keys <- unique(c(an, bn))
    out <- character(0)
    for (nm in keys) {
      child <- if (nzchar(path)) paste0(path, ".", nm) else nm
      in_a <- nm %in% an
      in_b <- nm %in% bn
      if (!in_a || !in_b) {
        out <- c(out, child)
      } else {
        out <- c(out, walk(a[[nm]], b[[nm]], child, depth + 1L))
      }
    }
    unique(out)
  }

  walk(old, new, as.character(prefix %||% "")[1], 0L)
}

# Canonical GraphState uses named plain lists as records. Their field order is
# representation-only, but atomic values, unnamed collections, classes and
# non-name attributes remain strict. Keep that rule in one place so Registry
# and RenderState do not create revisions solely because two record fields were
# assembled in a different order.
app_state_semantically_equal <- function(old, new) {
  walk_equal <- function(a, b) {
    if (identical(a, b)) return(TRUE)
    if (!(is.list(a) && is.list(b))) return(FALSE)

    aa <- attributes(a) %||% list()
    ba <- attributes(b) %||% list()
    aa$names <- NULL
    ba$names <- NULL
    if (!identical(aa, ba)) return(FALSE)

    an <- names(a) %||% character(0)
    bn <- names(b) %||% character(0)
    if (!length(an) || !length(bn)) return(FALSE)
    if (anyDuplicated(an) || anyDuplicated(bn)) return(FALSE)
    if (!setequal(an, bn)) return(FALSE)

    all(vapply(an, function(nm) walk_equal(a[[nm]], b[[nm]]), logical(1)))
  }

  walk_equal(old, new)
}

app_state_diff_summary <- function(old, new, max_paths = 24L) {
  paths <- app_state_diff_paths(old, new)
  max_paths <- suppressWarnings(as.integer(max_paths)[1])
  if (!is.finite(max_paths) || max_paths < 1L) max_paths <- 24L
  if (!length(paths)) return("<none>")
  shown <- head(paths, max_paths)
  suffix <- if (length(paths) > length(shown)) paste0(" +", length(paths) - length(shown), " more") else ""
  paste0("{", paste(shown, collapse = ","), "}", suffix)
}
