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

figure_write_pptx_editable <- function(path, layout, canvas_w, canvas_h, overrides, plots, exports,
                                       gap_x = 12, gap_y = 12, rects = NULL,
                                       external_assets = list(), inset_snapshots = list(),
                                       persisted_previews = list(), reference_res = 120) {
  pptx_editable_require()

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
      draw_state$summary <- figure_draw_to_device(
        layout, canvas_w, canvas_h, overrides, plots, exports, gap_x, gap_y,
        rects = rects,
        external_assets = external_assets,
        inset_snapshots = inset_snapshots,
        persisted_previews = persisted_previews
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
  doc <- officer::ph_with(doc, value = editable_figure, location = loc)

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
  summary$slide_width_in <- slide_w_in
  summary$slide_height_in <- slide_h_in
  summary$figure_width_in <- figure_w_in
  summary$figure_height_in <- figure_h_in
  summary$drawingml <- TRUE
  summary
}
