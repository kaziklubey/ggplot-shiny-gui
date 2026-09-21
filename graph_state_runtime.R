# v3.73.2.37 Phase 2.03 — canonical GraphState capture for the persistent Editor.
# Project loading is owned by server_project_io_runtime.R and canonical GraphState
# replay is owned by server_graph_state_replay_runtime.R. No staged hydrate,
# semantic readback/reconcile, retry, remount, or hidden-Graph restore exists here.

  project_settings <- reactive({
    if (isTRUE(graph_state_replay_active())) return(graph_state_replay_target())
    # Recipe add/delete/rename lives in stats_recipes(), while selected Analysis
    # fields are ordinary Shiny inputs. Keep explicit dependencies so the
    # canonical GraphState includes both the reproducible recipe collection and
    # the Graph-local currently selected Analysis.
    stats_recipes()
    stats_selected_id()

    list(
      version = "3.3.42",
      schema_version = 4L,
      app = "ggplot GUI",
      project_name = input$project_name,
      data_text = input$text,
      reshape = list(
        enabled = input$reshape_wide,
        row_id = input$reshape_row_id,
        columns = input$reshape_columns,
        x_name = input$reshape_x_name,
        y_name = input$reshape_y_name
      ),
      mapping = list(
        x = resolved_xvar(),
        y = resolved_yvar(),
        position = effective_position_var(dat()),
        color = input$colorvar,
        linetype = input$linetypevar %||% "__color__",
        shape = input$shapevar %||% "__color__",
        id = input$idvar,
        facet = input$facetvar,
        external_error = input$external_error_col %||% "",
        external_ymin = input$external_ymin_col %||% "",
        external_ymax = input$external_ymax_col %||% ""
      ),
      plot = list(
        type = input$plot_type,
        summary = input$summary_type,
        summary_unit = input$summary_unit %||% "row",
        external_error_mode = input$external_error_mode %||% "none",
        show_raw = input$show_raw,
        connect_id = input$connect_id,
        scatter_connect_mode = input$scatter_connect_mode %||% "none",
        line_breaks = line_break_clean(line_break_state())
      ),
      labels = list(
        xlab = normalize_multiline_label(input$xlab),
        ylab = normalize_multiline_label(input$ylab),
        title = input$title,
        ymin = input$ymin,
        ymax = input$ymax,
        y_top_to_tick = input$y_top_to_tick
      ),
      export = list(
        mode = "follow_plot",
        reference_res = 120
      ),
      style = style_settings(),
      statistics_recipes = stats_recipes_for_project(),
      statistics_selected_id = stats_selected_id_for_project(),
      ui_snapshot = graph_capture_editor_ui_snapshot()
    )
  })

  # Live edits are canonical only when value replay/style application is idle.
  # The outer persistent-Editor callback still arbitrates Graph ownership, so
  # there is no browser semantic comparison or post-replay retry here.
  project_commit_candidate <- reactive({
    list(generation = graph_state_replay_generation(),
         replaying = graph_state_replay_active(), state = project_settings())
  })
  project_settings_for_commit <- shiny::debounce(project_commit_candidate, millis = 200)
  observe({
    candidate <- project_settings_for_commit()
    if (!graph_commit_candidate_current(candidate,
        isolate(graph_state_replay_generation()), isolate(graph_state_replay_active()))) return()
    state_now <- candidate$state
    if (!is.function(on_state_change)) return()
    if (isTRUE(isolate(graph_state_replay_active()))) return()
    if (isTRUE(restoring_style_state())) return()

    tryCatch(
      {
        on_state_change(state_now)
        attached_state_seed(state_now)
      },
      error = function(e) diag("STATE-COMMIT", paste0("callback error: ", conditionMessage(e)))
    )
  }, priority = -50)
