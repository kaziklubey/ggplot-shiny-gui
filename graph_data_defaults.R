# Shared deterministic defaults for Graph data UI and the built-in sample Graph.
#
# The sample GraphState is the canonical template for g001 and New Graph.
# Browser controls display that state; they do not manufacture its Mapping.
# Duplicate Graph continues to copy its source GraphState instead.

graph_sample_data_text <- function() {
  paste(
    "ID\tGroup\tPre\tPost",
    "1\tCTL\t10.2\t13.8",
    "2\tCTL\t11.4\t14.6",
    "3\tCTL\t9.8\t13.2",
    "4\tCTL\t10.9\t14.1",
    "5\tCTL\t11.8\t15.0",
    "6\tCTL\t10.5\t13.9",
    "7\tEXP\t9.4\t11.6",
    "8\tEXP\t10.1\t12.3",
    "9\tEXP\t9.7\t11.2",
    "10\tEXP\t10.4\t12.0",
    "11\tEXP\t9.9\t11.8",
    "12\tEXP\t10.6\t12.5",
    sep = "\n"
  )
}

# Pure helper shared by the reshape UI.
graph_default_reshape_columns <- function(data) {
  if (!is.data.frame(data) || !ncol(data)) return(character(0))
  cols <- names(data)
  numeric_cols <- cols[vapply(data, is.numeric, logical(1))]
  defaults <- setdiff(
    numeric_cols,
    c("ID", "Id", "id", "Subject", "subject", "SubjectID", "subject_id")
  )
  common <- cols[tolower(cols) %in% c(
    "pre", "post", "baseline", "test", "followup", "follow_up",
    "day1", "day2", "day3", "day4", "day5"
  )]
  if (length(common) >= 2L) defaults <- common
  defaults
}

# Pure helper matching the Mapping UI default-selection policy.
graph_default_mapping_for_data <- function(data) {
  if (!is.data.frame(data) || !ncol(data)) {
    return(list(
      x = "", y = "", color = "", linetype = "__color__", shape = "__color__",
      id = "", facet = "", position = "",
      external_error = "", external_ymin = "", external_ymax = ""
    ))
  }

  cols <- names(data)
  numeric_cols <- cols[vapply(data, is.numeric, logical(1))]
  id_candidates <- cols[tolower(cols) %in% c(
    "id", "subject", "subjectid", "subject_id",
    "rat", "ratid", "rat_id", "rowid", ".rowid"
  )]

  default_id <- if ("RowID" %in% cols) {
    "RowID"
  } else if (".RowID" %in% cols) {
    ".RowID"
  } else if ("ID" %in% cols) {
    "ID"
  } else if (length(id_candidates)) {
    id_candidates[[1]]
  } else ""

  numeric_measure_cols <- setdiff(numeric_cols, id_candidates)
  if (!length(numeric_measure_cols)) numeric_measure_cols <- numeric_cols

  factor_like_names <- c(
    "group", "condition", "cond", "treatment", "route", "phase",
    "block", "day", "trial", "session", "time", "period", "category",
    "factor", "type", "sex"
  )
  value_like_names <- c(
    "value", "mean", "average", "avg", "estimate", "dv", "score", "response",
    "duration", "latency", "time_sec", "distance", "speed", "count", "rate",
    "percent", "percentage", "measure"
  )

  value_named <- numeric_measure_cols[tolower(numeric_measure_cols) %in% value_like_names]
  numeric_dv_candidates <- numeric_measure_cols[
    !tolower(numeric_measure_cols) %in% factor_like_names
  ]
  default_y <- if ("Value" %in% numeric_measure_cols) {
    "Value"
  } else if (length(value_named)) {
    value_named[[1]]
  } else if (length(numeric_dv_candidates)) {
    numeric_dv_candidates[[length(numeric_dv_candidates)]]
  } else if (length(numeric_measure_cols)) {
    numeric_measure_cols[[length(numeric_measure_cols)]]
  } else ""

  non_id_cols <- setdiff(cols, id_candidates)
  named_factor_candidates <- non_id_cols[
    tolower(non_id_cols) %in% factor_like_names & non_id_cols != default_y
  ]
  categorical_candidates <- non_id_cols[
    !vapply(data[non_id_cols], is.numeric, logical(1)) & non_id_cols != default_y
  ]

  default_x <- if ("Time" %in% cols && !identical("Time", default_y)) {
    "Time"
  } else if ("Group" %in% cols && !identical("Group", default_y)) {
    "Group"
  } else if (length(named_factor_candidates)) {
    named_factor_candidates[[1]]
  } else if (length(categorical_candidates)) {
    categorical_candidates[[1]]
  } else if (nzchar(default_id) && !identical(default_id, default_y)) {
    default_id
  } else {
    other_cols <- setdiff(cols, default_y)
    if (length(other_cols)) other_cols[[1]] else if (length(cols)) cols[[1]] else ""
  }

  default_series <- if (
    identical(default_x, "Time") &&
      "Group" %in% cols &&
      !identical("Group", default_y)
  ) "Group" else ""

  list(
    x = default_x,
    y = default_y,
    color = default_series,
    linetype = "__color__",
    shape = "__color__",
    id = default_id,
    facet = "",
    position = "",
    external_error = "",
    external_ymin = "",
    external_ymax = ""
  )
}
# Build the canonical built-in sample GraphState from the Editor's static
# appearance/style shell. Data and Mapping are deterministic and therefore do
# not depend on whether browser selectInput values have round-tripped yet.

