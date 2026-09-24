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


# Column-name validation shared by paste parsing, Mapping defaults and replay.
# A transient malformed paste can contain blank or duplicated headers; those
# names are not safe selectInput values and must never reach data[character]
# lookups.  Keep this pure so every caller can fail softly instead of tearing
# down a Shiny observer/session.
graph_data_column_name_status <- function(data) {
  if (!is.data.frame(data)) {
    return(list(valid = FALSE, usable = character(0), message = "データ形式を確認してください。"))
  }

  nm <- names(data)
  if (is.null(nm) || length(nm) != ncol(data)) nm <- rep("", ncol(data))
  nm <- as.character(nm)
  blank <- is.na(nm) | !nzchar(trimws(nm))
  duplicated_name <- duplicated(nm) | duplicated(nm, fromLast = TRUE)
  duplicated_name[blank] <- FALSE

  usable <- nm[!blank & !duplicated_name]
  message <- NULL
  if (any(blank)) {
    message <- "列名が空欄の列があります。貼り付けたデータのヘッダー行を確認してください。"
  } else if (any(duplicated_name)) {
    dup <- unique(nm[duplicated_name])
    message <- paste0(
      "同じ列名が複数あります（", paste(dup, collapse = ", "),
      "）。列名を一意にしてから貼り直してください。"
    )
  }

  list(
    valid = is.null(message),
    usable = usable,
    message = message,
    blank = blank,
    duplicated = duplicated_name
  )
}

graph_usable_column_names <- function(data) {
  st <- graph_data_column_name_status(data)
  if (!is.data.frame(data) || !length(st$usable)) return(character(0))
  st$usable
}

# Pure helper shared by the reshape UI.
graph_default_reshape_columns <- function(data) {
  if (!is.data.frame(data) || !ncol(data)) return(character(0))
  cols <- graph_usable_column_names(data)
  if (!length(cols)) return(character(0))
  numeric_flags <- vapply(data, is.numeric, logical(1))
  all_names <- as.character(names(data) %||% rep("", ncol(data)))
  numeric_cols <- unique(all_names[numeric_flags & all_names %in% cols])
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

  cols <- graph_usable_column_names(data)
  if (!length(cols)) {
    return(list(
      x = "", y = "", color = "", linetype = "__color__", shape = "__color__",
      id = "", facet = "", position = "",
      external_error = "", external_ymin = "", external_ymax = ""
    ))
  }
  all_names <- as.character(names(data) %||% rep("", ncol(data)))
  numeric_flags <- vapply(data, is.numeric, logical(1))
  numeric_cols <- unique(all_names[numeric_flags & all_names %in% cols])
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
  non_id_positions <- which(all_names %in% non_id_cols)
  categorical_candidates <- unique(all_names[
    non_id_positions[!numeric_flags[non_id_positions]]
  ])
  categorical_candidates <- categorical_candidates[
    categorical_candidates %in% non_id_cols & categorical_candidates != default_y
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
    line_series_mode = "auto",
    line_series_var = "",
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

# Current canonical GraphState schema 5 migration. Runtime only consumes schema 5 fields;
# compatibility is resolved once at the replay/load boundary.
graph_state_migrate_v5 <- function(state) {
  if (!is.list(state)) return(state)
  old_schema <- suppressWarnings(as.integer(graph_state_scalar(state$schema_version, 0L)))
  if (!is.finite(old_schema)) old_schema <- 0L

  mp <- state$mapping %||% list()
  if (!is.list(mp)) mp <- list()
  mode <- graph_state_scalar(mp$line_series_mode, "auto")
  mode <- as.character(mode %||% "auto")[1]
  if (!mode %in% c("auto", "mapped", "single", "column")) mode <- "auto"
  mp$line_series_mode <- mode
  series_var <- as.character(graph_state_scalar(mp$line_series_var, "") %||% "")[1]
  if (is.na(series_var)) series_var <- ""
  mp$line_series_var <- series_var
  state$mapping <- mp

  st <- graph_style_migrate_v6(state$style %||% list())
  ap <- st$appearance %||% list()
  if (!is.list(ap)) ap <- list()
  alpha <- suppressWarnings(as.numeric(graph_state_scalar(ap$scatter_point_alpha, 0.90)))
  if (!is.finite(alpha)) alpha <- 0.90
  ap$scatter_point_alpha <- max(0, min(1, alpha))
  st$appearance <- ap
  state$style <- st

  state$version <- "4.0-rc2"
  state$schema_version <- max(5L, old_schema)
  state
}

# Normalize loaded GraphState before replay into the persistent Editor.
# Mapping choice vectors are never persisted. Replay derives target choices
# synchronously from canonical data/reshape and sends them with selected values;
# ui_snapshot remains presentation-only and no browser semantic readback is used.
graph_state_prepare_replay_snapshot <- function(state) {
  if (!is.list(state)) return(state)
  state <- graph_normalize_legend_state(state)

  # Replay does not require saved choice vectors or a browser-readback gate.
  # Choices are derived from canonical data/reshape at replay time and ordinary
  # observers continue to own later user-edit choice updates. This helper remains
  # a pure GraphState schema migration boundary for deterministic Style defaults.
  state$ui_snapshot <- graph_ui_snapshot_normalize(state$ui_snapshot)
  old_schema <- suppressWarnings(as.integer(graph_state_scalar(state$schema_version, 0L)))
  if (!is.finite(old_schema)) old_schema <- 0L
  if (old_schema >= 4L) return(graph_state_migrate_v5(state))

  raw <- tryCatch(
    graph_parse_pasted_data(as.character(state$data_text %||% "")[1]),
    error = function(e) NULL
  )
  if (!is.data.frame(raw) || !ncol(raw)) {
    state$schema_version <- max(4L, old_schema)
    return(graph_state_migrate_v5(state))
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
  graph_state_migrate_v5(
    graph_state_materialize_dynamic_style_defaults(state, prepared_data = prepared)
  )
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

