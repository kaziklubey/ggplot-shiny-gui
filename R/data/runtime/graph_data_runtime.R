  # Section: DATA-BEGIN


  # ============================================================
  # Data source contract
  # ============================================================
  # Full Editor owns an editable Ace input. Figure controls deliberately have
  # no Data/reshape inputs and read the attached Figure-owned GraphState instead.
  # The shared plotting/mapping pipeline below only consumes raw_dat()/dat() and
  # therefore does not need to know which editor profile supplied the data.
  editor_has_data_controls <- graph_editor_profile_has(editor_profile, "editable_data")
  editor_has_reshape_controls <- graph_editor_profile_has(editor_profile, "reshape_controls")

  validate_editor_raw_data <- function(x) {
    shiny::validate(shiny::need(
      !is.null(x),
      "データを読み込めませんでした。タブ区切り、または空白区切りか確認してください。"
    ))
    shiny::validate(shiny::need(ncol(x) >= 1, "1列以上のデータが必要です。"))
    header_status <- graph_data_column_name_status(x)
    shiny::validate(shiny::need(
      isTRUE(header_status$valid),
      header_status$message %||% "列名を確認してください。"
    ))
    x
  }

  raw_dat <- reactive({
    graph_cold_diag_measure("raw_dat", function() {
      if (isTRUE(graph_state_replay_active())) {
        plan <- graph_mapping_replay_plan()
        req(is.list(plan))
        return(validate_editor_raw_data(plan$raw))
      }

    # once a Graph owns the persistent Editor,
    # Data is read only from the accepted canonical GraphState attachment. The one
    # exception is the pristine startup bootstrap before any GraphState has been
    # attached: use the deterministic built-in sample directly. The Ace DOM is
    # never read as a server-side ownership fallback.
    base <- attached_state_seed()
    if (is.list(base) && !is.null(base$data_text)) {
      return(validate_editor_raw_data(
        graph_parse_pasted_data(graph_state_scalar(base$data_text, ""))
      ))
    }
    if (isTRUE(editor_has_data_controls)) {
      return(validate_editor_raw_data(graph_parse_pasted_data(graph_sample_data_text())))
    }
      req(FALSE)
    })
  })


  # Ace Data editing has one explicit document transport. The browser payload
  # contains graphId/generation/seq/text, so delayed edits remain attached to
  # the Graph/lease where they were created. Native input$text is intentionally
  # not observed as a commit source.
  observeEvent(input$data_document_patch, {
    if (!isTRUE(editor_has_data_controls)) return()
    if (!graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (!is.function(on_data_document_patch)) return()

    evt <- input$data_document_patch
    if (!is.list(evt)) return()
    accepted <- tryCatch(
      isTRUE(on_data_document_patch(evt)),
      error = function(e) {
        diag("DATA-DOCUMENT-TRANSPORT", paste0("commit error: ", conditionMessage(e)))
        FALSE
      }
    )
    if (isTRUE(accepted)) {
      diag(
        "DATA-DOCUMENT-TRANSPORT",
        paste0(
          "accepted graph=", as.character(evt$graphId %||% "")[[1]],
          " generation=", as.integer(evt$generation %||% 0L),
          " seq=", as.integer(evt$seq %||% 0L),
          " chars=", nchar(as.character(evt$text %||% "")[[1]], type = "chars")
        )
      )
    }
  }, ignoreInit = TRUE, priority = 180)

  output$data_document_status <- renderUI({
    graph_cold_diag_measure("output$data_document_status", function() {
    if (!isTRUE(editor_has_data_controls)) return(NULL)
    base <- attached_state_seed()
    if (!is.list(base)) return(NULL)
    doc <- graph_data_document_from_state(base)
    if (!identical(doc$parse_status, "invalid")) return(NULL)
    div(
      class = "alert alert-warning",
      style = "padding:6px 9px; margin-top:6px; margin-bottom:0;",
      tags$b("入力中のDataはまだ解析できません。"),
      tags$br(),
      tags$small("入力内容はこのGraphに保存されています。Plot / Statisticsは最後に正常に解析できたDataを使います。")
    )
    })
  })

  # Wide→Long変換エラーはアプリ全体へ伝播させず、
  # 元データへフォールバックして利用者へ表示する。
  reshape_warning <- reactiveVal(NULL)

  # When an incompatible Wide→Long selection is auto-disabled once, the next
  # manual enable enters an edit/recovery mode. In that mode the transform may
  # stay invalid (and the raw data continues to be used), but the checkbox is
  # not immediately forced OFF again. This keeps the column checklist visible
  # long enough for the user to repair mixed-type selections such as numeric +
  # character columns. Recovery ends as soon as a valid transform succeeds.
  reshape_edit_recovery <- reactiveVal(FALSE)

  set_reshape_warning <- function(msg = NULL) {
    old <- isolate(reshape_warning())
    if (identical(old, msg)) return(invisible(FALSE))
    reshape_warning(msg)
    invisible(TRUE)
  }

  output$reshape_warning_ui <- renderUI({
    graph_cold_diag_measure("output$reshape_warning_ui", function() {
    if (!isTRUE(editor_has_reshape_controls)) return(NULL)
    msg <- reshape_warning()
    if (is.null(msg) || !nzchar(msg)) return(NULL)

    editing <- isTRUE(reshape_edit_recovery()) && isTRUE(graph_reshape_value("enabled", input$reshape_wide))
    div(
      class = "alert alert-warning",
      style = "padding:6px 9px; margin-top:6px; margin-bottom:8px;",
      tags$b(if (editing) "Wide→Long変換を保留しています。" else "Wide→Long変換を停止しました。"),
      tags$br(),
      "元データをそのまま使用しています。",
      tags$br(),
      if (editing) tags$small("列の選択を修正してください。候補リストは開いたまま編集できます。"),
      if (editing) tags$br(),
      tags$small(msg)
    )
    })
  })

  plot_data_transform_recipe <- reactive({
    if (isTRUE(graph_state_replay_active())) {
      plan <- graph_mapping_replay_plan()
      req(is.list(plan))
      return(plan$recipe)
    }

    # Reshape follows the same ownership rule as raw Data. Canonical GraphState is
    # authoritative after attach; only the pristine startup bootstrap may read the
    # mounted Shiny controls so the initial sample/default GraphState can be built.
    base <- attached_state_seed()
    if (is.list(base)) {
      r <- base$reshape %||% list()
      return(graph_plot_data_transform_recipe(
        enabled = isTRUE(r$enabled),
        row_id = isTRUE(r$row_id),
        columns = r$columns %||% character(0),
        x_name = r$x_name %||% "Time",
        y_name = r$y_name %||% "Value"
      ))
    }
    if (isTRUE(editor_has_reshape_controls)) {
      return(graph_plot_data_transform_recipe(
        enabled = isTRUE(input$reshape_wide),
        row_id = isTRUE(input$reshape_row_id),
        columns = input$reshape_columns %||% character(0),
        x_name = input$reshape_x_name %||% "Time",
        y_name = input$reshape_y_name %||% "Value"
      ))
    }
    req(FALSE)
  })

  # Plot source data is the raw Graph dataset plus only the Plot-owned transform
  # recipe. Keep this name distinct from the longstanding prepared plot_data()
  # reactive in R/data/runtime/graph_prepared_data_runtime.R; both files share one graphServer
  # environment, so reusing plot_data would create dat() <-> plot_data() recursion.
  plot_source_data <- reactive({
    graph_cold_diag_measure("plot_source_data", function() {
    # Replay owns one target-derived data plan. Reuse its already-transformed
    # source instead of parsing/reshaping the same Data Document again inside
    # the flush that must complete before browser hydration can be sent.
    if (isTRUE(graph_state_replay_active())) {
      plan <- graph_mapping_replay_plan()
      req(is.list(plan), is.data.frame(plan$source_data))
      set_reshape_warning(plan$transform_warning %||% NULL)
      return(plan$source_data)
    }

    d0 <- raw_dat()
    rec <- plot_data_transform_recipe()
    res <- graph_apply_data_transform(
      d0,
      rec,
      incomplete_is_warning = FALSE
    )
    set_reshape_warning(res$warning)
      res$data
    })
  })

  # Shared Plot pipeline: reshape, then Filter. During replay the same canonical
  # plan already owns the filtered data, so no second Filter pass is performed.
  # Statistics defaults to raw_dat(), but an Analysis can explicitly opt into active_plot_data().
  active_plot_data <- reactive({
    graph_cold_diag_measure("active_plot_data", function() {
      if (isTRUE(graph_state_replay_active())) {
        plan <- graph_mapping_replay_plan()
        req(is.list(plan), is.data.frame(plan$data))
        return(plan$data)
      }
      graph_plot_filter_apply(plot_source_data(), (attached_state_seed() %||% list())$plot_filter)
    })
  })
  dat <- reactive({ graph_cold_diag_measure("dat", function() active_plot_data()) })

  # Incompatible selected columns (for example numeric phase2 + character
  # phase) are not a valid wide measurement selection. The first failure is
  # auto-disabled so Mapping can continue on raw data. If the user enables the
  # transform again, keep the panel open in recovery mode instead of repeatedly
  # closing it before the offending column selection can be edited.
  observe({
    if (!isTRUE(editor_has_reshape_controls)) return()
    if (isTRUE(graph_state_replay_active())) return()

    msg <- reshape_warning()
    enabled <- isTRUE(graph_reshape_value("enabled", input$reshape_wide))

    # Do not clear recovery while the checkbox is OFF: the next manual enable
    # needs that grace period. A successful enabled transform ends recovery.
    if (is.null(msg) || !nzchar(msg)) {
      if (enabled && isTRUE(reshape_edit_recovery())) {
        reshape_edit_recovery(FALSE)
      }
      return()
    }
    if (!enabled) return()

    if (grepl("結合できません", msg, fixed = TRUE)) {
      if (isTRUE(reshape_edit_recovery())) return()
      reshape_edit_recovery(TRUE)
      updateCheckboxInput(
        session,
        "reshape_wide",
        value = FALSE
      )
    }
  })

  # Browser-direct controls are resolved through one canonical read boundary.
  # Full Editor reads the attached accepted GraphState; Figure Controls read the
  # frozen Figure-owned state plus their local working overlay.
  graph_mapping_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      x = "xvar", y = "yvar", position = "groupvar", color = "colorvar",
      linetype = "linetypevar", shape = "shapevar", id = "idvar",
      facet = "facetvar", line_series_mode = "line_series_mode",
      line_series_var = "line_series_var", external_error = "external_error_col",
      external_ymin = "external_ymin_col", external_ymax = "external_ymax_col",
      ""
    )
    if (!nzchar(input_key)) return(fallback)
    graph_browser_owned_scalar(input_key, fallback)
  }

  graph_plot_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      type = "plot_type", bar_layout = "bar_layout", bar_value_source = "bar_value_source",
      summary = "summary_type", summary_unit = "summary_unit",
      external_error_mode = "external_error_mode", show_raw = "show_raw",
      connect_id = "connect_id", scatter_connect_mode = "scatter_connect_mode",
      individual_connect_direction = "individual_connect_direction",
      line_breaks = "line_breaks", ""
    )
    if (!nzchar(input_key)) return(fallback)
    if (identical(input_key, "line_breaks")) {
      return(graph_browser_owned_value(input_key, fallback))
    }
    graph_browser_owned_scalar(input_key, fallback)
  }

  graph_label_value <- function(key, fallback = "") {
    input_key <- switch(
      as.character(key %||% "")[1],
      xlab = "xlab", ylab = "ylab", title = "title", ymin = "ymin", ymax = "ymax",
      y_top_to_tick = "y_top_to_tick", ""
    )
    if (!nzchar(input_key)) return(fallback)
    graph_browser_owned_scalar(input_key, fallback)
  }

  graph_reshape_value <- function(key, fallback = NULL) {
    input_key <- switch(
      as.character(key %||% "")[1],
      enabled = "reshape_wide", row_id = "reshape_row_id", columns = "reshape_columns",
      x_name = "reshape_x_name", y_name = "reshape_y_name", ""
    )
    if (!nzchar(input_key)) return(fallback)
    if (identical(input_key, "reshape_columns")) {
      return(graph_browser_owned_value(input_key, fallback))
    }
    graph_browser_owned_scalar(input_key, fallback)
  }

  graph_appearance_value <- function(key, fallback = "") {
    graph_browser_owned_scalar(as.character(key %||% "")[1], fallback)
  }

  effective_position_var <- function(d = NULL) {
    plot_now <- graph_plot_value("type", input$plot_type %||% "line")
    if (!graph_plot_supports_position(plot_now)) return("")
    v <- graph_mapping_value("position", input$groupvar %||% "")
    if (!has_selection(v)) return("")
    if (!is.null(d) && !v %in% names(d)) return("")
    v
  }

  resolve_color_var <- function(d) {
    mode <- graph_mapping_value("color", input$colorvar %||% "")
    if (identical(mode, "__fixed__") || !nzchar(mode)) return("")
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  resolve_linetype_var <- function(d) {
    # LinetypeはLine、またはScatterの接続線で使用する。
    if (!graph_plot_supports_mapping(graph_plot_value("type", input$plot_type %||% "line"), "linetype")) return("")
    mode <- graph_mapping_value("linetype", input$linetypevar %||% "__color__")
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  resolve_shape_var <- function(d) {
    mode <- graph_mapping_value("shape", input$shapevar %||% "__color__")
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  active_display_label_vars <- reactive({
    d <- dat()
    vars <- c(
      resolved_xvar() %||% "",
      effective_position_var(d),
      resolve_color_var(d),
      resolve_linetype_var(d),
      resolve_shape_var(d),
      graph_mapping_value("facet", input$facetvar %||% "")
    )
    vars <- unique(vars[nzchar(vars) & vars %in% names(d)])

    # Scatterの数値Xはカテゴリ名変更の対象外。
    if (identical(graph_plot_value("type", input$plot_type %||% "line"), "scatter") &&
        has_selection(resolved_xvar()) &&
        resolved_xvar() %in% vars) {
      vars <- setdiff(vars, resolved_xvar())
    }
    vars
  })

  active_legend_specs <- reactive({
    d <- dat()
    cvar0 <- resolve_color_var(d)
    lvar0 <- resolve_linetype_var(d)
    svar0 <- resolve_shape_var(d)
    g0 <- effective_position_var(d)

    combo0 <- isTRUE(graph_appearance_value("series_style_override", input$series_style_override)) &&
      nzchar(g0) && nzchar(cvar0) && !identical(g0, cvar0)

    color_key <- if (combo0) paste0("__combo__::", cvar0, "::", g0) else cvar0
    color_default <- if (combo0) paste0(cvar0, " × ", g0) else cvar0

    specs <- list()

    if (nzchar(cvar0)) {
      specs[[color_key]] <- list(
        key = color_key,
        default = color_default,
        used_by = "色"
      )
    }

    line_mode <- graph_mapping_value("linetype", input$linetypevar %||% "__color__")
    if (!identical(line_mode, "") && nzchar(lvar0)) {
      k <- if (identical(line_mode, "__color__") && !combo0) color_key else lvar0
      def <- if (identical(line_mode, "__color__") && !combo0) color_default else lvar0
      if (!is.null(specs[[k]])) {
        specs[[k]]$used_by <- paste(specs[[k]]$used_by, "線の種類", sep = "・")
      } else {
        specs[[k]] <- list(key = k, default = def, used_by = "線の種類")
      }
    }

    shape_mode0 <- graph_mapping_value("shape", input$shapevar %||% "__color__")
    if (!identical(shape_mode0, "") && nzchar(svar0)) {
      k <- if (identical(shape_mode0, "__color__") && !combo0) color_key else svar0
      def <- if (identical(shape_mode0, "__color__") && !combo0) color_default else svar0
      if (!is.null(specs[[k]])) {
        specs[[k]]$used_by <- paste(specs[[k]]$used_by, "点の形", sep = "・")
      } else {
        specs[[k]] <- list(key = k, default = def, used_by = "点の形")
      }
    }

    specs
  })

  legend_spec_levels <- function(spec_key, d) {
    key <- as.character(spec_key %||% "")[1]
    if (!nzchar(key)) return(list(levels = character(0), defaults = character(0)))

    if (startsWith(key, "__combo__::")) {
      parts <- strsplit(sub("^__combo__::", "", key), "::", fixed = TRUE)[[1]]
      if (length(parts) < 2L) return(list(levels = character(0), defaults = character(0)))
      cv <- parts[1]; gv <- paste(parts[-1], collapse = "::")
      if (!cv %in% names(d) || !gv %in% names(d)) return(list(levels = character(0), defaults = character(0)))

      observed <- graph_series_combo_key(as.character(d[[cv]]), as.character(d[[gv]]))
      observed <- unique(observed[!is.na(observed)])
      preferred <- series_combo_levels()
      lev <- c(preferred[preferred %in% observed], setdiff(observed, preferred))
      defaults <- vapply(lev, function(k) {
        bits <- strsplit(k, " × ", fixed = TRUE)[[1]]
        if (length(bits) < 2L) return(k)
        left <- level_label_values(cv, bits[1])
        right <- level_label_values(gv, paste(bits[-1], collapse = " × "))
        paste0(left, " × ", right)
      }, character(1))
      return(list(levels = lev, defaults = defaults))
    }

    if (!key %in% names(d)) return(list(levels = character(0), defaults = character(0)))
    z <- d[[key]]
    lev <- levels(z)
    if (is.null(lev) || !length(lev)) lev <- unique(as.character(z))
    lev <- lev[!is.na(lev)]
    list(levels = lev, defaults = level_label_values(key, lev))
  }

  output$legend_item_labels_ui <- renderUI({
    graph_cold_diag_measure("output$legend_item_labels_ui", function() {
    style_restore_epoch()
    level_labels()
    shared_style_ui_epoch()
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return(NULL)
    specs <- active_legend_specs()
    if (!length(specs)) return(tags$em("現在、編集できる凡例項目はありません。"))

    state <- isolate(legend_item_labels())
    cards <- lapply(specs, function(spec) {
      info <- legend_spec_levels(spec$key, d)
      if (!length(info$levels)) return(NULL)
      branch <- state[[spec$key]] %||% list()

      tags$div(
        class = "group-style-box",
        tags$b(paste0(spec$used_by, "：", spec$default)),
        lapply(seq_along(info$levels), function(i) {
          lv <- info$levels[i]
          def <- info$defaults[i]
          current <- branch[[lv]]
          explicit_value <- if (is.null(current) || !length(current) ||
                                !nzchar(trimws(as.character(current)[1]))) "" else as.character(current)[1]
          fluidRow(
            column(5, tags$div(style = "padding-top:7px;", def)),
            column(
              7,
              textInput(
                style_input_id("legend_item_label", spec$key, lv),
                label = NULL,
                value = explicit_value,
                placeholder = def
              )
            )
          )
        })
      )
    })

    tagList(cards)
    })
  })

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    if (isTRUE(restoring_style_state())) return()

    # Shared Style applies level_labels() before renderUI can replace these
    # dynamic text inputs. Without this one-epoch guard, an old DOM default
    # such as "Pre" can be read against the new default "Pre Common" and be
    # incorrectly stored as an explicit legend-only override.
    sync_epoch <- as.integer(shared_style_ui_epoch() %||% 0L)
    seen_epoch <- as.integer(isolate(legend_item_shared_sync_seen()) %||% 0L)
    if (!identical(sync_epoch, seen_epoch)) {
      legend_item_shared_sync_seen(sync_epoch)
      return()
    }

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()
    specs <- active_legend_specs()
    if (!length(specs)) return()

    state <- isolate(legend_item_labels())
    changed <- FALSE

    for (spec in specs) {
      info <- legend_spec_levels(spec$key, d)
      if (!length(info$levels)) next
      branch <- state[[spec$key]] %||% list()

      for (i in seq_along(info$levels)) {
        lv <- info$levels[i]
        def <- info$defaults[i]
        id0 <- style_input_id("legend_item_label", spec$key, lv)
        z <- input[[id0]]
        if (is.null(z)) next
        z <- as.character(z)[1]
        old <- branch[[lv]]

        # Empty/default text means "follow the ordinary condition display name".
        if (!nzchar(trimws(z)) || identical(z, def)) {
          if (!is.null(old)) { branch[[lv]] <- NULL; changed <- TRUE }
        } else if (is.null(old) || !identical(as.character(old)[1], z)) {
          branch[[lv]] <- z
          changed <- TRUE
        }
      }

      if (length(branch)) state[[spec$key]] <- branch else state[[spec$key]] <- NULL
    }

    if (changed) legend_item_labels(state)
  })

  # The display-name Editor has its own topology/commit boundary. Neither
  # keystrokes nor unrelated canonical state revisions may re-mount its textareas.
  # See graph_display_label_input_runtime.R (same graphServer owner environment).
  sys.source(file.path(getwd(), "R/data/runtime/graph_display_label_input_runtime.R"), envir = environment())

  group_levels <- reactive({
    d <- dat()
    v <- effective_position_var(d)
    if (!nzchar(v)) return(character(0))
    observed <- unique(as.character(d[[v]]))
    observed <- observed[!is.na(observed)]
    get_saved_order("group", v, observed)
  })

  style_levels <- reactive({
    d <- dat()
    v <- resolve_color_var(d)
    if (!nzchar(v)) return(character(0))
    ordered_levels_for_var(d, v)
  })

  linetype_style_levels <- reactive({
    d <- dat(); v <- resolve_linetype_var(d)
    if (!nzchar(v) || !v %in% names(d)) return(character(0))
    ordered_levels_for_var(d, v)
  })

  shape_style_levels <- reactive({
    d <- dat(); v <- resolve_shape_var(d)
    if (!nzchar(v) || !v %in% names(d)) return(character(0))
    ordered_levels_for_var(d, v)
  })

  x_levels <- reactive({
    d <- dat()
    x_now <- graph_mapping_value("x", input$xvar %||% "")
    if (!has_selection(x_now) || !x_now %in% names(d)) return(character(0))
    observed <- unique(as.character(d[[x_now]]))
    observed <- observed[!is.na(observed)]
    get_saved_order("x", x_now, observed)
  })

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    d <- dat()
    cv <- resolve_color_var(d); lv <- resolve_linetype_var(d); sv <- resolve_shape_var(d)
    cl <- style_levels(); ll <- linetype_style_levels(); shl <- shape_style_levels()
    if (nzchar(cv) && length(cl)) ensure_style_branch("color", cv, cl)
    if (nzchar(lv) && length(ll)) ensure_style_branch("linetype", lv, ll)
    if (nzchar(sv) && length(shl)) ensure_style_branch("shape", sv, shl)
  })
