# v3.70.0: extracted from server.R; sourced into the same server function environment.

  # ------------------------------------------------------------------
  # Export target / lazy preparation
  # ------------------------------------------------------------------
  export_ids_now <- function() {
    # Keep these reads reactive when the caller is reactive. observeEvent and
    # download handlers already isolate their bodies as appropriate, while
    # requested_export_ready()/status must follow target/selection/owner changes.
    meta <- graph_meta()
    mode <- input$top_export_target %||% "current"

    if (identical(mode, "all")) return(meta$id)

    if (identical(mode, "selected")) {
      return(intersect(
        input$bulk_export_selected %||% character(0),
        meta$id
      ))
    }

    id <- as.character(editing_graph_id() %||% "")[1]
    if (nzchar(id) && id %in% meta$id) id else character(0)
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

    pending <- ids[!vapply(ids, source_graph_ready, logical(1))]

    export_queue(unique(pending))
    export_prepare_active(length(pending) > 0)
    # The persistent Editor owns its current Graph. Never start a background
    # source materializer for that same id while it is SYNCING/HYDRATING.
    bg_pending <- setdiff(unique(pending), graph_single_owner())
    if (length(bg_pending)) schedule_graph_materialization(bg_pending, reason = "export-prepare")
    invisible(NULL)
  }

  observeEvent(input$top_export_target, {
    if (project_load_action_blocked("export-target")) return()
    schedule_export_prep()
  }, ignoreInit = FALSE)

  observeEvent(input$bulk_export_selected, {
    if (project_load_action_blocked("export-selection")) return()
    if (identical(input$top_export_target %||% "current", "selected")) {
      schedule_export_prep()
    }
  }, ignoreInit = TRUE)

  observe({
    graph_materialization_signal()
    graph_single_editor_mode()
    graph_single_editor_loading()
    q <- export_queue()

    if (!length(q)) {
      export_prepare_active(FALSE)
      return()
    }

    id <- q[1]

    if (isTRUE(source_graph_ready(id))) {
      # ready()がTRUEになったGraphから順に次へ。
      export_queue(q[-1])
      return()
    }

    # If this id is owned by the persistent Editor, wait for its existing
    # transaction. Starting modules[[id]] here would create a second editor.
    if (identical(id, graph_single_owner())) return()

    request_graph_materialization(id, reason = "export-prepare")
  })

  requested_export_ready <- reactive({
    export_queue()  # queue変化も依存に含める
    editing_graph_id()
    graph_single_editor_mode()
    graph_single_editor_loading()
    ids <- export_ids_now()
    if (!length(ids)) return(FALSE)

    all(vapply(ids, source_graph_ready, logical(1)))
  })

  observe({
    if (isTRUE(requested_export_ready())) {
      shinyjs::enable("download_graphs")
    } else {
      shinyjs::disable("download_graphs")
    }
  })

  output$bulk_export_status <- renderText({
    export_queue()
    graph_single_editor_mode()
    graph_single_editor_loading()
    mode <- input$top_export_target %||% "current"
    if (identical(mode, "current")) return("")

    ids <- export_ids_now()
    if (!length(ids)) return("書き出すGraphを選択してください。")

    ready_n <- sum(vapply(ids, source_graph_ready, logical(1)))

    if (ready_n == length(ids)) {
      paste0("書き出し準備完了（", ready_n, " / ", length(ids), "）")
    } else {
      paste0("書き出し用にGraphを準備中… ", ready_n, " / ", length(ids))
    }
  })

