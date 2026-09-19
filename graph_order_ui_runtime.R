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

    if (has_selection(input$facetvar) && input$facetvar %in% names(d)) {
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

  observeEvent(input$apply_x_order, {
    req(input$xvar)
    observed <- unique(as.character(dat()[[input$xvar]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(input$x_order_text)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(paste("データにないX水準を無視しました:", paste(unknown, collapse = ", ")), type = "warning")
    }
    set_saved_order("x", input$xvar, complete_order(requested, observed))
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

