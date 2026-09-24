# v3.73.2.36: Graph export renders directly from canonical GraphState.
# Bulk/current export never creates hidden graphUI/graphServer instances.

  graph_export_sync_visible_owner <- function(ids) {
    owner <- graph_single_owner()
    if (!nzchar(owner) || !owner %in% as.character(ids %||% character(0))) return(invisible(FALSE))
    if (isTRUE(isolate(graph_single_editor_loading())) || !graph_single_ready(owner)) return(invisible(FALSE))
    graph_single_commit("export-direct-state")
    invisible(TRUE)
  }

  graph_export_payload <- function(id) {
    id <- as.character(id %||% "")[1]
    state <- if (nzchar(id) && cache_has(id)) cache_get(id) else NULL
    if (!is.list(state)) stop("GraphStateが見つかりません。")
    tryCatch(
      graph_state_export_snapshot(state),
      error = function(e) stop("Graphの書き出し用描画を作成できません: ", conditionMessage(e))
    )
  }

  write_one_graph <- function(path, id, format) {
    payload <- graph_export_payload(id)
    p <- payload$plot
    ex <- payload$meta %||% list()

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

    if (identical(format, "pptx")) {
      info <- pptx_write_ggplot_editable(
        path, p, width_px = pw, height_px = ph, reference_res = ref_res,
        label = paste0("ggplot-editable-graph-", id)
      )
      diag_log(
        "GRAPH-PPTX-EDITABLE",
        paste0(
          "flattened_groups=", as.integer(info$flattened_groups %||% 0L),
          " skipped_groups=", as.integer(info$skipped_groups %||% 0L),
          " exposed_shapes=", as.integer(info$exposed_shapes %||% 0L),
          " slide=", round(info$slide_width_in %||% NA_real_, 3), "x",
          round(info$slide_height_in %||% NA_real_, 3), "in"
        ),
        id = id
      )
      return(invisible(TRUE))
    }

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

    app_save_plot_png(
      p, path, width_px = pw, height_px = ph, res = ref_res
    )
    invisible(TRUE)
  }

  write_graph_export <- function(file, ids, format) {
    meta <- isolate(graph_meta())
    ids <- ids[ids %in% meta$id]

    if (!length(ids)) stop("出力するGraphがありません。")

    graph_export_sync_visible_owner(ids)
    missing_state <- ids[!vapply(ids, graph_export_state_ready, logical(1))]
    if (length(missing_state)) {
      stop("GraphStateを取得できないGraphがあります。")
    }

    ext <- switch(
      format,
      png = "png",
      pdf = "pdf",
      svg = "svg",
      pptx = "pptx",
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
    ext <- switch(fmt, png = "png", pdf = "pdf", svg = "svg", pptx = "pptx", "svg")

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
