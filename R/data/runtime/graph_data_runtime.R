# v3.69.0: extracted from R/editor/graph_module.R; sourced into graphServer local environment.
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
    shiny::validate(shiny::need(ncol(x) >= 2, "2列以上のデータが必要です。"))
    header_status <- graph_data_column_name_status(x)
    shiny::validate(shiny::need(
      isTRUE(header_status$valid),
      header_status$message %||% "列名を確認してください。"
    ))
    x
  }

  raw_dat <- reactive({
    if (isTRUE(graph_state_replay_active())) {
      plan <- graph_mapping_replay_plan()
      req(is.list(plan))
      return(validate_editor_raw_data(plan$raw))
    }

    # v4.0.1-data-canonical-bootstrap1: once a Graph owns the persistent Editor,
    # Data is read only from the accepted canonical GraphState attachment. The one
    # exception is the pristine startup bootstrap before any GraphState has been
    # attached: the default Graph template must be capturable from the mounted Ace
    # controls. This fallback is unreachable after the first canonical attach, so
    # ordinary user edits never reintroduce the old input$text/canonical split.
    base <- attached_state_seed()
    if (is.list(base) && !is.null(base$data_text)) {
      return(validate_editor_raw_data(
        graph_parse_pasted_data(graph_state_scalar(base$data_text, ""))
      ))
    }
    if (isTRUE(editor_has_data_controls)) {
      return(validate_editor_raw_data(graph_parse_pasted_data(input$text)))
    }
    req(FALSE)
  })


  # v4.0.1-mapping-style-canonical1: Data text is the one Full-Editor field that does
  # not use the generic browser-patch queue. shinyAce owns browser -> Shiny
  # rate policy; once input$text settles, send that single value to the outer
  # canonical GraphState owner. Plot/Data View continue to read only the accepted
  # attached GraphState, so input$text is transport only, never canonical truth.
  observeEvent(input$text, {
    if (!isTRUE(editor_has_data_controls)) return()
    if (!graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (isTRUE(graph_state_replay_active())) return()
    if (!is.function(on_data_text_commit)) return()

    base <- isolate(attached_state_seed())
    if (!is.list(base)) return()

    text_now <- as.character(input$text %||% "")[1]
    if (identical(text_now, graph_state_scalar(base$data_text, ""))) return()

    accepted <- tryCatch(
      isTRUE(on_data_text_commit(text_now)),
      error = function(e) {
        diag("DATA-TEXT-TRANSPORT", paste0("commit error: ", conditionMessage(e)))
        FALSE
      }
    )
    if (isTRUE(accepted)) {
      line_count <- if (!nzchar(text_now)) 0L else length(strsplit(text_now, "\n", fixed = TRUE)[[1]])
      diag(
        "DATA-TEXT-TRANSPORT",
        paste0("accepted chars=", nchar(text_now, type = "chars"), " lines=", line_count)
      )
    }
  }, ignoreInit = TRUE, priority = 170)


  # Wide→Long変換エラーはアプリ全体へ伝播させず、
  # 元データへフォールバックして利用者へ表示する。
  reshape_warning <- reactiveVal(NULL)

  # When an incompatible Wide→Long selection is auto-disabled once, the next
  # manual enable enters an edit/recovery mode.  In that mode the transform may
  # stay invalid (and the raw data continues to be used), but the checkbox is
  # not immediately forced OFF again.  This keeps the column checklist visible
  # long enough for the user to repair mixed-type selections such as numeric +
  # character columns.  Recovery ends as soon as a valid transform succeeds.
  reshape_edit_recovery <- reactiveVal(FALSE)

  # Short-lived value seed used only while canonical GraphState replay updates
  # Wide→Long selections in the persistent Editor. No browser binding handshake
  # or staged restore transaction is involved.
  reshape_restore_seed <- reactiveVal(NULL)

  set_reshape_warning <- function(msg = NULL) {
    old <- isolate(reshape_warning())
    if (identical(old, msg)) return(invisible(FALSE))
    reshape_warning(msg)
    invisible(TRUE)
  }

  output$reshape_warning_ui <- renderUI({
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

  # v3.73.2.18: reshape_columns is permanently mounted in R/editor/ui/graph_ui_module.R.
  # Its choices are updated in place; no server-rendered duplicate UI exists.

  # v3.62.0-fixedref1: reshape_columns is a persistent input in the fixed
  # Graph Editor DOM.  Only choices/selection change; the input binding itself
  # is never destroyed when another Graph becomes the editor target.
  observe({
    if (!isTRUE(editor_has_reshape_controls)) return()
    if (graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (isTRUE(graph_state_replay_active())) return()
    d0 <- raw_dat()
    req(d0)
    if (!graph_mapping_choices_changed("reshape", d0)) return()
    cols <- graph_usable_column_names(d0)
    if (!length(cols)) return()
    default_cols <- graph_default_reshape_columns(d0)

    restore_cols <- isolate(reshape_restore_seed())
    restore_keep <- if (!is.null(restore_cols) && length(restore_cols)) {
      as.character(restore_cols)[as.character(restore_cols) %in% cols]
    } else character(0)
    current_cols <- isolate(graph_reshape_value("columns", input$reshape_columns))
    current_keep <- if (!is.null(current_cols) && length(current_cols)) {
      as.character(current_cols)[as.character(current_cols) %in% cols]
    } else character(0)
    selected_cols <- if (length(restore_keep)) restore_keep else if (length(current_keep)) current_keep else default_cols

    updateCheckboxGroupInput(
      session, "reshape_columns",
      choices = cols,
      selected = selected_cols
    )
  }, priority = 120)

  observe({
    if (!isTRUE(editor_has_reshape_controls)) return()
    if (isTRUE(graph_state_replay_active())) return()
    seed <- reshape_restore_seed()
    if (is.null(seed)) return()
    current <- graph_reshape_value("columns", input$reshape_columns %||% character(0))
    if (identical(as.character(current), as.character(seed))) reshape_restore_seed(NULL)
  }, priority = 119)

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
    d0 <- raw_dat()
    rec <- plot_data_transform_recipe()
    res <- graph_apply_data_transform(
      d0,
      rec,
      # During value replay, an incomplete column selection is transient.
      incomplete_is_warning = FALSE
    )
    set_reshape_warning(res$warning)
    res$data
  })

  # Compatibility name used by the existing Plot pipeline. New non-Plot
  # consumers should choose raw_dat() or plot_source_data() explicitly.
  dat <- reactive({
    plot_source_data()
  })

  # Incompatible selected columns (for example numeric phase2 + character
  # phase) are not a valid wide measurement selection.  The first failure is
  # auto-disabled so Mapping can continue on raw data.  If the user enables the
  # transform again, keep the panel open in recovery mode instead of repeatedly
  # closing it before the offending column selection can be edited.
  observe({
    if (!isTRUE(editor_has_reshape_controls)) return()
    if (isTRUE(graph_state_replay_active())) return()

    msg <- reshape_warning()
    enabled <- isTRUE(graph_reshape_value("enabled", input$reshape_wide))

    # Do not clear recovery while the checkbox is OFF: the next manual enable
    # needs that grace period.  A successful enabled transform ends recovery.
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

  # Replay時、plot-type依存のdynamic UI choice更新より先にcanonical値を
  # 保持しておく。updateSelectInput()のタイミング依存を避ける。
  restore_position_seed <- reactiveVal(NULL)
  restore_linetype_seed <- reactiveVal(NULL)
  # Replay中、Error bar列のdynamic selectInputが自動候補で
  # canonical値を上書きしないよう一時的に保持するseed。
  restore_external_error_seed <- reactiveVal(NULL)
  restore_external_ymin_seed <- reactiveVal(NULL)
  restore_external_ymax_seed <- reactiveVal(NULL)

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    seed <- restore_position_seed()
    if (is.null(seed) || !length(seed)) return()
    expected <- as.character(seed)[1]
    actual <- graph_mapping_value("position", input$groupvar %||% "")
    if (identical(actual, expected)) {
      restore_position_seed(NULL)
    }
  })

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    seed <- restore_linetype_seed()
    if (is.null(seed) || !length(seed)) return()
    expected <- as.character(seed)[1]
    actual <- graph_mapping_value("linetype", input$linetypevar %||% "__color__")
    if (identical(actual, expected)) {
      restore_linetype_seed(NULL)
    }
  })

  # v3.62.0-fixedref1: X/Y/Color/Shape/ID/Facet are persistent selectInputs
  # created once by R/editor/ui/graph_ui_module.R.  This observer only updates choices and
  # selected values.  Switching Graphs therefore does not replace the Mapping
  # DOM or its Shiny input bindings.
  observe({
    # Full Editor choice topology is owned by one browser-direct hydration
    # payload. Figure Controls retain the legacy server update path.
    if (graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (isTRUE(graph_state_replay_active())) return()
    d <- dat()
    req(d)
    cols <- graph_usable_column_names(d)
    all_names <- as.character(names(d) %||% rep("", ncol(d)))
    numeric_flags <- vapply(d, is.numeric, logical(1))
    numeric_cols <- unique(all_names[numeric_flags & all_names %in% cols])
    if (!length(numeric_cols)) return()
    if (!graph_mapping_choices_changed("mapping", d)) return()

    defaults <- graph_default_mapping_for_data(d)
    default_id <- defaults$id
    default_y <- defaults$y
    default_x <- defaults$x
    default_series <- defaults$color
    default_color <- defaults$color

    keep <- function(value, choices, fallback, specials = character(0), allow_empty = FALSE) {
      value <- isolate(value)
      if (is.null(value) || !length(value)) return(fallback)
      value <- as.character(value)[1]
      if (value %in% specials) return(value)
      if (allow_empty && identical(value, "")) return("")
      if (nzchar(value) && value %in% choices) return(value)
      fallback
    }

    selected_x <- keep(graph_mapping_value("x", input$xvar), cols, default_x)
    selected_y <- keep(graph_mapping_value("y", input$yvar), numeric_cols, default_y)
    selected_color <- keep(graph_mapping_value("color", input$colorvar %||% ""), cols, default_color, allow_empty = TRUE)
    selected_shape <- keep(graph_mapping_value("shape", input$shapevar %||% "__color__"), cols, "__color__", specials = c("", "__color__"))
    selected_id <- keep(graph_mapping_value("id", input$idvar %||% ""), cols, default_id, allow_empty = TRUE)
    selected_facet <- keep(graph_mapping_value("facet", input$facetvar %||% ""), cols, "", allow_empty = TRUE)

    cfg <- isolate(graph_state_replay_target())
    mp <- cfg$mapping
    if (!is.null(mp)) {
      if (json_chr(mp$x) %in% cols) selected_x <- json_chr(mp$x)
      if (json_chr(mp$y) %in% numeric_cols) selected_y <- json_chr(mp$y)
      saved_color <- json_chr(mp$color)
      if (!nzchar(saved_color) && is.null(mp$position)) saved_color <- json_chr(mp$series)
      if (identical(saved_color, "__fixed__")) saved_color <- ""
      if (saved_color %in% c("", cols)) selected_color <- saved_color
      saved_shape <- json_chr(mp$shape, "__color__")
      if (saved_shape %in% c("", "__color__", cols)) selected_shape <- saved_shape
      if (json_chr(mp$id) %in% c("", cols)) selected_id <- json_chr(mp$id)
      if (json_chr(mp$facet) %in% c("", cols)) selected_facet <- json_chr(mp$facet)
    }

    if (exists("last_valid_xvar", inherits = FALSE)) last_valid_xvar(selected_x)
    if (exists("last_valid_yvar", inherits = FALSE)) last_valid_yvar(selected_y)

    updateSelectInput(session, "xvar", choices = cols, selected = selected_x)
    updateSelectInput(session, "yvar", choices = numeric_cols, selected = selected_y)
    updateSelectInput(session, "colorvar", choices = c("使わない（固定）" = "", cols), selected = selected_color)
    updateSelectInput(session, "shapevar", choices = c("Color と同じ" = "__color__", "なし（固定）" = "", cols), selected = selected_shape)
    updateSelectInput(session, "idvar", choices = c("なし" = "", cols), selected = selected_id)
    updateSelectInput(session, "facetvar", choices = c("なし" = "", cols), selected = selected_facet)
  }, priority = 110)

  # v3.63.0-editor-shell1: linetype/group controls also live permanently in
  # R/editor/ui/graph_ui_module.R. Keep only their choices/selected values in sync.
  observe({
    if (graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (isTRUE(graph_state_replay_active())) return()
    d <- dat()
    req(d)
    cols <- graph_usable_column_names(d)
    if (!length(cols)) return()
    color_now <- resolve_color_var(d)
    if (!graph_mapping_choices_changed("group", list(d, color_now))) return()

    current_linetype <- isolate(graph_mapping_value("linetype", input$linetypevar %||% "__color__"))
    if (is.null(current_linetype) || !length(current_linetype)) current_linetype <- if (nzchar(color_now)) "__color__" else ""
    current_linetype <- as.character(current_linetype)[1]
    if (!current_linetype %in% c("", "__color__", cols)) current_linetype <- if (nzchar(color_now)) "__color__" else ""

    linetype_seed <- isolate(restore_linetype_seed())
    if (!is.null(linetype_seed) && length(linetype_seed)) {
      seeded_linetype <- as.character(linetype_seed)[1]
      if (seeded_linetype %in% c("", "__color__", cols)) current_linetype <- seeded_linetype
    }

    current_group <- isolate(graph_mapping_value("position", input$groupvar %||% ""))
    if (is.null(current_group) || !length(current_group)) current_group <- ""
    current_group <- as.character(current_group)[1]
    if (!current_group %in% c("", cols)) current_group <- ""
    group_seed <- isolate(restore_position_seed())
    if (!is.null(group_seed) && length(group_seed)) {
      seeded_group <- as.character(group_seed)[1]
      if (seeded_group %in% c("", cols)) current_group <- seeded_group
    }

    updateSelectInput(
      session, "linetypevar",
      choices = c("色で分ける要因と同じ" = "__color__", "使わない（固定）" = "", cols),
      selected = current_linetype
    )
    updateSelectInput(
      session, "groupvar",
      choices = c("なし" = "", cols),
      selected = current_group
    )

    current_series_var <- isolate(graph_mapping_value("line_series_var", input$line_series_var %||% ""))
    if (!nzchar(current_series_var) || !current_series_var %in% cols) current_series_var <- ""
    cfg_series <- isolate(graph_state_replay_target())
    saved_series_var <- if (is.list(cfg_series)) json_chr((cfg_series$mapping %||% list())$line_series_var, "") else ""
    if (saved_series_var %in% c("", cols)) current_series_var <- saved_series_var
    updateSelectInput(
      session, "line_series_var",
      choices = c("なし" = "", cols),
      selected = current_series_var
    )
  }, priority = 109)

  # v3.73.2.18: Mapping controls are all permanently mounted in
  # R/editor/ui/graph_ui_module.R. The old mapping_ui / plot_specific_mapping_ui renderUI
  # copies were dead outputs and are intentionally removed.

  # 計算済み値をそのまま描画する value モード用Error bar列。
  # 列名はデータ依存のMappingとして扱い、数値列だけを候補にする。
  observe({
    if (graph_editor_profile_has(editor_profile, "full_shell")) return()
    if (isTRUE(graph_state_replay_active())) return()
    d <- dat()
    cols <- graph_usable_column_names(d)
    all_names <- as.character(names(d) %||% rep("", ncol(d)))
    numeric_flags <- vapply(d, is.numeric, logical(1))
    numeric_cols <- unique(all_names[numeric_flags & all_names %in% cols])
    if (!length(numeric_cols)) return()

    y_now <- graph_mapping_value("y", input$yvar %||% "")
    if (!graph_mapping_choices_changed("external", list(d, y_now))) return()
    other_numeric <- setdiff(numeric_cols, y_now)
    if (!length(other_numeric)) other_numeric <- numeric_cols

    choose_column <- function(current, preferred_names, fallback_pool, restore_seed = NULL) {
      # Project復元中は保存列を最優先する。dynamic selectInputのbrowser
      # commitより先にこのobserverが走ってもdefault候補へ戻さない。
      seed <- if (is.function(restore_seed)) restore_seed() else NULL
      if (!is.null(seed) && length(seed)) {
        sv <- as.character(seed)[1]
        if (nzchar(sv) && sv %in% numeric_cols) return(sv)
      }

      current <- isolate(current)
      if (!is.null(current) && length(current)) {
        cur <- as.character(current)[1]
        if (nzchar(cur) && cur %in% numeric_cols) return(cur)
      }

      low <- tolower(numeric_cols)
      idx <- match(preferred_names, low, nomatch = 0L)
      idx <- idx[idx > 0L]
      if (length(idx)) return(numeric_cols[idx[1]])
      fallback_pool[1]
    }

    sym_selected <- choose_column(
      graph_mapping_value("external_error", input$external_error_col %||% ""),
      c("sem", "se", "stderr", "std_error", "sd", "error", "err"),
      other_numeric,
      restore_external_error_seed
    )
    low_selected <- choose_column(
      graph_mapping_value("external_ymin", input$external_ymin_col %||% ""),
      c("ci_low", "ci_lower", "lower", "low", "lwr", "ymin"),
      other_numeric,
      restore_external_ymin_seed
    )
    high_selected <- choose_column(
      graph_mapping_value("external_ymax", input$external_ymax_col %||% ""),
      c("ci_high", "ci_upper", "upper", "high", "upr", "ymax"),
      other_numeric,
      restore_external_ymax_seed
    )

    updateSelectInput(
      session, "external_error_col",
      choices = numeric_cols,
      selected = sym_selected
    )
    updateSelectInput(
      session, "external_ymin_col",
      choices = numeric_cols,
      selected = low_selected
    )
    updateSelectInput(
      session, "external_ymax_col",
      choices = numeric_cols,
      selected = high_selected
    )
  })

  # canonical replay値が実inputへ反映されたらseedを解放する。
  observe({
    if (isTRUE(graph_state_replay_active())) return()
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()
    numeric_cols <- names(d)[vapply(d, is.numeric, logical(1))]

    release_seed <- function(seed_rv, current) {
      seed <- seed_rv()
      if (is.null(seed) || !length(seed)) return(invisible(NULL))
      sv <- as.character(seed)[1]
      cv <- current %||% ""
      if (nzchar(sv) && sv %in% numeric_cols && identical(as.character(cv)[1], sv)) {
        seed_rv(NULL)
      }
      invisible(NULL)
    }

    release_seed(restore_external_error_seed, graph_mapping_value("external_error", input$external_error_col %||% ""))
    release_seed(restore_external_ymin_seed, graph_mapping_value("external_ymin", input$external_ymin_col %||% ""))
    release_seed(restore_external_ymax_seed, graph_mapping_value("external_ymax", input$external_ymax_col %||% ""))
  })

  observe({
    pt <- graph_plot_value("type", input$plot_type %||% "line")
    if (!pt %in% c("line", "bar", "box")) restore_position_seed(NULL)
    if (!pt %in% c("line", "scatter")) restore_linetype_seed(NULL)
  })

  # v3.73.2.18: groupvar is one persistent Mapping input for line/bar/box.
  # The old line-only position_var_ui remount was removed.

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
      type = "plot_type", summary = "summary_type", summary_unit = "summary_unit",
      external_error_mode = "external_error_mode", show_raw = "show_raw",
      connect_id = "connect_id", scatter_connect_mode = "scatter_connect_mode",
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
    if (!plot_now %in% c("line", "bar", "box")) return("")
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
    if (!graph_plot_value("type", input$plot_type %||% "line") %in% c("line", "scatter")) return("")
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
    style_restore_epoch()
    level_labels()
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
          if (is.null(current) || !length(current) || !nzchar(trimws(as.character(current)[1]))) current <- def
          fluidRow(
            column(5, tags$div(style = "padding-top:7px;", def)),
            column(
              7,
              textInput(
                style_input_id("legend_item_label", spec$key, lv),
                label = NULL,
                value = as.character(current)[1],
                placeholder = def
              )
            )
          )
        })
      )
    })

    tagList(cards)
  })

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    if (isTRUE(restoring_style_state())) return()

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

  output$display_labels_ui <- renderUI({
    style_restore_epoch()

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return(NULL)

    vars <- active_display_label_vars()

    label_state <- isolate(level_labels())

    var_ui <- lapply(vars, function(v) {
      z <- d[[v]]
      if (is.numeric(z) && identical(v, resolved_xvar()) && identical(graph_plot_value("type", input$plot_type %||% "line"), "scatter")) {
        return(NULL)
      }

      observed <- unique(as.character(z))
      observed <- observed[!is.na(observed)]
      if (!length(observed)) return(NULL)

      branch <- label_state[[v]]
      if (is.null(branch)) branch <- list()

      tags$div(
        class = "group-style-box",
        tags$b(paste0(v, " の条件名")),
        lapply(observed, function(lv) {
          val <- branch[[lv]]
          if (is.null(val) || !length(val) || !nzchar(as.character(val)[1])) val <- lv

          fluidRow(
            column(5, tags$div(style = "padding-top:7px;", lv)),
            column(
              7,
              textInput(
                style_input_id("level_label", paste0(v, "::", lv)),
                label = NULL,
                value = as.character(val)[1]
              )
            )
          )
        })
      )
    })

    tagList(
      tags$b("条件名（表示名）"),
      p(class = "help-block", "左が元データの値、右がグラフに表示する名前です。"),
      var_ui
    )
  })

  observe({
    if (isTRUE(graph_state_replay_active())) return()
    if (isTRUE(restoring_style_state())) return()

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()

    vars <- active_display_label_vars()

    ls <- isolate(level_labels())
    changed_label <- FALSE

    for (v in vars) {
      observed <- unique(as.character(d[[v]]))
      observed <- observed[!is.na(observed)]
      if (!length(observed)) next

      branch <- ls[[v]]
      if (is.null(branch)) branch <- list()

      for (lv in observed) {
        id0 <- style_input_id("level_label", paste0(v, "::", lv))
        z <- input[[id0]]
        if (is.null(z)) next
        z <- as.character(z)[1]
        old_raw <- branch[[lv]]
        # Same rule for level labels: the generated input displays the original
        # level by default.  Missing -> original-level is semantically unchanged
        # and must not become a post-READY state mutation/redraw.
        if (is.null(old_raw) && identical(z, as.character(lv)[1])) next
        old <- if (is.null(old_raw)) "" else as.character(old_raw)[1]
        if (!identical(old, z)) {
          branch[[lv]] <- z
          changed_label <- TRUE
        }
      }

      ls[[v]] <- branch
    }

    if (changed_label) level_labels(ls)
  })

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
