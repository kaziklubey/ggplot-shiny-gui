# v3.69.0: extracted from graph_module.R; sourced into graphServer local environment.
# Section: ORDER-UI-BEGIN


  # ============================================================
  # Order UI
  # ============================================================
  output$order_ui <- renderUI({
    d <- dat()
    req(input$xvar)

    xobs <- unique(as.character(d[[input$xvar]]))
    xobs <- xobs[!is.na(xobs)]
    xord <- get_saved_order("x", input$xvar, xobs)

    items <- list(
      tags$div(class = "order-box",
        tags$b(paste0("X軸（", input$xvar, "）の順序")),
        p(class = "help-block", "カンマ区切りで左から表示したい順に指定します。"),
        textInput("x_order_text", NULL, value = paste(xord, collapse = ", ")),
        actionButton("apply_x_order", "X順序を適用", class = "btn-sm")
      )
    )

    g_order_var <- effective_position_var(d)
    if (nzchar(g_order_var)) {
      gobs <- unique(as.character(d[[g_order_var]]))
      gobs <- gobs[!is.na(gobs)]
      gord <- get_saved_order("group", g_order_var, gobs)
      items <- c(items, list(
        tags$div(class = "order-box",
          tags$b(paste0("追加横並び / 横ずらし要因（", g_order_var, "）の順序")),
          p(class = "help-block", "横ずらし・横並び条件の左右順に反映します。"),
          textInput("group_order_text", NULL, value = paste(gord, collapse = ", ")),
          actionButton("apply_group_order", "横位置順序を適用", class = "btn-sm")
        )
      ))
    }

    # Color / Fill, Linetype, Shape-only variables get one shared display
    # order. When the same variable is already X or horizontal-position, that
    # spatial order remains authoritative and no duplicate control is shown.
    used_vars <- unique(c(
      as.character(input$xvar %||% "")[1],
      g_order_var
    ))
    used_vars <- used_vars[nzchar(used_vars)]

    aes_specs <- list(
      list(id = "color", label = "色 / 塗り", var = resolve_color_var(d)),
      list(id = "linetype", label = "線種", var = resolve_linetype_var(d)),
      list(id = "shape", label = "点の形", var = resolve_shape_var(d))
    )

    for (spec in aes_specs) {
      v <- as.character(spec$var %||% "")[1]
      if (!nzchar(v) || !v %in% names(d) || v %in% used_vars) next
      obs <- unique(as.character(d[[v]]))
      obs <- obs[!is.na(obs)]
      ord <- get_saved_order("display", v, obs)
      items <- c(items, list(
        tags$div(class = "order-box",
          tags$b(paste0(spec$label, "（", v, "）の順序")),
          p(
            class = "help-block",
            "凡例項目とMappingの表示順に反映します。Bar / Boxでこの変数が横並びslotを作る場合は左右順にも反映します。"
          ),
          textInput(paste0(spec$id, "_display_order_text"), NULL, value = paste(ord, collapse = ", ")),
          actionButton(paste0("apply_", spec$id, "_display_order"), "表示順序を適用", class = "btn-sm")
        )
      ))
      used_vars <- c(used_vars, v)
    }

    if (has_selection(input$facetvar) && input$facetvar %in% names(d) && !input$facetvar %in% used_vars) {
      fobs <- unique(as.character(d[[input$facetvar]]))
      fobs <- fobs[!is.na(fobs)]
      ford <- get_saved_order("facet", input$facetvar, fobs)
      items <- c(items, list(
        tags$div(
          class = "order-box",
          tags$b(paste0("Facet（", input$facetvar, "）の順序")),
          p(
            class = "help-block",
            "カンマ区切りで、左上から表示したいFacetの順に指定します。"
          ),
          textInput("facet_order_text", NULL, value = paste(ford, collapse = ", ")),
          actionButton("apply_facet_order", "Facet順序を適用", class = "btn-sm")
        )
      ))
    }

    tagList(items)
  })

  # Line-break browser synchronization lives in graph_line_connection_runtime.R.

  observeEvent(input$apply_x_order, {
    req(input$xvar)
    observed <- unique(as.character(dat()[[input$xvar]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(input$x_order_text)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(paste("データにないX水準を無視しました:", paste(unknown, collapse = ", ")), type = "warning")
    }
    final_order <- complete_order(requested, observed)
    set_saved_order("x", input$xvar, final_order)
    # An explicit user order change is the one place where a previously saved
    # boundary is intentionally dropped when its two levels are no longer
    # adjacent. Replay/choice rebuilding never performs this destructive prune.
    if (exists("line_break_prune_to_levels", mode = "function")) {
      line_break_prune_to_levels(final_order, source = "x-category-order")
    }
  })

  observeEvent(input$apply_group_order, {
    d <- dat()
    v <- effective_position_var(d)
    req(nzchar(v))
    observed <- unique(as.character(d[[v]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(input$group_order_text)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(paste("データにない横位置水準を無視しました:", paste(unknown, collapse = ", ")), type = "warning")
    }
    set_saved_order("group", v, complete_order(requested, observed))
  })

  apply_display_order <- function(var_name, text_value, label) {
    d <- dat()
    v <- as.character(var_name %||% "")[1]
    req(nzchar(v), v %in% names(d))
    observed <- unique(as.character(d[[v]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(text_value)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(
        paste0("データにない", label, "水準を無視しました: ", paste(unknown, collapse = ", ")),
        type = "warning"
      )
    }
    set_saved_order("display", v, complete_order(requested, observed))
  }

  observeEvent(input$apply_color_display_order, {
    apply_display_order(resolve_color_var(dat()), input$color_display_order_text, "色 / 塗り")
  })

  observeEvent(input$apply_linetype_display_order, {
    apply_display_order(resolve_linetype_var(dat()), input$linetype_display_order_text, "線種")
  })

  observeEvent(input$apply_shape_display_order, {
    apply_display_order(resolve_shape_var(dat()), input$shape_display_order_text, "点の形")
  })

  observeEvent(input$apply_facet_order, {
    req(input$facetvar)
    d <- dat()
    req(input$facetvar %in% names(d))

    observed <- unique(as.character(d[[input$facetvar]]))
    observed <- observed[!is.na(observed)]

    requested <- parse_order_text(input$facet_order_text)
    unknown <- setdiff(requested, observed)

    if (length(unknown)) {
      showNotification(
        paste("データにないFacet水準を無視しました:", paste(unknown, collapse = ", ")),
        type = "warning"
      )
    }

    set_saved_order(
      "facet",
      input$facetvar,
      complete_order(requested, observed)
    )
  })

