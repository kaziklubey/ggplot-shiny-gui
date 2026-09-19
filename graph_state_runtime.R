  # ============================================================
  # Project save / load
  # ============================================================
  project_settings <- reactive({
    # v3.58.3: recipe add/delete/rename lives in stats_recipes(), while the
    # selected Analysis fields are ordinary Shiny inputs.  Keep an explicit
    # dependency on the recipe collection so Project state is invalidated when
    # the collection changes; otherwise a cached project_settings() can keep an
    # older zero-recipe snapshot even though Statistics shows saved analyses.
    stats_recipes()

    list(
      version = "3.3.41",
      schema_version = 4L,
      app = "ggplot GUI",
      project_name = input$project_name,
      data_text = input$text,
      reshape = list(
        enabled = input$reshape_wide,
        row_id = input$reshape_row_id,
        columns = input$reshape_columns,
        x_name = input$reshape_x_name,
        y_name = input$reshape_y_name
      ),
      mapping = list(
        x = resolved_xvar(),
        y = resolved_yvar(),
        position = effective_position_var(dat()),
        color = input$colorvar,
        linetype = input$linetypevar %||% "__color__",
        shape = input$shapevar %||% "__color__",
        id = input$idvar,
        facet = input$facetvar,
        external_error = input$external_error_col %||% "",
        external_ymin = input$external_ymin_col %||% "",
        external_ymax = input$external_ymax_col %||% ""
      ),
      plot = list(
        type = input$plot_type,
        summary = input$summary_type,
        summary_unit = input$summary_unit %||% "row",
        external_error_mode = input$external_error_mode %||% "none",
        show_raw = input$show_raw,
        connect_id = input$connect_id,
        scatter_connect_mode = input$scatter_connect_mode %||% "none"
      ),
      labels = list(
        xlab = normalize_multiline_label(input$xlab),
        ylab = normalize_multiline_label(input$ylab),
        title = input$title,
        ymin = input$ymin,
        ymax = input$ymax,
        y_top_to_tick = input$y_top_to_tick
      ),
      export = list(
        mode = "follow_plot",
        reference_res = 120
      ),
      style = style_settings(),
      statistics_recipes = stats_recipes_for_project(),
      ui_snapshot = graph_capture_editor_ui_snapshot()
    )
  })

  # v3.4.0 alpha6 GraphState phase 1:
  # Once initial hydration is fully complete, persistent Graph edits are
  # committed back to the session-level canonical GraphState registry.
  # This removes the old requirement that a Graph must be switched/evicted
  # before graph_state_cache catches up with the live editor.  A short debounce
  # collapses slider/text bursts and also lets remounted input bindings settle.
  # v3.73.2.5: semantic Plot revision arbitration moved to
  # graph_state_boundary_runtime.R.  GraphState persistence remains here; the
  # new runtime owns the explicit live-browser vs attached-canonical boundary.

  project_settings_for_commit <- shiny::debounce(project_settings, millis = 200)
  observe({
    state_now <- project_settings_for_commit()
    if (!is.function(on_state_change)) return()
    if (isTRUE(isolate(graph_state_replay_active()))) return()
    # A READY graphServer can outlive its browser inputs. During DOM remount,
    # dynamic controls briefly disappear/rebind; never let those transient
    # NULL/default values overwrite the canonical registry state.
    if (!is.null(remount_state_seed())) return()
    if (!isTRUE(initial_restore_done())) return()
    if (!isTRUE(restore_stage3_done())) return()
    if (!isTRUE(restore_final_done())) return()
    if (!is.null(restore_error())) return()
    if (!identical(project_restore_stage(), 0)) return()
    if (isTRUE(restoring_style_state())) return()

    tryCatch(
      {
        on_state_change(state_now)
        # Keep the safety snapshot canonical: refresh it only after the outer
        # registry commit callback has accepted this live Editor state.
        attached_state_seed(state_now)
      },
      error = function(e) diag("STATE-COMMIT", paste0("callback error: ", conditionMessage(e)))
    )
  }, priority = -50)

  output$download_project <- downloadHandler(
    filename = function() {
      nm <- trimws(input$project_name %||% "")
      if (!nzchar(nm)) nm <- paste0("ggplot_project_", Sys.Date())
      nm <- gsub("[\\/:*?\"<>|]+", "_", nm)
      paste0(nm, ".ggplotproj")
    },
    content = function(file) {
      jsonlite::write_json(json_safe_tree(project_settings()), file, pretty = TRUE, auto_unbox = TRUE, null = "null")
    }
  )

  # v3.72.7: direct-sync delta mask.  Full Project restore continues to apply
  # every saved field.  The persistent single Editor may instead update only
  # GraphState branches that differ from the state currently shown in the shell.
  direct_sync_path_changed <- function(prefix) {
    if (is.null(isolate(direct_sync_project()))) return(TRUE)
    paths <- isolate(direct_sync_diff_paths())
    if (is.null(paths)) return(TRUE)
    if (!length(paths)) return(FALSE)
    prefix <- as.character(prefix %||% "")[1]
    if (!nzchar(prefix)) return(length(paths) > 0L)
    any(paths == prefix | startsWith(paths, paste0(prefix, ".")))
  }

  direct_sync_any_changed <- function(prefixes) {
    any(vapply(prefixes, direct_sync_path_changed, logical(1)))
  }

  # Re-assert dynamic style trees from the target canonical GraphState after
  # their renderUI controls have been rebuilt.  colourInput/selectInput values
  # from the previously edited Graph can arrive one flush late; keeping
  # restoring_style_state=TRUE until this exact snapshot has reached the DOM
  # prevents those stale browser values from becoming canonical state.
  reassert_dynamic_style_state <- function(cfg) {
    st <- cfg$style %||% list()
    if (!is.list(st)) return(invisible(FALSE))

    if (!is.null(st$color_styles)) {
      color_styles(parse_style_tree(st$color_styles, "color"))
    } else if (!is.null(st$group_styles) && length(st$group_styles)) {
      mv <- legacy_mapping_vars(cfg$mapping)
      migrate_legacy_group_styles(st$group_styles, mv$color, mv$linetype, mv$shape)
    }
    if (!is.null(st$linetype_styles)) linetype_styles(parse_style_tree(st$linetype_styles, "linetype"))
    if (!is.null(st$shape_styles)) shape_styles(parse_style_tree(st$shape_styles, "shape"))

    if (!is.null(st$raw_group_colors)) {
      if (!length(st$raw_group_colors)) {
        raw_group_colors(list())
      } else {
        first_val <- st$raw_group_colors[[1]]
        if (is.list(first_val) && !is.null(names(first_val))) {
          raw_group_colors(parse_style_tree(st$raw_group_colors, "color"))
        } else {
          mv <- legacy_mapping_vars(cfg$mapping); rc <- list(); br <- list()
          for (nm in names(st$raw_group_colors)) br[[nm]] <- json_chr(st$raw_group_colors[[nm]], "#777777")
          if (nzchar(mv$color)) rc[[mv$color]] <- br
          raw_group_colors(rc)
        }
      }
    }

    if (!is.null(st$legend_titles)) {
      lt <- list()
      for (nm in names(st$legend_titles)) lt[[nm]] <- json_chr(st$legend_titles[[nm]], "")
      legend_titles(lt)
    }
    if (!is.null(st$level_labels)) {
      ll <- list()
      for (vn in names(st$level_labels)) {
        branch <- st$level_labels[[vn]]; bb <- list()
        for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
        ll[[vn]] <- bb
      }
      level_labels(ll)
    }
    shared_style_binding(shared_style_normalize_binding(st$shared_library %||% NULL))

    invisible(TRUE)
  }

  # v3.63.0-editor-shell1: fixed-shell GraphState sync for the persistent single editor.
  # Preconditions are checked by server.R: same raw data, reshape schema and
  # plot type. The input DOM/bindings are therefore already alive. This path
  # does not run reshape/mapping binding handshakes; it only changes the state
  # referenced by the existing editor controls, verifies Mapping, then reuses
  # the ordinary stage-3 style application/finalization.
  sync_editor_from_state <- function(cfg) {
    if (is.null(cfg) || !is.list(cfg)) return(invisible(FALSE))

    restore_timing_reset()
    diag("EDITOR-SYNC", "BEGIN fixed-shell GraphState sync")
    initial_restore_started(TRUE)
    initial_restore_done(FALSE)
    restore_stage3_done(FALSE)
    restore_final_done(FALSE)
    mapping_restore_resync_count(0L)
    restore_diag_stage2_available_logged(FALSE)
    restore_parent_preseed_match(FALSE)
    restore_parent_preseed_consumed(FALSE)
    reset_mapping_binding_wait()
    reset_reshape_binding_wait(clear_seed = TRUE)
    restore_error(NULL)

    # v3.72.7: snapshot the state currently represented by the singleton Editor
    # before declaring the target Graph canonical for this sync transaction.
    # The delta mask is used only to suppress redundant browser update messages;
    # GraphState remains the full target state throughout verification/commit.
    current_editor_state <- tryCatch(isolate(project_settings()), error = function(e) NULL)
    sync_diff <- if (is.list(current_editor_state)) {
      app_state_diff_paths(current_editor_state, cfg)
    } else {
      character(0)
    }
    if (!is.list(current_editor_state)) sync_diff <- NULL
    # From this point onward cfg is the canonical state being attached to the
    # singleton. Preserve it across the browser rebuild/final READY boundary.
    attached_state_seed(cfg)
    graph_seed_render_target(cfg, reason = "editor-sync")
    direct_sync_diff_paths(sync_diff)
    direct_sync_project(cfg)
    diag(
      "EDITOR-SYNC-DELTA",
      paste0(
        "paths=", if (is.null(sync_diff)) "<FULL>" else length(sync_diff),
        if (length(sync_diff %||% character(0))) paste0(
          " {", paste(head(sync_diff, 24L), collapse = ","),
          if (length(sync_diff) > 24L) ",..." else "", "}"
        ) else ""
      )
    )

    r_seed <- cfg$reshape %||% list()
    if (direct_sync_path_changed("reshape") && isTRUE(r_seed$enabled)) {
      seed_cols <- json_vec(r_seed$columns)
      if (length(seed_cols)) reshape_restore_seed(seed_cols)
    }

    size_seed <- saved_plot_size_from_state(cfg)
    size_changed <- direct_sync_any_changed(c(
      "style.appearance.plot_width_px", "style.appearance.plot_height_px"
    ))
    if (isTRUE(size_changed)) {
      plot_width_restore_seed(size_seed$width)
      plot_height_restore_seed(size_seed$height)
      updateNumericInput(session, "plot_width_px_direct", value = size_seed$width)
      updateNumericInput(session, "plot_height_px_direct", value = size_seed$height)
      if (size_seed$width >= 300 && size_seed$width <= 1400) {
        updateSliderInput(session, "plot_width_px", value = size_seed$width)
      }
      if (size_seed$height >= 220 && size_seed$height <= 900) {
        updateSliderInput(session, "plot_height_px", value = size_seed$height)
      }
    } else {
      plot_width_restore_seed(NULL)
      plot_height_restore_seed(NULL)
    }

    target_type_seed <- json_chr(cfg$plot$type, "line")
    if (identical(target_type_seed, "violin")) target_type_seed <- "box"

    mp_seed <- cfg$mapping
    if (direct_sync_path_changed("mapping") && !is.null(mp_seed)) {
      if (target_type_seed %in% c("line", "bar", "box")) {
        restore_position_seed(json_chr(mp_seed$position, json_chr(mp_seed$series)))
      } else {
        restore_position_seed(NULL)
      }
      if (target_type_seed %in% c("line", "scatter")) {
        restore_linetype_seed(json_chr(mp_seed$linetype, "__color__"))
      } else {
        restore_linetype_seed(NULL)
      }
      ee <- json_chr(mp_seed$external_error)
      el <- json_chr(mp_seed$external_ymin)
      eh <- json_chr(mp_seed$external_ymax)
      restore_external_error_seed(if (nzchar(ee)) ee else NULL)
      restore_external_ymin_seed(if (nzchar(el)) el else NULL)
      restore_external_ymax_seed(if (nzchar(eh)) eh else NULL)
    } else {
      restore_position_seed(NULL)
      restore_linetype_seed(NULL)
      restore_external_error_seed(NULL)
      restore_external_ymin_seed(NULL)
      restore_external_ymax_seed(NULL)
    }

    restore_notify(FALSE)
    plot_drawn(FALSE)
    restoring_style_state(TRUE)
    project_restore_wait_count(0L)
    project_restore_wait_phase("")
    mapping_stage3_flush_pending(FALSE)

    if (direct_sync_path_changed("statistics_recipes")) {
      restored_stats <- cfg$statistics_recipes
      if (is.null(restored_stats) || !is.list(restored_stats)) restored_stats <- list()
      restored_stats <- normalize_stats_recipes(restored_stats, legacy_reshape = cfg$reshape %||% list())
      stats_post_restore_baseline(NULL)
      stats_recipes(restored_stats)
      first_stats_id <- if (length(restored_stats)) names(restored_stats)[1] else NULL
      stats_selected_id(first_stats_id)
      pending_stats_ui_restore(first_stats_id)
      refresh_stats_choices(first_stats_id)
      diag("STATS-RESTORE", paste0(
        "direct-switch recipes=", length(restored_stats),
        " ids={", paste(names(restored_stats), collapse = ","), "}",
        " results_saved=FALSE recalc_on_open=TRUE"
      ))
    } else {
      diag("EDITOR-SYNC-DELTA", "statistics unchanged; UI refresh skipped")
    }

    if (direct_sync_path_changed("project_name") && !is.null(cfg$project_name)) {
      updateTextInput(session, "project_name", value = json_chr(cfg$project_name))
    }

    # The persistent-editor sync can be initiated from a non-reactive callback
    # (notably startup onFlushed). During the transaction GraphState is the
    # canonical source. v3.72.7 sends the plot type only when it actually differs.
    if (direct_sync_path_changed("plot.type")) {
      updateSelectInput(session, "plot_type", selected = target_type_seed)
    }

    # Likewise, obtain the current prepared data without registering/depending
    # on a reactive consumer.  Later verification continues inside observers.
    d <- tryCatch(isolate(dat()), error = function(e) NULL)
    if (is.null(d)) {
      abort_project_restore("Editor syncでprepared dataを取得できませんでした。")
      return(invisible(FALSE))
    }

    mp <- cfg$mapping
    if (!is.null(mp)) {
      restored_color <- json_chr(mp$color)
      if (!nzchar(restored_color) && is.null(mp$position) && nzchar(json_chr(mp$series))) {
        restored_color <- json_chr(mp$series)
      }
      if (identical(restored_color, "__fixed__")) restored_color <- ""

      expected_map <- list(
        xvar = json_chr(mp$x),
        yvar = json_chr(mp$y),
        colorvar = restored_color,
        shapevar = json_chr(mp$shape, "__color__"),
        idvar = json_chr(mp$id),
        facetvar = json_chr(mp$facet)
      )
      if (target_type_seed %in% c("line", "bar", "box")) {
        expected_map$groupvar <- json_chr(mp$position, json_chr(mp$series))
      }
      if (target_type_seed %in% c("line", "scatter")) {
        expected_map$linetypevar <- json_chr(mp$linetype, "__color__")
      }

      wanted <- unique(unlist(expected_map, use.names = FALSE))
      wanted <- wanted[nzchar(wanted) & !wanted %in% c("__color__", "__fixed__")]
      if (!all(wanted %in% names(d))) {
        abort_project_restore(paste0(
          "Editor syncのMapping列が現在のデータにありません: ",
          paste(setdiff(wanted, names(d)), collapse = ", ")
        ))
        return(invisible(FALSE))
      }

      # v3.63.1-editor-shell2: do not freeze persistent Mapping inputs during
      # a GraphState sync. The editor-level loading guard already blocks
      # UI -> Registry commits. freezeReactiveValue() made the immediate
      # verification phase observe these fixed inputs as transient <NULL>,
      # which unnecessarily entered the legacy RESTORE-RESYNC path.
      map_path <- c(
        xvar = "mapping.x", yvar = "mapping.y", colorvar = "mapping.color",
        shapevar = "mapping.shape", idvar = "mapping.id", facetvar = "mapping.facet",
        groupvar = "mapping.position", linetypevar = "mapping.linetype"
      )
      sent_fields <- character(0)
      for (field in names(expected_map)) {
        prefixes <- map_path[[field]]
        changed_field <- direct_sync_path_changed(prefixes)
        if (identical(field, "groupvar")) {
          changed_field <- changed_field || direct_sync_path_changed("mapping.series")
        }
        if (!isTRUE(changed_field)) next
        updateSelectInput(session, field, selected = expected_map[[field]])
        sent_fields <- c(sent_fields, field)
      }
      diag("EDITOR-SYNC-DELTA", paste0(
        "mapping sent={", paste(sent_fields, collapse = ","), "}",
        " skipped=", length(expected_map) - length(sent_fields)
      ))
    }

    # Skip restore stages 1/2 and every browser binding ACK. Enter the shared
    # style/finalization stage only after this update batch has been flushed to
    # the browser. This is a UI-sync transaction, not a restore handshake.
    project_restore_stage(2)
    session$onFlushed(function() {
      if (!isTRUE(isolate(initial_restore_started())) ||
          !identical(isolate(project_restore_stage()), 2) ||
          is.null(isolate(direct_sync_project()))) {
        diag("EDITOR-SYNC", "stale sync flush ignored")
        return(invisible(NULL))
      }
      project_restore_stage(3)
      diag("EDITOR-SYNC", "input update flush complete; verify/apply style")
      invisible(NULL)
    }, once = TRUE)
    invisible(TRUE)
  }

  start_state_restore <- function(cfg, notify = FALSE, parent_preseed_match = FALSE) {
    if (is.null(cfg)) return(invisible(FALSE))
    restore_timing_reset()
    diag("RESTORE", "start_state_restore BEGIN")
    initial_restore_started(TRUE)
    initial_restore_done(FALSE)
    restore_stage3_done(FALSE)
    restore_final_done(FALSE)
    mapping_restore_resync_count(0L)
    restore_diag_stage2_available_logged(FALSE)
    restore_parent_preseed_match(isTRUE(controls_only) && isTRUE(parent_preseed_match))
    restore_parent_preseed_consumed(FALSE)
    reset_mapping_binding_wait()
    reset_reshape_binding_wait(clear_seed = TRUE)
    restore_error(NULL)
    deferred_initial_state(cfg)
    attached_state_seed(cfg)
    graph_seed_render_target(cfg, reason = "state-restore")

    r_seed <- cfg$reshape %||% list()
    if (isTRUE(r_seed$enabled)) {
      seed_cols <- json_vec(r_seed$columns)
      if (length(seed_cols)) reshape_restore_seed(seed_cols)
    }

    # ------------------------------------------------------------
    # Stage 0: Plot size first
    # ------------------------------------------------------------
    # Graphを表示するかなり前に保存済みpanel/device寸法を確定させる。
    # 巨大Plotでも「600×600でpanel生成 → 後から巨大化」という
    # レイアウト時間差を作らない。
    size_seed <- saved_plot_size_from_state(cfg)
    plot_width_restore_seed(size_seed$width)
    plot_height_restore_seed(size_seed$height)

    updateNumericInput(
      session, "plot_width_px_direct",
      value = size_seed$width
    )
    updateNumericInput(
      session, "plot_height_px_direct",
      value = size_seed$height
    )

    if (size_seed$width >= 300 && size_seed$width <= 1400) {
      updateSliderInput(
        session, "plot_width_px",
        value = size_seed$width
      )
    }
    if (size_seed$height >= 220 && size_seed$height <= 900) {
      updateSliderInput(
        session, "plot_height_px",
        value = size_seed$height
      )
    }

    target_type_seed <- json_chr(cfg$plot$type, "line")
    if (identical(target_type_seed, "violin")) target_type_seed <- "box"

    mp_seed <- cfg$mapping
    if (!is.null(mp_seed)) {
      if (target_type_seed %in% c("line", "bar", "box")) {
        restore_position_seed(
          json_chr(mp_seed$position, json_chr(mp_seed$series))
        )
      } else {
        restore_position_seed(NULL)
      }

      if (target_type_seed %in% c("line", "scatter")) {
        restore_linetype_seed(
          json_chr(mp_seed$linetype, "__color__")
        )
      } else {
        restore_linetype_seed(NULL)
      }
    } else {
      restore_position_seed(NULL)
      restore_linetype_seed(NULL)
    }

    # Error bar列はdynamic selectInputなので、保存値を先にseedして
    # 自動候補observerとの競合から守る。旧ProjectではNULL。
    if (!is.null(mp_seed)) {
      ee <- json_chr(mp_seed$external_error)
      el <- json_chr(mp_seed$external_ymin)
      eh <- json_chr(mp_seed$external_ymax)
      restore_external_error_seed(if (nzchar(ee)) ee else NULL)
      restore_external_ymin_seed(if (nzchar(el)) el else NULL)
      restore_external_ymax_seed(if (nzchar(eh)) eh else NULL)
    } else {
      restore_external_error_seed(NULL)
      restore_external_ymin_seed(NULL)
      restore_external_ymax_seed(NULL)
    }

    restore_notify(isTRUE(notify))
    plot_drawn(FALSE)
    restoring_style_state(TRUE)
    pending_project(cfg)
    project_restore_wait_count(0L)
    project_restore_wait_phase("")
    mapping_stage3_flush_pending(FALSE)
    project_restore_stage(1)

    # StatisticsはGraph本体の復元から分離する。
    # recipeのみメモリへ戻し、UI入力の復元・自動計算はStatisticsタブを
    # 実際に開いた時まで遅延する。
    restored_stats <- cfg$statistics_recipes
    if (is.null(restored_stats) || !is.list(restored_stats)) {
      restored_stats <- list()
    }

    # Project内の各Analysisを独立したrecipeとして正規化してから格納する。
    # ここではbrowser inputを一切参照しない。
    restored_stats <- normalize_stats_recipes(restored_stats, legacy_reshape = cfg$reshape %||% list())
    stats_post_restore_baseline(NULL)
    stats_recipes(restored_stats)
    diag("STATS-RESTORE", paste0(
      "loaded recipes=", length(restored_stats),
      " ids={", paste(names(restored_stats), collapse = ","), "}",
      " results_saved=FALSE recalc_on_open=TRUE"
    ))

    # Seed the dynamic ANOVA UI structure from Project data itself.
    # The selected Analysis will set it again in load_stats_recipe(), but this
    # prevents an initial 2-factor flash/stale UI during Project restoration.
    if (length(restored_stats)) {
      first_stats_id <- names(restored_stats)[1]
      fn0 <- restored_stats[[first_stats_id]]$factor_n %||% "two"
      if (!fn0 %in% c("one", "two", "three")) fn0 <- "two"
      stats_ui_factor_n(fn0)
    }

    first_stats_id <- if (length(restored_stats)) names(restored_stats)[1] else NULL
    stats_selected_id(first_stats_id)
    pending_stats_ui_restore(first_stats_id)

    # choicesの更新だけは軽量なので行う。個々の設定UIはまだ触らない。
    refresh_stats_choices(first_stats_id)

    # 第1段階: 動的UIの土台になる値だけ先に戻す
    if (!is.null(cfg$project_name)) {
      updateTextInput(session, "project_name", value = json_chr(cfg$project_name))
    }
    if (!is.null(cfg$data_text)) {
      shinyAce::updateAceEditor(session, "text", value = json_chr(cfg$data_text))
    }

    r <- cfg$reshape
    if (!is.null(r) && !isTRUE(isolate(restore_parent_preseed_match()))) {
      if (!is.null(r$enabled)) updateCheckboxInput(session, "reshape_wide", value = isTRUE(r$enabled))
      if (!is.null(r$row_id)) updateCheckboxInput(session, "reshape_row_id", value = isTRUE(r$row_id))
      if (!is.null(r$x_name)) updateTextInput(session, "reshape_x_name", value = json_chr(r$x_name, "Time"))
      if (!is.null(r$y_name)) updateTextInput(session, "reshape_y_name", value = json_chr(r$y_name, "Value"))
    }

    if (isTRUE(notify)) {
      showNotification("Graph設定を復元しています…", type = "message", duration = 2)
    }
    invisible(TRUE)
  }

  observeEvent(input$upload_project, {
    req(input$upload_project$datapath)
    cfg <- tryCatch(
      jsonlite::read_json(input$upload_project$datapath, simplifyVector = FALSE),
      error = function(e) NULL
    )
    shiny::validate(shiny::need(!is.null(cfg), "プロジェクトファイルを読み込めませんでした。"))
    start_state_restore(cfg, notify = TRUE)
  })

  # 第2段階: 元データが更新された後にWide→Long対象列を戻す
  observe({
    cfg <- pending_project()
    if (is.null(cfg) || project_restore_stage() != 1) return()

    d0 <- tryCatch(
      raw_dat(),
      error = function(e) {
        if (restore_diag_checkpoint()) restore_diag_condition("stage1 raw_dat error", e, cfg)
        NULL
      }
    )
    if (is.null(d0)) {
      restore_wait("元データを再構成できませんでした。", phase = "stage1-raw-data")
      return()
    }
    r <- cfg$reshape
    if (!is.null(r) && isTRUE(r$enabled)) {
      # The child reshape_columns UI lives inside a conditionalPanel controlled
      # by reshape_wide.  During restore, static parent controls can still be
      # unbound when the first update messages are sent.  Confirm the parent
      # inputs are bound and that the browser/server round-trip has applied the
      # saved parent state before asking the child UI for its binding ack.
      parent_expected <- list(
        enabled = TRUE,
        row_id = if (!is.null(r$row_id)) isTRUE(r$row_id) else TRUE,
        x_name = json_chr(r$x_name, "Time"),
        y_name = json_chr(r$y_name, "Value")
      )

      figure_parent_preseed_match <- isTRUE(controls_only) &&
        isTRUE(isolate(restore_parent_preseed_match()))
      persistent_parent_match <- isTRUE(persistent_shell) &&
        isTRUE(restore_current_reshape_parent_matches(parent_expected))
      parent_fast_match <- isTRUE(figure_parent_preseed_match) || isTRUE(persistent_parent_match)
      if (isTRUE(parent_fast_match)) {
        if (!isTRUE(isolate(restore_parent_preseed_consumed()))) {
          restore_parent_preseed_consumed(TRUE)
          project_restore_wait_count(0L)
          project_restore_wait_phase("")
          if (isTRUE(figure_parent_preseed_match)) {
            diag("FIGURE-EDIT-FAST", "stage=parent status=match; static parent restore skipped")
          } else {
            diag("RESTORE-FAST", "RESHAPE-PARENT persistent shell already matches; browser binding ACK skipped")
          }
        }
      } else {
        parent_pending <- isolate(reshape_parent_binding_pending())
        parent_ack <- input$reshape_parent_restore_binding_ack

        if (is.null(parent_pending)) {
        project_restore_wait_count(0L)
        request_reshape_parent_binding_ack(parent_expected)
        return()
      }

      if (!isTRUE(parent_pending$server_observed)) {
        parent_ack_generation <- suppressWarnings(as.integer(parent_ack$generation %||% NA_integer_))
        if (is.null(parent_ack) ||
            !identical(parent_ack_generation, as.integer(parent_pending$generation))) {
          restore_wait("Wide→Long親UIのbrowser bindingを確認できませんでした。", phase = "reshape-parent-binding")
          return()
        }

        parent_ack_status <- as.character(parent_ack$status %||% "")[1]
        if (!identical(parent_ack_status, "ready")) {
          missing <- as.character(unlist(parent_ack$missing %||% character(0), use.names = FALSE))
          diag(
            "RESHAPE-PARENT",
            paste0(
              "timeout generation=", parent_pending$generation,
              " missing=", if (length(missing)) paste(missing, collapse = ",") else "<unknown>",
              " ", restore_binding_ack_diag(parent_ack)
            )
          )
          abort_project_restore(paste0(
            "Wide→Long親UIのbrowser bindingを確認できませんでした",
            if (length(missing)) paste0(": ", paste(missing, collapse = ", ")) else "。"
          ))
          return()
        }

        if (!isTRUE(parent_pending$values_sent)) {
          diag(
            "RESHAPE-PARENT",
            paste0("ack generation=", parent_pending$generation, " fields=reshape_wide,reshape_row_id,reshape_x_name,reshape_y_name")
          )
          restore_timing_mark("RESHAPE-PARENT-ACK", parent_pending$generation, from = "RESHAPE-PARENT-REQUEST")
          browser_preseed_ok <-
            restore_ack_scalar_matches(parent_ack, "reshape_wide", TRUE, logical_value = TRUE) &&
            restore_ack_scalar_matches(parent_ack, "reshape_row_id", isTRUE(parent_expected$row_id), logical_value = TRUE) &&
            restore_ack_scalar_matches(parent_ack, "reshape_x_name", parent_expected$x_name) &&
            restore_ack_scalar_matches(parent_ack, "reshape_y_name", parent_expected$y_name)
          if (!isTRUE(browser_preseed_ok)) {
            freezeReactiveValue(input, "reshape_wide")
            freezeReactiveValue(input, "reshape_row_id")
            freezeReactiveValue(input, "reshape_x_name")
            freezeReactiveValue(input, "reshape_y_name")
            updateCheckboxInput(session, "reshape_wide", value = TRUE)
            updateCheckboxInput(session, "reshape_row_id", value = isTRUE(parent_expected$row_id))
            updateTextInput(session, "reshape_x_name", value = parent_expected$x_name)
            updateTextInput(session, "reshape_y_name", value = parent_expected$y_name)
          } else {
            diag("RESTORE-FAST", paste0("RESHAPE-PARENT generation=", parent_pending$generation, " browser preseed already matches; update messages skipped"))
          }
          parent_pending$values_sent <- TRUE
          project_restore_wait_phase("reshape-parent-value")
          project_restore_wait_count(0L)
          reshape_parent_binding_pending(parent_pending)
          diag(
            "RESHAPE-PARENT",
            paste0(
              if (isTRUE(browser_preseed_ok)) "preseed accepted" else "restore values sent",
              " generation=", parent_pending$generation,
              " enabled=TRUE row_id=", isTRUE(parent_expected$row_id),
              " x=", parent_expected$x_name,
              " y=", parent_expected$y_name
            )
          )
          restore_timing_mark("RESHAPE-PARENT-SENT", parent_pending$generation)
          # Do not return here. The browser ACK may already describe values that
          # are also current on the Shiny server. Validate in this same reactive
          # execution so a no-op/preseed match does not wait for an input change
          # that will never occur. If the server is still behind, the reads below
          # establish reactive dependencies and the client update will re-run us.
        }

        actual_enabled <- tryCatch(input$reshape_wide, error = function(e) NULL)
        actual_row_id <- tryCatch(input$reshape_row_id, error = function(e) NULL)
        actual_x <- tryCatch(input$reshape_x_name, error = function(e) NULL)
        actual_y <- tryCatch(input$reshape_y_name, error = function(e) NULL)
        parent_ok <- !is.null(actual_enabled) && identical(isTRUE(actual_enabled), TRUE) &&
          !is.null(actual_row_id) && identical(isTRUE(actual_row_id), isTRUE(parent_expected$row_id)) &&
          !is.null(actual_x) && identical(as.character(actual_x)[1], parent_expected$x_name) &&
          !is.null(actual_y) && identical(as.character(actual_y)[1], parent_expected$y_name)

        if (!isTRUE(parent_ok)) {
          if (restore_diag_checkpoint()) {
            diag(
              "RESHAPE-PARENT",
              paste0(
                "waiting server values generation=", parent_pending$generation,
                " enabled=", restore_diag_value(actual_enabled),
                " row_id=", restore_diag_value(actual_row_id),
                " x=", restore_diag_value(actual_x),
                " y=", restore_diag_value(actual_y)
              )
            )
          }
          restore_wait("保存済みWide→Long親設定をUIへ反映できませんでした。", phase = "reshape-parent-value")
          return()
        }

        parent_pending$server_observed <- TRUE
        reshape_parent_binding_pending(parent_pending)
        project_restore_wait_count(0L)
        diag(
          "RESHAPE-PARENT",
          paste0(
            "server values observed generation=", parent_pending$generation,
            " enabled=TRUE row_id=", isTRUE(actual_row_id),
            " x=", as.character(actual_x)[1],
            " y=", as.character(actual_y)[1]
          )
        )
        restore_timing_mark("RESHAPE-PARENT-OBSERVED", parent_pending$generation, from = "RESHAPE-PARENT-SENT")
      }

      }

      wanted <- json_vec(r$columns)
      if (length(wanted)) {
        wanted <- wanted[wanted %in% names(d0)]
      }

      if (length(wanted)) {
        # Keep renderUI selected state anchored to the saved Project values.
        if (!identical(isolate(reshape_restore_seed()), wanted)) {
          reshape_restore_seed(wanted)
        }

        pending_bind <- isolate(reshape_binding_pending())
        ack <- input$reshape_restore_binding_ack

        if (is.null(pending_bind)) {
          # Parent state is now confirmed on the server.  Only now ask the
          # browser to acknowledge the dynamic child checkbox binding.
          project_restore_wait_count(0L)
          request_reshape_binding_ack(wanted)
          return()
        }

        ack_generation <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
        if (is.null(ack) || !identical(ack_generation, as.integer(pending_bind$generation))) {
          restore_wait("Wide→Long対象列UIのbrowser bindingを確認できませんでした。", phase = "reshape-child-binding")
          return()
        }

        ack_status <- as.character(ack$status %||% "")[1]
        if (!identical(ack_status, "ready")) {
          missing <- as.character(unlist(ack$missing %||% character(0), use.names = FALSE))
          diag(
            "RESHAPE-BIND",
            paste0(
              "timeout generation=", pending_bind$generation,
              " missing=", if (length(missing)) paste(missing, collapse = ",") else "<unknown>",
              " ", restore_binding_ack_diag(ack)
            )
          )
          abort_project_restore(paste0(
            "Wide→Long対象列UIのbrowser bindingを確認できませんでした",
            if (length(missing)) paste0(": ", paste(missing, collapse = ", ")) else "。"
          ))
          return()
        }

        if (!isTRUE(pending_bind$values_sent)) {
          diag(
            "RESHAPE-BIND",
            paste0(
              "ack generation=", pending_bind$generation,
              " field=reshape_columns"
            )
          )
          restore_timing_mark("RESHAPE-BIND-ACK", pending_bind$generation, from = "RESHAPE-BIND-REQUEST")
          browser_preseed_ok <- restore_ack_set_matches(ack, "reshape_columns", wanted)
          if (isTRUE(controls_only)) diag("FIGURE-EDIT-FAST", paste0("stage=child status=", if (isTRUE(browser_preseed_ok)) "match" else "mismatch"))
          if (!isTRUE(browser_preseed_ok)) {
            freezeReactiveValue(input, "reshape_columns")
            updateCheckboxGroupInput(
              session, "reshape_columns",
              choices = names(d0),
              selected = wanted
            )
          } else {
            diag("RESTORE-FAST", paste0("RESHAPE-BIND generation=", pending_bind$generation, " browser preseed already matches; update message skipped"))
          }
          pending_bind$values_sent <- TRUE
          project_restore_wait_phase("reshape-child-value")
          project_restore_wait_count(0L)
          reshape_binding_pending(pending_bind)
          diag(
            "RESHAPE-BIND",
            paste0(
              if (isTRUE(browser_preseed_ok)) "preseed accepted" else "restore values sent",
              " generation=", pending_bind$generation,
              " selected={", paste(wanted, collapse = ","), "}"
            )
          )
          restore_timing_mark("RESHAPE-BIND-SENT", pending_bind$generation)
          # Fall through to the server-value check in the same reactive pass.
          # With a matching browser preseed there may be no subsequent Shiny
          # input event, so returning here can leave restore stuck forever.
          # When an update is actually needed, the reads below register the
          # input dependency and the client update naturally re-runs this stage.
        }

        actual_cols <- tryCatch(input$reshape_columns, error = function(e) NULL)
        actual_cols <- if (is.null(actual_cols)) character(0) else as.character(actual_cols)
        expected_cols <- as.character(pending_bind$wanted)
        value_ok <- length(actual_cols) == length(expected_cols) &&
          setequal(actual_cols, expected_cols)

        if (!isTRUE(value_ok)) {
          if (restore_diag_checkpoint()) {
            diag(
              "RESHAPE-BIND",
              paste0(
                "waiting server value generation=", pending_bind$generation,
                " expected={", paste(expected_cols, collapse = ","), "}",
                " actual={", if (length(actual_cols)) paste(actual_cols, collapse = ",") else "<NULL>", "}"
              )
            )
          }
          restore_wait("保存済みWide→Long対象列をUIへ反映できませんでした。", phase = "reshape-child-value")
          return()
        }

        diag(
          "RESHAPE-BIND",
          paste0(
            "server value observed generation=", pending_bind$generation,
            " selected={", paste(actual_cols, collapse = ","), "}"
          )
        )
        restore_timing_mark("RESHAPE-BIND-OBSERVED", pending_bind$generation, from = "RESHAPE-BIND-SENT")
        reset_reshape_binding_wait(clear_seed = FALSE)
      }
    }

    project_restore_wait_count(0L)
    diag("HYDRATE-UI", paste0("stage1 raw data ready; ui_preseeded=", isTRUE(ui_preseeded)))
    project_restore_stage(2)
  })

  # 第3段階: 変換後データにMapping列が揃ってからMappingを戻す
  observe({
    cfg <- pending_project()
    if (is.null(cfg) || project_restore_stage() != 2) return()

    target_plot_type <- graph_plot_type_normalize(
      json_chr(cfg$plot$type, input$plot_type %||% "line")
    )

    if (!identical(input$plot_type %||% "", target_plot_type)) {
      freezeReactiveValue(input, "plot_type")
      updateSelectInput(session, "plot_type", selected = target_plot_type)
      return()
    }

    d <- tryCatch(
      dat(),
      error = function(e) {
        if (restore_diag_checkpoint()) restore_diag_condition("stage2 dat error", e, cfg)
        NULL
      }
    )
    if (is.null(d)) {
      restore_wait("Wide→Long変換後のデータを準備できませんでした。", phase = "stage2-prepared-data")
      return()
    }

    if (!isTRUE(isolate(restore_diag_stage2_available_logged())) &&
        isTRUE((cfg$reshape %||% list())$enabled)) {
      restore_diag_snapshot("stage2 dat available", cfg, d)
      restore_diag_stage2_available_logged(TRUE)
    }

    mp <- cfg$mapping
    if (!is.null(mp)) {
      wanted <- c(
        json_chr(mp$x),
        json_chr(mp$y),
        if (graph_plot_supports_mapping(target_plot_type, "position")) {
          json_chr(mp$position, json_chr(mp$series))
        } else "",
        json_chr(mp$color),
        if (graph_plot_supports_mapping(target_plot_type, "linetype")) json_chr(mp$linetype) else "",
        json_chr(mp$shape),
        json_chr(mp$id),
        json_chr(mp$facet)
      )
      wanted <- unique(wanted[
        nzchar(wanted) & !wanted %in% c("__color__", "__fixed__")
      ])
      if (!all(wanted %in% names(d))) {
        missing_cols <- setdiff(wanted, names(d))
        restore_wait(paste0(
          "保存済みMapping列が現在のデータにありません: ",
          paste(missing_cols, collapse = ", ")
        ), phase = "stage2-mapping-columns")
        return()
      }

      restore_inputs <- graph_plot_restore_input_ids(target_plot_type)

      # The parent Mapping renderUI requires at least one numeric column.
      # Stage2 used to ignore that render condition and could advance while
      # every Mapping input was still absent.  Fail with a precise diagnosis
      # instead of timing out later as a generic Mapping mismatch.
      numeric_cols <- names(d)[vapply(d, is.numeric, logical(1))]
      if (!length(numeric_cols)) {
        abort_project_restore("Mapping UIを生成できませんでした: 数値列が1列以上必要です。")
        return()
      }

      pending_bind <- isolate(mapping_binding_pending())
      ack <- input$mapping_restore_binding_ack

      if (is.null(pending_bind)) {
        request_mapping_binding_ack(restore_inputs, target_plot_type)
        return()
      }

      ack_generation <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
      if (is.null(ack) || !identical(ack_generation, as.integer(pending_bind$generation))) {
        # Wait for the browser to acknowledge this exact Mapping UI generation.
        # The client is event-driven (Shiny binding/input events + one animation
        # frame); stale acks are ignored by generation.
        return()
      }

      ack_status <- as.character(ack$status %||% "")[1]
      if (!identical(ack_status, "ready")) {
        missing <- as.character(unlist(ack$missing %||% character(0), use.names = FALSE))
        diag(
          "MAPPING-BIND",
          paste0(
            "timeout generation=", pending_bind$generation,
            " missing=", if (length(missing)) paste(missing, collapse = ",") else "<unknown>",
            " ", restore_binding_ack_diag(ack)
          )
        )
        abort_project_restore(paste0(
          "Mapping UIのbrowser bindingを確認できませんでした",
          if (length(missing)) paste0(": ", paste(missing, collapse = ", ")) else "。"
        ))
        return()
      }

      diag(
        "MAPPING-BIND",
        paste0(
          "ack generation=", pending_bind$generation,
          " fields=", paste(pending_bind$fields, collapse = ",")
        )
      )

      restore_timing_mark("MAPPING-BIND-ACK", pending_bind$generation, from = "MAPPING-BIND-REQUEST")

      restored_color <- json_chr(mp$color)
      if (!nzchar(restored_color) && is.null(mp$position) && nzchar(json_chr(mp$series))) {
        restored_color <- json_chr(mp$series)
      }
      if (identical(restored_color, "__fixed__")) restored_color <- ""
      expected_map <- list(
        xvar = json_chr(mp$x),
        yvar = json_chr(mp$y),
        colorvar = restored_color,
        shapevar = json_chr(mp$shape, "__color__"),
        idvar = json_chr(mp$id),
        facetvar = json_chr(mp$facet)
      )
      if (target_plot_type %in% c("line", "bar", "box")) expected_map$groupvar <- json_chr(mp$position, json_chr(mp$series))
      if (target_plot_type %in% c("line", "scatter")) expected_map$linetypevar <- json_chr(mp$linetype, "__color__")
      browser_preseed_ok <- all(vapply(names(expected_map), function(nm) {
        restore_ack_scalar_matches(ack, nm, expected_map[[nm]])
      }, logical(1)))
      if (isTRUE(controls_only)) diag("FIGURE-EDIT-FAST", paste0("stage=mapping status=", if (isTRUE(browser_preseed_ok)) "match" else "mismatch"))

      if (!isTRUE(browser_preseed_ok)) {
        for (nm in restore_inputs) freezeReactiveValue(input, nm)
        updateSelectInput(session, "xvar", selected = expected_map$xvar)
        updateSelectInput(session, "yvar", selected = expected_map$yvar)
        if (!is.null(expected_map$groupvar)) updateSelectInput(session, "groupvar", selected = expected_map$groupvar)
        updateSelectInput(session, "colorvar", selected = expected_map$colorvar)
        if (!is.null(expected_map$linetypevar)) updateSelectInput(session, "linetypevar", selected = expected_map$linetypevar)
        updateSelectInput(session, "shapevar", selected = expected_map$shapevar)
        updateSelectInput(session, "idvar", selected = expected_map$idvar)
        updateSelectInput(session, "facetvar", selected = expected_map$facetvar)
      } else {
        diag("RESTORE-FAST", paste0("MAPPING-BIND generation=", pending_bind$generation, " browser preseed already matches; update messages skipped"))
      }

      diag(
        "MAPPING-BIND",
        paste0(if (isTRUE(browser_preseed_ok)) "preseed accepted generation=" else "restore values sent generation=", pending_bind$generation)
      )
      restore_timing_mark("MAPPING-BIND-SENT", pending_bind$generation)
      reset_mapping_binding_wait()
    }

    project_restore_wait_count(0L)
    diag("HYDRATE-UI", "stage2 mapping UI bound; restore values sent")

    # Full structural hydrate must cross one real browser flush before stage 3
    # verifies Mapping values. updateSelectInput() messages are asynchronous;
    # advancing in this same reactive turn can strand a newly created Graph in
    # HYDRATING with the mask still up.  Coalesce repeated stage-2 wakes into
    # one event-driven barrier; no timer/polling is involved.
    if (!isTRUE(isolate(mapping_stage3_flush_pending()))) {
      mapping_stage3_flush_pending(TRUE)
      activation_gen <- as.integer(isolate(restore_activation_generation()) %||% 0L)
      diag("MAPPING-BIND", paste0("stage3 browser-flush barrier queued generation=", activation_gen))
      session$onFlushed(function() {
        still_current <- isTRUE(isolate(initial_restore_started())) &&
          isTRUE(isolate(mapping_stage3_flush_pending())) &&
          identical(as.integer(isolate(restore_activation_generation()) %||% 0L), activation_gen) &&
          identical(as.integer(isolate(project_restore_stage()) %||% 0L), 2L) &&
          !is.null(isolate(pending_project()))
        if (!isTRUE(still_current)) {
          mapping_stage3_flush_pending(FALSE)
          diag("MAPPING-BIND", paste0("stage3 browser-flush barrier stale generation=", activation_gen))
          return(invisible(NULL))
        }
        mapping_stage3_flush_pending(FALSE)
        project_restore_stage(3)
        diag("MAPPING-BIND", paste0("stage3 start after browser flush generation=", activation_gen))
        invisible(NULL)
      }, once = TRUE)
    }
  })

  # 第4段階: Mappingが実際に反映されたことを確認して残りを復元
  observe({
    cfg <- pending_project()
    if (is.null(cfg)) cfg <- direct_sync_project()
    if (is.null(cfg) || project_restore_stage() != 3) return()

    mapping_status <- mapping_project_status(cfg)
    if (!isTRUE(mapping_status$ok)) {
      wait_n <- isolate(project_restore_wait_count())
      is_direct_sync <- !is.null(isolate(direct_sync_project()))

      # Persistent-shell sync has no binding/remount step. updateSelectInput()
      # reaches the browser asynchronously, so the first server-side check can
      # still see the previous values. Just wait for the fixed inputs to report
      # their new values; do not invoke legacy RESTORE-RESYNC.
      if (isTRUE(is_direct_sync)) {
        if (wait_n == 0L || wait_n %% 20L == 0L) {
          bits <- vapply(mapping_status$mismatch, function(nm) {
            paste0(
              nm,
              " expected=", if (identical(mapping_status$expected[[nm]], "")) "<EMPTY>" else mapping_status$expected[[nm]],
              " actual=", mapping_status$raw[[nm]]
            )
          }, character(1))
          diag("EDITOR-SYNC", paste0("waiting fixed Mapping inputs: ", paste(bits, collapse = "; ")))
        }
        restore_wait("Editor syncのMapping反映を待機しています。", phase = "editor-sync-mapping-value")
        return()
      }

      resync_n <- isolate(mapping_restore_resync_count())
      should_resync <- resync_n < mapping_restore_resync_limit &&
        (wait_n == 0L || wait_n %% mapping_restore_resync_interval == 0L)

      if (isTRUE(should_resync)) {
        next_resync <- resync_n + 1L
        mapping_restore_resync_count(next_resync)
        bits <- vapply(mapping_status$mismatch, function(nm) {
          paste0(
            nm,
            " expected=", if (identical(mapping_status$expected[[nm]], "")) "<EMPTY>" else mapping_status$expected[[nm]],
            " actual=", mapping_status$raw[[nm]]
          )
        }, character(1))
        diag(
          "RESTORE-RESYNC",
          paste0(
            "attempt=", next_resync, "/", mapping_restore_resync_limit,
            " fields=", paste(mapping_status$mismatch, collapse = ","),
            " state={", paste(bits, collapse = "; "), "}"
          )
        )
        resync_mapping_fields(cfg, mapping_status$mismatch)
      }

      restore_wait("保存済みMappingをUIへ反映できませんでした。", phase = "mapping-value")
      return()
    }
    project_restore_wait_count(0L)
    mapping_restore_resync_count(0L)
    reset_mapping_binding_wait()
    diag("HYDRATE-UI", "stage3 mapping committed; restoring remaining controls/style")

    if (!is.na(restore_timing_last_mapping_generation)) {
      restore_timing_mark("MAPPING-BIND-OBSERVED", restore_timing_last_mapping_generation, from = "MAPPING-BIND-SENT")
    }
    restore_timing_mark("MAPPING-COMMITTED")

    # seedはここでは消さない。
    # dynamic UIの実inputが保存値へ追いついたことを別observerで確認してから解除する。

    pl <- cfg$plot
    if (!is.null(pl)) {
      if (direct_sync_path_changed("plot.summary") && !is.null(pl$summary)) {
        updateSelectInput(session, "summary_type", selected = json_chr(pl$summary))
      }
      if (direct_sync_path_changed("plot.summary_unit")) {
        updateRadioButtons(session, "summary_unit", selected = json_chr(pl$summary_unit, "row"))
      }
      if (direct_sync_path_changed("plot.external_error_mode")) {
        updateRadioButtons(session, "external_error_mode", selected = json_chr(pl$external_error_mode, "none"))
      }

      mp_error <- cfg$mapping
      error_mapping_changed <- direct_sync_any_changed(c(
        "mapping.external_error", "mapping.external_ymin", "mapping.external_ymax"
      ))
      if (isTRUE(error_mapping_changed) && !is.null(mp_error)) {
        d_error <- tryCatch(dat(), error = function(e) NULL)
        error_choices <- if (is.null(d_error)) character(0) else {
          names(d_error)[vapply(d_error, is.numeric, logical(1))]
        }
        if (direct_sync_path_changed("mapping.external_error") && !is.null(mp_error$external_error)) {
          saved_error <- json_chr(mp_error$external_error)
          if (nzchar(saved_error) && saved_error %in% error_choices) {
            updateSelectInput(session, "external_error_col", choices = error_choices, selected = saved_error)
          }
        }
        if (direct_sync_path_changed("mapping.external_ymin") && !is.null(mp_error$external_ymin)) {
          saved_ymin <- json_chr(mp_error$external_ymin)
          if (nzchar(saved_ymin) && saved_ymin %in% error_choices) {
            updateSelectInput(session, "external_ymin_col", choices = error_choices, selected = saved_ymin)
          }
        }
        if (direct_sync_path_changed("mapping.external_ymax") && !is.null(mp_error$external_ymax)) {
          saved_ymax <- json_chr(mp_error$external_ymax)
          if (nzchar(saved_ymax) && saved_ymax %in% error_choices) {
            updateSelectInput(session, "external_ymax_col", choices = error_choices, selected = saved_ymax)
          }
        }
      }
      if (direct_sync_path_changed("plot.show_raw") && !is.null(pl$show_raw)) {
        updateCheckboxInput(session, "show_raw", value = isTRUE(pl$show_raw))
      }
      if (direct_sync_path_changed("plot.connect_id") && !is.null(pl$connect_id)) {
        updateCheckboxInput(session, "connect_id", value = isTRUE(pl$connect_id))
      }
      if (direct_sync_path_changed("plot.scatter_connect_mode")) {
        updateRadioButtons(
          session, "scatter_connect_mode",
          selected = json_chr(pl$scatter_connect_mode, if (isTRUE(pl$connect_id)) "id" else "none")
        )
      }
    }

    lb <- cfg$labels
    if (!is.null(lb)) {
      if (direct_sync_path_changed("labels.xlab") && !is.null(lb$xlab)) updateTextAreaInput(session, "xlab", value = json_chr(lb$xlab))
      if (direct_sync_path_changed("labels.ylab") && !is.null(lb$ylab)) updateTextAreaInput(session, "ylab", value = json_chr(lb$ylab))
      if (direct_sync_path_changed("labels.title") && !is.null(lb$title)) updateTextInput(session, "title", value = json_chr(lb$title))
      if (direct_sync_path_changed("labels.ymin") && !is.null(lb$ymin)) updateTextInput(session, "ymin", value = json_chr(lb$ymin))
      if (direct_sync_path_changed("labels.ymax") && !is.null(lb$ymax)) updateTextInput(session, "ymax", value = json_chr(lb$ymax))
      if (direct_sync_path_changed("labels.y_top_to_tick") && !is.null(lb$y_top_to_tick)) {
        updateCheckboxInput(session, "y_top_to_tick", value = isTRUE(lb$y_top_to_tick))
      }
    }

    # Legacy Project export width/height/dpi are intentionally ignored.
    # v3.3.31+ export geometry follows the restored Plot pixel dimensions.

    st <- cfg$style
    if (!is.null(st)) {
      if (direct_sync_path_changed("style.color_styles") && !is.null(st$color_styles)) color_styles(parse_style_tree(st$color_styles, "color"))
      if (direct_sync_path_changed("style.linetype_styles") && !is.null(st$linetype_styles)) linetype_styles(parse_style_tree(st$linetype_styles, "linetype"))
      if (direct_sync_path_changed("style.shape_styles") && !is.null(st$shape_styles)) shape_styles(parse_style_tree(st$shape_styles, "shape"))
      if (direct_sync_path_changed("style.group_styles") && is.null(st$color_styles) && !is.null(st$group_styles) && length(st$group_styles)) {
        mv <- legacy_mapping_vars(cfg$mapping)
        migrate_legacy_group_styles(st$group_styles, mv$color, mv$linetype, mv$shape)
      }

      if (direct_sync_path_changed("style.series_styles") && !is.null(st$series_styles)) {
        ss <- list()
        for (nm in names(st$series_styles)) {
          z <- st$series_styles[[nm]]
          ss[[nm]] <- list(color = json_chr(z$color, "#333333"))
        }
        series_styles(ss)
      }

      if (direct_sync_path_changed("style.regression_styles") && !is.null(st$regression_styles)) {
        rs <- list()
        for (nm in names(st$regression_styles)) {
          z <- st$regression_styles[[nm]]
          rs[[nm]] <- list(
            color = json_chr(z$color, "#333333"),
            linetype = json_chr(z$linetype, "solid"),
            width = as.numeric(json_chr(z$width, "0.9"))
          )
        }
        regression_styles(rs)
      }

      if (direct_sync_path_changed("style.raw_group_colors") && !is.null(st$raw_group_colors)) {
        if (!length(st$raw_group_colors)) {
          raw_group_colors(list())
        } else {
          first_val <- st$raw_group_colors[[1]]
          if (is.list(first_val) && !is.null(names(first_val))) {
            raw_group_colors(parse_style_tree(st$raw_group_colors, "color"))
          } else {
            mv <- legacy_mapping_vars(cfg$mapping); rc <- list(); br <- list()
            for (nm in names(st$raw_group_colors)) br[[nm]] <- json_chr(st$raw_group_colors[[nm]], "#777777")
            if (nzchar(mv$color)) rc[[mv$color]] <- br
            raw_group_colors(rc)
          }
        }
      }

      if (direct_sync_path_changed("style.orders") && !is.null(st$orders)) {
        order_state(normalize_order_tree(st$orders))
      }

      if (direct_sync_path_changed("style.legend_titles") && !is.null(st$legend_titles)) {
        lt <- list()
        for (nm in names(st$legend_titles)) {
          lt[[nm]] <- json_chr(st$legend_titles[[nm]], "")
        }
        legend_titles(lt)
      }

      if (direct_sync_path_changed("style.level_labels") && !is.null(st$level_labels)) {
        ll <- list()
        for (vn in names(st$level_labels)) {
          branch <- st$level_labels[[vn]]
          bb <- list()
          for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
          ll[[vn]] <- bb
        }
        level_labels(ll)
      }
      if (direct_sync_path_changed("style.shared_library")) {
        shared_style_binding(shared_style_normalize_binding(st$shared_library %||% NULL))
      }

      a <- st$appearance
      if (direct_sync_path_changed("style.appearance")) {
        if (direct_sync_any_changed(c(
          "style.appearance.font_family_mode",
          "style.appearance.font_family_custom",
          "style.appearance.font_family_effective"
        ))) {
          apply_font_family_state_to_editor(a)
        }
        if (!is.null(a)) {
        if (direct_sync_path_changed("style.appearance.series_style_override") && !is.null(a$series_style_override)) {
          updateCheckboxInput(
            session, "series_style_override",
            value = isTRUE(a$series_style_override)
          )
        }
        if (direct_sync_path_changed("style.appearance.scatter_regression") && !is.null(a$scatter_regression)) {
          updateCheckboxInput(session, "scatter_regression", value = isTRUE(a$scatter_regression))
        }
        if (direct_sync_path_changed("style.appearance.scatter_regression_se") && !is.null(a$scatter_regression_se)) {
          updateCheckboxInput(session, "scatter_regression_se", value = isTRUE(a$scatter_regression_se))
        }
        if (direct_sync_path_changed("style.appearance.scatter_regression_color") && !is.null(a$scatter_regression_color)) {
          colourpicker::updateColourInput(
            session, "scatter_regression_color",
            value = json_chr(a$scatter_regression_color)
          )
        }

        simple_select <- c(
          theme = "theme",
          palette_preset = "palette_preset",
          raw_palette_preset = "raw_palette_preset",
          scatter_regression_group = "scatter_regression_group",
          scatter_regression_linetype = "scatter_regression_linetype",
          summary_type = "summary_type",
          mean_linetype = "mean_linetype",
          mean_shape = "mean_shape",
          raw_shape_mode = "raw_shape_mode",
          raw_shape = "raw_shape",
          id_linetype = "id_linetype",
          error_color_mode = "error_color_mode",
          legend_pos = "legend_pos"
        )
        for (nm in names(simple_select)) {
          if (direct_sync_path_changed(paste0("style.appearance.", nm)) && !is.null(a[[nm]])) {
            selected_value <- json_chr(a[[nm]])
            if (identical(nm, "scatter_regression_group") &&
                !selected_value %in% c("overall", "style")) {
              selected_value <- "overall"
            }
            updateSelectInput(
              session, simple_select[[nm]],
              selected = selected_value
            )
          }
        }

        if (direct_sync_path_changed("style.appearance.mean_color_mode") && !is.null(a$mean_color_mode)) {
          colourpicker::updateColourInput(
            session, "mean_color_mode",
            value = normalise_colour(json_chr(a$mean_color_mode), "#000000")
          )
        }
        if (direct_sync_path_changed("style.appearance.bar_border_mode")) {
          updateRadioButtons(
            session, "bar_border_mode",
            selected = json_chr(a$bar_border_mode, "fixed")
          )
        }
        if (direct_sync_path_changed("style.appearance.bar_border_color") && !is.null(a$bar_border_color)) {
          colourpicker::updateColourInput(
            session, "bar_border_color",
            value = normalise_colour(json_chr(a$bar_border_color), "#000000")
          )
        }
        if (direct_sync_path_changed("style.appearance.raw_fixed_custom") && !is.null(a$raw_fixed_custom)) {
          colourpicker::updateColourInput(
            session, "raw_fixed_custom",
            value = normalise_colour(json_chr(a$raw_fixed_custom), "#555555")
          )
        }
        if (direct_sync_path_changed("style.appearance.raw_color_mode") && !is.null(a$raw_color_mode)) {
          raw_mode_saved <- json_chr(a$raw_color_mode, "group_light")
          if (raw_mode_saved %in% c("black", "gray30", "white", "red3", "blue3", "darkgreen")) {
            updateSelectInput(session, "raw_color_mode", selected = "custom_fixed")
            colourpicker::updateColourInput(
              session, "raw_fixed_custom",
              value = normalise_colour(raw_mode_saved, "#555555")
            )
          } else {
            updateSelectInput(session, "raw_color_mode", selected = raw_mode_saved)
          }
        }
        if (direct_sync_path_changed("style.appearance.id_line_color_mode") && !is.null(a$id_line_color_mode)) {
          id_mode_saved <- json_chr(a$id_line_color_mode, "group_light")
          if (id_mode_saved %in% c("black", "gray30", "gray50", "white", "red3", "blue3", "darkgreen")) {
            updateSelectInput(session, "id_line_color_mode", selected = "custom_fixed")
            colourpicker::updateColourInput(
              session, "id_line_custom_color",
              value = normalise_colour(id_mode_saved, "#4D4D4D")
            )
          } else {
            updateSelectInput(session, "id_line_color_mode", selected = id_mode_saved)
          }
        }
        if (direct_sync_path_changed("style.appearance.id_line_custom_color") && !is.null(a$id_line_custom_color)) {
          colourpicker::updateColourInput(
            session, "id_line_custom_color",
            value = normalise_colour(json_chr(a$id_line_custom_color), "#4D4D4D")
          )
        }
        if (direct_sync_path_changed("style.appearance.error_color") && !is.null(a$error_color)) {
          colourpicker::updateColourInput(
            session, "error_color",
            value = json_chr(a$error_color)
          )
        }

        sliders <- c(
          base_size = "base_size",
          scatter_regression_width = "scatter_regression_width",
          scatter_regression_se_alpha = "scatter_regression_se_alpha",
          point_size = "point_size",
          line_width = "line_width",
          line_group_dodge = "line_group_dodge",
          line_x_spacing = "line_x_spacing",
          bar_width = "bar_width",
          group_spacing = "group_spacing",
          box_width_scale = "box_width_scale",
          x_category_spacing = "x_category_spacing",
          bar_border_width = "bar_border_width",
          raw_lighten = "raw_lighten",
          raw_alpha = "raw_alpha",
          raw_point_size = "raw_point_size",
          jitter_width = "jitter_width",
          id_line_lighten = "id_line_lighten",
          id_line_width = "id_line_width",
          id_line_alpha = "id_line_alpha",
          legend_key_width = "legend_key_width",
          facet_spacing_x = "facet_spacing_x",
          error_width = "error_width",
          error_line_width = "error_line_width"
        )
        for (nm in names(sliders)) {
          if (direct_sync_path_changed(paste0("style.appearance.", nm)) && !is.null(a[[nm]])) {
            updateSliderInput(
              session, sliders[[nm]],
              value = as.numeric(a[[nm]])
            )
          }
        }

        # Plot width/height are restored in Stage 0 before panel reveal.
        # Do not touch them again here; late geometry changes caused oversized
        # Project layouts to collide with the Graph style panel.

        if (direct_sync_path_changed("style.appearance.summary_on_top") && !is.null(a$summary_on_top)) {
          updateCheckboxInput(
            session, "summary_on_top",
            value = isTRUE(a$summary_on_top)
          )
        }
        if (direct_sync_path_changed("style.appearance.bar_zero_touch") && !is.null(a$bar_zero_touch)) {
          updateCheckboxInput(session, "bar_zero_touch", value = isTRUE(a$bar_zero_touch))
        }
        if (direct_sync_path_changed("style.appearance.sticky_plot") && !is.null(a$sticky_plot)) {
          updateCheckboxInput(session, "sticky_plot", value = isTRUE(a$sticky_plot))
        }
        if (direct_sync_path_changed("style.appearance.y_break_enabled") && !is.null(a$y_break_enabled)) {
          updateCheckboxInput(session, "y_break_enabled", value = isTRUE(a$y_break_enabled))
        }
        if (direct_sync_path_changed("style.appearance.y_breaks_auto") && !is.null(a$y_breaks_auto)) {
          updateCheckboxInput(session, "y_breaks_auto", value = isTRUE(a$y_breaks_auto))
        }
        if (direct_sync_path_changed("style.appearance.y_breaks_step") && !is.null(a$y_breaks_step)) {
          updateNumericInput(session, "y_breaks_step", value = as.numeric(a$y_breaks_step))
        }
        if (direct_sync_path_changed("style.appearance.y_break_from") && !is.null(a$y_break_from)) {
          updateNumericInput(session, "y_break_from", value = as.numeric(a$y_break_from))
        }
        if (direct_sync_path_changed("style.appearance.y_break_to") && !is.null(a$y_break_to)) {
          updateNumericInput(session, "y_break_to", value = as.numeric(a$y_break_to))
        }
        if (direct_sync_path_changed("style.appearance.y_break_space") && !is.null(a$y_break_space)) {
          updateSliderInput(session, "y_break_space", value = as.numeric(a$y_break_space))
        }
        if (direct_sync_path_changed("style.appearance.y_break_symbol") && !is.null(a$y_break_symbol)) {
          updateCheckboxInput(session, "y_break_symbol", value = isTRUE(a$y_break_symbol))
        }
        }
      }
    }

    # 保存済みstyleをreactiveValへ入れ終えた後、dynamic style UIを
    # 必要な時だけ保存値から作り直す。Mapping/style/plot構造が同じ
    # Graph再訪では、この再生成も省略する。observerはまだguard中。
    dynamic_style_changed <- direct_sync_any_changed(c(
      "style.color_styles", "style.linetype_styles", "style.shape_styles",
      "style.series_styles", "style.regression_styles", "style.raw_group_colors",
      "style.orders", "style.legend_titles", "style.level_labels", "style.shared_library",
      "mapping", "plot.type"
    ))
    if (isTRUE(dynamic_style_changed)) {
      style_restore_epoch(isolate(style_restore_epoch()) + 1L)
    } else {
      diag("EDITOR-SYNC-DELTA", "dynamic style UI rebuild skipped")
    }

    # Browser dynamic inputs are created asynchronously.  In particular,
    # colourInput values from the previous Graph may be reported one flush
    # after renderUI replacement.  Do not release the style guard on the same
    # flush as the rebuild. Re-assert the target canonical style and give that
    # UI one additional flush before normal observers are allowed to write.
    restore_stage3_done(TRUE)
    project_restore_stage(4)

    finish_restore <- function() {
      if (!isTRUE(isolate(initial_restore_started())) ||
          !identical(isolate(project_restore_stage()), 4)) {
        diag("RESTORE-CANCEL", "stale finalization ignored")
        return()
      }

      project_restore_stage(0)
      project_restore_wait_count(0L)
      mapping_stage3_flush_pending(FALSE)
      pending_project(NULL)
      direct_sync_project(NULL)
      direct_sync_diff_paths(NULL)
      restore_final_done(TRUE)
      initial_restore_done(TRUE)
      restore_retry_count(0L)
      deferred_initial_state(NULL)
      reset_reshape_binding_wait(clear_seed = TRUE)
      restoring_style_state(FALSE)

      # v3.51: the live layer is always mounted in the stable preview stage.
      # Restore completion merely permits renderPlot to run; the cached SVG
      # stays visible until the browser observes the live plot image load.
      diag("PREVIEW-MODE", "restore complete; cached layer retained until live plot image load")
      if (isTRUE(isolate(restore_notify()))) {
        showNotification("Graphの設定を読み込みました。", type = "message")
      }
      restore_notify(FALSE)
      diag("RESTORE", "final onFlushed END initial_restore_done=TRUE")
      restore_timing_mark("FINAL-END", from = "FINAL-BEGIN")
    }

    session$onFlushed(function() {
      # A user may preempt this Graph after stage3 queued the final flush.
      if (!isTRUE(isolate(initial_restore_started())) ||
          !identical(isolate(project_restore_stage()), 4)) {
        diag("RESTORE-CANCEL", "stale final onFlushed ignored")
        return()
      }
      diag("RESTORE", "final onFlushed BEGIN")
      restore_timing_mark("FINAL-BEGIN", from = "MAPPING-COMMITTED")

      if (isTRUE(dynamic_style_changed)) {
        reassert_dynamic_style_state(cfg)
        style_restore_epoch(isolate(style_restore_epoch()) + 1L)
        if (isTRUE(persistent_shell)) {
          # v3.72.24: persistent-Editor dynamic controls use generation-scoped
          # browser input ids. Old-Graph inputs therefore cannot feed values
          # into the new generation, and graph_single_editor_loading remains a
          # canonical-write guard until the outer Preview transaction completes.
          # One extra whole-server flush is no longer required here.
          diag("RESTORE-STYLE-GUARD", "canonical dynamic style reasserted; persistent generation scope allows immediate finalize")
          finish_restore()
        } else {
          diag("RESTORE-STYLE-GUARD", "canonical dynamic style reasserted; release deferred one flush")
          session$onFlushed(function() {
            if (!isTRUE(isolate(initial_restore_started())) ||
                !identical(isolate(project_restore_stage()), 4)) {
              diag("RESTORE-CANCEL", "stale style-guard release ignored")
              return()
            }
            diag("RESTORE-STYLE-GUARD", "release after canonical dynamic style flush")
            finish_restore()
          }, once = TRUE)
        }
      } else {
        finish_restore()
      }
    }, once = TRUE)
  })

  # Hidden Graphでもstate復元に必要な動的UIだけは動かす。
  # Plot本体はhidden時にShiny標準どおりsuspendする。
  # Project Managerはready()で先にGraphを表示し、表示後の正常サイズでPlotを描く。
  for (nm in c(
    "reshape_warning_ui", "order_ui",
    "color_style_ui", "linetype_style_ui", "shape_style_ui", "series_style_ui", "scatter_regression_style_ui", "raw_group_color_ui",
    "display_labels_ui", "shared_style_binding_ui"
  )) {
    try(outputOptions(output, nm, suspendWhenHidden = FALSE), silent = TRUE)
  }

  # v3.58.4.1: Figure-owned controls-only editors use a staged preseed gate.
  # The outer mount ACK can prove only the static parent controls. Dynamic
  # reshape_columns and Mapping controls are verified later by their own
  # generation-scoped browser ACKs after prepared data exists.
  accept_preseeded_controls_state <- function(browser_ack = NULL) {
    if (!isTRUE(controls_only) || !isTRUE(ui_preseeded)) {
      return(list(status = "mismatch", mismatched = "mode", unconfirmed = character(0)))
    }
    if (isTRUE(isolate(initial_restore_done()))) {
      return(list(status = "match", mismatched = character(0), unconfirmed = character(0)))
    }

    cfg <- isolate(deferred_initial_state())
    if (!is.list(cfg)) {
      return(list(status = "unconfirmed", mismatched = character(0), unconfirmed = "state"))
    }

    ack_state <- function(field) {
      states <- browser_ack$states %||% list()
      if (!length(states)) return(list(confirmed = FALSE, value = NULL))
      for (st in states) {
        if (identical(as.character(st$field %||% "")[1], field)) {
          readable <- if (is.null(st$valueReadable)) TRUE else isTRUE(st$valueReadable)
          confirmed <- isTRUE(st$exists) && isTRUE(st$bound) && readable
          return(list(confirmed = confirmed, value = st$value))
        }
      }
      list(confirmed = FALSE, value = NULL)
    }
    scalar_state <- function(field, expected, logical_value = FALSE) {
      st <- ack_state(field)
      if (!isTRUE(st$confirmed)) return("unconfirmed")
      actual <- st$value
      if (isTRUE(logical_value)) {
        g <- tolower(as.character(actual)[1] %||% "")
        actual_logical <- g %in% c("true", "1", "on", "yes")
        if (identical(actual_logical, isTRUE(expected))) "match" else "mismatch"
      } else {
        if (identical(as.character(actual)[1] %||% "", as.character(expected %||% "")[1])) "match" else "mismatch"
      }
    }

    r <- cfg$reshape %||% list()
    target_plot_type <- graph_plot_type_normalize(json_chr(cfg$plot$type, "bar"), fallback = "bar")

    checks <- c(
      plot_type = scalar_state("plot_type", target_plot_type),
      reshape_wide = scalar_state("reshape_wide", isTRUE(r$enabled), logical_value = TRUE)
    )
    if (isTRUE(r$enabled)) {
      checks <- c(
        checks,
        reshape_row_id = scalar_state("reshape_row_id", if (!is.null(r$row_id)) isTRUE(r$row_id) else TRUE, logical_value = TRUE),
        reshape_x_name = scalar_state("reshape_x_name", json_chr(r$x_name, "Time")),
        reshape_y_name = scalar_state("reshape_y_name", json_chr(r$y_name, "Value"))
      )
    }

    mismatched <- names(checks)[checks == "mismatch"]
    unconfirmed <- names(checks)[checks == "unconfirmed"]
    status <- if (length(mismatched)) "mismatch" else if (length(unconfirmed)) "unconfirmed" else "match"
    diag(
      "FIGURE-EDIT-FAST",
      paste0(
        "stage=parent status=", status,
        " mismatched={", paste(mismatched, collapse = ","), "}",
        " unconfirmed={", paste(unconfirmed, collapse = ","), "}"
      )
    )
    list(status = status, mismatched = mismatched, unconfirmed = unconfirmed)
  }

  prepare_restore_from_canonical <- function(state, source = "user") {
    if (!is.list(state)) return(invisible(FALSE))

    # Cancel any unfinished generation first. The caller owns whether the DOM
    # is subsequently evicted or re-acknowledged; this function only resets the
    # persistent module restore state to the latest canonical GraphState.
    try(cancel_initial_restore(reason = paste0("prepare-", source)), silent = TRUE)
    deferred_initial_state(state)
    seed_internal_state(state)
    pending_project(NULL)
    project_restore_stage(0)
    project_restore_wait_count(0L)
    project_restore_wait_phase("")
    mapping_stage3_flush_pending(FALSE)
    reset_mapping_binding_wait()
    reset_reshape_binding_wait(clear_seed = TRUE)
    mapping_restore_resync_count(0L)
    restore_stage3_done(FALSE)
    restore_final_done(FALSE)
    restore_error(NULL)
    restore_retry_count(0L)
    restoring_style_state(FALSE)
    restore_notify(FALSE)
    initial_restore_started(FALSE)
    initial_restore_done(FALSE)
    restore_parent_preseed_match(FALSE)
    restore_parent_preseed_consumed(FALSE)
    activation_gen <- as.integer(isolate(restore_activation_generation()) %||% 0L) + 1L
    restore_activation_generation(activation_gen)
    diag("RESTORE-RETRY", paste0("source=", source, " generation=", activation_gen, " canonical_reset=TRUE"))
    invisible(TRUE)
  }

  activate_initial_state <- function() {
    diag(
      "RESTORE",
      paste0("activate called done=", isTRUE(isolate(initial_restore_done())),
             " started=", isTRUE(isolate(initial_restore_started())))
    )
    if (isTRUE(isolate(initial_restore_done()))) return(invisible(TRUE))
    if (isTRUE(isolate(initial_restore_started()))) return(invisible(FALSE))

    cfg <- isolate(deferred_initial_state())
    if (is.null(cfg)) {
      initial_restore_started(TRUE)
      initial_restore_done(TRUE)
      return(invisible(TRUE))
    }

    # A previous failed restore leaves restore_error populated until the next
    # attempt actually starts.  The serial materialization worker checks restore_error
    # immediately after activate(), before this onFlushed callback can run.
    # Clear only that stale terminal error synchronously when accepting a retry
    # so the worker observes the new in-flight attempt rather than the previous
    # attempt's failure.  start_state_restore() still owns the full per-attempt
    # state reset once the browser flush boundary is reached.
    stale_restore_error <- isolate(restore_error())
    if (!is.null(stale_restore_error)) {
      retry_n <- isolate(restore_retry_count())
      if (retry_n >= restore_retry_limit) {
        diag(
          "RESTORE",
          paste0(
            "retry rejected; retry limit reached count=", retry_n,
            " limit=", restore_retry_limit,
            " error=", stale_restore_error
          )
        )
        return(invisible(FALSE))
      }
      restore_retry_count(retry_n + 1L)
      restore_error(NULL)
      diag(
        "RESTORE",
        paste0(
          "retry accepted count=", retry_n + 1L, "/", restore_retry_limit,
          "; cleared stale restore_error before materialization poll"
        )
      )
    }

    activation_gen <- as.integer(isolate(restore_activation_generation()) %||% 0L) + 1L
    restore_activation_generation(activation_gen)
    initial_restore_started(TRUE)
    diag("RESTORE", paste0("activate queued start_state_restore onFlushed generation=", activation_gen))
    session$onFlushed(function() {
      if (!identical(as.integer(isolate(restore_activation_generation()) %||% 0L), activation_gen) ||
          !isTRUE(isolate(initial_restore_started()))) {
        diag("RESTORE-CANCEL", paste0("stale activate onFlushed ignored generation=", activation_gen))
        return()
      }
      diag("RESTORE", paste0("activate onFlushed -> start_state_restore generation=", activation_gen))
      start_state_restore(cfg, notify = FALSE)
    }, once = TRUE)
    invisible(TRUE)
  }

  # ------------------------------------------------------------
  # READY DOM remount state hydration
  # ------------------------------------------------------------
  prepare_remount_state <- function(state) {
    if (!isTRUE(isolate(initial_restore_done())) || !is.list(state)) {
      return(invisible(FALSE))
    }

    remount_state_seed(state)
    remount_seed_browser_ready(FALSE)
    remount_seed_browser_generation(NA_integer_)

    # v3.57.2: canonical GraphState may have been replaced while this persistent
    # module had no browser DOM (notably Figure -> 元Graphへ反映). Mapping seeds
    # already came from the canonical state, but internal reactive style trees
    # (colour/shape/series/etc.) remained stale. Seed only those internal
    # non-browser style/order stores here; do not launch a restore or touch
    # absent browser inputs.
    seed_internal_state(state)
    st_dbg <- state$style %||% list()
    dbg_tree <- function(x) {
      if (is.null(x) || !length(x)) return("<none>")
      paste(vapply(names(x), function(nm) {
        br <- x[[nm]]
        vals <- if (is.list(br)) {
          paste(vapply(names(br), function(k) paste0(k, "=", json_chr(br[[k]], "")), character(1)), collapse = "|")
        } else json_chr(br, "")
        paste0(nm, ":[", vals, "]")
      }, character(1)), collapse = ";")
    }
    diag("FIGURE-APPLY-STYLE", paste0(
      "remount internal seed",
      " color_mapping=", json_chr((state$mapping %||% list())$color),
      " shape_mapping=", json_chr((state$mapping %||% list())$shape, "__color__"),
      " color={", dbg_tree(st_dbg$color_styles), "}",
      " shape={", dbg_tree(st_dbg$shape_styles), "}",
      " series={", dbg_tree(st_dbg$series_styles), "}"
    ))

    mp <- state$mapping %||% list()
    rs <- state$reshape %||% list()

    # Wide->Long selected columns are also rendered dynamically. Without a
    # remount seed they can briefly fall back to the heuristic numeric-column
    # defaults and change the downstream Mapping choices.
    reshape_restore_seed(rs$columns %||% character(0))

    # Seed all dynamic Mapping sub-UIs from the canonical registry snapshot.
    # These seeds are released by their existing input-ack observers once the
    # newly bound browser controls report the same values.
    restore_position_seed(mp$position %||% "")
    restore_linetype_seed(mp$linetype %||% "__color__")
    restore_external_error_seed(mp$external_error %||% "")
    restore_external_ymin_seed(mp$external_ymin %||% "")
    restore_external_ymax_seed(mp$external_ymax %||% "")

    # resolved_xvar()/resolved_yvar() are also used while the new dynamic
    # selectInputs are still binding, so protect them from falling back to the
    # heuristic default during that gap.
    d <- tryCatch(isolate(dat()), error = function(e) NULL)
    cols <- if (is.null(d)) character(0) else names(d)
    num <- if (is.null(d)) character(0) else cols[vapply(d, is.numeric, logical(1))]
    sx <- json_chr(mp$x)
    sy <- json_chr(mp$y)
    if (nzchar(sx) && sx %in% cols) last_valid_xvar(sx)
    if (nzchar(sy) && sy %in% num) last_valid_yvar(sy)

    diag("MAPPING-REMOUNT-SEED", paste0(
      "prepared x=", sx, " y=", sy,
      " color=", json_chr(mp$color),
      " position=", json_chr(mp$position),
      " linetype=", json_chr(mp$linetype, "__color__"),
      " shape=", json_chr(mp$shape, "__color__"),
      " id=", json_chr(mp$id), " facet=", json_chr(mp$facet)
    ))
    invisible(TRUE)
  }

  # Release the remount seed only after TWO gates have passed:
  #   1) the browser confirms the new live DOM generation is ready; and
  #   2) the rebound dynamic inputs equal the canonical seed.
  # This prevents an early correct-looking input value from releasing the gate
  # before Shiny has finished materializing/binding the remounted namespace.
  observe({
    seed <- remount_state_seed()
    if (is.null(seed) || !isTRUE(initial_restore_done())) return()
    if (!isTRUE(remount_seed_browser_ready())) return()
    browser_gen <- suppressWarnings(as.integer(isolate(remount_seed_browser_generation())))
    current_gen <- suppressWarnings(as.integer(isolate(remount_generation())))
    if (!is.finite(browser_gen) || !is.finite(current_gen) || !identical(browser_gen, current_gen)) return()
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()
    cols <- names(d)
    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    mp <- seed$mapping %||% list()
    pt <- json_chr(seed$plot$type, input$plot_type %||% "line")

    char1 <- function(x, default = "") {
      if (is.null(x) || !length(x)) return(default)
      z <- as.character(x)[1]
      if (is.na(z)) default else z
    }
    same <- function(actual, expected) identical(char1(actual), char1(expected))

    expected_color <- json_chr(mp$color)
    if (identical(expected_color, "__fixed__")) expected_color <- ""
    expected_shape <- json_chr(mp$shape, "__color__")
    expected_id <- json_chr(mp$id)
    expected_facet <- json_chr(mp$facet)

    expected_reshape <- as.character(unlist((seed$reshape %||% list())$columns %||% character(0), use.names = FALSE))
    actual_reshape <- as.character(input$reshape_columns %||% character(0))
    reshape_ok <- if (length(expected_reshape)) {
      identical(actual_reshape, expected_reshape)
    } else {
      TRUE
    }

    checks <- c(
      reshape = reshape_ok,
      x = json_chr(mp$x) %in% cols && same(input$xvar, json_chr(mp$x)),
      y = json_chr(mp$y) %in% numeric_cols && same(input$yvar, json_chr(mp$y)),
      color = expected_color %in% c("", cols) && same(input$colorvar, expected_color),
      shape = expected_shape %in% c("", "__color__", cols) && same(input$shapevar, expected_shape),
      id = expected_id %in% c("", cols) && same(input$idvar, expected_id),
      facet = expected_facet %in% c("", cols) && same(input$facetvar, expected_facet)
    )

    if (pt %in% c("bar", "box")) {
      expected_pos <- json_chr(mp$position)
      checks <- c(checks, position = expected_pos %in% c("", cols) && same(input$groupvar, expected_pos))
    }
    if (pt %in% c("line", "scatter")) {
      expected_lt <- json_chr(mp$linetype, "__color__")
      checks <- c(checks, linetype = expected_lt %in% c("", "__color__", cols) && same(input$linetypevar, expected_lt))
    }

    if (!length(checks) || !all(checks)) return()
    remount_state_seed(NULL)
    remount_seed_browser_ready(FALSE)
    remount_seed_browser_generation(NA_integer_)
    reshape_restore_seed(NULL)
    diag("MAPPING-REMOUNT-SEED", paste0(
      "released after browser ack fields=", paste(names(checks), collapse=",")
    ))
  }, priority = 50)

  # Cancel an in-flight browser remount when its DOM is evicted.  Keep a
  # canonical state seed while dormant: Shiny inputs disappear with removeUI(),
  # so allowing project_settings() to become authoritative here would reopen
  # the same default/NULL state-bounce window we just closed for remount.
  cancel_remount_ui <- function(state = NULL, reason = "evict") {
    pending <- suppressWarnings(as.integer(isolate(remount_pending_generation())))
    had_pending <- is.finite(pending)
    had_seed <- !is.null(isolate(remount_state_seed()))
    if (is.list(state)) {
      remount_state_seed(state)
      rs <- state$reshape %||% list()
      reshape_restore_seed(rs$columns %||% character(0))
      had_seed <- TRUE
    }

    # Advance the generation as an explicit cancellation boundary.  Any late
    # browser ack from the removed DOM can no longer match a future remount.
    next_gen <- as.integer(isolate(remount_generation()) %||% 0L) + 1L
    remount_generation(next_gen)
    remount_pending_generation(NA_integer_)
    remount_seed_browser_ready(FALSE)
    remount_seed_browser_generation(NA_integer_)
    browser_ui_active(FALSE)
    plot_drawn(FALSE)
    diag("UI-REMOUNT-CANCEL", paste0(
      "reason=", reason,
      " pending=", if (had_pending) pending else "none",
      " hold_seed=", had_seed,
      " next_generation=", next_gen
    ))
    invisible(had_pending || had_seed)
  }

  remount_binding_fields <- function(seed) {
    if (!is.list(seed)) return(list())
    mp <- seed$mapping %||% list()
    rs <- seed$reshape %||% list()
    pt <- json_chr(seed$plot$type, "line")
    if (identical(pt, "violin")) pt <- "box"
    field <- function(name, expected, mode = "scalar") {
      list(field = name, id = session$ns(name), expected = expected, mode = mode)
    }
    out <- list(
      field("plot_type", pt),
      field("reshape_wide", isTRUE(rs$enabled), "logical")
    )
    if (isTRUE(rs$enabled)) {
      out <- c(out, list(
        field("reshape_row_id", if (!is.null(rs$row_id)) isTRUE(rs$row_id) else TRUE, "logical"),
        field("reshape_x_name", json_chr(rs$x_name, "Time")),
        field("reshape_y_name", json_chr(rs$y_name, "Value"))
      ))
      cols <- json_vec(rs$columns)
      if (length(cols)) out <- c(out, list(field("reshape_columns", cols, "set")))
    }
    restored_color <- json_chr(mp$color)
    if (!nzchar(restored_color) && is.null(mp$position) && nzchar(json_chr(mp$series))) restored_color <- json_chr(mp$series)
    if (identical(restored_color, "__fixed__")) restored_color <- ""
    out <- c(out, list(
      field("xvar", json_chr(mp$x)),
      field("yvar", json_chr(mp$y)),
      field("colorvar", restored_color),
      field("shapevar", json_chr(mp$shape, "__color__")),
      field("idvar", json_chr(mp$id)),
      field("facetvar", json_chr(mp$facet))
    ))
    if (pt %in% c("line", "bar", "box")) out <- c(out, list(field("groupvar", json_chr(mp$position, json_chr(mp$series)))))
    if (pt %in% c("line", "scatter")) out <- c(out, list(field("linetypevar", json_chr(mp$linetype, "__color__"))))
    out
  }

  # ------------------------------------------------------------
  # Browser DOM remount lifecycle
  # ------------------------------------------------------------
  # graphServer is intentionally persistent while graphUI() is virtualized.
  # A READY module must therefore be told explicitly when a new DOM generation
  # has been inserted.  Do not rerun Project restore here: GraphState already
  # seeded the new controls.  We only re-materialize the live output surface.
  remount_ui <- function() {
    if (!isTRUE(isolate(initial_restore_done()))) {
      diag("UI-REMOUNT", "ignored because initial restore is not complete")
      return(invisible(FALSE))
    }

    gen <- as.integer(isolate(remount_generation()) %||% 0L) + 1L
    remount_generation(gen)
    remount_pending_generation(gen)
    browser_ui_active(TRUE)
    plot_drawn(FALSE)
    diag("UI-REMOUNT", paste0("scheduled generation=", gen))

    # insertUI() is delivered on flush.  Ask the browser only to confirm that
    # the stable preview stage's live output subtree is bound; do not switch
    # away from cached mode until the remounted plot image actually loads.
    session$onFlushed(function() {
      pending <- suppressWarnings(as.integer(isolate(remount_pending_generation())))
      if (!is.finite(pending) || !identical(pending, gen)) return()
      diag("UI-REMOUNT", paste0("prepare request generation=", gen))
      seed_now <- isolate(remount_state_seed())
      session$sendCustomMessage(
        "graph-ui-remount-prepare",
        list(
          generation = gen,
          graphId = id,
          panelId = paste0("panel_", id),
          stageId = "graph_global_preview_stage",
          liveId = "graph_global_preview_live_layer",
          cachedId = "graph_global_preview_cached_layer",
          plotOutputId = session$ns("plot"),
          fields = remount_binding_fields(seed_now),
          ackId = session$ns("ui_remount_ack"),
          timeoutMs = 8000
        )
      )
    }, once = TRUE)
    invisible(TRUE)
  }

  observeEvent(input$ui_remount_ack, {
    ack <- input$ui_remount_ack
    if (!is.list(ack)) return()
    gen <- suppressWarnings(as.integer(ack$generation %||% NA_integer_))
    pending <- suppressWarnings(as.integer(isolate(remount_pending_generation())))
    if (!is.finite(gen) || !is.finite(pending) || !identical(gen, pending)) {
      diag("UI-REMOUNT", paste0("stale ack ignored generation=", gen, " pending=", pending))
      return()
    }

    live_ok <- isTRUE(ack$liveExists)
    plot_ok <- isTRUE(ack$plotExists)
    binding_ok <- isTRUE(ack$boundInputsReady)
    dom_gen <- suppressWarnings(as.integer(ack$domGeneration %||% NA_integer_))
    status <- as.character(ack$status %||% "")[1]
    diag(
      "UI-REMOUNT",
      paste0(
        "ack generation=", gen,
        " status=", status,
        " elapsed_ms=", ack$elapsedMs %||% "NA",
        " live_exists=", live_ok,
        " plot_exists=", plot_ok,
        " bindings_ready=", binding_ok,
        " dom_generation=", if (is.finite(dom_gen)) dom_gen else "NA",
        " cached_exists=", isTRUE(ack$cachedExists)
      )
    )
    if (!identical(status, "ready") || !live_ok || !plot_ok || !binding_ok ||
        !is.finite(dom_gen) || !identical(dom_gen, gen)) return()

    remount_pending_generation(NA_integer_)
    # This is the browser-side half of the READY remount hydration gate.  The
    # seed-release observer still requires all dynamic Mapping inputs to equal
    # the canonical snapshot before normal live registry commits resume.
    remount_seed_browser_ready(TRUE)
    remount_seed_browser_generation(gen)
    diag("REMOUNT-BIND-ACK", paste0("generation=", gen, " current_dom_inputs_confirmed=TRUE"))

    # v3.57.2: the live Preview DOM was just recreated. Replay the exact
    # measured plot dimensions now, rather than relying on the earlier
    # reactive message that targeted the previous/absent DOM generation.
    dims_now <- tryCatch(isolate(plot_total_dimensions()), error = function(e) NULL)
    if (is.list(dims_now)) send_plot_dimensions(dims_now, reason = "remount-ack")

    # Browser binding is ready.  Invalidate the live plot for this DOM
    # generation; the stage remains cached until the plot image load event.
    remount_render_epoch(gen)
  }, ignoreInit = TRUE)

