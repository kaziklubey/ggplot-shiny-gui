# R/export/export_text_normalization.R — export-only text compatibility normalization
#
# Canonical GraphState/FigureState and on-screen text remain byte-for-byte as
# entered by the user. Only external editable/vector export payloads are
# normalized here. RC13.3 intentionally starts with one confirmed compatibility
# substitution: U+FF05 FULLWIDTH PERCENT SIGN -> ASCII percent.

export_text_normalization_tokens <- function() {
  # XML serializers may preserve the Unicode character literally or emit a
  # numeric character reference. All tokens below represent the same U+FF05.
  c("\uFF05", "&#xFF05;", "&#xff05;", "&#65285;")
}

export_text_normalize_character <- function(x) {
  if (!is.character(x) || !length(x)) return(x)
  out <- x
  for (token in export_text_normalization_tokens()) {
    out <- gsub(token, "%", out, fixed = TRUE)
  }
  out
}

export_text_normalization_count <- function(x) {
  if (!is.character(x) || !length(x)) return(0L)
  count_one <- function(token) {
    hits <- gregexpr(token, x, fixed = TRUE)
    sum(vapply(hits, function(z) {
      if (length(z) == 1L && identical(z[[1]], -1L)) 0L else length(z)
    }, integer(1)))
  }
  as.integer(sum(vapply(export_text_normalization_tokens(), count_one, numeric(1))))
}

export_text_normalize_utf8_file <- function(path) {
  path <- as.character(path %||% "")[1]
  if (!nzchar(path) || !file.exists(path)) {
    return(list(ok = FALSE, replacements = 0L, path = path))
  }

  lines <- tryCatch(
    readLines(path, warn = FALSE, encoding = "UTF-8"),
    error = function(e) NULL
  )
  if (is.null(lines)) return(list(ok = FALSE, replacements = 0L, path = path))

  n <- export_text_normalization_count(lines)
  if (n > 0L) {
    writeLines(export_text_normalize_character(lines), path, useBytes = TRUE)
  }
  list(ok = TRUE, replacements = as.integer(n), path = path)
}

export_text_normalize_xml_tree <- function(root) {
  root <- as.character(root %||% "")[1]
  if (!nzchar(root) || !dir.exists(root)) {
    return(list(files = 0L, replacements = 0L))
  }
  files <- list.files(root, pattern = "\\.xml$", recursive = TRUE, full.names = TRUE)
  if (!length(files)) return(list(files = 0L, replacements = 0L))

  changed_files <- 0L
  replacements <- 0L
  for (path in files) {
    ans <- export_text_normalize_utf8_file(path)
    if (isTRUE(ans$ok) && is.finite(ans$replacements) && ans$replacements > 0L) {
      changed_files <- changed_files + 1L
      replacements <- replacements + as.integer(ans$replacements)
    }
  }
  list(files = as.integer(changed_files), replacements = as.integer(replacements))
}
