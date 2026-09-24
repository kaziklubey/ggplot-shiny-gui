# R/export/figure_pptx_export.R — editable PowerPoint Figure export via officer + rvg
#
# The PowerPoint export deliberately bypasses SVG. rvg records the completed
# Figure drawing directly as DrawingML, so PowerPoint receives editable Office
# shapes rather than having to reinterpret an SVG with nested transforms/clips.
#
# WYSIWYG sizing rule:
#   Figure Preview/normal SVG use reference_res = 120 px/in. The PPTX slide is
#   therefore created at exactly canvas_px / 120 inches. This preserves the same
#   physical text/line/point proportions instead of redrawing a large Figure on
#   a standard 10x7.5-in slide (which would make text appear too large).

# Shared PowerPoint infrastructure lives in R/export/pptx_editable_export.R so Graph
# and Figure exports use the same slide sizing and DrawingML flattening rules.
figure_pptx_blank_layout <- pptx_blank_layout
figure_pptx_set_slide_size <- pptx_set_slide_size

# Project files persist Figure-owned GraphState + SVG snapshots, but deliberately
# do not persist heavyweight ggplot objects. SVG is excellent for Figure preview
# and SVG/PDF export, yet feeding that snapshot through the grid compatibility
# path rasterizes it inside rvg. For editable PowerPoint, rebuild only missing
# internal Graph plots synchronously from the frozen Figure-owned GraphState.
# This is export-local: it does not mutate GraphState, Figure snapshots or Editor DOM.
figure_pptx_prepare_editable_sources <- function(ids, plots, exports, edit_states) {
  ids <- unique(as.character(ids %||% character(0)))
  ids <- ids[nzchar(ids)]
  if (!is.list(plots)) plots <- list()
  if (!is.list(exports)) exports <- list()
  if (!is.list(edit_states)) edit_states <- list()

  rebuilt <- character(0)
  fallback <- character(0)
  errors <- list()

  for (id in ids) {
    if (!is.null(plots[[id]])) next
    state <- edit_states[[id]]
    if (!is.list(state)) {
      fallback <- c(fallback, id)
      next
    }

    payload <- tryCatch(
      graph_state_figure_snapshot(state),
      error = function(e) {
        errors[[id]] <<- conditionMessage(e)
        NULL
      }
    )
    if (!is.list(payload) || is.null(payload$plot)) {
      fallback <- c(fallback, id)
      next
    }

    plots[[id]] <- payload$plot
    exports[[id]] <- payload$meta %||% exports[[id]]
    rebuilt <- c(rebuilt, id)
  }

  list(
    plots = plots,
    exports = exports,
    rebuilt_ids = unique(rebuilt),
    fallback_ids = unique(fallback),
    errors = errors
  )
}

# rvg::ph_with.dml currently assumes scan(dml_file) has length >= 1 and uses
# `if (dml_str == "</p:grpSp>")`. On the Windows browser runtime the first
# code-based Figure DML device can occasionally close with a zero-length
# capture file even though the drawing expression ran to completion. That
# upstream check then throws `argument is of length zero`; the same Figure
# succeeds on the next call. Keep this compatibility guard local to the PPTX
# boundary: retry the exact zero-length-rvg signature once, never retry user
# plotting errors or rvg's explicit "no plot output" error.
figure_pptx_is_rvg_empty_dml_error <- function(e) {
  if (!inherits(e, "condition")) return(FALSE)
  msg <- as.character(conditionMessage(e) %||% "")[1]
  call_txt <- tryCatch(
    paste(deparse(conditionCall(e), width.cutoff = 180L), collapse = ""),
    error = function(...) ""
  )
  identical(msg, "argument is of length zero") &&
    grepl("dml_str", call_txt, fixed = TRUE) &&
    grepl("</p:grpSp>", call_txt, fixed = TRUE)
}

