# Pure target-derived Mapping plan. No session, reactive input or registry writes.
graph_replay_mapping_plan <- function(cfg) {
    json_chr <- graph_state_scalar
    mp <- cfg$mapping %||% list()
    r <- cfg$reshape %||% list()

    raw <- tryCatch(
      graph_parse_pasted_data(json_chr(cfg$data_text, "")),
      error = function(e) NULL
    )
    if (!is.data.frame(raw) || ncol(raw) < 2L) return(NULL)

    raw_cols <- names(raw)
    reshape_cols <- as.character(r$columns %||% character(0))
    reshape_cols <- reshape_cols[reshape_cols %in% raw_cols]
    recipe <- graph_plot_data_transform_recipe(
      enabled = isTRUE(r$enabled),
      row_id = isTRUE(r$row_id),
      columns = reshape_cols,
      x_name = json_chr(r$x_name, "Time"),
      y_name = json_chr(r$y_name, "Value")
    )
    transformed <- tryCatch(
      graph_apply_data_transform(raw, recipe, incomplete_is_warning = FALSE),
      error = function(e) NULL
    )
    d <- if (is.list(transformed) && is.data.frame(transformed$data)) transformed$data else raw
    cols <- names(d)
    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    defaults <- graph_default_mapping_for_data(d)

    choose <- function(value, choices, fallback = "", specials = character(0), allow_empty = FALSE) {
      value <- json_chr(value, "")
      if (value %in% specials) return(value)
      if (allow_empty && identical(value, "")) return("")
      if (nzchar(value) && value %in% choices) return(value)
      fallback
    }

    color <- json_chr(mp$color, "")
    if (!nzchar(color) && is.null(mp$position)) color <- json_chr(mp$series, "")
    if (identical(color, "__fixed__")) color <- ""

    x <- choose(mp$x, cols, defaults$x)
    y <- choose(mp$y, numeric_cols, defaults$y)
    color <- choose(color, cols, defaults$color, allow_empty = TRUE)
    shape <- choose(mp$shape, cols, "__color__", specials = c("", "__color__"))
    id <- choose(mp$id, cols, defaults$id, allow_empty = TRUE)
    facet <- choose(mp$facet, cols, "", allow_empty = TRUE)
    position <- choose(mp$position %||% mp$series, cols, "", allow_empty = TRUE)
    linetype <- choose(mp$linetype, cols, "__color__", specials = c("", "__color__"))

    list(
      raw = raw,
      data = d,
      recipe = recipe,
      raw_cols = raw_cols,
      reshape_columns = reshape_cols,
      cols = cols,
      numeric_cols = numeric_cols,
      x = x,
      y = y,
      color = color,
      shape = shape,
      id = id,
      facet = facet,
      position = position,
      linetype = linetype,
      external_error = choose(mp$external_error, numeric_cols, "", allow_empty = TRUE),
      external_ymin = choose(mp$external_ymin, numeric_cols, "", allow_empty = TRUE),
      external_ymax = choose(mp$external_ymax, numeric_cols, "", allow_empty = TRUE)
    )
  }

# A queued commit belongs to the generation and phase in which it was captured.
graph_commit_candidate_current <- function(candidate, generation, active) {
  is.list(candidate) && !isTRUE(active) && !isTRUE(candidate$replaying) &&
    identical(candidate$generation, generation)
}
