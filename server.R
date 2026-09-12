shinyServer(function(input, output, session) {

  # ------------------------------------------------------------------
  # Graph registry
  # ------------------------------------------------------------------
  modules <- new.env(parent = emptyenv())

  # 未初期化Graphの保存stateを保持する。
  # 各要素は list(state = <saved graph state>) として持つことで、
  # state=NULLとの区別もつけられる。
  graph_state_cache <- reactiveVal(list())

  # Graph間・Project間で使う一時的な「書式クリップボード」。
  # Project stateとは独立しているため、同じShiny session内なら
  # Project Aでコピー -> Project Bで貼り付け ができる。
  style_clipboard <- reactiveVal(NULL)

  graph_meta <- reactiveVal(data.frame(
    id = "g001", name = "Graph 1", stringsAsFactors = FALSE
  ))
  active_graph <- reactiveVal("g001")
  id_counter <- reactiveVal(1L)

  # 起動時Graph 1だけは最初からmoduleを持つ。
  modules[["g001"]] <- graphServer("g001", initial_state = NULL, style_clipboard = style_clipboard)

  # ------------------------------------------------------------------
  # Project / Graph restore status
  # ------------------------------------------------------------------
  restore_status <- reactiveVal("idle")       # idle / restoring / complete
  restore_kind <- reactiveVal("project")      # project / graph
  restore_target <- reactiveVal(NULL)
  project_file_read <- reactiveVal(FALSE)
  project_save_destination_available <- reactiveVal(FALSE)

  # 保存先記憶は表示名ではなくProject UUIDをキーにする。
  new_project_uuid <- function() {
    b <- sample.int(256L, 16L, replace = TRUE) - 1L
    b[7] <- bitwOr(bitwAnd(b[7], 15L), 64L)
    b[9] <- bitwOr(bitwAnd(b[9], 63L), 128L)
    h <- sprintf("%02x", b)
    paste0(
      paste0(h[1:4], collapse = ""), "-",
      paste0(h[5:6], collapse = ""), "-",
      paste0(h[7:8], collapse = ""), "-",
      paste0(h[9:10], collapse = ""), "-",
      paste0(h[11:16], collapse = "")
    )
  }

  valid_project_uuid <- function(x) {
    x <- as.character(x %||% "")
    length(x) == 1L && grepl(
      "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$",
      x
    )
  }

  project_uuid <- reactiveVal(new_project_uuid())
  project_uuid_save_override <- reactiveVal(NULL)
  project_remember_pref <- reactiveVal(FALSE)
  project_name_save_override <- reactiveVal(NULL)

  # Project/未初期化Graphの復元中は、新panelを完成まで画面へ出さない。
  pending_display_graph <- reactiveVal(NULL)
  obsolete_panels <- reactiveVal(character(0))

  # ------------------------------------------------------------------
  # Export preparation
  # ------------------------------------------------------------------
  export_queue <- reactiveVal(character(0))
  export_prepare_active <- reactiveVal(FALSE)

  safe_name <- function(x, fallback = "Graph") {
    x <- trimws(as.character(x %||% ""))
    if (!nzchar(x)) x <- fallback
    gsub("[\\/:*?\"<>|]+", "_", x)
  }

  next_id <- function() {
    n <- isolate(id_counter()) + 1L
    id_counter(n)
    sprintf("g%03d", n)
  }

  module_exists <- function(id) {
    !is.null(modules[[id]])
  }

  cache_has <- function(id) {
    id %in% names(isolate(graph_state_cache()))
  }

  cache_get <- function(id) {
    ca <- isolate(graph_state_cache())
    if (!id %in% names(ca)) return(NULL)
    ca[[id]]$state
  }

  cache_set <- function(id, state) {
    ca <- isolate(graph_state_cache())
    ca[[id]] <- list(state = state)
    graph_state_cache(ca)
    invisible(TRUE)
  }

  cache_remove <- function(id) {
    ca <- isolate(graph_state_cache())
    ca[[id]] <- NULL
    graph_state_cache(ca)
    invisible(TRUE)
  }

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
          "Shiny.setInputValue('graph_click', '%s', {priority:'event'});",
          id
        ),
        ondblclick = sprintf(
          "Shiny.setInputValue('graph_rename_dblclick', '%s', {priority:'event'});",
          id
        ),
        title = "クリック: 切替 / ダブルクリック: 名前変更",
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

  # ------------------------------------------------------------------
  # Lazy module creation
  # ------------------------------------------------------------------
  instantiate_graph <- function(id, context = c("display", "export")) {
    context <- match.arg(context)
    meta <- isolate(graph_meta())
    if (!id %in% meta$id) return(invisible(FALSE))
    if (module_exists(id)) return(invisible(TRUE))

    initial_state <- if (cache_has(id)) cache_get(id) else NULL

    insertUI(
      selector = "#graph_panels",
      where = "beforeEnd",
      ui = div(
        id = paste0("panel_", id),
        class = "graph-module-panel",
        style = "display:none;",
        graphUI(id)
      ),
      immediate = TRUE
    )

    modules[[id]] <- graphServer(id, initial_state = initial_state, style_clipboard = style_clipboard)

    if (!is.null(initial_state)) {
      mod <- modules[[id]]
      if (!is.null(mod) && is.function(mod$activate)) mod$activate()
    }

    invisible(TRUE)
  }

  show_graph <- function(id, kind = "graph") {
    meta <- isolate(graph_meta())
    if (!id %in% meta$id) return(invisible(FALSE))

    old_active <- isolate(active_graph())
    needs_restore <- !module_exists(id) && cache_has(id)

    if (needs_restore) {
      restore_kind(kind)
      restore_target(id)
      restore_status("restoring")
      pending_display_graph(id)

      if (!identical(kind, "project")) project_file_read(FALSE)

      # panelはdisplay:noneで生成して復元を開始する。
      # この時点では現在の完成済みGraphを隠さない。
      instantiate_graph(id, context = "display")
      mod <- modules[[id]]
      if (!is.null(mod) && is.function(mod$activate)) mod$activate()

      return(invisible(TRUE))
    }

    # 新規Graph / 既に一度復元済みGraphは即時切替。
    for (z in meta$id) {
      if (module_exists(z)) shinyjs::hide(paste0("panel_", z), anim = FALSE)
    }
    shinyjs::show(paste0("panel_", id), anim = FALSE)
    active_graph(id)
    pending_display_graph(NULL)

    mod <- modules[[id]]
    if (!is.null(mod) && is.function(mod$activate)) mod$activate()

    if (!identical(kind, "project")) {
      restore_status("idle")
      restore_target(NULL)
    }

    invisible(TRUE)
  }

  create_graph <- function(name, initial_state = NULL, select = TRUE) {
    id <- next_id()

    meta <- isolate(graph_meta())
    meta <- rbind(
      meta,
      data.frame(id = id, name = name, stringsAsFactors = FALSE)
    )
    graph_meta(meta)

    if (!is.null(initial_state)) cache_set(id, initial_state)

    # 新規/複製は明示操作なので、その場でmoduleを生成する。
    instantiate_graph(id, context = "display")
    refresh_export_choices()

    if (select) show_graph(id, kind = "graph")
    id
  }

  # ------------------------------------------------------------------
  # Restore progress
  # ------------------------------------------------------------------
  observe({
    if (!identical(restore_status(), "restoring")) return()

    id <- restore_target()
    if (is.null(id) || !nzchar(id)) return()

    mod <- modules[[id]]
    if (is.null(mod)) return()

    ready <- isTRUE(mod$ready())

    # Project復元の完了条件は「設定/stateの復元完了」にする。
    # hidden panel内のPlot描画(draw)を待つと、Bootstrapのdisplay:none中に
    # plotOutputサイズが確定せず85%で待ち続けるため、drawnは条件にしない。
    if (ready) {
      target <- isolate(pending_display_graph())

      if (!is.null(target) && identical(target, id)) {
        meta <- isolate(graph_meta())

        # stateが完成した時点で新Graphを先に表示する。
        # Plotは表示後の正常なbrowserサイズで描画させる。
        for (z in meta$id) {
          if (module_exists(z)) shinyjs::hide(paste0("panel_", z), anim = FALSE)
        }
        shinyjs::show(paste0("panel_", id), anim = FALSE)
        active_graph(id)
        pending_display_graph(NULL)

        # 新しいGraphを表示してから前Projectのpanelを削除。
        old_ids <- isolate(obsolete_panels())
        if (length(old_ids)) {
          for (old_id in old_ids) {
            removeUI(selector = paste0("#panel_", old_id), immediate = TRUE)
          }
          obsolete_panels(character(0))
        }
      }

      restore_status("complete")

      # Project/Graph復元直後は保存済み状態なのでdirtyを解除。
    }
  })

  output$project_load_progress <- renderUI({
    st <- restore_status()
    if (identical(st, "idle")) return(NULL)

    kind <- restore_kind()
    id <- restore_target()
    mod <- if (!is.null(id)) modules[[id]] else NULL

    ready <- !is.null(mod) && isTRUE(mod$ready())

    # hidden Plot描画は復元完了条件にしない。
    # readyになったらGraphを表示して100%へ進む。
    graph_pct <- if (ready) {
      100
    } else if (!is.null(mod)) {
      45
    } else {
      10
    }

    if (identical(st, "complete")) {
      return(
        div(
          class = "restore-done",
          HTML("&#10003;&nbsp;"),
          if (identical(kind, "project")) "Project・Graph復元完了" else "Graph復元完了"
        )
      )
    }

    parts <- list()

    if (identical(kind, "project")) {
      parts <- c(parts, list(
        div(
          class = "project-progress-line",
          div(class = "project-progress-label", "Projectファイル"),
          div(
            class = "progress compact-progress",
            div(
              class = "progress-bar progress-bar-success",
              role = "progressbar",
              style = "width:100%;",
              "100%"
            )
          )
        )
      ))
    }

    parts <- c(parts, list(
      div(
        class = "project-progress-line",
        div(
          class = "project-progress-label",
          if (identical(kind, "project")) "表示Graphを復元しています…" else "Graphを復元しています…"
        ),
        div(
          class = "progress compact-progress",
          div(
            class = "progress-bar progress-bar-striped active",
            role = "progressbar",
            style = paste0("width:", graph_pct, "%;"),
            paste0(graph_pct, "%")
          )
        )
      )
    ))

    tagList(parts)
  })

  # ------------------------------------------------------------------
  # Graph actions
  # ------------------------------------------------------------------
  observeEvent(input$graph_click, {
    id <- as.character(input$graph_click %||% "")
    if (!nzchar(id)) return()
    if (!identical(id, isolate(active_graph()))) show_graph(id, kind = "graph")
  }, ignoreInit = TRUE)

  pending_new_graph_default <- reactiveVal(NULL)

  next_graph_default_name <- function(meta) {
    existing <- if (!is.null(meta) && nrow(meta)) as.character(meta$name) else character(0)
    hits <- regmatches(existing, regexec("^Graph ([0-9]+)$", existing))
    nums <- suppressWarnings(vapply(
      hits,
      function(z) if (length(z) >= 2L) as.integer(z[2]) else NA_integer_,
      integer(1)
    ))
    nums <- nums[is.finite(nums)]
    paste0("Graph ", if (length(nums)) max(nums) + 1L else 1L)
  }

  show_new_graph_modal <- function() {
    meta <- isolate(graph_meta())
    default_nm <- next_graph_default_name(meta)
    pending_new_graph_default(default_nm)

    showModal(modalDialog(
      title = "新しいGraph",
      textInput(
        "new_graph_name",
        "Graph名",
        value = default_nm
      ),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("create_graph_confirm", "作成", class = "btn-primary")
      ),
      easyClose = TRUE
    ))

    session$onFlushed(function() {
      session$sendCustomMessage(
        "focus-select-input",
        list(id = "new_graph_name")
      )
    }, once = TRUE)
  }

  observeEvent(input$graph_add, {
    show_new_graph_modal()
  })

  create_new_graph_from_modal <- function() {
    default_nm <- isolate(pending_new_graph_default())
    if (is.null(default_nm) || !nzchar(default_nm)) {
      meta <- isolate(graph_meta())
      default_nm <- next_graph_default_name(meta)
    }

    nm <- trimws(input$new_graph_name %||% "")
    if (!nzchar(nm)) nm <- default_nm

    removeModal()
    pending_new_graph_default(NULL)

    create_graph(
      nm,
      initial_state = NULL,
      select = TRUE
    )
  }

  observeEvent(input$create_graph_confirm, {
    create_new_graph_from_modal()
  })

  observeEvent(input$new_graph_enter, {
    if (isTRUE(input$new_graph_enter)) {
      create_new_graph_from_modal()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$graph_duplicate, {
    id <- isolate(active_graph())
    mod <- modules[[id]]
    if (is.null(mod) || !isTRUE(isolate(mod$ready()))) {
      showNotification("現在Graphの準備が終わってから複製してください。", type = "warning")
      return()
    }

    state <- tryCatch(isolate(mod$state()), error = function(e) NULL)
    if (is.null(state)) {
      showNotification("現在Graphの状態を取得できませんでした。", type = "error")
      return()
    }

    meta <- isolate(graph_meta())
    nm <- meta$name[match(id, meta$id)]
    create_graph(paste0(nm, " copy"), initial_state = state, select = TRUE)
  })

  rename_target_graph <- reactiveVal(NULL)

  show_rename_graph_modal <- function(id) {
    meta <- isolate(graph_meta())
    if (is.null(id) || !id %in% meta$id) return(invisible(FALSE))

    # ダブルクリック対象をactiveにしてから名前変更する。
    if (!identical(id, isolate(active_graph()))) {
      show_graph(id, kind = "graph")
    }

    nm <- meta$name[match(id, meta$id)]
    rename_target_graph(id)

    showModal(modalDialog(
      title = "Graph名を変更",
      textInput("rename_graph_text", "Graph名", value = nm),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("rename_graph_confirm", "変更", class = "btn-primary")
      ),
      easyClose = TRUE
    ))

    session$onFlushed(function() {
      session$sendCustomMessage(
        "focus-select-input",
        list(id = "rename_graph_text")
      )
    }, once = TRUE)

    invisible(TRUE)
  }

  observeEvent(input$graph_rename, {
    show_rename_graph_modal(isolate(active_graph()))
  })

  observeEvent(input$graph_rename_dblclick, {
    id <- as.character(input$graph_rename_dblclick %||% "")
    if (nzchar(id)) show_rename_graph_modal(id)
  }, ignoreInit = TRUE)

  apply_graph_rename <- function() {
    nm <- trimws(input$rename_graph_text %||% "")
    if (!nzchar(nm)) return(invisible(FALSE))

    meta <- isolate(graph_meta())
    id <- isolate(rename_target_graph())
    if (is.null(id) || !id %in% meta$id) {
      id <- isolate(active_graph())
    }
    if (is.null(id) || !id %in% meta$id) return(invisible(FALSE))

    meta$name[match(id, meta$id)] <- nm
    graph_meta(meta)
    refresh_export_choices()
    rename_target_graph(NULL)
    removeModal()
    invisible(TRUE)
  }

  observeEvent(input$rename_graph_confirm, {
    apply_graph_rename()
  })

  observeEvent(input$rename_graph_enter, {
    if (isTRUE(input$rename_graph_enter)) {
      apply_graph_rename()
    }
  }, ignoreInit = TRUE)

  observeEvent(input$graph_delete, {
    meta <- isolate(graph_meta())
    id <- isolate(active_graph())

    if (nrow(meta) <= 1) {
      showNotification("Projectには最低1つのGraphが必要です。", type = "warning")
      return()
    }

    nm <- meta$name[match(id, meta$id)]
    showModal(modalDialog(
      title = "Graphを削除",
      paste0("「", nm, "」を削除しますか？"),
      footer = tagList(
        modalButton("キャンセル"),
        actionButton("delete_graph_confirm", "削除", class = "btn-danger")
      ),
      easyClose = TRUE
    ))
  })

  observeEvent(input$delete_graph_confirm, {
    meta <- isolate(graph_meta())
    id <- isolate(active_graph())
    if (nrow(meta) <= 1) return()

    pos <- match(id, meta$id)

    if (module_exists(id)) {
      removeUI(selector = paste0("#panel_", id), immediate = TRUE)
      modules[[id]] <- NULL
    }
    cache_remove(id)

    meta <- meta[meta$id != id, , drop = FALSE]
    graph_meta(meta)

    new_pos <- min(pos, nrow(meta))
    new_id <- meta$id[new_pos]

    refresh_export_choices()
    show_graph(new_id, kind = "graph")
    removeModal()
  })

  # ------------------------------------------------------------------
  # Project save / load
  # ------------------------------------------------------------------
  graph_state_for_save <- function(id) {
    mod <- modules[[id]]

    if (!is.null(mod) && isTRUE(isolate(mod$ready()))) {
      live <- tryCatch(isolate(mod$state()), error = function(e) NULL)
      if (!is.null(live)) return(live)
    }

    if (cache_has(id)) return(cache_get(id))
    NULL
  }

  build_project <- function() {
    meta <- isolate(graph_meta())
    graphs <- vector("list", nrow(meta))
    names(graphs) <- meta$id

    for (i in seq_len(nrow(meta))) {
      id <- meta$id[i]
      graphs[[id]] <- list(
        name = meta$name[i],
        state = graph_state_for_save(id)
      )
    }

    list(
      version = "3.3.38-zero-slider-minima",
      app = "ggplot GUI",
      project_uuid = {
        uo <- shiny::isolate(project_uuid_save_override())
        if (!is.null(uo) && valid_project_uuid(uo)) as.character(uo) else shiny::isolate(project_uuid())
      },
      project_name = {
        nm_override <- shiny::isolate(project_name_save_override())
        if (!is.null(nm_override) && nzchar(as.character(nm_override))) {
          as.character(nm_override)
        } else {
          shiny::isolate(input$project_name)
        }
      },
      active_graph = isolate(active_graph()),
      project_options = list(
        remember_save_destination = isTRUE(shiny::isolate(project_remember_pref()))
      ),
      graphs = graphs
    )
  }

  project_filename <- function() {
    nm_override <- shiny::isolate(project_name_save_override())
    project_name_now <- if (!is.null(nm_override) &&
                            nzchar(as.character(nm_override))) {
      as.character(nm_override)
    } else {
      shiny::isolate(input$project_name)
    }

    paste0(
      safe_name(
        project_name_now,
        paste0("ggplot_project_", Sys.Date())
      ),
      ".ggplotproj"
    )
  }

  write_project_file <- function(file) {
    saveRDS(
      build_project(),
      file = file,
      compress = "gzip",
      version = 3
    )
  }

  output$download_project_all <- downloadHandler(
    filename = function() project_filename(),
    contentType = "application/octet-stream",
    content = function(file) write_project_file(file)
  )

  # Browser側のFile System Access APIが取得するための非表示endpoint。
  # display:none の中にあっても必ず有効なRDSを生成できるよう、
  # suspendWhenHidden=FALSE を明示する。
  output$download_project_overwrite_payload <- downloadHandler(
    filename = function() project_filename(),
    contentType = "application/octet-stream",
    content = function(file) write_project_file(file)
  )

  outputOptions(
    output,
    "download_project_overwrite_payload",
    suspendWhenHidden = FALSE
  )
  outputOptions(
    output,
    "download_project_all",
    suspendWhenHidden = FALSE
  )

  observeEvent(input$save_project_as_all, {
    filename_now <- project_filename()
    project_name_now <- as.character(input$project_name %||% "MyProject")
    old_uuid <- isolate(project_uuid())
    candidate_uuid <- new_project_uuid()
    project_uuid_save_override(candidate_uuid)
    remember_now <- isTRUE(project_remember_pref())

    session$onFlushed(function() {
      session$sendCustomMessage(
        "prepare-project-save-as",
        list(
          fallbackLinkId = "download_project_all",
          filename = filename_now,
          projectName = project_name_now,
          projectKey = candidate_uuid,
          oldProjectKey = old_uuid,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$project_save_as_target, {
    tg <- input$project_save_as_target
    if (is.null(tg)) return()

    selected_name <- as.character(tg$projectName %||% "")
    selected_uuid <- as.character(tg$projectKey %||% "")
    if (!nzchar(selected_name)) return()
    if (!valid_project_uuid(selected_uuid)) selected_uuid <- isolate(project_uuid_save_override())
    if (!valid_project_uuid(selected_uuid)) selected_uuid <- new_project_uuid()

    project_uuid_save_override(selected_uuid)
    project_name_save_override(selected_name)
    updateTextInput(session, "project_name", value = selected_name)
    old_uuid <- isolate(project_uuid())
    remember_now <- isTRUE(tg$remember)

    session$onFlushed(function() {
      session$sendCustomMessage(
        "commit-project-save-as",
        list(
          linkId = "download_project_overwrite_payload",
          filename = paste0(safe_name(selected_name, selected_name), ".ggplotproj"),
          projectName = selected_name,
          projectKey = selected_uuid,
          oldProjectKey = old_uuid,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$overwrite_project_all, {
    filename_now <- project_filename()
    project_key_now <- isolate(project_uuid())
    remember_now <- isTRUE(project_remember_pref())

    session$onFlushed(function() {
      session$sendCustomMessage(
        "overwrite-project-file",
        list(
          linkId = "download_project_overwrite_payload",
          filename = filename_now,
          projectKey = project_key_now,
          remember = remember_now
        )
      )
    }, once = TRUE)
  }, ignoreInit = TRUE)

  observeEvent(input$project_save_destination_available, {
    z <- input$project_save_destination_available
    if (is.null(z)) return()
    current_key <- isolate(project_uuid())
    response_key <- as.character(z$projectKey %||% "")
    if (nzchar(response_key) && !identical(response_key, current_key)) return()
    project_save_destination_available(isTRUE(z$available) && isTRUE(project_remember_pref()))
  }, ignoreInit = TRUE)

  observeEvent(input$project_remember_manual_state, {
    z <- input$project_remember_manual_state
    if (is.null(z)) return()
    remember_now <- isTRUE(z$value)
    project_remember_pref(remember_now)
    project_key <- isolate(project_uuid())
    if (remember_now) {
      session$sendCustomMessage("check-project-save-destination", list(projectKey = project_key, remember = TRUE))
    } else {
      project_save_destination_available(FALSE)
      session$sendCustomMessage("forget-project-save-destination", list(projectKey = project_key))
    }
  }, ignoreInit = TRUE)

  observeEvent(input$remember_project_save_destination, {
    remember_now <- isTRUE(input$remember_project_save_destination)
    project_remember_pref(remember_now)
    project_key <- isolate(project_uuid())
    if (remember_now) {
      session$sendCustomMessage("check-project-save-destination", list(projectKey = project_key, remember = TRUE))
    } else {
      project_save_destination_available(FALSE)
      session$sendCustomMessage("forget-project-save-destination", list(projectKey = project_key))
    }
  }, ignoreInit = FALSE)

  observeEvent(input$project_save_as_status, {
    st <- input$project_save_as_status
    if (is.null(st)) return()

    pending_uuid <- isolate(project_uuid_save_override())
    project_name_save_override(NULL)
    project_uuid_save_override(NULL)

    if (isTRUE(st$ok)) {
      saved_uuid <- as.character(st$projectKey %||% pending_uuid %||% "")
      if (valid_project_uuid(saved_uuid)) project_uuid(saved_uuid)
      saved_project_name <- as.character(st$projectName %||% "")
      if (nzchar(saved_project_name)) {
        updateTextInput(session, "project_name", value = saved_project_name)
        session$sendCustomMessage(
          "set-project-name-input",
          list(name = saved_project_name)
        )
      }

      if (isTRUE(st$remembered)) {
        project_remember_pref(TRUE)
        project_save_destination_available(TRUE)
      } else {
        # Session overwrite works, but persistent destination storage remains unavailable
        # because "保存先を記憶する" is OFF.
        project_save_destination_available(FALSE)
      }

      msg <- paste0(
        "Projectを保存しました: ",
        st$name %||% project_filename()
      )
      if (isTRUE(st$remembered)) {
        msg <- paste0(msg, "（保存先を記憶）")
      }

      showNotification(
        msg,
        type = "message",
        duration = 3
      )

    } else if (isTRUE(st$fallback)) {
      fallback_uuid <- as.character(st$projectKey %||% pending_uuid %||% "")
      if (valid_project_uuid(fallback_uuid)) project_uuid(fallback_uuid)
      showNotification(
        st$message %||% "通常の保存へ切り替えました。",
        type = "warning",
        duration = 4
      )
    } else if (isTRUE(st$cancelled)) {
      invisible(NULL)
    } else {
      showNotification(
        paste0(
          "Projectの保存に失敗しました: ",
          st$message %||% "不明なエラー"
        ),
        type = "error",
        duration = 5
      )
    }
  }, ignoreInit = TRUE)

  observeEvent(input$project_overwrite_status, {
    st <- input$project_overwrite_status
    if (is.null(st)) return()

    if (isTRUE(st$ok)) {
      if (isTRUE(st$remembered)) {
        project_remember_pref(TRUE)
        project_save_destination_available(TRUE)
      }

      msg <- paste0(
        "Projectを上書き保存しました: ",
        st$name %||% project_filename()
      )
      if (isTRUE(st$remembered)) {
        msg <- paste0(msg, "（保存先を記憶）")
      }
      showNotification(
        msg,
        type = "message",
        duration = 2
      )
    } else if (isTRUE(st$fallback)) {
      showNotification(
        st$message %||% "通常の保存へ切り替えました。",
        type = "warning",
        duration = 4
      )
    } else {
      showNotification(
        paste0("Projectの上書き保存に失敗しました: ", st$message %||% "不明なエラー"),
        type = "error",
        duration = 5
      )
    }
  }, ignoreInit = TRUE)


  project_read_error <- reactiveVal(NULL)

  read_project_file <- function(path) {
    project_read_error(NULL)

    rds_error <- NULL
    cfg <- tryCatch(
      readRDS(path),
      error = function(e) {
        rds_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cfg)) return(cfg)

    json_error <- NULL
    cfg <- tryCatch(
      jsonlite::read_json(path, simplifyVector = FALSE),
      error = function(e) {
        json_error <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.null(cfg)) return(cfg)

    project_read_error(
      paste0(
        "RDS: ", rds_error %||% "unknown",
        " / JSON: ", json_error %||% "unknown"
      )
    )
    NULL
  }

  observeEvent(input$upload_project_all, {
    req(input$upload_project_all$datapath)

    restore_status("idle")
    restore_target(NULL)
    pending_display_graph(NULL)
    project_file_read(FALSE)
    export_queue(character(0))
    export_prepare_active(FALSE)

    cfg <- read_project_file(input$upload_project_all$datapath)

    if (is.null(cfg)) {
      detail <- isolate(project_read_error())
      if (!is.null(detail) && nzchar(detail)) {
        showNotification(
          paste0("Project読込エラー: ", detail),
          type = "error",
          duration = 10
        )
      }
    }

    shiny::validate(
      shiny::need(!is.null(cfg), "Projectを読み込めませんでした。")
    )
    project_file_read(TRUE)

    loaded_uuid <- as.character(cfg$project_uuid %||% "")
    uuid_was_missing <- !valid_project_uuid(loaded_uuid)
    if (uuid_was_missing) {
      loaded_uuid <- new_project_uuid()
      showNotification(
        "旧ProjectをUUID方式へ移行しました。次回保存時にProject IDが記録されます。",
        type = "message", duration = 5
      )
    }
    project_uuid(loaded_uuid)
    project_uuid_save_override(NULL)

    loaded_project_name <- NULL
    if (!is.null(cfg$project_name)) {
      loaded_project_name <- as.character(cfg$project_name)
      updateTextInput(
        session, "project_name",
        value = loaded_project_name
      )
      session$sendCustomMessage(
        "set-project-name-input",
        list(name = loaded_project_name)
      )
    }

    # Project単位の保存先記憶設定を復元する。
    popt <- cfg$project_options
    remember_restore <- if (is.null(popt)) FALSE else isTRUE(popt$remember_save_destination)
    project_remember_pref(remember_restore)
    updateCheckboxInput(session, "remember_project_save_destination", value = remember_restore)
    if (remember_restore) {
      if (isTRUE(uuid_was_missing) && !is.null(loaded_project_name) && nzchar(loaded_project_name)) {
        session$sendCustomMessage(
          "migrate-project-save-destination",
          list(
            oldKey = safe_name(loaded_project_name, loaded_project_name),
            newKey = loaded_uuid
          )
        )
      } else {
        session$sendCustomMessage(
          "check-project-save-destination",
          list(projectKey = loaded_uuid, remember = TRUE)
        )
      }
    }

    # 現在見えている完成済みGraphは、新しいProjectの最初のGraphが
    # 描画完了するまで残す。これにより標準/空のGraphへの瞬間的な切替を防ぐ。
    old <- isolate(graph_meta())
    old_panels <- old$id[vapply(old$id, module_exists, logical(1))]
    obsolete_panels(old_panels)

    # 旧moduleの参照はregistryから外すが、DOM panelは完成表示まで残す。
    for (id in old_panels) {
      modules[[id]] <- NULL
    }

    graph_state_cache(list())
    graph_meta(data.frame(
      id = character(0),
      name = character(0),
      stringsAsFactors = FALSE
    ))

    entries <- list()
    old_active <- NULL

    if (!is.null(cfg$graphs) && length(cfg$graphs)) {
      entries <- cfg$graphs
      old_active <- as.character(cfg$active_graph %||% "")
    } else {
      # v1.14以前の単一Graph Project
      entries <- list(
        old_graph_1 = list(name = "Graph 1", state = cfg)
      )
      old_active <- "old_graph_1"
    }

    source_ids <- names(entries)
    created <- character(0)
    new_meta <- data.frame(
      id = character(0),
      name = character(0),
      stringsAsFactors = FALSE
    )

    # 重要:
    # ここではGraph module/UIを生成しない。
    # RDSからstateだけregistryへ読み込む。
    for (i in seq_along(entries)) {
      e <- entries[[i]]
      st <- if (!is.null(e$state)) e$state else e
      nm <- as.character(e$name %||% paste0("Graph ", i))

      id <- next_id()
      created <- c(created, id)
      new_meta <- rbind(
        new_meta,
        data.frame(id = id, name = nm, stringsAsFactors = FALSE)
      )
      cache_set(id, st)
    }

    if (!length(created)) {
      id <- next_id()
      created <- id
      new_meta <- data.frame(
        id = id,
        name = "Graph 1",
        stringsAsFactors = FALSE
      )
    }

    graph_meta(new_meta)

    target_index <- match(old_active, source_ids)
    if (is.na(target_index)) target_index <- 1L
    target <- created[target_index]

    refresh_export_choices()

    restore_kind("project")
    restore_target(target)
    restore_status("restoring")

    # 表示Graph 1枚だけを初期化・復元。
    show_graph(target, kind = "project")

    showNotification(
      "Projectファイルを読み込みました。表示Graphだけ復元しています。",
      type = "message",
      duration = 3
    )
  })

  # ------------------------------------------------------------------
  # Export target / lazy preparation
  # ------------------------------------------------------------------
  export_ids_now <- function() {
    meta <- isolate(graph_meta())
    mode <- isolate(input$top_export_target %||% "current")

    if (identical(mode, "all")) return(meta$id)

    if (identical(mode, "selected")) {
      return(intersect(
        isolate(input$bulk_export_selected %||% character(0)),
        meta$id
      ))
    }

    id <- isolate(active_graph())
    if (!is.null(id) && id %in% meta$id) id else character(0)
  }

  schedule_export_prep <- function() {
    mode <- isolate(input$top_export_target %||% "current")

    # 現在Graphだけなら既に表示時に初期化されるため、余計な準備はしない。
    if (identical(mode, "current")) {
      export_queue(character(0))
      export_prepare_active(FALSE)
      return(invisible(NULL))
    }

    ids <- export_ids_now()
    if (!length(ids)) {
      export_queue(character(0))
      export_prepare_active(FALSE)
      return(invisible(NULL))
    }

    pending <- ids[!vapply(ids, function(id) {
      mod <- modules[[id]]
      !is.null(mod) && isTRUE(isolate(mod$ready()))
    }, logical(1))]

    export_queue(unique(pending))
    export_prepare_active(length(pending) > 0)
    invisible(NULL)
  }

  observeEvent(input$top_export_target, {
    schedule_export_prep()
  }, ignoreInit = FALSE)

  observeEvent(input$bulk_export_selected, {
    if (identical(input$top_export_target %||% "current", "selected")) {
      schedule_export_prep()
    }
  }, ignoreInit = TRUE)

  observe({
    q <- export_queue()

    if (!length(q)) {
      export_prepare_active(FALSE)
      return()
    }

    id <- q[1]

    if (!module_exists(id)) {
      instantiate_graph(id, context = "export")
    }

    mod <- modules[[id]]
    if (is.null(mod)) {
      export_queue(q[-1])
      return()
    }

    if (is.function(mod$activate)) mod$activate()

    # ready()がTRUEになったGraphから順に次へ。
    if (isTRUE(mod$ready())) {
      export_queue(q[-1])
    }
  })

  requested_export_ready <- reactive({
    export_queue()  # queue変化も依存に含める
    ids <- export_ids_now()
    if (!length(ids)) return(FALSE)

    all(vapply(ids, function(id) {
      mod <- modules[[id]]
      !is.null(mod) && isTRUE(mod$ready())
    }, logical(1)))
  })

  observe({
    if (isTRUE(requested_export_ready())) {
      shinyjs::enable("download_graphs")
    } else {
      shinyjs::disable("download_graphs")
    }
  })

  output$bulk_export_status <- renderText({
    mode <- input$top_export_target %||% "current"
    if (identical(mode, "current")) return("")

    ids <- export_ids_now()
    if (!length(ids)) return("書き出すGraphを選択してください。")

    ready_n <- sum(vapply(ids, function(id) {
      mod <- modules[[id]]
      !is.null(mod) && isTRUE(mod$ready())
    }, logical(1)))

    if (ready_n == length(ids)) {
      paste0("書き出し準備完了（", ready_n, " / ", length(ids), "）")
    } else {
      paste0("書き出し用にGraphを準備中… ", ready_n, " / ", length(ids))
    }
  })

  # ------------------------------------------------------------------
  # Export writers
  # ------------------------------------------------------------------
  write_one_graph <- function(path, id, format) {
    mod <- modules[[id]]
    if (is.null(mod)) stop("Graph moduleが見つかりません。")
    if (!isTRUE(isolate(mod$ready()))) {
      stop("Graphの復元がまだ完了していません。")
    }

    p <- isolate(mod$plot())
    ex <- tryCatch(
      isolate(mod$export()),
      error = function(e) list(
        plot_width_px = 600,
        plot_height_px = 600,
        reference_res = 120
      )
    )

    pw <- as.numeric(ex$plot_width_px %||% 600)
    ph <- as.numeric(ex$plot_height_px %||% 600)
    ref_res <- as.numeric(ex$reference_res %||% 120)

    if (!length(pw) || !is.finite(pw[1])) pw <- 600
    if (!length(ph) || !is.finite(ph[1])) ph <- 600
    if (!length(ref_res) || !is.finite(ref_res[1]) || ref_res[1] <= 0) ref_res <- 120

    pw <- pw[1]
    ph <- ph[1]
    ref_res <- ref_res[1]
    w <- pw / ref_res
    h <- ph / ref_res

    if (identical(format, "svg")) {
      svglite::svglite(path, width = w, height = h)
      svg_device <- grDevices::dev.cur()
      svg_closed <- FALSE
      on.exit({
        if (!isTRUE(svg_closed) && identical(grDevices::dev.cur(), svg_device)) {
          try(grDevices::dev.off(), silent = TRUE)
        }
      }, add = TRUE)
      suppressWarnings(print(p))
      grDevices::dev.off()
      svg_closed <- TRUE
      return(invisible(TRUE))
    }

    if (identical(format, "pdf")) {
      ggplot2::ggsave(
        filename = path,
        plot = p,
        width = w,
        height = h,
        units = "in",
        device = grDevices::cairo_pdf
      )
      return(invisible(TRUE))
    }

    ggplot2::ggsave(
      filename = path,
      plot = p,
      width = w,
      height = h,
      units = "in",
      dpi = ref_res,
      device = "png"
    )
    invisible(TRUE)
  }

  write_graph_export <- function(file, ids, format) {
    meta <- isolate(graph_meta())
    ids <- ids[ids %in% meta$id]

    if (!length(ids)) stop("出力するGraphがありません。")

    not_ready <- ids[!vapply(ids, function(id) {
      mod <- modules[[id]]
      !is.null(mod) && isTRUE(isolate(mod$ready()))
    }, logical(1))]

    if (length(not_ready)) {
      stop("まだ書き出し準備中のGraphがあります。")
    }

    ext <- switch(
      format,
      png = "png",
      pdf = "pdf",
      svg = "svg",
      "svg"
    )

    if (length(ids) == 1L) {
      write_one_graph(file, ids[[1]], format)
      return(invisible(TRUE))
    }

    td <- tempfile("ggplot_export_")
    dir.create(td, recursive = TRUE)

    files <- character(0)
    for (i in seq_along(ids)) {
      id <- ids[[i]]
      nm <- meta$name[match(id, meta$id)]
      fp <- file.path(
        td,
        sprintf("%02d_%s.%s", i, safe_name(nm, id), ext)
      )
      write_one_graph(fp, id, format)
      files <- c(files, fp)
    }

    zip::zipr(
      zipfile = file,
      files = basename(files),
      root = td,
      include_directories = FALSE
    )

    invisible(TRUE)
  }

  export_filename_now <- function() {
    ids <- export_ids_now()
    fmt <- isolate(input$top_export_format %||% "svg")
    meta <- isolate(graph_meta())
    ext <- switch(fmt, png = "png", pdf = "pdf", svg = "svg", "svg")

    if (length(ids) == 1L) {
      nm <- meta$name[match(ids, meta$id)]
      return(paste0(safe_name(nm, "Graph"), ".", ext))
    }

    paste0(
      safe_name(input$project_name, "Project"),
      "_", toupper(ext), ".zip"
    )
  }

  output$download_graphs <- downloadHandler(
    filename = function() export_filename_now(),
    content = function(file) {
      ids <- export_ids_now()
      fmt <- isolate(input$top_export_format %||% "svg")
      write_graph_export(file, ids, fmt)
    }
  )



})
