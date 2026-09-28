# v3.73.0 — Shared Label / Style Library bindings inside graphServer.
# This runtime owns only the interactive Graph-side binding UI and local
# write-through adapter. The central Library and cross-Graph propagation live
# in R/server/style/server_shared_style_runtime.R.

  shared_style_choices <- function(kind) {
    items <- shared_style_library_items(shared_style_library(), kind)
    if (!length(items)) return(c("未接続" = ""))
    labs <- vapply(items, shared_style_item_label, character(1))
    vals <- names(items)
    out <- stats::setNames(vals, labs)
    c("未接続" = "", out)
  }

  # Shared Style controls have a focused UI generation in addition to the
  # ordinary Style generation. Returning from Figure can rebind hidden Shiny
  # inputs; using a fresh id lets us rehydrate from the Graph-owned binding
  # without rebuilding the rest of the Style editor.
  shared_style_input_id <- function(prefix, variable_name, level_name = NULL) {
    paste0(
      style_input_id(prefix, variable_name, level_name),
      "_ss", as.integer(shared_style_binding_ui_epoch() %||% 0L)
    )
  }

  shared_style_diag_binding <- function(b) {
    b <- shared_style_normalize_binding(b)
    diag(
      "SHARED-STYLE-BIND",
      paste0(
        "enabled=", isTRUE(b$enabled),
        " level_links=", sum(vapply(b$levels, length, integer(1))),
        " axis_links=", sum(nzchar(unlist(b$axis, use.names = FALSE))),
        " legend_links=", length(b$legends)
      )
    )
    invisible(TRUE)
  }

  shared_style_level_rows <- reactive({
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return(list())
    vars <- active_display_label_vars()
    rows <- list()
    for (v in vars) {
      if (!v %in% names(d)) next
      observed <- unique(as.character(d[[v]]))
      observed <- observed[!is.na(observed)]
      for (lv in observed) rows[[paste0(v, "\r", lv)]] <- list(variable = v, level = lv)
    }
    rows
  })

  output$shared_style_binding_ui <- renderUI({
    style_restore_epoch()
    shared_style_binding_ui_epoch()
    lib <- shared_style_normalize_library(shared_style_library())
    b <- shared_style_normalize_binding(isolate(shared_style_binding()))
    level_choices <- shared_style_choices("level")
    axis_choices <- shared_style_choices("axis_label")
    legend_choices <- shared_style_choices("legend_title")
    rows <- shared_style_level_rows()
    specs <- active_legend_specs()

    attr_selected <- names(b$attributes)[vapply(b$attributes, isTRUE, logical(1))]
    linked_n <- sum(vapply(b$levels, length, integer(1))) +
      sum(nzchar(unlist(b$axis, use.names = FALSE))) + length(b$legends)

    tagList(
      div(
        class = "shared-style-graph-binding",
        checkboxInput(
          shared_style_input_id("shared_style_enabled", "binding"),
          "共通スタイルを使用", value = isTRUE(b$enabled)
        ),
        checkboxGroupInput(
          shared_style_input_id("shared_style_attributes", "binding"), "共通スタイルで揃える項目",
          choices = c("表示名" = "display", "色" = "color", "形" = "shape", "線" = "linetype"),
          selected = attr_selected, inline = TRUE
        ),
        tags$p(
          class = "help-block",
          paste0(
            "共通グループとこのGraphの項目を対応づけます。現在の対応: ", linked_n,
            "。揃える項目をこのGraphで変更すると、同じ共通グループを使うGraphにも反映します。Figureは自動では変わりません。"
          )
        ),
        if (!length(lib$items)) {
          tags$div(class = "alert alert-info shared-style-empty", "共通スタイルはまだありません。Figure > Figure調整 > まとめて調整 > 共通スタイル管理 から作成してください。")
        } else tagList(
          if (length(rows)) tagList(
            tags$strong("群・条件"),
            tags$div(
              class = "shared-style-binding-grid",
              lapply(rows, function(row) {
                current <- b$levels[[row$variable]][[row$level]] %||% ""
                div(
                  class = "shared-style-binding-row",
                  tags$span(class = "shared-style-binding-source", paste0(row$variable, " / ", row$level)),
                  selectInput(
                    shared_style_input_id("shared_bind_level", paste0(row$variable, "::", row$level)),
                    label = NULL, choices = level_choices, selected = current, width = "230px"
                  )
                )
              })
            )
          ),
          tags$hr(),
          tags$strong("軸ラベル"),
          div(
            class = "shared-style-binding-grid shared-style-binding-axis",
            div(class = "shared-style-binding-row", tags$span(class = "shared-style-binding-source", "X axis"),
                selectInput(shared_style_input_id("shared_bind_axis", "x"), NULL, choices = axis_choices, selected = b$axis$x %||% "", width = "230px")),
            div(class = "shared-style-binding-row", tags$span(class = "shared-style-binding-source", "Y axis"),
                selectInput(shared_style_input_id("shared_bind_axis", "y"), NULL, choices = axis_choices, selected = b$axis$y %||% "", width = "230px"))
          ),
          if (length(specs)) tagList(
            tags$hr(),
            tags$strong("凡例タイトル"),
            tags$div(
              class = "shared-style-binding-grid",
              lapply(specs, function(sp) {
                current <- b$legends[[sp$key]] %||% ""
                div(
                  class = "shared-style-binding-row",
                  tags$span(class = "shared-style-binding-source", paste0(sp$used_by, " / ", sp$default)),
                  selectInput(shared_style_input_id("shared_bind_legend", sp$key), NULL, choices = legend_choices, selected = current, width = "230px")
                )
              })
            )
          )
        )
      )
    )
  })

  # The linkage checkbox is user-intent owned. A hidden persistent Editor can
  # be unbound/rebound while Figure is active; that browser lifecycle used to
  # publish a synthetic FALSE and silently disable the Graph. Only the explicit
  # trusted-user channel from app_client.js may change `enabled`.
  observeEvent(input$shared_style_enabled_user_change, {
    if (isTRUE(restoring_style_state()) || isTRUE(graph_state_replay_active())) return()
    req <- input$shared_style_enabled_user_change
    if (!is.list(req) || is.null(req$value)) return()
    req_graph <- as.character(req$graphId %||% "")[[1]]
    owner_now <- tryCatch(as.character(graph_browser_patch_override_snapshot()$graphId %||% "")[[1]], error = function(e) "")
    if (nzchar(req_graph) && nzchar(owner_now) && !identical(req_graph, owner_now)) {
      diag("SHARED-STYLE-BIND-SKIP", paste0("stale user event graph=", req_graph, " owner=", owner_now))
      return()
    }
    old <- isolate(shared_style_binding())
    b <- shared_style_normalize_binding(old)
    b$enabled <- isTRUE(req$value)
    b <- shared_style_normalize_binding(b)
    if (!identical(old, b)) {
      shared_style_binding(b)
      shared_style_diag_binding(b)
    }
  }, ignoreInit = TRUE, priority = 130)

  # Remaining Browser binding controls -> canonical per-Graph binding metadata.
  # Do not read/write the linkage checkbox here: this observer can re-run for
  # topology/UI reasons that are not user edits.
  observe({
    if (isTRUE(restoring_style_state())) return()
    style_restore_epoch()
    shared_style_binding_ui_epoch()
    attrs <- input[[shared_style_input_id("shared_style_attributes", "binding")]]

    old <- isolate(shared_style_binding())
    b <- shared_style_normalize_binding(old)
    if (!is.null(attrs)) {
      attrs <- as.character(attrs %||% character(0))
      b$attributes <- list(
        display = "display" %in% attrs,
        color = "color" %in% attrs,
        shape = "shape" %in% attrs,
        linetype = "linetype" %in% attrs
      )
    }

    rows <- shared_style_level_rows()
    active_keys <- character(0)
    for (row in rows) {
      key <- paste0(row$variable, "\r", row$level)
      active_keys <- c(active_keys, key)
      val <- input[[shared_style_input_id("shared_bind_level", paste0(row$variable, "::", row$level))]]
      if (is.null(val)) next
      val <- shared_style_safe_id(val)
      br <- b$levels[[row$variable]] %||% list()
      if (nzchar(val)) br[[row$level]] <- val else br[[row$level]] <- NULL
      if (length(br)) b$levels[[row$variable]] <- br else b$levels[[row$variable]] <- NULL
    }

    for (axis_nm in c("x", "y")) {
      val <- input[[shared_style_input_id("shared_bind_axis", axis_nm)]]
      if (!is.null(val)) b$axis[[axis_nm]] <- shared_style_safe_id(val)
    }
    specs <- active_legend_specs()
    active_legend_keys <- vapply(specs, function(sp) sp$key, character(1))
    for (sp in specs) {
      val <- input[[shared_style_input_id("shared_bind_legend", sp$key)]]
      if (is.null(val)) next
      val <- shared_style_safe_id(val)
      if (nzchar(val)) b$legends[[sp$key]] <- val else b$legends[[sp$key]] <- NULL
    }

    b <- shared_style_normalize_binding(b)
    if (!identical(old, b)) {
      shared_style_binding(b)
      shared_style_diag_binding(b)
    }
  }, priority = 120)

  shared_style_apply_local <- function() {
    lib <- shared_style_normalize_library(shared_style_library())
    b <- shared_style_normalize_binding(shared_style_binding())
    if (!isTRUE(b$enabled)) return(invisible(FALSE))
    attrs <- b$attributes
    changed <- FALSE

    ll <- isolate(level_labels())
    cs <- isolate(color_styles())
    ss <- isolate(shape_styles())
    ls <- isolate(linetype_styles())
    lt <- isolate(legend_titles())

    for (vn in names(b$levels) %||% character(0)) {
      for (lv in names(b$levels[[vn]]) %||% character(0)) {
        item <- lib$items[[b$levels[[vn]][[lv]]]]
        if (!is.list(item) || !identical(item$kind, "level")) next
        mg <- item$manage %||% list()
        if (isTRUE(attrs$display) && isTRUE(mg$display)) {
          br <- ll[[vn]] %||% list(); if (!identical(br[[lv]], item$display)) { br[[lv]] <- item$display; ll[[vn]] <- br; changed <- TRUE }
        }
        if (isTRUE(attrs$color) && (isTRUE(mg$color) || isTRUE(mg$fill))) {
          br <- cs[[vn]] %||% list(); if (!identical(as.character(br[[lv]] %||% ""), as.character(item$color))) { br[[lv]] <- item$color; cs[[vn]] <- br; changed <- TRUE }
        }
        if (isTRUE(attrs$shape) && isTRUE(mg$shape)) {
          br <- ss[[vn]] %||% list(); if (!isTRUE(all.equal(as.numeric(br[[lv]] %||% NA_real_), as.numeric(item$shape)))) { br[[lv]] <- item$shape; ss[[vn]] <- br; changed <- TRUE }
        }
        if (isTRUE(attrs$linetype) && isTRUE(mg$linetype)) {
          br <- ls[[vn]] %||% list(); if (!identical(as.character(br[[lv]] %||% ""), as.character(item$linetype))) { br[[lv]] <- item$linetype; ls[[vn]] <- br; changed <- TRUE }
        }
      }
    }

    if (isTRUE(attrs$display)) {
      for (axis_nm in c("x", "y")) {
        item <- lib$items[[b$axis[[axis_nm]] %||% ""]]
        if (is.list(item) && identical(item$kind, "axis_label") && isTRUE(item$manage$display)) {
          if (identical(axis_nm, "x")) {
            current_xlab <- graph_label_value("xlab", input$xlab %||% "")
            if (!identical(as.character(current_xlab), as.character(item$display))) {
              updateTextAreaInput(session, "xlab", value = item$display)
            }
          } else {
            current_ylab <- graph_label_value("ylab", input$ylab %||% "")
            if (!identical(as.character(current_ylab), as.character(item$display))) {
              updateTextAreaInput(session, "ylab", value = item$display)
            }
          }
        }
      }
      for (legend_key in names(b$legends) %||% character(0)) {
        item <- lib$items[[b$legends[[legend_key]]]]
        if (!is.list(item) || !identical(item$kind, "legend_title") || !isTRUE(item$manage$display)) next
        if (!identical(lt[[legend_key]], item$display)) { lt[[legend_key]] <- item$display; changed <- TRUE }
        key <- graph_group_legend_key(list(mapping = list(
          color = graph_mapping_value("color", input$colorvar %||% ""),
          position = graph_mapping_value("position", input$groupvar %||% "")
        ), style = list(appearance = list(
          series_style_override = graph_appearance_value("series_style_override", input$series_style_override)
        ))))
        title_input <- if (graph_plot_value("type", input$plot_type %||% "line") %in% c("bar", "box")) "legend_fill_title" else "legend_colour_title"
        current_legend_title <- graph_appearance_value(title_input, input[[title_input]] %||% "")
        if (identical(legend_key, key) && !identical(current_legend_title, item$display)) {
          updateTextInput(session, "legend_group_title", value = item$display)
          updateTextInput(session, title_input, value = item$display)
        }
      }
    }

    if (!identical(ll, isolate(level_labels()))) {
      level_labels(ll)
      shared_style_mark_ui_sync()
    }
    if (!identical(cs, isolate(color_styles()))) color_styles(cs)
    if (!identical(ss, isolate(shape_styles()))) shape_styles(ss)
    if (!identical(ls, isolate(linetype_styles()))) linetype_styles(ls)
    if (!identical(lt, isolate(legend_titles()))) legend_titles(lt)
    invisible(changed)
  }

  # Pull from Library before lower-priority write-through observers see local
  # state. This keeps explicit bindings Library-authoritative on restore.
  observe({
    shared_style_library()
    shared_style_binding()
    if (isTRUE(restoring_style_state())) return()
    shared_style_apply_local()
  }, priority = 80)

  # Graph -> Library write-through is event-driven, not state-driven. The old
  # implementation observed level_labels/color_styles/etc. directly, so a
  # Library -> Graph application invalidated the writeback observer and could
  # bounce the same semantic value back into the Library indefinitely. Only
  # explicit user-edit sources increment shared_style_user_edit_epoch().
  observeEvent(shared_style_user_edit_epoch(), {
    if (isTRUE(restoring_style_state())) return()
    b <- shared_style_normalize_binding(shared_style_binding())
    if (!isTRUE(b$enabled) || !is.function(on_shared_style_library_change)) return()

    reason <- as.character(isolate(shared_style_user_edit_reason()) %||% "graph-user-edit")[[1]]
    current_xlab <- graph_label_value("xlab", input$xlab %||% "")
    current_ylab <- graph_label_value("ylab", input$ylab %||% "")
    current_colour_title <- graph_appearance_value("legend_colour_title", input$legend_colour_title %||% "")
    current_fill_title <- graph_appearance_value("legend_fill_title", input$legend_fill_title %||% "")
    current_title <- if (graph_plot_value("type", input$plot_type %||% "line") %in% c("bar", "box")) current_fill_title else current_colour_title

    # Axis controls are browser-owned and may be applied programmatically by the
    # Library. They become write-through candidates only when this event itself
    # came from an explicit axis edit. This keeps Library -> Graph directional.
    b_write <- b
    if (!reason %in% c("browser:xlab", "browser:ylab")) {
      b_write$axis <- list(x = "", y = "")
    } else if (identical(reason, "browser:xlab")) {
      b_write$axis$y <- ""
    } else if (identical(reason, "browser:ylab")) {
      b_write$axis$x <- ""
    }

    # Likewise, legend-title writeback is enabled only for the explicit browser
    # title controls. Level/style edits should not reinterpret a programmatic
    # legend title refresh as a Graph edit.
    if (!reason %in% c("browser:legend_group_title", "browser:legend_colour_title", "browser:legend_fill_title")) {
      b_write$legends <- list()
    }

    partial_state <- list(
      mapping = list(
        color = graph_mapping_value("color", input$colorvar %||% ""),
        position = graph_mapping_value("position", input$groupvar %||% "")
      ),
      plot = list(type = graph_plot_value("type", input$plot_type %||% "line")),
      labels = list(xlab = current_xlab, ylab = current_ylab),
      style = list(
        appearance = list(legend_group_title = current_title,
                          legend_colour_title = current_colour_title,
                          legend_fill_title = current_fill_title,
                          series_style_override = graph_appearance_value("series_style_override", input$series_style_override)),
        color_styles = isolate(color_styles()),
        shape_styles = isolate(shape_styles()),
        linetype_styles = isolate(linetype_styles()),
        legend_titles = isolate(legend_titles()),
        level_labels = isolate(level_labels()),
        shared_library = b_write
      )
    )
    old_lib <- isolate(shared_style_library())
    new_lib <- shared_style_update_library_from_graph_state(old_lib, partial_state)
    if (!identical(shared_style_normalize_library(old_lib), new_lib)) {
      diag("SHARED-STYLE-WRITEBACK", paste0("trigger=", reason))
      on_shared_style_library_change(new_lib)
    }
  }, ignoreInit = TRUE, priority = -90)
