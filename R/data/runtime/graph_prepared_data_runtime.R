  eval(graph_plot_data_definitions, envir = environment())
# v3.69.0: extracted from R/editor/graph_module.R; sourced into graphServer local environment.
# Section: PREPARED-DATA-BEGIN


  # ============================================================
  # Prepared data
  # ============================================================
  last_valid_xvar <- reactiveVal(NULL)
  last_valid_yvar <- reactiveVal(NULL)

  resolved_xvar <- reactive({
    d <- dat()
    z <- graph_mapping_value("x", input$xvar)
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    z <- last_valid_xvar()
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    ""
  })

  resolved_yvar <- reactive({
    d <- dat()
    z <- graph_mapping_value("y", input$yvar)
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    z <- last_valid_yvar()
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    ""
  })

  observe({
    d <- dat()
    xv <- graph_mapping_value("x", input$xvar)
    yv <- graph_mapping_value("y", input$yvar)
    if (!is.null(xv) && length(xv) && xv %in% names(d)) last_valid_xvar(as.character(xv)[1])
    if (!is.null(yv) && length(yv) && yv %in% names(d)) last_valid_yvar(as.character(yv)[1])
  })

  plot_data <- reactive({ compute_plot_data() })

  # Summaryの条件セルは現在のMappingから自動決定する。
  # 「追加横並び / 横ずらし要因」は必要な場合だけ追加し、Lineでは
  # Color/Linetype/Shapeもtrajectory/summary groupingへ自動的に入る。
  summary_grouping_vars <- reactive({ compute_summary_grouping_vars() })

  # ID内平均モードでは、各 ID × 条件セル内の複数trialを先に1値へまとめる。
  # これによりSEMのnはtrial数ではなく個体数になる。
  id_mean_data <- reactive({ compute_id_mean_data() })

  # Raw point / ID lineも、ID内平均モードではtrial値ではなく個体平均値を描く。
  display_observation_data <- reactive({ compute_display_observation_data() })

  summary_data <- reactive({ compute_summary_data() })

  # Line/Bar の「値（集計しない）」は入力行をそのまま描画する。
  # summary_unit や ID 内平均はこのモードでは一切適用しない。
  direct_value_mode <- reactive({ compute_direct_value_mode() })

  # value モードで外部計算済みError barを描画座標へ変換するだけのhelper。
  # mean / SD / SEM / n / CI の再計算は行わない。
  # external_error_bounds is shared by Graph and state snapshots.

  output$summary_unit_status <- renderUI({
    if (identical(graph_plot_value("type", input$plot_type %||% "line"), "scatter") || isTRUE(direct_value_mode())) return(NULL)
    d <- tryCatch(plot_data(), error = function(e) NULL)
    if (is.null(d)) return(NULL)

    idv <- graph_mapping_value("id", input$idvar %||% "")
    if (!has_selection(idv) || !idv %in% names(d)) {
      return(p(
        class = "help-block",
        "「個体IDごとに先に平均」を選ぶ場合は、Mappingで個体IDを指定してください。"
      ))
    }

    grouping <- summary_grouping_vars()
    cell_vars <- unique(c(idv, grouping))
    repeated <- d %>%
      count(across(all_of(cell_vars)), name = ".n_trial__") %>%
      summarise(any_repeat = any(.n_trial__ > 1L)) %>%
      pull(.data$any_repeat)

    if (identical(graph_plot_value("summary_unit", input$summary_unit %||% "row"), "id_mean")) {
      return(p(
        class = "help-block",
        "現在はID内の複数trialを各条件セルで先に平均します。平均・SD・SEM・95%CIのnは個体数です。"
      ))
    }

    if (isTRUE(repeated)) {
      p(
        class = "help-block",
        style = "color:#8a6d3b;",
        "同じID・同じ条件セルに複数行があります。各個体をexperimental unitとして扱う場合は「個体IDごとに先に平均」を推奨します。"
      )
    } else {
      p(class = "help-block", "現在の条件セルでは各IDは1行なので、2つの集計単位は同じ平均になります。")
    }
  })

  # Selectize bindings can report NULL briefly and later re-report the visual
  # default ("sans") after restore.  Downstream plot reactives should invalidate
  # only when the *effective* mode changes, not when the browser binding merely
  # materializes the same default.
  font_family_mode_effective <- reactiveVal("sans")
  font_family_custom_effective <- reactiveVal("")

  apply_font_family_state_to_editor <- function(appearance = NULL) {
    a <- if (is.list(appearance)) appearance else list()
    ff <- app_normalize_font_family_mode(a$font_family_mode %||% "sans")
    ffc <- app_normalize_font_family_custom(a$font_family_custom %||% "")

    # Update the render-facing state first. Browser Selectize/TextInput messages
    # may be acknowledged in a later flush, but they must not change the font
    # seen by a READY plot if they merely confirm this same target.
    font_family_mode_effective(ff)
    font_family_custom_effective(ffc)
    diag(
      "FONT-RESTORE",
      paste0(
        "target_mode=", ff,
        " target_custom=", if (nzchar(ffc)) ffc else "<empty>",
        " effective=", app_effective_font_family(ff, ffc)
      )
    )
    updateSelectizeInput(
      session, "font_family_mode",
      choices = app_font_choices(ff), selected = ff, server = FALSE
    )
    updateTextInput(session, "font_family_custom", value = ffc)

    invisible(list(
      mode = ff, custom = ffc,
      effective = app_effective_font_family(ff, ffc)
    ))
  }

  observe({
    mode <- app_normalize_font_family_mode(graph_appearance_value("font_family_mode", input$font_family_mode %||% "sans"))
    old <- isolate(font_family_mode_effective())
    if (!identical(old, mode)) {
      diag("FONT-BIND", paste0("mode ", old, " -> ", mode))
      font_family_mode_effective(mode)
    }
  })

  observe({
    fam <- app_normalize_font_family_custom(graph_appearance_value("font_family_custom", input$font_family_custom %||% ""))
    old <- isolate(font_family_custom_effective())
    if (!identical(old, fam)) {
      diag(
        "FONT-BIND",
        paste0(
          "custom ", if (nzchar(old)) old else "<empty>",
          " -> ", if (nzchar(fam)) fam else "<empty>"
        )
      )
      font_family_custom_effective(fam)
    }
  })

  selected_font_family <- reactive({
    app_effective_font_family(
      font_family_mode_effective(),
      font_family_custom_effective()
    )
  })

  output$font_family_warning_ui <- renderUI({
    fam <- selected_font_family()
    backend <- as.character(app_font_catalog$backend %||% "fallback")
    if (identical(backend, "systemfonts")) {
      if (!app_font_available(fam)) {
        return(p(
          class = "help-block", style = "color:#a94442;",
          paste0("この実行環境ではフォント『", fam, "』を検出できません。保存済み設定は保持しますが、描画時に代替フォントへ置換される可能性があります。")
        ))
      }
      if (fam %in% as.character(app_font_catalog$japanese_candidates %||% character(0))) {
        return(p(class = "help-block", paste0("実環境で検出済み。日本語向け候補として優先表示: ", fam)))
      }
      return(NULL)
    }
    p(
      class = "help-block", style = "color:#8a6d3b;",
      "systemfontsを利用できないため、フォントの実在確認は行わず互換候補を表示しています。"
    )
  })

  theme_object <- reactive({ compute_theme_object() })

  # 同一X × Group × Facet内で横方向へ規則的に散らす。
  # 乱数ではないので再描画やチェックON/OFFで位置が動かない。
  # add_stable_spread is shared by Graph and state snapshots.

  # ============================================================
  # Plot notes / warnings
  # ============================================================
  plot_note <- reactive({
    plot_type_now <- graph_plot_value("type", input$plot_type %||% "line")
    x_now <- graph_mapping_value("x", input$xvar %||% "")
    group_now <- graph_mapping_value("position", input$groupvar %||% "")
    facet_now <- graph_mapping_value("facet", input$facetvar %||% "")
    summary_now <- graph_plot_value("summary", input$summary_type %||% "mean")
    d <- if (identical(plot_type_now, "scatter") || isTRUE(direct_value_mode())) {
      plot_data()
    } else {
      display_observation_data()
    }

    if (identical(plot_type_now, "scatter") &&
        has_selection(x_now) && x_now %in% names(dat())) {
      raw_x <- dat()[[x_now]]
      if (!is.numeric(raw_x)) {
        x_chr <- trimws(as.character(raw_x))
        present <- !is.na(x_chr) & nzchar(x_chr)
        x_num <- suppressWarnings(as.numeric(x_chr))
        if (any(present) && any(is.finite(x_num[present])) &&
            any(!is.finite(x_num[present]))) {
          return(paste0(
            "散布図のX列「", x_now,
            "」には数値と文字が混在しています。文字の行を捨てず、離散Xとして表示しています。",
            "数値Xとして回帰したい場合はX列を数値だけに整理してください。"
          ))
        }
      }
    }

    if (identical(plot_type_now, "bar") && identical(summary_now, "value")) {
      grouping <- c(x_now)
      if (has_selection(group_now)) grouping <- c(grouping, group_now)
      if (has_selection(facet_now)) grouping <- c(grouping, facet_now)
      dup <- d %>% count(across(all_of(unique(grouping)))) %>% filter(n > 1)
      if (nrow(dup) > 0) {
        return("『値（集計しない）』の棒グラフで同じ X × Group × Facet に複数行があります。平均化はしていないため、棒が同じ位置に重なります。必要ならIDをX/Group側に含めるか、事前に1値へ整理してください。")
      }
    }
    NULL
  })

  output$plot_note <- renderUI({
    # Plot notes are advisory only. During browser-direct Graph hydration the
    # bound Shiny mapping inputs can lag the already-accepted canonical state
    # by a flush, while the Preview itself renders correctly from GraphState.
    # Never surface that transient validation (for example "Y列を選択してください。")
    # as a stale warning above an otherwise valid plot. Real plot validation
    # still belongs to make_plot()/the Preview error shield.
    note <- tryCatch(
      plot_note(),
      error = function(e) {
        if (!inherits(e, c("shiny.silent.error", "validation"))) {
          diag("PLOT-NOTE", paste0("suppressed advisory error: ", conditionMessage(e)))
        }
        NULL
      }
    )
    if (is.null(note)) return(NULL)
    div(class = "alert alert-warning plot-note-wrap", note)
  })
