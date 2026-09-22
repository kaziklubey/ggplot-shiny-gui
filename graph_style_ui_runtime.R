# v3.69.0: extracted from graph_module.R; sourced into graphServer local environment.
# Section: STYLE-UI-BEGIN


  # ============================================================
  # Independent Color / Linetype / Shape appearance editors
  # ============================================================
  output$color_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Colorに使う列がありません。"))
    ensure_style_branch("color", v, lev); br <- isolate(color_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      colourInput(style_input_id("color_colour", v, lv), "色", value = br[[lv]], showColour = "both")
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("color", v, lev)
    tree <- isolate(color_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("color_colour", v, lv)]]
      if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) { br[[lv]] <- val; changed <- TRUE }
    }
    if (changed) { tree[[v]] <- br; color_styles(tree) }
  })

  observeEvent(input$apply_palette, {
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return()
    tree <- isolate(color_styles()); br <- tree[[v]] %||% list(); pal <- default_palette(length(lev), input$palette_preset)
    for (i in seq_along(lev)) br[[lev[i]]] <- pal[i]
    tree[[v]] <- br; color_styles(tree); style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

  output$linetype_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_linetype_var(d); lev <- linetype_style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Linetypeは固定です。"))
    ensure_style_branch("linetype", v, lev); br <- isolate(linetype_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      selectInput(style_input_id("line_type", v, lv), "線タイプ",
        choices = c("実線"="solid","破線"="dashed","点線"="dotted","一点鎖線"="dotdash","長い破線"="longdash","二重点線"="twodash"),
        selected = br[[lv]])
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_linetype_var(d); lev <- linetype_style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("linetype", v, lev)
    tree <- isolate(linetype_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("line_type", v, lv)]]
      if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) { br[[lv]] <- val; changed <- TRUE }
    }
    if (changed) { tree[[v]] <- br; linetype_styles(tree) }
  })

  output$shape_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_shape_var(d); lev <- shape_style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Shapeは固定です。"))
    ensure_style_branch("shape", v, lev); br <- isolate(shape_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      selectInput(style_input_id("point_shape", v, lv), "点の形",
        choices = c("● 丸"=16,"▲ 三角"=17,"■ 四角"=15,"◆ ひし形"=18,"+ プラス"=3,"× クロス"=4,"○ 白丸"=1,"△ 白三角"=2,"□ 白四角"=0,"◇ 白ひし形"=5),
        selected = as.character(br[[lv]]))
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_shape_var(d); lev <- shape_style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("shape", v, lev)
    tree <- isolate(shape_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("point_shape", v, lv)]]
      if (!is.null(val) && nzchar(val)) {
        num <- suppressWarnings(as.numeric(val)); if (is.finite(num) && !identical(as.numeric(br[[lv]]), num)) { br[[lv]] <- num; changed <- TRUE }
      }
    }
    if (changed) { tree[[v]] <- br; shape_styles(tree) }
  })

  # ============================================================
  # Series-specific style overrides
  # ============================================================
  output$series_style_ui <- renderUI({
    style_restore_epoch(); keys <- series_combo_levels()
    if (!isTRUE(input$series_style_override)) return(NULL)
    if (!length(keys)) return(tags$em("Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。"))
    ensure_series_styles(keys); ss <- isolate(series_styles())
    tagList(lapply(keys, function(key) tags$div(
      class = "group-style-box", tags$b(key),
      colourInput(style_input_id("series_colour", key), "色", value = ss[[key]]$color, showColour = "both")
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    keys <- series_combo_levels(); if (!length(keys)) return(); ensure_series_styles(keys)
    ss <- isolate(series_styles()); changed <- FALSE
    for (key in keys) {
      col <- input[[style_input_id("series_colour", key)]]
      if (!is.null(col) && nzchar(col) && !identical(ss[[key]]$color, col)) { ss[[key]]$color <- col; changed <- TRUE }
    }
    if (changed) series_styles(ss)
  })


  observeEvent(input$apply_series_palette, {
    if (isTRUE(restoring_style_state())) return()
    keys <- series_combo_levels()
    if (!length(keys)) return()
    ensure_series_styles(keys)
    pal <- default_palette(length(keys), input$series_palette_preset %||% "okabe_ito")
    ss <- isolate(series_styles())
    for (i in seq_along(keys)) ss[[keys[[i]]]]$color <- pal[[i]]
    series_styles(ss)
    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

  # ============================================================
  # Scatter regression styles

  # ============================================================
  regression_levels <- reactive({
    if (!isTRUE(input$scatter_regression)) return(character(0))
    mode <- input$scatter_regression_group %||% "overall"
    if (identical(mode, "overall")) return(character(0))

    d <- dat()

    if (!identical(mode, "style")) return(character(0))
    v <- resolve_color_var(d)

    if (!nzchar(v)) return(character(0))
    z <- unique(as.character(d[[v]]))
    z[!is.na(z)]
  })

  ensure_regression_styles <- function(levels_now) {
    if (!length(levels_now)) return()

    rs <- isolate(regression_styles())
    changed <- FALSE

    # 現在のColor/Linetype styleを初期値に利用
    d0 <- dat(); cv0 <- resolve_color_var(d0); lv0 <- resolve_linetype_var(d0)
    cbranch <- if (nzchar(cv0)) isolate(color_styles())[[cv0]] else list()
    lbranch <- if (nzchar(lv0)) isolate(linetype_styles())[[lv0]] else list()
    fallback_cols <- default_palette(length(levels_now), "okabe_ito")

    for (i in seq_along(levels_now)) {
      nm <- levels_now[i]
      if (is.null(rs[[nm]])) {
        col0 <- cbranch[[nm]]
        lt0 <- lbranch[[nm]]

        if (is.null(col0) || !length(col0) || is.na(col0[[1]]) || !nzchar(as.character(col0[[1]]))) {
          col0 <- fallback_cols[i]
        } else {
          col0 <- as.character(col0[[1]])
        }

        if (is.null(lt0) || !length(lt0) || is.na(lt0[[1]]) || !nzchar(as.character(lt0[[1]]))) {
          lt0 <- "solid"
        } else {
          lt0 <- as.character(lt0[[1]])
        }

        rs[[nm]] <- list(
          color = col0,
          linetype = lt0,
          width = 0.9
        )
        changed <- TRUE
      }
    }

    if (changed) regression_styles(rs)
  }

  output$scatter_regression_style_ui <- renderUI({
    style_restore_epoch()
    lev <- regression_levels()

    if (!length(lev)) {
      return(tags$em("回帰線を分けるための列をMappingで指定してください。"))
    }

    ensure_regression_styles(lev)
    # 重要: slider操作で regression_styles() が更新されても
    # renderUI自体を再生成しない。これが線幅の「戻る/飛ぶ」を防ぐ。
    rs <- isolate(regression_styles())

    tagList(lapply(lev, function(nm) {
      st <- rs[[nm]]

      tags$div(
        class = "group-style-box",
        tags$b(nm),
        fluidRow(
          column(
            4,
            colourInput(
              style_input_id("reg_colour", nm),
              "線色",
              value = st$color,
              showColour = "both"
            )
          ),
          column(
            4,
            selectInput(
              style_input_id("reg_linetype", nm),
              "線タイプ",
              choices = c(
                "実線" = "solid",
                "破線" = "dashed",
                "点線" = "dotted",
                "一点鎖線" = "dotdash",
                "長い破線" = "longdash",
                "二重点線" = "twodash"
              ),
              selected = st$linetype
            )
          ),
          column(
            4,
            sliderInput(
              style_input_id("reg_width", nm),
              "線幅",
              min = 0, max = 3,
              value = st$width, step = 0.1
            )
          )
        )
      )
    }))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    lev <- regression_levels()
    if (!length(lev)) return()

    ensure_regression_styles(lev)

    rs <- isolate(regression_styles())
    changed <- FALSE

    for (nm in lev) {
      col <- input[[style_input_id("reg_colour", nm)]]
      lt <- input[[style_input_id("reg_linetype", nm)]]
      wd <- input[[style_input_id("reg_width", nm)]]

      if (is.null(rs[[nm]])) next

      if (!is.null(col) && nzchar(col) && !identical(rs[[nm]]$color, col)) {
        rs[[nm]]$color <- col
        changed <- TRUE
      }
      if (!is.null(lt) && nzchar(lt) && !identical(rs[[nm]]$linetype, lt)) {
        rs[[nm]]$linetype <- lt
        changed <- TRUE
      }
      if (!is.null(wd) && is.finite(as.numeric(wd)) &&
          !isTRUE(all.equal(as.numeric(rs[[nm]]$width), as.numeric(wd)))) {
        rs[[nm]]$width <- as.numeric(wd)
        changed <- TRUE
      }
    }

    if (changed) regression_styles(rs)
  })

  # ============================================================
  # 個体点 custom colours
  # ============================================================
  raw_custom_colour_context <- reactive({
    d <- dat()
    cvar <- resolve_color_var(d)
    if (!nzchar(cvar)) return(NULL)

    g <- effective_position_var(d)
    combo <- isTRUE(input$series_style_override) && nzchar(g) && !identical(g, cvar)

    if (combo) {
      observed <- graph_series_combo_key(as.character(d[[cvar]]), as.character(d[[g]]))
      observed <- unique(observed[!is.na(observed)])
      preferred <- series_combo_levels()
      lev <- c(preferred[preferred %in% observed], setdiff(observed, preferred))
      if (!length(lev)) return(NULL)
      base <- series_style_vectors(lev)$color
      labels <- vapply(lev, function(k) {
        bits <- strsplit(k, " × ", fixed = TRUE)[[1]]
        if (length(bits) < 2L) return(k)
        paste0(
          level_label_values(cvar, bits[1]),
          " × ",
          level_label_values(g, paste(bits[-1], collapse = " × "))
        )
      }, character(1))
      return(list(
        key = paste0("__combo__::", cvar, "::", g),
        levels = lev,
        labels = labels,
        base = base
      ))
    }

    lev <- style_levels()
    if (!length(lev)) return(NULL)
    ensure_style_branch("color", cvar, lev)
    base <- isolate(color_styles())[[cvar]] %||% list()
    base <- setNames(vapply(lev, function(lv) as.character(base[[lv]] %||% "#333333"), character(1)), lev)
    list(
      key = cvar,
      levels = lev,
      labels = level_label_values(cvar, lev),
      base = base
    )
  })

  ensure_raw_custom_colors <- function(ctx) {
    if (is.null(ctx) || !length(ctx$levels)) return(invisible(FALSE))
    tree <- isolate(raw_group_colors())
    br <- tree[[ctx$key]] %||% list()
    changed <- FALSE
    for (lv in ctx$levels) {
      if (is.null(br[[lv]])) {
        br[[lv]] <- lighten_colour(ctx$base[[lv]] %||% "#333333", amount = 0.45)
        changed <- TRUE
      }
    }
    if (changed) {
      tree[[ctx$key]] <- br
      raw_group_colors(tree)
    }
    invisible(changed)
  }

  output$raw_group_color_ui <- renderUI({
    style_restore_epoch()
    ctx <- raw_custom_colour_context()
    if (is.null(ctx) || !length(ctx$levels)) return(tags$em("Colorに使う系列がありません。"))
    ensure_raw_custom_colors(ctx)
    br <- isolate(raw_group_colors())[[ctx$key]] %||% list()
    tagList(lapply(seq_along(ctx$levels), function(i) {
      lv <- ctx$levels[i]
      tags$div(
        class = "group-style-box",
        tags$b(ctx$labels[i]),
        colourInput(
          style_input_id("raw_colour", ctx$key, lv),
          "個体点色",
          value = br[[lv]] %||% "#555555",
          showColour = "both"
        )
      )
    }))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    ctx <- raw_custom_colour_context()
    if (is.null(ctx) || !length(ctx$levels)) return()
    ensure_raw_custom_colors(ctx)
    tree <- isolate(raw_group_colors())
    br <- tree[[ctx$key]] %||% list()
    changed <- FALSE
    for (lv in ctx$levels) {
      val <- input[[style_input_id("raw_colour", ctx$key, lv)]]
      if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) {
        br[[lv]] <- val
        changed <- TRUE
      }
    }
    if (changed) { tree[[ctx$key]] <- br; raw_group_colors(tree) }
  })

  observeEvent(input$apply_raw_palette, {
    if (isTRUE(restoring_style_state())) return()
    ctx <- raw_custom_colour_context()
    if (is.null(ctx) || !length(ctx$levels)) return()
    pal <- default_palette(length(ctx$levels), input$raw_palette_preset)
    tree <- isolate(raw_group_colors())
    br <- tree[[ctx$key]] %||% list()
    for (i in seq_along(ctx$levels)) br[[ctx$levels[i]]] <- pal[i]
    tree[[ctx$key]] <- br
    raw_group_colors(tree)
    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

