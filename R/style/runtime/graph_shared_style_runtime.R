  # Shared Label / Style Library bindings inside graphServer.
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

  # The grouping follows the actual mapped aesthetics. X/facet labels remain
  # independently editable in the existing Axis/Label section; they are not
  # automatically treated as line/point styles.
  shared_style_level_rows <- reactive({
    d <- tryCatch(dat(), error = function(e) NULL)
    if (!is.data.frame(d)) return(list())
    plot_type <- graph_plot_value("type", input$plot_type %||% "line")
    mapped <- list(
      color = resolve_color_var(d),
      linetype = graph_mapping_value("linetype", input$linetypevar %||% "__color__"),
      shape = graph_mapping_value("shape", input$shapevar %||% "__color__")
    )
    roles <- shared_style_mapping_roles(
      mapped, plot_type, names(d),
      scatter_connect = graph_appearance_value("scatter_connect_mode", input$scatter_connect_mode %||% "none"),
      scatter_raw_shapes = isTRUE(graph_appearance_value("show_raw", input$show_raw))
    )
    rows <- list()
    for (vn in names(roles)) {
      observed <- unique(as.character(d[[vn]]))
      observed <- observed[!is.na(observed)]
      for (lv in observed) {
        rows[[paste0(vn, "\r", lv)]] <- list(variable = vn, level = lv,
                                               roles = roles[[vn]])
      }
    }
    rows
  })

  # Keep the renderUI DOM steady on ordinary GraphState commits. The source
  # data may invalidate `dat()` even though the set of aesthetic keys did not
  # change. Only changes to mapping/levels, library choice labels, or legend
  # structure require replacing these selectors.
  shared_style_ui_structure <- reactiveVal(NULL)
  observe({
    rows <- shared_style_level_rows()
    specs <- active_legend_specs()
    spec <- list(
      rows = rows,
      specs = specs,
      levels = shared_style_choices("level"),
      axes = shared_style_choices("axis_label"),
      legends = shared_style_choices("legend_title")
    )
    if (!identical(isolate(shared_style_ui_structure()), spec)) {
      shared_style_ui_structure(spec)
    }
  }, priority = 140)

  output$shared_style_binding_status <- renderText({
    rows <- shared_style_level_rows()
    b <- shared_style_normalize_binding(shared_style_binding())
    linked <- sum(vapply(rows, function(row) {
      nzchar(shared_style_safe_id(b$levels[[row$variable]][[row$level]] %||% ""))
    }, logical(1)))
    paste0("Mapping対応済み: ", linked, " / ", length(rows), "件")
  })

  output$shared_style_binding_ui <- renderUI({
    shared_style_binding_ui_epoch()
    spec <- shared_style_ui_structure()
    if (is.null(spec)) return(NULL)
    b <- shared_style_normalize_binding(isolate(shared_style_binding()))
    rows <- spec$rows
    by_variable <- split(rows, vapply(rows, function(row) row$variable, character(1)))
    attr_selected <- names(b$attributes)[vapply(b$attributes, isTRUE, logical(1))]
    active_keys <- vapply(rows, function(row) paste0(row$variable, "\r", row$level), character(1))
    legacy_rows <- list()
    for (vn in names(b$levels) %||% character(0)) {
      for (lv in names(b$levels[[vn]]) %||% character(0)) {
        if (paste0(vn, "\r", lv) %in% active_keys) next
        legacy_rows[[paste0(vn, "\r", lv)]] <- list(variable = vn, level = lv)
      }
    }
    level_choices <- spec$levels
    axis_choices <- spec$axes
    legend_choices <- spec$legends

    tagList(div(class = "shared-style-graph-binding",
      checkboxInput(shared_style_input_id("shared_style_enabled", "binding"),
                    "共通スタイルを使用", value = isTRUE(b$enabled)),
      checkboxGroupInput(shared_style_input_id("shared_style_attributes", "binding"),
        "共通スタイルで揃える項目",
        choices = c("表示名" = "display", "色" = "color", "形" = "shape", "線" = "linetype"),
        selected = attr_selected, inline = TRUE),
      div(class = "help-block",
        shiny::textOutput(session$ns("shared_style_binding_status")),
        tags$span("X軸・Facetの表示名は『7. 軸・Label』で設定できます。Figureは自動更新しません。")),
      if (!length(rows)) {
        tags$p(class = "help-block", "共有対象のColor・Shape・Linetype Mappingはありません。")
      } else {
        tags$details(class = "shared-style-detail", open = "open",
          tags$summary("視覚スタイルの対応付け"),
          lapply(names(by_variable), function(vn) {
            var_rows <- by_variable[[vn]]
            roles <- unique(unlist(lapply(var_rows, `[[`, "roles"), use.names = FALSE))
            tags$div(class = "shared-style-mapped-group",
              tags$strong(paste0(paste(roles, collapse = "・"), ": ", vn)),
              tags$div(class = "shared-style-binding-grid", lapply(var_rows, function(row) {
                current <- b$levels[[row$variable]][[row$level]] %||% ""
                div(class = "shared-style-binding-row",
                  tags$span(class = "shared-style-binding-source", row$level),
                  selectInput(shared_style_input_id("shared_bind_level", paste0(row$variable, "::", row$level)),
                              NULL, choices = level_choices, selected = current,
                              width = "230px", selectize = FALSE))
              }))
            )
          })
        )
      },
      if (length(legacy_rows)) tags$details(class = "shared-style-detail",
        tags$summary(paste0("既存Projectの旧対応（Mapping外・", length(legacy_rows), "件）")),
        tags$p(class = "help-block", "旧ProjectのX軸・Facet等に残る接続です。新しい一括対応の対象にはなりません。不要なら未接続に変更できます。"),
        tags$div(class = "shared-style-binding-grid",
          lapply(legacy_rows, function(row) {
            current <- b$levels[[row$variable]][[row$level]] %||% ""
            div(class = "shared-style-binding-row",
              tags$span(class = "shared-style-binding-source", paste0(row$variable, " / ", row$level)),
              selectInput(shared_style_input_id("shared_bind_level", paste0(row$variable, "::", row$level)),
                NULL, choices = level_choices, selected = current, width = "230px", selectize = FALSE))
          })
        )
      ),
      tags$details(class = "shared-style-detail",
        tags$summary("軸ラベル・凡例タイトル（個別設定）"),
        tags$div(class = "shared-style-binding-grid shared-style-binding-axis",
          div(class = "shared-style-binding-row", tags$span(class = "shared-style-binding-source", "X axis"),
            selectInput(shared_style_input_id("shared_bind_axis", "x"), NULL,
                        choices = axis_choices, selected = b$axis$x %||% "", width = "230px", selectize = FALSE)),
          div(class = "shared-style-binding-row", tags$span(class = "shared-style-binding-source", "Y axis"),
            selectInput(shared_style_input_id("shared_bind_axis", "y"), NULL,
                        choices = axis_choices, selected = b$axis$y %||% "", width = "230px", selectize = FALSE))
        ),
        if (length(spec$specs)) tags$div(class = "shared-style-binding-grid",
          lapply(spec$specs, function(sp) {
            current <- b$legends[[sp$key]] %||% ""
            div(class = "shared-style-binding-row",
              tags$span(class = "shared-style-binding-source", paste0(sp$used_by, " / ", sp$default)),
              selectInput(shared_style_input_id("shared_bind_legend", sp$key), NULL,
                choices = legend_choices, selected = current, width = "230px", selectize = FALSE))
          })
        )
      )
    ))
  })

  # Use the exact same Library editor as Figure, with a Graph-side entry
  # point. The modal and its handlers remain project-level / single-owner.
  observeEvent(input$shared_style_open_library, {
    if (is.function(on_shared_style_library_open)) on_shared_style_library_open()
  }, ignoreInit = TRUE)

  shared_style_bulk_commit <- function(create_missing = FALSE) {
    if (isTRUE(restoring_style_state()) || isTRUE(graph_state_replay_active()) ||
        !isTRUE(graph_activation_current())) return(invisible(FALSE))
    rows <- isolate(shared_style_level_rows())
    result <- shared_style_bulk_bind_levels(
      isolate(shared_style_library()), isolate(shared_style_binding()),
      rows, create_missing = create_missing,
      source_style = list(color_styles = isolate(color_styles()),
                          shape_styles = isolate(shape_styles()),
                          linetype_styles = isolate(linetype_styles()))
    )
    if (result$created > 0L) {
      if (!is.function(on_shared_style_library_change) ||
          !isTRUE(on_shared_style_library_change(result$library))) {
        showNotification("共通スタイルの作成を確定できませんでした。", type = "warning")
        return(invisible(FALSE))
      }
    }
    old <- isolate(shared_style_binding())
    if (!identical(old, result$binding)) {
      shared_style_binding(result$binding)
      shared_style_diag_binding(result$binding)
      # Fresh input generation prevents stale selectInput values from a prior
      # UI from overwriting the newly committed bulk binding.
      shared_style_binding_ui_epoch(as.integer(isolate(shared_style_binding_ui_epoch()) %||% 0L) + 1L)
    }
    if (result$linked > 0L || result$created > 0L) {
      showNotification(paste0(result$linked, "件を対応付け、", result$created,
          "件の共通スタイルを作成しました。",
          if (!isTRUE(result$binding$enabled)) "『共通スタイルを使用』をONにすると適用されます。" else ""),
          type = "message", duration = 5)
    } else {
      showNotification("新たに対応できる未接続項目はありませんでした。", type = "message")
    }
    if (result$ambiguous > 0L) {
      showNotification(paste0(result$ambiguous, "件は同名の共通スタイルが複数あるため保留しました。個別に選択してください。"),
                       type = "warning", duration = 6)
    }
    invisible(TRUE)
  }
  observeEvent(input$shared_style_bulk_match, {
    shared_style_bulk_commit(create_missing = FALSE)
  }, ignoreInit = TRUE)
  observeEvent(input$shared_style_bulk_register, {
    shared_style_bulk_commit(create_missing = TRUE)
  }, ignoreInit = TRUE)

  # The linkage checkbox is user-intent owned. A hidden persistent Editor can
  # be unbound/rebound while Figure is active; that browser lifecycle used to
  # publish a synthetic FALSE and silently disable the Graph. Only the explicit
  # trusted-user channel from app_client.js may change `enabled`.
  observeEvent(input$shared_style_enabled_user_change, {
    if (isTRUE(restoring_style_state()) || isTRUE(graph_state_replay_active()) ||
        !isTRUE(graph_activation_current())) return()
    req <- input$shared_style_enabled_user_change
    if (!is.list(req) || is.null(req$value) ||
        !identical(shared_style_scalar_chr(req$controlId, ""),
                   session$ns(shared_style_input_id("shared_style_enabled", "binding")))) return()
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

  # Only actual browser changes modify the linkage/attributes. A Shiny input
  # echo from renderUI or workspace resume is not user intent, and must not
  # write its temporary values back into canonical GraphState.
  observeEvent(input$shared_style_binding_user_change, {
    if (isTRUE(restoring_style_state()) || isTRUE(graph_state_replay_active()) ||
        !isTRUE(graph_activation_current())) return()
    req <- input$shared_style_binding_user_change
    if (!is.list(req) || is.null(req$controlId)) return()
    owner_now <- tryCatch(as.character(graph_browser_patch_override_snapshot()$graphId %||% "")[[1]],
                          error = function(e) "")
    req_graph <- shared_style_scalar_chr(req$graphId, "")
    if (!nzchar(req_graph) || !identical(req_graph, owner_now)) return()
    current_id <- function(prefix, key) {
      identical(shared_style_scalar_chr(req$controlId, ""),
                session$ns(shared_style_input_id(prefix, key)))
    }
    old <- isolate(shared_style_binding())
    b <- shared_style_normalize_binding(old)
    value <- req$value
    found <- FALSE
    if (current_id("shared_style_attributes", "binding")) {
      attrs <- as.character(value %||% character(0))
      b$attributes <- list(display = "display" %in% attrs,
                           color = "color" %in% attrs,
                           shape = "shape" %in% attrs,
                           linetype = "linetype" %in% attrs)
      found <- TRUE
    } else {
      rows_now <- isolate(shared_style_level_rows())
      for (vn in names(b$levels) %||% character(0)) {
        for (lv in names(b$levels[[vn]]) %||% character(0)) {
          key <- paste0(vn, "\r", lv)
          if (!any(vapply(rows_now, function(row) identical(paste0(row$variable, "\r", row$level), key), logical(1)))) {
            rows_now[[key]] <- list(variable = vn, level = lv)
          }
        }
      }
      for (row in rows_now) {
        if (!current_id("shared_bind_level", paste0(row$variable, "::", row$level))) next
        id <- shared_style_safe_id(value)
        branch <- b$levels[[row$variable]] %||% list()
        if (nzchar(id)) branch[[row$level]] <- id else branch[[row$level]] <- NULL
        if (length(branch)) b$levels[[row$variable]] <- branch else b$levels[[row$variable]] <- NULL
        found <- TRUE
        break
      }
      if (!found) for (axis_nm in c("x", "y")) {
        if (!current_id("shared_bind_axis", axis_nm)) next
        b$axis[[axis_nm]] <- shared_style_safe_id(value)
        found <- TRUE
        break
      }
      if (!found) for (sp in isolate(active_legend_specs())) {
        if (!current_id("shared_bind_legend", sp$key)) next
        id <- shared_style_safe_id(value)
        if (nzchar(id)) b$legends[[sp$key]] <- id else b$legends[[sp$key]] <- NULL
        found <- TRUE
        break
      }
    }
    if (!found) return()
    b <- shared_style_normalize_binding(b)
    if (!identical(old, b)) {
      shared_style_binding(b)
      shared_style_diag_binding(b)
    }
  }, priority = 120, ignoreInit = TRUE)

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
        title_input <- if (graph_plot_uses_fill(graph_plot_value("type", input$plot_type %||% "line"))) "legend_fill_title" else "legend_colour_title"
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
    current_title <- if (graph_plot_uses_fill(graph_plot_value("type", input$plot_type %||% "line"))) current_fill_title else current_colour_title

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
