# v3.73.2.36: Export readiness is canonical-state based.
# No hidden Graph UI/module is mounted or hydrated for bulk export.

  # ------------------------------------------------------------------
  # Export target / direct-state readiness
  # ------------------------------------------------------------------
  export_ids_now <- function() {
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

  graph_export_state_ready <- function(id) {
    id <- as.character(id %||% "")[1]
    nzchar(id) && cache_has(id) && is.list(cache_get(id))
  }

  requested_export_ready <- reactive({
    graph_state_cache()
    editing_graph_id()
    ids <- export_ids_now()
    if (!length(ids)) return(FALSE)
    all(vapply(ids, graph_export_state_ready, logical(1)))
  })

  observe({
    if (isTRUE(requested_export_ready())) {
      shinyjs::enable("download_graphs")
    } else {
      shinyjs::disable("download_graphs")
    }
  })

  output$bulk_export_status <- renderText({
    graph_state_cache()
    mode <- input$top_export_target %||% "current"
    if (identical(mode, "current")) return("")

    ids <- export_ids_now()
    if (!length(ids)) return("書き出すGraphを選択してください。")

    ready_n <- sum(vapply(ids, graph_export_state_ready, logical(1)))
    if (ready_n == length(ids)) {
      paste0("書き出し準備完了（", ready_n, " / ", length(ids), "）")
    } else {
      paste0("GraphStateを確認中… ", ready_n, " / ", length(ids))
    }
  })
