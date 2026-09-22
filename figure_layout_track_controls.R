# figure_layout_track_controls.R — Figure-wide Fixed track controls
# v3.80.8.1: shared column ratios have one UI owner in the top-level Layout card.

figure_shared_column_ratio_controls <- function(layout) {
  ratios <- figure_shared_column_ratios(layout)
  if (!length(ratios)) return(NULL)

  controls <- lapply(seq_along(ratios), function(cc) {
    div(
      class = "figure-column-ratio-item",
      tags$label(class = "figure-mini-label", paste0("Col ", cc)),
      tags$input(
        type = "number",
        class = "form-control input-sm figure-column-ratio-edit",
        `data-col` = cc,
        value = format(ratios[[cc]], trim = TRUE, scientific = FALSE),
        min = "0.1", max = "10", step = "0.1",
        title = paste0("Fixed Canvasの全Row共通 Col ", cc, " 幅比")
      )
    )
  })

  div(
    class = "figure-shared-column-ratios",
    div(
      class = "figure-shared-column-ratios-heading",
      tags$strong("全Row共通の列幅比"),
      tags$span(class = "text-muted", "Fixed / Row")
    ),
    div(class = "figure-shared-column-ratio-items", tagList(controls)),
    tags$span(
      class = "figure-shared-column-ratios-help",
      "列はFigure全体で共有されます。各Rowには行高さ比だけを設定します。"
    )
  )
}
