# v3.73.2.29 — Graph/Figure Settings Manager companion data.
# Canonical GraphState remains server-owned. The in-page and external managers
# compare Graph and Figure-owned values, expose Shared Library binding status,
# and navigate to the one persistent Graph Editor. Writes remain in focused
# settings runtimes sourced after this file.

  graph_settings_manager_get_result <- function(x, path) {
    cur <- x
    parts <- strsplit(as.character(path %||% "")[1], ".", fixed = TRUE)[[1]]
    if (!length(parts) || any(!nzchar(parts))) return(list(found = FALSE, value = NULL))
    for (key in parts) {
      if (!is.list(cur) || !key %in% (names(cur) %||% character(0))) {
        return(list(found = FALSE, value = NULL))
      }
      cur <- cur[[key]]
    }
    list(found = TRUE, value = cur)
  }

  graph_settings_manager_get <- function(x, path, default = NULL) {
    got <- graph_settings_manager_get_result(x, path)
    if (isTRUE(got$found)) got$value else default
  }

  graph_settings_manager_scalar <- function(x) {
    if (is.null(x) || !length(x)) return("—")
    if (is.logical(x)) return(if (isTRUE(x[[1]])) "ON" else "OFF")
    if (is.numeric(x)) {
      z <- suppressWarnings(as.numeric(x[[1]]))
      if (!is.finite(z)) return("—")
      return(format(z, trim = TRUE, scientific = FALSE))
    }
    z <- as.character(x[[1]] %||% "")
    z <- gsub("\\r?\\n", " / ", z)
    z <- trimws(z)
    if (nzchar(z)) z else "—"
  }

  graph_settings_manager_rows <- function() {
    editor_text <- function(allow_empty = TRUE) list(kind = "text", allowEmpty = isTRUE(allow_empty))
    editor_number <- function(min = NULL, max = NULL, step = NULL) {
      out <- list(kind = "number")
      if (!is.null(min)) out$min <- min
      if (!is.null(max)) out$max <- max
      if (!is.null(step)) out$step <- step
      out
    }
    editor_axis_number <- function() list(kind = "axis_number", allowEmpty = TRUE)
    editor_boolean <- function() list(kind = "boolean")
    editor_select <- function(values, labels = values) {
      list(
        kind = "select",
        choices = unname(Map(function(value, label) list(value = value, label = label), values, labels))
      )
    }

    list(
      list(group="基本", label="Plot type", path="plot.type", section="mapping", input="plot_type", apply=FALSE),
      list(group="Mapping", label="X", path="mapping.x", section="mapping", input="xvar", apply=FALSE),
      list(group="Mapping", label="Y", path="mapping.y", section="mapping", input="yvar", apply=FALSE),
      list(group="Mapping", label="Color", path="mapping.color", section="mapping", input="colorvar", apply=FALSE),
      list(group="Mapping", label="Facet", path="mapping.facet", section="mapping", input="facetvar", apply=FALSE),
      list(group="タイトル", label="Graph title", path="labels.title", section="axes-legend", input="title", apply=TRUE, editor=editor_text()),
      list(group="X軸", label="X軸タイトル", path="labels.xlab", section="axes-legend", input="xlab", apply=TRUE, shared_axis="x", editor=editor_text()),
      list(group="X軸", label="X軸のカテゴリ名を表示", path="style.appearance.x_tick_labels_show", section="axes-legend", input="x_tick_labels_show", apply=TRUE, editor=editor_boolean()),
      list(group="X軸", label="カテゴリ間隔", path="style.appearance.x_category_spacing", section="appearance", input="x_category_spacing", apply=TRUE, editor=editor_number(0, 2.5, 0.05)),
      list(group="X軸", label="Line X目盛間隔", path="style.appearance.line_x_spacing", section="axes-legend", input="line_x_spacing", apply=TRUE, editor=editor_number(0, 1, 0.05)),
      list(group="Y軸", label="Y軸タイトル", path="labels.ylab", section="axes-legend", input="ylab", apply=TRUE, shared_axis="y", editor=editor_text()),
      list(group="Y軸", label="Y最小", path="labels.ymin", section="axes-legend", input="ymin", apply=TRUE, editor=editor_axis_number()),
      list(group="Y軸", label="Y最大", path="labels.ymax", section="axes-legend", input="ymax", apply=TRUE, editor=editor_axis_number()),
      list(group="Y軸", label="上端を最終目盛りに合わせる", path="labels.y_top_to_tick", section="axes-legend", input="y_top_to_tick", apply=TRUE, editor=editor_boolean()),
      list(group="Y軸", label="目盛間隔 自動", path="style.appearance.y_breaks_auto", section="axes-legend", input="y_breaks_auto", apply=TRUE, editor=editor_boolean()),
      list(group="Y軸", label="目盛間隔", path="style.appearance.y_breaks_step", section="axes-legend", input="y_breaks_step", apply=TRUE, editor=editor_number(0.000001, NULL, 0.1)),
      list(group="Y軸", label="途中省略", path="style.appearance.y_break_enabled", section="axes-legend", input="y_break_enabled", apply=TRUE, editor=editor_boolean()),
      list(group="サイズ", label="Plot横幅", path="style.appearance.plot_width_px", section="axes-legend", input="plot_width_px_direct", suffix=" px", apply=TRUE, editor=editor_number(250, 2000, 10)),
      list(group="サイズ", label="Plot縦幅", path="style.appearance.plot_height_px", section="axes-legend", input="plot_height_px_direct", suffix=" px", apply=TRUE, editor=editor_number(180, 1400, 10)),
      list(group="凡例", label="凡例位置", path="style.appearance.legend_pos", section="legend", input="legend_pos", apply=TRUE,
           editor=editor_select(c("right","left","top","bottom","none"), c("右","左","上","下","非表示"))),
      list(group="凡例", label="色 / 塗り凡例を表示", path="style.appearance.legend_colour_show", section="legend", input="legend_colour_show", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="線種凡例を表示", path="style.appearance.legend_linetype_show", section="legend", input="legend_linetype_show", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="点形状凡例を表示", path="style.appearance.legend_shape_show", section="legend", input="legend_shape_show", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="同じ変数の線種と点形状を統合", path="style.appearance.legend_merge_linetype_shape", section="legend", input="legend_merge_linetype_shape", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="色 / 塗り凡例タイトルを表示", path="style.appearance.legend_title_show", section="legend", input="legend_title_show", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="色 / 塗り凡例タイトル", path="style.appearance.legend_group_title", section="legend", input="legend_group_title", apply=TRUE, editor=editor_text()),
      list(group="凡例", label="線種 / 点形状凡例タイトルを表示", path="style.appearance.legend_individual_title_show", section="legend", input="legend_individual_title_show", apply=TRUE, editor=editor_boolean()),
      list(group="凡例", label="線種 / 点形状凡例タイトル", path="style.appearance.legend_individual_title", section="legend", input="legend_individual_title", apply=TRUE, editor=editor_text()),
      list(group="凡例", label="凡例サンプル長", path="style.appearance.legend_key_width", section="legend", input="legend_key_width", apply=TRUE, editor=editor_number(0, 4, 0.1)),
      list(group="書式", label="Theme", path="style.appearance.theme", section="appearance", input="theme", apply=TRUE,
           editor=editor_select(c("classic","bw","minimal","gray"), c("classic","bw","minimal","gray"))),
      list(group="書式", label="Font", path="style.appearance.font_family_mode", section="appearance", input="font_family_mode", apply=TRUE, editor=editor_text(FALSE)),
      list(group="書式", label="基本フォントサイズ", path="style.appearance.base_size", section="appearance", input="base_size", apply=TRUE, editor=editor_number(8, 24, 1)),
      # Palette selection alone does not apply colours in the Graph UI; the
      # separate "Colorへパレットを適用" action materializes color_styles.
      # Keep this row comparison/navigation-only rather than implying a direct
      # value write would recolour the plot.
      list(group="書式", label="Palette", path="style.appearance.palette_preset", section="appearance", input="palette_preset", apply=FALSE),
      list(group="書式", label="Point size", path="style.appearance.point_size", section="appearance", input="point_size", apply=TRUE, editor=editor_number(0, 8, 0.1)),
      list(group="書式", label="Line width", path="style.appearance.line_width", section="appearance", input="line_width", apply=TRUE, editor=editor_number(0, 3, 0.1)),
      list(group="書式", label="Bar width", path="style.appearance.bar_width", section="appearance", input="bar_width", apply=TRUE, editor=editor_number(0, 1, 0.02)),
      list(group="Error bar", label="Error bar幅", path="style.appearance.error_width", section="error-bars", input="error_width", apply=TRUE, editor=editor_number(0, 0.8, 0.05)),
      list(group="Error bar", label="Error bar線幅", path="style.appearance.error_line_width", section="error-bars", input="error_line_width", apply=TRUE, editor=editor_number(0, 2, 0.05))
    )
  }

  graph_settings_manager_row_for_path <- function(path) {
    path <- as.character(path %||% "")[1]
    rows <- graph_settings_manager_rows()
    hit <- which(vapply(rows, function(rec) identical(as.character(rec$path %||% ""), path), logical(1)))
    if (length(hit)) rows[[hit[[1]]]] else NULL
  }

  graph_settings_manager_jump_js <- function(id, section, input_id) {
    paste0(
      "return window.ggplotGuiJumpToGraphSetting && window.ggplotGuiJumpToGraphSetting(",
      jsonlite::toJSON(as.character(id), auto_unbox = TRUE), ",",
      jsonlite::toJSON(as.character(section), auto_unbox = TRUE), ",",
      jsonlite::toJSON(as.character(input_id), auto_unbox = TRUE), ");"
    )
  }

  graph_settings_manager_display_value <- function(state, rec) {
    raw <- graph_settings_manager_get(state, rec$path, NULL)
    value <- graph_settings_manager_scalar(raw)
    if (!identical(value, "—") && nzchar(as.character(rec$suffix %||% ""))) {
      value <- paste0(value, rec$suffix)
    }
    value
  }

  graph_settings_manager_value_key <- function(state, rec) {
    got <- graph_settings_manager_get_result(state, rec$path)
    if (!isTRUE(got$found)) return("<missing>")
    raw <- got$value
    encoded <- tryCatch(
      jsonlite::toJSON(raw, auto_unbox = TRUE, null = "null", na = "string", digits = NA),
      error = function(e) graph_settings_manager_scalar(raw)
    )
    paste0(typeof(raw), ":", as.character(encoded))
  }

  graph_settings_manager_raw_value <- function(state, rec) {
    got <- graph_settings_manager_get_result(state, rec$path)
    if (!isTRUE(got$found)) return(NULL)
    raw <- got$value
    if (is.null(raw) || !length(raw)) return(NULL)
    if (is.logical(raw)) return(isTRUE(raw[[1]]))
    if (is.numeric(raw)) {
      z <- suppressWarnings(as.numeric(raw[[1]]))
      return(if (is.finite(z)) z else NULL)
    }
    as.character(raw[[1]] %||% "")
  }

  graph_settings_manager_shared_summary <- function(state) {
    if (!is.list(state)) return(list(enabled = FALSE, links = 0L))
    b <- shared_style_normalize_binding(state$style$shared_library %||% NULL)
    n <- sum(vapply(b$levels, length, integer(1))) +
      sum(nzchar(unlist(b$axis, use.names = FALSE))) + length(b$legends)
    list(enabled = isTRUE(b$enabled), links = as.integer(n))
  }

  graph_settings_manager_shared_marker <- function(state, rec, library) {
    axis_nm <- as.character(rec$shared_axis %||% "")[1]
    if (!nzchar(axis_nm) || !is.list(state)) return("")
    b <- shared_style_normalize_binding(state$style$shared_library %||% NULL)
    if (!isTRUE(b$enabled)) return("")
    item_id <- as.character(b$axis[[axis_nm]] %||% "")[1]
    if (!nzchar(item_id)) return("")
    item <- library$items[[item_id]]
    if (is.list(item)) as.character(item$display %||% item_id)[1] else item_id
  }

  graph_settings_manager_payload <- reactive({
    # Explicit registry/Figure dependencies: the companion window mirrors both
    # canonical GraphState and Figure-owned editable state without owning either.
    graph_state_cache()
    shared_style_library()
    figure_layout_state()
    figure_states_now <- figure_edit_states()
    meta <- graph_meta()
    if (is.null(meta) || !nrow(meta)) {
      return(list(graphs = list(), rows = list()))
    }

    ids <- as.character(meta$id)
    names_by_id <- stats::setNames(as.character(meta$name), ids)
    states <- stats::setNames(lapply(ids, function(id) {
      st <- if (cache_has(id)) cache_get(id) else NULL
      if (is.list(st)) graph_normalize_legend_state(st) else st
    }), ids)
    main_figure_ids <- tryCatch(figure_main_panel_source_ids(), error = function(e) character(0))
    figure_states <- stats::setNames(lapply(ids, function(id) {
      st <- figure_states_now[[id]] %||% NULL
      if (is.list(st)) graph_normalize_legend_state(st) else st
    }), ids)
    rows <- graph_settings_manager_rows()
    lib <- shared_style_normalize_library(shared_style_library())

    graphs <- unname(lapply(ids, function(id) {
      ss <- graph_settings_manager_shared_summary(states[[id]])
      list(
        id = id,
        name = names_by_id[[id]] %||% id,
        sharedEnabled = isTRUE(ss$enabled),
        sharedLinks = as.integer(ss$links %||% 0L),
        inFigure = id %in% main_figure_ids,
        figureEditable = is.list(figure_states[[id]])
      )
    }))

    row_payload <- lapply(rows, function(rec) {
      keys <- unname(lapply(ids, function(id) graph_settings_manager_value_key(states[[id]], rec)))
      figure_keys <- unname(lapply(ids, function(id) {
        if (!id %in% main_figure_ids || !is.list(figure_states[[id]])) return("<unavailable>")
        graph_settings_manager_value_key(figure_states[[id]], rec)
      }))
      list(
        group = rec$group,
        label = rec$label,
        path = rec$path,
        section = rec$section,
        input = rec$input,
        canApply = isTRUE(rec$apply),
        editor = rec$editor %||% list(),
        values = unname(lapply(ids, function(id) graph_settings_manager_display_value(states[[id]], rec))),
        rawValues = unname(lapply(ids, function(id) graph_settings_manager_raw_value(states[[id]], rec))),
        keys = keys,
        figureValues = unname(lapply(ids, function(id) {
          if (!id %in% main_figure_ids || !is.list(figure_states[[id]])) return(NULL)
          graph_settings_manager_display_value(figure_states[[id]], rec)
        })),
        figureRawValues = unname(lapply(ids, function(id) {
          if (!id %in% main_figure_ids || !is.list(figure_states[[id]])) return(NULL)
          graph_settings_manager_raw_value(figure_states[[id]], rec)
        })),
        figureKeys = figure_keys,
        figureDiffers = unname(lapply(seq_along(ids), function(i) {
          ids[[i]] %in% main_figure_ids && is.list(figure_states[[ids[[i]]]]) &&
            !identical(as.character(keys[[i]]), as.character(figure_keys[[i]]))
        })),
        shared = unname(lapply(ids, function(id) graph_settings_manager_shared_marker(states[[id]], rec, lib))),
        allEqual = length(unique(unlist(keys, use.names = FALSE))) <= 1L
      )
    })

    list(graphs = graphs, rows = row_payload)
  })

  graph_settings_manager_cell <- function(id, value, shared, rec) {
    td_class <- paste(
      "graph-settings-manager-cell",
      if (!isTRUE(rec$allEqual)) "graph-settings-manager-diff-cell" else ""
    )
    tags$td(
      class = td_class,
      tags$span(class = "graph-settings-manager-value", value %||% "—"),
      if (nzchar(as.character(shared %||% ""))) tags$span(
        class = "label label-info graph-settings-manager-shared-badge",
        title = paste0("Shared Library: ", shared),
        "Shared"
      ),
      tags$button(
        type = "button",
        class = "btn btn-default btn-xs graph-settings-manager-jump",
        title = "このGraphの設定欄を開く",
        onclick = graph_settings_manager_jump_js(id, rec$section, rec$input),
        "↗"
      )
    )
  }

  output$graph_settings_manager <- renderUI({
    payload <- graph_settings_manager_payload()
    graphs <- payload$graphs %||% list()
    rows <- payload$rows %||% list()
    if (!length(graphs)) {
      return(div(class="graph-settings-manager-empty", "Graphがありません。"))
    }

    ids <- vapply(graphs, function(x) as.character(x$id %||% ""), character(1))
    body <- list()
    previous_group <- ""
    for (rec in rows) {
      if (!identical(rec$group, previous_group)) {
        body[[length(body) + 1L]] <- tags$tr(
          class = "graph-settings-manager-group-row",
          tags$th(colspan = length(ids) + 1L, rec$group)
        )
        previous_group <- rec$group
      }
      body[[length(body) + 1L]] <- tags$tr(
        class = if (!isTRUE(rec$allEqual)) "graph-settings-manager-diff-row" else "",
        tags$th(
          class = "graph-settings-manager-setting",
          rec$label,
          if (!isTRUE(rec$allEqual)) tags$span(class="graph-settings-manager-diff-badge", "差あり")
        ),
        lapply(seq_along(ids), function(i) graph_settings_manager_cell(
          ids[[i]], rec$values[[i]] %||% "—", rec$shared[[i]] %||% "", rec
        ))
      )
    }

    div(
      class = "graph-settings-manager-wrap",
      tags$p(
        class = "help-block graph-settings-manager-help",
        "各Graphの現在値を横並びで比較できます。差がある行は強調表示します。↗ で該当設定へ移動できます。一括適用は外部ウィンドウで行います。"
      ),
      div(
        class = "graph-settings-manager-scroll",
        tags$table(
          class = "table table-condensed graph-settings-manager-table",
          tags$thead(
            tags$tr(
              tags$th(class="graph-settings-manager-setting-head", "設定"),
              lapply(graphs, function(rec) tags$th(
                class="graph-settings-manager-graph-head",
                div(rec$name %||% rec$id),
                if (isTRUE(rec$sharedEnabled)) tags$span(
                  class="label label-info graph-settings-manager-shared-head",
                  paste0("Shared ", as.integer(rec$sharedLinks %||% 0L))
                )
              ))
            )
          ),
          tags$tbody(body)
        )
      )
    )
  })

  observe({
    session$sendCustomMessage("graph-settings-manager-data", graph_settings_manager_payload())
  })

  # Diagnostics only; confirms that a jump request from the in-page or popout
  # manager reached the main Shiny session.
  observeEvent(input$graph_settings_manager_jump_trace, {
    req <- input$graph_settings_manager_jump_trace %||% list()
    diag_log(
      "GRAPH-SETTINGS-JUMP",
      paste0(
        "stage=", as.character(req$stage %||% "main-received"),
        " section=", as.character(req$sectionKey %||% ""),
        " input=", as.character(req$inputId %||% "")
      ),
      id = as.character(req$id %||% "")
    )
  }, ignoreInit = TRUE)
