# v4.0 RC13.8 — browser numeric input semantic contract.
# Shared by Full Editor and Figure Controls; canonical GraphState stays server-owned.

# v4.0 RC13.8: numeric browser edits are normalized by control semantics,
# never by the incidental R storage type of the currently saved value. Older
# Projects can contain whole-number values as integer (for example bar_width =
# 1L); a continuous control must still preserve a later 0.9/0.7 edit as double.
graph_input_integer_numeric_keys <- function() {
  c(
    "base_size", "mean_shape", "raw_shape",
    "bar_border_dash", "bar_border_gap",
    "plot_width_px", "plot_width_px_direct",
    "plot_height_px", "plot_height_px_direct",
    "legend_colour_order", "legend_fill_order",
    "legend_linetype_order", "legend_shape_order",
    "legend_wrap_count"
  )
}

graph_normalize_browser_input_value <- function(key, value, previous = NULL) {
  key <- as.character(key %||% "")[[1]]
  defaults <- graph_snapshot_input_defaults()
  default <- if (nzchar(key) && key %in% names(defaults)) defaults[[key]] else NULL
  template <- if (!is.null(default)) default else previous

  if (is.logical(template)) {
    return(list(ok = TRUE, value = isTRUE(value), kind = "logical"))
  }

  if (key %in% graph_input_integer_numeric_keys()) {
    z <- suppressWarnings(as.integer(value %||% NA_integer_)[[1]])
    if (!is.finite(z)) return(list(ok = FALSE, value = NULL, kind = "integer"))
    return(list(ok = TRUE, value = z, kind = "integer"))
  }

  # A numeric default declares a continuous numeric control even when a legacy
  # Project happened to serialize its current whole-number value as integer.
  if (is.numeric(template) || is.numeric(previous)) {
    z <- suppressWarnings(as.numeric(value %||% NA_real_)[[1]])
    if (!is.finite(z)) return(list(ok = FALSE, value = NULL, kind = "numeric"))
    return(list(ok = TRUE, value = z, kind = "numeric"))
  }

  list(ok = TRUE, value = as.character(value %||% "")[[1]], kind = "character")
}
