# v3.70.0: extracted from server.R; sourced into the same server function environment.

  # ------------------------------------------------------------------
  # Graph tabs / UI
  # ------------------------------------------------------------------
  output$graph_tab_bar <- renderUI({
    meta <- graph_meta()
    active <- active_graph()
    if (!nrow(meta)) return(NULL)

    tagList(lapply(seq_len(nrow(meta)), function(i) {
      id <- meta$id[i]
      nm <- meta$name[i]
      cls <- paste("graph-tab-btn", if (identical(id, active)) "active" else "")
      tags$button(
        type = "button",
        class = cls,
        `data-graph-id` = id,
        onclick = sprintf(
          "if (window.ggplotGuiBrowseGraph) return window.ggplotGuiBrowseGraph('%s'); if (window.Shiny) Shiny.setInputValue('graph_client_selected', '%s', {priority:'event'}); return false;",
          id, id
        ),
        ondblclick = sprintf(
          "Shiny.setInputValue('graph_rename_dblclick', '%s', {priority:'event'});",
          id
        ),
        title = "クリック: このGraphをEditorへ切替 / ダブルクリック: 名前変更",
        nm
      )
    }))
  })

  output$bulk_export_choices <- renderUI({
    meta <- graph_meta()
    if (!nrow(meta)) return(NULL)

    current <- isolate(input$bulk_export_selected %||% character(0))
    selected <- intersect(current, meta$id)
    if (!length(selected)) {
      a <- isolate(active_graph())
      selected <- if (a %in% meta$id) a else meta$id[1]
    }

    checkboxGroupInput(
      "bulk_export_selected", NULL,
      choices = stats::setNames(as.list(as.character(meta$id)), as.character(meta$name)),
      selected = selected
    )
  })
  # v3.3.56: figure_make_cell moved to its Figure module.
  # v3.3.56: figure_reindex_layout moved to its Figure module.
  # v3.3.56: figure_sanitize_layout moved to its Figure module.

  # Initialize/sanitize once graph metadata exists. Layout state, not dynamic
  # input defaults, remains authoritative after this point.
  observe({
    meta <- graph_meta()
    st <- isolate(figure_layout_state())
    first_fill <- !isTRUE(isolate(figure_layout_initialized())) && nrow(meta) > 0
    external_now <- isolate(figure_external_assets())
    st2 <- figure_sanitize_layout(st, meta, auto_fill = first_fill, external_assets = external_now)
    if (!identical(st, st2)) {
      figure_layout_state(st2)
      bump_figure_layout_ui()
    }
    if (first_fill) figure_layout_initialized(TRUE)

    valid_graph_ids <- as.character(meta$id %||% character(0))
    valid_source_ids <- unique(c(valid_graph_ids, names(external_now)))
    drafts <- isolate(figure_override_drafts())
    if (length(drafts)) {
      keep <- intersect(names(drafts), valid_source_ids)
      if (!identical(sort(names(drafts)), sort(keep))) {
        figure_override_drafts(drafts[keep])
      }
    }
    plots <- isolate(figure_loaded_plots())
    if (length(plots)) {
      keep <- intersect(names(plots), valid_graph_ids)
      if (!identical(sort(names(plots)), sort(keep))) figure_loaded_plots(plots[keep])
    }
    exports <- isolate(figure_loaded_exports())
    if (length(exports)) {
      keep <- intersect(names(exports), valid_graph_ids)
      if (!identical(sort(names(exports)), sort(keep))) figure_loaded_exports(exports[keep])
    }
    assets <- isolate(figure_loaded_assets())
    if (length(assets)) {
      keep <- intersect(names(assets), valid_graph_ids)
      if (!identical(sort(names(assets)), sort(keep))) figure_loaded_assets(assets[keep])
    }

    sr <- isolate(figure_selected_row())
    if (sr > length(st2)) figure_selected_row(max(1L, length(st2)))

    # If a Graph used by the Figure is deleted, clear the Inspector selection as
    # well. Keeping a stale selected ID would leave controls visible for a Graph
    # that can no longer be rendered or written back later.
    sel_id <- as.character(isolate(figure_selected_graph() %||% ""))
    if (nzchar(sel_id) && !sel_id %in% valid_source_ids) {
      figure_selected_graph("")
      figure_selected_panel_key("")
    }
  })

  output$figure_layout_editor <- renderUI({
    diag_log("FIGURE-LAYOUT-UI", paste0("render begin version=", isolate(figure_layout_ui_version())))
    # v3.3.48: Figure layout controls are intentionally NOT Shiny input widgets.
    # They are plain HTML controls that send one explicit edit event on commit.
    # figure_layout_state() is the only source of truth. This removes the
    # renderUI -> input initial value -> observer -> state feedback loop that
    # caused width/height values to bounce between the edited and old values.
    figure_layout_ui_version()
    meta <- graph_meta()
    st <- isolate(figure_layout_state())
    if (!length(st)) return(NULL)
    sr <- min(max(1L, isolate(figure_selected_row())), length(st))

    # v3.3.69: when an Auto Graph size field is first nudged with the native
    # number-input spinner, start from the Graph-side panel size instead of
    # the HTML min=80 fallback.
    assets_for_size <- isolate(figure_loaded_assets())
    external_for_size <- isolate(figure_external_assets())
    previews_for_size <- isolate(figure_persisted_previews())
    exports_for_size <- isolate(figure_loaded_exports())
    auto_panel_size_for <- function(id) {
      id <- as.character(id %||% "")
      if (!nzchar(id)) return(list(width = 600, height = 600))
      meta0 <- assets_for_size[[id]]$meta %||% external_for_size[[id]]$meta %||% previews_for_size[[id]]$meta %||% exports_for_size[[id]] %||% list()
      ww <- suppressWarnings(as.numeric(meta0$panel_width %||% meta0$panel_width_px %||% 600)[1])
      hh <- suppressWarnings(as.numeric(meta0$panel_height %||% meta0$panel_height_px %||% 600)[1])
      if (!is.finite(ww) || ww <= 0) ww <- 600
      if (!is.finite(hh) || hh <= 0) hh <- 600
      list(width = ww, height = hh)
    }

    option_tag <- function(value, label, selected = FALSE) {
      tags$option(
        value = as.character(value),
        selected = if (isTRUE(selected)) "selected" else NULL,
        as.character(label)
      )
    }

    used_elsewhere_for <- function(r) {
      used <- unique(unlist(lapply(seq_along(st), function(rr) {
        if (rr == r) return(character(0))
        vapply(st[[rr]]$cells %||% list(), function(cell) as.character(cell$id %||% ""), character(1))
      })))
      used[nzchar(used)]
    }

    selected_row_detail <- function(r) {
      row <- st[[r]]
      used_elsewhere <- used_elsewhere_for(r)
      panel_cards <- lapply(seq_len(row$ncol), function(c) {
        cell <- row$cells[[c]]
        other_same_row <- vapply(seq_len(row$ncol), function(cc) {
          if (cc == c) "" else as.character(row$cells[[cc]]$id %||% "")
        }, character(1))
        unavailable <- unique(c(used_elsewhere, other_same_row[nzchar(other_same_row)]))
        available_graph <- as.character(meta$id[!meta$id %in% unavailable])
        available_asset <- names(external_for_size)
        available <- c(available_graph, available_asset)
        current <- as.character(cell$id %||% "")
        auto_size <- auto_panel_size_for(current)
        if (nzchar(current) && !current %in% available) available <- c(current, available)
        labels <- vapply(available, function(src) {
          if (src %in% meta$id) {
            z <- as.character(meta$name[match(src, meta$id)])
            if (!length(z) || is.na(z) || !nzchar(z)) src else z
          } else if (src %in% names(external_for_size)) {
            paste0("Asset: ", as.character(external_for_size[[src]]$name %||% src))
          } else src
        }, character(1))
        current_label <- if (!nzchar(current)) "空白" else if (current %in% meta$id) {
          z <- as.character(meta$name[match(current, meta$id)])
          if (!length(z) || is.na(z) || !nzchar(z)) current else z
        } else if (current %in% names(external_for_size)) {
          paste0("Asset: ", as.character(external_for_size[[current]]$name %||% current))
        } else current

        option_tags <- c(
          list(option_tag("", "空白", !nzchar(current))),
          lapply(seq_along(available), function(i) {
            option_tag(available[[i]], labels[[i]], identical(available[[i]], current))
          })
        )

        div(
          class = "figure-row-panel-card-compact",
          title = current_label,
          div(class = "figure-row-panel-index", paste0("P", c)),
          div(
            class = "figure-row-panel-graph",
            tags$select(
              class = "form-control input-sm figure-panel-graph-edit",
              `data-row` = r,
              `data-col` = c,
              title = current_label,
              tagList(option_tags)
            )
          ),
          div(
            class = "figure-row-panel-width",
            tags$label(class = "figure-mini-label", "列幅比 (Fixed Canvas)"),
            tags$input(
              type = "number",
              class = "form-control input-sm figure-panel-width-edit",
              `data-row` = r,
              `data-col` = c,
              value = format(cell$width %||% 1, trim = TRUE, scientific = FALSE),
              min = "0.1", max = "10", step = "0.1",
              title = "Fixed Canvas時の列スロット配分比。Graph表示幅とは別です。Autoでは使用しません。"
            )
          ),
          div(
            class = "figure-row-graph-size",
            tags$label(class = "figure-mini-label", "Graph表示幅"),
            tags$input(
              type = "number",
              class = "form-control input-sm figure-graph-width-edit",
              `data-row` = r,
              `data-col` = c,
              `data-auto-value` = format(auto_size$width, trim = TRUE, scientific = FALSE),
              value = if (is.finite(suppressWarnings(as.numeric(cell$graph_width %||% NA_real_)))) format(cell$graph_width, trim = TRUE, scientific = FALSE) else "",
              placeholder = "Auto", min = "80", max = "3000", step = "10",
              title = "Crop前のGraph表示サイズを決める目標幅(px)。Panel/列幅とは別です。空欄は元Graph基準のAuto。"
            )
          ),
          div(
            class = "figure-row-graph-size",
            tags$label(class = "figure-mini-label", "Graph表示高さ"),
            tags$input(
              type = "number",
              class = "form-control input-sm figure-graph-height-edit",
              `data-row` = r,
              `data-col` = c,
              `data-auto-value` = format(auto_size$height, trim = TRUE, scientific = FALSE),
              value = if (is.finite(suppressWarnings(as.numeric(cell$graph_height %||% NA_real_)))) format(cell$graph_height, trim = TRUE, scientific = FALSE) else "",
              placeholder = "Auto", min = "80", max = "3000", step = "10",
              title = "Crop前のGraph表示サイズを決める目標高さ(px)。Panel/行高さとは別です。空欄は元Graph基準のAuto。"
            )
          )
        )
      })

      div(
        class = "figure-selected-row-editor",
        div(
          class = "figure-selected-row-header",
          div(
            class = "figure-row-height-compact",
            tags$label(class = "figure-mini-label", "行高さ比 (Fixed Canvas)"),
            tags$input(
              type = "number",
              class = "form-control input-sm figure-row-height-edit",
              `data-row` = r,
              value = format(row$height %||% 1, trim = TRUE, scientific = FALSE),
              min = "0.1", max = "10", step = "0.1"
            )
          ),
          div(
            class = "figure-row-basis-compact",
            tags$label(class = "figure-mini-label", "サイズ基準"),
            tags$select(
              class = "form-control input-sm figure-row-basis-edit",
              `data-row` = r,
              option_tag("inherit", "Figure設定を継承", identical(as.character(row$size_basis %||% "inherit"), "inherit")),
              option_tag("plot", "Plot領域", identical(as.character(row$size_basis %||% "inherit"), "plot")),
              option_tag("facet", "Facet込み", identical(as.character(row$size_basis %||% "inherit"), "facet")),
              option_tag("axis", "軸ラベル込み", identical(as.character(row$size_basis %||% "inherit"), "axis")),
              option_tag("axis_legend", "軸＋凡例込み", identical(as.character(row$size_basis %||% "inherit"), "axis_legend"))
            )
          ),
          tags$button(type = "button", class = "btn btn-default btn-sm figure-layout-structure-action",
                      `data-figure-layout-action` = "add_panel", `data-row` = r, "+ Panel"),
          tags$button(type = "button", class = "btn btn-default btn-sm figure-layout-structure-action",
                      `data-figure-layout-action` = "remove_panel", `data-row` = r, "− Panel")
        ),
        div(class = "figure-selected-row-panels", panel_cards)
      )
    }

    row_items <- lapply(seq_along(st), function(r) {
      row <- st[[r]]
      selected <- identical(r, sr)
      div(
        class = paste("figure-row-summary", if (selected) "selected" else ""),
        `data-figure-row` = r,
        div(
          class = "figure-row-summary-line",
          div(class = "figure-row-summary-name", paste0("Row ", r)),
          div(class = "figure-row-summary-meta", paste0(row$ncol, " panels")),
          div(class = "figure-row-summary-chevron", if (selected) "▾" else "▸")
        ),
        if (selected) selected_row_detail(r)
      )
    })

    out <- tagList(
      div(class = "figure-row-summary-list", row_items),
      div(
        class = "figure-row-list-actions",
        tags$button(type = "button", class = "btn btn-default btn-sm figure-layout-structure-action",
                    `data-figure-layout-action` = "add_row", "+ Row"),
        tags$button(type = "button", class = "btn btn-default btn-sm figure-layout-structure-action",
                    `data-figure-layout-action` = "remove_row", "− Row")
      )
    )
    diag_log("FIGURE-LAYOUT-UI", paste0("render end rows=", length(st), " selected_row=", sr))
    out
  })
  # Phase 8: keep the Row editor materialized even while the Figure tab is
  # hidden.  The Figure tab can be opened long after Project restore/materialization;
  # suspending this dynamic UI left an empty editor on some browser sessions.
  outputOptions(output, "figure_layout_editor", suspendWhenHidden = FALSE)

  output$figure_reorder_controls <- renderUI({
    st <- figure_layout_state()
    if (!length(st)) return(NULL)
    key <- as.character(figure_selected_panel_key() %||% "")[1]
    id <- figure_layout_source_at_key(st, key)
    slots <- figure_layout_slot_index(st)
    meta <- graph_meta()
    ext <- figure_external_assets()
    label_for <- function(z) {
      sid <- figure_layout_source_at_key(st, z$key)
      nm <- if (!nzchar(sid)) {
        "空白"
      } else if (sid %in% meta$id) {
        x <- as.character(meta$name[match(sid, meta$id)])
        if (length(x) && !is.na(x) && nzchar(x)) x else sid
      } else if (sid %in% names(ext)) {
        paste0("Asset: ", as.character(ext[[sid]]$name %||% sid))
      } else sid
      paste0(z$key, " · ", nm)
    }
    choices <- if (length(slots)) stats::setNames(
      vapply(slots, `[[`, character(1), "key"),
      vapply(slots, label_for, character(1))
    ) else character(0)
    row_mode <- identical(as.character(figure_requested_layout_mode() %||% "row"), "row")

    div(
      class = "figure-layout-reorder-card",
      div(
        class = "figure-layout-reorder-title",
        tags$strong("Graphの並び"),
        tags$span(class="text-muted", if (nzchar(id)) paste0("選択: ", key) else "PreviewでGraphを選択してください")
      ),
      tags$details(
        class="figure-inline-help",
        tags$summary("移動ルール"),
        tags$p(class="help-block", "Panel label・Slot幅・Row構造はその場に残し、Graph/Asset本体とGraph表示サイズを移動します。Crop / free legend / Inset / Figure個別編集はsourceに追従します。")
      ),
      if (!isTRUE(row_mode)) tags$p(class="text-warning", "並び替えはRow layoutで使用します。Free layoutではPanelをドラッグしてください。"),
      div(
        class="figure-layout-reorder-main",
        div(
          class="figure-inline-controls figure-layout-reorder-arrows",
          actionButton("figure_shift_left", "←", class="btn-sm btn-default"),
          actionButton("figure_shift_right", "→", class="btn-sm btn-default"),
          actionButton("figure_shift_up", "↑", class="btn-sm btn-default"),
          actionButton("figure_shift_down", "↓", class="btn-sm btn-default")
        ),
        selectInput("figure_reorder_target", "移動/交換先", choices=choices, selected=if (key %in% unname(choices)) key else "", width="210px", selectize=FALSE),
        div(
          class="figure-inline-controls figure-layout-reorder-actions",
          actionButton("figure_shift_to", "挿入してShift", class="btn-sm btn-default"),
          actionButton("figure_swap_with", "⇄ Swap", class="btn-sm btn-default"),
          actionButton("figure_reorder_undo", "直前を戻す", class="btn-sm btn-default"),
          actionButton("figure_reorder_reset", "並びを初期順へ", class="btn-sm btn-warning")
        )
      ),
      div(
        class="figure-layout-batch-align",
        tags$strong("全Panelの縦配置"),
        selectInput("figure_batch_align_v", NULL, choices=c("上"="top", "中央"="center", "下"="bottom"), selected="top", width="95px"),
        numericInput("figure_batch_top_gutter", "上側余白", value=32, min=0, max=240, step=2, width="95px"),
        actionButton("figure_apply_panel_vertical", "全Panelへ適用", class="btn-sm btn-default"),
        tags$span(class="text-muted", "Fixed Canvasで上側が広い場合は『上 + 32px』を目安にできます。")
      )
    )
  })
  outputOptions(output, "figure_reorder_controls", suspendWhenHidden = FALSE)

  # v3.48: Figure tab activation itself is not a structural layout change.
  # Keep the already-materialized Layout editor DOM untouched on tab reuse.
  # Do not depend on an extra browser probe here; outputOptions(..., suspendWhenHidden = FALSE)
  # keeps the output materialized while hidden.
  observeEvent(input$workspace_main_tab, {
    if (identical(as.character(input$workspace_main_tab %||% ""), "figure_workspace")) {
      diag_log("FIGURE-LAYOUT-UI", "Figure tab activated; reuse existing layout DOM; render skipped")
    }
  }, ignoreInit = TRUE)

  observeEvent(input$figure_interaction_ready, {
    diag_log("FIGURE-JS", "stable inline interaction bridge ready")
  }, ignoreInit = TRUE)

  observeEvent(input$figure_row_clicked, {
    if (project_load_action_blocked("figure-row-click")) return()
    r <- suppressWarnings(as.integer(input$figure_row_clicked$row %||% NA_integer_))
    diag_log("FIGURE-EDIT", paste0("row_click row=", as.character(r)))
    st <- isolate(figure_layout_state())
    if (is.finite(r) && r >= 1L && r <= length(st) && !identical(r, isolate(figure_selected_row()))) {
      figure_selected_row(r)
      bump_figure_layout_ui()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$figure_add_row, {
    if (project_load_action_blocked("figure-add-row")) return()
    st <- isolate(figure_layout_state())
    if (length(st) >= 6L) return()
    r <- length(st) + 1L
    st[[r]] <- list(row = r, height = 1, ncol = 2L, size_basis = "inherit",
                    cells = list(figure_make_cell(r, 1), figure_make_cell(r, 2)))
    figure_layout_state(figure_reindex_layout(st))
    figure_selected_row(r)
    bump_figure_layout_ui()
  }, ignoreInit = TRUE)

  observeEvent(input$figure_remove_row, {
    if (project_load_action_blocked("figure-remove-row")) return()
    st <- isolate(figure_layout_state())
    if (length(st) <= 1L) return()
    r <- min(max(1L, isolate(figure_selected_row())), length(st))
    st <- st[-r]
    figure_layout_state(figure_reindex_layout(st))
    figure_selected_row(min(r, length(st)))
    bump_figure_layout_ui()
  }, ignoreInit = TRUE)

  observeEvent(input$figure_add_panel, {
    if (project_load_action_blocked("figure-add-panel")) return()
    st <- isolate(figure_layout_state())
    if (!length(st)) return()
    r <- min(max(1L, isolate(figure_selected_row())), length(st))
    if (st[[r]]$ncol >= 6L) return()
    st[[r]]$ncol <- st[[r]]$ncol + 1L
    st[[r]]$cells[[st[[r]]$ncol]] <- figure_make_cell(r, st[[r]]$ncol)
    figure_layout_state(figure_reindex_layout(st))
    bump_figure_layout_ui()
  }, ignoreInit = TRUE)

  observeEvent(input$figure_remove_panel, {
    if (project_load_action_blocked("figure-remove-panel")) return()
    st <- isolate(figure_layout_state())
    if (!length(st)) return()
    r <- min(max(1L, isolate(figure_selected_row())), length(st))
    if (st[[r]]$ncol <= 1L) return()
    st[[r]]$ncol <- st[[r]]$ncol - 1L
    st[[r]]$cells <- st[[r]]$cells[seq_len(st[[r]]$ncol)]
    figure_layout_state(figure_reindex_layout(st))
    bump_figure_layout_ui()
  }, ignoreInit = TRUE)

  # All Row/Panel edits arrive through a single explicit event. Numeric edits do
  # not rebuild the layout editor; graph assignment does, because the choices in
  # sibling selectors depend on which Graphs are already used.
  observeEvent(input$figure_layout_edit, {
    if (project_load_action_blocked("figure-layout-edit")) return()
    e <- input$figure_layout_edit
    st <- isolate(figure_layout_state())
    typ0 <- as.character(e$type %||% "")[1]

    # Phase 9: structural Row/Panel controls are plain HTML buttons routed
    # through this same explicit event channel.  Keeping them out of dynamic
    # actionButton() binding avoids restore/re-render input lifecycle loss.
    if (typ0 %in% c("add_row", "remove_row", "add_panel", "remove_panel")) {
      changed0 <- FALSE
      if (identical(typ0, "add_row")) {
        if (length(st) < 6L) {
          r0 <- length(st) + 1L
          st[[r0]] <- list(row = r0, height = 1, ncol = 2L, size_basis = "inherit",
                           cells = list(figure_make_cell(r0, 1), figure_make_cell(r0, 2)))
          st <- figure_reindex_layout(st)
          figure_layout_state(st)
          figure_selected_row(r0)
          changed0 <- TRUE
        }
      } else if (identical(typ0, "remove_row")) {
        if (length(st) > 1L) {
          r0 <- suppressWarnings(as.integer(e$row %||% isolate(figure_selected_row())))
          if (!is.finite(r0) || r0 < 1L || r0 > length(st)) r0 <- min(max(1L, isolate(figure_selected_row())), length(st))
          st <- st[-r0]
          st <- figure_reindex_layout(st)
          figure_layout_state(st)
          figure_selected_row(min(r0, length(st)))
          changed0 <- TRUE
        }
      } else {
        r0 <- suppressWarnings(as.integer(e$row %||% isolate(figure_selected_row())))
        if (!is.finite(r0) || r0 < 1L || r0 > length(st)) r0 <- min(max(1L, isolate(figure_selected_row())), length(st))
        if (identical(typ0, "add_panel") && st[[r0]]$ncol < 6L) {
          st[[r0]]$ncol <- st[[r0]]$ncol + 1L
          st[[r0]]$cells[[st[[r0]]$ncol]] <- figure_make_cell(r0, st[[r0]]$ncol)
          figure_layout_state(figure_reindex_layout(st))
          figure_selected_row(r0)
          changed0 <- TRUE
        } else if (identical(typ0, "remove_panel") && st[[r0]]$ncol > 1L) {
          st[[r0]]$ncol <- st[[r0]]$ncol - 1L
          st[[r0]]$cells <- st[[r0]]$cells[seq_len(st[[r0]]$ncol)]
          figure_layout_state(figure_reindex_layout(st))
          figure_selected_row(r0)
          changed0 <- TRUE
        }
      }
      diag_log("FIGURE-EDIT", paste0("structure type=", typ0,
                                      " changed=", changed0,
                                      " rows=", length(isolate(figure_layout_state())),
                                      " selected_row=", isolate(figure_selected_row())))
      if (isTRUE(changed0)) {
        figure_gc_unreferenced_sources(reason = paste0("structure-", typ0))
        bump_figure_layout_ui()
      }
      return()
    }

    meta <- isolate(graph_meta())
    old_refs <- figure_referenced_graph_ids(layout = st)
    tr <- figure_apply_layout_edit_state(
      st, e,
      valid_graph_ids = as.character(meta$id),
      valid_asset_ids = names(isolate(figure_external_assets()))
    )
    diag_log(
      "FIGURE-EDIT",
      paste0("layout type=", as.character(e$type %||% ""),
             " row=", as.character(e$row %||% ""),
             " col=", as.character(e$col %||% ""),
             " changed=", isTRUE(tr$changed),
             " rebuild_ui=", isTRUE(tr$rebuild_ui))
    )
    if (isTRUE(tr$changed)) {
      figure_layout_state(tr$state)
      if (identical(as.character(e$type %||% ""), "panel_graph")) {
        rid <- suppressWarnings(as.integer(e$row %||% NA_integer_))
        cid <- suppressWarnings(as.integer(e$col %||% NA_integer_))
        src <- ""
        if (is.finite(rid) && rid >= 1L && rid <= length(tr$state)) {
          cells <- tr$state[[rid]]$cells %||% list()
          if (is.finite(cid) && cid >= 1L && cid <= length(cells)) {
            src <- as.character(cells[[cid]]$id %||% "")
          }
        }
        key <- if (is.finite(rid) && is.finite(cid)) paste0("r", rid, "_c", cid) else ""
        fresh_assignment <- nzchar(src) && src %in% meta$id && !src %in% old_refs
        diag_log(
          "FIGURE-SOURCE",
          paste0("row=", rid, " col=", cid, " key=", key, " source=", src,
                 " fresh_import=", fresh_assignment),
          id = src
        )
        figure_selected_panel_key(key)
        figure_selected_graph(src)

        if (isTRUE(fresh_assignment)) {
          # A Graph with zero previous Figure references owns no Figure cache.
          # Clear any historical/stale snapshot before treating this assignment
          # as a new import from the current Graph.
          figure_evict_source_state(src, reason = "new-assignment-reset")
          figure_mark_new_import(src)

          request_figure_source_snapshot(
            src, reason = "figure-assignment", import_editor_state = TRUE
          )
          diag_log("FIGURE-SOURCE-SYNC", "new assignment queued for direct GraphState snapshot", id = src)
        } else if (nzchar(src) && src %in% meta$id) {
          # Existing Figure ownership is a snapshot. Selecting/reassigning the
          # same source is not permission to refresh it from Graph.
          diag_log("FIGURE-SOURCE-SYNC", "existing Figure snapshot retained; no source refresh", id = src)
        }
      }
      figure_gc_unreferenced_sources(reason = "panel-graph-change")
      if (isTRUE(tr$rebuild_ui)) bump_figure_layout_ui()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$figure_free_panel_event, {
    if (project_load_action_blocked("figure-free-panel-drag")) return()
    e <- input$figure_free_panel_event
    if (!identical(isolate(figure_requested_layout_mode()), "free")) return()
    st <- isolate(figure_layout_state())
    # F1-2b: browser resize dimensions are the visible (cropped) footprint.
    # Store the uncropped source box so applying Crop on the next render does
    # not shrink the Panel a second time. Move events need no conversion.
    if (identical(as.character(e$type %||% ""), "panel_resize")) {
      rr <- suppressWarnings(as.integer(e$row %||% NA_integer_))
      cc <- suppressWarnings(as.integer(e$col %||% NA_integer_))
      if (is.finite(rr) && is.finite(cc) && rr >= 1L && rr <= length(st) &&
          cc >= 1L && cc <= length(st[[rr]]$cells %||% list())) {
        cell <- st[[rr]]$cells[[cc]]
        id <- as.character(cell$id %||% "")
        ov <- figure_apply_slot_label_to_override(
          figure_override_for(id, isolate(figure_requested_overrides())), cell
        )
        cr <- figure_crop_fractions(ov)
        if (isTRUE(cr$enabled)) {
          ew <- suppressWarnings(as.numeric(e$width %||% NA_real_)[1])
          eh <- suppressWarnings(as.numeric(e$height %||% NA_real_)[1])
          band <- max(0, figure_label_band(ov))
          if (is.finite(ew) && ew > 0) e$width <- ew / max(0.05, cr$width_frac)
          if (is.finite(eh) && eh > 0) {
            e$height <- band + max(1, eh - band) / max(0.05, cr$height_frac)
          }
        }
      }
    }
    tr <- figure_apply_free_panel_drag_state(st, e)
    if (isTRUE(tr$changed)) {
      figure_layout_state(figure_reindex_layout(tr$state))
      diag_log("FIGURE-FREE-EDIT", paste0(
        "type=", as.character(e$type %||% ""),
        " row=", as.character(e$row %||% ""), " col=", as.character(e$col %||% ""),
        " x=", as.character(e$x %||% ""), " y=", as.character(e$y %||% ""),
        " w=", as.character(e$width %||% ""), " h=", as.character(e$height %||% "")
      ))
    }
  }, ignoreInit = TRUE)

  # v3.73.1.6: deterministic Row/Grid reorder transaction. Slot-owned
  # presentation stays put; source-owned content follows the Graph/Asset.
  # Every transaction is validated before commit, then selection/Inspector/
  # browser highlight follow the moved source to its destination slot.
  figure_source_map <- function(st) {
    st <- figure_reindex_layout(st)
    slots <- figure_layout_slot_index(st)
    out <- vapply(slots, function(z) figure_layout_source_at_key(st, z$key), character(1))
    stats::setNames(out, vapply(slots, `[[`, character(1), "key"))
  }

  send_figure_browser_selection <- function(key) {
    session$sendCustomMessage("figure-select-panel", list(key=as.character(key %||% "")))
    invisible(NULL)
  }

  verify_figure_reorder_after_flush <- function(expected_state, expected_key, expected_id, action) {
    expected_map <- figure_source_map(expected_state)
    session$onFlushed(function() {
      live_state <- isolate(figure_layout_state())
      req_state <- isolate(figure_requested_layout())
      live_ok <- identical(figure_source_map(live_state), expected_map)
      requested_ok <- identical(figure_source_map(req_state), expected_map)
      sel_key_ok <- identical(as.character(isolate(figure_selected_panel_key()) %||% ""), as.character(expected_key %||% ""))
      sel_id_ok <- identical(as.character(isolate(figure_selected_graph()) %||% ""), as.character(expected_id %||% ""))
      diag_log("FIGURE-REORDER-VERIFY", paste0(
        "action=", action,
        " layout=", live_ok,
        " requested=", requested_ok,
        " selected_key=", sel_key_ok,
        " selected_source=", sel_id_ok
      ), id=if (nzchar(expected_id)) expected_id else NULL)
      send_figure_browser_selection(expected_key)
    }, once=TRUE)
    invisible(NULL)
  }

  commit_figure_reorder <- function(tr, action = "reorder") {
    if (!isTRUE(tr$changed)) {
      validation <- tr$validation %||% list(ok=TRUE, reason="unchanged")
      if (!isTRUE(validation$ok)) {
        diag_log("FIGURE-REORDER-GUARD", paste0("action=", action, " rejected reason=", validation$reason %||% "unknown"))
        showNotification("並び替えの整合性検査に失敗したため変更しませんでした。", type="error", duration=4)
      }
      return(FALSE)
    }
    old <- isolate(figure_layout_state())
    validation <- tr$validation %||% figure_validate_reorder_state(old, tr$state)
    if (!isTRUE(validation$ok)) {
      diag_log("FIGURE-REORDER-GUARD", paste0("action=", action, " rejected reason=", validation$reason %||% "unknown"))
      showNotification("並び替えの整合性検査に失敗したため変更しませんでした。", type="error", duration=4)
      return(FALSE)
    }

    old_key <- as.character(isolate(figure_selected_panel_key() %||% ""))
    old_id <- as.character(isolate(figure_selected_graph() %||% ""))
    if (!nzchar(old_id)) old_id <- figure_layout_source_at_key(old, old_key)
    old_row <- suppressWarnings(as.integer(isolate(figure_selected_row()) %||% 1L)[1])
    new_state <- figure_reindex_layout(tr$state)
    new_key <- if (nzchar(old_id)) figure_layout_key_for_source(new_state, old_id) else ""
    if (!nzchar(new_key)) new_key <- as.character(tr$to %||% old_key)
    new_id <- figure_layout_source_at_key(new_state, new_key)
    pos <- figure_layout_key_position(new_state, new_key)
    new_row <- if (is.finite(pos$row)) as.integer(pos$row) else old_row

    figure_reorder_undo(list(
      layout=old, selected_key=old_key, selected_graph=old_id, selected_row=old_row, action=action
    ))
    figure_layout_state(new_state)
    figure_selected_panel_key(new_key)
    figure_selected_graph(new_id)
    figure_selected_row(max(1L, new_row))
    sync_figure_inspector()
    bump_figure_layout_ui()
    diag_log("FIGURE-REORDER", paste0(
      "action=", action,
      " from=", tr$from %||% "",
      " to=", tr$to %||% "",
      " follow_source=", old_id,
      " selected_key=", new_key,
      " validation=", validation$reason %||% "ok"
    ), id=if (nzchar(new_id)) new_id else NULL)
    verify_figure_reorder_after_flush(new_state, new_key, new_id, action)
    TRUE
  }

  do_figure_adjacent_shift <- function(direction) {
    if (project_load_action_blocked("figure-reorder-adjacent")) return(invisible(FALSE))
    if (!identical(isolate(figure_requested_layout_mode()), "row")) {
      showNotification("ShiftはRow/Grid modeで使用してください。Free modeではドラッグ移動します。", type="warning")
      return(invisible(FALSE))
    }
    key <- as.character(isolate(figure_selected_panel_key() %||% ""))
    if (!nzchar(key)) return(invisible(FALSE))
    tr <- figure_shift_adjacent_state(isolate(figure_layout_state()), key, direction)
    commit_figure_reorder(tr, paste0("adjacent-", direction))
  }
  observeEvent(input$figure_shift_left,  do_figure_adjacent_shift("left"),  ignoreInit=TRUE)
  observeEvent(input$figure_shift_right, do_figure_adjacent_shift("right"), ignoreInit=TRUE)
  observeEvent(input$figure_shift_up,    do_figure_adjacent_shift("up"),    ignoreInit=TRUE)
  observeEvent(input$figure_shift_down,  do_figure_adjacent_shift("down"),  ignoreInit=TRUE)

  observeEvent(input$figure_swap_with, {
    if (project_load_action_blocked("figure-swap")) return()
    if (!identical(isolate(figure_requested_layout_mode()), "row")) return()
    from <- as.character(isolate(figure_selected_panel_key() %||% ""))
    to <- as.character(isolate(input$figure_reorder_target %||% ""))
    tr <- figure_reorder_content_state(isolate(figure_layout_state()), from, to, mode="swap")
    commit_figure_reorder(tr, "swap")
  }, ignoreInit=TRUE)

  observeEvent(input$figure_shift_to, {
    if (project_load_action_blocked("figure-shift-to")) return()
    if (!identical(isolate(figure_requested_layout_mode()), "row")) return()
    from <- as.character(isolate(figure_selected_panel_key() %||% ""))
    to <- as.character(isolate(input$figure_reorder_target %||% ""))
    tr <- figure_reorder_content_state(isolate(figure_layout_state()), from, to, mode="shift")
    commit_figure_reorder(tr, "shift-insert")
  }, ignoreInit=TRUE)

  observeEvent(input$figure_reorder_reset, {
    if (project_load_action_blocked("figure-reorder-reset")) return()
    if (!identical(isolate(figure_requested_layout_mode()), "row")) return()
    meta <- isolate(graph_meta())
    ext <- isolate(figure_external_assets())
    source_order <- c(as.character(meta$id %||% character(0)), names(ext))
    tr <- figure_reset_content_order_state(isolate(figure_layout_state()), source_order)
    if (!isTRUE(tr$changed) && isTRUE((tr$validation %||% list(ok=TRUE))$ok)) {
      showNotification("Graph/Assetの並びはすでに初期順です。", type="message", duration=2)
      return()
    }
    if (commit_figure_reorder(tr, "reset-graph-order")) {
      showNotification("Graph/Assetを元のGraph順へ並べ直しました。", type="message", duration=2)
    }
  }, ignoreInit=TRUE)

  observeEvent(input$figure_reorder_undo, {
    prev <- isolate(figure_reorder_undo())
    if (is.null(prev) || !is.list(prev$layout)) {
      showNotification("戻せる並べ替えはありません。", type="message", duration=2)
      return()
    }
    restored <- figure_reindex_layout(prev$layout)
    key <- as.character(prev$selected_key %||% "")
    id <- as.character(prev$selected_graph %||% figure_layout_source_at_key(restored, key))
    row <- suppressWarnings(as.integer(prev$selected_row %||% figure_layout_key_position(restored, key)$row %||% 1L)[1])
    if (!is.finite(row) || row < 1L) row <- 1L
    figure_layout_state(restored)
    figure_selected_panel_key(key)
    figure_selected_graph(id)
    figure_selected_row(row)
    figure_reorder_undo(NULL)
    sync_figure_inspector()
    bump_figure_layout_ui()
    diag_log("FIGURE-REORDER", paste0("action=undo previous=", prev$action %||% "", " selected_key=", key), id=if (nzchar(id)) id else NULL)
    verify_figure_reorder_after_flush(restored, key, id, "undo")
  }, ignoreInit=TRUE)

  observeEvent(input$figure_position_reset, {
    if (project_load_action_blocked("figure-position-reset")) return()
    key <- as.character(isolate(figure_selected_panel_key()) %||% "")[1]
    id <- as.character(isolate(figure_selected_graph()) %||% "")[1]
    if (!nzchar(key) || !nzchar(id)) {
      showNotification("PreviewでPanelを選択してください。", type="message", duration=2)
      return()
    }

    st <- isolate(figure_layout_state())
    pos <- figure_layout_key_position(st, key)
    if (!is.finite(pos$row) || !is.finite(pos$col) ||
        pos$row < 1L || pos$row > length(st) ||
        pos$col < 1L || pos$col > length(st[[pos$row]]$cells %||% list())) return()

    old_cell <- st[[pos$row]]$cells[[pos$col]]
    new_cell <- figure_reset_slot_free_positions(old_cell)
    st[[pos$row]]$cells[[pos$col]] <- new_cell

    drafts <- isolate(figure_override_drafts())
    old_ov <- drafts[[id]] %||% isolate(figure_requested_overrides())[[id]] %||% figure_default_override(id)
    new_ov <- figure_reset_override_free_positions(old_ov)
    drafts[[id]] <- figure_strip_slot_label_fields_from_override(new_ov)

    slot_changed <- !isTRUE(all.equal(old_cell, new_cell, check.attributes=FALSE))
    ov_changed <- !isTRUE(all.equal(old_ov, new_ov, check.attributes=FALSE))
    if (!slot_changed && !ov_changed) {
      showNotification("自由配置はすでに初期位置です。", type="message", duration=2)
      return()
    }

    if (slot_changed) figure_layout_state(figure_reindex_layout(st))
    if (ov_changed) {
      cls <- figure_override_change_class(old_ov, new_ov)
      figure_override_drafts(drafts)
      figure_requested_overrides(
        if (exists("figure_visible_requested_overrides", mode = "function", inherits = TRUE)) {
          figure_visible_requested_overrides(drafts)
        } else drafts
      )
      if (cls %in% c("GRAPH_GEOMETRY", "FIGURE_GEOMETRY")) {
        figure_geometry_revision(as.integer(isolate(figure_geometry_revision()) %||% 0L) + 1L)
      }
    }
    bump_figure_panel_display_revision(id)
    sync_figure_inspector()
    diag_log("FIGURE-POSITION-RESET", paste0(
      "key=", key,
      " slot=", slot_changed,
      " override=", ov_changed,
      " legend_free_auto=", isTRUE(new_ov$legend_free_auto)
    ), id=id)
    showNotification("選択Panelの自由配置位置を初期化しました。", type="message", duration=2)
  }, ignoreInit=TRUE)

  observeEvent(input$figure_apply_panel_vertical, {
    if (project_load_action_blocked("figure-batch-vertical")) return()
    mode <- as.character(isolate(input$figure_batch_align_v %||% "top"))[1]
    if (!mode %in% c("top", "center", "bottom")) mode <- "top"
    gutter <- suppressWarnings(as.numeric(isolate(input$figure_batch_top_gutter %||% 32))[1])
    if (!is.finite(gutter)) gutter <- 32
    gutter <- min(max(gutter, 0), 240)
    st <- isolate(figure_layout_state())
    drafts <- isolate(figure_override_drafts())
    requested <- isolate(figure_requested_overrides())
    touched <- character(0)
    for (r in seq_along(st)) for (c in seq_along(st[[r]]$cells %||% list())) {
      cell <- st[[r]]$cells[[c]]
      cell$top_gutter <- gutter
      st[[r]]$cells[[c]] <- cell
      id <- as.character(cell$id %||% "")[1]
      if (!nzchar(id)) next
      ov <- drafts[[id]] %||% requested[[id]] %||% figure_default_override(id)
      ov$align_v <- mode
      drafts[[id]] <- figure_strip_slot_label_fields_from_override(ov)
      touched <- c(touched, id)
    }
    figure_layout_state(figure_reindex_layout(st))
    figure_override_drafts(drafts)
    for (id in unique(touched)) bump_figure_panel_display_revision(id)
    figure_geometry_revision(as.integer(isolate(figure_geometry_revision()) %||% 0L) + 1L)
    sync_figure_inspector()
    bump_figure_layout_ui()
    diag_log("FIGURE-BATCH-ALIGN", paste0("vertical=", mode, " top_gutter=", gutter, " sources=", length(unique(touched))))
    showNotification("全Panelの縦配置と上側余白を更新しました。", type="message", duration=2)
  }, ignoreInit=TRUE)

  output$figure_selected_panel_header <- renderUI({
    gm <- graph_meta()
    ext <- figure_external_assets()
    if (length(ext)) {
      em <- data.frame(
        id = names(ext),
        name = vapply(ext, function(z) paste0("Asset: ", as.character(z$name %||% z$asset_id)), character(1)),
        stringsAsFactors = FALSE
      )
      gm <- rbind(gm[, intersect(c("id","name"), names(gm)), drop=FALSE], em)
    }
    figureSelectedPanelHeaderUI(figure_selected_graph(), figure_selected_panel_key(), gm)
  })
  # v3.3.56: figure_default_override moved to its Figure module.

  observeEvent(figure_selected_graph(), {
    # Dynamic Inspector follows selection, but v3.60.0 deliberately does NOT
    # change Figure Graph-editor ownership. Viewing/selecting a panel is light.
    sync_figure_inspector()
    id <- as.character(figure_selected_graph() %||% "")[1]
    editing_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    if (nzchar(id)) {
      diag_log(
        "FIGURE-EDITOR-SHELL",
        paste0("selected-only editing=", if (nzchar(editing_id)) editing_id else "<none>"),
        id = id
      )
    }
  }, ignoreInit = FALSE)

  observeEvent(input$workspace_main_tab, {
    if (!identical(as.character(input$workspace_main_tab %||% "")[1], "figure_workspace")) return()
    id <- as.character(isolate(figure_selected_graph()) %||% "")[1]
    editing_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    diag_log(
      "FIGURE-EDITOR-SHELL",
      paste0("Figure tab browse-only selected=", if (nzchar(id)) id else "<none>",
             " editing=", if (nzchar(editing_id)) editing_id else "<none>"),
      id = if (nzchar(id)) id else NULL
    )
  }, ignoreInit = TRUE)

  # Figure source generation computes a snapshot directly from saved values.
  # Status reporting therefore follows Figure-owned snapshot jobs rather than
  # legacy per-Graph materialization/restore modules.
  figure_source_load_status <- function(ids, label) {
    figure_source_snapshot_generation()
    pending <- ids[vapply(ids, function(id) isTRUE(figure_source_snapshot_pending(id)), logical(1))]
    if (!length(pending)) return("")
    paste0(label, "中… 対象: ", paste(pending, collapse = ", "))
  }

  figure_explicit_load_status <- function(selected_id = NULL) {
    messages <- character(0)
    target <- figure_panel_refresh_target()
    id <- as.character(target$id %||% "")[1]
    if (nzchar(id) && (is.null(selected_id) || identical(selected_id, id))) {
      messages <- c(messages, figure_source_load_status(id, "Graphから再読込"))
    }
    if (isTRUE(figure_load_pending())) {
      ids <- figure_load_target_ids()
      if (length(ids) && (is.null(selected_id) || selected_id %in% ids)) {
        # Editor status only reports its selected Graph; Preview reports all targets.
        check_ids <- if (is.null(selected_id)) ids else selected_id
        messages <- c(messages, paste0(
          figure_source_load_status(check_ids, "全GraphをFigureへ読込"),
          " [cache miss処理済み ", length(setdiff(ids, figure_queue())), " / ", length(ids), "]"
        ))
      }
    }
    paste(messages, collapse = " | ")
  }

  # Keep the existing Progress object truthful on restore failure, without
  # closing it or changing queue/pending/retry semantics.
  observe({
    if (!isTRUE(figure_load_pending())) return()
    ids <- figure_load_target_ids()
    if (!length(ids)) return()
    status <- figure_source_load_status(ids, "Figure用Graph読込")
    prog <- isolate(figure_load_progress())
    if (!is.null(prog) && nzchar(status)) try(prog$set(message = status), silent = TRUE)
  })

  output$figure_graph_editor_status <- renderText({
    selected_id <- as.character(figure_selected_graph() %||% "")[1]
    editing_id <- as.character(figure_editing_graph() %||% "")[1]
    figure_single_editor_loading()
    figure_editor_mount_generation()
    figure_editor_epoch()
    if (!nzchar(selected_id)) return("Panelを選択してください。Graph Editorは明示的に『このPanelを編集』した時だけ読み込みます。")
    if (selected_id %in% names(figure_external_assets())) return("外部AssetにはGraph Editorはありません。")
    operation <- figure_explicit_load_status(selected_id)
    if (nzchar(operation)) return(operation)
    states <- figure_edit_states()
    if (!is.list(states[[selected_id]])) {
      return("編集可能snapshotがありません。『Graphから再読込』で現在のGraphから作成してください。")
    }
    if (!nzchar(editing_id)) return(paste0("選択中: ", selected_id, " / Editor未起動"))
    mod <- figure_editor_module(editing_id)
    err <- if (!is.null(mod) && is.function(mod$replay_error)) {
      tryCatch(mod$replay_error(), error = function(e) NULL)
    } else NULL
    if (!is.null(err)) return(paste0("Figure Graph Editorの値反映失敗（", editing_id, "）：", err))
    if (isTRUE(figure_single_editor_loading())) {
      return(paste0("選択中: ", selected_id, " / 編集準備中: ", editing_id))
    }
    ready <- !is.null(mod) && isTRUE(tryCatch(mod$ready(), error=function(e) FALSE))
    if (identical(selected_id, editing_id)) {
      if (ready) "このPanelのFigure専用snapshotを編集中（元Graphは変更されません）" else "Figure専用Graph Editorを準備中…"
    } else {
      paste0("選択中: ", selected_id, " / 編集中: ", editing_id, "（選択だけではEditorは切り替わりません）")
    }
  })

  # Transient presentation state, deliberately excluded from GraphState/project save.
  figure_inspector_folds <- reactiveVal(list())
  observeEvent(input$figure_inspector_fold, {
    event <- input$figure_inspector_fold
    keys <- c("label", "crop", "alignment", "legend", "inset")
    if (!is.list(event) || !is.character(event$key) || length(event$key) != 1L ||
        !event$key %in% keys || !is.logical(event$collapsed) || length(event$collapsed) != 1L ||
        is.na(event$collapsed)) return()
    folds <- isolate(figure_inspector_folds())
    folds[[event$key]] <- event$collapsed
    figure_inspector_folds(folds)
  }, ignoreInit = TRUE, priority = 100)

  build_figure_override_ui <- function(section = c("panel", "overlay")) {
    section <- match.arg(section)
    figure_inspector_ui_revision()
    id <- figure_selected_graph()
    if (!nzchar(id)) return(NULL)
    drafts <- isolate(figure_override_drafts())
    requested <- isolate(figure_requested_overrides())
    ov <- drafts[[id]] %||% requested[[id]] %||% figure_default_override(id)
    key <- as.character(isolate(figure_selected_panel_key() %||% ""))
    st_now <- isolate(figure_layout_state())
    if (nzchar(key)) {
      for (row in st_now) for (cell in row$cells %||% list()) {
        if (identical(as.character(cell$key %||% ""), key)) {
          ov <- figure_apply_slot_label_to_override(ov, cell)
        }
      }
    }
    meta <- isolate(graph_meta())
    graph_choices <- stats::setNames(as.character(meta$id), paste0("Graph: ", as.character(meta$name)))
    ext <- isolate(figure_external_assets())
    asset_choices <- if (length(ext)) stats::setNames(names(ext), vapply(ext, figure_asset_display_name, character(1))) else character(0)
    is_external <- id %in% names(ext)
    figureOverrideDetailUI(
      id, ov, source_choices = c(graph_choices, asset_choices),
      is_external = is_external, asset_info = if (is_external) ext[[id]] else NULL,
      sync_generation = isolate(figure_inspector_sync_generation()),
      section = section, fold_state = isolate(figure_inspector_folds())
    )
  }

  output$figure_panel_detail <- renderUI({
    build_figure_override_ui("panel")
  })

  output$figure_overlay_detail <- renderUI({
    build_figure_override_ui("overlay")
  })

  send_figure_label_overlay_update <- function(id, ov) {
    if (!nzchar(as.character(id %||% "")) || is.null(ov)) return(invisible(NULL))
    session$sendCustomMessage(
      "figure-label-overlay-update",
      list(
        id = as.character(id),
        text = as.character(ov$panel_label %||% ""),
        size = as.numeric(ov$label_size %||% 18),
        mode = as.character(ov$label_mode %||% "align"),
        anchor = as.character(ov$label_anchor %||% "plot_axis"),
        xOffset = as.numeric(ov$label_x_offset %||% 0),
        yOffset = as.numeric(ov$label_y_offset %||% 0),
        x = as.numeric(ov$label_x %||% 0.06),
        y = as.numeric(ov$label_y %||% 0.02),
        topGutter = as.numeric(ov$top_gutter %||% 48)
      )
    )
    invisible(NULL)
  }

  capture_current_figure_override <- function(legend_position_input = "none", inset_geometry_input = "none") {
    if (isTRUE(isolate(figure_drag_syncing())) || isTRUE(isolate(figure_inspector_syncing()))) {
      return(invisible(NULL))
    }
    id <- as.character(isolate(figure_selected_graph() %||% ""))
    bound_id <- as.character(isolate(input$figure_inspector_graph_id %||% ""))
    bound_gen <- suppressWarnings(as.integer(isolate(input$figure_inspector_sync_generation))[1])
    current_gen <- isolate(figure_inspector_sync_generation())
    if (length(bound_gen) != 1L || !is.finite(bound_gen) || !identical(as.integer(bound_gen), as.integer(current_gen))) return(invisible(NULL))
    meta <- isolate(graph_meta())
    valid_sources <- c(as.character(meta$id), names(isolate(figure_external_assets())))
    if (!nzchar(id) || !identical(bound_id, id) || !id %in% valid_sources) return(invisible(NULL))

    label_size <- suppressWarnings(as.numeric(isolate(input$figure_panel_label_size %||% 18)))
    if (!is.finite(label_size)) label_size <- 18
    label_size <- min(max(label_size, 6), 72)
    top_gutter <- suppressWarnings(as.numeric(isolate(input$figure_top_gutter %||% 48)))
    if (!is.finite(top_gutter)) top_gutter <- 48
    top_gutter <- min(max(top_gutter, 0), 240)
    label_mode <- as.character(isolate(input$figure_label_mode %||% "align"))
    if (!label_mode %in% c("align", "free")) label_mode <- "align"
    label_anchor <- as.character(isolate(input$figure_label_anchor %||% "plot_axis"))
    if (!label_anchor %in% c("plot_axis", "plot_left", "cell_left")) label_anchor <- "plot_axis"
    label_x_offset <- suppressWarnings(as.numeric(isolate(input$figure_label_x_offset %||% 0)))
    if (!is.finite(label_x_offset)) label_x_offset <- 0
    label_x_offset <- min(max(label_x_offset, -300), 300)
    label_y_offset <- suppressWarnings(as.numeric(isolate(input$figure_label_y_offset %||% 0)))
    if (!is.finite(label_y_offset)) label_y_offset <- 0
    label_y_offset <- min(max(label_y_offset, -300), 300)
    label_x <- suppressWarnings(as.numeric(isolate(input$figure_label_x %||% 0.06)))
    if (!is.finite(label_x)) label_x <- 0.06
    label_x <- min(max(label_x, -0.2), 1.2)
    label_y <- suppressWarnings(as.numeric(isolate(input$figure_label_y %||% 0.02)))
    if (!is.finite(label_y)) label_y <- 0.02
    label_y <- min(max(label_y, -0.2), 1.2)
    legend <- as.character(isolate(input$figure_legend_override %||% "inherit"))
    if (!legend %in% c("inherit", "none", "right", "left", "top", "bottom", "free")) legend <- "inherit"
    legend_title <- figure_normalize_legend_title_mode(isolate(input$figure_legend_title %||% "inherit"))
    legend_background <- as.character(isolate(input$figure_legend_background %||% "transparent"))[1]
    if (!legend_background %in% c("transparent", "white")) legend_background <- "transparent"
    legend_gap <- suppressWarnings(as.numeric(isolate(input$figure_legend_gap %||% 8)))
    if (!is.finite(legend_gap)) legend_gap <- 8
    legend_gap <- min(max(legend_gap, 0), 100)
    # F1-4e: legend placement is canonical in the draft, not in the Inspector
    # input echo. Direct drag updates the draft immediately and mirrors the
    # visible numeric fields client-side without sending another Shiny input.
    # This prevents a post-drop input echo from re-entering this observer and
    # causing a redundant STYLE_ONLY / FIGURE_GEOMETRY redraw.
    raw_old_for_position <- isolate(figure_override_drafts())[[id]] %||% figure_default_override(id)
    old_for_position <- figure_override_for(id, setNames(list(raw_old_for_position), id))
    detached_now <- identical(legend, "free")
    if (detached_now) {
      legend_x <- suppressWarnings(as.numeric(old_for_position$legend_free_x %||% old_for_position$legend_x %||% 0.72)[1])
      legend_y <- suppressWarnings(as.numeric(old_for_position$legend_free_y %||% old_for_position$legend_y %||% 0.08)[1])
    } else {
      legend_x <- suppressWarnings(as.numeric(old_for_position$legend_x %||% 0.72)[1])
      legend_y <- suppressWarnings(as.numeric(old_for_position$legend_y %||% 0.08)[1])
    }
    if (!is.finite(legend_x)) legend_x <- 0.72
    if (!is.finite(legend_y)) legend_y <- 0.08
    pos_mode <- as.character(legend_position_input %||% "none")[1]
    if (!pos_mode %in% c("none", "x", "y", "both")) pos_mode <- "none"
    if (pos_mode %in% c("x", "both")) {
      zx <- suppressWarnings(as.numeric(isolate(input$figure_legend_x %||% legend_x))[1])
      if (is.finite(zx)) legend_x <- zx
    }
    if (pos_mode %in% c("y", "both")) {
      zy <- suppressWarnings(as.numeric(isolate(input$figure_legend_y %||% legend_y))[1])
      if (is.finite(zy)) legend_y <- zy
    }
    if (identical(legend, "free")) {
      legend_x <- min(max(legend_x, -2), 3)
      legend_y <- min(max(legend_y, -2), 3)
    } else {
      legend_x <- min(max(legend_x, 0), 1)
      legend_y <- min(max(legend_y, 0), 1)
    }
    align_h <- as.character(isolate(input$figure_align_h %||% "center"))
    if (!align_h %in% c("left", "center", "right")) align_h <- "center"
    align_v <- as.character(isolate(input$figure_align_v %||% "center"))
    if (!align_v %in% c("top", "center", "bottom")) align_v <- "center"

    crop <- figure_default_crop()
    crop$enabled <- isTRUE(isolate(input$figure_crop_enabled))
    for (nm in c("left", "right", "top", "bottom")) {
      val <- suppressWarnings(as.numeric(isolate(input[[paste0("figure_crop_", nm)]] %||% 0)))
      if (!is.finite(val)) val <- 0
      crop[[nm]] <- min(max(val, 0), 0.49)
    }

    # F1-5: Inset geometry is canonical in the draft, just like free legend
    # placement. Browser-local drag/resize mirrors the Inspector without a Shiny
    # input echo, so unrelated Inspector edits must not read stale numericInput
    # values back over the canonical geometry.
    inset <- old_for_position$inset %||% figure_default_inset()
    inset$enabled <- isTRUE(isolate(input$figure_inset_enabled))
    inset$source_id <- as.character(isolate(input$figure_inset_source %||% ""))[1]
    inset$anchor <- "graph"
    ext_assets_now <- isolate(figure_external_assets())
    inset$source_type <- if (inset$source_id %in% names(ext_assets_now)) "external_asset" else "internal_graph"
    inset_mode <- as.character(inset_geometry_input %||% "none")[1]
    if (!inset_mode %in% c("none", "x", "y", "width", "height")) inset_mode <- "none"
    if (!identical(inset_mode, "none")) {
      val <- suppressWarnings(as.numeric(isolate(input[[paste0("figure_inset_", inset_mode)]] %||% inset[[inset_mode]]))[1])
      if (is.finite(val)) inset[[inset_mode]] <- val
    }
    inset$x <- min(max(suppressWarnings(as.numeric(inset$x %||% 0.62)[1]), -2), 3)
    inset$y <- min(max(suppressWarnings(as.numeric(inset$y %||% 0.08)[1]), -2), 3)
    inset$width <- min(max(suppressWarnings(as.numeric(inset$width %||% 0.32)[1]), 0.05), 1.5)
    inset$height <- min(max(suppressWarnings(as.numeric(inset$height %||% 0.32)[1]), 0.05), 1.5)
    inset$border <- isTRUE(isolate(input$figure_inset_border))

    # v3.41: Appearance is no longer authored by Figure override controls.
    # Preserve a legacy override while an old Project is only being viewed;
    # the first successful editable Figure Graph snapshot clears it and makes
    # the Figure-owned GraphState the sole owner of graph appearance.
    app <- modifyList(
      figure_default_appearance_override(),
      old_for_position$appearance %||% list()
    )

    exleg <- figure_default_external_legend()
    exleg$mode <- as.character(isolate(input$figure_external_legend_mode %||% "inherit"))[1]
    if (!exleg$mode %in% c("inherit","included","separate","none")) exleg$mode <- "inherit"
    exleg$position <- as.character(isolate(input$figure_external_legend_position %||% "right"))[1]
    if (!exleg$position %in% c("right","left","top","bottom","free")) exleg$position <- "right"
    for (nm in c("x","y","width","height")) {
      z <- suppressWarnings(as.numeric(isolate(input[[paste0("figure_external_legend_", nm)]] %||% exleg[[nm]])))
      if (is.finite(z)) exleg[[nm]] <- z
    }

    # Panel label text + label geometry are Slot-owned.  Source-specific
    # Appearance/Crop/Legend state must not carry them during Swap/Shift.
    panel_label_value <- as.character(isolate(input$figure_panel_label %||% ""))[1]
    key_now <- as.character(isolate(figure_selected_panel_key() %||% ""))[1]
    slot_before <- NULL
    slot_after <- NULL
    if (nzchar(key_now)) {
      st_now <- isolate(figure_layout_state())
      slot_changed <- FALSE
      for (rr in seq_along(st_now)) for (cc in seq_along(st_now[[rr]]$cells)) {
        cell0 <- st_now[[rr]]$cells[[cc]]
        if (identical(as.character(cell0$key %||% ""), key_now)) {
          slot_before <- figure_slot_label_payload(cell0)
          label_text_changed <- !identical(as.character(slot_before$panel_label %||% ""), panel_label_value)
          cell0$panel_label <- panel_label_value
          # Auto/manual ownership changes only when the label text itself is
          # explicitly changed. Appearance/legend/crop edits must not turn an
          # automatically generated A/B/C label into a manual label.
          if (isTRUE(label_text_changed)) cell0$panel_label_auto <- FALSE
          cell0$label_size <- label_size
          cell0$top_gutter <- top_gutter
          cell0$label_mode <- label_mode
          cell0$label_anchor <- label_anchor
          cell0$label_x_offset <- label_x_offset
          cell0$label_y_offset <- label_y_offset
          cell0$label_x <- label_x
          cell0$label_y <- label_y
          slot_after <- figure_slot_label_payload(cell0)
          if (!identical(slot_before, slot_after)) {
            st_now[[rr]]$cells[[cc]] <- cell0
            slot_changed <- TRUE
          }
        }
      }
      if (slot_changed) {
        figure_layout_state(st_now)
        # Label presence/size/top band affect layout; pure position edits only
        # need the Panel display revision.
        geom_fields <- c("panel_label", "label_size", "top_gutter")
        geom_changed <- any(vapply(geom_fields, function(nm) {
          !identical(slot_before[[nm]], slot_after[[nm]])
        }, logical(1)))
        if (isTRUE(geom_changed)) figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
        bump_figure_panel_display_revision(id)
      }
    }

    old <- old_for_position
    old_legend <- as.character(old$legend %||% "inherit")[1]
    detached_modes <- "free"
    entering_detached <- identical(legend, "free") && !identical(old_legend, "free")
    detached_xy_changed <- identical(legend, "free") && identical(old_legend, "free") &&
      (!isTRUE(all.equal(legend_x, suppressWarnings(as.numeric(old$legend_free_x %||% legend_x)[1]))) ||
       !isTRUE(all.equal(legend_y, suppressWarnings(as.numeric(old$legend_free_y %||% legend_y)[1]))))

    # F1-4 Figure Layer Model: detached legend ownership is prepared from the
    # source-side state, not captured after a mode transition.  This removes the
    # F1-3/F1-3b timing dependency where right -> free could briefly become
    # `inside` before the snapshot was measured.  Keep only the stable side
    # anchor; renderer/export derive their layer geometry from the source asset.
    last_side <- as.character(old$legend_last_side %||% "")[1]
    if (!last_side %in% c("right","left","top","bottom")) last_side <- ""
    if (old_legend %in% c("right","left","top","bottom")) last_side <- old_legend
    if (!legend %in% detached_modes && legend %in% c("right","left","top","bottom")) last_side <- legend

    free_origin <- as.character(old$legend_free_origin %||% "inherit")[1]
    source_origin <- as.character(old$legend_source_origin %||% "inherit")[1]
    if (!source_origin %in% c("right","left","top","bottom","inside")) source_origin <- "inherit"
    source_x <- suppressWarnings(as.numeric(old$legend_source_x %||% old$legend_x %||% 0.72)[1])
    source_y <- suppressWarnings(as.numeric(old$legend_source_y %||% old$legend_y %||% 0.08)[1])
    if (!is.finite(source_x)) source_x <- 0.72
    if (!is.finite(source_y)) source_y <- 0.08
    # Source/extraction ownership freezes when entering free placement. The
    # overlay itself is always Figure-owned and Graph-frame-relative.
    if (isTRUE(entering_detached)) {
      if (old_legend %in% c("right","left","top","bottom")) source_origin <- old_legend
      else if (last_side %in% c("right","left","top","bottom")) source_origin <- last_side
      else if (!source_origin %in% c("right","left","top","bottom","inside")) source_origin <- "inherit"
      free_origin <- source_origin
      diag_log("FIGURE-LAYER-ENTER", paste0(
        "mode=free source_origin=", source_origin,
        " anchor=owner-graph snapshot_dependency=FALSE"
      ), id=id)
    } else if (!legend %in% detached_modes && legend %in% c("right","left","top","bottom")) {
      # Returning to a normal side mode intentionally establishes a new source.
      source_origin <- legend
      free_origin <- legend
    } else if (identical(legend, "free") && source_origin %in% c("right","left","top","bottom","inside")) {
      free_origin <- source_origin
    }
    # Retain the legacy field in saved state only for backward compatibility;
    # F1-4 never consults it for source/render geometry.
    detach_snapshot <- old$legend_detach_snapshot

    free_auto <- if (isTRUE(entering_detached)) TRUE else if (isTRUE(detached_xy_changed)) FALSE else isTRUE(old$legend_free_auto)

    drafts <- figure_override_drafts()
    drafts[[id]] <- modifyList(old, list(
      legend = legend,
      legend_title = legend_title,
      legend_background = legend_background,
      legend_gap = legend_gap,
      legend_x = legend_x,
      legend_y = legend_y,
      legend_free_x = if (identical(legend, "free")) legend_x else old$legend_free_x %||% legend_x,
      legend_free_y = if (identical(legend, "free")) legend_y else old$legend_free_y %||% legend_y,
      legend_free_auto = if (legend %in% detached_modes) free_auto else FALSE,
      legend_free_origin = free_origin,
      legend_source_origin = source_origin,
      legend_source_x = source_x,
      legend_source_y = source_y,
      legend_last_side = last_side,
      legend_detach_snapshot = detach_snapshot,
      align_h = align_h,
      align_v = align_v,
      crop = crop,
      inset = inset,
      appearance = app,
      external_legend = exleg
    ))
    cls <- figure_override_change_class(old, drafts[[id]])
    if (!identical(cls, "NONE")) diag_log("FIGURE-OVERRIDE", paste0("class=", cls), id=id)
    hold_display <- FALSE
    if (!identical(cls, "NONE") &&
        exists("figure_legend_materializer_on_override_change", mode = "function", inherits = TRUE)) {
      hold_display <- isTRUE(figure_legend_materializer_on_override_change(
        id, old, drafts[[id]], reason = "inspector"
      ))
    }
    # Canonical edit ownership advances immediately, but a legend transition
    # that still needs its Figure-owned ggplot snapshot keeps the *visible*
    # requested override frozen.  The materializer publishes the newest draft
    # together with the completed snapshot, so the Panel paints once rather
    # than first showing the persisted SVG under new geometry.
    bump_figure_commit_edit_revisions(id, old, drafts[[id]])
    figure_override_drafts(drafts)
    if (!isTRUE(hold_display)) {
      if (cls %in% c("GRAPH_GEOMETRY", "FIGURE_GEOMETRY")) {
        figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
      }
      figure_requested_overrides(
        if (exists("figure_visible_requested_overrides", mode = "function", inherits = TRUE)) {
          figure_visible_requested_overrides(drafts)
        } else drafts
      )
      if (!identical(cls, "NONE")) bump_figure_panel_display_revision(id)
    } else {
      diag_log("FIGURE-LEGEND-MATERIALIZE", "display-hold reason=inspector", id=id)
    }
    merged <- if (is.list(slot_after)) figure_apply_slot_label_to_override(drafts[[id]], slot_after) else drafts[[id]]
    send_figure_label_overlay_update(id, merged)
    invisible(merged)
  }

  observeEvent(
    list(
      input$figure_panel_label,
      input$figure_panel_label_size,
      input$figure_top_gutter,
      input$figure_label_mode,
      input$figure_label_anchor,
      input$figure_label_x_offset,
      input$figure_label_y_offset,
      input$figure_label_x,
      input$figure_label_y,
      input$figure_legend_override,
      input$figure_legend_title,
      input$figure_legend_background,
      input$figure_legend_gap,
      input$figure_align_h,
      input$figure_align_v,
      input$figure_crop_enabled,
      input$figure_crop_left,
      input$figure_crop_right,
      input$figure_crop_top,
      input$figure_crop_bottom,
      input$figure_inset_enabled,
      input$figure_inset_source,
      input$figure_inset_border,
      input$figure_external_legend_mode, input$figure_external_legend_position,
      input$figure_external_legend_x, input$figure_external_legend_y,
      input$figure_external_legend_width, input$figure_external_legend_height
    ),
    {
      capture_current_figure_override()
    },
    ignoreInit = TRUE
  )


  # F1-4e: numeric X/Y edits are observed independently. Each observer updates
  # only the axis the user actually changed and preserves the other canonical
  # coordinate from the draft. Programmatic Inspector sync remains gated by
  # figure_inspector_syncing() inside capture_current_figure_override().
  observeEvent(input$figure_legend_x, {
    capture_current_figure_override("x")
  }, ignoreInit = TRUE)

  observeEvent(input$figure_legend_y, {
    capture_current_figure_override("y")
  }, ignoreInit = TRUE)

  # F1-5: numeric Inset geometry edits update only the field the user changed.
  # Direct drag/resize keeps these controls display-synced client-side without
  # sending Shiny events, so canonical geometry cannot be overwritten by echo.
  observeEvent(input$figure_inset_x, {
    capture_current_figure_override("none", "x")
  }, ignoreInit = TRUE)
  observeEvent(input$figure_inset_y, {
    capture_current_figure_override("none", "y")
  }, ignoreInit = TRUE)
  observeEvent(input$figure_inset_width, {
    capture_current_figure_override("none", "width")
  }, ignoreInit = TRUE)
  observeEvent(input$figure_inset_height, {
    capture_current_figure_override("none", "height")
  }, ignoreInit = TRUE)

  # Phase 2.1: the first explicit Inset enable/source selection should be
  # immediately visible without requiring a second refresh click. Freeze one
  # direct-state snapshot only when the user changes these controls and no
  # Figure-owned Inset snapshot exists yet. Later Graph edits remain snapshot-
  # based and require the explicit refresh action, as before.
  observeEvent(
    list(input$figure_inset_enabled, input$figure_inset_source),
    {
      if (isTRUE(isolate(figure_drag_syncing())) || isTRUE(isolate(figure_inspector_syncing()))) return()
      if (!isTRUE(isolate(input$figure_inset_enabled))) return()

      owner_id <- as.character(isolate(figure_selected_graph() %||% ""))[1]
      source_id <- as.character(isolate(input$figure_inset_source %||% ""))[1]
      if (!nzchar(owner_id) || !nzchar(source_id)) return()

      ext <- isolate(figure_external_assets())
      if (source_id %in% names(ext %||% list())) return()
      if (!cache_has(source_id)) return()

      existing <- isolate(figure_inset_preview_cache())[[source_id]]
      if (is.list(existing) && isTRUE(valid_graph_preview_record(existing))) return()
      if (isTRUE(figure_source_snapshot_target_pending(source_id, "inset", owner_id))) return()

      revision <- request_figure_inset_snapshot(
        owner_id, source_id, reason = "figure-inset-initial-source"
      )
      if (is.numeric(revision) && length(revision) == 1L && is.finite(revision)) {
        diag_log(
          "FIGURE-INSET",
          paste0("initial source queued direct state revision=", as.integer(revision),
                 " owner=", owner_id),
          id = source_id
        )
      }
    },
    ignoreInit = TRUE,
    priority = -10
  )

  observeEvent(input$figure_override_reset, {
    id <- as.character(isolate(figure_selected_graph() %||% ""))
    if (!nzchar(id)) return()
    drafts <- isolate(figure_override_drafts())
    old <- drafts[[id]] %||% figure_default_override(id)
    fresh <- figure_default_override(id)
    # Slot-owned Panel label settings are intentionally untouched.
    drafts[[id]] <- fresh
    cls <- figure_override_change_class(old, fresh)
    hold_display <- FALSE
    if (exists("figure_legend_materializer_on_override_change", mode = "function", inherits = TRUE)) {
      hold_display <- isTRUE(figure_legend_materializer_on_override_change(
        id, old, fresh, reason = "reset"
      ))
    }
    bump_figure_commit_edit_revisions(id, old, fresh)
    figure_override_drafts(drafts)
    if (!isTRUE(hold_display)) {
      if (cls %in% c("GRAPH_GEOMETRY","FIGURE_GEOMETRY")) {
        figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
      }
      figure_requested_overrides(
        if (exists("figure_visible_requested_overrides", mode = "function", inherits = TRUE)) {
          figure_visible_requested_overrides(drafts)
        } else drafts
      )
      bump_figure_panel_display_revision(id)
    } else {
      diag_log("FIGURE-LEGEND-MATERIALIZE", "display-hold reason=reset", id=id)
    }
    sync_figure_inspector()
    diag_log("FIGURE-OVERRIDE", "action=reset-to-inherit", id=id)
  }, ignoreInit=TRUE)

  copy_figure_style_fields <- function(from_ov, to_ov) {
    out <- modifyList(figure_default_override(), to_ov %||% list())
    src <- modifyList(figure_default_override(), from_ov %||% list())
    out$appearance <- src$appearance
    for (nm in c("legend","legend_title","legend_background","legend_gap","legend_x","legend_y","legend_free_x","legend_free_y",
                 "legend_free_anchor","legend_free_auto","legend_free_origin","legend_source_origin","legend_source_x","legend_source_y","legend_last_side","legend_detach_snapshot")) out[[nm]] <- src[[nm]]
    out
  }

  observeEvent(input$figure_copy_style_to, {
    from_id <- as.character(isolate(figure_selected_graph() %||% ""))
    target_key <- as.character(isolate(input$figure_style_target %||% ""))
    to_id <- figure_layout_source_at_key(isolate(figure_layout_state()), target_key)
    if (!nzchar(from_id) || !nzchar(to_id) || identical(from_id, to_id)) return()
    if (to_id %in% names(isolate(figure_external_assets()))) {
      showNotification("Appearance/Legendコピー先は内部Graphにしてください。", type="warning"); return()
    }
    drafts <- isolate(figure_override_drafts())
    old_to <- drafts[[to_id]] %||% figure_default_override(to_id)
    new_to <- copy_figure_style_fields(drafts[[from_id]], old_to)
    drafts[[to_id]] <- new_to
    cls <- figure_override_change_class(old_to, new_to)
    hold_display <- FALSE
    if (exists("figure_legend_materializer_on_override_change", mode = "function", inherits = TRUE)) {
      hold_display <- isTRUE(figure_legend_materializer_on_override_change(
        to_id, old_to, new_to, reason = "copy-style"
      ))
    }
    bump_figure_commit_edit_revisions(to_id, old_to, new_to)
    figure_override_drafts(drafts)
    if (!isTRUE(hold_display)) {
      if (cls %in% c("GRAPH_GEOMETRY","FIGURE_GEOMETRY")) {
        figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
      }
      figure_requested_overrides(
        if (exists("figure_visible_requested_overrides", mode = "function", inherits = TRUE)) {
          figure_visible_requested_overrides(drafts)
        } else drafts
      )
      bump_figure_panel_display_revision(to_id)
    } else {
      diag_log("FIGURE-LEGEND-MATERIALIZE", "display-hold reason=copy-style", id=to_id)
    }
    diag_log("FIGURE-OVERRIDE", paste0("action=copy-style target=", to_id), id=from_id)
  }, ignoreInit=TRUE)

  observeEvent(input$figure_copy_style_all, {
    from_id <- as.character(isolate(figure_selected_graph() %||% ""))
    if (!nzchar(from_id) || from_id %in% names(isolate(figure_external_assets()))) return()
    drafts <- isolate(figure_override_drafts())
    requested <- isolate(figure_requested_overrides())
    meta <- isolate(graph_meta())
    geom_changed <- FALSE
    display_changed <- character(0)
    for (to_id in as.character(meta$id)) {
      if (!identical(to_id, from_id)) {
        old_to <- drafts[[to_id]] %||% figure_default_override(to_id)
        new_to <- copy_figure_style_fields(drafts[[from_id]], old_to)
        drafts[[to_id]] <- new_to
        cls <- figure_override_change_class(old_to, new_to)
        hold_display <- FALSE
        if (exists("figure_legend_materializer_on_override_change", mode = "function", inherits = TRUE)) {
          hold_display <- isTRUE(figure_legend_materializer_on_override_change(
            to_id, old_to, new_to, reason = "copy-style-all"
          ))
        }
        bump_figure_commit_edit_revisions(to_id, old_to, new_to)
        if (!isTRUE(hold_display)) {
          requested[[to_id]] <- new_to
          if (cls %in% c("GRAPH_GEOMETRY","FIGURE_GEOMETRY")) geom_changed <- TRUE
          if (!identical(cls, "NONE")) display_changed <- c(display_changed, to_id)
        } else {
          diag_log("FIGURE-LEGEND-MATERIALIZE", "display-hold reason=copy-style-all", id=to_id)
        }
      }
    }
    figure_override_drafts(drafts)
    figure_requested_overrides(requested)
    if (geom_changed) figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
    for (to_id in unique(display_changed)) bump_figure_panel_display_revision(to_id)
    diag_log("FIGURE-OVERRIDE", "action=copy-style-all-internal", id=from_id)
  }, ignoreInit=TRUE)

  observeEvent(input$figure_apply_to_source, {
    if (project_load_action_blocked("figure-commit-source")) return()
    id <- as.character(isolate(figure_selected_graph() %||% ""))[1]
    if (!nzchar(id) || id %in% names(isolate(figure_external_assets()))) {
      showNotification("元Graphへの反映は内部Graphのみ対応しています。", type="warning")
      return()
    }

    st <- isolate(figure_edit_states())[[id]]
    if (!is.list(st)) {
      showNotification("Figure側に編集可能なGraph snapshotがありません。先に『Graphから再読込』してください。", type="warning", duration=4)
      return()
    }

    # Figure and Graph share the same GraphState schema.  The ownership
    # boundary is centralized in figure_sync_contract.R: Figure-only layout,
    # crop/inset and detached-legend placement are outside GraphState and are
    # never part of this source commit.
    source_before <- if (cache_has(id)) cache_get(id) else NULL
    payload <- figure_source_apply_payload(st, source_before)
    requested_paths <- figure_source_apply_diff(source_before, st)
    diag_log(
      "FIGURE-APPLY-DIFF",
      paste0(
        "requested paths=",
        if (length(requested_paths)) paste0("{", paste(requested_paths, collapse=","), "}") else "<none>"
      ),
      id=id
    )
    diag_log("FIGURE-APPLY-STYLE", paste0("figure_state ", figure_graphstate_style_summary(payload)), id=id)
    changed <- registry_commit(id, payload, source = "figure-editor-apply")
    committed_state <- cache_get(id)
    if (isTRUE(changed) && exists("graph_single_mark_stale", mode = "function", inherits = TRUE)) {
      graph_single_mark_stale(id, reason = "figure-editor-apply")
    }
    diag_log("FIGURE-APPLY-STYLE", paste0("registry_state ", figure_graphstate_style_summary(committed_state)), id=id)
    commit_mismatch <- app_state_diff_paths(payload, committed_state)
    diag_log(
      "FIGURE-APPLY-DIFF",
      paste0(
        "post-commit payload-vs-registry=",
        if (length(commit_mismatch)) paste0("{", paste(commit_mismatch, collapse=","), "}") else "<none>"
      ),
      id=id
    )

    # Canonical GraphState is the only Graph-side commit target. Dormant Graphs
    # stay state-only; if this Graph currently owns the persistent Editor, the
    # stale marker above makes the normal Graph-workspace resume path replay it.
    diag_log(
      "FIGURE-COMMIT",
      paste0(
        "full-graphstate applied registry_changed=", isTRUE(changed),
        " dormant_state_only=TRUE deferred_visible_replay=",
        identical(id, graph_single_owner()),
        " figure_snapshot_unchanged=TRUE"
      ),
      id=id
    )
    showNotification(
      "FigureのGraph設定を元Graphへ反映しました。Graphへ戻ると保存状態をEditorへ再現します。",
      type="message", duration=4
    )
  }, ignoreInit = TRUE)

  observeEvent(input$figure_graph_edit_selected, {
    if (project_load_action_blocked("figure-graph-edit-selected")) return()
    id <- as.character(isolate(figure_selected_graph()) %||% "")[1]
    if (!nzchar(id) || id %in% names(isolate(figure_external_assets()))) return()
    if (!id %in% names(isolate(figure_edit_states()))) {
      showNotification("Figure側に編集可能なGraph snapshotがありません。先に『Graphから再読込』してください。", type="warning", duration=4)
      return()
    }
    diag_log("FIGURE-EDITOR-SHELL", "edit-request", id = id)
    ensure_figure_editor(id)
  }, ignoreInit = TRUE)

  observeEvent(input$figure_panel_clicked, {
    if (project_load_action_blocked("figure-panel-click")) return()
    x <- input$figure_panel_clicked
    id <- as.character(x$id %||% "")
    diag_log("FIGURE-EDIT", paste0("panel_click key=", as.character(x$key %||% "")), id = id)
    key <- as.character(x$key %||% "")
    # v3.49.1: panel selection carries a synchronous snapshot of the currently
    # visible Inspector fold state.  Store it before changing the selected Graph
    # so the replacement renderUI cannot fall back to default collapsed classes.
    incoming_folds <- x$folds
    if (is.list(incoming_folds) && length(incoming_folds)) {
      allowed_fold_keys <- c("label", "crop", "alignment", "legend", "inset")
      folds <- isolate(figure_inspector_folds())
      for (fold_key in intersect(names(incoming_folds), allowed_fold_keys)) {
        fold_value <- incoming_folds[[fold_key]]
        if (is.logical(fold_value) && length(fold_value) == 1L && !is.na(fold_value)) {
          folds[[fold_key]] <- fold_value
        }
      }
      figure_inspector_folds(folds)
    }
    if (nzchar(id)) {
      figure_selected_graph(id)
      figure_selected_panel_key(key)
      pos <- figure_layout_key_position(isolate(figure_layout_state()), key)
      if (is.finite(pos$row) && !identical(as.integer(pos$row), as.integer(isolate(figure_selected_row())))) {
        figure_selected_row(as.integer(pos$row))
        bump_figure_layout_ui()
      }
      if (id %in% names(isolate(figure_external_assets()))) {
        diag_log("FIGURE-SOURCE", paste0("panel select external_asset=TRUE key=", key), id = id)
      } else {
        # Selecting a Figure panel must never mean source -> Figure refresh.
        # Existing Figure-owned state/snapshot stays authoritative until one of
        # the explicit refresh buttons is pressed.
        has_edit <- id %in% names(isolate(figure_edit_states()))
        diag_log(
          "FIGURE-SOURCE-SYNC",
          paste0("panel select only; automatic source refresh ignored key=", key, " editable_state=", has_edit),
          id = id
        )
        # Panel selection stays browse/inspect-only until the user has explicitly
        # opened the Figure Graph Editor. Once an editor is active, selecting a
        # different editable Figure panel must move that same persistent editor
        # to the selected Figure-owned state; otherwise controls from the old
        # owner can mutate the newly selected panel by mistake.
        editing_id <- as.character(isolate(figure_editing_graph()) %||% "")[1]
        editor_active <- nzchar(editing_id) &&
          isTRUE(isolate(figure_single_editor_show_when_ready()))
        if (isTRUE(has_edit) && isTRUE(editor_active) && !identical(editing_id, id)) {
          switched <- isTRUE(ensure_figure_editor(
            id, preserve_current = TRUE, show_when_ready = TRUE
          ))
          diag_log(
            "FIGURE-EDITOR-SHELL",
            paste0("selection-follow previous=", editing_id, " switched=", switched),
            id = id
          )
        }
      }
    }
  }, ignoreInit = TRUE)

  observeEvent(input$figure_drag_event, {
    if (project_load_action_blocked("figure-drag")) return()
    x <- input$figure_drag_event
    id <- as.character(x$id %||% "")[1]
    typ <- as.character(x$type %||% "")[1]
    key <- as.character(x$key %||% "")[1]
    if (!nzchar(id) || !typ %in% c("label", "legend", "inset")) return()
    xp <- suppressWarnings(as.numeric(x$x %||% NA_real_)[1])
    yp <- suppressWarnings(as.numeric(x$y %||% NA_real_)[1])
    if (!is.finite(xp) || !is.finite(yp)) return()
    drag_scope <- as.character(x$scope %||% "")[1]
    diag_log("FIGURE-EDIT", paste0("drag type=", typ, " scope=", drag_scope, " x=", round(xp, 4), " y=", round(yp, 4)), id = id)
    figure_drag_syncing(TRUE)
    figure_selected_graph(id)
    figure_selected_panel_key(key)

    if (identical(typ, "label")) {
      # alpha3 ownership rule: a Panel label belongs to the Slot. Dragging A/B/C
      # must not mutate a source-keyed override that would move with Swap/Shift.
      st <- isolate(figure_layout_state())
      changed <- FALSE
      slot_payload <- NULL
      if (nzchar(key)) {
        for (rr in seq_along(st)) for (cc in seq_along(st[[rr]]$cells)) {
          cell <- st[[rr]]$cells[[cc]]
          if (!identical(as.character(cell$key %||% ""), key)) next
          cell$label_mode <- "free"
          cell$label_x <- min(max(xp, -0.2), 1.2)
          cell$label_y <- min(max(yp, -0.2), 1.2)
          cell$panel_label_auto <- FALSE
          st[[rr]]$cells[[cc]] <- cell
          slot_payload <- figure_slot_label_payload(cell)
          changed <- TRUE
        }
      }
      if (changed) {
        figure_layout_state(st)
        bump_figure_panel_display_revision(id)
        updateRadioButtons(session, "figure_label_mode", selected = "free")
        updateNumericInput(session, "figure_label_x", value = slot_payload$label_x)
        updateNumericInput(session, "figure_label_y", value = slot_payload$label_y)
        ov <- figure_apply_slot_label_to_override(
          isolate(figure_override_drafts())[[id]] %||% figure_default_override(id),
          slot_payload
        )
        send_figure_label_overlay_update(id, ov)
      }
    } else {
      drafts <- isolate(figure_override_drafts())
      ov <- figure_apply_drag_override_state(
        drafts[[id]] %||% figure_default_override(id), typ, xp, yp, x$width, x$height, x$scope
      )
      drafts[[id]] <- ov
      figure_override_drafts(drafts)
      # Publish the canonical state immediately, but do not redraw a legend that
      # the browser has already moved to its final pixel position.  The next
      # unrelated Figure render will materialize the same saved coordinates.
      figure_requested_overrides(
        if (exists("figure_visible_requested_overrides", mode = "function", inherits = TRUE)) {
          figure_visible_requested_overrides(drafts)
        } else drafts
      )
      if (identical(typ, "legend")) {
        scope_now <- figure_legend_layer_scope(ov)
        # Free legends live on the Figure layer. They only need a geometry pass
        # when Auto Canvas may have to grow beyond the outer edge.
        if (identical(scope_now, "figure") && identical(isolate(figure_requested_size_mode()), "auto")) {
          figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
        }
        # Keep the visible Inspector numbers aligned without creating a second
        # Shiny input event. The server-side source of truth is already `ov`.
        shown_x <- ov$legend_free_x %||% ov$legend_x
        shown_y <- ov$legend_free_y %||% ov$legend_y
        session$sendCustomMessage("figure-inspector-legend-position", list(x = shown_x, y = shown_y))
        diag_log("FIGURE-EDIT", paste0("legend_commit scope=", scope_now, " render=client-hold no-input-echo"), id=id)
      } else {
        # F1-5: pointer movement/resizing is browser-local. Persist once on
        # pointerup, keep the visible overlay in place, and update Inspector DOM
        # without creating a second Shiny input event.
        if (identical(isolate(figure_requested_size_mode()), "auto")) {
          figure_geometry_revision(isolate(figure_geometry_revision()) + 1L)
        }
        session$sendCustomMessage("figure-inspector-inset-geometry", list(
          x = ov$inset$x, y = ov$inset$y,
          width = ov$inset$width, height = ov$inset$height
        ))
        diag_log("FIGURE-EDIT", "inset_commit anchor=owner-graph render=client-hold no-input-echo", id=id)
      }
    }

    session$onFlushed(function() {
      figure_drag_syncing(FALSE)
    }, once = TRUE)
  }, ignoreInit = TRUE)



  observeEvent(input$figure_layout_mode, {
    mode <- as.character(input$figure_layout_mode %||% "row")[1]
    if (!mode %in% c("row", "free")) mode <- "row"
    restore_seed <- isolate(figure_control_restore_seed())
    if (!is.null(restore_seed)) {
      target <- as.character(restore_seed$layout_mode %||% "row")[1]
      diag_log("FIGURE-LAYOUT-MODE", paste0(
        "restore-gated input=", mode, " target=", target
      ))
      return()
    }
    old <- isolate(figure_requested_layout_mode())
    if (!identical(old, mode)) {
      if (identical(mode, "free")) {
        st <- isolate(figure_layout_state())
        source_sizes <- tryCatch(isolate(figure_source_sizes()), error = function(e) list())
        row_geo <- tryCatch(
          figure_auto_layout_geometry(
            st, source_sizes, isolate(figure_override_drafts()),
            isolate(figure_requested_gap_x()), isolate(figure_requested_gap_y()),
            figure_auto_outer_margin(), size_basis = isolate(figure_requested_size_basis()),
            title_align = isolate(figure_requested_title_align())
          ),
          error = function(e) list(rects=list())
        )
        figure_layout_state(figure_seed_free_geometry(st, row_geo$rects %||% list()))
      }
      figure_requested_layout_mode(mode)
      diag_log("FIGURE-LAYOUT-MODE", paste0("mode=", mode))
      bump_figure_layout_ui()
    }
  }, ignoreInit = TRUE)

  output$figure_asset_status <- renderText({
    assets <- figure_external_assets()
    if (!length(assets)) return("Assetなし")
    paste0(length(assets), " Asset: ", paste(vapply(assets, figure_asset_display_name, character(1)), collapse = ", "))
  })

  observeEvent(input$figure_asset_add, {
    if (project_load_action_blocked("figure-asset-add")) return()
    up <- input$figure_asset_upload
    if (is.null(up) || is.null(up$datapath) || !file.exists(up$datapath)) {
      showNotification("追加するAssetファイルを選択してください。", type="warning")
      return()
    }
    assets <- isolate(figure_external_assets())
    role <- as.character(input$figure_asset_role %||% "external_graph")[1]
    if (!role %in% c("external_graph","generic","legend")) role <- "external_graph"
    legend_mode <- as.character(input$figure_asset_legend_mode %||% "included")[1]
    if (!legend_mode %in% c("included","separate","none")) legend_mode <- "included"
    if (!identical(role, "external_graph")) legend_mode <- "none"

    z <- tryCatch(figure_import_external_asset(up, assets), error = function(e) e)
    if (inherits(z, "error")) {
      showNotification(paste0("Asset追加失敗: ", conditionMessage(z)), type="error", duration=6)
      return()
    }
    legend_z <- NULL
    if (identical(role, "external_graph") && identical(legend_mode, "separate")) {
      lup <- input$figure_asset_legend_upload
      if (is.null(lup) || is.null(lup$datapath) || !file.exists(lup$datapath)) {
        showNotification("『凡例を別ファイル』では凡例ファイルも選択してください。", type="warning")
        return()
      }
      existing2 <- assets; existing2[[z$asset_id]] <- z
      legend_z <- tryCatch(figure_import_external_asset(lup, existing2), error=function(e) e)
      if (inherits(legend_z, "error")) {
        showNotification(paste0("凡例Asset追加失敗: ", conditionMessage(legend_z)), type="error", duration=6)
        return()
      }
      legend_z <- figure_decorate_external_asset(legend_z, role="legend", parent_asset_id=z$asset_id)
      z <- figure_decorate_external_asset(z, role="external_graph", legend_mode="separate", legend_asset_id=legend_z$asset_id)
    } else {
      z <- figure_decorate_external_asset(z, role=role, legend_mode=legend_mode)
    }
    assets[[z$asset_id]] <- z
    if (!is.null(legend_z)) assets[[legend_z$asset_id]] <- legend_z
    figure_external_assets(assets)
    figure_requested_external_assets(assets)
    diag_log("FIGURE-ASSET", paste0("added id=", z$asset_id, " role=", role, " type=", z$type,
                                      " legend_mode=", legend_mode,
                                      if (!is.null(legend_z)) paste0(" legend_asset=", legend_z$asset_id) else ""))
    bump_figure_layout_ui()
    showNotification(paste0("Assetを追加しました: ", z$name), type="message", duration=2)
  }, ignoreInit = TRUE)

  observeEvent(input$figure_asset_remove, {
    if (project_load_action_blocked("figure-asset-remove")) return()
    id <- as.character(isolate(figure_selected_graph() %||% ""))
    assets <- isolate(figure_external_assets())
    if (!nzchar(id) || !id %in% names(assets)) {
      showNotification("削除するAsset Panelを選択してください。", type="warning")
      return()
    }
    victim <- assets[[id]]
    remove_ids <- id
    if (identical(victim$asset_role %||% "", "external_graph")) {
      lid <- as.character(victim$legend_asset_id %||% "")
      if (nzchar(lid) && lid %in% names(assets)) remove_ids <- unique(c(remove_ids, lid))
    }
    if (identical(victim$asset_role %||% "", "legend")) {
      pid <- as.character(victim$parent_asset_id %||% "")
      if (nzchar(pid) && pid %in% names(assets)) {
        assets[[pid]]$legend_asset_id <- ""
        assets[[pid]]$legend_mode <- "none"
      }
    }
    for (rid in remove_ids) assets[[rid]] <- NULL
    figure_external_assets(assets)
    figure_requested_external_assets(assets)
    st <- isolate(figure_layout_state())
    for (r in seq_along(st)) for (c in seq_along(st[[r]]$cells)) {
      if (as.character(st[[r]]$cells[[c]]$id %||% "") %in% remove_ids) {
        st[[r]]$cells[[c]]$id <- ""
        st[[r]]$cells[[c]]$source_id <- ""
        st[[r]]$cells[[c]]$source_type <- "internal_graph"
      }
    }
    figure_layout_state(figure_reindex_layout(st))
    drafts <- isolate(figure_override_drafts())
    for (rid in remove_ids) drafts[[rid]] <- NULL
    # Disable insets referencing removed assets.
    for (oid in names(drafts)) {
      if (as.character(drafts[[oid]]$inset$source_id %||% "") %in% remove_ids) {
        drafts[[oid]]$inset$enabled <- FALSE; drafts[[oid]]$inset$source_id <- ""
      }
    }
    figure_override_drafts(drafts)
    figure_selected_graph(""); figure_selected_panel_key("")
    bump_figure_layout_ui()
    diag_log("FIGURE-ASSET", paste0("removed ids=", paste(remove_ids, collapse=",")))
  }, ignoreInit = TRUE)



  refresh_export_choices <- function() {
    meta <- isolate(graph_meta())
    if (!nrow(meta)) return(invisible(NULL))

    current <- isolate(input$bulk_export_selected %||% character(0))
    selected <- intersect(current, meta$id)
    if (!length(selected)) {
      a <- isolate(active_graph())
      selected <- if (a %in% meta$id) a else meta$id[1]
    }

    updateCheckboxGroupInput(
      session, "bulk_export_selected",
      choices = stats::setNames(as.list(as.character(meta$id)), as.character(meta$name)),
      selected = selected
    )
    invisible(NULL)
  }
