# ============================================================
# Pure Graph data transforms
# v3.72.27: one transform engine shared by Plot Data and Statistics recipes.
# ============================================================

# A transform recipe is presentation/analysis state only. It never reads
# Shiny inputs. Callers own when/how the recipe is constructed and persisted.
graph_normalize_data_transform_recipe <- function(recipe = NULL, default_type = "as_is") {
  recipe <- recipe %||% list()

  # Shiny inputs can be NULL/character(0)/NA before their browser bindings exist.
  # Canonical transform recipes must always contain usable scalar strings so the
  # pristine singleton Editor can be captured before any Graph is attached.
  default_type_value <- unlist(default_type, recursive = TRUE, use.names = FALSE)
  default_type <- if (!length(default_type_value)) "as_is" else trimws(as.character(default_type_value[[1]]))
  if (is.na(default_type) || !nzchar(default_type) || !default_type %in% c("as_is", "wide_to_long")) {
    default_type <- "as_is"
  }

  type_value <- unlist(recipe$type, recursive = TRUE, use.names = FALSE)
  type <- if (!length(type_value)) default_type else trimws(as.character(type_value[[1]]))
  if (is.na(type) || !nzchar(type) || !type %in% c("as_is", "wide_to_long")) type <- default_type

  cols <- as.character(unlist(recipe$columns %||% character(0), use.names = FALSE))
  cols <- trimws(cols)
  cols <- unique(cols[!is.na(cols) & nzchar(cols)])

  names_value <- unlist(recipe$names_to, recursive = TRUE, use.names = FALSE)
  names_to <- if (!length(names_value)) "Condition" else trimws(as.character(names_value[[1]]))
  if (is.na(names_to) || !nzchar(names_to)) names_to <- "Condition"

  values_value <- unlist(recipe$values_to, recursive = TRUE, use.names = FALSE)
  values_to <- if (!length(values_value)) "Value" else trimws(as.character(values_value[[1]]))
  if (is.na(values_to) || !nzchar(values_to)) values_to <- "Value"

  list(
    type = type,
    columns = cols,
    row_id = isTRUE(recipe$row_id),
    names_to = names_to,
    values_to = values_to
  )
}

graph_plot_data_transform_recipe <- function(enabled = FALSE, row_id = TRUE,
                                             columns = character(0),
                                             x_name = "Time", y_name = "Value") {
  graph_normalize_data_transform_recipe(list(
    type = if (isTRUE(enabled)) "wide_to_long" else "as_is",
    columns = columns,
    row_id = isTRUE(row_id),
    names_to = x_name,
    values_to = y_name
  ))
}

graph_validate_wide_to_long_recipe <- function(data, recipe,
                                                incomplete_is_warning = TRUE) {
  cols <- recipe$columns[recipe$columns %in% names(data)]
  if (length(cols) < 2L) {
    return(list(
      ok = FALSE,
      columns = cols,
      warning = if (isTRUE(incomplete_is_warning)) {
        "Wide→Longには2列以上の変換対象列を指定してください。"
      } else NULL
    ))
  }

  untouched <- setdiff(names(data), cols)
  invalid_names <- identical(recipe$names_to, recipe$values_to) ||
    recipe$names_to %in% untouched || recipe$values_to %in% untouched
  if (invalid_names) {
    return(list(
      ok = FALSE,
      columns = cols,
      warning = "変換後の列名が既存列と重複しているか、要因列名と値列名が同じです。"
    ))
  }

  list(ok = TRUE, columns = cols, warning = NULL)
}

graph_apply_wide_to_long <- function(data, recipe, columns) {
  d1 <- data
  row_id_name <- NULL
  if (isTRUE(recipe$row_id)) {
    row_id_name <- if ("RowID" %in% names(d1)) ".RowID" else "RowID"
    d1[[row_id_name]] <- seq_len(nrow(d1))
  }

  # Keep source column order as the generated factor order.
  columns <- names(d1)[names(d1) %in% columns]
  out <- tryCatch(
    tidyr::pivot_longer(
      d1,
      cols = dplyr::all_of(columns),
      names_to = recipe$names_to,
      values_to = recipe$values_to
    ),
    error = function(e) e
  )

  if (inherits(out, "error")) {
    return(list(
      data = data,
      warning = paste0(
        "選択列を1つの値列へ結合できません: ", conditionMessage(out),
        "  Long形式のデータなら、この変換は不要です。"
      ),
      transformed = FALSE,
      row_id_name = NULL
    ))
  }

  out[[recipe$names_to]] <- factor(out[[recipe$names_to]], levels = columns)
  list(
    data = out,
    warning = NULL,
    transformed = TRUE,
    row_id_name = row_id_name
  )
}

graph_apply_data_transform <- function(data, recipe = NULL,
                                       incomplete_is_warning = TRUE) {
  rec <- graph_normalize_data_transform_recipe(recipe)
  if (is.null(data) || !is.data.frame(data)) {
    return(list(
      data = data,
      warning = "変換対象のデータがありません。",
      transformed = FALSE,
      recipe = rec
    ))
  }
  if (identical(rec$type, "as_is")) {
    return(list(data = data, warning = NULL, transformed = FALSE, recipe = rec))
  }

  check <- graph_validate_wide_to_long_recipe(data, rec, incomplete_is_warning)
  if (!isTRUE(check$ok)) {
    return(list(
      data = data,
      warning = check$warning,
      transformed = FALSE,
      recipe = rec
    ))
  }

  out <- graph_apply_wide_to_long(data, rec, check$columns)
  out$recipe <- rec
  out
}
