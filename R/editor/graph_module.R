# ============================================================
# Independent Graph module server
# Each module owns its own input/reactive/style/data state.
# ============================================================

graphServer <- function(id, style_clipboard = NULL, diag_log = NULL, ui_preseeded = FALSE, on_state_change = NULL, profile = c("full", "figure_controls"), render_gate = NULL, persistent_shell = FALSE, shared_style_library = NULL, on_shared_style_library_change = NULL, statistics_plot_preview = NULL, browser_patch_override = NULL) {
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

  # Shared Label / Style Library is session/project state.  Only the persistent
  # interactive Graph Editor receives the live project reactive/callback;
  # the persistent Graph Editor and Figure snapshot editor use this isolated
  # fallback so they remain read-only with respect to the central Library.
  if (is.null(shared_style_library) || !is.function(shared_style_library)) {
    shared_style_library <- reactiveVal(shared_style_default_library())
  }
  if (!is.function(on_shared_style_library_change)) {
    on_shared_style_library_change <- NULL
  }

  # Statistics uses a separate read-only Plot preview for interpreting test
  # results. The persistent Editor may inject a reactive provider backed by the
  # Graph preview cache; controls-only Figure editing intentionally gets
  # this inert fallback and never depend on workspace preview state.
  if (is.null(statistics_plot_preview) || !is.function(statistics_plot_preview)) {
    statistics_plot_preview <- function() NULL
  }

  # v3.66.3: external transaction-level render gate. The ordinary Graph module
  # defaults to open; the persistent single Editor receives a reactiveVal from
  # server.R that stays closed throughout HYDRATING/SYNC and opens only after
  # the canonical READY snapshot has been committed. This prevents intermediate
  # Mapping/reshape/style input updates from rebuilding or drawing the Plot.
  if (is.null(render_gate) || !is.function(render_gate)) {
    render_gate <- reactiveVal(TRUE)
  }

  # v3.73.2.18: normal Graph switches replay one saved GraphState into this
  # persistent Editor. These transaction values exist before data/style observers
  # are installed so those observers can cheaply suppress auto-default work while
  # a replay batch is crossing the browser.
  graph_mapping_replay_plan <- reactiveVal(NULL)
  graph_state_replay_active <- reactiveVal(FALSE)
  graph_state_replay_target <- reactiveVal(NULL)
  graph_state_replay_generation <- reactiveVal(0L)
  graph_state_replay_completed_generation <- reactiveVal(0L)
  graph_state_replay_error <- reactiveVal(NULL)

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

  # RC12: Figure Controls use the same browser working-copy model as the Full
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
      values[key] <- list(value)
      profile_browser_values(values)
      diag("BROWSER-PATCH", paste0("profile=figure_controls key=", key, " accepted=TRUE"))
    }, ignoreInit = TRUE, priority = 160)
  }
  sys.source(file.path(getwd(), "R/editor/runtime/graph_slot_pool_runtime.R"), envir = environment())
  sys.source(file.path(getwd(), "R/mapping/runtime/graph_mapping_transaction_runtime.R"), envir = environment())
  init_timing_emit("DATA-BEGIN")
  sys.source(file.path(getwd(), "R/data/runtime/graph_data_runtime.R"), envir = environment())
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
  # v3.67.0: graphServer remains the owner environment.  Large, self-contained
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
      graph_editor_arbitration_state_snapshot("module-api-state")
    }),

    # SVG一括出力ではreadyなGraphだけPlotを生成する。
    plot = reactive({
      diag("PLOT-CONSUMER", "request=module-plot")
      panel_sized_plot()
    }),

    # Figure editorでは元ggplotをsnapshotし、Figureセル寸法に合わせて
    # panelサイズだけを非破壊で再指定する。元Graph設定自体は変更しない。
    figure_plot = reactive({
      diag("PLOT-CONSUMER", "request=figure-plot")
      make_plot()
    }),

    # Figure Editor only needs the Graph-side panel dimensions. Returning this
    # lightweight metadata avoids calling plot_total_dimensions(), which would
    # build/draw the full plot once merely to measure legend/axis decorations.
    # Figure itself measures its overridden plot geometry where needed.
    figure_meta = reactive({
      list(
        panel_width_px = as.numeric(effective_plot_width_px()),
        panel_height_px = as.numeric(effective_plot_height_px()),
        reference_res = 120
      )
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


    # Project persistence stores only reproducible Statistics recipes.  Results
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

    # Outer persistent-Editor transaction calls this exactly once after it has
    # accepted the Registry canonical state for the current Graph.  This keeps
    # the module's attached safety snapshot and the pending render target on
    # the same accepted state before render_gate is opened.
    accept_canonical = function(state, reason = "outer-ready-accept", seed_render = TRUE) {
      graph_accept_attached_canonical(state, reason = reason, seed_render = seed_render)
    },
    refresh_browser_pools = function(state) {
      graph_browser_direct_publish_pools(state)
    },
    refresh_browser_hydration = function(state, graph_id = "") {
      if (!is.list(state) || !graph_editor_profile_has(editor_profile, "full_shell")) return(invisible(FALSE))
      graph_mapping_replay_plan(graph_replay_mapping_plan(state))
      graph_mapping_choices_seed(isolate(graph_mapping_replay_plan()))
      plan <- graph_editor_replay_plan(NULL, state, editor_profile)
      payload <- graph_browser_direct_hydration_payload(
        state, plan, transaction = list(id = as.character(graph_id %||% "")[1])
      )
      session$sendCustomMessage("graph-state-browser-hydrate", payload)
      graph_browser_direct_publish_pools(state)
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
    # sections are transported. One browser completion barrier remains the sole
    # replay boundary; there is no staged restore/reconcile fallback.
    replay_state = function(state, transaction = NULL) {
      if (!is.list(state)) return(invisible(FALSE))
      graph_apply_state_replay(state, transaction = transaction)
    },
    replay_active = reactive({ isTRUE(graph_state_replay_active()) }),
    replay_error = reactive({ graph_state_replay_error() })
  )


  init_timing_emit("INNER-RETURN", "module API constructed")
  module_api
  })
  init_timing_emit("MODULESERVER-CALL-END")
  module_result
}
