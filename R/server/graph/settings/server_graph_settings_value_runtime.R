# v3.73.2.29 — direct value editing / explicit Figure refresh from the external
# Graph Settings Manager.  GraphState and Figure-owned GraphState remain
# separate owners. No automatic Graph -> Figure following is introduced.

  graph_settings_manager_feedback <- function(ok, message, path = "", scope = "", value = NULL) {
    payload <- list(
      ok = isTRUE(ok),
      message = as.character(message %||% "")[1],
      path = as.character(path %||% "")[1],
      scope = as.character(scope %||% "")[1]
    )
    if (!is.null(value) && length(value)) {
      payload$value <- tryCatch(as.character(value[[1]]), error = function(e) "<unprintable>")
    }
    session$sendCustomMessage("graph-settings-manager-feedback", payload)
    invisible(payload)
  }

  graph_settings_manager_value_diag <- function(value) {
    if (is.null(value)) return("<NULL>")
    cls <- paste(class(value), collapse = "/")
    tp <- typeof(value)
    len <- length(value)
    txt <- tryCatch({
      x <- if (is.list(value) && length(value) == 1L) value[[1]] else value
      paste(utils::head(as.character(x), 3L), collapse = ",")
    }, error = function(e) "<unprintable>")
    paste0("type=", tp, " class=", cls, " length=", len, " value=", txt)
  }

  graph_settings_manager_normalize_input_value <- function(rec, value) {
    editor <- rec$editor %||% list()
    kind <- as.character(editor$kind %||% "")[1]
    fail <- function(message) list(ok = FALSE, value = NULL, message = message)
    pass <- function(value) list(ok = TRUE, value = value, message = "")

    if (!nzchar(kind)) return(fail("この設定は外部ウィンドウから直接編集できません。"))

    if (identical(kind, "boolean")) {
      if (is.logical(value) && length(value)) return(pass(isTRUE(value[[1]])))
      z <- tolower(trimws(as.character(value %||% "")[1]))
      if (z %in% c("true", "1", "on", "yes")) return(pass(TRUE))
      if (z %in% c("false", "0", "off", "no")) return(pass(FALSE))
      return(fail("ON / OFF の値として解釈できません。"))
    }

    if (identical(kind, "number")) {
      z <- suppressWarnings(as.numeric(value %||% NA_real_)[1])
      if (!is.finite(z)) return(fail("数値を入力してください。"))
      lo <- suppressWarnings(as.numeric(editor$min %||% NA_real_)[1])
      hi <- suppressWarnings(as.numeric(editor$max %||% NA_real_)[1])
      if (is.finite(lo) && z < lo) return(fail(paste0("最小値は ", lo, " です。")))
      if (is.finite(hi) && z > hi) return(fail(paste0("最大値は ", hi, " です。")))
      return(pass(z))
    }

    if (identical(kind, "axis_number")) {
      z <- trimws(as.character(value %||% "")[1])
      if (!nzchar(z)) return(pass(""))
      numeric_value <- suppressWarnings(as.numeric(z))
      if (!is.finite(numeric_value)) return(fail("Y軸範囲は数値、または空欄（自動）にしてください。"))
      return(pass(z))
    }

    if (identical(kind, "select")) {
      z <- as.character(value %||% "")[1]
      choices <- editor$choices %||% list()
      allowed <- vapply(choices, function(x) as.character(x$value %||% "")[1], character(1))
      if (!z %in% allowed) return(fail("選択肢にない値です。"))
      return(pass(z))
    }

    if (identical(kind, "text")) {
      z <- as.character(value %||% "")[1]
      if (!isTRUE(editor$allowEmpty %||% TRUE) && !nzchar(trimws(z))) {
        return(fail("空欄にはできません。"))
      }
      return(pass(z))
    }

    fail("未対応の編集形式です。")
  }

  graph_settings_manager_apply_graph_value <- function(path, value, target_ids,
                                                        reason = "settings-manager-direct") {
    changed <- character(0)
    render_changed <- character(0)
    for (id in unique(as.character(target_ids %||% character(0)))) {
      if (!nzchar(id) || !cache_has(id)) next
      old <- cache_get(id)
      if (!is.list(old)) next
      new <- graph_settings_manager_set_path(old, path, value)
      result <- graph_settings_manager_commit_exact(id, new, source = reason)
      if (isTRUE(result$changed)) changed <- c(changed, id)
      if (isTRUE(result$render)) render_changed <- c(render_changed, id)
    }
    graph_settings_manager_finalize_graph_changes(render_changed, reason = reason)
    list(changed = unique(changed), render_changed = unique(render_changed))
  }

  graph_settings_manager_figure_base_state <- function(id) {
    id <- as.character(id %||% "")[1]
    states <- isolate(figure_edit_states())
    st <- states[[id]]
    if (is.list(st)) return(list(state = st, source = "figure-owned"))
    if (cache_has(id)) {
      st <- cache_get(id)
      if (is.list(st)) return(list(state = st, source = "graph-canonical"))
    }
    list(state = NULL, source = "missing")
  }

  graph_settings_manager_reload_visible_figure_editor <- function(ids, reason) {
    ids <- unique(as.character(ids %||% character(0)))
    owner <- as.character(isolate(figure_editing_graph()) %||% "")[1]
    if (!nzchar(owner) || !owner %in% ids) return(invisible(FALSE))
    if (!isTRUE(tryCatch(figure_workspace_is_active(), error = function(e) FALSE))) return(invisible(FALSE))
    if (!isTRUE(isolate(figure_single_editor_show_when_ready()))) return(invisible(FALSE))
    state <- isolate(figure_edit_states())[[owner]]
    if (!is.list(state)) return(invisible(FALSE))
    session$onFlushed(function() {
      ensure_figure_editor(
        owner,
        force_reload = TRUE,
        preserve_current = FALSE,
        show_when_ready = TRUE,
        state_override = state
      )
    }, once = TRUE)
    diag_log("GRAPH-SETTINGS-FIGURE", paste0("visible Figure editor resync queued reason=", reason), id = owner)
    invisible(TRUE)
  }

  graph_settings_manager_apply_figure_value <- function(path, value, target_ids,
                                                         reason = "settings-manager-figure-value") {
    main_ids <- tryCatch(figure_main_panel_source_ids(), error = function(e) character(0))
    requested <- intersect(unique(as.character(target_ids %||% character(0))), main_ids)
    requested <- requested[nzchar(requested)]
    queued <- character(0)
    changed <- character(0)
    base_sources <- character(0)

    for (id in requested) {
      base <- graph_settings_manager_figure_base_state(id)
      if (!is.list(base$state)) next
      new <- graph_settings_manager_set_path(base$state, path, value)
      if (!identical(base$state, new)) changed <- c(changed, id)
      store_figure_edit_state(id, new, reason = reason)
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
      if (!identical(rev, FALSE) && is.finite(rev_num) && rev_num > 0L) {
        queued <- c(queued, id)
        base_sources <- c(base_sources, paste0(id, ":", base$source))
      }
    }

    graph_settings_manager_reload_visible_figure_editor(queued, reason)
    diag_log(
      "GRAPH-SETTINGS-FIGURE",
      paste0(
        "VALUE path=", path,
        " requested={", paste(requested, collapse=","), "}",
        " queued={", paste(unique(queued), collapse=","), "}",
        " changed={", paste(unique(changed), collapse=","), "}",
        " bases={", paste(base_sources, collapse=","), "}",
        " graph_state_unchanged=TRUE"
      )
    )
    list(requested = requested, queued = unique(queued), changed = unique(changed))
  }

  graph_settings_manager_refresh_figure_from_graph <- function(target_ids,
                                                                reason = "settings-manager-figure-refresh") {
    main_ids <- tryCatch(figure_main_panel_source_ids(), error = function(e) character(0))
    requested <- intersect(unique(as.character(target_ids %||% character(0))), main_ids)
    requested <- requested[nzchar(requested)]
    queued <- character(0)

    for (id in requested) {
      if (!cache_has(id)) next
      st <- cache_get(id)
      if (!is.list(st)) next
      if (exists("cancel_figure_source_snapshot_jobs", mode = "function", inherits = TRUE)) {
        cancel_figure_source_snapshot_jobs(id, reason = paste0(reason, "-replace"))
      }
      rev <- request_figure_source_snapshot(
        id,
        reason = reason,
        import_editor_state = TRUE,
        state_override = st,
        target_type = "main"
      )
      rev_num <- suppressWarnings(as.integer(rev %||% NA_integer_)[1])
      if (!identical(rev, FALSE) && is.finite(rev_num) && rev_num > 0L) queued <- c(queued, id)
    }

    graph_settings_manager_reload_visible_figure_editor(queued, reason)
    diag_log(
      "GRAPH-SETTINGS-FIGURE",
      paste0(
        "REFRESH-FROM-GRAPH requested={", paste(requested, collapse=","), "}",
        " queued={", paste(unique(queued), collapse=","), "}",
        " path=DIRECT-STATE persisted_svg_bypass=TRUE graph_state_unchanged=TRUE"
      )
    )
    unique(queued)
  }

  observeEvent(input$graph_settings_manager_value_apply, {
    req <- input$graph_settings_manager_value_apply %||% list()
    path <- as.character(req$path %||% "")[1]
    scope <- as.character(req$scope %||% "graph")[1]
    if (!scope %in% c("graph", "figure", "both")) scope <- "graph"
    source_id <- as.character(req$sourceId %||% "")[1]
    target_ids <- unique(as.character(unlist(req$targetIds %||% character(0), use.names = FALSE)))
    target_ids <- target_ids[nzchar(target_ids)]
    meta_ids <- as.character(isolate(graph_meta())$id %||% character(0))
    target_ids <- intersect(target_ids, meta_ids)
    rec <- graph_settings_manager_row_for_path(path)

    if (!is.list(rec) || !isTRUE(rec$apply) || !length(target_ids)) {
      msg <- "編集対象または適用先が不正です。"
      diag_log("GRAPH-SETTINGS-DIRECT", paste0("REJECT path=", path, " scope=", scope, " reason=invalid-request"), id = source_id)
      graph_settings_manager_feedback(FALSE, msg, path, scope, req$value)
      showNotification(msg, type = "warning")
      return()
    }

    normalized <- graph_settings_manager_normalize_input_value(rec, req$value)
    if (!isTRUE(normalized$ok)) {
      msg <- normalized$message %||% "値を適用できません。"
      diag_log(
        "GRAPH-SETTINGS-DIRECT",
        paste0(
          "REJECT path=", path, " scope=", scope,
          " reason=value-invalid message=", msg,
          " ", graph_settings_manager_value_diag(req$value)
        ),
        id = source_id
      )
      graph_settings_manager_feedback(FALSE, msg, path, scope, req$value)
      showNotification(msg, type = "warning", duration = 4)
      return()
    }

    graph_result <- list(changed = character(0), render_changed = character(0))
    figure_result <- list(queued = character(0), changed = character(0))
    if (scope %in% c("graph", "both")) {
      graph_result <- graph_settings_manager_apply_graph_value(
        path, normalized$value, target_ids, reason = "settings-manager-direct"
      )
    }
    if (scope %in% c("figure", "both")) {
      figure_result <- graph_settings_manager_apply_figure_value(
        path, normalized$value, target_ids, reason = "settings-manager-figure-value"
      )
    }

    diag_log(
      "GRAPH-SETTINGS-DIRECT",
      paste0(
        "DONE path=", path,
        " scope=", scope,
        " source=", source_id,
        " targets={", paste(target_ids, collapse=","), "}",
        " graph_changed={", paste(graph_result$changed, collapse=","), "}",
        " figure_queued={", paste(figure_result$queued, collapse=","), "}"
      ),
      id = if (nzchar(source_id)) source_id else NULL
    )

    graph_n <- length(graph_result$changed)
    figure_n <- length(figure_result$queued)
    msg <- switch(
      scope,
      graph = paste0(rec$label, " をGraph ", graph_n, "件へ反映しました。"),
      figure = paste0(rec$label, " をFigure ", figure_n, "件へ反映しました（Graphは変更していません）。"),
      both = paste0(rec$label, " をGraph ", graph_n, "件 / Figure ", figure_n, "件へ反映しました。")
    )
    graph_settings_manager_feedback(TRUE, msg, path, scope, normalized$value)
    showNotification(msg, type = "message", duration = 4)
  }, ignoreInit = TRUE)

  observeEvent(input$graph_settings_manager_figure_refresh, {
    req <- input$graph_settings_manager_figure_refresh %||% list()
    ids <- unique(as.character(unlist(req$targetIds %||% character(0), use.names = FALSE)))
    ids <- ids[nzchar(ids)]
    if (!length(ids)) {
      showNotification("Figure更新対象のGraphを選択してください。", type = "message")
      return()
    }
    queued <- graph_settings_manager_refresh_figure_from_graph(ids)
    if (length(queued)) {
      msg <- paste0("選択中の ", length(queued), " Graphを現在のGraphStateからFigureへ更新します。")
      graph_settings_manager_feedback(TRUE, msg, scope = "figure-refresh")
      showNotification(msg, type = "message", duration = 4)
    } else {
      msg <- "選択Graphは現在のFigure main panelにありません。"
      graph_settings_manager_feedback(FALSE, msg, scope = "figure-refresh")
      showNotification(msg, type = "message", duration = 3)
    }
  }, ignoreInit = TRUE)
