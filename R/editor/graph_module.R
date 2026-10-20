# ============================================================
# Independent Graph module server
# Each module owns its own input/reactive/style/data state.
# ============================================================

graphServer <- function(id, style_clipboard = NULL, diag_log = NULL, ui_preseeded = FALSE, on_state_change = NULL, profile = c("full", "figure_controls"), render_gate = NULL, persistent_shell = FALSE, shared_style_library = NULL, on_shared_style_library_change = NULL, on_shared_style_library_open = NULL, browser_patch_override = NULL, on_data_document_patch = NULL, on_plot_filter_commit = NULL, activation_is_current = NULL, state_capture_deferred = function(generation) FALSE) {
  editor_profile <- graph_editor_profile(match.arg(profile))
  init_timing_outer_ms <- as.numeric(proc.time()[["elapsed"]]) * 1000
  init_timing_last_ms <- init_timing_outer_ms
  init_timing_emit <- function(mark, detail = NULL) {
    now <- as.numeric(proc.time()[["elapsed"]]) * 1000
    if (is.function(diag_log)) {
      msg <- paste0(
        "mark=", mark,
        " delta_prev_ms=", sprintf("%.1f", now - init_timing_last_ms),
        " delta_outer_ms=", sprintf("%.1f", now - init_timing_outer_ms)
      )
      if (!is.null(detail) && nzchar(as.character(detail)[1])) msg <- paste0(msg, " ", as.character(detail)[1])
      diag_log("INIT-TIMING", msg, id = id)
    }
    init_timing_last_ms <<- now
    invisible(now)
  }
  init_timing_emit("OUTER-ENTER")
  init_timing_emit("MODULESERVER-CALL-BEGIN")
  module_result <- moduleServer(id, function(input, output, session) {

  init_timing_emit("INNER-ENTER", "moduleServer callback entered")

  diag <- function(tag, ...) {
    if (is.function(diag_log)) diag_log(tag, ..., id = id)
    invisible(NULL)
  }
  diag("MODULE", paste0("graphServer entered ui_preseeded=", isTRUE(ui_preseeded),
                          " profile=", editor_profile$name, " replay_only=TRUE"))
  init_timing_emit("DIAG-READY")

  # server.Rからsession単位の共有clipboardを受け取る。
  # 単独利用時にも壊れないようfallbackを持つ。
  if (is.null(style_clipboard) || !is.function(style_clipboard)) {
    style_clipboard <- reactiveVal(NULL)
  }

  # Shared Label / Style Library is session/project state. Only the persistent
  # interactive Graph Editor receives the live project reactive/callback;
  # the persistent Graph Editor and Figure snapshot editor use this isolated
  # fallback so they remain read-only with respect to the central Library.
  if (is.null(shared_style_library) || !is.function(shared_style_library)) {
    shared_style_library <- reactiveVal(shared_style_default_library())
  }
  if (!is.function(on_shared_style_library_change)) {
    on_shared_style_library_change <- NULL
  }

  # external transaction-level render gate. The ordinary Graph module
  # defaults to open; the persistent single Editor receives a reactiveVal from
  # server.R that stays closed throughout HYDRATING/SYNC and opens only after
  # the canonical READY snapshot has been committed. This prevents intermediate
  # Mapping/reshape/style input updates from rebuilding or drawing the Plot.
  if (is.null(render_gate) || !is.function(render_gate)) {
    render_gate <- reactiveVal(TRUE)
  }

  # Data editing uses one explicit Graph-owned document transport. Browser
  # patches carry graph_id/generation/seq; ownership is never inferred from the
  # currently selected Graph when a delayed edit arrives.
  if (!is.function(on_data_document_patch)) {
    on_data_document_patch <- NULL
  }

  # normal Graph switches replay one saved GraphState into this
  # persistent Editor. These transaction values exist before data/style observers
  # are installed so those observers can cheaply suppress auto-default work while
  # a replay batch is crossing the browser.
  graph_mapping_replay_plan <- reactiveVal(NULL)
  graph_state_replay_active <- reactiveVal(FALSE)
  graph_state_replay_target <- reactiveVal(NULL)
  graph_state_replay_generation <- reactiveVal(0L)
  graph_editor_activation_generation <- reactiveVal(0L)
  graph_activation_current <- function(generation = isolate(graph_editor_activation_generation())) {
    if (!graph_editor_profile_has(editor_profile, "full_shell")) return(TRUE)
    is.function(activation_is_current) && isTRUE(activation_is_current(as.integer(generation)))
  }
  graph_state_replay_completed_generation <- reactiveVal(0L)
  graph_state_replay_error <- reactiveVal(NULL)

  # Bounded cold-replay diagnostics. This is deliberately non-reactive and is
  # enabled only for the selected Graph replay inside a Project-load lock. It
  # observes evaluation counts/timing without changing any output suspension,
  # dependency, owner, or replay scheduling rule.
  graph_cold_diag <- new.env(parent = emptyenv())
  graph_cold_diag$active <- FALSE
  graph_cold_diag$generation <- 0L
  graph_cold_diag$started_at <- NA_real_
  graph_cold_diag$stats <- list()

  graph_cold_diag_begin <- function(generation, enabled = FALSE) {
    graph_cold_diag$active <- isTRUE(enabled) && graph_editor_profile_has(editor_profile, "full_shell")
    graph_cold_diag$generation <- as.integer(generation %||% 0L)
    graph_cold_diag$started_at <- proc.time()[["elapsed"]]
    graph_cold_diag$stats <- list()
    if (isTRUE(graph_cold_diag$active)) {
      diag("COLD-REPLAY-DIAG", paste0("BEGIN generation=", graph_cold_diag$generation))
    }
    invisible(graph_cold_diag$active)
  }

  graph_cold_diag_record <- function(name, elapsed_ms = 0, detail = "") {
    if (!isTRUE(graph_cold_diag$active)) return(invisible(FALSE))
    key <- as.character(name %||% "unknown")[[1]]
    old <- graph_cold_diag$stats[[key]] %||% list(count = 0L, total_ms = 0, max_ms = 0, details = character(0))
    ms <- suppressWarnings(as.numeric(elapsed_ms %||% 0)[[1]])
    if (!is.finite(ms)) ms <- 0
    old$count <- as.integer(old$count %||% 0L) + 1L
    old$total_ms <- as.numeric(old$total_ms %||% 0) + ms
    old$max_ms <- max(as.numeric(old$max_ms %||% 0), ms)
    if (nzchar(detail)) old$details <- unique(c(as.character(old$details %||% character(0)), detail))
    graph_cold_diag$stats[[key]] <- old
    invisible(TRUE)
  }

  graph_cold_diag_measure <- function(name, fn, detail = "") {
    if (!isTRUE(graph_cold_diag$active)) return(fn())
    t0 <- proc.time()[["elapsed"]]
    on.exit(graph_cold_diag_record(name, (proc.time()[["elapsed"]] - t0) * 1000, detail), add = TRUE)
    fn()
  }

  graph_cold_diag_boundary <- function(phase) {
    if (!isTRUE(graph_cold_diag$active)) return(invisible(FALSE))
    elapsed <- (proc.time()[["elapsed"]] - graph_cold_diag$started_at) * 1000
    diag("COLD-REPLAY-FLUSH", paste0("phase=", phase, " generation=", graph_cold_diag$generation,
      " elapsed_ms=", round(elapsed, 1)))
    invisible(TRUE)
  }

  graph_cold_diag_end <- function(reason = "complete") {
    if (!isTRUE(graph_cold_diag$active)) return(invisible(FALSE))
    keys <- sort(names(graph_cold_diag$stats))
    for (key in keys) {
      z <- graph_cold_diag$stats[[key]]
      diag("COLD-REPLAY-EVAL", paste0(
        "name=", key,
        " count=", as.integer(z$count %||% 0L),
        " total_ms=", round(as.numeric(z$total_ms %||% 0), 1),
        " max_ms=", round(as.numeric(z$max_ms %||% 0), 1),
        if (length(z$details %||% character(0))) paste0(" detail={", paste(z$details, collapse = ","), "}") else ""
      ))
    }
    graph_cold_diag_boundary(paste0("END reason=", reason))
    graph_cold_diag$active <- FALSE
    invisible(TRUE)
  }

  # make_plot() is invalidated by one explicit semantic revision, not by every
  # Shiny input it reads while building ggplot. Graph switches release the
  # already-accepted canonical RenderState once; ordinary READY user edits
  # advance the same revision from live project_settings().
  plot_build_revision <- reactiveVal(0L)
  plot_build_render_state <- reactiveVal(NULL)
  # Transaction gates control permission, not plot invalidation. While a Graph
  # is attached we hold one pending canonical target. When the outer Editor
  # transaction accepts READY and opens the gate, that target is released once.
  # Only one completed plot is retained, so memory does not grow with Graph count.
  plot_build_pending <- reactiveVal(FALSE)
  plot_last_built_render_state <- reactiveVal(NULL)
  plot_last_success_revision <- reactiveVal(NA_integer_)
  plot_last_success_object <- new.env(parent = emptyenv())
  plot_last_success_object$value <- NULL

  # Dynamic UI generated inside moduleServer also needs namespace wrappers.
  textInput <- function(inputId, ...) shiny::textInput(session$ns(inputId), ...)
  textAreaInput <- function(inputId, ...) shiny::textAreaInput(session$ns(inputId), ...)
  selectInput <- function(inputId, ...) shiny::selectInput(session$ns(inputId), ...)
  checkboxInput <- function(inputId, ...) shiny::checkboxInput(session$ns(inputId), ...)
  checkboxGroupInput <- function(inputId, ...) shiny::checkboxGroupInput(session$ns(inputId), ...)
  sliderInput <- function(inputId, ...) shiny::sliderInput(session$ns(inputId), ...)
  numericInput <- function(inputId, ...) shiny::numericInput(session$ns(inputId), ...)
  actionButton <- function(inputId, ...) shiny::actionButton(session$ns(inputId), ...)
  downloadButton <- function(outputId, ...) shiny::downloadButton(session$ns(outputId), ...)
  fileInput <- function(inputId, ...) shiny::fileInput(session$ns(inputId), ...)
  uiOutput <- function(outputId, ...) shiny::uiOutput(session$ns(outputId), ...)
  plotOutput <- function(outputId, ...) shiny::plotOutput(session$ns(outputId), ...)
  tableOutput <- function(outputId, ...) shiny::tableOutput(session$ns(outputId), ...)
  verbatimTextOutput <- function(outputId, ...) shiny::verbatimTextOutput(session$ns(outputId), ...)
  colourInput <- function(inputId, ...) colourpicker::colourInput(session$ns(inputId), ...)


  init_timing_emit("HELPERS-BEGIN")
  sys.source(file.path(getwd(), "R/editor/runtime/graph_editor_primitives_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/editor/runtime/graph_helpers_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/editor/runtime/graph_browser_patch_bridge_runtime.R"), envir = environment())

  # Figure Controls use the same browser working-copy model as the Full
  # Editor. Their frozen Figure-owned GraphState remains the base; only the
  # profile-owned values below are overlaid. One namespaced patch input carries
  # user edits, so hydration never has to replay 14 bound inputs through Shiny.
  profile_browser_values <- reactiveVal(NULL)
  profile_browser_paths <- reactiveVal(NULL)
  if (graph_editor_profile_is_figure(editor_profile)) {
    browser_patch_override <- function() {
      values <- profile_browser_values()
      paths <- profile_browser_paths()
      if (!is.list(values) || !is.list(paths)) return(NULL)
      list(active = TRUE, graphId = id, revision = 0L, values = values, paths = paths)
    }
    observeEvent(input$graph_profile_browser_patch, {
      req <- input$graph_profile_browser_patch
      if (!is.list(req) || isTRUE(graph_state_replay_active())) return()
      key <- as.character(req$key %||% "")[[1]]
      paths <- isolate(profile_browser_paths())
      values <- isolate(profile_browser_values())
      if (!nzchar(key) || !is.list(paths) || !key %in% names(paths) || !is.list(values)) return()
      value <- req$value
      if (key %in% c("reshape_columns", "line_breaks")) {
        value <- as.character(unlist(value %||% character(0), use.names = FALSE))
      } else {
        previous <- values[[key]]
        normalized <- graph_normalize_browser_input_value(key, value, previous = previous)
        if (!isTRUE(normalized$ok)) return()
        value <- normalized$value
      }
      # Width/height slider + direct numeric inputs are aliases of one canonical
      # Figure appearance path. Keep both working-copy aliases coherent so the
      # later overlay cannot let a stale sibling overwrite the user's edit.
      if (key %in% c("plot_width_px", "plot_width_px_direct")) {
        values$plot_width_px <- value
        values$plot_width_px_direct <- value
      } else if (key %in% c("plot_height_px", "plot_height_px_direct")) {
        values$plot_height_px <- value
        values$plot_height_px_direct <- value
      } else {
        values[key] <- list(value)
      }
      profile_browser_values(values)
      diag("BROWSER-PATCH", paste0("profile=figure_controls key=", key, " accepted=TRUE"))
    }, ignoreInit = TRUE, priority = 160)
  }
  sys.source(file.path(getwd(), "R/editor/runtime/graph_slot_pool_runtime.R"), envir = environment())
  init_timing_emit("DATA-BEGIN")
  sys.source(file.path(getwd(), "R/data/runtime/graph_data_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/data/runtime/graph_plot_filter_runtime.R"), envir = environment())
  init_timing_emit("ORDER-UI-BEGIN")
  sys.source(file.path(getwd(), "R/mapping/runtime/graph_order_ui_runtime.R"), envir = environment())
  init_timing_emit("STYLE-UI-BEGIN")
  sys.source(file.path(getwd(), "R/style/runtime/graph_style_ui_runtime.R"), envir = environment())
  if (graph_editor_profile_has(editor_profile, "shared_style")) {
    sys.source(file.path(getwd(), "R/style/runtime/graph_shared_style_runtime.R"), envir = environment())
  }
  init_timing_emit("PREPARED-DATA-BEGIN")
  sys.source(file.path(getwd(), "R/data/runtime/graph_prepared_data_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/mapping/runtime/graph_mapping_diagnostics_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/plot/line/graph_line_connection_runtime.R"), envir = environment())
  init_timing_emit("PLOT-BUILDER-BEGIN")

  # ============================================================
  # Runtime components
  # ============================================================
  # graphServer remains the owner environment. Large, self-contained
  # runtime sections are sourced into this exact local environment so this is a
  # source-organization refactor only: no reactive ownership or dependency is
  # changed by the split.
  sys.source(file.path(getwd(), "R/plot/runtime/graph_plot_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/plot/runtime/graph_output_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/style/runtime/graph_style_persistence_runtime.R"), envir = environment())
  if (graph_editor_profile_has(editor_profile, "statistics")) {
    init_timing_emit("STATISTICS-BEGIN")
    sys.source(file.path(getwd(), "R/statistics/graph_statistics_runtime.R"), envir = environment())
  } else {
    init_timing_emit("STATISTICS-SKIP", paste0("profile=", editor_profile$name))
  }
  sys.source(file.path(getwd(), "R/editor/runtime/server_graph_state_replay_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/state/runtime/graph_state_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/state/runtime/graph_state_boundary_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/diagnostics/graph_render_error_runtime.R"), envir = environment())
  install_graph_render_revision_runtime()

  # ============================================================
  # Downloads
  # ============================================================
  # Export geometry follows the on-screen Plot device (renderPlot res = 120).
  # This keeps aspect ratio, text/line proportions, and layout consistent.
  export_reference_res <- 120

  output$download_png <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".png"),
    content = function(file) {
      dims <- plot_total_dimensions()
      app_save_plot_png(
        panel_sized_plot(), file,
        width_px = dims$width, height_px = dims$height, res = export_reference_res
      )
    }
  )

  output$download_pdf <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".pdf"),
    content = function(file) {
      dims <- plot_total_dimensions()
      ggsave(
        file,
        plot = panel_sized_plot(),
        width = dims$width / export_reference_res,
        height = dims$height / export_reference_res,
        units = "in",
        device = grDevices::cairo_pdf
      )
    }
  )

  output$download_svg <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".svg"),
    content = function(file) {
      dims <- plot_total_dimensions()
      svglite::svglite(
        file,
        width = dims$width / export_reference_res,
        height = dims$height / export_reference_res
      )
      dev_id <- grDevices::dev.cur()
      closed <- FALSE
      on.exit({
        if (!closed && identical(grDevices::dev.cur(), dev_id)) {
          try(grDevices::dev.off(), silent = TRUE)
        }
      }, add = TRUE)
      print(panel_sized_plot())
      grDevices::dev.off()
      closed <- TRUE
      norm <- export_text_normalize_utf8_file(file)
      if (isTRUE(norm$ok) && norm$replacements > 0L) {
        diag("EXPORT-TEXT-NORMALIZE", paste0("format=svg replacements=", norm$replacements))
      }
    }
  )

  output$download_pptx <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".pptx"),
    content = function(file) {
      dims <- plot_total_dimensions()
      pptx_write_ggplot_editable(
        file, panel_sized_plot(),
        width_px = dims$width, height_px = dims$height,
        reference_res = export_reference_res,
        label = "ggplot-editable-graph-module"
      )
    }
  )

  # Figure -> Graph Apply is owned by the server-level canonical Registry
  # transaction in R/server/figure/server_figure_controls_runtime.R. graphServer no longer
  # carries a second UI-input commit protocol for Figure overrides.


  init_timing_emit("MODULE-API-BEGIN")

  module_api <- list(
    # 未初期化Graphは、ブラウザinputではなく保存済みstateをそのまま返す。
    state = reactive({
      # While a value replay is crossing the browser, canonical GraphState is
      # already authoritative. Otherwise expose the arbitration snapshot.
      if (isTRUE(graph_state_replay_active()) && is.list(graph_state_replay_target())) {
        return(graph_state_replay_target())
      }
      project_settings()
    }),

    # Commit the current dynamic label input before a Graph boundary captures
    # the old owner; normal typing is still settled by the debounced observer.
    flush_display_label_inputs = function() display_label_flush_before_graph_switch(),

    # Browser-owned title/axis controls are committed outside graphServer. The
    # outer canonical patch runtime calls this only after a real user patch has
    # been accepted, converting that explicit action into one Shared Style
    # writeback event without observing programmatic state changes.
    shared_style_user_edit = function(reason = "browser-edit") {
      shared_style_mark_user_edit(reason)
    },

    # Figure -> Graph workspace return may rebind dynamic Shared Style inputs
    # without changing canonical GraphState. Rebuild only that small binding UI
    # from the Graph-owned reactive state so browser lifecycle defaults cannot
    # remain visible. This does not replay the Graph or rebuild other Style UI.
    refresh_shared_style_binding_ui = function(reason = "workspace-resume") {
      shared_style_binding_ui_epoch(as.integer(isolate(shared_style_binding_ui_epoch()) %||% 0L) + 1L)
      diag(
        "SHARED-STYLE-UI",
        paste0(
          "refresh reason=", as.character(reason %||% "workspace-resume")[[1]],
          " enabled=", isTRUE(shared_style_normalize_binding(isolate(shared_style_binding()))$enabled)
        )
      )
      invisible(TRUE)
    },

    # SVG一括出力ではreadyなGraphだけPlotを生成する。
    plot = reactive({
      diag("PLOT-CONSUMER", "request=module-plot")
      panel_sized_plot()
    }),

    # Formal boundary for the experimental Figure asset renderer. Figure code
    # no longer needs to know how this Graph was built; it asks for a component
    # bundle and may cache only its preview representation. The ggplot object
    # remains authoritative for export and future style overrides.
    figure_components = reactive({
      diag("PLOT-CONSUMER", "request=figure-components")
      list(
        source_type = "internal_graph",
        plot = make_plot(),
        meta = list(
          panel_width_px = as.numeric(effective_plot_width_px()),
          panel_height_px = as.numeric(effective_plot_height_px()),
          reference_res = 120
        ),
        capabilities = list(
          vector_preview = TRUE,
          style_override = TRUE,
          legend_component = FALSE,
          external_asset = FALSE
        )
      )
    }),

    export = reactive({
      diag("PLOT-CONSUMER", "request=export-meta")
      dims <- plot_total_dimensions()
      list(
        plot_width_px = as.numeric(dims$width),
        plot_height_px = as.numeric(dims$height),
        panel_width_px = as.numeric(effective_plot_width_px()),
        panel_height_px = as.numeric(effective_plot_height_px()),
        reference_res = 120
      )
    }),


    # Project persistence stores only reproducible Statistics recipes. Results
    # are deliberately excluded and are recalculated when Statistics is opened.
    statistics_recipes = reactive({
      if (graph_editor_profile_has(editor_profile, "statistics")) {
        return(normalize_stats_recipes(stats_recipes()))
      }
      base <- attached_state_seed()
      if (is.list(base) && is.list(base$statistics_recipes)) base$statistics_recipes else list()
    }),

    ready = reactive({
      # READY now means only that the single value-replay transaction has
      # completed. Canonical GraphState is not re-read/reconciled in-browser.
      !isTRUE(graph_state_replay_active()) && is.null(graph_state_replay_error())
    }),

    # Startup adoption uses the same explicit Data Document lease channel as
    # ordinary Graph replay, but does not replay the already-pristine browser
    # controls back onto themselves.
    hydrate_data_document = function(state, graph_id, generation) {
      graph_replay_hydrate_data_document(
        state,
        transaction = list(id = as.character(graph_id %||% "")[[1]], generation = as.integer(generation %||% 0L)),
        replay_generation = as.integer(generation %||% 0L)
      )
    },

    # Startup pristine adoption skips normal Graph replay because the one
    # persistent Editor DOM is already showing the captured default state.
    # The static shell intentionally starts data-derived selects with empty
    # choices, however, so publish exactly that derived control context once.
    # Reuse the normal replay builders rather than duplicating Mapping/level
    # choice logic, and keep Data Document on its dedicated transport above.
    hydrate_startup_data_context = function(state, graph_id, generation) {
      if (!is.list(state) || !graph_editor_profile_has(editor_profile, "full_shell")) {
        return(invisible(FALSE))
      }
      mapping_plan <- tryCatch(graph_replay_mapping_plan(state), error = function(e) NULL)
      if (!is.list(mapping_plan)) return(invisible(FALSE))
      graph_mapping_replay_plan(mapping_plan)

      # Publish level-derived slot pools under the same activation owner before
      # building/sending the hydration batch, matching normal replay ordering
      # and allowing its poolContexts to describe the just-published leases.
      # No browser ACK is introduced; custom messages are consumed in their
      # queued order.
      graph_browser_direct_publish_pools(state, mapping_plan)
      context <- graph_browser_direct_data_context(state)
      choice_keys <- names(context$choices)
      values <- context$values[intersect(names(context$values), choice_keys)]
      payload <- graph_browser_direct_payload_envelope(
        state, values, context$choices, "delta", choice_keys,
        transaction = list(
          id = as.character(graph_id %||% "")[[1]],
          generation = as.integer(generation %||% 0L)
        )
      )
      session$sendCustomMessage("graph-state-browser-hydrate", app_json_safe_tree(payload))
      diag(
        "DATA-CONTEXT-HYDRATE",
        paste0(
          "queued graph=", as.character(graph_id %||% "")[[1]],
          " scalar_count=", length(payload$values),
          " choice_sets=", length(payload$choices),
          " pool_count=", length(graph_slot_pool_names()),
          " browser_ack=NONE"
        )
      )
      invisible(TRUE)
    },

    # Outer persistent-Editor transaction calls this exactly once after it has
    # accepted the Registry canonical state for the current Graph. This keeps
    # the module's attached safety snapshot and the pending render target on
    # the same accepted state before render_gate is opened.
    accept_canonical = function(state, reason = "outer-ready-accept", seed_render = TRUE) {
      graph_accept_attached_canonical(state, reason = reason, seed_render = seed_render)
    },
    refresh_browser_pools = function(state) {
      plan <- tryCatch(graph_replay_mapping_plan(state), error = function(e) NULL)
      graph_browser_direct_publish_pools(state, plan)
    },
    refresh_browser_hydration = function(state, graph_id = "") {
      if (!is.list(state) || !graph_editor_profile_has(editor_profile, "full_shell")) return(invisible(FALSE))
      mapping_plan <- tryCatch(graph_replay_mapping_plan(state), error = function(e) NULL)
      # A transient malformed/incomplete paste is already handled by the Data
      # validation path. Keep the current browser choices until canonical data
      # becomes valid instead of hydrating a half-built topology.
      if (!is.list(mapping_plan)) return(invisible(FALSE))
      graph_mapping_replay_plan(mapping_plan)
      plan <- graph_editor_replay_plan(NULL, state, editor_profile)
      payload <- graph_browser_direct_hydration_payload(
        state, plan, transaction = list(id = as.character(graph_id %||% "")[1])
      )
      # Same-Graph topology refreshes must not write the potentially very large
      # Ace text back to the browser. The current Ace value is already the user
      # Data Document working copy whose accepted patch produced `state`; only
      # dependent choices/scalars need refreshing. Graph switching restores Data
      # through the explicit Data Document lease channel, never this batch.
      payload$values$text <- NULL
      session$sendCustomMessage("graph-state-browser-hydrate", app_json_safe_tree(payload))
      graph_browser_direct_publish_pools(state, mapping_plan)
      invisible(TRUE)
    },

    render_revision = reactive({ as.integer(plot_render_revision()) }),
    # Figure persistent-editor replay releases exactly one semantic RenderState
    # after browser-direct hydration. This prevents the controls-only editor
    # from leaving an intermediate plot from the previous Figure-owned state.
    release_render_state = function(state, reason = "explicit-release") {
      graph_release_render_revision(state, reason = reason)
    },
    rendered_state = reactive({ last_render_state() }),
    main_tab = reactive({ as.character(input$graph_main_tab %||% "Plot")[1] }),

    # Normal persistent-editor transaction. Canonical GraphState is compared
    # with the state already attached to this persistent DOM and only changed
    # sections are transported. Transport dispatch and completion share one
    # owner; there is no staged restore/reconcile fallback.
    replay_state = function(state, transaction = NULL) {
      if (!is.list(state)) return(invisible(FALSE))
      graph_apply_state_replay(state, transaction = transaction)
    },
    set_activation_generation = function(generation) {
      graph_editor_activation_generation(as.integer(generation))
      invisible(TRUE)
    },
    filter_generation = function() isolate(graph_state_replay_generation()),
    replay_active = reactive({ isTRUE(graph_state_replay_active()) }),
    replay_completed_generation = reactive({ as.integer(graph_state_replay_completed_generation()) }),
    replay_error = reactive({ graph_state_replay_error() })
  )


  init_timing_emit("INNER-RETURN", "module API constructed")
  module_api
  })
  init_timing_emit("MODULESERVER-CALL-END")
  module_result
}
