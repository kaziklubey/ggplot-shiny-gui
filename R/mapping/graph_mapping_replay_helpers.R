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

    raw_cols <- graph_usable_column_names(raw)
    if (length(raw_cols) < 2L) return(NULL)
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
    cols <- graph_usable_column_names(d)
    all_names <- as.character(names(d) %||% rep("", ncol(d)))
    numeric_flags <- vapply(d, is.numeric, logical(1))
    numeric_cols <- unique(all_names[numeric_flags & all_names %in% cols])
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
    line_series_mode <- json_chr(mp$line_series_mode, "auto")
    if (!line_series_mode %in% c("auto", "mapped", "single", "column")) line_series_mode <- "auto"
    line_series_var <- choose(mp$line_series_var, cols, "", allow_empty = TRUE)

    list(
      raw = raw,
      data = d,
      recipe = recipe,
      transform_applied = isTRUE(transformed$transformed),
      transform_warning = transformed$warning %||% NULL,
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
      line_series_mode = line_series_mode,
      line_series_var = line_series_var,
      external_error = choose(mp$external_error, numeric_cols, "", allow_empty = TRUE),
      external_ymin = choose(mp$external_ymin, numeric_cols, "", allow_empty = TRUE),
      external_ymax = choose(mp$external_ymax, numeric_cols, "", allow_empty = TRUE)
    )
  }


# Reconcile Mapping against any accepted change that can alter the effective
# data schema (raw Data text or Wide→Long recipe). This is one pure state step:
# Mapping is resolved from the transformed data before the canonical commit.
# Invalid/partial Data/reshape deliberately leaves Mapping unchanged so the
# ordinary validation/recovery UI can handle the transient state safely.
graph_reconcile_mapping_for_schema_change <- function(previous_state, state) {
  if (!is.list(state)) {
    return(list(state = state, plan = NULL, changed_keys = character(0)))
  }

  mapping_plan <- tryCatch(graph_replay_mapping_plan(state), error = function(e) NULL)
  if (!is.list(mapping_plan)) {
    return(list(state = state, plan = NULL, changed_keys = character(0)))
  }
  reshape_enabled <- isTRUE((state$reshape %||% list())$enabled)
  if (isTRUE(reshape_enabled) && !isTRUE(mapping_plan$transform_applied)) {
    return(list(state = state, plan = mapping_plan, changed_keys = character(0)))
  }

  old_mapping <- if (is.list(previous_state) && is.list(previous_state$mapping)) previous_state$mapping else list()
  current_mapping <- if (is.list(state$mapping)) state$mapping else list()
  resolved_mapping <- list(
    x = mapping_plan$x,
    y = mapping_plan$y,
    color = mapping_plan$color,
    linetype = mapping_plan$linetype,
    shape = mapping_plan$shape,
    id = mapping_plan$id,
    facet = mapping_plan$facet,
    position = mapping_plan$position,
    line_series_mode = mapping_plan$line_series_mode,
    line_series_var = mapping_plan$line_series_var,
    external_error = mapping_plan$external_error,
    external_ymin = mapping_plan$external_ymin,
    external_ymax = mapping_plan$external_ymax
  )

  state$mapping <- utils::modifyList(current_mapping, resolved_mapping)
  if (is.list(state$reshape)) {
    state$reshape$columns <- as.character(mapping_plan$reshape_columns %||% character(0))
  }

  changed_keys <- names(resolved_mapping)[vapply(names(resolved_mapping), function(nm) {
    !identical(
      graph_state_scalar(old_mapping[[nm]], NULL),
      graph_state_scalar(resolved_mapping[[nm]], NULL)
    )
  }, logical(1))]

  list(state = state, plan = mapping_plan, changed_keys = changed_keys)
}

# Backward-compatible focused name used by the Data transport boundary.
graph_reconcile_mapping_after_data_change <- function(previous_state, state) {
  graph_reconcile_mapping_for_schema_change(previous_state, state)
}

# A queued commit belongs to the generation and phase in which it was captured.
graph_commit_candidate_current <- function(candidate, generation, active) {
  is.list(candidate) && !isTRUE(active) && !isTRUE(candidate$replaying) &&
    identical(candidate$generation, generation)
}
