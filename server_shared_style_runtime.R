# v3.73.0 — project-level Shared Label / Style Library runtime.
# Central Library mediates semantic style changes. Graphs never message each
# other directly; canonical GraphState remains the only per-Graph authority.

  shared_style_prune_binding_to_library <- function(binding, library) {
    b <- shared_style_normalize_binding(binding)
    lib <- shared_style_normalize_library(library)
    valid <- names(lib$items)
    for (vn in names(b$levels) %||% character(0)) {
      br <- b$levels[[vn]]
      for (lv in names(br) %||% character(0)) {
        item_id <- br[[lv]]
        item <- lib$items[[item_id]]
        if (!item_id %in% valid || !is.list(item) || !identical(item$kind, "level")) br[[lv]] <- NULL
      }
      if (length(br)) b$levels[[vn]] <- br else b$levels[[vn]] <- NULL
    }
    for (axis_nm in c("x", "y")) {
      item_id <- b$axis[[axis_nm]]
      item <- lib$items[[item_id]]
      if (!item_id %in% valid || !is.list(item) || !identical(item$kind, "axis_label")) b$axis[[axis_nm]] <- ""
    }
    for (key in names(b$legends) %||% character(0)) {
      item_id <- b$legends[[key]]
      item <- lib$items[[item_id]]
      if (!item_id %in% valid || !is.list(item) || !identical(item$kind, "legend_title")) b$legends[[key]] <- NULL
    }
    shared_style_normalize_binding(b)
  }

  shared_style_prune_graph_state <- function(state, library) {
    if (!is.list(state)) return(state)
    st <- state$style %||% list()
    st$shared_library <- shared_style_prune_binding_to_library(st$shared_library %||% NULL, library)
    state$style <- st
    state
  }

  shared_style_request_visible_graph_replay <- function(ids, reason = "shared-style-library") {
    ids <- unique(as.character(ids %||% character(0)))
    owner <- graph_single_owner()
    if (!nzchar(owner) || !owner %in% ids) return(invisible(FALSE))

    workspace_visible <- identical(
      as.character(isolate(input$workspace_main_tab) %||% "")[1],
      "graph_workspace"
    )
    if (isTRUE(isolate(graph_single_editor_loading()))) {
      # Do not interrupt the existing ACK-gated Graph replay. The canonical
      # revision has already advanced; once the current transaction finishes,
      # mark that same owner stale and replay it only if Graph is still visible.
      shared_style_graph_replay_pending(list(id = owner, reason = reason))
      diag_log("SHARED-STYLE-GRAPH", "owner resync deferred until current replay completes", id = owner)
      return(invisible(TRUE))
    }

    shared_style_graph_replay_pending(NULL)
    graph_single_mark_stale(owner, reason = reason)
    if (isTRUE(workspace_visible)) {
      request_graph_editor(owner, source = reason, new_graph = FALSE)
      diag_log("SHARED-STYLE-GRAPH", "visible owner replay requested from canonical state", id = owner)
    } else {
      diag_log("SHARED-STYLE-GRAPH", "owner marked stale; replay deferred until Graph workspace resume", id = owner)
    }
    invisible(TRUE)
  }

  shared_style_apply_to_registry <- function(library, skip_graph_id = "", reason = "shared-style-library") {
    lib <- shared_style_normalize_library(library)
    meta <- isolate(graph_meta())
    changed_ids <- character(0)
    render_ids <- character(0)
    skip_graph_id <- as.character(skip_graph_id %||% "")[1]

    for (id in as.character(meta$id %||% character(0))) {
      if (!nzchar(id) || identical(id, skip_graph_id) || !cache_has(id)) next
      old <- cache_get(id)
      if (!is.list(old)) next
      base <- shared_style_prune_graph_state(old, lib)
      new <- shared_style_apply_to_graph_state(base, lib)
      if (identical(old, new)) next
      render_changed <- isTRUE(graph_render_state_changed(old, new))
      if (isTRUE(registry_commit(id, new, source = reason))) {
        changed_ids <- c(changed_ids, id)
        if (isTRUE(render_changed)) render_ids <- c(render_ids, id)
      }
    }

    changed_ids <- unique(changed_ids)
    render_ids <- unique(render_ids)
    # Dormant Graphs stay state-only. Only the one visible persistent Graph
    # Editor is replayed, and only when its render-affecting state changed.
    if (length(render_ids)) shared_style_request_visible_graph_replay(render_ids, reason = reason)
    changed_ids
  }

  # Direct Figure Shared Style application. Figure-owned GraphStates are updated
  # first, then snapshots are regenerated from those values through the existing
  # server-side GraphState renderer. No Figure Editor is created/switched merely
  # to rebuild snapshots.
  shared_style_apply_figure_states <- function(library, reason = "shared-style-figure") {
    lib <- shared_style_normalize_library(library)
    states <- isolate(figure_edit_states())
    if (!length(states)) return(character(0))

    current_owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    current_visible <- nzchar(current_owner) &&
      figure_workspace_is_active() &&
      isTRUE(isolate(figure_single_editor_show_when_ready())) &&
      !isTRUE(isolate(figure_single_editor_loading())) &&
      identical(as.character(isolate(figure_single_editor_mode()) %||% ""), "READY")

    # Preserve unsaved Figure-only controls for the one currently visible editor
    # before changing its Figure-owned GraphState externally.
    if (isTRUE(current_visible)) {
      mod_now <- figure_editor_module(current_owner)
      live_state <- tryCatch({
        if (!is.null(mod_now) && is.function(mod_now$state)) isolate(mod_now$state()) else NULL
      }, error = function(e) NULL)
      if (is.list(live_state)) states[[current_owner]] <- live_state
    }

    changed <- character(0)
    render_changed <- character(0)
    for (id in names(states)) {
      old <- states[[id]]
      if (!is.list(old)) next

      # Figure has no independent semantic-binding editor. Resolve binding
      # metadata from the current source Graph while keeping all other Figure
      # GraphState fields snapshot-owned.
      source_state <- if (cache_has(id)) cache_get(id) else NULL
      source_binding <- if (is.list(source_state)) {
        source_state$style$shared_library %||% NULL
      } else {
        old$style$shared_library %||% NULL
      }

      base <- old
      if (!is.list(base$style)) base$style <- list()
      base$style$shared_library <- shared_style_prune_binding_to_library(source_binding, lib)
      base <- shared_style_prune_graph_state(base, lib)
      new <- shared_style_apply_to_graph_state(base, lib)
      if (identical(old, new)) next
      states[[id]] <- new
      changed <- c(changed, id)
      if (isTRUE(graph_render_state_changed(old, new))) render_changed <- c(render_changed, id)
    }
    if (!length(changed)) return(character(0))

    changed <- unique(changed)
    render_changed <- unique(render_changed)
    figure_edit_states(states)

    for (id in render_changed) {
      request_figure_source_snapshot(
        id,
        reason = paste0(reason, "-direct-state"),
        import_editor_state = FALSE,
        state_override = states[[id]],
        target_type = "main"
      )
    }

    # If the user is actively looking at the affected Figure Editor, replay that
    # one owner from the updated Figure-owned state. This is presentation sync;
    # snapshot generation above remains direct-state and editor-independent.
    if (isTRUE(current_visible) && current_owner %in% render_changed) {
      ensure_figure_editor(
        current_owner,
        force_reload = TRUE,
        preserve_current = FALSE,
        show_when_ready = TRUE,
        state_override = states[[current_owner]]
      )
      diag_log("SHARED-STYLE-FIGURE", "visible editor replayed; snapshots queued direct-state", id = current_owner)
    }

    if (length(render_changed)) {
      diag_log(
        "SHARED-STYLE-FIGURE",
        paste0("direct-state queued={", paste(render_changed, collapse=","), "} reason=", reason)
      )
    }
    render_changed
  }

  observe({
    pending <- shared_style_graph_replay_pending()
    if (!is.list(pending) || isTRUE(graph_single_editor_loading())) return()
    id <- as.character(pending$id %||% "")[1]
    reason <- as.character(pending$reason %||% "shared-style-library")[1]
    shared_style_graph_replay_pending(NULL)
    if (!nzchar(id) || !identical(id, graph_single_owner()) || !cache_has(id)) return()

    graph_single_mark_stale(id, reason = reason)
    workspace_visible <- identical(
      as.character(isolate(input$workspace_main_tab) %||% "")[1],
      "graph_workspace"
    )
    if (isTRUE(workspace_visible)) {
      request_graph_editor(id, source = reason, new_graph = FALSE)
      diag_log("SHARED-STYLE-GRAPH", "deferred visible owner replay started", id = id)
    } else {
      diag_log("SHARED-STYLE-GRAPH", "deferred owner marked stale; waits for Graph workspace resume", id = id)
    }
  })

  shared_style_commit_library <- function(library_now, source = "library-ui", skip_graph_id = "") {
    new_lib <- shared_style_normalize_library(library_now)
    old_lib <- shared_style_normalize_library(isolate(shared_style_library()))
    if (identical(old_lib, new_lib)) return(invisible(FALSE))

    shared_style_library(new_lib)
    diag_log(
      "SHARED-STYLE-LIBRARY",
      paste0("commit source=", source, " items=", length(new_lib$items), " skip_graph=", skip_graph_id %||% "")
    )

    changed_graphs <- shared_style_apply_to_registry(
      new_lib,
      skip_graph_id = skip_graph_id,
      reason = paste0("shared-style:", source)
    )

    changed_figure <- character(0)
    if (isTRUE(isolate(figure_shared_style_sync()))) {
      changed_figure <- shared_style_apply_figure_states(new_lib, reason = paste0("auto:", source))
    }

    diag_log(
      "SHARED-STYLE-APPLY",
      paste0(
        "source=", source,
        " graphs={", paste(changed_graphs, collapse=","), "}",
        " figure={", paste(changed_figure, collapse=","), "}"
      )
    )
    invisible(TRUE)
  }

  shared_style_usage_records <- reactive({
    graph_state_cache()
    lib <- shared_style_normalize_library(shared_style_library())
    usage <- stats::setNames(lapply(names(lib$items), function(x) character(0)), names(lib$items))
    meta <- graph_meta()
    for (i in seq_len(nrow(meta))) {
      id <- meta$id[[i]]
      nm <- meta$name[[i]]
      st <- if (cache_has(id)) cache_get(id) else NULL
      if (!is.list(st)) next
      b <- shared_style_normalize_binding(st$style$shared_library %||% NULL)
      if (!isTRUE(b$enabled)) next
      for (vn in names(b$levels) %||% character(0)) for (lv in names(b$levels[[vn]]) %||% character(0)) {
        item_id <- b$levels[[vn]][[lv]]
        if (item_id %in% names(usage)) usage[[item_id]] <- c(usage[[item_id]], paste0(nm, " / ", vn, " / ", lv))
      }
      for (axis_nm in c("x", "y")) {
        item_id <- b$axis[[axis_nm]] %||% ""
        if (item_id %in% names(usage)) usage[[item_id]] <- c(usage[[item_id]], paste0(nm, " / ", toupper(axis_nm), " axis"))
      }
      for (key in names(b$legends) %||% character(0)) {
        item_id <- b$legends[[key]]
        if (item_id %in% names(usage)) usage[[item_id]] <- c(usage[[item_id]], paste0(nm, " / legend / ", key))
      }
    }
    lapply(usage, unique)
  })

  output$shared_style_summary <- renderUI({
    lib <- shared_style_normalize_library(shared_style_library())
    usage <- shared_style_usage_records()
    if (!length(lib$items)) {
      return(div(class = "shared-style-summary-empty", "Libraryは空です。下の『Libraryを編集…』から共通項目を作成してください。"))
    }
    div(
      class = "shared-style-summary-grid",
      lapply(lib$items, function(item) {
        used <- usage[[item$id]] %||% character(0)
        div(
          class = "shared-style-summary-item",
          div(
            class = "shared-style-summary-swatch",
            style = paste0("background:", if (identical(item$kind, "level")) item$color else "#f3f3f3", ";")
          ),
          div(
            class = "shared-style-summary-copy",
            tags$strong(item$display),
            tags$span(class = "text-muted", paste0(item$id, " · ", switch(item$kind, level="群・条件", axis_label="軸ラベル", legend_title="凡例タイトル", item$kind))),
            tags$span(class = "text-muted", paste0("使用中 ", length(used), " 箇所"))
          )
        )
      })
    )
  })

  observe({
    lib <- shared_style_normalize_library(shared_style_library())
    choices <- if (length(lib$items)) {
      stats::setNames(names(lib$items), vapply(lib$items, shared_style_item_label, character(1)))
    } else c("項目なし" = "")
    current <- as.character(isolate(input$shared_style_selected_id %||% ""))[1]
    selected <- if (current %in% unname(choices)) current else if (length(lib$items)) names(lib$items)[1] else ""
    updateSelectInput(session, "shared_style_selected_id", choices = choices, selected = selected)
  })

  output$shared_style_editor <- renderUI({
    lib <- shared_style_normalize_library(shared_style_library())
    id <- as.character(input$shared_style_selected_id %||% "")[1]
    item <- lib$items[[id]]
    if (!is.list(item)) return(tags$em("編集するLibrary項目を選択してください。"))
    is_level <- identical(item$kind, "level")
    manage_selected <- names(item$manage)[vapply(item$manage, isTRUE, logical(1))]
    div(
      class = "shared-style-editor-card",
      textInput("shared_style_edit_display", "表示名", value = item$display, width = "220px"),
      selectInput(
        "shared_style_edit_kind", "種類",
        choices = c("群・条件"="level", "軸ラベル"="axis_label", "凡例タイトル"="legend_title"),
        selected = item$kind, width = "140px"
      ),
      conditionalPanel(
        condition = "input.shared_style_edit_kind == 'level'",
        div(
          class = "shared-style-editor-style-row",
          colourpicker::colourInput("shared_style_edit_color", "Color / Fill", value = item$color, showColour = "both"),
          selectInput("shared_style_edit_shape", "Shape", choices = c("● 丸"=16,"▲ 三角"=17,"■ 四角"=15,"◆ ひし形"=18,"+ プラス"=3,"× クロス"=4,"○ 白丸"=1,"△ 白三角"=2,"□ 白四角"=0,"◇ 白ひし形"=5), selected = as.character(item$shape), width = "120px"),
          selectInput("shared_style_edit_linetype", "Line", choices = c("実線"="solid","破線"="dashed","点線"="dotted","一点鎖線"="dotdash","長い破線"="longdash","二重点線"="twodash"), selected = item$linetype, width = "120px")
        )
      ),
      checkboxGroupInput(
        "shared_style_edit_manage", "Libraryが管理する属性",
        choices = if (is_level) c("表示名"="display","Color"="color","Fill"="fill","Shape"="shape","Line type"="linetype") else c("表示名"="display"),
        selected = manage_selected, inline = TRUE
      ),
      actionButton("shared_style_save", "Libraryへ保存", class = "btn-sm btn-primary"),
      tags$p(class = "help-block", "internal idは作成後固定です。表示名を変更してもGraph bindingは維持されます。現行GraphではColor/Fillは同じcategorical colour treeを共有するため、1つの色として管理します。")
    )
  })

  observeEvent(input$shared_style_add, {
    id <- shared_style_safe_id(input$shared_style_new_id %||% "")
    display <- trimws(as.character(input$shared_style_new_display %||% "")[1])
    kind <- as.character(input$shared_style_new_kind %||% "level")[1]
    if (!nzchar(id)) {
      showNotification("internal idを入力してください。", type="warning")
      return()
    }
    lib <- shared_style_normalize_library(isolate(shared_style_library()))
    if (id %in% names(lib$items)) {
      showNotification("同じinternal idが既にあります。", type="warning")
      return()
    }
    if (!nzchar(display)) display <- id
    lib$items[[id]] <- shared_style_default_item(id, display, kind)
    shared_style_commit_library(lib, source = "library-add")
    updateSelectInput(session, "shared_style_selected_id", selected = id)
    updateTextInput(session, "shared_style_new_id", value = "")
    updateTextInput(session, "shared_style_new_display", value = "")
  }, ignoreInit = TRUE)

  observeEvent(input$shared_style_save, {
    id <- as.character(isolate(input$shared_style_selected_id %||% ""))[1]
    lib <- shared_style_normalize_library(isolate(shared_style_library()))
    item <- lib$items[[id]]
    if (!is.list(item)) return()
    kind <- as.character(input$shared_style_edit_kind %||% item$kind)[1]
    item$display <- as.character(input$shared_style_edit_display %||% item$display)[1]
    item$kind <- kind
    if (identical(kind, "level")) {
      item$color <- input$shared_style_edit_color %||% item$color
      # Current Graph rendering has one categorical colour tree, so v3.73.0
      # intentionally keeps portable Color/Fill definitions in lockstep.
      item$fill <- item$color
      item$shape <- input$shared_style_edit_shape %||% item$shape
      item$linetype <- input$shared_style_edit_linetype %||% item$linetype
    }
    manage <- as.character(input$shared_style_edit_manage %||% character(0))
    item$manage <- list(
      display = "display" %in% manage,
      color = identical(kind, "level") && "color" %in% manage,
      fill = identical(kind, "level") && "fill" %in% manage,
      shape = identical(kind, "level") && "shape" %in% manage,
      linetype = identical(kind, "level") && "linetype" %in% manage
    )
    lib$items[[id]] <- shared_style_normalize_item(item, id)
    shared_style_commit_library(lib, source = "library-edit")
  }, ignoreInit = TRUE)

  observeEvent(input$shared_style_delete, {
    id <- as.character(isolate(input$shared_style_selected_id %||% ""))[1]
    if (!nzchar(id)) return()
    lib <- shared_style_normalize_library(isolate(shared_style_library()))
    if (!id %in% names(lib$items)) return()
    lib$items[[id]] <- NULL
    shared_style_commit_library(lib, source = "library-delete")
  }, ignoreInit = TRUE)

  observeEvent(input$shared_style_import, {
    fi <- input$shared_style_import
    if (is.null(fi) || !nrow(fi)) return()
    imported <- tryCatch(jsonlite::read_json(fi$datapath, simplifyVector = FALSE), error = function(e) e)
    if (inherits(imported, "error")) {
      showNotification(paste0("Library Importに失敗しました: ", conditionMessage(imported)), type="error", duration=5)
      return()
    }
    incoming <- shared_style_normalize_library(imported)
    if (!length(incoming$items)) {
      showNotification("ImportファイルにLibrary項目がありません。", type="warning")
      return()
    }
    lib <- shared_style_normalize_library(isolate(shared_style_library()))
    for (id in names(incoming$items)) lib$items[[id]] <- incoming$items[[id]]
    shared_style_commit_library(lib, source = "library-import")
    showNotification(paste0("Shared LibraryをImportしました（", length(incoming$items), "項目）。bindingは変更していません。"), type="message")
  }, ignoreInit = TRUE)

  output$download_shared_style <- downloadHandler(
    filename = function() paste0("ggplot_shared_style_library_", Sys.Date(), ".json"),
    content = function(file) {
      jsonlite::write_json(
        shared_style_normalize_library(isolate(shared_style_library())),
        file, pretty=TRUE, auto_unbox=TRUE, null="null"
      )
    }
  )

  observeEvent(input$figure_shared_style_sync, {
    figure_shared_style_sync(isTRUE(input$figure_shared_style_sync))
    diag_log("SHARED-STYLE-FIGURE", paste0("auto_sync=", isTRUE(input$figure_shared_style_sync)))
  }, ignoreInit = TRUE)

  observeEvent(input$figure_shared_style_apply, {
    changed <- shared_style_apply_figure_states(isolate(shared_style_library()), reason = "manual-apply")
    if (length(changed)) showNotification(paste0("Shared LibraryをFigureの ", length(changed), " Graphへ反映します。"), type="message")
    else showNotification("Figure側に反映が必要なShared Style変更はありません。", type="message", duration=2)
  }, ignoreInit = TRUE)

