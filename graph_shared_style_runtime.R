# v3.73.0 — Shared Label / Style Library bindings inside graphServer.
# This runtime owns only the interactive Graph-side binding UI and local
# write-through adapter. The central Library and cross-Graph propagation live
# in server_shared_style_runtime.R.

  shared_style_choices <- function(kind) {
    items <- shared_style_library_items(shared_style_library(), kind)
    if (!length(items)) return(c("未接続" = ""))
    labs <- vapply(items, shared_style_item_label, character(1))
    vals <- names(items)
    out <- stats::setNames(vals, labs)
    c("未接続" = "", out)
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
        checkboxInput("shared_style_enabled", "共通Graph Label / Style Libraryと連動", value = isTRUE(b$enabled)),
        checkboxGroupInput(
          "shared_style_attributes", "Libraryから管理する属性",
          choices = c("表示名" = "display", "Color / Fill" = "color", "Shape" = "shape", "Line type" = "linetype"),
          selected = attr_selected, inline = TRUE
        ),
        tags$p(
          class = "help-block",
          paste0(
            "①連動をON → ②Libraryから管理する属性を選択 → ③下の各行で対応するLibrary項目を選択します。名前から自動判定しません。現在のbinding: ", linked_n,
            "。Library連動中の属性をこのGraphで変更するとLibraryへ書き戻し、他の連動Graphへ反映します。"
          )
        ),
        if (!length(lib$items)) {
          tags$div(class = "alert alert-info shared-style-empty", "Shared Libraryはまだ空です。Figure > 共通Graph Label / Style で項目を作成してください。")
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
                    style_input_id("shared_bind_level", paste0(row$variable, "::", row$level)),
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
                selectInput(style_input_id("shared_bind_axis", "x"), NULL, choices = axis_choices, selected = b$axis$x %||% "", width = "230px")),
            div(class = "shared-style-binding-row", tags$span(class = "shared-style-binding-source", "Y axis"),
                selectInput(style_input_id("shared_bind_axis", "y"), NULL, choices = axis_choices, selected = b$axis$y %||% "", width = "230px"))
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
                  selectInput(style_input_id("shared_bind_legend", sp$key), NULL, choices = legend_choices, selected = current, width = "230px")
                )
              })
            )
          )
        )
      )
    )
  })

  # Browser binding controls -> canonical per-Graph binding metadata.
  observe({
    if (isTRUE(restoring_style_state())) return()
    enabled <- input$shared_style_enabled
    attrs <- input$shared_style_attributes
    if (is.null(enabled) || is.null(attrs)) return()

    old <- isolate(shared_style_binding())
    b <- shared_style_normalize_binding(old)
    b$enabled <- isTRUE(enabled)
    attrs <- as.character(attrs %||% character(0))
    b$attributes <- list(
      display = "display" %in% attrs,
      color = "color" %in% attrs,
      shape = "shape" %in% attrs,
      linetype = "linetype" %in% attrs
    )

    rows <- shared_style_level_rows()
    active_keys <- character(0)
    for (row in rows) {
      key <- paste0(row$variable, "\r", row$level)
      active_keys <- c(active_keys, key)
      val <- input[[style_input_id("shared_bind_level", paste0(row$variable, "::", row$level))]]
      if (is.null(val)) next
      val <- shared_style_safe_id(val)
      br <- b$levels[[row$variable]] %||% list()
      if (nzchar(val)) br[[row$level]] <- val else br[[row$level]] <- NULL
      if (length(br)) b$levels[[row$variable]] <- br else b$levels[[row$variable]] <- NULL
    }

    for (axis_nm in c("x", "y")) {
      val <- input[[style_input_id("shared_bind_axis", axis_nm)]]
      if (!is.null(val)) b$axis[[axis_nm]] <- shared_style_safe_id(val)
    }
    specs <- active_legend_specs()
    active_legend_keys <- vapply(specs, function(sp) sp$key, character(1))
    for (sp in specs) {
      val <- input[[style_input_id("shared_bind_legend", sp$key)]]
      if (is.null(val)) next
      val <- shared_style_safe_id(val)
      if (nzchar(val)) b$legends[[sp$key]] <- val else b$legends[[sp$key]] <- NULL
    }

    b <- shared_style_normalize_binding(b)
    if (!identical(old, b)) {
      shared_style_binding(b)
      diag(
        "SHARED-STYLE-BIND",
        paste0(
          "enabled=", isTRUE(b$enabled),
          " level_links=", sum(vapply(b$levels, length, integer(1))),
          " axis_links=", sum(nzchar(unlist(b$axis, use.names = FALSE))),
          " legend_links=", length(b$legends)
        )
      )
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
            if (!identical(as.character(input$xlab %||% ""), as.character(item$display))) {
              updateTextAreaInput(session, "xlab", value = item$display)
            }
          } else if (!identical(as.character(input$ylab %||% ""), as.character(item$display))) {
            updateTextAreaInput(session, "ylab", value = item$display)
          }
        }
      }
      for (legend_key in names(b$legends) %||% character(0)) {
        item <- lib$items[[b$legends[[legend_key]]]]
        if (!is.list(item) || !identical(item$kind, "legend_title") || !isTRUE(item$manage$display)) next
        if (!identical(lt[[legend_key]], item$display)) { lt[[legend_key]] <- item$display; changed <- TRUE }
      }
    }

    if (!identical(ll, isolate(level_labels()))) level_labels(ll)
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

  # Linked Graph edits write back to the central semantic item. The server-level
  # callback performs an identical-state guard and propagates only affected
  # canonical Graphs; no Graph-to-Graph direct messaging exists.
  observe({
    if (isTRUE(restoring_style_state())) return()
    b <- shared_style_normalize_binding(shared_style_binding())
    if (!isTRUE(b$enabled) || !is.function(on_shared_style_library_change)) return()

    # Dependencies that can represent linked user edits.
    level_labels(); color_styles(); shape_styles(); linetype_styles(); legend_titles()
    input$xlab; input$ylab

    # Axis text controls are browser inputs. Immediately after a binding change,
    # updateTextAreaInput() may still be in flight when this low-priority
    # observer runs. Do not write those transient values back into the central
    # Library. Axis bindings are Library -> Graph in this first release;
    # level/legend/style values remain safe to write through because their
    # reactiveVals are updated synchronously.
    b_write <- b
    b_write$axis <- list(x = "", y = "")

    partial_state <- list(
      labels = list(xlab = input$xlab %||% "", ylab = input$ylab %||% ""),
      style = list(
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
      on_shared_style_library_change(new_lib)
    }
  }, priority = -90)
