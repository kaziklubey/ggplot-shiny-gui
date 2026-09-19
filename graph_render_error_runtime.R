# v3.73.2.5: Plot render error boundary.
# Expected Shiny validation/req control flow must remain Shiny control flow;
# only genuine R errors are converted to a visible diagnostic Plot.

graph_plot_error_placeholder <- function(e) {
  msg <- conditionMessage(e)
  if (!nzchar(msg)) msg <- "Unknown plot error"

  ggplot() +
    annotate(
      "text",
      x = 0,
      y = 0,
      label = paste0(
        "Plot error:\n",
        paste(strwrap(msg, width = 58), collapse = "\n")
      ),
      hjust = 0
    ) +
    xlim(0, 1) +
    ylim(-1, 1) +
    theme_void()
}

graph_render_plot_safely <- function(plot_provider) {
  tryCatch(
    withCallingHandlers(
      plot_provider(),
      warning = function(w) {
        diag("WARN", paste0("plot warning: ", conditionMessage(w)))
        try(invokeRestart("muffleWarning"), silent = TRUE)
      }
    ),
    error = function(e) {
      if (is_shiny_control_condition(e)) {
        # Preserve validate()/req() semantics so an unconfigured new Graph is
        # shown as a normal waiting/validation state, not as a Plot error.
        stop(e)
      }

      diag(
        "ERROR",
        paste0(
          "plot error class={", paste(class(e), collapse = ","),
          "}: ", conditionMessage(e)
        )
      )
      graph_plot_error_placeholder(e)
    }
  )
}
