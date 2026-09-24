# R/figure/layout/figure_layout_contract.R — canonical Figure alignment semantics
# v3.80.7: alignment anchor and attached outer-legend participation are one
# explicit, persisted contract. Legacy names are accepted only at state/load
# boundaries and never become a second runtime geometry path.

figure_alignment_basis_values <- function() {
  c("panel", "panel_legend", "panel_axis", "panel_axis_legend")
}

figure_normalize_alignment_basis <- function(x, fallback = "panel_legend", allow_inherit = FALSE) {
  z <- as.character(x %||% fallback)[1]
  if (!length(z) || is.na(z) || !nzchar(z)) z <- fallback
  if (isTRUE(allow_inherit) && identical(z, "inherit")) return("inherit")

  # Load/state-boundary migration from pre-v3.80.7 names. Note that the old
  # literal `axis` was already migrated to panel_auto by v3.80.6, so the new
  # Panel+axis contract deliberately uses the unambiguous `panel_axis` name.
  map <- c(
    panel_auto = "panel_legend",
    plot = "panel",
    facet = "panel_legend",
    axis = "panel_legend",
    axis_legend = "panel_axis_legend",
    panel = "panel",
    panel_legend = "panel_legend",
    panel_axis = "panel_axis",
    panel_axis_legend = "panel_axis_legend"
  )
  if (z %in% names(map)) z <- unname(map[[z]]) else z <- fallback
  if (!z %in% figure_alignment_basis_values()) z <- fallback
  z
}

figure_alignment_anchor_kind <- function(basis) {
  basis <- figure_normalize_alignment_basis(basis)
  if (basis %in% c("panel_axis", "panel_axis_legend")) "axis" else "panel"
}

figure_alignment_includes_outer_legend <- function(basis) {
  figure_normalize_alignment_basis(basis) %in% c("panel_legend", "panel_axis_legend")
}

figure_alignment_basis_label <- function(basis) {
  switch(
    figure_normalize_alignment_basis(basis),
    panel = "Panel本体（外側凡例を除外）",
    panel_legend = "Panel本体（外側凡例を含む）",
    panel_axis = "Panel＋軸（外側凡例を除外）",
    panel_axis_legend = "Panel＋軸（外側凡例を含む）",
    "Panel本体（外側凡例を含む）"
  )
}
