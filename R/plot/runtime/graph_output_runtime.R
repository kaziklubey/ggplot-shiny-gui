  # ============================================================
  # Outputs
  # ============================================================
  # Plot size is browser-owned. The slider/direct numeric aliases are kept in
  # sync in app_client.js; R reads only the accepted canonical/Figure working
  # appearance value. This avoids depending on Shiny mirrors that are purposely
  # prevented from reaching the server by browser-direct transport.
  effective_plot_width_px <- reactive({
    z <- safe_num1(graph_appearance_value("plot_width_px", 600), 600)
    max(250, min(2000, z))
  })

  effective_plot_height_px <- reactive({
    z <- safe_num1(graph_appearance_value("plot_height_px", 600), 600)
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

  output$plot_container <- renderUI({
    # IMPORTANT:
    # Plot width/height changes must NOT recreate this DOM.
    # Rebuilding plot_follow while sticky caused a temporary vertical jump.
    # Dimensions are applied in-place by JavaScript instead. Seed the initial
    # DOM once from the currently bound values without taking a reactive
    # dependency; subsequent size changes are handled in-place by JS.
    initial_plot_width_px <- isolate(effective_plot_width_px())
    initial_plot_height_px <- isolate(effective_plot_height_px())
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
                  as.integer(round(initial_plot_width_px + 26))
                ),
                plotOutput(
                  "plot",
                  width = paste0(as.integer(round(initial_plot_width_px)), "px"),
                  height = paste0(as.integer(round(initial_plot_height_px)), "px")
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
  # Native Plot dimensions are published into the one persistent live Plot DOM.
  # Graph replay changes values only; it never swaps display surfaces.
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

  if (graph_editor_profile_has(editor_profile, "preview")) {
    observe({
      # Only profiles with an actual live Preview DOM publish device dimensions.
      # Figure Controls are controls-only; running this consumer there used to
      # build/measure a plot after every panel selection even though no preview
      # output existed. Figure plot construction stays demand-driven by snapshot
      # publication after a real render-affecting edit.
      shiny::req(isTRUE(render_gate()))
      diag("PLOT-CONSUMER", "request=dimensions")
      dims <- plot_total_dimensions()
      send_plot_dimensions(dims, reason = "reactive")
    })
  }

  observeEvent(input$sticky_plot, {
    session$sendCustomMessage(
      "set-follow-state",
      list(
        id = session$ns("plot_follow"),
        value = if (isTRUE(input$sticky_plot)) "true" else "false"
      )
    )
  }, ignoreInit = FALSE)

  output$plot <- renderPlot({
    # Keep renderPlot itself behind the same transaction gate as make_plot().
    # This blocks dimension/input invalidations from drawing an intermediate
    # Graph while a persistent-Editor value replay is in flight.
    shiny::req(isTRUE(render_gate()), cancelOutput = TRUE)
    diag("PLOT-CONSUMER", "request=live-render")
    diag("DRAW", "output$plot renderPlot entered")
    # Value replay is already blocked by render_gate. Style application keeps its
    # own short-lived guard so intermediate style controls never draw.
    shiny::req(!isTRUE(restoring_style_state()), cancelOutput = TRUE)

    # non-Plotタブ表示中はhidden Plotを更新しない。
    # 実際のPNG deviceは下の固定1000×600で生成し、タブ切替時の一時的な
    # client幅0/極小値による "figure margins too large" を回避する。
    shiny::req(
      is.null(input$graph_main_tab) || identical(input$graph_main_tab, "Plot"),
      cancelOutput = TRUE
    )

    p <- graph_render_plot_safely(function() panel_sized_plot())
    graph_draw_plot_safely(p)

    # The completed Plot belongs to the semantic target released by the render
    # revision boundary.  Do not re-read browser inputs here: dynamic controls
    # can disappear between make_plot() completion and renderPlot publication.
    last_render_state(isolate(plot_last_built_render_state()))
    plot_render_revision(as.integer(isolate(plot_render_revision()) %||% 0L) + 1L)

    # v3.51: do not manipulate cached/live DOM here. The browser switches the
    # stable preview stage only after the plot <img> has actually loaded. The
    # image has already been drawn by app_draw_static_plot(); returning NULL
    # deliberately prevents Shiny from constructing a ggplot coordmap that the
    # GUI never consumes.
    invisible(NULL)
  },
  # Browserの瞬間的なoutput幅には依存せず、Axes設定の明示値を
  # device sizeとして使う。これによりPlot横幅/縦幅を安定して変更できる。
  width = function() {
    # Transaction-closed editors do not need exact outer geometry yet. Using
    # panel dimensions here avoids building/measuring an intermediate plot just
    # to size a hidden/pre-replay PNG device. Opening the gate invalidates this
    # function and resolves the exact total dimensions once for the final plot.
    if (!isTRUE(render_gate())) return(as.numeric(effective_plot_width_px()))
    plot_total_dimensions()$width
  },
  height = function() {
    if (!isTRUE(render_gate())) return(as.numeric(effective_plot_height_px()))
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
    # plot_source_data() now depends on the attached canonical GraphState. A
    # malformed/incomplete paste therefore invalidates here through the same
    # source as Plot/Statistics; the last valid Data View is retained below.
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
    plot_type_now <- graph_plot_value("type", input$plot_type %||% "line")
    color_now <- graph_mapping_value("color", input$colorvar %||% "")
    linetype_now <- graph_mapping_value("linetype", input$linetypevar %||% "__color__")
    shape_now <- graph_mapping_value("shape", input$shapevar %||% "__color__")
    facet_now <- graph_mapping_value("facet", input$facetvar %||% "")
    summary_now <- graph_plot_value("summary", input$summary_type %||% "mean")
    summary_label <- switch(summary_now,
                            value = "値（集計しない）",
                            mean = "平均",
                            sd = "平均 ± SD",
                            sem = "平均 ± SEM",
                            ci95 = "平均 ± 95% CI",
                            "")

    summary_unit_label <- if (isTRUE(direct_value_mode())) {
      "使用しない（入力行をそのまま使用）"
    } else if (identical(graph_plot_value("summary_unit", input$summary_unit %||% "row"), "id_mean")) {
      "ID mean -> between-ID summary"
    } else {
      "row"
    }

    external_error_label <- if (isTRUE(direct_value_mode())) {
      switch(
        graph_plot_value("external_error_mode", input$external_error_mode %||% "none"),
        symmetric = paste0("Y ± ", graph_mapping_value("external_error", input$external_error_col %||% "")),
        bounds = paste0(
          "lower=", graph_mapping_value("external_ymin", input$external_ymin_col %||% ""),
          " / upper=", graph_mapping_value("external_ymax", input$external_ymax_col %||% "")
        ),
        "なし"
      )
    } else {
      switch(
        graph_plot_value("summary", input$summary_type %||% "mean"),
        sd = "GUI計算 SD",
        sem = "GUI計算 SEM",
        ci95 = "GUI計算 95% CI",
        "なし"
      )
    }

    paste0(
      "# GUIで作成した図の主要設定\n",
      "# Plot: ", plot_type_now, "\n",
      "# X: ", x, " / Y: ", y, if (nzchar(g)) paste0(" / Position: ", g) else "", if (nzchar(color_now)) paste0(" / Color: ", color_now) else "",
      if (nzchar(linetype_now) && linetype_now != "__color__") paste0(" / Linetype: ", linetype_now) else "",
      if (nzchar(shape_now) && shape_now != "__color__") paste0(" / Shape: ", shape_now) else "", "\n",
      "# Summary: ", summary_label, "\n",
      "# Summary unit: ", summary_unit_label, "\n",
      "# Error bar: ", external_error_label, "\n",
      "# X order: ", paste(x_levels(), collapse = ", "), "\n",
      if (length(group_levels())) paste0("# Position order: ", paste(group_levels(), collapse = ", "), "\n") else "",
      if (nzchar(facet_now) && facet_now %in% names(dat())) {
        fobs <- unique(as.character(dat()[[facet_now]]))
        fobs <- fobs[!is.na(fobs)]
        paste0(
          "# Facet order: ",
          paste(get_saved_order("facet", facet_now, fobs), collapse = ", "),
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
