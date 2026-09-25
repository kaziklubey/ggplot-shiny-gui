# v4 architecture — canonical GraphState capture for one persistent Editor.
# Full Editor owns Data/reshape/Statistics. Figure Controls own only the
# shared editable plot sections and overlay those sections onto their attached
# Figure-owned GraphState. Missing Figure-only browser inputs therefore never
# erase protected canonical state.

  graph_live_shared_state <- function() {
    live <- list(
      version = "4.0-rc2",
      schema_version = 5L,
      app = "ggplot GUI",
      mapping = list(
        x = resolved_xvar(),
        y = resolved_yvar(),
        position = effective_position_var(dat()),
        color = graph_mapping_value("color", input$colorvar %||% ""),
        linetype = graph_mapping_value("linetype", input$linetypevar %||% "__color__"),
        shape = graph_mapping_value("shape", input$shapevar %||% "__color__"),
        line_series_mode = graph_mapping_value("line_series_mode", input$line_series_mode %||% "auto"),
        line_series_var = graph_mapping_value("line_series_var", input$line_series_var %||% ""),
        id = graph_mapping_value("id", input$idvar %||% ""),
        facet = graph_mapping_value("facet", input$facetvar %||% ""),
        external_error = graph_mapping_value("external_error", input$external_error_col %||% ""),
        external_ymin = graph_mapping_value("external_ymin", input$external_ymin_col %||% ""),
        external_ymax = graph_mapping_value("external_ymax", input$external_ymax_col %||% "")
      ),
      plot = list(
        type = graph_plot_value("type", input$plot_type %||% "line"),
        summary = graph_plot_value("summary", input$summary_type %||% "mean"),
        summary_unit = graph_plot_value("summary_unit", input$summary_unit %||% "row"),
        external_error_mode = graph_plot_value("external_error_mode", input$external_error_mode %||% "none"),
        show_raw = graph_plot_value("show_raw", input$show_raw),
        connect_id = graph_plot_value("connect_id", input$connect_id),
        scatter_connect_mode = graph_plot_value("scatter_connect_mode", input$scatter_connect_mode %||% "none"),
        line_breaks = line_break_clean(line_break_state())
      ),
      labels = list(
        xlab = normalize_multiline_label(graph_label_value("xlab", input$xlab %||% "")),
        ylab = normalize_multiline_label(graph_label_value("ylab", input$ylab %||% "")),
        title = graph_label_value("title", input$title %||% ""),
        ymin = graph_label_value("ymin", input$ymin %||% ""),
        ymax = graph_label_value("ymax", input$ymax %||% ""),
        y_top_to_tick = graph_label_value("y_top_to_tick", input$y_top_to_tick)
      ),
      export = list(
        mode = "follow_plot",
        reference_res = 120
      ),
      style = style_settings()
    )
    # RC5 browser-patch PoC: once a path is browser-owned, canonical accepted
    # values overlay the stale Shiny input mirror. This prevents a later edit
    # to an unrelated control from rolling the browser-patched value back.
    graph_apply_browser_patch_overlay(live)
  }

  project_settings <- reactive({
    if (isTRUE(graph_state_replay_active())) return(graph_state_replay_target())

    live <- graph_live_shared_state()

    if (graph_editor_profile_has(editor_profile, "full_shell")) {
      # Recipe add/delete/rename lives in stats_recipes(), while selected
      # Analysis fields are ordinary Shiny inputs. Keep explicit dependencies
      # only in the Full Editor profile.
      stats_recipes()
      stats_selected_id()

      live$project_name <- graph_browser_owned_scalar("project_name", input$project_name %||% "")
      # Data/reshape are canonical Graph-owned fields. Browser patch acceptance
      # updates attached_state_seed() before this coalesced snapshot runs, so do
      # not reconstruct them from delayed Shiny mirrors of Ace/reshape controls.
      canonical_data <- attached_state_seed()
      if (is.list(canonical_data)) {
        live$data_text <- graph_state_scalar(canonical_data$data_text, "")
        live$reshape <- canonical_data$reshape %||% list()
      } else {
        # Startup/replay normally returns above before reaching this branch. Keep
        # a defensive fallback for an unexpectedly unattached Full Editor.
        live$data_text <- input$text
        live$reshape <- list(
          enabled = input$reshape_wide,
          row_id = input$reshape_row_id,
          columns = input$reshape_columns,
          x_name = input$reshape_x_name,
          y_name = input$reshape_y_name
        )
      }
      live$statistics_recipes <- stats_recipes_for_project()
      live$statistics_selected_id <- stats_selected_id_for_project()
      live$ui_snapshot <- graph_capture_editor_ui_snapshot()
      # Browser-owned Full-Editor controls include Data/reshape fields. Apply the
      # accepted canonical overlay after those profile-owned sections are added;
      # otherwise stale Shiny values can reappear as reshape.columns false diffs.
      live <- graph_apply_browser_patch_overlay(live)
      return(live)
    }

    # Figure Controls: start from the attached frozen/canonical GraphState and
    # replace only profile-owned sections (mapping/plot/labels/style). Data,
    # reshape, Statistics and Full-Editor UI snapshot remain untouched.
    base <- attached_state_seed()
    req(is.list(base))
    graph_state_overlay_for_profile(base, live, editor_profile)
  })

  # Live edits are canonical only when value replay/style application is idle.
  # The outer persistent-Editor callback still arbitrates Graph ownership, so
  # there is no browser semantic comparison or post-replay retry here.
  project_commit_candidate <- reactive({
    list(generation = graph_state_replay_generation(),
         replaying = graph_state_replay_active(), state = project_settings())
  })
  graph_rapid_render_debounce_ms <- suppressWarnings(as.integer(get0(
    "GRAPH_RAPID_RENDER_DEBOUNCE_MS", ifnotfound = 180L, inherits = TRUE
  )))
  if (!is.finite(graph_rapid_render_debounce_ms) || graph_rapid_render_debounce_ms < 50L) {
    graph_rapid_render_debounce_ms <- 180L
  }
  project_settings_for_commit <- shiny::debounce(
    project_commit_candidate, millis = graph_rapid_render_debounce_ms
  )
  observe({
    candidate <- project_settings_for_commit()
    if (!graph_commit_candidate_current(candidate,
        isolate(graph_state_replay_generation()), isolate(graph_state_replay_active()))) return()
    state_now <- candidate$state
    if (isTRUE(isolate(graph_state_replay_active()))) return()
    if (isTRUE(restoring_style_state())) return()

    tryCatch(
      {
        if (is.function(on_state_change)) on_state_change(state_now)
        # RC13 rapid-edit contract: canonical/module attachment is updated for
        # the latest coalesced state before the expensive plot revision is
        # released.  Spinner holds, text typing, color/palette experiments and
        # persistent slot-pool edits therefore collapse to one rebuild after
        # the configured short project-state quiet period.
        attached_state_seed(state_now)
        if (exists("graph_release_render_revision", mode = "function", inherits = TRUE) &&
            isTRUE(render_gate()) && !isTRUE(graph_state_replay_active()) &&
            !isTRUE(plot_build_pending())) {
          graph_release_render_revision(state_now, reason = "live-edit-coalesced")
        }
      },
      error = function(e) diag("STATE-COMMIT", paste0("callback error: ", conditionMessage(e)))
    )
  }, priority = -50)
