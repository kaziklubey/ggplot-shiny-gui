# v3.73.2.37 Phase 2.03 — persistent Graph Editor local primitives.
# Sourced before data/style/output runtimes so those files never depend on a
# later source for transaction guards or scalar JSON normalization.

  attached_state_seed <- reactiveVal(NULL)
  restoring_style_state <- reactiveVal(FALSE)
  style_restore_epoch <- reactiveVal(0L)
  plot_render_revision <- reactiveVal(0L)
  last_render_state <- reactiveVal(NULL)

  json_chr <- function(x, default = "") {
    if (is.null(x) || !length(x)) return(default)
    z <- as.character(unlist(x, use.names = FALSE))
    if (!length(z) || is.na(z[[1]])) default else z[[1]]
  }
