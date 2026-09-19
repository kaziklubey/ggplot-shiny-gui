# v3.73.2.18: normal Graph state replay for the one persistent Editor.
# Sourced inside graphServer after data/style/statistics runtimes are installed.
# This runtime is the only GraphState-to-Editor hydration path. It uses one
# value batch plus one browser completion barrier—no staged restore, semantic
# comparison, retry, or per-Graph DOM/module instances.

  graph_capture_editor_ui_snapshot <- function() {
    graph_ui_snapshot_normalize(list(
      schema_version = 2L,
      selections = list(
        graph_main_tab = as.character(input$graph_main_tab %||% "Plot")[1],
        sticky_plot = isTRUE(input$sticky_plot)
      ),
      panels = list()
    ))
  }

  graph_replay_selected <- function(snapshot, key, fallback = "") {
    z <- snapshot$selections[[key]]
    if (is.null(z) || !length(z)) return(fallback)
    as.character(unlist(z, use.names = FALSE))
  }

  graph_replay_apply_mapping_values <- function(cfg) {
    mp <- cfg$mapping %||% list()
    r <- cfg$reshape %||% list()

    color <- json_chr(mp$color, "")
    if (identical(color, "__fixed__")) color <- ""

    # The normal data observers own choice lists.  Keep only the saved values
    # as short-lived seeds while raw data / Wide→Long choices are changing, so
    # those ordinary observers do not replace the requested value with a
    # default before the browser has applied the replay batch.
    reshape_restore_seed(as.character(r$columns %||% character(0)))
    restore_position_seed(json_chr(mp$position, json_chr(mp$series, "")))
    restore_linetype_seed(json_chr(mp$linetype, "__color__"))
    restore_external_error_seed(json_chr(mp$external_error, ""))
    restore_external_ymin_seed(json_chr(mp$external_ymin, ""))
    restore_external_ymax_seed(json_chr(mp$external_ymax, ""))

    # Choices/visibility belong to the already-running UI reactive chain.
    # Replay restores only saved values; raw_dat()/dat()/plot_type observers
    # update the available choices exactly as they do for ordinary user edits.
    updateCheckboxGroupInput(
      session, "reshape_columns",
      selected = as.character(r$columns %||% character(0))
    )
    updateSelectInput(session, "xvar", selected = json_chr(mp$x, ""))
    updateSelectInput(session, "yvar", selected = json_chr(mp$y, ""))
    updateSelectInput(session, "colorvar", selected = color)
    updateSelectInput(session, "shapevar", selected = json_chr(mp$shape, "__color__"))
    updateSelectInput(session, "idvar", selected = json_chr(mp$id, ""))
    updateSelectInput(session, "facetvar", selected = json_chr(mp$facet, ""))
    updateSelectInput(
      session, "groupvar",
      selected = json_chr(mp$position, json_chr(mp$series, ""))
    )
    updateSelectInput(session, "linetypevar", selected = json_chr(mp$linetype, "__color__"))
    updateSelectInput(session, "external_error_col", selected = json_chr(mp$external_error, ""))
    updateSelectInput(session, "external_ymin_col", selected = json_chr(mp$external_ymin, ""))
    updateSelectInput(session, "external_ymax_col", selected = json_chr(mp$external_ymax, ""))
    invisible(TRUE)
  }

  graph_replay_apply_scalar_controls <- function(cfg) {
    r <- cfg$reshape %||% list()
    pl <- cfg$plot %||% list()
    lb <- cfg$labels %||% list()

    # UI-only view state is replayed from the snapshot alongside canonical
    # Graph fields so persistent DOM does not inherit the previous Graph's tab
    # or sticky-view preference.
    snap <- graph_ui_snapshot_normalize(cfg$ui_snapshot)
    updateTabsetPanel(
      session, "graph_main_tab",
      selected = graph_replay_selected(snap, "graph_main_tab", "Plot")[1]
    )
    sticky_saved <- snap$selections$sticky_plot
    if (!is.null(sticky_saved) && length(sticky_saved)) {
      updateCheckboxInput(session, "sticky_plot", value = isTRUE(sticky_saved[[1]]))
    }

    if (!is.null(cfg$project_name)) updateTextInput(session, "project_name", value = json_chr(cfg$project_name))
    if (!is.null(cfg$data_text)) shinyAce::updateAceEditor(session, "text", value = json_chr(cfg$data_text))

    updateCheckboxInput(session, "reshape_wide", value = isTRUE(r$enabled))
    updateCheckboxInput(session, "reshape_row_id", value = isTRUE(r$row_id))
    updateTextInput(session, "reshape_x_name", value = json_chr(r$x_name, "Time"))
    updateTextInput(session, "reshape_y_name", value = json_chr(r$y_name, "Value"))

    target_type <- json_chr(pl$type, "line")
    if (identical(target_type, "violin")) target_type <- "box"
    updateSelectInput(session, "plot_type", selected = target_type)
    updateSelectInput(session, "summary_type", selected = json_chr(pl$summary, "mean"))
    updateRadioButtons(session, "summary_unit", selected = json_chr(pl$summary_unit, "row"))
    updateRadioButtons(session, "external_error_mode", selected = json_chr(pl$external_error_mode, "none"))
    updateCheckboxInput(session, "show_raw", value = isTRUE(pl$show_raw))
    updateCheckboxInput(session, "connect_id", value = isTRUE(pl$connect_id))
    updateRadioButtons(
      session, "scatter_connect_mode",
      selected = json_chr(pl$scatter_connect_mode, if (isTRUE(pl$connect_id)) "id" else "none")
    )

    if (!is.null(lb$xlab)) updateTextAreaInput(session, "xlab", value = json_chr(lb$xlab))
    if (!is.null(lb$ylab)) updateTextAreaInput(session, "ylab", value = json_chr(lb$ylab))
    if (!is.null(lb$title)) updateTextInput(session, "title", value = json_chr(lb$title))
    if (!is.null(lb$ymin)) updateTextInput(session, "ymin", value = json_chr(lb$ymin))
    if (!is.null(lb$ymax)) updateTextInput(session, "ymax", value = json_chr(lb$ymax))
    if (!is.null(lb$y_top_to_tick)) updateCheckboxInput(session, "y_top_to_tick", value = isTRUE(lb$y_top_to_tick))
    invisible(TRUE)
  }

  graph_replay_apply_statistics <- function(cfg) {
    restored <- cfg$statistics_recipes
    if (!is.list(restored)) restored <- list()
    restored <- normalize_stats_recipes(restored, legacy_reshape = cfg$reshape %||% list())
    stats_post_restore_baseline(NULL)
    stats_recipes(restored)
    first_id <- if (length(restored)) names(restored)[1] else NULL
    stats_selected_id(first_id)
    pending_stats_ui_restore(first_id)
    refresh_stats_choices(first_id)
    invisible(TRUE)
  }

  graph_replay_finish <- function(generation, token) {
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!identical(as.integer(generation), pending_generation)) return(invisible(FALSE))
    cfg <- isolate(graph_state_replay_target())
    if (!is.list(cfg)) return(invisible(FALSE))

    # This is a value replay, not a restore/verification transaction. The
    # browser ACK means the persistent controls have accepted the update batch.
    # From here the ordinary reactive graph owns reshape, Mapping choices,
    # visibility and plot errors exactly as it does after a user edit.
    attached_state_seed(cfg)
    graph_state_replay_completed_generation(as.integer(generation))
    graph_state_replay_active(FALSE)
    graph_state_replay_target(NULL)
    graph_state_replay_error(NULL)
    restoring_style_state(FALSE)
    diag("STATE-REPLAY", paste0("READY generation=", generation, " token=", token, " mode=value-only"))
    invisible(TRUE)
  }

  observeEvent(input$graph_state_replay_ack, {
    ack <- input$graph_state_replay_ack
    if (!is.list(ack)) return()
    generation <- suppressWarnings(as.integer(ack$generation %||% -1L))
    token <- as.character(ack$token %||% "")[1]
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!isTRUE(isolate(graph_state_replay_active())) || !identical(generation, pending_generation)) return()
    diag("STATE-REPLAY", paste0("browser-flush complete generation=", generation, " token=", token))
    # The ACK arrives after the browser processed the updateInput batch. Cross
    # one server flush so ordinary reactive observers can settle once before READY.
    session$onFlushed(function() {
      graph_replay_finish(generation, token)
    }, once = TRUE)
  }, ignoreInit = TRUE, priority = 200)

  graph_apply_state_replay <- function(cfg, transaction = NULL) {
    if (!is.list(cfg)) return(invisible(FALSE))
    snapshot <- graph_ui_snapshot_normalize(cfg$ui_snapshot)

    generation <- as.integer(isolate(graph_state_replay_generation()) %||% 0L) + 1L
    graph_state_replay_generation(generation)
    graph_state_replay_error(NULL)
    graph_state_replay_target(cfg)
    graph_state_replay_active(TRUE)
    restoring_style_state(TRUE)
    attached_state_seed(cfg)
    graph_seed_render_target(cfg, reason = "state-replay")

    diag("STATE-REPLAY", paste0("BEGIN generation=", generation))
    apply_ok <- tryCatch({
      graph_replay_apply_scalar_controls(cfg)
      graph_replay_apply_mapping_values(cfg)
      graph_replay_apply_statistics(cfg)
      if (is.list(cfg$style)) {
        apply_style_config(cfg$style, success_message = NULL, release_guard = FALSE, notify = FALSE)
      }
      TRUE
    }, error = function(e) {
      graph_state_replay_error(conditionMessage(e))
      diag("STATE-REPLAY", paste0("APPLY-ERROR generation=", generation, " error=", conditionMessage(e)))
      FALSE
    })
    if (!isTRUE(apply_ok)) {
      graph_state_replay_active(FALSE)
      graph_state_replay_target(NULL)
      # The persistent Editor is not structurally rebuilt after bootstrap.
      # Clear the transient replay error so the outer owner can abort cleanly.
      graph_state_replay_error(NULL)
      restoring_style_state(FALSE)
      return(invisible(FALSE))
    }

    token <- paste0("replay:", generation, ":", as.character((transaction %||% list())$id %||% "graph"))
    panels <- snapshot$panels %||% list()
    session$onFlushed(function() {
      if (!isTRUE(isolate(graph_state_replay_active())) ||
          !identical(as.integer(isolate(graph_state_replay_generation()) %||% -1L), generation)) return(invisible(NULL))
      session$sendCustomMessage(
        "graph-state-replay-complete-request",
        list(
          generation = generation,
          token = token,
          graphId = as.character((transaction %||% list())$id %||% "")[1],
          panels = panels,
          ackId = session$ns("graph_state_replay_ack")
        )
      )
      diag("STATE-REPLAY", paste0("apply fields=batch generation=", generation, " completion-barrier requested"))
      invisible(NULL)
    }, once = TRUE)
    invisible(TRUE)
  }
