# v3.74.2: canonical line-break control state for the persistent Graph Editor.
#
# `input$line_breaks` is a browser control, not the authority. Updating a
# selectize's choices can briefly clear its selected values while a Graph replay
# or Category-order rebuild is settling. If that transient browser value is
# committed directly, a duplicated/switched Graph can lose its saved break.
#
# Keep one module-local value that mirrors the attached GraphState. User edits
# update it; server-driven choices refreshes never delete a saved break merely
# because a transient choice universe cannot represent it yet.

  line_break_state <- reactiveVal(character(0))
  line_break_x_var <- reactiveVal("")
  line_break_choice_signature <- reactiveVal("")
  line_break_transient_signature <- reactiveVal("")

  line_break_clean <- function(x) {
    z <- unique(as.character(unlist(x %||% character(0), use.names = FALSE)))
    z[!is.na(z) & nzchar(z)]
  }

  line_break_set_state <- function(value, x_var = NULL, source = "runtime") {
    value <- line_break_clean(value)
    old <- isolate(line_break_state())
    if (!identical(old, value)) {
      line_break_state(value)
      diag(
        "LINE-BREAK-STATE",
        paste0("source=", source, " count=", length(value))
      )
    }
    if (!is.null(x_var)) {
      x_var <- as.character(x_var %||% "")[1]
      if (is.na(x_var)) x_var <- ""
      line_break_x_var(x_var)
    }
    invisible(value)
  }

  line_break_restore_from_cfg <- function(cfg, mapping_plan = NULL, hydrate_bound_control = TRUE) {
    if (!is.list(cfg)) return(invisible(FALSE))
    plan <- graph_line_break_plan(cfg, mapping_plan)
    saved <- line_break_clean((cfg$plot %||% list())$line_breaks)
    target_x <- ""
    if (is.list(mapping_plan)) target_x <- as.character(mapping_plan$x %||% "")[1]

    # Preserve the saved canonical value exactly at the Graph boundary. The
    # current browser choices may temporarily be incomplete; only the UI
    # selection is intersected with the target-derived choices.
    line_break_set_state(saved, x_var = target_x, source = "state-replay")
    line_break_choice_signature("")
    line_break_transient_signature("")

    if (isTRUE(hydrate_bound_control)) {
      selected_ui <- saved[saved %in% unname(plan$choices)]
      updateSelectizeInput(
        session, "line_breaks",
        choices = plan$choices,
        selected = selected_ui,
        server = FALSE
      )
    }
    invisible(TRUE)
  }

  line_break_prune_to_levels <- function(levels_now, source = "category-order") {
    current <- isolate(line_break_state())
    valid <- graph_line_break_normalize(current, levels_now)
    line_break_set_state(valid, source = source)
    line_break_choice_signature("")
    line_break_transient_signature("")
    invisible(valid)
  }

  # Browser edits become canonical only outside Graph replay. Programmatic
  # updates that keep the same selection are harmless; replay updates are
  # ignored while the transaction is active.
  observeEvent(input$line_breaks, {
    if (isTRUE(graph_state_replay_active())) return(invisible(NULL))
    if (!identical(input$plot_type %||% "line", "line")) return(invisible(NULL))

    d <- tryCatch(plot_data(), error = function(e) NULL)
    x_now <- as.character(resolved_xvar() %||% "")[1]
    if (!is.data.frame(d) || !nzchar(x_now) || !x_now %in% names(d)) return(invisible(NULL))

    levels_now <- levels(d[[x_now]])
    if (is.null(levels_now) || !length(levels_now)) {
      levels_now <- unique(as.character(d[[x_now]]))
      levels_now <- levels_now[!is.na(levels_now)]
    }
    selected <- graph_line_break_normalize(input$line_breaks %||% character(0), levels_now)
    line_break_set_state(selected, x_var = x_now, source = "browser-user")
    invisible(NULL)
  }, ignoreInit = TRUE, priority = 130)

  # Keep labels/choices synchronized with the effective X Category order. If
  # the current choice universe cannot represent a saved canonical break, do
  # not push a destructive empty selection into selectize. This is the exact
  # transient that previously occurred just after duplicate/Graph replay.
  observe({
    if (isTRUE(graph_state_replay_active())) return(invisible(NULL))
    if (!identical(input$plot_type %||% "line", "line")) return(invisible(NULL))

    d <- tryCatch(plot_data(), error = function(e) NULL)
    x_now <- as.character(resolved_xvar() %||% "")[1]
    if (!is.data.frame(d) || !nzchar(x_now) || !x_now %in% names(d)) return(invisible(NULL))

    previous_x <- as.character(isolate(line_break_x_var()) %||% "")[1]
    if (nzchar(previous_x) && !identical(previous_x, x_now)) {
      # A real X-Mapping change defines a different set of boundaries. Replay
      # itself pre-seeds line_break_x_var(), so this branch is user-driven.
      line_break_set_state(character(0), x_var = x_now, source = "x-mapping-change")
      line_break_choice_signature("")
      line_break_transient_signature("")
    } else if (!nzchar(previous_x)) {
      line_break_x_var(x_now)
    }

    levels_now <- levels(d[[x_now]])
    if (is.null(levels_now) || !length(levels_now)) {
      levels_now <- unique(as.character(d[[x_now]]))
      levels_now <- levels_now[!is.na(levels_now)]
    }
    labels_now <- level_label_values(x_now, levels_now)
    choices <- graph_line_break_choices(levels_now, labels_now)
    saved <- isolate(line_break_state())
    selected <- graph_line_break_normalize(saved, levels_now)

    if (length(saved) && length(selected) < length(saved)) {
      transient_sig <- paste(c(x_now, levels_now, sort(saved)), collapse = "|~|")
      if (!identical(transient_sig, isolate(line_break_transient_signature()))) {
        line_break_transient_signature(transient_sig)
        diag(
          "LINE-BREAK-CHOICES",
          paste0(
            "preserve canonical during incomplete choices saved=", length(saved),
            " representable=", length(selected)
          )
        )
      }
      return(invisible(NULL))
    }
    line_break_transient_signature("")

    signature <- paste(
      c(names(choices), unname(choices), "::selected::", sort(selected)),
      collapse = "|~|"
    )
    if (identical(signature, isolate(line_break_choice_signature()))) return(invisible(NULL))
    line_break_choice_signature(signature)

    if (graph_editor_profile_has(editor_profile, "full_shell") ||
        graph_editor_profile_is_figure(editor_profile)) {
      # RC13.1: both persistent Editors keep category-order-driven line-break
      # topology browser-direct. Figure used to fall back to updateSelectizeInput(),
      # whose delayed echo could be misclassified as a user edit after replay.
      session$sendCustomMessage(
        "graph-browser-control-hydrate",
        list(
          inputPrefix = session$ns(""),
          mode = as.character(editor_profile$name %||% "full"),
          key = "line_breaks",
          value = as.character(selected),
          choices = lapply(seq_along(choices), function(i) list(
            label = as.character(names(choices)[[i]] %||% unname(choices)[[i]]),
            value = as.character(unname(choices)[[i]])
          )),
          generation = as.integer(isolate(graph_state_replay_generation()) %||% 0L)
        )
      )
      return(invisible(NULL))
    }

    updateSelectizeInput(
      session, "line_breaks",
      choices = choices,
      selected = selected,
      server = FALSE
    )
    invisible(NULL)
  }, priority = 120)
