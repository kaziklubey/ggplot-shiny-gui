# ============================================================
# Graph plot-type contract
# ============================================================
# Plot-type metadata belongs here rather than being repeated across UI,
# mapping and state code. Builders still live in R/plot/runtime/graph_plot_runtime.R;
# this file only defines stable capabilities shared by those callers.

graph_plot_type_specs <- function() {
  list(
    line = list(
      id = "line", label = "折れ線",
      mappings = c("x", "y", "position", "color", "linetype", "shape", "id", "facet"),
      primary_aesthetic = "colour", position_mode = "line_dodge",
      summary = TRUE, raw_overlay = TRUE, id_connect = TRUE
    ),
    bar = list(
      id = "bar", label = "棒",
      mappings = c("x", "y", "position", "color", "shape", "id", "facet"),
      primary_aesthetic = "fill", position_mode = "stable_slot",
      bar_layouts = c("side_by_side", "stacked", "percent"),
      bar_value_sources = c("numeric_y", "count"),
      bar_proportion_displays = c("percent", "ratio"),
      summary = TRUE, raw_overlay = TRUE, id_connect = TRUE
    ),
    scatter = list(
      id = "scatter", label = "散布図",
      mappings = c("x", "y", "color", "linetype", "shape", "id", "facet"),
      primary_aesthetic = "colour", position_mode = "none",
      summary = FALSE, raw_overlay = FALSE, id_connect = FALSE
    ),
    box = list(
      id = "box", label = "箱ひげ",
      mappings = c("x", "y", "position", "color", "shape", "id", "facet"),
      primary_aesthetic = "fill", position_mode = "stable_slot",
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

graph_plot_primary_aesthetic <- function(plot_type) {
  z <- as.character(graph_plot_type_spec(plot_type)$primary_aesthetic %||% "colour")[1]
  if (!z %in% c("colour", "fill")) z <- "colour"
  z
}

graph_plot_uses_fill <- function(plot_type) {
  identical(graph_plot_primary_aesthetic(plot_type), "fill")
}

graph_plot_position_mode <- function(plot_type) {
  z <- as.character(graph_plot_type_spec(plot_type)$position_mode %||% "none")[1]
  if (!z %in% c("none", "line_dodge", "stable_slot")) z <- "none"
  z
}

graph_plot_supports_position <- function(plot_type) {
  !identical(graph_plot_position_mode(plot_type), "none")
}

graph_plot_uses_stable_slot <- function(plot_type) {
  identical(graph_plot_position_mode(plot_type), "stable_slot")
}

graph_plot_supports_raw_overlay <- function(plot_type) {
  isTRUE(graph_plot_type_spec(plot_type)$raw_overlay)
}

graph_plot_bar_layouts <- function(plot_type = "bar") {
  out <- graph_plot_type_spec(plot_type)$bar_layouts %||% character(0)
  unique(as.character(out[nzchar(as.character(out))]))
}

graph_plot_bar_layout_normalize <- function(x, fallback = "side_by_side") {
  allowed <- graph_plot_bar_layouts("bar")
  z <- as.character(x %||% fallback)[1]
  if (!length(z) || is.na(z) || !nzchar(z) || !z %in% allowed) z <- fallback
  if (is.na(z) || !nzchar(z) || !z %in% allowed) z <- "side_by_side"
  z
}

graph_plot_bar_layout_is_stacked <- function(x) {
  graph_plot_bar_layout_normalize(x) %in% c("stacked", "percent")
}

graph_plot_bar_layout_is_percent <- function(x) {
  identical(graph_plot_bar_layout_normalize(x), "percent")
}

graph_plot_bar_value_sources <- function(plot_type = "bar") {
  out <- graph_plot_type_spec(plot_type)$bar_value_sources %||% character(0)
  unique(as.character(out[nzchar(as.character(out))]))
}

graph_plot_bar_value_source_normalize <- function(x, fallback = "numeric_y") {
  allowed <- graph_plot_bar_value_sources("bar")
  z <- as.character(x %||% fallback)[1]
  if (!length(z) || is.na(z) || !nzchar(z) || !z %in% allowed) z <- fallback
  if (is.na(z) || !nzchar(z) || !z %in% allowed) z <- "numeric_y"
  z
}

graph_plot_bar_value_source_is_count <- function(x) {
  identical(graph_plot_bar_value_source_normalize(x), "count")
}

graph_plot_bar_proportion_displays <- function(plot_type = "bar") {
  out <- graph_plot_type_spec(plot_type)$bar_proportion_displays %||% character(0)
  unique(as.character(out[nzchar(as.character(out))]))
}

graph_plot_bar_proportion_display_normalize <- function(x, fallback = "percent") {
  allowed <- graph_plot_bar_proportion_displays("bar")
  z <- as.character(x %||% fallback)[1]
  if (!length(z) || is.na(z) || !nzchar(z) || !z %in% allowed) z <- fallback
  if (is.na(z) || !nzchar(z) || !z %in% allowed) z <- "percent"
  z
}

graph_plot_bar_proportion_display_is_ratio <- function(x) {
  identical(graph_plot_bar_proportion_display_normalize(x), "ratio")
}

graph_plot_requires_y <- function(plot_type, bar_value_source = "numeric_y") {
  !identical(graph_plot_type_normalize(plot_type), "bar") ||
    !graph_plot_bar_value_source_is_count(bar_value_source)
}
