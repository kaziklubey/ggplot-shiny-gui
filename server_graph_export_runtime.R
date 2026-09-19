# v3.70.0: extracted from server.R; sourced into the same server function environment.

  write_one_graph <- function(path, id, format) {
    mod <- source_graph_module(id)
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

    app_save_plot_png(
      p, path, width_px = pw, height_px = ph, res = ref_res
    )
    invisible(TRUE)
  }

  write_graph_export <- function(file, ids, format) {
    meta <- isolate(graph_meta())
    ids <- ids[ids %in% meta$id]

    if (!length(ids)) stop("出力するGraphがありません。")

    not_ready <- ids[!vapply(ids, source_graph_ready, logical(1))]

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



