# ============================================================
# Editor replay plan
# ============================================================
# A persistent Editor should transport only the canonical sections that differ
# from the state already attached to its DOM. This is not a browser-side skip
# guard: the server derives one transaction plan from canonical GraphState
# before issuing any update*Input calls. The browser completion barrier then
# waits only for bindings that this transaction actually touched.

graph_replay_value_changed <- function(old, new) {
  !app_state_semantically_equal(old, new)
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
  mapping_changed <- changed("mapping")
  plot_changed <- changed("plot")
  labels_changed <- changed("labels")
  style_changed <- changed("style")
  ui_changed <- changed("ui_snapshot")
  project_changed <- graph_editor_profile_has(profile, "full_shell") &&
    (isTRUE(full) || graph_replay_value_changed(previous_state$project_name, target_state$project_name))
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
  data_context_changed <- isTRUE(data_changed) || isTRUE(reshape_changed)
  mapping_transport <- isTRUE(full) || isTRUE(mapping_changed) ||
    isTRUE(data_context_changed) || isTRUE(plot_changed)

  full_scalar_transport <- graph_editor_profile_has(profile, "full_shell") &&
    (isTRUE(full) || isTRUE(ui_changed) || isTRUE(project_changed) ||
       isTRUE(data_changed) || isTRUE(reshape_changed))
  shared_scalar_transport <- isTRUE(full) || isTRUE(plot_changed) || isTRUE(labels_changed)

  updated_inputs <- character(0)
  add_inputs <- function(x) updated_inputs <<- unique(c(updated_inputs, as.character(x)))

  if (isTRUE(full_scalar_transport)) {
    if (isTRUE(full) || isTRUE(ui_changed)) add_inputs(c("graph_main_tab", "sticky_plot"))
    if (isTRUE(full) || isTRUE(project_changed)) add_inputs("project_name")
    if (isTRUE(full) || isTRUE(data_changed)) add_inputs("text")
    if (isTRUE(full) || isTRUE(reshape_changed)) {
      add_inputs(c("reshape_wide", "reshape_row_id", "reshape_x_name", "reshape_y_name"))
    }
  }

  if (isTRUE(shared_scalar_transport)) {
    if (isTRUE(full) || isTRUE(plot_changed)) {
      add_inputs(c(
        "plot_type", "summary_type", "summary_unit", "external_error_mode",
        "show_raw", "connect_id", "scatter_connect_mode", "line_breaks"
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

  required <- intersect(graph_editor_profile_required_inputs(profile), updated_inputs)

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
    mapping_changed = isTRUE(mapping_changed),
    plot_changed = isTRUE(plot_changed),
    labels_changed = isTRUE(labels_changed),
    style_changed = isTRUE(style_changed),
    ui_changed = isTRUE(ui_changed),
    project_changed = isTRUE(project_changed),
    statistics_changed = isTRUE(statistics_changed),
    data_context_changed = isTRUE(data_context_changed),
    mapping_transport = isTRUE(mapping_transport),
    full_scalar_transport = isTRUE(full_scalar_transport),
    shared_scalar_transport = isTRUE(shared_scalar_transport),
    updated_inputs = updated_inputs,
    required_inputs = required,
    sections = sections,
    no_input_updates = !length(updated_inputs) && !isTRUE(style_changed) && !isTRUE(statistics_changed)
  )
}
