  # ============================================================
  # Plot builder
  # ============================================================
  
  # Y-axis tick sequence helper
  y_break_values <- function(ymin, ymax) {
    manual_y_break_values(ymin, ymax, input$y_breaks_step, input$y_breaks_auto)
  }

make_plot <- reactive({
    # v3.66.3: persistent single-Editor Graph switches are one render
    # transaction. Do not rebuild while the outer owner is HYDRATING/SYNCING.
    # Opening this gate at READY invalidates make_plot once with the completed
    # canonical state.
    shiny::req(isTRUE(render_gate()))

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

    # Browser-direct Full Editor rendering uses the exact accepted canonical
    # attachment that released this revision. Do not rebuild semantics from the
    # stale Shiny input mirror; that mirror is presentation-only during direct
    # hydration and may still show the previous plot type for a few milliseconds.
    state_for_plot <- NULL
    direct_state <- isTRUE(graph_browser_patch_direct_render_active())
    if (isTRUE(direct_state)) {
      # Full Editor renders the outer accepted canonical attachment. Figure
      # Controls render their Figure-owned base plus the local working overlay;
      # this never consults or mutates the source Graph registry.
      state_for_plot <- if (graph_editor_profile_is_figure(editor_profile)) {
        isolate(project_settings())
      } else {
        isolate(attached_state_seed())
      }
      if (!is.list(state_for_plot)) {
        state_for_plot <- isolate(project_settings())
        state_for_plot <- graph_apply_browser_patch_overlay(state_for_plot)
      }
    }
    plot_type_diag <- if (is.list(state_for_plot)) {
      as.character((state_for_plot$plot %||% list())$type %||% "<unset>")[1]
    } else {
      as.character(input$plot_type %||% "<unset>")[1]
    }
    diag("PLOT", paste0("make_plot START rev=", build_rev, " type=", plot_type_diag))
    on.exit({
      dt <- proc.time()[["elapsed"]] - t0_diag_plot
      diag("PLOT", sprintf("make_plot END %.3fs type=%s", dt, plot_type_diag))
    }, add = TRUE)

    p <- graph_render_plot_safely(function() {
      if (isTRUE(direct_state)) {
        built <- graph_build_plot(graph_snapshot_context(state_for_plot))
        diag("PLOT", paste0(
          "make_plot path=DIRECT-STATE ",
          if (graph_editor_profile_is_figure(editor_profile)) "figure-owned-working-state" else "accepted-canonical"
        ))
        built
      } else {
        graph_build_plot(environment())
      }
    })

    plot_last_built_render_state(isolate(plot_build_render_state()))
    plot_last_success_revision(as.integer(build_rev))
    plot_last_success_object$value <- p
    p
    })
  })

  init_timing_emit("OUTPUTS-BEGIN")
