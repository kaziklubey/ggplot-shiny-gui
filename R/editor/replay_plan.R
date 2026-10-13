# ============================================================
# Editor replay plan
# ============================================================
# A persistent Editor should transport only the canonical sections that differ
# from the state already attached to its DOM. This is not a browser-side skip
# guard: the server derives one transaction plan from canonical GraphState
# before sending the single browser-direct hydration payload.

graph_replay_value_changed <- function(old, new) {
  !app_state_semantically_equal(old, new)
}

graph_style_replay_branches <- function(previous, target, full = FALSE) {
  keys <- c("shared_library", "color_styles", "fill_none_styles", "linetype_styles",
    "shape_styles", "series_styles", "regression_styles", "raw_group_colors",
    "orders", "legend_titles", "legend_item_labels", "level_labels")
  timing <- isTRUE(getOption("ggplot.gui.style_pool_diag", FALSE))
  diff_ms <- setNames(numeric(length(keys)), keys)
  out <- setNames(vapply(keys, function(key) {
    t0 <- if (timing) proc.time()[["elapsed"]] else 0
    changed <- isTRUE(full) || graph_replay_value_changed(previous[[key]], target[[key]])
    if (timing) diff_ms[[key]] <<- round((proc.time()[["elapsed"]] - t0) * 1000, 1)
    changed
  }, logical(1)), keys)
  if (timing) attr(out, "diff_ms") <- diff_ms
  out
}

