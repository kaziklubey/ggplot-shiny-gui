# Browser-direct payload builders shared by startup context and Graph replay.
# Pure payload construction; no UI creation, observer, or transport ownership.
  graph_browser_direct_hydration_payload <- function(cfg, replay_plan, transaction = NULL) {
    values <- utils::modifyList(graph_snapshot_input_defaults(), graph_ui_seed_from_state(cfg))
    # graph_ui_seed_from_state() intentionally includes Data text for ordinary
    # UI seeding. Browser-direct replay removes it because the dedicated Data
    # Document channel hydrates Ace with explicit Graph/lease ownership.
    values$text <- NULL
    values$reshape_wide <- isTRUE((cfg$reshape %||% list())$enabled)
    values$reshape_row_id <- isTRUE((cfg$reshape %||% list())$row_id)
    values$reshape_x_name <- graph_state_scalar((cfg$reshape %||% list())$x_name, "Time")
    values$reshape_y_name <- graph_state_scalar((cfg$reshape %||% list())$y_name, "Value")
    snap <- graph_ui_snapshot_normalize(cfg$ui_snapshot)
    # The Graph workspace section is intentionally absent from GraphState
    # hydration. The one persistent Editor DOM owns graph_main_tab across Graph
    # switches; only Graph-owned view state such as sticky_plot is replayed.
    values$sticky_plot <- isTRUE(snap$selections$sticky_plot %||% FALSE)
    values$reshape_columns <- as.character((cfg$reshape %||% list())$columns %||% character(0))
    values$line_breaks <- as.character((cfg$plot %||% list())$line_breaks %||% character(0))

    context <- graph_browser_direct_data_context(cfg)
    for (key in names(context$values)) values[[key]] <- context$values[[key]]
    choices <- context$choices

    # Full and delta replay are modes of this one transport owner. A delta
    # contains only controls selected by the canonical server-side diff.
    transport_mode <- if (isTRUE(replay_plan$full)) "full" else "delta"
    if (identical(transport_mode, "delta")) {
      transport_keys <- unique(as.character(replay_plan$updated_inputs %||% character(0)))
      values <- values[intersect(names(values), transport_keys)]
      choices <- choices[intersect(names(choices), transport_keys)]
    }

    graph_browser_direct_payload_envelope(cfg, values, choices,
      transport_mode, replay_plan$updated_inputs, transaction)
  }

  # Shared data-derived choices/values; no full scalar snapshot or replay plan.
  graph_browser_direct_data_context <- function(cfg) {
    values <- list()
    mapping_plan <- isolate(graph_mapping_replay_plan())
    choices <- list()
    option_records <- function(x, labels = NULL) {
      x <- as.character(x %||% character(0))
      if (is.null(labels)) labels <- x
      labels <- as.character(labels)
      lapply(seq_along(x), function(i) list(label = labels[[i]], value = x[[i]]))
    }
    prepend_options <- function(prefix, x) c(prefix, option_records(x))
    if (is.list(mapping_plan)) {
      cols <- as.character(mapping_plan$cols %||% character(0))
      nums <- as.character(mapping_plan$numeric_cols %||% character(0))

      # Use the same target-derived, validity-checked Mapping plan for both the
      # option universe and the selected values. This prevents a stale/invalid
      # saved scalar from being selected against a newly rebuilt choice set.
      values$xvar <- as.character(mapping_plan$x %||% "")[1]
      values$yvar <- as.character(mapping_plan$y %||% "")[1]
      values$colorvar <- as.character(mapping_plan$color %||% "")[1]
      values$shapevar <- as.character(mapping_plan$shape %||% "__color__")[1]
      values$idvar <- as.character(mapping_plan$id %||% "")[1]
      values$facetvar <- as.character(mapping_plan$facet %||% "")[1]
      values$groupvar <- as.character(mapping_plan$position %||% "")[1]
      values$linetypevar <- as.character(mapping_plan$linetype %||% "__color__")[1]
      values$line_series_mode <- as.character(mapping_plan$line_series_mode %||% "auto")[1]
      values$line_series_var <- as.character(mapping_plan$line_series_var %||% "")[1]
      values$external_error_col <- as.character(mapping_plan$external_error %||% "")[1]
      values$external_ymin_col <- as.character(mapping_plan$external_ymin %||% "")[1]
      values$external_ymax_col <- as.character(mapping_plan$external_ymax %||% "")[1]
      values$reshape_columns <- as.character(mapping_plan$reshape_columns %||% character(0))

      choices$xvar <- option_records(cols)
      choices$yvar <- option_records(nums)
      choices$colorvar <- prepend_options(list(list(label = "使わない（固定）", value = "")), cols)
      choices$shapevar <- prepend_options(list(
        list(label = "Color と同じ", value = "__color__"),
        list(label = "なし（固定）", value = "")
      ), cols)
      choices$idvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$facetvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$groupvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$line_series_var <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$linetypevar <- prepend_options(list(
        list(label = "色で分ける要因と同じ", value = "__color__"),
        list(label = "使わない（固定）", value = "")
      ), cols)
      choices$external_error_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$external_ymin_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$external_ymax_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$reshape_columns <- option_records(mapping_plan$raw_cols %||% character(0))

      # line_breaks is a selectize whose option universe depends on the effective
      # X mapping/order. Keep it inside the same browser-direct choice phase so
      # the Full Editor never needs a late updateSelectizeInput() after READY.
      lb_plan <- tryCatch(graph_line_break_plan(cfg, mapping_plan), error = function(e) NULL)
      if (is.list(lb_plan) && !is.null(lb_plan$choices)) {
        lb_values <- as.character(unname(lb_plan$choices) %||% character(0))
        lb_labels <- as.character(names(lb_plan$choices) %||% lb_values)
        choices$line_breaks <- option_records(lb_values, lb_labels)
        saved_breaks <- as.character((cfg$plot %||% list())$line_breaks %||% character(0))
        values$line_breaks <- saved_breaks[saved_breaks %in% lb_values]
      }
    }

    list(values = values, choices = choices)
  }

  graph_browser_direct_payload_envelope <- function(cfg, values, choices,
      replay_mode, changed_inputs, transaction = NULL) {
    list(
      graphId = as.character((transaction %||% list())$id %||% "")[[1]],
      generation = as.integer(isolate(graph_state_replay_generation()) %||% 0L),
      activationGeneration = as.integer((transaction %||% list())$generation %||%
        isolate(graph_editor_activation_generation()) %||% 0L),
      editorMode = if (graph_editor_profile_is_figure(editor_profile)) "figure_controls" else "full_editor",
      replayMode = replay_mode,
      inputPrefix = session$ns(""),
      patchInput = session$ns("graph_profile_browser_patch"),
      values = values,
      choices = choices,
      poolContexts = if (graph_editor_profile_has(editor_profile, "full_shell")) graph_slot_pool_replay_contexts() else list(),
      panels = graph_ui_snapshot_normalize(cfg$ui_snapshot)$panels %||% list(),
      changedInputs = as.list(as.character(changed_inputs %||% character(0)))
    )
  }
