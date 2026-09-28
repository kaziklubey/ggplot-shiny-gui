# v4.0.1 — Figure Common Settings runtime.
#
# Responsibilities:
# - choose already-imported Figure GraphStates as Figure-only bulk targets;
# - apply a compact set of frequently used appearance values in one snapshot
#   rebuild per target (rather than one rebuild per property);
# - edit Figure-owned semantic level bindings and explicitly materialize the
#   current Shared Style Library into those frozen Figure GraphStates.
#
# This runtime never seeds FigureState from GraphState and never writes GraphState.

  figure_common_available_ids <- reactive({
    figure_layout_state()
    states <- figure_edit_states()
    meta <- graph_meta()
    graph_ids <- as.character(meta$id %||% character(0))
    main_ids <- tryCatch(figure_main_panel_source_ids(), error = function(e) character(0))
    ids <- intersect(main_ids, graph_ids)
    ids[ids %in% (names(states) %||% character(0))]
  })

  figure_common_selected_ids <- reactive({
    available <- figure_common_available_ids()
    raw <- input$figure_common_target_ids
    if (is.null(raw)) return(available)
    requested <- as.character(raw %||% character(0))
    intersect(requested[nzchar(requested)], available)
  })

  figure_common_target_labels <- function(ids = figure_common_available_ids()) {
    meta <- graph_meta()
    stats::setNames(
      ids,
      vapply(ids, function(id) {
        hit <- which(as.character(meta$id) == id)
        nm <- if (length(hit)) as.character(meta$name[hit[[1]]]) else id
        nm
      }, character(1))
    )
  }

  output$figure_common_target_selector <- renderUI({
    ids <- figure_common_available_ids()
    if (!length(ids)) {
      return(tags$div(
        class = "figure-common-empty",
        "Figureへ読み込み済みのGraphがありません。Graph Sourcesから先に読み込んでください。"
      ))
    }
    labels <- figure_common_target_labels(ids)
    raw_current <- isolate(input$figure_common_target_ids)
    current <- if (is.null(raw_current)) ids else intersect(as.character(raw_current %||% character(0)), ids)
    tagList(
      div(
        class = "figure-common-target-toolbar",
        actionButton("figure_common_targets_all", "すべて選択", class = "btn-xs btn-default"),
        actionButton("figure_common_targets_none", "すべて解除", class = "btn-xs btn-default"),
        tags$span(
          class = "text-muted figure-common-target-count",
          paste0(length(current), " / ", length(ids), " Graph")
        )
      ),
      checkboxGroupInput(
        "figure_common_target_ids", NULL,
        choices = labels, selected = current, inline = TRUE
      )
    )
  })

  observeEvent(input$figure_common_targets_all, {
    ids <- isolate(figure_common_available_ids())
    updateCheckboxGroupInput(session, "figure_common_target_ids", selected = ids)
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_targets_none, {
    updateCheckboxGroupInput(session, "figure_common_target_ids", selected = character(0))
  }, ignoreInit = TRUE)

  output$figure_common_modal_target_summary <- renderUI({
    ids <- figure_common_selected_ids()
    if (!length(ids)) return(tags$span(class = "text-muted", "対象なし"))
    labels <- figure_common_target_labels(ids)
    div(
      class = "figure-common-modal-target-chips",
      lapply(seq_along(ids), function(i) tags$span(class = "figure-common-target-chip", names(labels)[[i]]))
    )
  })

  observeEvent(input$figure_common_open_semantic, {
    showModal(figureSemanticWorkspaceModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_open_library, {
    showModal(figureSharedStyleLibraryModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_library_new, {
    showModal(figureSharedStyleNewModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_library_new_cancel, {
    showModal(figureSharedStyleLibraryModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_semantic_open_library, {
    showModal(figureSharedStyleLibraryModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_library_back_semantic, {
    showModal(figureSemanticWorkspaceModalUI())
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_open_advanced, {
    showModal(figureAdvancedSettingsModalUI())
  }, ignoreInit = TRUE)


  figure_common_quick_specs <- function() {
    list(
      theme = list(label = "テーマ", path = "style.appearance.theme", kind = "select"),
      font_family_mode = list(label = "フォント", path = "style.appearance.font_family_mode", kind = "font"),
      base_size = list(label = "基本文字サイズ", path = "style.appearance.base_size", kind = "number"),
      legend_text_size = list(label = "凡例文字サイズ", path = "style.appearance.legend_text_size", kind = "number"),
      point_size = list(label = "Pointサイズ", path = "style.appearance.point_size", kind = "number"),
      line_width = list(label = "Line幅", path = "style.appearance.line_width", kind = "number"),
      bar_width = list(label = "Bar幅", path = "style.appearance.bar_width", kind = "number"),
      plot_width_px = list(label = "幅 (px)", path = "style.appearance.plot_width_px", kind = "number"),
      plot_height_px = list(label = "高さ (px)", path = "style.appearance.plot_height_px", kind = "number")
    )
  }

  figure_common_value_summary <- function(states, ids, path) {
    vals <- lapply(ids, function(id) graph_settings_manager_get(states[[id]], path, NULL))
    if (!length(vals)) return(list(equal = FALSE, value = NULL, display = "—"))
    keys <- vapply(vals, function(value) {
      tryCatch(
        as.character(jsonlite::toJSON(app_json_safe_tree(value), auto_unbox = TRUE, null = "null", na = "string", digits = NA)),
        error = function(e) paste0(typeof(value), ":", paste(as.character(value %||% ""), collapse = "|"))
      )
    }, character(1))
    equal <- length(unique(keys)) == 1L
    value <- if (equal) vals[[1]] else NULL
    list(
      equal = equal,
      value = value,
      display = if (equal) graph_settings_manager_scalar(value) else "Mixed"
    )
  }

  output$figure_common_quick_controls <- renderUI({
    states <- figure_edit_states()
    ids <- figure_common_selected_ids()
    if (!length(ids)) return(tags$div(class = "figure-common-empty", "対象Graphを選択してください。"))
    specs <- figure_common_quick_specs()
    summaries <- lapply(specs, function(spec) figure_common_value_summary(states, ids, spec$path))

    quick_numeric <- function(key, spec) {
      sm <- summaries[[key]]
      value <- if (isTRUE(sm$equal) && !is.null(sm$value) && length(sm$value)) {
        format(as.numeric(sm$value[[1]]), trim = TRUE, scientific = FALSE)
      } else ""
      div(
        class = "figure-common-field",
        textInput(
          paste0("figure_common_quick_", key),
          spec$label,
          value = value,
          placeholder = if (isTRUE(sm$equal)) "" else "Mixed"
        )
      )
    }

    theme_sm <- summaries$theme
    theme_value <- if (isTRUE(theme_sm$equal)) as.character(theme_sm$value %||% "")[1] else ""
    font_sm <- summaries$font_family_mode
    font_value <- if (isTRUE(font_sm$equal)) as.character(font_sm$value %||% "")[1] else ""
    font_custom_sm <- figure_common_value_summary(states, ids, "style.appearance.font_family_custom")
    font_custom_value <- if (isTRUE(font_custom_sm$equal)) as.character(font_custom_sm$value %||% "")[1] else ""

    tagList(
      div(
        class = "figure-common-quick-card-grid",
        div(
          class = "figure-common-quick-card",
          div(class = "figure-common-quick-card-title", "文字"),
          div(
            class = "figure-common-quick-grid",
            div(
              class = "figure-common-field",
              selectInput(
                "figure_common_quick_theme", "テーマ",
                choices = c("— 変更しない —" = "", "classic" = "classic", "bw" = "bw", "minimal" = "minimal", "gray" = "gray"),
                selected = if (theme_value %in% c("classic", "bw", "minimal", "gray")) theme_value else ""
              )
            ),
            div(
              class = "figure-common-field",
              selectizeInput(
                "figure_common_quick_font_family_mode", "フォント",
                choices = c("— 変更しない / Mixed —" = "", app_font_choices(if (nzchar(font_value)) font_value else "sans")),
                selected = font_value,
                options = list(placeholder = "Mixed / 変更しない")
              )
            ),
            quick_numeric("base_size", specs$base_size),
            quick_numeric("legend_text_size", specs$legend_text_size)
          )
        ),
        div(
          class = "figure-common-quick-card",
          div(class = "figure-common-quick-card-title", "線・点・バー"),
          div(
            class = "figure-common-quick-grid",
            quick_numeric("point_size", specs$point_size),
            quick_numeric("line_width", specs$line_width),
            quick_numeric("bar_width", specs$bar_width)
          )
        ),
        div(
          class = "figure-common-quick-card",
          div(class = "figure-common-quick-card-title", "Graphサイズ"),
          div(
            class = "figure-common-quick-grid",
            quick_numeric("plot_width_px", specs$plot_width_px),
            quick_numeric("plot_height_px", specs$plot_height_px)
          )
        )
      ),
      conditionalPanel(
        condition = "input.figure_common_quick_font_family_mode == 'custom'",
        div(
          class = "figure-common-custom-font",
          textInput(
            "figure_common_quick_font_family_custom", "フォント名",
            value = font_custom_value,
            placeholder = if (isTRUE(font_custom_sm$equal)) "例: Calibri, Helvetica, Noto Sans JP" else "Mixed"
          )
        )
      )
    )
  })


  figure_common_collect_quick_patch <- function() {
    specs <- figure_common_quick_specs()
    ids <- isolate(figure_common_selected_ids())
    states <- isolate(figure_edit_states())
    values <- list(
      theme = input$figure_common_quick_theme,
      font_family_mode = input$figure_common_quick_font_family_mode,
      base_size = input$figure_common_quick_base_size,
      legend_text_size = input$figure_common_quick_legend_text_size,
      point_size = input$figure_common_quick_point_size,
      line_width = input$figure_common_quick_line_width,
      bar_width = input$figure_common_quick_bar_width,
      plot_width_px = input$figure_common_quick_plot_width_px,
      plot_height_px = input$figure_common_quick_plot_height_px
    )
    patch <- list()
    errors <- character(0)
    already_equal <- function(path, value) {
      value_equal <- function(current, requested) {
        if (is.numeric(current) && length(current) && is.numeric(requested) && length(requested)) {
          a <- suppressWarnings(as.numeric(current[[1]]))
          b <- suppressWarnings(as.numeric(requested[[1]]))
          return(is.finite(a) && is.finite(b) && identical(a, b))
        }
        identical(current, requested)
      }
      length(ids) > 0L && all(vapply(ids, function(id) {
        st <- states[[id]]
        is.list(st) && value_equal(graph_settings_manager_get(st, path, NULL), value)
      }, logical(1)))
    }

    for (key in names(values)) {
      raw <- values[[key]]
      if (is.null(raw) || !nzchar(trimws(as.character(raw)[1]))) next
      spec <- specs[[key]]
      rec <- graph_settings_manager_row_for_path(spec$path)
      normalized <- graph_settings_manager_normalize_input_value(rec, raw)
      if (!isTRUE(normalized$ok)) {
        errors <- c(errors, paste0(spec$label, ": ", normalized$message %||% "値が不正です。"))
      } else if (!already_equal(spec$path, normalized$value)) {
        patch[[spec$path]] <- normalized$value
      }
    }

    font_mode <- as.character(values$font_family_mode %||% "")[1]
    custom <- trimws(as.character(input$figure_common_quick_font_family_custom %||% "")[1])
    mode_changes_to_custom <- identical(font_mode, "custom") &&
      !already_equal("style.appearance.font_family_mode", "custom")
    if (mode_changes_to_custom && !nzchar(custom)) {
      errors <- c(errors, "フォント名を入力してください。")
    }
    if (nzchar(custom) && !already_equal("style.appearance.font_family_custom", custom)) {
      patch[["style.appearance.font_family_custom"]] <- custom
    }
    list(patch = patch, errors = errors)
  }

  figure_common_commit_states <- function(states, ids, reason) {
    ids <- unique(as.character(ids %||% character(0)))
    ids <- ids[nzchar(ids)]
    changed <- character(0)
    queued <- character(0)
    for (id in ids) {
      new <- states[[id]]
      if (!is.list(new)) next
      old <- isolate(figure_edit_states())[[id]]
      if (identical(old, new)) next
      store_figure_edit_state(id, new, reason = reason)
      changed <- c(changed, id)
      if (exists("cancel_figure_source_snapshot_jobs", mode = "function", inherits = TRUE)) {
        cancel_figure_source_snapshot_jobs(id, reason = paste0(reason, "-replace"))
      }
      rev <- request_figure_source_snapshot(
        id,
        reason = reason,
        import_editor_state = FALSE,
        state_override = new,
        target_type = "main"
      )
      rev_num <- suppressWarnings(as.integer(rev %||% NA_integer_)[1])
      if (!identical(rev, FALSE) && is.finite(rev_num) && rev_num > 0L) queued <- c(queued, id)
    }
    changed <- unique(changed)
    queued <- unique(queued)
    if (length(queued)) graph_settings_manager_reload_visible_figure_editor(queued, reason)
    list(changed = changed, queued = queued)
  }

  observeEvent(input$figure_common_quick_apply, {
    ids <- isolate(figure_common_selected_ids())
    if (!length(ids)) {
      showNotification("対象Graphを選択してください。", type = "warning")
      return()
    }
    collected <- figure_common_collect_quick_patch()
    if (length(collected$errors)) {
      showNotification(paste(collected$errors, collapse = " / "), type = "warning", duration = 6)
      return()
    }
    if (!length(collected$patch)) {
      showNotification("変更する項目を入力してください。", type = "message", duration = 2)
      return()
    }

    states <- isolate(figure_edit_states())
    for (id in ids) {
      st <- states[[id]]
      if (!is.list(st)) next
      for (path in names(collected$patch)) {
        st <- graph_settings_manager_set_path(st, path, collected$patch[[path]])
      }
      states[[id]] <- st
    }
    result <- figure_common_commit_states(states, ids, "figure-common-quick")
    diag_log(
      "FIGURE-COMMON-QUICK",
      paste0(
        "targets={", paste(ids, collapse = ","), "}",
        " paths={", paste(names(collected$patch), collapse = ","), "}",
        " changed={", paste(result$changed, collapse = ","), "}",
        " graph_state_unchanged=TRUE"
      )
    )
    showNotification(
      paste0("見た目をFigure ", length(result$changed), " Graphへ適用しました（元Graphは変更していません）。"),
      type = "message", duration = 4
    )
  }, ignoreInit = TRUE)

  figure_common_semantic_variables <- function(state) {
    if (!is.list(state)) return(list(data = NULL, vars = character(0)))
    d <- tryCatch(graph_snapshot_data(state), error = function(e) NULL)
    if (!is.data.frame(d) || !ncol(d)) return(list(data = d, vars = character(0)))
    mp <- state$mapping %||% list()
    actual <- function(x) {
      z <- as.character(x %||% "")[1]
      if (!nzchar(z) || startsWith(z, "__") || !z %in% names(d)) "" else z
    }
    color <- actual(mp$color)
    linetype <- as.character(mp$linetype %||% "")[1]
    if (identical(linetype, "__color__")) linetype <- color else linetype <- actual(linetype)
    shape <- as.character(mp$shape %||% "")[1]
    if (identical(shape, "__color__")) shape <- color else shape <- actual(shape)
    # Common Semantic Styles focuses on grouping/condition roles rather than
    # every X-axis category. Existing X-level bindings are still retained below
    # through bound_vars so imported projects do not lose them.
    vars <- c(actual(mp$position), color, linetype, shape, actual(mp$facet))
    vars <- unique(vars[nzchar(vars)])
    binding <- shared_style_normalize_binding(state$style$shared_library %||% NULL)
    bound_vars <- intersect(names(binding$levels) %||% character(0), names(d))
    list(data = d, vars = unique(c(vars, bound_vars)))
  }

  figure_common_semantic_records <- reactive({
    ids <- figure_common_selected_ids()
    states <- figure_edit_states()
    meta <- graph_meta()
    out <- list()
    idx <- 0L
    for (id in ids) {
      st <- states[[id]]
      if (!is.list(st)) next
      hit <- which(as.character(meta$id) == id)
      graph_name <- if (length(hit)) as.character(meta$name[hit[[1]]]) else id
      info <- figure_common_semantic_variables(st)
      d <- info$data
      binding <- shared_style_normalize_binding(st$style$shared_library %||% NULL)
      if (!is.data.frame(d)) next
      for (vn in info$vars) {
        values <- unique(as.character(d[[vn]]))
        values <- values[!is.na(values)]
        for (lv in values) {
          idx <- idx + 1L
          out[[idx]] <- list(
            index = idx,
            graph_id = id,
            graph_name = graph_name,
            variable = vn,
            level = lv,
            current = as.character(binding$levels[[vn]][[lv]] %||% "")[1]
          )
        }
      }
    }
    out
  })

  figure_common_group_input_id <- function(item_id, graph_id) {
    paste0(
      "figure_common_group_bind_",
      shared_style_safe_id(item_id), "__", shared_style_safe_id(graph_id)
    )
  }

  figure_common_shape_mark <- function(shape) {
    switch(
      as.character(shape %||% "16")[1],
      `16` = "●", `17` = "▲", `15` = "■", `18` = "◆",
      `3` = "+", `4` = "×", `1` = "○", `2` = "△", `0` = "□", `5` = "◇",
      "●"
    )
  }

  figure_common_line_mark <- function(linetype) {
    switch(
      as.character(linetype %||% "solid")[1],
      solid = "━", dashed = "┅", dotted = "┈", dotdash = "┅·", longdash = "━━", twodash = "┅┅",
      "━"
    )
  }

  output$figure_common_semantic_bindings <- renderUI({
    records <- figure_common_semantic_records()
    lib <- shared_style_normalize_library(shared_style_library())
    items <- shared_style_library_items(lib, "level")
    ids <- figure_common_selected_ids()
    meta <- graph_meta()

    if (!length(records)) {
      return(tags$div(class = "figure-common-empty", "選択したGraphに、まとめて揃えられる群・条件がありません。"))
    }

    if (!length(items)) {
      return(tagList(
        tags$div(class = "alert alert-warning", "まだ共通グループがありません。まず Expert / Normal / Control など、揃えたい名前を作成してください。"),
        actionButton("figure_common_semantic_open_library", "共通グループを作る…", class = "btn-sm btn-primary")
      ))
    }

    graph_labels <- stats::setNames(
      vapply(ids, function(id) {
        hit <- which(as.character(meta$id) == id)
        if (length(hit)) as.character(meta$name[hit[[1]]]) else id
      }, character(1)),
      ids
    )

    unassigned_records <- Filter(function(rec) !nzchar(as.character(rec$current %||% "")[1]), records)
    assigned_n <- length(records) - length(unassigned_records)

    row_for_item <- function(item_id) {
      item <- items[[item_id]]
      tags$tr(
        tags$th(
          class = "figure-common-semantic-group-cell",
          div(
            class = "figure-common-semantic-group-title",
            tags$span(
              class = "figure-common-semantic-group-swatch",
              style = paste0("background:", as.character(item$color %||% "#808080")[1], ";")
            ),
            tags$strong(as.character(item$display %||% item_id)[1])
          ),
          tags$span(
            class = "figure-common-semantic-group-style",
            paste(figure_common_shape_mark(item$shape), figure_common_line_mark(item$linetype))
          )
        ),
        lapply(ids, function(id) {
          graph_records <- Filter(function(rec) identical(rec$graph_id, id), records)
          if (!length(graph_records)) return(tags$td(class = "figure-common-semantic-empty-cell", "—"))
          choices <- stats::setNames(
            vapply(graph_records, function(rec) as.character(rec$index), character(1)),
            vapply(graph_records, function(rec) paste0(rec$variable, " / ", rec$level), character(1))
          )
          selected <- vapply(
            Filter(function(rec) identical(as.character(rec$current %||% "")[1], item_id), graph_records),
            function(rec) as.character(rec$index), character(1)
          )
          tags$td(
            selectizeInput(
              figure_common_group_input_id(item_id, id),
              label = NULL,
              choices = choices,
              selected = selected,
              multiple = TRUE,
              width = "100%",
              options = list(
                plugins = list("remove_button"),
                placeholder = "このGraphの対応項目を選択"
              )
            )
          )
        })
      )
    }

    unassigned_ui <- if (!length(unassigned_records)) {
      div(class = "figure-common-unassigned-allset", "✓ すべての群・条件に対応先があります。")
    } else {
      by_graph <- split(unassigned_records, vapply(unassigned_records, `[[`, character(1), "graph_id"))
      div(
        class = "figure-common-unassigned-panel",
        div(class = "figure-common-unassigned-title", tags$strong("まだ揃えていない項目"), tags$span("必要なものだけ上の共通グループへ割り当てます。")),
        lapply(ids, function(id) {
          recs <- by_graph[[id]] %||% list()
          if (!length(recs)) return(NULL)
          div(
            class = "figure-common-unassigned-row",
            tags$strong(graph_labels[[id]]),
            div(
              class = "figure-common-unassigned-chips",
              lapply(recs, function(rec) tags$span(class = "figure-common-unassigned-chip", paste0(rec$variable, " / ", rec$level)))
            )
          )
        })
      )
    }

    tagList(
      div(
        class = "figure-common-semantic-status",
        tags$span(paste0(length(ids), " Graph")),
        tags$span(paste0(length(items), " 共通グループ")),
        tags$span(class = if (length(unassigned_records)) "is-warning" else "is-ok", paste0("対応済み ", assigned_n, " / ", length(records)))
      ),
      tags$p(
        class = "help-block figure-common-semantic-guide",
        "行が共通グループ、列がGraphです。各Graphで同じ意味として扱う項目を選んでください。1つの項目は1つの共通グループにだけ割り当てられます。"
      ),
      div(
        class = "figure-common-semantic-matrix-scroll",
        tags$table(
          class = "table table-condensed figure-common-semantic-matrix figure-common-semantic-group-matrix",
          tags$thead(tags$tr(
            tags$th(class = "figure-common-semantic-source-head", "共通グループ"),
            lapply(ids, function(id) tags$th(graph_labels[[id]]))
          )),
          tags$tbody(lapply(names(items), row_for_item))
        )
      ),
      unassigned_ui
    )
  })

  figure_common_binding_from_inputs <- function(state, records_for_graph, auto_match = FALSE, library = NULL, graph_id = NULL) {
    b <- shared_style_normalize_binding(state$style$shared_library %||% NULL)
    lib <- shared_style_normalize_library(library %||% shared_style_library())
    items <- shared_style_library_items(lib, "level")
    normalized_display <- if (length(items)) {
      stats::setNames(tolower(trimws(vapply(items, function(item) as.character(item$display %||% "")[1], character(1)))), names(items))
    } else character(0)

    if (isTRUE(auto_match)) {
      for (rec in records_for_graph) {
        val <- shared_style_safe_id(rec$current %||% "")
        if (!nzchar(val) && length(items)) {
          level_key <- tolower(trimws(as.character(rec$level %||% "")[1]))
          id_key <- shared_style_safe_id(rec$level %||% "")
          hits <- names(items)[normalized_display == level_key | names(items) == id_key]
          hits <- unique(hits)
          if (length(hits) == 1L) val <- hits[[1]]
        }
        br <- b$levels[[rec$variable]] %||% list()
        if (nzchar(val)) br[[rec$level]] <- val else br[[rec$level]] <- NULL
        if (length(br)) b$levels[[rec$variable]] <- br else b$levels[[rec$variable]] <- NULL
      }
      b$enabled <- shared_style_binding_has_links(b)
      return(list(ok = TRUE, binding = shared_style_prune_binding_to_library(b, lib), error = NULL))
    }

    gid <- as.character(graph_id %||% if (length(records_for_graph)) records_for_graph[[1]]$graph_id else "")[1]
    selected_for_record <- list()
    conflicts <- character(0)
    valid_indices <- stats::setNames(rep(TRUE, length(records_for_graph)), vapply(records_for_graph, function(rec) as.character(rec$index), character(1)))

    for (item_id in names(items)) {
      raw <- as.character(input[[figure_common_group_input_id(item_id, gid)]] %||% character(0))
      raw <- unique(raw[raw %in% names(valid_indices)])
      for (idx in raw) {
        previous <- selected_for_record[[idx]] %||% ""
        if (nzchar(previous) && !identical(previous, item_id)) {
          rec <- records_for_graph[[which(vapply(records_for_graph, function(x) identical(as.character(x$index), idx), logical(1)))[1]]]
          conflicts <- c(conflicts, paste0(rec$variable, " / ", rec$level))
        } else {
          selected_for_record[[idx]] <- item_id
        }
      }
    }

    if (length(conflicts)) {
      return(list(
        ok = FALSE,
        binding = b,
        error = paste0("同じ項目が複数の共通グループに入っています: ", paste(unique(conflicts), collapse = ", "))
      ))
    }

    for (rec in records_for_graph) {
      val <- shared_style_safe_id(selected_for_record[[as.character(rec$index)]] %||% "")
      br <- b$levels[[rec$variable]] %||% list()
      if (nzchar(val)) br[[rec$level]] <- val else br[[rec$level]] <- NULL
      if (length(br)) b$levels[[rec$variable]] <- br else b$levels[[rec$variable]] <- NULL
    }
    b$enabled <- shared_style_binding_has_links(b)
    list(ok = TRUE, binding = shared_style_prune_binding_to_library(b, lib), error = NULL)
  }

  figure_common_apply_semantic_bindings <- function(auto_match = FALSE, reason = "figure-common-semantic") {
    ids <- isolate(figure_common_selected_ids())
    records <- isolate(figure_common_semantic_records())
    if (!length(ids)) return(list(changed = character(0), queued = character(0), matched = 0L))
    lib <- shared_style_normalize_library(isolate(shared_style_library()))
    states <- isolate(figure_edit_states())
    matched <- 0L

    for (id in ids) {
      st <- states[[id]]
      if (!is.list(st)) next
      recs <- Filter(function(rec) identical(rec$graph_id, id), records)
      old_binding <- shared_style_normalize_binding(st$style$shared_library %||% NULL)
      built <- figure_common_binding_from_inputs(st, recs, auto_match = auto_match, library = lib, graph_id = id)
      if (!isTRUE(built$ok)) {
        return(list(changed = character(0), queued = character(0), matched = 0L, error = built$error %||% "対応を確認してください。"))
      }
      new_binding <- built$binding
      if (isTRUE(auto_match)) {
        old_links <- sum(vapply(old_binding$levels, length, integer(1)))
        new_links <- sum(vapply(new_binding$levels, length, integer(1)))
        matched <- matched + max(0L, new_links - old_links)
      }
      if (!is.list(st$style)) st$style <- list()
      st$style$shared_library <- new_binding
      st <- shared_style_prune_graph_state(st, lib)
      st <- shared_style_apply_to_graph_state(st, lib)
      states[[id]] <- st
    }

    result <- figure_common_commit_states(states, ids, reason)
    result$matched <- matched
    result$error <- NULL
    diag_log(
      "FIGURE-COMMON-SEMANTIC",
      paste0(
        "targets={", paste(ids, collapse = ","), "}",
        " auto_match=", isTRUE(auto_match),
        " matched=", matched,
        " changed={", paste(result$changed, collapse = ","), "}",
        " graph_state_unchanged=TRUE"
      )
    )
    result
  }

  observeEvent(input$figure_common_semantic_apply, {
    if (!length(isolate(figure_common_selected_ids()))) {
      showNotification("対象Graphを選択してください。", type = "warning")
      return()
    }
    result <- figure_common_apply_semantic_bindings(FALSE, "figure-common-semantic-apply")
    if (nzchar(as.character(result$error %||% "")[1])) {
      showNotification(result$error, type = "warning", duration = 6)
    } else if (length(result$changed)) {
      showNotification(paste0("群・条件の対応と見た目をFigure ", length(result$changed), " Graphへ適用しました。"), type = "message", duration = 4)
    } else {
      showNotification("Figure側に変更はありませんでした。", type = "message", duration = 2)
    }
  }, ignoreInit = TRUE)

  observeEvent(input$figure_common_semantic_auto_match, {
    if (!length(isolate(figure_common_selected_ids()))) {
      showNotification("対象Graphを選択してください。", type = "warning")
      return()
    }
    result <- figure_common_apply_semantic_bindings(TRUE, "figure-common-semantic-auto-match")
    if (result$matched > 0L) {
      showNotification(paste0("同じ名前の項目を ", result$matched, " 件対応付けてFigureへ適用しました。"), type = "message", duration = 4)
    } else {
      showNotification("新しく自動で揃えられる同名項目はありませんでした。", type = "message", duration = 3)
    }
  }, ignoreInit = TRUE)
