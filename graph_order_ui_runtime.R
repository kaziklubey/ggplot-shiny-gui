# v3.81.0: structured category ordering; no comma-delimited editor state.
# Sourced into graphServer local environment.

  category_order_observed <- function(d, variable) {
    variable <- as.character(variable %||% "")[1]
    if (!nzchar(variable) || !is.data.frame(d) || !variable %in% names(d)) return(character(0))
    z <- unique(as.character(d[[variable]]))
    as.character(z[!is.na(z)])
  }

  category_order_box <- function(kind, variable, label, help) {
    d <- dat()
    obs <- category_order_observed(d, variable)
    ord <- get_saved_order(kind, variable, obs)
    graph_category_order_control(
      input_id = session$ns("category_order_move"),
      kind = kind,
      variable = variable,
      label = label,
      values = ord,
      help = help
    )
  }

  output$order_ui <- renderUI({
    d <- dat()
    req(input$xvar)

    items <- list()
    if (!identical(input$plot_type %||% "line", "scatter")) {
      items <- c(items, list(category_order_box(
        "x", input$xvar,
        paste0("X軸（", input$xvar, "）の順序"),
        "↑ / ↓ で左から表示する順序を変更します。カテゴリ名にカンマが含まれていてもそのまま扱えます。"
      )))
    }

    g_order_var <- effective_position_var(d)
    if (nzchar(g_order_var)) {
      items <- c(items, list(category_order_box(
        "group", g_order_var,
        paste0("追加横並び / 横ずらし要因（", g_order_var, "）の順序"),
        "横ずらし・横並び条件の左右順に反映します。Bar / Box の stable slot も同じ順序を使います。"
      )))
    }

    used_vars <- unique(c(as.character(input$xvar %||% "")[1], g_order_var))
    used_vars <- used_vars[nzchar(used_vars)]
    aes_specs <- list(
      list(label = "色 / 塗り", var = resolve_color_var(d)),
      list(label = "線種", var = resolve_linetype_var(d)),
      list(label = "点の形", var = resolve_shape_var(d))
    )
    for (spec in aes_specs) {
      v <- as.character(spec$var %||% "")[1]
      if (!nzchar(v) || !v %in% names(d) || v %in% used_vars) next
      items <- c(items, list(category_order_box(
        "display", v,
        paste0(spec$label, "（", v, "）の順序"),
        "凡例項目とMappingの表示順に反映します。この変数がBar / Boxの横並びslotを作る場合は左右順にも反映します。"
      )))
      used_vars <- c(used_vars, v)
    }

    if (has_selection(input$facetvar) && input$facetvar %in% names(d) && !input$facetvar %in% used_vars) {
      items <- c(items, list(category_order_box(
        "facet", input$facetvar,
        paste0("Facet（", input$facetvar, "）の順序"),
        "↑ / ↓ で左上から表示するFacet順を変更します。"
      )))
    }

    tagList(items)
  })

  observeEvent(input$category_order_move, {
    evt <- input$category_order_move
    req(is.list(evt))
    kind <- as.character(evt$kind %||% "")[1]
    variable <- as.character(evt$variable %||% "")[1]
    idx <- suppressWarnings(as.integer(evt$index)[1])
    direction <- suppressWarnings(as.integer(evt$direction)[1])
    if (!kind %in% c("x", "group", "display", "facet") || !nzchar(variable)) return()

    d <- dat()
    if (!variable %in% names(d)) return()
    observed <- category_order_observed(d, variable)
    current <- get_saved_order(kind, variable, observed)
    moved <- graph_category_order_move(current, idx, direction)
    if (identical(current, moved)) return()
    set_saved_order(kind, variable, moved)

    if (identical(kind, "x") && identical(variable, as.character(input$xvar %||% "")[1]) &&
        exists("line_break_prune_to_levels", mode = "function")) {
      line_break_prune_to_levels(moved, source = "x-category-order")
    }
  }, ignoreInit = TRUE)
