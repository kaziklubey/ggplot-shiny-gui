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
    plan <- isolate(graph_mapping_replay_plan())

    color <- json_chr(mp$color, "")
    if (identical(color, "__fixed__")) color <- ""

    # Keep saved values as short-lived seeds while ordinary observers process
    # the same replay.  Unlike the old path, the replay itself now sends the
    # target Graph's choice lists together with the selected values.  A switch
    # therefore never asks the browser to select a value against the previous
    # Graph's choices (which could coerce Color/Shape/ID/etc. to empty).
    reshape_restore_seed(if (is.list(plan)) plan$reshape_columns else as.character(r$columns %||% character(0)))
    restore_position_seed(if (is.list(plan)) plan$position else json_chr(mp$position, json_chr(mp$series, "")))
    restore_linetype_seed(if (is.list(plan)) plan$linetype else json_chr(mp$linetype, "__color__"))
    restore_external_error_seed(if (is.list(plan)) plan$external_error else json_chr(mp$external_error, ""))
    restore_external_ymin_seed(if (is.list(plan)) plan$external_ymin else json_chr(mp$external_ymin, ""))
    restore_external_ymax_seed(if (is.list(plan)) plan$external_ymax else json_chr(mp$external_ymax, ""))

    if (is.list(plan)) {
      updateCheckboxGroupInput(
        session, "reshape_columns",
        choices = plan$raw_cols,
        selected = plan$reshape_columns
      )
      updateSelectInput(session, "xvar", choices = plan$cols, selected = plan$x)
      updateSelectInput(session, "yvar", choices = plan$numeric_cols, selected = plan$y)
      updateSelectInput(session, "colorvar", choices = c("使わない（固定）" = "", plan$cols), selected = plan$color)
      updateSelectInput(session, "shapevar", choices = c("Color と同じ" = "__color__", "なし（固定）" = "", plan$cols), selected = plan$shape)
      updateSelectInput(session, "idvar", choices = c("なし" = "", plan$cols), selected = plan$id)
      updateSelectInput(session, "facetvar", choices = c("なし" = "", plan$cols), selected = plan$facet)
      updateSelectInput(session, "groupvar", choices = c("なし" = "", plan$cols), selected = plan$position)
      updateSelectInput(
        session, "linetypevar",
        choices = c("色で分ける要因と同じ" = "__color__", "使わない（固定）" = "", plan$cols),
        selected = plan$linetype
      )
      updateSelectInput(session, "external_error_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_error)
      updateSelectInput(session, "external_ymin_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_ymin)
      updateSelectInput(session, "external_ymax_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_ymax)
      return(invisible(TRUE))
    }

    # Invalid/partial legacy data falls back to value-only updates; the normal
    # data observers will rebuild choices from whatever data can be parsed.
    updateCheckboxGroupInput(session, "reshape_columns", selected = as.character(r$columns %||% character(0)))
    updateSelectInput(session, "xvar", selected = json_chr(mp$x, ""))
    updateSelectInput(session, "yvar", selected = json_chr(mp$y, ""))
    updateSelectInput(session, "colorvar", selected = color)
    updateSelectInput(session, "shapevar", selected = json_chr(mp$shape, "__color__"))
    updateSelectInput(session, "idvar", selected = json_chr(mp$id, ""))
    updateSelectInput(session, "facetvar", selected = json_chr(mp$facet, ""))
    updateSelectInput(session, "groupvar", selected = json_chr(mp$position, json_chr(mp$series, "")))
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

    # Statistics has persistent browser controls just like the Graph Editor.
    # Replace the entire Graph-linked context at the replay boundary so an
    # in-flight restore or stale Analysis from the previous Graph cannot leak
    # into the target Graph. The selected Analysis is Graph-local when saved;
    # older Projects without that field safely fall back to the first recipe.
    stats_replace_graph_context(
      restored = restored,
      preferred_id = cfg$statistics_selected_id %||% NULL,
      legacy_reshape = cfg$reshape %||% list()
    )
    invisible(TRUE)
  }

  graph_replay_finish <- function(generation, token) {
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!identical(as.integer(generation), pending_generation)) return(invisible(FALSE))
    cfg <- isolate(graph_state_replay_target())
    if (!is.list(cfg)) return(invisible(FALSE))

    # ACK follows immediate transport of bound input values (including Ace).
    # Ordinary choices writers were excluded throughout this transaction.
    # Release only after those inputs have crossed the server flush.
    attached_state_seed(cfg)
    graph_state_replay_completed_generation(as.integer(generation))
    graph_state_replay_active(FALSE)
    graph_state_replay_target(NULL)
    graph_state_replay_error(NULL)
    restoring_style_state(FALSE)
    diag("STATE-REPLAY", paste0("READY generation=", generation, " token=", token, " mode=mapping-transaction"))
    invisible(TRUE)
  }

  observeEvent(input$graph_state_replay_ack, {
    ack <- input$graph_state_replay_ack
    if (!is.list(ack)) return()
    generation <- suppressWarnings(as.integer(ack$generation %||% -1L))
    token <- as.character(ack$token %||% "")[1]
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!isTRUE(isolate(graph_state_replay_active())) || !identical(generation, pending_generation)) return()
    if (!is.null(ack$error)) {
      graph_state_replay_error(as.character(ack$error))
      diag("STATE-REPLAY", paste0("TRANSPORT-ERROR ", ack$error))
      return()
    }
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
    graph_mapping_replay_plan(graph_replay_mapping_plan(cfg))
    graph_mapping_choices_seed(isolate(graph_mapping_replay_plan()))
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
          ackId = session$ns("graph_state_replay_ack"),
          inputPrefix = session$ns(""),
          requiredInputs = session$ns(c("text", "reshape_wide", "reshape_row_id",
            "reshape_columns", "reshape_x_name", "reshape_y_name", "xvar", "yvar",
            "colorvar", "shapevar", "idvar", "facetvar", "groupvar", "linetypevar",
            "external_error_col", "external_ymin_col", "external_ymax_col"))
        )
      )
      diag("STATE-REPLAY", paste0("apply fields=batch generation=", generation, " completion-barrier requested"))
      invisible(NULL)
    }, once = TRUE)
    invisible(TRUE)
  }