# Normalize loaded GraphState before replay into the persistent Editor.
# The persistent UI derives choices and conditional visibility itself; only
# manual view state remains in ui_snapshot. Project load and Graph switches
# therefore need no temporary UI hydration or browser readback.
graph_state_prepare_replay_snapshot <- function(state) {
  if (!is.list(state)) return(state)

  # Replay no longer requires saved choice vectors or a browser-readback gate.
  # The persistent UI derives choices/visibility from raw_dat()/dat()/plot_type
  # exactly as it does during ordinary editing. This helper is now only a pure
  # GraphState schema migration boundary for deterministic Style defaults.
  state$ui_snapshot <- graph_ui_snapshot_normalize(state$ui_snapshot)
  old_schema <- suppressWarnings(as.integer(graph_state_scalar(state$schema_version, 0L)))
  if (!is.finite(old_schema)) old_schema <- 0L
  if (old_schema >= 4L) return(state)

  raw <- tryCatch(
    graph_parse_pasted_data(as.character(state$data_text %||% "")[1]),
    error = function(e) NULL
  )
  if (!is.data.frame(raw) || !ncol(raw)) {
    state$schema_version <- max(4L, old_schema)
    return(state)
  }

  scalar_chr <- function(x, default = "") {
    z <- unlist(x, recursive = TRUE, use.names = FALSE)
    if (!length(z) || is.na(z[[1]])) return(default)
    as.character(z[[1]])
  }

  r <- state$reshape %||% list()
  recipe <- graph_plot_data_transform_recipe(
    enabled = isTRUE(r$enabled),
    row_id = isTRUE(r$row_id),
    columns = as.character(r$columns %||% character(0)),
    x_name = scalar_chr(r$x_name, "Time"),
    y_name = scalar_chr(r$y_name, "Value")
  )
  transformed <- tryCatch(
    graph_apply_data_transform(raw, recipe, incomplete_is_warning = FALSE),
    error = function(e) NULL
  )
  prepared <- if (is.list(transformed) && is.data.frame(transformed$data)) transformed$data else raw
  graph_state_materialize_dynamic_style_defaults(state, prepared_data = prepared)
}

graph_sample_graph_state <- function(base_state) {
  if (!is.list(base_state)) return(NULL)

  state <- tryCatch(
    unserialize(serialize(base_state, NULL, version = 3)),
    error = function(e) base_state
  )

  sample_text <- graph_sample_data_text()
  sample_data <- graph_parse_pasted_data(sample_text)
  if (!is.data.frame(sample_data) || !ncol(sample_data)) return(NULL)

  state$data_text <- sample_text
  state$reshape <- modifyList(
    if (is.list(state$reshape)) state$reshape else list(),
    list(
      enabled = FALSE,
      row_id = TRUE,
      columns = graph_default_reshape_columns(sample_data),
      x_name = "Time",
      y_name = "Value"
    )
  )
  sample_mapping <- graph_default_mapping_for_data(sample_data)
  # The built-in line sample does not need an ID mapping.  The browser's line
  # Mapping UI also starts with ID unset; keeping the template unset avoids a
  # pointless ID -> empty commit immediately after first render.
  sample_mapping$id <- ""
  state$mapping <- modifyList(
    if (is.list(state$mapping)) state$mapping else list(),
    sample_mapping
  )

  # UI snapshot owns presentation only; Mapping/reshape selections above are
  # already canonical GraphState fields and need no duplicate replay metadata.
  state$ui_snapshot <- graph_ui_snapshot_normalize(state$ui_snapshot)
  state
}

