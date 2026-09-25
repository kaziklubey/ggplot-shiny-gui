# v3.69.0: extracted from R/editor/graph_module.R; sourced into graphServer local environment.
# Section: STYLE-UI-BEGIN


  # ============================================================
  # Independent Color / Linetype / Shape appearance editors
  # ============================================================
  # v4.0-rc8: Color / Linetype / Shape use persistent browser slot pools.
  # No per-level Shiny inputs are created or rebound when Graph/mapping changes.
  observe({
    style_restore_epoch()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    bar_box_now <- graph_plot_value("type", input$plot_type %||% "line") %in% c("bar", "box")
    if (!nzchar(v) || !length(lev)) {
      graph_slot_pool_publish(
        "color_style", "color_fill", list(),
        context_key = paste0("none|barbox=", bar_box_now),
        empty_text = "Colorに使う列がありません。",
        options = list(showFillNone = bar_box_now)
      )
      return()
    }
    ensure_style_branch("color", v, lev)
    br <- (color_styles())[[v]] %||% list()
    fill_tree <- fill_none_styles()
    fill_levels <- graph_bar_box_fill_none_levels(fill_tree, v)
    entries <- lapply(lev, function(lv) list(
      key = lv,
      label = lv,
      value = as.character(br[[lv]] %||% "#333333")[1],
      fillNone = lv %in% fill_levels
    ))
    graph_slot_pool_publish(
      "color_style", "color_fill", entries,
      context_key = paste(c(v, lev, paste0("barbox=", bar_box_now)), collapse = "\u001f"),
      empty_text = "Colorに使う列がありません。",
      options = list(showFillNone = bar_box_now)
    )
  })

  observeEvent(input$apply_palette, {
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return()

    # Browser-direct editors do not write palette_preset back to the Shiny
    # input mirror.  The apply action must therefore use the same accepted
    # canonical / Figure-owned working state as the derived Appearance UI.
    preset <- as.character(graph_appearance_value(
      "palette_preset", input$palette_preset %||% "okabe_ito"
    ) %||% "okabe_ito")[[1]]
    if (!nzchar(preset)) preset <- "okabe_ito"

    tree <- isolate(color_styles())
    br <- tree[[v]] %||% list()
    pal <- default_palette(length(lev), preset)
    for (i in seq_along(lev)) br[[lev[i]]] <- pal[i]
    tree[[v]] <- br
    color_styles(tree)
    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
    diag("PALETTE-APPLY", paste0(
      "preset=", preset,
      " variable=", v,
      " levels=", length(lev),
      " profile=", as.character(editor_profile %||% "unknown")[[1]]
    ))
  })

  observe({
    style_restore_epoch()
    d <- dat(); v <- resolve_linetype_var(d); lev <- linetype_style_levels()
    if (!nzchar(v) || !length(lev)) {
      graph_slot_pool_publish("linetype_style", "linetype", list(), context_key = "none", empty_text = "Linetypeは固定です。")
      return()
    }
    ensure_style_branch("linetype", v, lev)
    br <- (linetype_styles())[[v]] %||% list()
    entries <- lapply(lev, function(lv) list(
      key = lv, label = lv, value = as.character(br[[lv]] %||% "solid")[1]
    ))
    graph_slot_pool_publish(
      "linetype_style", "linetype", entries,
      context_key = paste(c(v, lev), collapse = "\u001f"),
      empty_text = "Linetypeは固定です。"
    )
  })

  observe({
    style_restore_epoch()
    d <- dat(); v <- resolve_shape_var(d); lev <- shape_style_levels()
    if (!nzchar(v) || !length(lev)) {
      graph_slot_pool_publish("shape_style", "shape", list(), context_key = "none", empty_text = "Shapeは固定です。")
      return()
    }
    ensure_style_branch("shape", v, lev)
    br <- (shape_styles())[[v]] %||% list()
    entries <- lapply(lev, function(lv) list(
      key = lv, label = lv, value = as.character(br[[lv]] %||% 16)[1]
    ))
    graph_slot_pool_publish(
      "shape_style", "shape", entries,
      context_key = paste(c(v, lev), collapse = "\u001f"),
      empty_text = "Shapeは固定です。"
    )
  })

  # ============================================================
  # Series-specific style overrides
  # ============================================================
  observe({
    style_restore_epoch(); keys <- series_combo_levels()
    enabled <- isTRUE(graph_appearance_value("series_style_override", input$series_style_override))
    if (!enabled || !length(keys)) {
      graph_slot_pool_publish(
        "series_style", "color", list(),
        context_key = paste0("enabled=", enabled),
        empty_text = "Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。"
      )
      return()
    }
    ensure_series_styles(keys)
    ss <- series_styles()
    entries <- lapply(keys, function(key) list(
      key = key, label = key, value = as.character((ss[[key]] %||% list())$color %||% "#333333")[1]
    ))
    graph_slot_pool_publish(
      "series_style", "color", entries,
      context_key = paste(keys, collapse = "\u001f"),
      empty_text = "Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。"
    )
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
    if (!isTRUE(graph_appearance_value("scatter_regression", input$scatter_regression))) return(character(0))
    mode <- graph_appearance_value("scatter_regression_group", input$scatter_regression_group %||% "overall")
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
    combo <- isTRUE(graph_appearance_value("series_style_override", input$series_style_override)) &&
      nzchar(g) && !identical(g, cvar)

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

  observe({
    style_restore_epoch()
    ctx <- raw_custom_colour_context()
    if (is.null(ctx) || !length(ctx$levels)) {
      graph_slot_pool_publish("raw_group_color", "color", list(), context_key = "none", empty_text = "Colorに使う系列がありません。")
      return()
    }
    ensure_raw_custom_colors(ctx)
    br <- (raw_group_colors())[[ctx$key]] %||% list()
    entries <- lapply(seq_along(ctx$levels), function(i) {
      lv <- ctx$levels[i]
      list(
        key = lv,
        label = as.character(ctx$labels[i] %||% lv)[1],
        value = as.character(br[[lv]] %||% "#555555")[1]
      )
    })
    graph_slot_pool_publish(
      "raw_group_color", "color", entries,
      context_key = paste(c(ctx$key, ctx$levels), collapse = "\u001f"),
      empty_text = "Colorに使う系列がありません。"
    )
  })

  observeEvent(input$apply_raw_palette, {
    if (isTRUE(restoring_style_state())) return()
    ctx <- raw_custom_colour_context()
    if (is.null(ctx) || !length(ctx$levels)) return()
    raw_preset <- as.character(graph_appearance_value(
      "raw_palette_preset", input$raw_palette_preset %||% "okabe_ito"
    ) %||% "okabe_ito")[[1]]
    if (!nzchar(raw_preset)) raw_preset <- "okabe_ito"
    pal <- default_palette(length(ctx$levels), raw_preset)
    tree <- isolate(raw_group_colors())
    br <- tree[[ctx$key]] %||% list()
    for (i in seq_along(ctx$levels)) br[[ctx$levels[i]]] <- pal[i]
    tree[[ctx$key]] <- br
    raw_group_colors(tree)
    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

  # One event channel handles all persistent slot-pool user edits.  Programmatic
  # pool hydration never enters Shiny input bindings, so it cannot be mistaken
  # for a live user edit during Graph replay.
  observeEvent(input$graph_slot_pool_event, {
    if (isTRUE(graph_state_replay_active()) || isTRUE(restoring_style_state())) return()
    evt <- input$graph_slot_pool_event
    if (!is.list(evt)) return()
    pool <- as.character(evt$pool %||% "")[1]
    key <- as.character(evt$key %||% "")[1]
    field <- as.character(evt$field %||% "value")[1]
    value <- evt$value
    if (!nzchar(pool) || !nzchar(key)) return()
    if (!graph_slot_pool_event_valid(evt, pool) || !graph_slot_pool_event_key_active(evt, pool)) return()
    canonical <- isolate(attached_state_seed())
    mp <- if (is.list(canonical)) canonical$mapping %||% list() else list()
    color_var <- json_chr(mp$color, "")
    if (identical(color_var, "__fixed__")) color_var <- ""
    linetype_mode <- json_chr(mp$linetype, "__color__")
    linetype_var <- if (identical(linetype_mode, "__color__")) color_var else linetype_mode
    shape_mode <- json_chr(mp$shape, "__color__")
    shape_var <- if (identical(shape_mode, "__color__")) color_var else shape_mode

    if (identical(pool, "color_style")) {
      v <- color_var
      if (!nzchar(v)) return()
      if (identical(field, "value")) {
        z <- as.character(value %||% "")[1]
        if (!nzchar(z)) return()
        tree <- isolate(color_styles()); br <- tree[[v]] %||% list()
        if (!identical(as.character(br[[key]] %||% "")[1], z)) { br[[key]] <- z; tree[[v]] <- br; color_styles(tree) }
      } else if (identical(field, "fillNone") && json_chr((canonical$plot %||% list())$type, "line") %in% c("bar", "box")) {
        tree <- isolate(fill_none_styles())
        old <- key %in% graph_bar_box_fill_none_levels(tree, v)
        z <- isTRUE(value)
        if (!identical(old, z)) fill_none_styles(graph_bar_box_set_fill_none(tree, v, key, z))
      }
      return()
    }

    if (identical(pool, "linetype_style")) {
      v <- linetype_var
      z <- as.character(value %||% "")[1]
      if (!nzchar(v) || !nzchar(z)) return()
      tree <- isolate(linetype_styles()); br <- tree[[v]] %||% list()
      if (!identical(as.character(br[[key]] %||% "")[1], z)) { br[[key]] <- z; tree[[v]] <- br; linetype_styles(tree) }
      return()
    }

    if (identical(pool, "shape_style")) {
      v <- shape_var
      z <- suppressWarnings(as.numeric(value)[1])
      if (!nzchar(v) || !is.finite(z)) return()
      tree <- isolate(shape_styles()); br <- tree[[v]] %||% list()
      if (!isTRUE(all.equal(as.numeric(br[[key]] %||% NA_real_), z))) { br[[key]] <- z; tree[[v]] <- br; shape_styles(tree) }
      return()
    }

    if (identical(pool, "series_style")) {
      z <- as.character(value %||% "")[1]
      if (!isTRUE(((canonical$style %||% list())$appearance %||% list())$series_style_override) || !nzchar(z)) return()
      ss <- isolate(series_styles())
      if (!identical(as.character((ss[[key]] %||% list())$color %||% "")[1], z)) { ss[[key]]$color <- z; series_styles(ss) }
      return()
    }

    if (identical(pool, "raw_group_color")) {
      ctx <- isolate(graph_slot_pool_contexts[[pool]])
      ctx_key <- strsplit(as.character((ctx %||% list())$context_key %||% "")[1], "\u001f", fixed = TRUE)[[1]][1]
      z <- as.character(value %||% "")[1]
      if (!nzchar(ctx_key) || !nzchar(z)) return()
      tree <- isolate(raw_group_colors()); br <- tree[[ctx_key]] %||% list()
      if (!identical(as.character(br[[key]] %||% "")[1], z)) { br[[key]] <- z; tree[[ctx_key]] <- br; raw_group_colors(tree) }
      return()
    }
  }, ignoreInit = TRUE)