figure_pptx_ph_with_dml_stable <- function(doc, value, location, diag = NULL,
                                           ph_with_fun = officer::ph_with,
                                           max_attempts = 2L) {
  emit <- function(tag, message) {
    if (is.function(diag)) try(diag(tag, message), silent = TRUE)
    invisible(TRUE)
  }
  attempts <- suppressWarnings(as.integer(max_attempts)[1])
  if (!length(attempts) || !is.finite(attempts) || attempts < 1L) attempts <- 1L

  last_error <- NULL
  for (attempt in seq_len(attempts)) {
    out <- tryCatch(
      ph_with_fun(doc, value = value, location = location),
      error = function(e) { last_error <<- e; NULL }
    )
    if (!is.null(out)) {
      if (attempt > 1L) emit("EMPTY-DML-RECOVERED", paste0("attempt=", attempt))
      return(out)
    }

    retryable <- figure_pptx_is_rvg_empty_dml_error(last_error)
    if (!isTRUE(retryable) || attempt >= attempts) break
    emit(
      "EMPTY-DML-RETRY",
      paste0(
        "attempt=", attempt, " next=", attempt + 1L,
        " rvg=", tryCatch(as.character(utils::packageVersion("rvg")), error = function(...) "unknown"),
        " officer=", tryCatch(as.character(utils::packageVersion("officer")), error = function(...) "unknown")
      )
    )
  }

  if (inherits(last_error, "condition")) stop(last_error)
  stop("PowerPoint DrawingML placeholder insertion failed without a condition.")
}

