# Existing Graph Editor level_labels ownership: no new GraphState or transport.
# A semantic category list, not a full data-frame reactive invalidation, owns
# the dynamic textarea DOM. Accepted text flows through level_labels() exactly
# as it did before this boundary refactor.

  display_label_topology <- reactiveVal(NULL)
  observe({
    d <- tryCatch(dat(), error = function(e) NULL)
    topology <- NULL
    if (is.data.frame(d)) {
      vars <- active_display_label_vars()
      topology <- lapply(vars, function(v) {
        z <- d[[v]]
        if (is.numeric(z) && identical(v, resolved_xvar()) &&
            identical(graph_plot_value("type", input$plot_type %||% "line"), "scatter")) return(NULL)
        observed <- unique(as.character(z))
        observed <- observed[!is.na(observed)]
        if (!length(observed)) return(NULL)
        list(variable = v, levels = observed)
      })
      topology <- Filter(Negate(is.null), topology)
    }
    # attached_state_seed updates on every GraphState publication, including
    # style-only changes, and thus invalidates dat(). Rebuild the UI only when
    # the actual variable/level topology changes, not on every text edit.
    if (!identical(topology, isolate(display_label_topology()))) {
      display_label_topology(topology)
    }
  }, priority = 110)

  output$display_labels_ui <- renderUI({
    graph_cold_diag_measure("output$display_labels_ui", function() {
      style_restore_epoch()
      shared_style_ui_epoch()
      topology <- display_label_topology()
      if (is.null(topology)) return(NULL)
      label_state <- isolate(level_labels())
      var_ui <- lapply(topology, function(row) {
        v <- row$variable
        branch <- label_state[[v]] %||% list()
        tags$div(
          class = "group-style-box",
          tags$b(paste0(v, " の条件名")),
          lapply(row$levels, function(lv) {
            val <- branch[[lv]]
            if (is.null(val) || !length(val) || !nzchar(as.character(val)[1])) val <- lv
            fluidRow(
              column(5, tags$div(style = "padding-top:7px;", lv)),
              column(7,
                textAreaInput(
                  style_input_id("level_label", paste0(v, "::", lv)),
                  label = NULL,
                  value = as.character(val)[1],
                  rows = 2,
                  resize = "vertical"
                )
              )
            )
          })
        )
      })
      tagList(
        tags$b("条件名（表示名）"),
        p(class = "help-block", "左が元データの値、右がグラフに表示する名前です。表示名はEnterで改行できます。"),
        var_ui
      )
    })
  })

  # Shiny's textAreaInput binding publishes during typing. Debounce the one
  # existing Shiny-input -> level_labels() commit, rather than constructing and
  # rendering a new GraphState on every character. Match the browser text
  # lease's existing 1000 ms quiet interval; use Shiny's supported debounce.
  display_label_input_snapshot <- reactive({
    topology <- display_label_topology()
    if (is.null(topology)) return(NULL)
    list(
      activation_generation = as.integer(graph_editor_activation_generation()),
      replay_generation = as.integer(graph_state_replay_generation()),
      style_epoch = as.integer(style_restore_epoch()),
      rows = lapply(topology, function(row) {
        v <- row$variable
        list(variable = v, fields = lapply(row$levels, function(lv) {
          id0 <- style_input_id("level_label", paste0(v, "::", lv))
          list(level = lv, value = input[[id0]])
        }))
      })
    )
  })
  display_label_input_settled <- shiny::debounce(
    display_label_input_snapshot, millis = 1000L
  )

  display_label_apply_snapshot <- function(snapshot) {
    if (!is.list(snapshot) || isTRUE(isolate(graph_state_replay_active())) ||
        isTRUE(isolate(restoring_style_state()))) return(invisible(FALSE))
    # A queued edit from an old Graph / different dynamic-input generation
    # must never become a write to the new persistent Editor owner.
    if (!identical(snapshot$activation_generation,
                   as.integer(isolate(graph_editor_activation_generation()))) ||
        !identical(snapshot$replay_generation,
                   as.integer(isolate(graph_state_replay_generation()))) ||
        !identical(snapshot$style_epoch,
                   as.integer(isolate(style_restore_epoch())))) return(invisible(FALSE))

    labels <- isolate(level_labels())
    changed <- FALSE
    for (row in snapshot$rows) {
      v <- row$variable
      branch <- labels[[v]] %||% list()
      branch_changed <- FALSE
      for (field in row$fields) {
        if (is.null(field$value)) next
        lv <- field$level
        z <- normalize_multiline_label(as.character(field$value)[1])
        old <- branch[[lv]]
        # Original or empty display names have the same ggplot meaning as no
        # override. Avoid storing redundant default/empty branches.
        if (!nzchar(trimws(z)) || identical(z, lv)) {
          if (!is.null(old)) {
            branch[[lv]] <- NULL
            branch_changed <- TRUE
          }
        } else if (is.null(old) || !identical(as.character(old)[1], z)) {
          branch[[lv]] <- z
          branch_changed <- TRUE
        }
      }
      if (branch_changed) {
        if (length(branch)) labels[[v]] <- branch else labels[[v]] <- NULL
        changed <- TRUE
      }
    }
    if (changed) {
      level_labels(labels)
      shared_style_mark_user_edit("level-label")
    }
    invisible(changed)
  }

  observeEvent(display_label_input_settled(), {
    display_label_apply_snapshot(display_label_input_settled())
  }, priority = 105)

  # An explicit Graph switch flushes the *current* Shiny input snapshot before
  # the previous owner's canonical state is captured. No unsent browser input
  # is guessed or re-routed; the normal GraphState publication stays the owner.
  display_label_flush_before_graph_switch <- function() {
    display_label_apply_snapshot(isolate(display_label_input_snapshot()))
  }
