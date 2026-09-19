  # ============================================================
  # Outputs
  # ============================================================
  # Plot size: sliderと直接数値入力を同期
  observeEvent(input$plot_width_px, {
    z <- safe_num1(input$plot_width_px, NA_real_)
    if (is.finite(z)) {
      cur <- safe_num1(input$plot_width_px_direct, NA_real_)
      if (!is.finite(cur) || abs(cur - z) > 0.5) {
        updateNumericInput(session, "plot_width_px_direct", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_width_px_direct, {
    z <- safe_num1(input$plot_width_px_direct, NA_real_)
    if (is.finite(z)) {
      z <- max(250, min(2000, z))
      cur <- safe_num1(input$plot_width_px, NA_real_)
      if (z >= 300 && z <= 1400 && (!is.finite(cur) || abs(cur - z) > 0.5)) {
        updateSliderInput(session, "plot_width_px", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_height_px, {
    z <- safe_num1(input$plot_height_px, NA_real_)
    if (is.finite(z)) {
      cur <- safe_num1(input$plot_height_px_direct, NA_real_)
      if (!is.finite(cur) || abs(cur - z) > 0.5) {
        updateNumericInput(session, "plot_height_px_direct", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_height_px_direct, {
    z <- safe_num1(input$plot_height_px_direct, NA_real_)
    if (is.finite(z)) {
      z <- max(180, min(1400, z))
      cur <- safe_num1(input$plot_height_px, NA_real_)
      if (z >= 220 && z <= 900 && (!is.finite(cur) || abs(cur - z) > 0.5)) {
        updateSliderInput(session, "plot_height_px", value = z)
      }
    }
  }, ignoreInit = FALSE)

  effective_plot_width_px <- reactive({
    seed <- plot_width_restore_seed()
    if (!is.null(seed) && length(seed) && is.finite(seed[1])) {
      return(max(250, min(2000, as.numeric(seed[1]))))
    }

    z <- safe_num1(input$plot_width_px_direct, NA_real_)
    if (!is.finite(z)) z <- safe_num1(input$plot_width_px, 600)
    max(250, min(2000, z))
  })

  effective_plot_height_px <- reactive({
    seed <- plot_height_restore_seed()
    if (!is.null(seed) && length(seed) && is.finite(seed[1])) {
      return(max(180, min(1400, as.numeric(seed[1]))))
    }

    z <- safe_num1(input$plot_height_px_direct, NA_real_)
    if (!is.finite(z)) z <- safe_num1(input$plot_height_px, 600)
    max(180, min(1400, z))
  })

  # v3.3.45: Plot横幅/縦幅はpanel（軸に囲まれた領域）の寸法として固定する。
  # Legendやタイトル等はpanel外側へ追加され、Legendを消しても軸長は変わらない。
  panel_sized_plot <- reactive({
    p <- make_plot()
    apply_fixed_panel_size(
      p,
      effective_plot_width_px(),
      effective_plot_height_px(),
      reference_res = 120
    )
  })

  plot_total_dimensions <- reactive({
    pw <- effective_plot_width_px()
    ph <- effective_plot_height_px()
    tryCatch(
      measure_plot_size_px(
        panel_sized_plot(),
        reference_res = 120,
        fallback_width = pw,
        fallback_height = ph
      ),
      error = function(e) list(width = pw, height = ph)
    )
  })

  # Browser側の直接数値inputが保存値へ追いついたらseedを解除する。
  # それまではhidden Graphのpanel/device寸法を保存値で固定する。
  observe({
    sw <- plot_width_restore_seed()
    if (!is.null(sw) && length(sw) && is.finite(sw[1])) {
      cur <- safe_num1(input$plot_width_px_direct, NA_real_)
      if (is.finite(cur) && abs(cur - as.numeric(sw[1])) <= 0.5) {
        plot_width_restore_seed(NULL)
      }
    }

    sh <- plot_height_restore_seed()
    if (!is.null(sh) && length(sh) && is.finite(sh[1])) {
      cur <- safe_num1(input$plot_height_px_direct, NA_real_)
      if (is.finite(cur) && abs(cur - as.numeric(sh[1])) <= 0.5) {
        plot_height_restore_seed(NULL)
      }
    }
  })

  output$plot_container <- renderUI({
    # IMPORTANT:
    # Plot width/height changes must NOT recreate this DOM.
    # Rebuilding plot_follow while sticky caused a temporary vertical jump.
    # Dimensions are applied in-place by JavaScript instead.
    div(
      id = session$ns("plot_anchor"),
      div(
        id = session$ns("plot_follow"),
        class = "plot-follow",
        `data-follow` = "true",
        uiOutput("plot_note"),
        # v3.58.1: Preview scrolling/zooming belongs to the graph viewport only.
        # Graph書式 remains a sibling below the viewport so it follows the Graph
        # section/sticky behavior, but never participates in preview zoom/scroll.
        div(
          id = session$ns("plot_viewport"),
          class = "graph-preview-viewport",
          # v3.58.2: the viewport is only the clipping/scrolling window.  The
          # native Graph keeps its own geometry inside a scale canvas, while a
          # spacer reserves the *displayed* geometry after browser zoom.
          div(
            id = session$ns("plot_scale_spacer"),
            class = "graph-preview-scale-spacer",
            div(
              id = session$ns("plot_scale_canvas"),
              class = "graph-preview-scale-canvas",
              div(
                id = session$ns("plot_panel"),
                class = "plot-panel",
                style = sprintf(
                  "width:%dpx; max-width:none; margin-left:auto; margin-right:auto;",
                  as.integer(round(initial_plot_size_seed$width + 26))
                ),
                plotOutput(
                  "plot",
                  width = paste0(as.integer(round(initial_plot_size_seed$width)), "px"),
                  height = paste0(as.integer(round(initial_plot_size_seed$height)), "px")
                )
              )
            )
          )
        ),
        div(
          class = "plot-style-toolbar",
          div(class = "plot-style-toolbar-title", "Graph書式"),
          fluidRow(
            column(3, actionButton("copy_style", "書式をコピー", class = "btn-sm btn-block")),
            column(3, actionButton("paste_style", "書式を貼り付け", class = "btn-sm btn-block")),
            column(3, downloadButton("download_style", "書式設定を保存", class = "btn-sm btn-block")),
            column(
              3,
              fileInput(
                "upload_style",
                NULL,
                accept = ".json",
                buttonLabel = "書式設定を読込",
                placeholder = "JSON"
              )
            )
          ),
          p(
            class = "help-block",
            "Data / Mapping / StatisticsとGraphタイトル・X/Y軸タイトルは変更せず、Plotサイズ・軸範囲・表示順・色/線/フォント・凡例/条件表示などを移します。コピー / 貼り付けは同じ起動中の別Graph・別Projectでも使用できます。"
          )
        )
      )
    )
  })

  # Plot DOMは固定したまま、native device寸法をbrowserへ通知する。
  # v3.58: Graph PreviewのAuto/manual表示倍率はbrowser側だけで適用し、
  # renderPlot/export device寸法そのものはplot_total_dimensions()のnative値を保つ。
  # The singleton Preview live subtree is recreated on READY remount.
  # The normal reactive dimension message may have fired before that new DOM
  # existed, so keep one reusable sender and replay it after remount ACK.
  send_plot_dimensions <- function(dims, reason = "reactive") {
    pw <- suppressWarnings(as.numeric(dims$width %||% NA_real_)[1])
    ph <- suppressWarnings(as.numeric(dims$height %||% NA_real_)[1])
    if (!is.finite(pw) || !is.finite(ph) || pw <= 0 || ph <= 0) return(invisible(FALSE))
    session$sendCustomMessage(
      "set-plot-dimensions",
      list(
        panelId = session$ns("plot_panel"),
        plotId = session$ns("plot"),
        followId = session$ns("plot_follow"),
        anchorId = session$ns("plot_anchor"),
        width = as.integer(round(pw)),
        panelWidth = as.integer(round(pw + 26)),
        height = as.integer(round(ph)),
        reason = as.character(reason %||% "")
      )
    )
    diag("PREVIEW-DIMS", paste0(
      "dimension message reason=", reason,
      " device=", round(pw, 1), "x", round(ph, 1)
    ))
    invisible(TRUE)
  }

  observe({
    # v3.72.3: the singleton Preview DOM belongs to the new target as soon as
    # a Graph switch begins.  Dimension invalidations from the previous/filling
    # Editor state must not resize that target while HYDRATING.  The gate-open
    # transition at READY re-runs this observer and publishes one final size.
    shiny::req(isTRUE(render_gate()))
    shiny::req(isTRUE(initial_restore_done()))
    diag("PLOT-CONSUMER", "request=dimensions")
    dims <- plot_total_dimensions()
    send_plot_dimensions(dims, reason = "reactive")
  })

  observeEvent(input$sticky_plot, {
    session$sendCustomMessage(
      "set-follow-state",
      list(
        id = session$ns("plot_follow"),
        value = if (isTRUE(input$sticky_plot)) "true" else "false"
      )
    )
  }, ignoreInit = FALSE)

  # v3.58.3: the singleton Preview lives outside the per-Graph tab pane, so
  # browser visibility must follow the real namespaced tab input rather than
  # inferred Bootstrap DOM ancestry.  Controls-only Figure editors have no
  # visible Graph Preview and therefore never send this message.
  if (!isTRUE(controls_only)) {
    observeEvent(input$graph_main_tab, {
      session$sendCustomMessage(
        "graph-global-preview-tab-state",
        list(
          graphId = id,
          tab = as.character(input$graph_main_tab %||% "Plot"),
          visible = identical(input$graph_main_tab %||% "Plot", "Plot")
        )
      )
    }, ignoreInit = FALSE)
  }

  output$plot <- renderPlot({
    # Keep renderPlot itself behind the same transaction gate as make_plot().
    # This blocks remount/dimension/input invalidations from drawing an
    # intermediate Graph while a persistent-Editor switch is in flight.
    shiny::req(isTRUE(render_gate()), cancelOutput = TRUE)
    diag("PLOT-CONSUMER", "request=live-render")
    diag("DRAW", "output$plot renderPlot entered")
    # A persistent graphServer may outlive its browser DOM.  Depend explicitly
    # on the acknowledged remount epoch so a newly materialized DOM always gets
    # one fresh live render even when all user inputs are unchanged.
    remount_render_epoch()
    # Project/duplicate Graphは、全設定の復元完了前にはPlotを描かない。
    # cancelOutput=TRUEにより、途中のdefault色・default Mappingの一瞬の描画を禁止。
    shiny::req(
      isTRUE(initial_restore_done()) &&
        !isTRUE(restoring_style_state()) &&
        project_restore_stage() == 0,
      cancelOutput = TRUE
    )

    # non-Plotタブ表示中はhidden Plotを更新しない。
    # graph_main_tabはmodule生成時にPlotが既定なので、Projectのhidden restore時に
    # 必要な最初の描画はこれまで通り可能。
    # 実際のPNG deviceは下の固定1000×600で生成し、タブ切替時の一時的な
    # client幅0/極小値による "figure margins too large" を回避する。
    shiny::req(
      is.null(input$graph_main_tab) || identical(input$graph_main_tab, "Plot"),
      cancelOutput = TRUE
    )

    p <- graph_render_plot_safely(function() panel_sized_plot())

    # The completed Plot belongs to the semantic target released by the render
    # revision boundary.  Do not re-read browser inputs here: dynamic controls
    # can disappear between make_plot() completion and renderPlot publication.
    last_render_state(isolate(plot_last_built_render_state()))
    plot_render_revision(as.integer(isolate(plot_render_revision()) %||% 0L) + 1L)
    plot_drawn(TRUE)

    # v3.51: do not manipulate cached/live DOM here.  The browser switches the
    # stable preview stage only after the plot <img> has actually loaded.
    p
  },
  # Browserの瞬間的なoutput幅には依存せず、Axes設定の明示値を
  # device sizeとして使う。これによりPlot横幅/縦幅を安定して変更できる。
  width = function() {
    plot_total_dimensions()$width
  },
  height = function() {
    plot_total_dimensions()$height
  },
  res = 120,
  execOnResize = FALSE
  )

  # v3.72.27: Statistics no longer renders or owns a Plot reference.
  # It consumes the original dataset plus its Analysis-local preparation recipe.

  last_valid_data_view <- reactiveVal(NULL)
  data_view_is_stale <- reactiveVal(FALSE)

  data_view_data <- reactive({
    # input$textを明示依存にして、貼り付け更新を確実に拾う。
    input$text
    dnow <- tryCatch(plot_source_data(), error = function(e) NULL)

    if (!is.null(dnow) && is.data.frame(dnow)) {
      last_valid_data_view(dnow)
      data_view_is_stale(FALSE)
      return(dnow)
    }

    data_view_is_stale(TRUE)
    last_valid_data_view()
  })

  output$data_view_status <- renderUI({
    if (!isTRUE(data_view_is_stale())) return(NULL)
    div(
      class = "alert alert-warning",
      style = "padding:6px 9px; margin-bottom:8px;",
      "現在の貼り付け内容をまだ解析できないため、直前の正常なData Viewを表示しています。"
    )
  })
  outputOptions(output, "data_view_status", suspendWhenHidden = FALSE)

  output$data_view <- renderTable({
    dv <- data_view_data()
    shiny::validate(shiny::need(
      !is.null(dv) && is.data.frame(dv),
      "表示できるデータがありません。"
    ))
    head(dv, 100)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  outputOptions(output, "data_view", suspendWhenHidden = FALSE)

  code_text <- reactive({
    x0 <- resolved_xvar()
    y0 <- resolved_yvar()
    x <- if (!nzchar(x0)) "X" else x0
    y <- if (!nzchar(y0)) "Y" else y0
    g <- effective_position_var(dat())
    summary_label <- switch(input$summary_type,
                            value = "値（集計しない）",
                            mean = "平均",
                            sd = "平均 ± SD",
                            sem = "平均 ± SEM",
                            ci95 = "平均 ± 95% CI",
                            "")

    summary_unit_label <- if (isTRUE(direct_value_mode())) {
      "使用しない（入力行をそのまま使用）"
    } else if (identical(input$summary_unit %||% "row", "id_mean")) {
      "ID mean -> between-ID summary"
    } else {
      "row"
    }

    external_error_label <- if (isTRUE(direct_value_mode())) {
      switch(
        input$external_error_mode %||% "none",
        symmetric = paste0("Y ± ", input$external_error_col %||% ""),
        bounds = paste0(
          "lower=", input$external_ymin_col %||% "",
          " / upper=", input$external_ymax_col %||% ""
        ),
        "なし"
      )
    } else {
      switch(
        input$summary_type %||% "mean",
        sd = "GUI計算 SD",
        sem = "GUI計算 SEM",
        ci95 = "GUI計算 95% CI",
        "なし"
      )
    }

    paste0(
      "# GUIで作成した図の主要設定\n",
      "# Plot: ", input$plot_type, "\n",
      "# X: ", x, " / Y: ", y, if (nzchar(g)) paste0(" / Position: ", g) else "", if (!is.null(input$colorvar) && nzchar(input$colorvar)) paste0(" / Color: ", input$colorvar) else "",
      if (!is.null(input$linetypevar) && nzchar(input$linetypevar) && input$linetypevar != "__color__") paste0(" / Linetype: ", input$linetypevar) else "",
      if (!is.null(input$shapevar) && nzchar(input$shapevar) && input$shapevar != "__color__") paste0(" / Shape: ", input$shapevar) else "", "\n",
      "# Summary: ", summary_label, "\n",
      "# Summary unit: ", summary_unit_label, "\n",
      "# Error bar: ", external_error_label, "\n",
      "# X order: ", paste(x_levels(), collapse = ", "), "\n",
      if (length(group_levels())) paste0("# Position order: ", paste(group_levels(), collapse = ", "), "\n") else "",
      if (!is.null(input$facetvar) && nzchar(input$facetvar)) {
        fobs <- unique(as.character(dat()[[input$facetvar]]))
        fobs <- fobs[!is.na(fobs)]
        paste0(
          "# Facet order: ",
          paste(get_saved_order("facet", input$facetvar, fobs), collapse = ", "),
          "\n"
        )
      } else "",
      "# Color / Linetype / Shape and detailed appearance are stored in the downloadable JSON settings file."
    )
  })

  output$ggcode <- renderText(code_text())

  observeEvent(input$copy_code, {
    session$sendCustomMessage("copy-code", code_text())
  })

  init_timing_emit("SETTINGS-BEGIN")

