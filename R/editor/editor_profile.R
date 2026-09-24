# v4 architecture: one explicit capability contract drives UI composition,
# replay transport, state capture, and browser binding checks.
# Figure controls are not a partial Full Editor DOM; they are a separate
# profile over the same canonical GraphState and shared plot/style core.

graph_editor_profile <- function(name = c("full", "figure_controls")) {
  name <- match.arg(name)

  if (identical(name, "full")) {
    return(list(
      name = "full",
      capabilities = list(
        full_shell = TRUE,
        editable_data = TRUE,
        reshape_controls = TRUE,
        statistics = TRUE,
        shared_style = TRUE,
        mapping = TRUE,
        style = TRUE,
        preview = TRUE
      ),
      # Full Editor uses one persistent browser DOM and direct local hydration.
      # It has no updateInput completion barrier.
      replay_required_inputs = character(0),
      mount_inputs = c("plot_type", "graph_main_tab", "text"),
      editable_state = c("project_name", "data_text", "reshape", "mapping",
                         "plot", "labels", "style", "statistics_recipes",
                         "statistics_selected_id", "ui_snapshot")
    ))
  }

  list(
    name = "figure_controls",
    capabilities = list(
      full_shell = FALSE,
      editable_data = FALSE,
      reshape_controls = FALSE,
      statistics = FALSE,
      shared_style = FALSE,
      mapping = TRUE,
      style = TRUE,
      preview = FALSE
    ),
    # RC12: Figure owns a browser working copy over its frozen snapshot. The
    # initial mount still checks the four structural bindings below, while
    # ordinary Figure selection/reselection has no per-input replay barrier.
    replay_required_inputs = character(0),
    mount_inputs = c("plot_type", "xvar", "yvar", "colorvar"),
    # Figure edits overlay only these canonical sections. Data, reshape,
    # Statistics, project identity and Full-Editor UI snapshot stay source-owned.
    editable_state = c("mapping", "plot", "labels", "style")
  )
}

graph_editor_profile_has <- function(profile, capability) {
  is.list(profile) && isTRUE((profile$capabilities %||% list())[[capability]])
}

graph_editor_profile_required_inputs <- function(profile) {
  as.character(profile$replay_required_inputs %||% character(0))
}

graph_editor_profile_mount_inputs <- function(profile) {
  as.character(profile$mount_inputs %||% character(0))
}

graph_editor_profile_is_figure <- function(profile) {
  is.list(profile) && identical(as.character(profile$name %||% ""), "figure_controls")
}