figure_write_pptx_editable <- function(path, layout, canvas_w, canvas_h, overrides, plots, exports,
                                       gap_x = 12, gap_y = 12, rects = NULL,
                                       external_assets = list(), inset_snapshots = list(),
                                       persisted_previews = list(), reference_res = 120,
                                       diag = NULL) {
  pptx_editable_require()

  emit_diag <- function(tag, message) {
    if (!is.function(diag)) return(invisible(FALSE))
    try(diag(as.character(tag %||% "TRACE")[1], as.character(message %||% "")[1]), silent = TRUE)
    invisible(TRUE)
  }
  compact_call <- function(x) {
    paste(deparse(x, width.cutoff = 180L), collapse = "")
  }

  rr <- suppressWarnings(as.numeric(reference_res %||% 120)[1])
  if (!is.finite(rr) || rr <= 0) rr <- 120
  cw <- suppressWarnings(as.numeric(canvas_w)[1])
  ch <- suppressWarnings(as.numeric(canvas_h)[1])
  if (!all(is.finite(c(cw, ch))) || cw <= 0 || ch <= 0) {
    stop("PowerPoint出力用のFigure canvasサイズが不正です。")
  }

  figure_w_in <- cw / rr
  figure_h_in <- ch / rr

  # Keep the Figure at exactly the same physical size as the normal SVG/PDF
  # reference device. Very small Figures get whitespace instead of scaling;
  # scaling here would change the text-to-geometry ratio on the rvg device.
  slide_w_in <- max(1, figure_w_in)
  slide_h_in <- max(1, figure_h_in)
  if (slide_w_in > 56 || slide_h_in > 56) {
    stop(sprintf(
      "FigureがPowerPointの最大スライドサイズ（56 inch）を超えています: %.2f x %.2f inch",
      figure_w_in, figure_h_in
    ))
  }
  left_in <- (slide_w_in - figure_w_in) / 2
  top_in <- (slide_h_in - figure_h_in) / 2

  doc <- officer::read_pptx()
  doc <- figure_pptx_set_slide_size(doc, slide_w_in, slide_h_in)
  blank <- figure_pptx_blank_layout(doc)
  doc <- officer::add_slide(doc, layout = blank$layout, master = blank$master)

  draw_state <- new.env(parent = emptyenv())
  draw_state$summary <- NULL

  # rvg::dml() captures this expression together with its local environment.
  # ph_with() opens the DrawingML graphics device and evaluates it there.
  # figure_draw_to_device() already owns the exact Preview/export rect geometry.
  editable_figure <- rvg::dml(
    code = {
      emit_diag(
        "DRAW-BEGIN",
        paste0(
          "canvas=", round(canvas_w, 3), "x", round(canvas_h, 3),
          " rects=", length(rects %||% list()),
          " plots=", length(plots %||% list())
        )
      )
      draw_state$summary <- figure_draw_to_device(
        layout, canvas_w, canvas_h, overrides, plots, exports, gap_x, gap_y,
        rects = rects,
        external_assets = external_assets,
        inset_snapshots = inset_snapshots,
        persisted_previews = persisted_previews
      )
      emit_diag(
        "DRAW-END",
        paste0(
          "drawn=", length(draw_state$summary$drawn_ids %||% character(0)),
          " missing=", length(draw_state$summary$missing_ids %||% character(0))
        )
      )
    },
    bg = "transparent",
    editable = TRUE
  )

  loc <- officer::ph_location(
    left = left_in, top = top_in,
    width = figure_w_in, height = figure_h_in,
    newlabel = "ggplot-editable-figure"
  )
  doc <- withCallingHandlers(
    figure_pptx_ph_with_dml_stable(
      doc, value = editable_figure, location = loc, diag = emit_diag
    ),
    error = function(e) {
      calls <- sys.calls()
      call_txt <- tryCatch(compact_call(conditionCall(e)), error = function(...) "<unavailable>")
      stack_txt <- if (length(calls)) {
        rendered <- vapply(calls, function(x) {
          tryCatch(compact_call(x), error = function(...) "<unavailable>")
        }, character(1))
        rendered <- rendered[
          grepl("figure_|ph_with|grid|rvg|if\\s*\\(", rendered, perl = TRUE)
        ]
        paste(tail(rendered, 14L), collapse = " <- ")
      } else {
        ""
      }
      emit_diag(
        "PH-WITH-ERROR",
        paste0(
          "message=", conditionMessage(e),
          " call=", call_txt,
          if (nzchar(stack_txt)) paste0(" stack={", stack_txt, "}") else ""
        )
      )
    }
  )

  summary <- draw_state$summary
  if (!is.list(summary)) {
    stop("PowerPoint DrawingMLへのFigure描画結果を取得できませんでした。")
  }

  tmp <- tempfile("figure_editable_", fileext = ".pptx")
  on.exit(try(unlink(tmp), silent = TRUE), add = TRUE)
  tryCatch(
    print(doc, target = tmp),
    error = function(e) stop("編集可能PowerPointの生成に失敗しました: ", conditionMessage(e))
  )
  if (!file.exists(tmp) || !is.finite(file.info(tmp)$size) || file.info(tmp)$size <= 0) {
    stop("編集可能PowerPointの一時ファイルが生成されませんでした。")
  }

  # rvg intentionally wraps editable primitives in one PowerPoint group. For
  # this GUI the expected workflow is direct selection of line/point/text
  # shapes, so flatten only our identity-transform wrapper after officer has
  # written the pptx. This keeps the visual geometry while exposing the child
  # DrawingML shapes directly on the slide.
  flatten <- pptx_flatten_editable_groups(tmp, label_prefix = "ggplot-editable-")
  pptx_commit_temp_export(tmp, path)

  summary$pptx_editable <- TRUE
  summary$flattened_groups <- as.integer(flatten$flattened %||% 0L)
  summary$skipped_groups <- as.integer(flatten$skipped_nonidentity %||% 0L)
  summary$exposed_shapes <- as.integer(flatten$exposed_elements %||% 0L)
  summary$export_text_replacements <- as.integer(flatten$export_text_replacements %||% 0L)
  summary$slide_width_in <- slide_w_in
  summary$slide_height_in <- slide_h_in
  summary$figure_width_in <- figure_w_in
  summary$figure_height_in <- figure_h_in
  summary$drawingml <- TRUE
  summary
}