graph_editor_replay_plan <- function(previous_state, target_state, profile) {
  if (!is.list(target_state)) return(NULL)

  full <- !is.list(previous_state)
  changed <- function(key) {
    isTRUE(full) || graph_replay_value_changed(previous_state[[key]], target_state[[key]])
  }

  data_changed <- isTRUE(full) ||
    graph_replay_value_changed(previous_state$data_text, target_state$data_text)
  reshape_changed <- changed("reshape")
  filter_changed <- changed("plot_filter")
  mapping_changed <- changed("mapping")
  plot_changed <- changed("plot")
  labels_changed <- changed("labels")
  style_changed <- changed("style")
  ui_changed <- changed("ui_snapshot")

  # Slot-pool payloads depend only on level topology and the small subset of
  # Style trees that supply per-level values. Do not rebuild/re-publish all
  # pools when a Graph differs only in unrelated appearance (font, axes,
  # legend layout, etc.).
  style_branches <- graph_style_replay_branches(previous_state$style, target_state$style, full)
  # Generation remains transaction-owned even when no pool content changes.
  # Data/schema changes require topology evaluation; Style-only changes select
  # only consumers of the changed branch. Publication compares the existing
  # pool owner's display signature, so equal topology/value changes stay local.
  topology_changed <- isTRUE(full) || data_changed || reshape_changed || filter_changed
  pools <- graph_slot_pool_names()
  pool_names <- pools[vapply(pools, function(pool) topology_changed ||
    graph_replay_value_changed(graph_slot_pool_state_dependencies(pool, previous_state),
      graph_slot_pool_state_dependencies(pool, target_state)), logical(1))]
  # Statistics context is data-owned as well as recipe-owned. A Graph switch
  # with identical recipes but different Data/reshape must not keep the previous
  # Graph's computed analysis context.
  statistics_changed <- graph_editor_profile_has(profile, "statistics") &&
    (isTRUE(full) || isTRUE(data_changed) || isTRUE(reshape_changed) ||
       graph_replay_value_changed(previous_state$statistics_recipes, target_state$statistics_recipes) ||
       graph_replay_value_changed(previous_state$statistics_selected_id, target_state$statistics_selected_id))

  # Mapping choices depend on the effective data/reshape context and some plot
  # semantics. Even when the selected mapping values themselves are unchanged,
  # a changed data context must rebuild those choices exactly once.
  data_context_changed <- isTRUE(data_changed) || isTRUE(reshape_changed) || isTRUE(filter_changed)
  mapping_transport <- isTRUE(full) || isTRUE(mapping_changed) ||
    isTRUE(data_context_changed) || isTRUE(plot_changed)

  full_scalar_transport <- graph_editor_profile_has(profile, "full_shell") &&
    (isTRUE(full) || isTRUE(ui_changed) ||
       isTRUE(data_changed) || isTRUE(reshape_changed))
  shared_scalar_transport <- isTRUE(full) || isTRUE(plot_changed) || isTRUE(labels_changed)

  updated_inputs <- character(0)
  add_inputs <- function(x) updated_inputs <<- unique(c(updated_inputs, as.character(x)))

  # Fixed browser-owned controls map one-to-one onto canonical GraphState
  # paths. Diff those paths directly so style/appearance scalars participate in
  # delta replay too; section flags alone are intentionally too coarse.
  path_value <- function(state, path) {
    if (!is.list(state)) return(NULL)
    parts <- strsplit(as.character(path %||% "")[[1]], ".", fixed = TRUE)[[1]]
    cur <- state
    for (key in parts) {
      if (!is.list(cur) || !key %in% (names(cur) %||% character(0))) return(NULL)
      cur <- cur[[key]]
    }
    cur
  }
  if (!isTRUE(full)) {
    browser_paths <- graph_browser_input_paths(target_state)
    for (key in names(browser_paths)) {
      path <- browser_paths[[key]]
      if (graph_replay_value_changed(path_value(previous_state, path), path_value(target_state, path))) {
        add_inputs(key)
      }
    }
    previous_ui <- graph_ui_snapshot_normalize(previous_state$ui_snapshot)
    target_ui <- graph_ui_snapshot_normalize(target_state$ui_snapshot)
    if (graph_replay_value_changed(previous_ui$selections$sticky_plot, target_ui$selections$sticky_plot)) {
      add_inputs("sticky_plot")
    }
  }

  if (isTRUE(full_scalar_transport)) {
    if (isTRUE(full) || isTRUE(ui_changed)) add_inputs("sticky_plot")
    if (isTRUE(full) || isTRUE(data_changed)) add_inputs("text")
    if (isTRUE(full) || isTRUE(reshape_changed)) {
      add_inputs(c("reshape_wide", "reshape_row_id", "reshape_x_name", "reshape_y_name"))
    }
  }

  if (isTRUE(shared_scalar_transport)) {
    if (isTRUE(full) || isTRUE(plot_changed)) {
      add_inputs(c(
        "plot_type", "bar_layout", "bar_value_source", "bar_proportion_display", "summary_type", "summary_unit", "external_error_mode",
        "show_raw", "connect_id", "scatter_connect_mode",
        "individual_connect_direction", "line_breaks"
      ))
    }
    if (isTRUE(full) || isTRUE(labels_changed)) {
      add_inputs(c("xlab", "ylab", "title", "ymin", "ymax", "y_top_to_tick"))
    }
  }

  if (isTRUE(mapping_transport)) {
    if (graph_editor_profile_has(profile, "reshape_controls")) add_inputs("reshape_columns")
    add_inputs(c(
      "xvar", "yvar", "colorvar", "shapevar", "idvar", "facetvar",
      "groupvar", "line_series_mode", "line_series_var", "linetypevar",
      "external_error_col", "external_ymin_col", "external_ymax_col",
      "line_breaks"
    ))
  }


  sections <- c(
    if (isTRUE(full_scalar_transport)) "full-scalar",
    if (isTRUE(shared_scalar_transport)) "plot-label",
    if (isTRUE(mapping_transport)) "mapping",
    if (isTRUE(style_changed)) "style",
    if (isTRUE(statistics_changed)) "statistics"
  )

  list(
    full = isTRUE(full),
    data_changed = isTRUE(data_changed),
    reshape_changed = isTRUE(reshape_changed),
    filter_changed = isTRUE(filter_changed),
    mapping_changed = isTRUE(mapping_changed),
    plot_changed = isTRUE(plot_changed),
    labels_changed = isTRUE(labels_changed),
    style_changed = isTRUE(style_changed),
    style_branches = style_branches,
    ui_changed = isTRUE(ui_changed),
    statistics_changed = isTRUE(statistics_changed),
    data_context_changed = isTRUE(data_context_changed),
    pool_names = pool_names,
    pool_transport = length(pool_names) > 0L,
    mapping_transport = isTRUE(mapping_transport),
    full_scalar_transport = isTRUE(full_scalar_transport),
    shared_scalar_transport = isTRUE(shared_scalar_transport),
    updated_inputs = updated_inputs,
    sections = sections,
    no_input_updates = !length(updated_inputs) && !isTRUE(style_changed) && !isTRUE(statistics_changed)
  )
}
