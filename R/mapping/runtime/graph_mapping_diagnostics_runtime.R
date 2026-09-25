# v3.80 Mapping/visual-density diagnostics.
# Derived UI only: no diagnostic result is persisted into GraphState.

  output$position_mapping_notice_ui <- renderUI({
    d <- tryCatch(dat(), error = function(e) NULL)
    if (!is.data.frame(d) || !nrow(d)) return(NULL)

    g <- effective_position_var(d)
    if (!nzchar(g) || !g %in% names(d)) return(NULL)

    observed <- unique(as.character(d[[g]]))
    observed <- observed[!is.na(observed)]
    if (!length(observed)) return(NULL)
    ordered <- get_saved_order("group", g, observed)
    displayed <- level_label_values(g, ordered)

    mapped_by <- character(0)
    plot_type0 <- graph_plot_value("type", input$plot_type %||% "line")
    c0 <- resolve_color_var(d)
    l0 <- resolve_linetype_var(d)
    s0 <- resolve_shape_var(d)
    if (identical(g, c0)) mapped_by <- c(mapped_by, "Color / Fill")
    if (identical(plot_type0, "line") && identical(g, l0)) mapped_by <- c(mapped_by, "Linetype")
    if (identical(plot_type0, "line") && identical(g, s0)) mapped_by <- c(mapped_by, "Shape")

    order_text <- paste(displayed, collapse = " → ")
    semantic <- if (length(mapped_by)) {
      paste0("この要因は位置に加えて ", paste(unique(mapped_by), collapse = " / "), " でも表現されるため、凡例からも識別できます。")
    } else {
      "この要因は位置だけで表現されています。位置だけでは凡例に出ないため、図単体で意味を示したい場合はColor / Linetype / Shapeへの重複MappingまたはFacetも利用できます。"
    }

    tags$div(
      class = "mapping-diagnostic mapping-diagnostic-info",
      tags$div(tags$b(paste0("横位置: ", g)), paste0("　左 → 右: ", order_text)),
      tags$div(class = "help-block", semantic)
    )
  })

  output$mapping_diagnostics_ui <- renderUI({
    d <- tryCatch(dat(), error = function(e) NULL)
    if (!is.data.frame(d) || !nrow(d)) return(NULL)

    x0 <- resolved_xvar()
    c0 <- resolve_color_var(d)
    l0 <- resolve_linetype_var(d)
    s0 <- resolve_shape_var(d)
    g0 <- effective_position_var(d)
    facet_now <- graph_mapping_value("facet", input$facetvar %||% "")
    f0 <- if (has_selection(facet_now) && facet_now %in% names(d)) facet_now else ""

    info <- graph_mapping_diagnostics(
      data = d,
      plot_type = graph_plot_value("type", input$plot_type %||% "line"),
      xvar = x0,
      position_var = g0,
      color_var = c0,
      linetype_var = l0,
      shape_var = s0,
      facet_var = f0,
      line_series_mode = graph_mapping_value("line_series_mode", input$line_series_mode %||% "auto"),
      line_series_var = graph_mapping_value("line_series_var", input$line_series_var %||% "")
    )
    if (!length(info$messages)) return(NULL)

    rows <- Map(function(msg, sev) {
      prefix <- if (identical(sev, "warn")) "⚠ " else "ℹ "
      tags$div(class = paste0("mapping-diagnostic mapping-diagnostic-", sev), paste0(prefix, msg))
    }, info$messages, info$severity)

    tags$details(
      class = "control-subsection mapping-diagnostics",
      tags$summary("Mappingチェック"),
      div(class = "subsection-body", tagList(rows))
    )
  })
