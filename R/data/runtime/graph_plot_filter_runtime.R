  plot_filter_value_controls <- function(r, possible, opt, selected_values = r$values) {
    tags$div(
      class = "plot-filter-value-section",
      tags$div(class = "plot-filter-value-heading",
        tags$b("値を選択"),
        if (r$kind %in% c("numeric", "time")) tags$small(class = "text-muted", "（範囲・比較と併用できます）")),
      tags$div(
        class = "plot-filter-actions",
        tags$button(type = "button", `data-filter-action` = "all", "すべて選択"),
        tags$button(type = "button", `data-filter-action` = "none", "すべて解除")
      ),
      if (length(possible) <= GRAPH_PLOT_FILTER_CHECKBOX_LIMIT)
        tags$div(class = "plot-filter-values", lapply(possible, function(v)
          tags$label(tags$input(type = "checkbox", `data-filter-field` = "values",
            value = v, checked = if (v %in% selected_values) "checked" else NULL), v)))
      else tags$div(
        tags$input(type = "search", class = "plot-filter-search", placeholder = "値を検索"),
        tags$select(multiple = "multiple", size = 7L, `data-filter-field` = "values",
          lapply(possible, function(v) opt(v, v, v %in% selected_values)))
      )
    )
  }

  plot_filter_compare_summary <- function(r) {
    a <- trimws(as.character(r$a %||% "")[1])
    b <- trimws(as.character(r$b %||% "")[1])
    if (!nzchar(a)) return("")
    op_label <- switch(r$op,
      gt = ">", gte = "≥", lt = "<", lte = "≤",
      inside = "範囲内", outside = "範囲外", r$op)
    if (r$op %in% c("inside", "outside")) {
      if (!nzchar(b)) paste(op_label, a, "～") else paste(op_label, a, "～", b)
    } else paste(op_label, a)
  }

  plot_filter_value_summary <- function(r, possible, selected_values = r$values) {
    selected <- sum(possible %in% selected_values)
    total <- length(possible)
    if (!total) "値なし" else if (selected == total) paste0("全", total, "値") else paste0(selected, " / ", total, " 値")
  }

  plot_filter_rule_summary <- function(r, possible) {
    suffix <- if (isTRUE(r$include_na)) " + 欠損値" else ""
    if (identical(r$mode, "values") || identical(r$kind, "categorical")) {
      return(paste0(plot_filter_value_summary(r, possible), suffix))
    }

    compare_label <- plot_filter_compare_summary(r)
    if (identical(r$mode, "combined") && r$kind %in% c("numeric", "time")) {
      value_label <- plot_filter_value_summary(r, possible)
      total <- length(possible)
      selected <- sum(possible %in% r$values)
      # All values is a no-op value constraint, so emphasize the comparison.
      # A subset (including zero selected) is shown alongside the range.
      parts <- character(0)
      if (nzchar(compare_label)) parts <- c(parts, compare_label)
      if (!total || selected != total || !nzchar(compare_label)) parts <- c(parts, value_label)
      if (!length(parts)) parts <- "条件未設定"
      return(paste0(paste(parts, collapse = " · "), suffix))
    }

    if (!nzchar(compare_label)) compare_label <- "条件未設定"
    paste0(compare_label, suffix)
  }

  # One event channel owns all dynamic rules. Native controls are deliberately
  # unbound to Shiny; stale DOM from an earlier Graph cannot update the owner.
  output$plot_filter_ui <- renderUI({
    if (!graph_editor_profile_has(editor_profile, "editable_data")) return(NULL)
    base <- attached_state_seed()
    if (!is.list(base)) return(NULL)
    d <- tryCatch(plot_source_data(), error = function(e) NULL)
    if (!is.data.frame(d)) return(NULL)
    f <- graph_plot_filter_normalize(base$plot_filter)
    generation <- as.integer(graph_state_replay_generation())
    opt <- function(value, label, selected = FALSE) tags$option(value = value,
      selected = if (selected) "selected" else NULL, label)
    controls <- lapply(f$rules, function(r) {
      if (!r$column %in% names(d)) return(NULL)
      kind <- r$kind
      combined_kind <- kind %in% c("numeric", "time")
      possible <- unique(as.character(d[[r$column]][!is.na(d[[r$column]])]))
      # Legacy compare-only numeric/time rules may not have stored the full value
      # set. Show all values until the user actually changes the value selector;
      # that first change upgrades the rule to combined mode.
      selected_values <- if (combined_kind && identical(r$mode, "compare") && !length(r$values)) possible else r$values
      comparison <- c("より大きい >" = "gt", "以上 ≥" = "gte", "より小さい <" = "lt",
                      "以下 ≤" = "lte", "範囲内" = "inside", "範囲外" = "outside")
      if (kind %in% c("date", "datetime", "time"))
        comparison <- c("より後" = "gt", "以降" = "gte", "より前" = "lt",
                        "以前" = "lte", "期間内" = "inside", "期間外" = "outside")
      input_type <- switch(kind, numeric = "number", date = "date", datetime = "datetime-local", time = "time", "text")
      show_compare <- !identical(kind, "categorical") && !identical(r$mode, "values") || combined_kind
      show_values <- identical(kind, "categorical") || combined_kind
      tags$details(class = "plot-filter-rule", open = "open",
        tags$summary(class = "plot-filter-rule-summary", title = "クリックして条件を開閉",
          tags$span(class = "plot-filter-rule-column", r$column),
          tags$span(class = "plot-filter-kind-badge", kind),
          tags$span(class = "plot-filter-rule-summary-state", plot_filter_rule_summary(r, possible))),
        tags$div(class = "plot-filter-rule-body", `data-column` = r$column,
          if (show_compare) tags$div(
            class = "plot-filter-comparison-section",
            if (combined_kind) tags$div(class = "plot-filter-value-heading",
              tags$b(if (identical(kind, "time")) "時間範囲・比較" else "範囲・比較"),
              tags$small(class = "text-muted", "（未入力なら範囲条件は使いません）")),
            tags$div(class = "plot-filter-comparison-controls",
              tags$label("条件", tags$select(`data-filter-field` = "op",
                lapply(seq_along(comparison), function(i)
                  opt(unname(comparison[i]), names(comparison)[i], identical(r$op, unname(comparison[i])))))),
              tags$label("値・開始", tags$input(type = input_type, step = if (kind %in% c("numeric", "time", "datetime")) "any" else NULL,
                `data-filter-field` = "a", value = r$a)),
              if (r$op %in% c("inside", "outside")) tags$label("終了", tags$input(type = input_type,
                step = if (kind %in% c("numeric", "time", "datetime")) "any" else NULL,
                `data-filter-field` = "b", value = r$b))
            )
          ),
          if (show_values) plot_filter_value_controls(r, possible, opt, selected_values = selected_values),
          tags$div(class = "plot-filter-rule-footer",
            tags$label(tags$input(type = "checkbox", `data-filter-field` = "include_na",
              checked = if (r$include_na) "checked" else NULL), "欠損値を含める"),
            tags$button(type = "button", `data-filter-action` = "remove", "条件を削除"))
        ))
    })
    available <- setdiff(names(d), vapply(f$rules, `[[`, "", "column"))
    tags$div(class = "plot-filter-root", `data-filter-generation` = generation,
      `data-filter-input` = session$ns("plot_filter_event"),
      tags$label(tags$input(type = "checkbox", `data-filter-action` = "enabled",
        checked = if (f$enabled) "checked" else NULL), "フィルターを使用"),
      if (f$enabled) tags$div(class = "plot-filter-contents",
        tags$div(class = "plot-filter-add",
          tags$select(`data-filter-column-picker` = "true",
            opt("", "列を選択"), lapply(available, function(n) opt(n, n))),
          tags$button(type = "button", `data-filter-action` = "add", "列の条件を追加")),
        controls,
        if (!length(f$rules)) tags$p(class = "help-block", "列の条件を追加してください。")),
      tags$script(src = paste0("plot_filter.js?v=", utils::URLencode(APP_ASSET_VERSION, reserved = TRUE)))
    )
  })
  outputOptions(output, "plot_filter_ui", suspendWhenHidden = FALSE)

  observeEvent(input$plot_filter_event, {
    e <- input$plot_filter_event
    if (!is.list(e) || isTRUE(graph_state_replay_active()) ||
        !identical(as.integer(e$generation), as.integer(isolate(graph_state_replay_generation())))) return()
    if (!is.function(on_plot_filter_commit)) return()
    on_plot_filter_commit(e, as.integer(e$generation))
  }, ignoreInit = TRUE, priority = 165)
