# v3.73.2.18: normal Graph state replay for the one persistent Editor.
# Sourced inside graphServer after data/style/statistics runtimes are installed.
# This runtime is the only GraphState-to-Editor hydration path. It uses one
# value batch plus one browser completion barrier—no staged restore, semantic
# comparison, retry, or per-Graph DOM/module instances.

  graph_capture_editor_ui_snapshot <- function() {
    if (!graph_editor_profile_has(editor_profile, "full_shell")) {
      base <- isolate(attached_state_seed())
      return(graph_ui_snapshot_normalize(if (is.list(base)) base$ui_snapshot else NULL))
    }
    graph_ui_snapshot_normalize(list(
      schema_version = 2L,
      selections = list(
        graph_main_tab = as.character(input$graph_main_tab %||% "Plot")[1],
        sticky_plot = isTRUE(input$sticky_plot)
      ),
      panels = list()
    ))
  }

  graph_replay_selected <- function(snapshot, key, fallback = "") {
    z <- snapshot$selections[[key]]
    if (is.null(z) || !length(z)) return(fallback)
    as.character(unlist(z, use.names = FALSE))
  }

  graph_replay_apply_mapping_values <- function(cfg) {
    mp <- cfg$mapping %||% list()
    r <- cfg$reshape %||% list()
    plan <- isolate(graph_mapping_replay_plan())

    color <- json_chr(mp$color, "")
    if (identical(color, "__fixed__")) color <- ""

    # Keep saved values as short-lived seeds while ordinary observers process
    # the same replay.  Unlike the old path, the replay itself now sends the
    # target Graph's choice lists together with the selected values.  A switch
    # therefore never asks the browser to select a value against the previous
    # Graph's choices (which could coerce Color/Shape/ID/etc. to empty).
    if (graph_editor_profile_has(editor_profile, "reshape_controls")) {
      reshape_restore_seed(if (is.list(plan)) plan$reshape_columns else as.character(r$columns %||% character(0)))
    }
    restore_position_seed(if (is.list(plan)) plan$position else json_chr(mp$position, json_chr(mp$series, "")))
    restore_linetype_seed(if (is.list(plan)) plan$linetype else json_chr(mp$linetype, "__color__"))
    restore_external_error_seed(if (is.list(plan)) plan$external_error else json_chr(mp$external_error, ""))
    restore_external_ymin_seed(if (is.list(plan)) plan$external_ymin else json_chr(mp$external_ymin, ""))
    restore_external_ymax_seed(if (is.list(plan)) plan$external_ymax else json_chr(mp$external_ymax, ""))

    if (is.list(plan)) {
      if (graph_editor_profile_has(editor_profile, "reshape_controls")) {
        updateCheckboxGroupInput(
          session, "reshape_columns",
          choices = plan$raw_cols,
          selected = plan$reshape_columns
        )
      }
      updateSelectInput(session, "xvar", choices = plan$cols, selected = plan$x)
      updateSelectInput(session, "yvar", choices = plan$numeric_cols, selected = plan$y)
      updateSelectInput(session, "colorvar", choices = c("使わない（固定）" = "", plan$cols), selected = plan$color)
      updateSelectInput(session, "shapevar", choices = c("Color と同じ" = "__color__", "なし（固定）" = "", plan$cols), selected = plan$shape)
      updateSelectInput(session, "idvar", choices = c("なし" = "", plan$cols), selected = plan$id)
      updateSelectInput(session, "facetvar", choices = c("なし" = "", plan$cols), selected = plan$facet)
      updateSelectInput(session, "groupvar", choices = c("なし" = "", plan$cols), selected = plan$position)
      updateSelectInput(session, "line_series_mode", selected = plan$line_series_mode)
      updateSelectInput(session, "line_series_var", choices = c("なし" = "", plan$cols), selected = plan$line_series_var)
      updateSelectInput(
        session, "linetypevar",
        choices = c("色で分ける要因と同じ" = "__color__", "使わない（固定）" = "", plan$cols),
        selected = plan$linetype
      )
      updateSelectInput(session, "external_error_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_error)
      updateSelectInput(session, "external_ymin_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_ymin)
      updateSelectInput(session, "external_ymax_col", choices = c("なし" = "", plan$numeric_cols), selected = plan$external_ymax)
      return(invisible(TRUE))
    }

    # Invalid/partial legacy data falls back to value-only updates; the normal
    # data observers will rebuild choices from whatever data can be parsed.
    if (graph_editor_profile_has(editor_profile, "reshape_controls")) {
      updateCheckboxGroupInput(session, "reshape_columns", selected = as.character(r$columns %||% character(0)))
    }
    updateSelectInput(session, "xvar", selected = json_chr(mp$x, ""))
    updateSelectInput(session, "yvar", selected = json_chr(mp$y, ""))
    updateSelectInput(session, "colorvar", selected = color)
    updateSelectInput(session, "shapevar", selected = json_chr(mp$shape, "__color__"))
    updateSelectInput(session, "idvar", selected = json_chr(mp$id, ""))
    updateSelectInput(session, "facetvar", selected = json_chr(mp$facet, ""))
    updateSelectInput(session, "groupvar", selected = json_chr(mp$position, json_chr(mp$series, "")))
    updateSelectInput(session, "line_series_mode", selected = json_chr(mp$line_series_mode, "auto"))
    updateSelectInput(session, "line_series_var", selected = json_chr(mp$line_series_var, ""))
    updateSelectInput(session, "linetypevar", selected = json_chr(mp$linetype, "__color__"))
    updateSelectInput(session, "external_error_col", selected = json_chr(mp$external_error, ""))
    updateSelectInput(session, "external_ymin_col", selected = json_chr(mp$external_ymin, ""))
    updateSelectInput(session, "external_ymax_col", selected = json_chr(mp$external_ymax, ""))
    invisible(TRUE)
  }

  graph_replay_apply_scalar_controls <- function(cfg, replay_plan) {
    r <- cfg$reshape %||% list()
    pl <- cfg$plot %||% list()
    lb <- cfg$labels %||% list()
    rp <- replay_plan %||% list(full = TRUE)

    if (graph_editor_profile_has(editor_profile, "full_shell") &&
        isTRUE(rp$full_scalar_transport)) {
      # Full-Editor-only view state and editable Data/reshape controls. Each
      # subsection is transported only when its canonical owner changed.
      if (isTRUE(rp$full) || isTRUE(rp$ui_changed)) {
        snap <- graph_ui_snapshot_normalize(cfg$ui_snapshot)
        updateTabsetPanel(
          session, "graph_main_tab",
          selected = graph_replay_selected(snap, "graph_main_tab", "Plot")[1]
        )
        sticky_saved <- snap$selections$sticky_plot
        if (!is.null(sticky_saved) && length(sticky_saved)) {
          updateCheckboxInput(session, "sticky_plot", value = isTRUE(sticky_saved[[1]]))
        }
      }

      if ((isTRUE(rp$full) || isTRUE(rp$project_changed)) && !is.null(cfg$project_name)) {
        updateTextInput(session, "project_name", value = json_chr(cfg$project_name))
      }
      if ((isTRUE(rp$full) || isTRUE(rp$data_changed)) && !is.null(cfg$data_text)) {
        shinyAce::updateAceEditor(session, "text", value = json_chr(cfg$data_text))
      }

      if (isTRUE(rp$full) || isTRUE(rp$reshape_changed)) {
        updateCheckboxInput(session, "reshape_wide", value = isTRUE(r$enabled))
        updateCheckboxInput(session, "reshape_row_id", value = isTRUE(r$row_id))
        updateTextInput(session, "reshape_x_name", value = json_chr(r$x_name, "Time"))
        updateTextInput(session, "reshape_y_name", value = json_chr(r$y_name, "Value"))
      }
    }

    if (isTRUE(rp$shared_scalar_transport)) {
      if (isTRUE(rp$full) || isTRUE(rp$plot_changed)) {
        target_type <- json_chr(pl$type, "line")
        if (identical(target_type, "violin")) target_type <- "box"
        updateSelectInput(session, "plot_type", selected = target_type)
        updateSelectInput(session, "summary_type", selected = json_chr(pl$summary, "mean"))
        updateRadioButtons(session, "summary_unit", selected = json_chr(pl$summary_unit, "row"))
        updateRadioButtons(session, "external_error_mode", selected = json_chr(pl$external_error_mode, "none"))
        updateCheckboxInput(session, "show_raw", value = isTRUE(pl$show_raw))
        updateCheckboxInput(session, "connect_id", value = isTRUE(pl$connect_id))
        updateRadioButtons(
          session, "scatter_connect_mode",
          selected = json_chr(pl$scatter_connect_mode, if (isTRUE(pl$connect_id)) "id" else "none")
        )
      }

      if (isTRUE(rp$full) || isTRUE(rp$labels_changed)) {
        if (!is.null(lb$xlab)) updateTextAreaInput(session, "xlab", value = json_chr(lb$xlab))
        if (!is.null(lb$ylab)) updateTextAreaInput(session, "ylab", value = json_chr(lb$ylab))
        if (!is.null(lb$title)) updateTextInput(session, "title", value = json_chr(lb$title))
        if (!is.null(lb$ymin)) updateTextInput(session, "ymin", value = json_chr(lb$ymin))
        if (!is.null(lb$ymax)) updateTextInput(session, "ymax", value = json_chr(lb$ymax))
        if (!is.null(lb$y_top_to_tick)) updateCheckboxInput(session, "y_top_to_tick", value = isTRUE(lb$y_top_to_tick))
      }
    }
    invisible(TRUE)
  }

  graph_replay_apply_statistics <- function(cfg) {
    if (!graph_editor_profile_has(editor_profile, "statistics")) return(invisible(TRUE))
    restored <- cfg$statistics_recipes
    if (!is.list(restored)) restored <- list()

    # Statistics exists only in the Full Editor profile. Figure Controls keep
    # the source GraphState recipes untouched through profile state overlay.
    stats_replace_graph_context(
      restored = restored,
      preferred_id = cfg$statistics_selected_id %||% NULL,
      legacy_reshape = cfg$reshape %||% list()
    )
    invisible(TRUE)
  }

  graph_browser_direct_hydration_payload <- function(cfg, replay_plan, transaction = NULL) {
    values <- utils::modifyList(graph_snapshot_input_defaults(), graph_ui_seed_from_state(cfg))
    values$project_name <- graph_state_scalar(cfg$project_name, "")
    values$text <- graph_state_scalar(cfg$data_text, "")
    values$reshape_wide <- isTRUE((cfg$reshape %||% list())$enabled)
    values$reshape_row_id <- isTRUE((cfg$reshape %||% list())$row_id)
    values$reshape_x_name <- graph_state_scalar((cfg$reshape %||% list())$x_name, "Time")
    values$reshape_y_name <- graph_state_scalar((cfg$reshape %||% list())$y_name, "Value")
    snap <- graph_ui_snapshot_normalize(cfg$ui_snapshot)
    values$graph_main_tab <- graph_replay_selected(snap, "graph_main_tab", "Plot")[[1]]
    values$sticky_plot <- isTRUE(snap$selections$sticky_plot %||% FALSE)
    values$reshape_columns <- as.character((cfg$reshape %||% list())$columns %||% character(0))
    values$line_breaks <- as.character((cfg$plot %||% list())$line_breaks %||% character(0))

    mapping_plan <- isolate(graph_mapping_replay_plan())
    choices <- list()
    option_records <- function(x, labels = NULL) {
      x <- as.character(x %||% character(0))
      if (is.null(labels)) labels <- x
      labels <- as.character(labels)
      lapply(seq_along(x), function(i) list(label = labels[[i]], value = x[[i]]))
    }
    prepend_options <- function(prefix, x) c(prefix, option_records(x))
    if (is.list(mapping_plan)) {
      cols <- as.character(mapping_plan$cols %||% character(0))
      nums <- as.character(mapping_plan$numeric_cols %||% character(0))

      # Use the same target-derived, validity-checked Mapping plan for both the
      # option universe and the selected values. This prevents a stale/invalid
      # saved scalar from being selected against a newly rebuilt choice set.
      values$xvar <- as.character(mapping_plan$x %||% "")[1]
      values$yvar <- as.character(mapping_plan$y %||% "")[1]
      values$colorvar <- as.character(mapping_plan$color %||% "")[1]
      values$shapevar <- as.character(mapping_plan$shape %||% "__color__")[1]
      values$idvar <- as.character(mapping_plan$id %||% "")[1]
      values$facetvar <- as.character(mapping_plan$facet %||% "")[1]
      values$groupvar <- as.character(mapping_plan$position %||% "")[1]
      values$linetypevar <- as.character(mapping_plan$linetype %||% "__color__")[1]
      values$line_series_mode <- as.character(mapping_plan$line_series_mode %||% "auto")[1]
      values$line_series_var <- as.character(mapping_plan$line_series_var %||% "")[1]
      values$external_error_col <- as.character(mapping_plan$external_error %||% "")[1]
      values$external_ymin_col <- as.character(mapping_plan$external_ymin %||% "")[1]
      values$external_ymax_col <- as.character(mapping_plan$external_ymax %||% "")[1]
      values$reshape_columns <- as.character(mapping_plan$reshape_columns %||% character(0))

      choices$xvar <- option_records(cols)
      choices$yvar <- option_records(nums)
      choices$colorvar <- prepend_options(list(list(label = "使わない（固定）", value = "")), cols)
      choices$shapevar <- prepend_options(list(
        list(label = "Color と同じ", value = "__color__"),
        list(label = "なし（固定）", value = "")
      ), cols)
      choices$idvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$facetvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$groupvar <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$line_series_var <- prepend_options(list(list(label = "なし", value = "")), cols)
      choices$linetypevar <- prepend_options(list(
        list(label = "色で分ける要因と同じ", value = "__color__"),
        list(label = "使わない（固定）", value = "")
      ), cols)
      choices$external_error_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$external_ymin_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$external_ymax_col <- prepend_options(list(list(label = "なし", value = "")), nums)
      choices$reshape_columns <- option_records(mapping_plan$raw_cols %||% character(0))

      # line_breaks is a selectize whose option universe depends on the effective
      # X mapping/order. Keep it inside the same browser-direct choice phase so
      # the Full Editor never needs a late updateSelectizeInput() after READY.
      lb_plan <- tryCatch(graph_line_break_plan(cfg, mapping_plan), error = function(e) NULL)
      if (is.list(lb_plan) && !is.null(lb_plan$choices)) {
        lb_values <- as.character(unname(lb_plan$choices) %||% character(0))
        lb_labels <- as.character(names(lb_plan$choices) %||% lb_values)
        choices$line_breaks <- option_records(lb_values, lb_labels)
        saved_breaks <- as.character((cfg$plot %||% list())$line_breaks %||% character(0))
        values$line_breaks <- saved_breaks[saved_breaks %in% lb_values]
      }
    }

    list(
      graphId = as.character((transaction %||% list())$id %||% "")[[1]],
      generation = as.integer(isolate(graph_state_replay_generation()) %||% 0L),
      mode = if (graph_editor_profile_is_figure(editor_profile)) "figure_controls" else "full",
      inputPrefix = session$ns(""),
      patchInput = session$ns("graph_profile_browser_patch"),
      values = values,
      choices = choices,
      panels = snap$panels %||% list(),
      changedInputs = as.list(as.character(replay_plan$updated_inputs %||% character(0)))
    )
  }

  graph_browser_direct_publish_pools <- function(cfg) {
    if (!is.list(cfg) || !graph_editor_profile_has(editor_profile, "full_shell")) return(invisible(FALSE))
    d <- tryCatch(graph_snapshot_data(cfg), error = function(e) NULL)
    if (!is.data.frame(d)) return(invisible(FALSE))
    mp <- cfg$mapping %||% list()
    st <- cfg$style %||% list()
    app <- st$appearance %||% list()
    levels_for <- function(v) {
      v <- json_chr(v, "")
      if (!nzchar(v) || !v %in% names(d)) return(character(0))
      z <- d[[v]]
      lev <- levels(z)
      if (is.null(lev) || !length(lev)) lev <- unique(as.character(z))
      as.character(lev[!is.na(lev)])
    }
    color_var <- json_chr(mp$color, "")
    if (identical(color_var, "__fixed__")) color_var <- ""
    linetype_mode <- json_chr(mp$linetype, "__color__")
    linetype_var <- if (identical(linetype_mode, "__color__")) color_var else linetype_mode
    shape_mode <- json_chr(mp$shape, "__color__")
    shape_var <- if (identical(shape_mode, "__color__")) color_var else shape_mode
    position_var <- json_chr(mp$position, "")
    color_levels <- levels_for(color_var)
    linetype_levels <- levels_for(linetype_var)
    shape_levels <- levels_for(shape_var)
    color_branch <- (st$color_styles %||% list())[[color_var]] %||% list()
    fill_levels <- graph_bar_box_fill_none_levels(st$fill_none_styles %||% list(), color_var)
    plot_type <- json_chr((cfg$plot %||% list())$type, "line")
    bar_box <- plot_type %in% c("bar", "box")
    graph_slot_pool_publish("color_style", "color_fill", lapply(color_levels, function(lv) list(
      key = lv, label = lv, value = as.character(color_branch[[lv]] %||% "#333333")[1], fillNone = lv %in% fill_levels
    )), context_key = paste(c(color_var, color_levels, paste0("barbox=", bar_box)), collapse = "\u001f"),
      empty_text = "Colorに使う列がありません。", options = list(showFillNone = bar_box))
    lt_branch <- (st$linetype_styles %||% list())[[linetype_var]] %||% list()
    graph_slot_pool_publish("linetype_style", "linetype", lapply(linetype_levels, function(lv) list(
      key = lv, label = lv, value = as.character(lt_branch[[lv]] %||% "solid")[1]
    )), context_key = paste(c(linetype_var, linetype_levels), collapse = "\u001f"), empty_text = "Linetypeは固定です。")
    sh_branch <- (st$shape_styles %||% list())[[shape_var]] %||% list()
    graph_slot_pool_publish("shape_style", "shape", lapply(shape_levels, function(lv) list(
      key = lv, label = lv, value = as.character(sh_branch[[lv]] %||% 16)[1]
    )), context_key = paste(c(shape_var, shape_levels), collapse = "\u001f"), empty_text = "Shapeは固定です。")

    combo_entries <- list()
    combo_keys <- character(0)
    if (isTRUE(app$series_style_override) && nzchar(color_var) && nzchar(position_var) &&
        !identical(color_var, position_var) && position_var %in% names(d)) {
      combo_keys <- unique(graph_series_combo_key(as.character(d[[color_var]]), as.character(d[[position_var]])))
      combo_keys <- combo_keys[!is.na(combo_keys)]
      series <- st$series_styles %||% list()
      combo_entries <- lapply(combo_keys, function(key) list(
        key = key, label = key, value = as.character((series[[key]] %||% list())$color %||% "#333333")[1]
      ))
    }
    graph_slot_pool_publish("series_style", "color", combo_entries,
      context_key = paste(combo_keys, collapse = "\u001f"),
      empty_text = "Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。")

    raw_key <- if (length(combo_keys)) paste0("__combo__::", color_var, "::", position_var) else color_var
    raw_levels <- if (length(combo_keys)) combo_keys else color_levels
    raw_branch <- (st$raw_group_colors %||% list())[[raw_key]] %||% list()
    graph_slot_pool_publish("raw_group_color", "color", lapply(raw_levels, function(lv) list(
      key = lv, label = lv, value = as.character(raw_branch[[lv]] %||% "#555555")[1]
    )), context_key = paste(c(raw_key, raw_levels), collapse = "\u001f"), empty_text = "Colorに使う系列がありません。")
    invisible(TRUE)
  }

  graph_replay_finish <- function(generation, token) {
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!identical(as.integer(generation), pending_generation)) return(invisible(FALSE))
    cfg <- isolate(graph_state_replay_target())
    if (!is.list(cfg)) return(invisible(FALSE))

    # ACK follows immediate transport of bound input values (including Ace).
    # Ordinary choices writers were excluded throughout this transaction.
    # Release only after those inputs have crossed the server flush.
    attached_state_seed(cfg)
    graph_state_replay_completed_generation(as.integer(generation))
    graph_state_replay_active(FALSE)
    graph_state_replay_target(NULL)
    graph_state_replay_error(NULL)
    restoring_style_state(FALSE)
    diag("STATE-REPLAY", paste0("READY generation=", generation, " token=", token, " mode=mapping-transaction"))
    invisible(TRUE)
  }

  observeEvent(input$graph_state_replay_ack, {
    ack <- input$graph_state_replay_ack
    if (!is.list(ack)) return()
    generation <- suppressWarnings(as.integer(ack$generation %||% -1L))
    token <- as.character(ack$token %||% "")[1]
    pending_generation <- as.integer(isolate(graph_state_replay_generation()) %||% -1L)
    if (!isTRUE(isolate(graph_state_replay_active())) || !identical(generation, pending_generation)) return()
    if (!is.null(ack$error) && nzchar(as.character(ack$error)[1])) {
      err <- as.character(ack$error)[1]
      graph_state_replay_error(err)
      # Failure is terminal for this replay generation. Never leave the module
      # in replay_active=TRUE waiting for an ACK that already reported failure.
      graph_state_replay_active(FALSE)
      graph_state_replay_target(NULL)
      restoring_style_state(FALSE)
      diag("STATE-REPLAY", paste0("TRANSPORT-ERROR ", err, " terminal=TRUE"))
      return()
    }
    diag("STATE-REPLAY", paste0("browser-flush complete generation=", generation, " token=", token))
    # The ACK arrives after the browser processed the updateInput batch. Cross
    # one server flush so ordinary reactive observers can settle once before READY.
    session$onFlushed(function() {
      graph_replay_finish(generation, token)
    }, once = TRUE)
  }, ignoreInit = TRUE, priority = 200)

  graph_apply_state_replay <- function(cfg, transaction = NULL) {
    if (!is.list(cfg)) return(invisible(FALSE))
    snapshot <- graph_ui_snapshot_normalize(cfg$ui_snapshot)

    previous_state <- isolate(attached_state_seed())
    replay_plan <- graph_editor_replay_plan(previous_state, cfg, editor_profile)
    if (!is.list(replay_plan)) return(invisible(FALSE))

    generation <- as.integer(isolate(graph_state_replay_generation()) %||% 0L) + 1L
    graph_state_replay_generation(generation)
    graph_state_replay_error(NULL)
    graph_state_replay_target(cfg)
    # Keep one canonical mapping/data plan available for data-source reactives
    # throughout replay. Browser mapping controls are updated only when the
    # canonical delta requires it.
    graph_mapping_replay_plan(graph_replay_mapping_plan(cfg))
    graph_mapping_choices_seed(isolate(graph_mapping_replay_plan()))
    graph_state_replay_active(TRUE)
    restoring_style_state(TRUE)
    graph_seed_render_target(cfg, reason = "state-replay")

    diag(
      "STATE-REPLAY",
      paste0(
        "BEGIN generation=", generation,
        " profile=", editor_profile$name,
        " sections={", paste(replay_plan$sections, collapse=","), "}",
        " required={", paste(replay_plan$required_inputs, collapse=","), "}"
      )
    )

    browser_direct <- graph_editor_profile_has(editor_profile, "full_shell") ||
      graph_editor_profile_is_figure(editor_profile)
    apply_ok <- tryCatch({
      if (!isTRUE(browser_direct)) {
        graph_replay_apply_scalar_controls(cfg, replay_plan)
        if (isTRUE(replay_plan$mapping_transport)) graph_replay_apply_mapping_values(cfg)
      }
      if (isTRUE(replay_plan$mapping_transport) || isTRUE(replay_plan$plot_changed) || isTRUE(replay_plan$full)) {
        line_break_restore_from_cfg(
          cfg, isolate(graph_mapping_replay_plan()),
          hydrate_bound_control = !isTRUE(browser_direct)
        )
      }
      if (isTRUE(replay_plan$statistics_changed)) graph_replay_apply_statistics(cfg)
      if (isTRUE(replay_plan$style_changed) && is.list(cfg$style)) {
        apply_style_config(
          cfg$style, success_message = NULL, release_guard = FALSE, notify = FALSE,
          hydrate_bound_controls = !isTRUE(browser_direct)
        )
      }
      if (isTRUE(browser_direct)) graph_browser_direct_publish_pools(cfg)
      TRUE
    }, error = function(e) {
      graph_state_replay_error(conditionMessage(e))
      diag("STATE-REPLAY", paste0("APPLY-ERROR generation=", generation, " error=", conditionMessage(e)))
      FALSE
    })
    if (!isTRUE(apply_ok)) {
      graph_state_replay_active(FALSE)
      graph_state_replay_target(NULL)
      graph_state_replay_error(NULL)
      restoring_style_state(FALSE)
      return(invisible(FALSE))
    }

    token <- paste0("replay:", generation, ":", as.character((transaction %||% list())$id %||% "graph"))
    panels <- if (graph_editor_profile_has(editor_profile, "full_shell")) snapshot$panels %||% list() else list()
    browser_graph_id <- if (graph_editor_profile_has(editor_profile, "full_shell")) {
      as.character((transaction %||% list())$id %||% "")[1]
    } else ""
    required_inputs <- as.character(replay_plan$required_inputs %||% character(0))

    # The Full Editor is one persistent DOM.  Apply its target-derived values
    # and choices locally in the browser and release the canonical render on
    # the same server flush.  There is no per-input transport, binding scan,
    # ACK or READY retry. Figure Controls use the same transport in RC12, but
    # retain their separate Figure-owned base state and lifecycle gate.
    if (isTRUE(browser_direct)) {
      payload <- graph_browser_direct_hydration_payload(cfg, replay_plan, transaction)
      if (graph_editor_profile_is_figure(editor_profile)) {
        profile_browser_values(payload$values)
        profile_browser_paths(as.list(graph_browser_patch_path_contract(cfg)))
      }
      session$onFlushed(function() {
        if (!isTRUE(isolate(graph_state_replay_active())) ||
            !identical(as.integer(isolate(graph_state_replay_generation()) %||% -1L), generation)) return(invisible(NULL))
        session$sendCustomMessage("graph-state-browser-hydrate", payload)
        diag(
          "STATE-REPLAY",
          paste0(
            "apply mode=browser-direct generation=", generation,
            " scalar_count=", length(payload$values),
            " choice_sets=", length(payload$choices),
            " browser_barrier=NONE",
            if (graph_editor_profile_is_figure(editor_profile)) " figure_owner=preserved" else ""
          )
        )
        graph_replay_finish(generation, token)
        invisible(NULL)
      }, once = TRUE)
      return(invisible(TRUE))
    }

    session$onFlushed(function() {
      if (!isTRUE(isolate(graph_state_replay_active())) ||
          !identical(as.integer(isolate(graph_state_replay_generation()) %||% -1L), generation)) return(invisible(NULL))
      session$sendCustomMessage(
        "graph-state-replay-complete-request",
        list(
          generation = generation,
          token = token,
          graphId = browser_graph_id,
          panels = panels,
          ackId = session$ns("graph_state_replay_ack"),
          inputPrefix = session$ns(""),
          requiredInputs = if (length(required_inputs)) {
            as.list(unname(session$ns(required_inputs)))
          } else {
            list()
          }
        )
      )
      diag(
        "STATE-REPLAY",
        paste0(
          "apply fields=delta generation=", generation,
          " completion-barrier requested required_count=", length(required_inputs)
        )
      )
      invisible(NULL)
    }, once = TRUE)
    invisible(TRUE)
  }
