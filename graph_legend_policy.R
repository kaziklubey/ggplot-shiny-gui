# Keep the group-title legacy/shared-library key backward compatible.
graph_group_legend_key <- function(state) {
  ap <- state$style$appearance %||% list()
  mp <- state$mapping %||% list()
  key <- graph_state_scalar(mp$color, "")
  if (isTRUE(ap$series_style_override) && nzchar(key) &&
      nzchar(graph_state_scalar(mp$position, ""))) {
    key <- paste0("__combo__::", key, "::", graph_state_scalar(mp$position, ""))
  }
  key
}

# Pure legend policy shared by the live and DIRECT-STATE plot builders.
graph_normalize_legend_state <- function(state) {
  if (!is.list(state)) return(state)
  ap <- state$style$appearance %||% list()
  key <- graph_group_legend_key(state)
  if (is.null(ap$legend_group_title)) {
    ap$legend_group_title <- graph_state_scalar(state$style$legend_titles[[key]], graph_state_scalar(state$mapping$color, ""))
  }
  if (is.null(ap$legend_individual_title)) ap$legend_individual_title <- ""
  if (is.null(ap$legend_title_show)) ap$legend_title_show <- FALSE
  if (is.null(ap$legend_individual_title_show)) ap$legend_individual_title_show <- FALSE
  state$style$appearance <- ap
  state
}

graph_legend_policy <- function(input, same_condition) {
  merged <- isTRUE(same_condition) &&
    !identical(input$legend_merge_group_individual, FALSE) &&
    !identical(input$legend_group_show, FALSE) &&
    !identical(input$legend_individual_show, FALSE)
  group <- if (isTRUE(input$legend_title_show)) input$legend_group_title %||% "" else NULL
  individual <- if (isTRUE(input$legend_individual_title_show)) input$legend_individual_title %||% "" else NULL
  list(group = group, individual = if (merged) group else individual,
       group_order = 1L, individual_order = if (merged) 1L else 2L,
       merged = merged)
}
