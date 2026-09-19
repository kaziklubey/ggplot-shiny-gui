# ============================================================
# Graph plot-type contract
# ============================================================
# Plot-type metadata belongs here rather than being repeated across UI,
# restore, mapping, and state code.  Builders still live in graph_plot_runtime.R;
# this file only defines stable capabilities and compatibility rules.

graph_plot_type_specs <- function() {
  list(
    line = list(
      id = "line", label = "折れ線",
      mappings = c("x", "y", "position", "color", "linetype", "shape", "id", "facet"),
      summary = TRUE, raw_overlay = TRUE, id_connect = TRUE
    ),
    bar = list(
      id = "bar", label = "棒",
      mappings = c("x", "y", "position", "color", "shape", "id", "facet"),
      summary = TRUE, raw_overlay = TRUE, id_connect = TRUE
    ),
    scatter = list(
      id = "scatter", label = "散布図",
      mappings = c("x", "y", "color", "linetype", "shape", "id", "facet"),
      summary = FALSE, raw_overlay = FALSE, id_connect = FALSE
    ),
    box = list(
      id = "box", label = "箱ひげ",
      mappings = c("x", "y", "position", "color", "shape", "id", "facet"),
      summary = FALSE, raw_overlay = TRUE, id_connect = FALSE
    )
  )
}

graph_plot_type_ids <- function() {
  names(graph_plot_type_specs())
}

graph_plot_type_choices <- function() {
  specs <- graph_plot_type_specs()
  ids <- vapply(specs, function(x) x$id, character(1))
  labels <- vapply(specs, function(x) x$label, character(1))
  stats::setNames(ids, labels)
}

graph_plot_type_normalize <- function(x, fallback = "line") {
  z <- as.character(x %||% fallback)[1]
  if (!length(z) || is.na(z) || !nzchar(z)) z <- fallback
  # Historical compatibility: old projects used "violin" for the box path.
  if (identical(z, "violin")) z <- "box"
  if (!z %in% graph_plot_type_ids()) z <- as.character(fallback %||% "line")[1]
  if (is.na(z) || !nzchar(z) || !z %in% graph_plot_type_ids()) z <- "line"
  z
}

graph_plot_type_spec <- function(x) {
  graph_plot_type_specs()[[graph_plot_type_normalize(x)]]
}

graph_plot_supports_mapping <- function(plot_type, mapping) {
  mapping %in% (graph_plot_type_spec(plot_type)$mappings %||% character(0))
}

graph_plot_restore_input_ids <- function(plot_type) {
  ids <- c("xvar", "yvar", "colorvar", "shapevar", "idvar", "facetvar")
  if (graph_plot_supports_mapping(plot_type, "position")) ids <- c(ids, "groupvar")
  if (graph_plot_supports_mapping(plot_type, "linetype")) ids <- c(ids, "linetypevar")
  unique(ids)
}
