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
        "この設定の組み合わせは描画できません。\n",
        "Editorの設定は保持されています。変更して続行できます。\n\n",
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

# v4.0.1 draw boundary: ggplot objects can be constructed successfully but fail
# later when renderPlot converts them to grobs (ggplotGrob/grid.draw).  Keep that
# draw-time failure inside the same Editor-owned error boundary instead of letting
# it escape through Shiny's output transport.  This is intentionally separate
# from graph_render_plot_safely(): construction and drawing are distinct phases.
graph_draw_plot_safely <- function(plot) {
  tryCatch(
    {
      app_draw_static_plot(plot)
      invisible(TRUE)
    },
    error = function(e) {
      if (is_shiny_control_condition(e)) {
        stop(e)
      }

      diag(
        "ERROR",
        paste0(
          "plot draw error class={", paste(class(e), collapse = ","),
          "}: ", conditionMessage(e)
        )
      )

      # app_draw_static_plot() starts a fresh grid page for ggplot objects, so
      # drawing the placeholder replaces any partially-created failed page.
      # If even the minimal placeholder cannot be drawn, preserve the original
      # Shiny failure semantics rather than hiding a second infrastructure error.
      placeholder <- graph_plot_error_placeholder(e)
      tryCatch(
        {
          app_draw_static_plot(placeholder)
          invisible(FALSE)
        },
        error = function(draw_e) {
          diag(
            "ERROR",
            paste0(
              "plot error placeholder draw failed class={",
              paste(class(draw_e), collapse = ","),
              "}: ", conditionMessage(draw_e)
            )
          )
          stop(draw_e)
        }
      )
    }
  )
}
