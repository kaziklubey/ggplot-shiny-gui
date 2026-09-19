  # ============================================================
  # Plot builder
  # ============================================================
  
  # Y-axis tick sequence helper
  y_break_values <- function(ymin, ymax) {
    if (isTRUE(input$y_breaks_auto)) return(waiver())

    step <- suppressWarnings(as.numeric(input$y_breaks_step))
    if (!is.finite(step) || step <= 0 || !is.finite(ymin) || !is.finite(ymax) || ymax <= ymin) {
      return(waiver())
    }

    start <- ceiling(ymin / step) * step
    end <- floor(ymax / step) * step

    vals <- seq(start, end, by = step)

    # Include exact limits when they fall on the requested interval.
    if (length(vals) > 5000) return(waiver())
    vals
  }

make_plot <- reactive({
    # v3.66.3: persistent single-Editor Graph switches are one render
    # transaction. Do not rebuild while the outer owner is HYDRATING/SYNCING.
    # Opening this gate at READY invalidates make_plot once with the completed
    # canonical state.
    shiny::req(isTRUE(render_gate()))

    # v3.3.54: while a saved Graph is being restored, input updates arrive over
    # several Shiny flushes. Do not rebuild ggplot for each intermediate state.
    # The transition initial_restore_done(FALSE -> TRUE) invalidates this reactive
    # once and permits the final plot build after restore completes.
    shiny::req(isTRUE(initial_restore_done()))

    # A Graph attach keeps one semantic target pending while the outer render
    # gate is closed. Never allow a consumer to build until the accepted target
    # has advanced the revision or explicitly reuse-approved the existing plot.
    shiny::req(!isTRUE(plot_build_pending()))

    # The plot builder is driven by the semantic RenderState revision. All
    # downstream reads are isolated so metadata-only/input-binding changes do
    # not directly invalidate this expensive reactive.
    build_rev <- plot_build_revision()

    # v3.72.7: gate reopen may invalidate this reactive even when the final
    # RenderState is identical to the last successful plot. Reuse that single
    # completed object instead of rebuilding ggplot. This is one-object cache
    # only; it does not grow with Graph count.
    target_render_state <- isolate(plot_build_render_state())
    last_render_state <- isolate(plot_last_built_render_state())
    last_success_rev <- suppressWarnings(as.integer(isolate(plot_last_success_revision())))
    cached_plot <- plot_last_success_object$value
    if (!is.null(cached_plot) && is.finite(last_success_rev) &&
        identical(last_success_rev, as.integer(build_rev)) &&
        identical(last_render_state, target_render_state)) {
      diag("PLOT", paste0("make_plot CACHE-HIT rev=", build_rev, " render_state_unchanged"))
      return(cached_plot)
    }

    isolate({
    t0_diag_plot <- proc.time()[["elapsed"]]
    plot_type_diag <- as.character(input$plot_type %||% "<unset>")
    diag("PLOT", paste0("make_plot START rev=", build_rev, " type=", plot_type_diag))
    on.exit({
      dt <- proc.time()[["elapsed"]] - t0_diag_plot
      diag("PLOT", sprintf("make_plot END %.3fs type=%s", dt, plot_type_diag))
    }, add = TRUE)

    p <- graph_build_plot(environment())

    plot_last_built_render_state(isolate(plot_build_render_state()))
    plot_last_success_revision(as.integer(build_rev))
    plot_last_success_object$value <- p
    p
    })
  })

  init_timing_emit("OUTPUTS-BEGIN")

