# Statistics owns analysis recipes/data preparation and its own recipe replay.
# It does not participate in GraphState hydration or persistent-Editor ownership.

  # ============================================================
  # Graph-linked Statistics (experimental)
  # ============================================================

  stats_recipes <- reactiveVal(list())
  stats_selected_id <- reactiveVal(NULL)
  stats_restoring <- reactiveVal(FALSE)

  # Analysis切替時のdynamic UI復元は複数flushにまたがる。
  # 古いAnalysisのonFlushed callbackが後から走って新しいAnalysisへ
  # 値を書き込まないよう、復元ごとにtokenを更新して世代管理する。
  stats_restore_token <- reactiveVal(NULL)

  # Analysis restore stays guarded until the browser-side input snapshot is
  # stable across consecutive explicit round-trips after the final update*Input()
  # batch. This reuses the existing generic browser barrier handler; no timer or
  # polling loop is involved.
  stats_restore_barrier_state <- reactiveVal(NULL)

  # A stable browser snapshot can intentionally differ from the stored recipe
  # when dynamic controls present an inferred/default value for an empty saved
  # field (for example Subject / ID).  Remember that post-restore presentation
  # state so the generic save observer does not mistake it for a user edit.
  stats_post_restore_baseline <- reactiveVal(NULL)

  # Dynamic ANOVA UI (1/2/3-factor design choices) must not depend on the
  # browser radio input arriving in the same flush. Keep an R-side source of
  # truth so Project restore / Analysis switching can rebuild the correct UI
  # immediately and deterministically.
  stats_ui_factor_n <- reactiveVal("two")

  # Project読込時はStatistics UIをGraph復元と同時に触らない。
  # recipe本体だけ保持し、Statisticsタブを開いた時にUIへ反映する。
  pending_stats_ui_restore <- reactiveVal(NULL)

  # While GraphState replay or lazy Analysis restore is in progress, the saved
  # target recipe is authoritative. Browser inputs can still contain values
  # from the previously attached Graph for one or more client flushes.
  stats_canonical_context_active <- function() {
    pending_id <- pending_stats_ui_restore()
    isTRUE(graph_state_replay_active()) ||
      isTRUE(stats_restoring()) ||
      (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id))
  }

  stats_new_id <- function() {
    paste0("analysis_", as.integer(Sys.time()), "_", sample.int(99999, 1))
  }

  # v3.58.3.4: derive the next default Analysis label from the largest
  # existing numeric suffix. This prevents duplicate visible names even when
  # add events arrive rapidly. User-entered names are never rewritten.
  stats_next_default_name <- function(rr = isolate(stats_recipes())) {
    rr <- rr %||% list()
    nms <- vapply(rr, function(z) as.character(z$name %||% ""), character(1))
    hits <- regexec("^Analysis\\s+([0-9]+)$", nms, perl = TRUE)
    nums <- suppressWarnings(vapply(regmatches(nms, hits), function(m) {
      if (length(m) >= 2L) as.integer(m[[2]]) else NA_integer_
    }, integer(1)))
    nums <- nums[is.finite(nums)]
    paste0("Analysis ", if (length(nums)) max(nums) + 1L else 1L)
  }

  stats_default_recipe <- function(name = NULL) {
    if (is.null(name)) {
      name <- stats_next_default_name()
    }
    list(
      name = name,
      type = "anova",
      data_source = "graph",
      custom_data = "",
      # Data preparation belongs to each Analysis.  The default is the original
      # Graph dataset as entered by the user; Plot reshape is a separate recipe.
      transform_type = "as_is",
      transform_columns = character(0),
      transform_row_id = FALSE,
      transform_names_to = "Condition",
      transform_values_to = "Value",
      factor_n = "two",
      design_one = "Between",
      design_two = "F1B_F2W",
      design_three = "F1B_F2W_F3W",
      alpha = "0.05",
      df_adjust = "none",
      multcomp = "holm",
      factor1_level = 2,
      factor2_level = 3,
      factor3_level = 3,
      anova_id = "",
      anova_dv = "",
      anova_f1 = "",
      anova_f2 = "",
      anova_f3 = "",
      anova_split = "",
      ttest_type = "welch",
      ttest_group = "",
      ttest_dv = "",
      ttest_x = "",
      ttest_y = "",
      cor_method = "pearson",
      cor_x = "",
      cor_y = "",
      cor_group = "",
      cor_levels = character(0)
    )
  }

  stats_scalar_chr <- function(x, default = "") {
    if (is.null(x) || length(x) < 1L) return(default)
    y <- unlist(x, recursive = TRUE, use.names = FALSE)
    if (!length(y) || is.na(y[[1]])) return(default)
    as.character(y[[1]])
  }

  stats_scalar_num <- function(x, default) {
    if (is.null(x) || length(x) < 1L) return(as.numeric(default))
    y <- suppressWarnings(as.numeric(unlist(x, recursive = TRUE, use.names = FALSE)[1]))
    if (!length(y) || !is.finite(y)) return(as.numeric(default))
    y
  }

  normalize_stats_recipe <- function(r, fallback_name = "Analysis", legacy_reshape = NULL) {
    if (is.null(r) || !is.list(r)) r <- list()

    out <- stats_default_recipe(name = stats_scalar_chr(r$name, fallback_name))

    # v3.72.27 migration: historical graph-source analyses implicitly consumed
    # Plot dat(), so a saved Plot Wide→Long configuration also changed the
    # Statistics input table.  Convert that hidden dependency once into an
    # explicit Analysis-local transform recipe.  New analyses default to raw.
    has_explicit_transform <- !is.null(r$transform_type)
    if (!has_explicit_transform && identical(stats_scalar_chr(r$data_source, "graph"), "graph")) {
      lr <- legacy_reshape %||% list()
      if (isTRUE(lr$enabled)) {
        r$transform_type <- "wide_to_long"
        r$transform_columns <- lr$columns %||% character(0)
        r$transform_row_id <- isTRUE(lr$row_id)
        r$transform_names_to <- stats_scalar_chr(lr$x_name, "Time")
        r$transform_values_to <- stats_scalar_chr(lr$y_name, "Value")
      }
    }

    # Character/scalar fields
    chr_fields <- c(
      "name", "type", "data_source", "custom_data",
      "transform_type", "transform_names_to", "transform_values_to", "factor_n",
      "design_one", "design_two", "design_three",
      "alpha", "df_adjust", "multcomp",
      "anova_id", "anova_dv", "anova_f1", "anova_f2", "anova_f3", "anova_split",
      "ttest_type", "ttest_group", "ttest_dv", "ttest_x", "ttest_y",
      "cor_method", "cor_x", "cor_y", "cor_group"
    )
    for (nm in chr_fields) {
      if (!is.null(r[[nm]])) out[[nm]] <- stats_scalar_chr(r[[nm]], out[[nm]])
    }

    out$transform_type <- if (out$transform_type %in% c("as_is", "wide_to_long")) out$transform_type else "as_is"
    out$transform_columns <- unique(as.character(unlist(r$transform_columns %||% out$transform_columns, use.names = FALSE)))
    out$transform_columns <- out$transform_columns[nzchar(out$transform_columns)]
    out$transform_row_id <- isTRUE(r$transform_row_id %||% out$transform_row_id)

    # The ANOVA factor levels are especially important: keep each recipe's
    # own saved scalar values independent from the preceding Analysis.
    out$factor1_level <- stats_scalar_num(r$factor1_level, out$factor1_level)
    out$factor2_level <- stats_scalar_num(r$factor2_level, out$factor2_level)
    out$factor3_level <- stats_scalar_num(r$factor3_level, out$factor3_level)

    lv <- r$cor_levels
    if (!is.null(lv)) {
      out$cor_levels <- as.character(unlist(lv, recursive = TRUE, use.names = FALSE))
    }

    out
  }

  normalize_stats_recipes <- function(rr, legacy_reshape = NULL) {
    if (is.null(rr) || !is.list(rr) || !length(rr)) return(list())

    ids <- names(rr)
    if (is.null(ids) || any(!nzchar(ids))) {
      ids <- paste0("analysis_restored_", seq_along(rr))
    }

    out <- vector("list", length(rr))
    names(out) <- ids

    for (i in seq_along(rr)) {
      out[[i]] <- normalize_stats_recipe(
        rr[[i]],
        fallback_name = paste0("Analysis ", i),
        legacy_reshape = legacy_reshape
      )
    }

    out
  }

  stats_custom_parsed_data <- reactive({
    canonical_context <- isTRUE(stats_canonical_context_active())
    r <- if (isTRUE(canonical_context)) stats_selected_recipe() else isolate(stats_selected_recipe())
    txt <- if (isTRUE(canonical_context)) {
      r$custom_data %||% ""
    } else {
      input$stats_custom_data %||% r$custom_data %||% ""
    }
    shiny::validate(shiny::need(nzchar(trimws(txt)), "別データを貼り付けてください。"))

    d <- tryCatch(
      read.delim(
        text = txt,
        header = TRUE,
        check.names = FALSE,
        stringsAsFactors = FALSE,
        na.strings = c("", "NA", "NaN")
      ),
      error = function(e) NULL
    )
    shiny::validate(shiny::need(!is.null(d), "Statistics用データを読み込めませんでした。"))
    d
  })

  stats_base_data <- reactive({
    canonical_context <- isTRUE(stats_canonical_context_active())
    r <- if (isTRUE(canonical_context)) stats_selected_recipe() else isolate(stats_selected_recipe())
    source_mode <- if (isTRUE(canonical_context)) {
      r$data_source %||% "graph"
    } else {
      input$stats_data_source %||% r$data_source %||% "graph"
    }
    if (identical(source_mode, "custom")) {
      return(stats_custom_parsed_data())
    }

    # Statistics starts from the original Graph dataset. Plot mapping/style and
    # Plot Wide→Long are intentionally outside this dependency boundary.
    raw_dat()
  })

  stats_selected_recipe <- reactive({
    id <- stats_selected_id()
    rr <- stats_recipes()
    if (is.null(id) || !id %in% names(rr)) return(stats_default_recipe())
    rr[[id]]
  })

  stats_transform_recipe <- reactive({
    # During recipe restore the stored Analysis is authoritative; browser inputs
    # can still contain the preceding Analysis for several flushes.  In this
    # guarded phase the recipe collection is allowed to be a reactive source so
    # an Analysis switch can immediately rebuild from its canonical recipe.
    if (isTRUE(stats_canonical_context_active())) {
      r <- stats_selected_recipe()
      return(graph_normalize_data_transform_recipe(list(
        type = r$transform_type %||% "as_is",
        columns = r$transform_columns %||% character(0),
        row_id = isTRUE(r$transform_row_id),
        names_to = r$transform_names_to %||% "Condition",
        values_to = r$transform_values_to %||% "Value"
      )))
    }

    # Normal Statistics editing is browser-input driven.  Keep the saved recipe
    # only as an isolated fallback for inputs that have not bound yet.  A
    # stats_recipes() write must not invalidate the analysis data pipeline: that
    # would rebuild the dynamic mapping UI, resend inputs, save again, and keep
    # the debounced Result output permanently pending.
    r <- isolate(stats_selected_recipe())
    graph_normalize_data_transform_recipe(list(
      type = input$stats_transform_type %||% r$transform_type %||% "as_is",
      columns = input$stats_transform_columns %||% r$transform_columns %||% character(0),
      row_id = isTRUE(input$stats_transform_row_id %||% r$transform_row_id),
      names_to = input$stats_transform_names_to %||% r$transform_names_to %||% "Condition",
      values_to = input$stats_transform_values_to %||% r$transform_values_to %||% "Value"
    ))
  })

  stats_source_result <- reactive({
    graph_apply_data_transform(
      stats_base_data(),
      stats_transform_recipe(),
      incomplete_is_warning = TRUE
    )
  })

  stats_source_data <- reactive({
    res <- stats_source_result()
    shiny::validate(shiny::need(
      is.null(res$warning),
      paste0("Statistics Data preparation: ", res$warning %||% "変換できませんでした。")
    ))
    res$data
  })

  output$stats_transform_status <- renderUI({
    r <- stats_transform_recipe()
    if (!identical(r$type, "wide_to_long")) {
      return(tags$small(class = "text-muted", "Original dataset をそのまま解析に使用します。"))
    }

    res <- tryCatch(stats_source_result(), error = function(e) NULL)
    if (is.null(res)) return(NULL)
    if (!is.null(res$warning)) {
      return(div(class = "alert alert-warning", style = "padding:6px 9px;", res$warning))
    }
    tags$small(
      class = "text-muted",
      paste0(
        "Analysis-local Wide→Long: ",
        paste(r$columns, collapse = ", "),
        " → ", r$names_to, " / ", r$values_to
      )
    )
  })

  output$stats_transform_columns_ui <- renderUI({
    d <- tryCatch(stats_base_data(), error = function(e) NULL)
    if (is.null(d) || !is.data.frame(d)) return(NULL)
    cols <- names(d)

    rid <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    r <- if (!is.null(rid) && rid %in% names(rr)) rr[[rid]] else stats_default_recipe()
    saved <- as.character(r$transform_columns %||% character(0))
    current <- isolate(input$stats_transform_columns)
    selected <- if (isTRUE(isolate(stats_canonical_context_active()))) {
      saved[saved %in% cols]
    } else if (!is.null(current) && length(current)) {
      as.character(current)[as.character(current) %in% cols]
    } else {
      saved[saved %in% cols]
    }

    checkboxGroupInput(
      "stats_transform_columns",
      "Wide→Longする列",
      choices = cols,
      selected = selected
    )
  })


  refresh_stats_choices <- function(selected = NULL) {
    rr <- isolate(stats_recipes())
    choices <- if (length(rr)) {
      stats::setNames(
        as.list(names(rr)),
        vapply(rr, function(z) z$name %||% "Analysis", character(1))
      )
    } else {
      character(0)
    }

    if (is.null(selected)) selected <- isolate(stats_selected_id())
    # Graph/Analysis replay owns this select value. Freeze the corresponding
    # browser echo so an updateSelectInput() message cannot be mistaken for a
    # user Analysis switch by the persistent Editor.
    freezeReactiveValue(input, "stats_selected")
    updateSelectInput(session, "stats_selected", choices = choices, selected = selected)
  }

  output$stats_link_summary <- renderUI({
    id <- stats_selected_id()
    rr <- stats_recipes()
    if (is.null(id) || !id %in% names(rr)) {
      return(
        div(
          class = "statistics-empty",
          "このGraphにはまだAnalysisがありません。左側の「＋ Add」から追加してください。"
        )
      )
    }

    r <- rr[[id]]
    div(
      class = "statistics-link-summary",
      tags$b(r$name %||% "Analysis"),
      tags$span(" — linked to this Graph"),
      tags$br(),
      tags$small(
        paste0(
          if (identical(r$data_source %||% "graph", "graph")) {
            "Data: original Graph dataset"
          } else {
            "Data: custom data"
          },
          if (identical(r$transform_type %||% "as_is", "wide_to_long")) {
            paste0(" / Preparation: Wide→Long (", paste(r$transform_columns %||% character(0), collapse = ", "), ")")
          } else {
            " / Preparation: as-is"
          }
        )
      )
    )
  })


  observeEvent(input$stats_factor_n, {
    # Normal user operation: radioButtons -> dynamic ANOVA UI.
    # During GraphState/recipe restoration the R-side target is authoritative;
    # ignore transient browser values until the owning replay has ended.
    if (isTRUE(isolate(stats_canonical_context_active()))) return()
    x <- input$stats_factor_n %||% "two"
    if (!x %in% c("one", "two", "three")) x <- "two"
    stats_ui_factor_n(x)
  }, ignoreInit = FALSE)

  output$stats_anova_factor_setup_ui <- renderUI({
    d <- tryCatch(stats_source_data(), error = function(e) NULL)
    cols <- if (!is.null(d) && ncol(d) > 0) names(d) else character(0)

    rid <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    r <- if (!is.null(rid) && rid %in% names(rr)) rr[[rid]] else list()

    # Dynamic UIの構造はR側の専用reactiveを唯一の基準にする。
    # radioButtonsのbrowser更新と同一flushである必要がなくなるため、
    # 「3要因が選択されているのに2要因用の要因計画が残る」状態を防ぐ。
    factor_n <- stats_ui_factor_n()
    if (!factor_n %in% c("one", "two", "three")) factor_n <- "two"
    nfac <- switch(factor_n, one = 1L, two = 2L, three = 3L, 2L)

    choose_saved <- function(saved, fallback = "") {
      saved <- saved %||% ""
      if (nzchar(saved) && saved %in% cols) return(saved)
      if (length(fallback) == 1L && nzchar(fallback) && fallback %in% cols) return(fallback)
      if (length(cols)) cols[1] else ""
    }

    # Statistics suggestions are derived only from the Analysis dataset. Plot
    # Mapping is deliberately not consulted. Saved recipe choices still win.
    id_names <- cols[tolower(cols) %in% c(
      "id", "subject", "subjectid", "subject_id",
      "rat", "ratid", "rat_id", "mouse", "animal"
    )]
    id_guess <- if (length(id_names)) id_names[1] else ""

    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    numeric_dv <- setdiff(numeric_cols, id_guess)
    dv_guess <- if (length(numeric_dv)) numeric_dv[length(numeric_dv)] else if (length(cols)) cols[length(cols)] else ""

    factor_priority_names <- c(
      "group", "condition", "time", "day", "session", "route",
      "treatment", "phase", "sex", "genotype"
    )
    factor_priority <- cols[tolower(cols) %in% factor_priority_names]
    categorical_cols <- cols[!vapply(d, is.numeric, logical(1))]
    candidate_factors <- unique(c(factor_priority, categorical_cols, cols))
    candidate_factors <- candidate_factors[
      nzchar(candidate_factors) &
        candidate_factors %in% cols &
        !candidate_factors %in% c(id_guess, dv_guess)
    ]
    if (!length(candidate_factors)) {
      candidate_factors <- setdiff(cols, c(id_guess, dv_guess))
    }
    if (!length(candidate_factors)) candidate_factors <- cols

    fallback_factor <- function(j) {
      if (!length(candidate_factors)) return("")
      candidate_factors[min(j, length(candidate_factors))]
    }

    # ANOVA3-like design selector.
    design_ui <- switch(
      factor_n,
      one = selectInput(
        "stats_design_one",
        "要因計画:",
        choices = c(
          "被験者間" = "Between",
          "被験者内" = "Within"
        ),
        selected = r$design_one %||% "Between"
      ),
      two = selectInput(
        "stats_design_two",
        "要因計画:",
        choices = c(
          "要因1：被験者間　|　要因2：被験者間" = "F1B_F2B",
          "要因1：被験者間　|　要因2：被験者内" = "F1B_F2W",
          "要因1：被験者内　|　要因2：被験者内" = "F1W_F2W"
        ),
        selected = r$design_two %||% "F1B_F2W"
      ),
      three = selectInput(
        "stats_design_three",
        "要因計画:",
        choices = c(
          "要因1：被験者間　|　要因2：被験者間　|　要因3：被験者間" = "F1B_F2B_F3B",
          "要因1：被験者間　|　要因2：被験者間　|　要因3：被験者内" = "F1B_F2B_F3W",
          "要因1：被験者間　|　要因2：被験者内　|　要因3：被験者内" = "F1B_F2W_F3W",
          "要因1：被験者内　|　要因2：被験者内　|　要因3：被験者内" = "F1W_F2W_F3W"
        ),
        selected = r$design_three %||% "F1B_F2W_F3W"
      )
    )

    current_level <- function(j, saved, fallback) {
      # Analysis切替中は、直前Analysisのinput値が一時的に残っているため
      # current inputを優先すると水準数が別Analysisへ混入する。
      # 復元中は必ずrecipe側の保存値を優先する。
      if (isTRUE(isolate(stats_canonical_context_active()))) {
        sv <- suppressWarnings(as.numeric(saved))
        if (length(sv) == 1L && is.finite(sv)) return(sv)
        return(fallback)
      }

      id <- paste0("stats_factor", j, "_level")
      cur <- isolate(input[[id]])
      if (!is.null(cur) && length(cur) == 1L && is.finite(as.numeric(cur))) {
        return(as.numeric(cur))
      }
      sv <- suppressWarnings(as.numeric(saved))
      if (length(sv) == 1L && is.finite(sv)) return(sv)
      fallback
    }

    factor_rows <- lapply(seq_len(nfac), function(j) {
      map_id <- paste0("stats_anova_f", j)
      level_id <- paste0("stats_factor", j, "_level")

      saved_map <- r[[paste0("anova_f", j)]] %||% ""
      saved_level <- r[[paste0("factor", j, "_level")]]

      selected_map <- choose_saved(saved_map, fallback_factor(j))

      actual_n <- NA_integer_
      if (!is.null(d) && nzchar(selected_map) && selected_map %in% names(d)) {
        z <- d[[selected_map]]
        actual_n <- length(unique(z[!is.na(z)]))
      }

      default_level <- if (is.finite(actual_n) && actual_n >= 2L) {
        actual_n
      } else if (j == 1L) {
        2
      } else {
        3
      }

      has_saved_mapping <- nzchar(saved_map) && saved_map %in% cols
      level_value <- if (!has_saved_mapping && is.finite(actual_n) && actual_n >= 2L) {
        actual_n
      } else {
        current_level(j, saved_level, default_level)
      }

      div(
        class = "anova-factor-row",
        h5(strong(paste0("要因", j))),
        fluidRow(
          column(
            7,
            selectInput(
              map_id,
              "データ列",
              choices = cols,
              selected = selected_map
            )
          ),
          column(
            5,
            numericInput(
              level_id,
              "水準数",
              value = level_value,
              min = 2,
              step = 1
            )
          )
        )
      )
    })

    tagList(
      design_ui,
      tags$hr(),
      p(strong("データの割り当て")),
      selectInput(
        "stats_anova_id",
        "Subject / ID",
        choices = c("（なし）" = "", cols),
        selected = if (nzchar(r$anova_id %||% "") && (r$anova_id %||% "") %in% cols) {
          r$anova_id
        } else {
          id_guess
        }
      ),
      selectInput(
        "stats_anova_dv",
        "従属変数",
        choices = cols,
        selected = choose_saved(r$anova_dv, dv_guess)
      ),
      selectInput(
        "stats_anova_split",
        "水準ごとに別々に解析する列（任意）",
        choices = c("分割しない" = "", cols),
        selected = if (
          nzchar(r$anova_split %||% "") &&
          (r$anova_split %||% "") %in% cols
        ) {
          r$anova_split
        } else {
          ""
        }
      ),
      p(
        class = "help-block",
        "例：groupを選ぶと、Normal / Expertなど各水準にデータを分け、同じANOVAを水準ごとに独立して実行します。"
      ),
      factor_rows
    )
  })

  output$stats_ttest_mapping_ui <- renderUI({
    d <- tryCatch(stats_source_data(), error = function(e) NULL)
    if (is.null(d) || ncol(d) < 1) return(NULL)
    cols <- names(d)
    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    if (!length(numeric_cols)) numeric_cols <- cols

    # Dynamic UIは現在の保存recipeを基準に再生成する。
    rid <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    r <- if (!is.null(rid) && rid %in% names(rr)) rr[[rid]] else list()

    choose_saved <- function(saved, fallback) {
      saved <- saved %||% ""
      if (nzchar(saved) && saved %in% cols) saved else fallback
    }

    if (identical(input$stats_ttest_type %||% "welch", "paired")) {
      tagList(
        selectInput(
          "stats_ttest_x",
          "変数1",
          choices = numeric_cols,
          selected = if (nzchar(r$ttest_x %||% "") && r$ttest_x %in% numeric_cols) {
            r$ttest_x
          } else {
            numeric_cols[1]
          }
        ),
        selectInput(
          "stats_ttest_y",
          "変数2",
          choices = numeric_cols,
          selected = if (nzchar(r$ttest_y %||% "") && r$ttest_y %in% numeric_cols) {
            r$ttest_y
          } else {
            numeric_cols[min(2, length(numeric_cols))]
          }
        )
      )
    } else {
      tagList(
        selectInput(
          "stats_ttest_group",
          "Group列",
          choices = cols,
          selected = choose_saved(r$ttest_group, cols[1])
        ),
        selectInput(
          "stats_ttest_dv",
          "従属変数",
          choices = numeric_cols,
          selected = if (nzchar(r$ttest_dv %||% "") && r$ttest_dv %in% numeric_cols) {
            r$ttest_dv
          } else {
            numeric_cols[length(numeric_cols)]
          }
        )
      )
    }
  })

  output$stats_cor_mapping_ui <- renderUI({
    d <- tryCatch(stats_source_data(), error = function(e) NULL)
    if (is.null(d) || ncol(d) < 1) return(NULL)
    cols <- names(d)
    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    if (!length(numeric_cols)) numeric_cols <- cols

    rid <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    r <- if (!is.null(rid) && rid %in% names(rr)) rr[[rid]] else list()

    choose_saved <- function(saved, fallback) {
      saved <- saved %||% ""
      if (nzchar(saved) && saved %in% cols) saved else fallback
    }

    group_saved <- r$cor_group %||% ""
    group_selected <- if (nzchar(group_saved) && group_saved %in% cols) {
      group_saved
    } else {
      ""
    }

    tagList(
      selectInput(
        "stats_cor_x",
        "X",
        choices = numeric_cols,
        selected = if (nzchar(r$cor_x %||% "") && r$cor_x %in% numeric_cols) {
          r$cor_x
        } else {
          numeric_cols[1]
        }
      ),
      selectInput(
        "stats_cor_y",
        "Y",
        choices = numeric_cols,
        selected = if (nzchar(r$cor_y %||% "") && r$cor_y %in% numeric_cols) {
          r$cor_y
        } else {
          numeric_cols[min(2, length(numeric_cols))]
        }
      ),
      selectInput(
        "stats_cor_group",
        "Group列（任意）",
        choices = c("なし（全体）" = "", cols),
        selected = group_selected
      ),
      uiOutput("stats_cor_levels_ui")
    )
  })

  output$stats_cor_levels_ui <- renderUI({
    d <- tryCatch(stats_source_data(), error = function(e) NULL)
    if (is.null(d)) return(NULL)

    grp <- input$stats_cor_group %||% ""
    if (!nzchar(grp) || !grp %in% names(d)) return(NULL)

    observed <- unique(as.character(d[[grp]]))
    observed <- observed[!is.na(observed) & nzchar(observed)]
    if (!length(observed)) return(NULL)

    rid <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    r <- if (!is.null(rid) && rid %in% names(rr)) rr[[rid]] else list()

    saved_levels <- r$cor_levels
    if (is.null(saved_levels)) saved_levels <- character(0)
    saved_levels <- as.character(unlist(saved_levels, use.names = FALSE))
    selected_levels <- saved_levels[saved_levels %in% observed]
    if (!length(selected_levels)) selected_levels <- observed

    checkboxGroupInput(
      "stats_cor_levels",
      "対象群",
      choices = observed,
      selected = selected_levels
    )
  })

  stats_restore_token_is_current <- function(id, token) {
    identical(isolate(stats_restore_token()), token) &&
      identical(isolate(stats_selected_id()), id)
  }

  stats_restore_static_controls <- function(r) {
    updateTextInput(session, "stats_name", value = r$name %||% "")
    updateSelectInput(session, "stats_type", selected = r$type %||% "anova")
    updateRadioButtons(session, "stats_data_source", selected = r$data_source %||% "graph")
    shinyAce::updateAceEditor(session, "stats_custom_data", value = r$custom_data %||% "")
    updateRadioButtons(session, "stats_transform_type", selected = r$transform_type %||% "as_is")
    updateCheckboxInput(session, "stats_transform_row_id", value = isTRUE(r$transform_row_id))
    updateTextInput(session, "stats_transform_names_to", value = r$transform_names_to %||% "Condition")
    updateTextInput(session, "stats_transform_values_to", value = r$transform_values_to %||% "Value")
    updateRadioButtons(session, "stats_factor_n", selected = r$factor_n %||% "two")
    updateRadioButtons(session, "stats_alpha", selected = r$alpha %||% "0.05")
    updateRadioButtons(session, "stats_df_adjust", selected = r$df_adjust %||% "none")
    updateRadioButtons(session, "stats_multcomp", selected = r$multcomp %||% "holm")
    updateRadioButtons(session, "stats_ttest_type", selected = r$ttest_type %||% "welch")
    updateRadioButtons(session, "stats_cor_method", selected = r$cor_method %||% "pearson")
    invisible(TRUE)
  }

  stats_restore_dynamic_controls <- function(r, include_cor_levels = FALSE) {
    updateCheckboxGroupInput(
      session, "stats_transform_columns",
      selected = as.character(r$transform_columns %||% character(0))
    )

    factor_n <- r$factor_n %||% "two"
    if (identical(factor_n, "one")) {
      updateSelectInput(session, "stats_design_one", selected = r$design_one %||% "Between")
    } else if (identical(factor_n, "two")) {
      updateSelectInput(session, "stats_design_two", selected = r$design_two %||% "F1B_F2W")
    } else {
      updateSelectInput(session, "stats_design_three", selected = r$design_three %||% "F1B_F2W_F3W")
    }

    updateNumericInput(session, "stats_factor1_level", value = as.numeric(r$factor1_level %||% 2))
    updateNumericInput(session, "stats_factor2_level", value = as.numeric(r$factor2_level %||% 3))
    updateNumericInput(session, "stats_factor3_level", value = as.numeric(r$factor3_level %||% 3))

    for (nm in c("anova_id", "anova_dv", "anova_f1", "anova_f2", "anova_f3", "anova_split")) {
      updateSelectInput(session, paste0("stats_", nm), selected = r[[nm]] %||% "")
    }
    for (nm in c("ttest_group", "ttest_dv", "ttest_x", "ttest_y")) {
      updateSelectInput(session, paste0("stats_", nm), selected = r[[nm]] %||% "")
    }
    for (nm in c("cor_x", "cor_y", "cor_group")) {
      updateSelectInput(session, paste0("stats_", nm), selected = r[[nm]] %||% "")
    }

    if (isTRUE(include_cor_levels)) {
      updateCheckboxGroupInput(
        session, "stats_cor_levels",
        selected = as.character(unlist(r$cor_levels %||% character(0), use.names = FALSE))
      )
    }
    invisible(TRUE)
  }

  stats_request_restore_barrier <- function(id, token, attempt = 1L) {
    if (!stats_restore_token_is_current(id, token)) return(invisible(FALSE))

    attempt <- suppressWarnings(as.integer(attempt))[1]
    if (!is.finite(attempt) || attempt < 1L) attempt <- 1L

    session$sendCustomMessage(
      "stats-restore-browser-barrier",
      list(
        id = id,
        generation = 1L,
        attempt = attempt,
        token = token,
        ackId = session$ns("stats_restore_barrier_ack")
      )
    )
    diag("STATS-RESTORE-BARRIER", paste0(
      "requested id=", id, " attempt=", attempt, " token=", token
    ))
    invisible(TRUE)
  }

  stats_restore_recipe_phase <- function(id, token, phase = 1L) {
    if (!stats_restore_token_is_current(id, token)) return(invisible(FALSE))
    rr <- isolate(stats_recipes())
    if (!id %in% names(rr)) {
      stats_restoring(FALSE)
      stats_restore_token(NULL)
      stats_restore_barrier_state(NULL)
      return(invisible(FALSE))
    }
    r <- rr[[id]]

    if (phase <= 2L) {
      stats_restore_dynamic_controls(r, include_cor_levels = phase >= 2L)
      session$onFlushed(function() {
        stats_restore_recipe_phase(id, token, phase = phase + 1L)
      }, once = TRUE)
      return(invisible(TRUE))
    }

    factor_n <- r$factor_n %||% "two"
    if (!factor_n %in% c("one", "two", "three")) factor_n <- "two"
    stats_ui_factor_n(factor_n)

    # Do not release stats_restoring here. update*Input() messages from the
    # preceding phases have only just reached the browser; dynamic renderUI
    # inputs can bind one client turn later. Cross bounded browser round-trips
    # until the canonical input snapshot is stable, then release the guard.
    stats_restore_barrier_state(list(
      id = id,
      token = token,
      attempt = 1L,
      signature = NULL
    ))
    stats_request_restore_barrier(id, token, attempt = 1L)
    invisible(TRUE)
  }

  stats_restore_input_snapshot <- function(id) {
    isolate({
      rr <- stats_recipes()
      if (is.null(id) || !id %in% names(rr)) return(NULL)

      current <- normalize_stats_recipe(
        rr[[id]],
        fallback_name = stats_scalar_chr(rr[[id]]$name, "Analysis")
      )
      candidate <- stats_capture_recipe_from_inputs(current, active_type = current$type)
      normalize_stats_recipe(
        candidate,
        fallback_name = stats_scalar_chr(candidate$name, current$name %||% "Analysis")
      )
    })
  }

  stats_settle_restore_barrier <- function(id, token, attempt) {
    if (!stats_restore_token_is_current(id, token)) return(invisible(FALSE))

    candidate <- stats_restore_input_snapshot(id)
    if (is.null(candidate)) {
      stats_post_restore_baseline(NULL)
      stats_restoring(FALSE)
      stats_restore_token(NULL)
      stats_restore_barrier_state(NULL)
      return(invisible(FALSE))
    }

    signature <- serialize(candidate, NULL, ascii = TRUE, version = 2)
    state <- isolate(stats_restore_barrier_state())
    if (is.null(state) || !identical(state$token, token)) return(invisible(FALSE))

    stable <- !is.null(state$signature) && identical(state$signature, signature)
    max_attempt <- 4L
    if (isTRUE(stable) || attempt >= max_attempt) {
      stats_post_restore_baseline(list(id = id, recipe = candidate))
      diag("STATS-RESTORE-BASELINE", paste0("armed id=", id, " attempt=", attempt))
      stats_restoring(FALSE)
      stats_restore_token(NULL)
      stats_restore_barrier_state(NULL)
      diag("STATS-RESTORE-BARRIER", paste0(
        "released id=", id, " attempt=", attempt,
        " stable=", if (isTRUE(stable)) "TRUE" else "FALSE_MAX"
      ))
      return(invisible(TRUE))
    }

    next_attempt <- attempt + 1L
    stats_restore_barrier_state(list(
      id = id, token = token, attempt = next_attempt, signature = signature
    ))
    diag("STATS-RESTORE-BARRIER", paste0(
      "settling id=", id, " attempt=", attempt, " next=", next_attempt
    ))
    stats_request_restore_barrier(id, token, attempt = next_attempt)
    invisible(TRUE)
  }

  observeEvent(input$stats_restore_barrier_ack, {
    ack <- input$stats_restore_barrier_ack
    if (!is.list(ack)) return()

    id <- isolate(stats_selected_id())
    token <- isolate(stats_restore_token())
    state <- isolate(stats_restore_barrier_state())
    if (is.null(id) || is.null(token) || is.null(state)) return()
    if (!identical(as.character(ack$id %||% "")[1], as.character(id)[1])) return()
    if (!identical(as.character(ack$token %||% "")[1], as.character(token)[1])) return()

    attempt <- suppressWarnings(as.integer(ack$attempt %||% 0L))[1]
    if (!is.finite(attempt) || !identical(attempt, as.integer(state$attempt %||% 0L))) return()

    diag("STATS-RESTORE-BARRIER", paste0(
      "acked id=", id, " attempt=", attempt, " token=", token
    ))

    # The ACK can share a flush with browser input echoes. Keep the restore guard
    # TRUE for that whole flush, then assess stability from a focused helper.
    session$onFlushed(function() {
      stats_settle_restore_barrier(id, token, attempt)
    }, once = TRUE)
  }, ignoreInit = TRUE, priority = 100)

  load_stats_recipe <- function(id) {
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return(invisible(FALSE))
    r <- rr[[id]]

    token <- paste0(
      id, "::", format(Sys.time(), "%Y%m%d%H%M%OS6"), "::", sample.int(999999L, 1L)
    )
    stats_restore_token(token)
    stats_restore_barrier_state(NULL)
    stats_post_restore_baseline(NULL)
    stats_restoring(TRUE)
    stats_selected_id(id)

    factor_n <- r$factor_n %||% "two"
    if (!factor_n %in% c("one", "two", "three")) factor_n <- "two"
    stats_ui_factor_n(factor_n)
    stats_restore_static_controls(r)

    session$onFlushed(function() {
      stats_restore_recipe_phase(id, token, phase = 1L)
    }, once = TRUE)
    invisible(TRUE)
  }


  # The Statistics controls live inside the one persistent Graph Editor, so a
  # Graph switch must replace their transient context just like Mapping/Style.
  # In particular, an in-flight Analysis restore from the previous Graph must
  # be cancelled explicitly; otherwise its token becomes stale while
  # stats_restoring() can remain TRUE indefinitely.
  stats_cancel_restore <- function(reason = "graph-context-replace") {
    had_restore <- isTRUE(isolate(stats_restoring())) ||
      !is.null(isolate(stats_restore_token())) ||
      !is.null(isolate(stats_restore_barrier_state()))
    old_id <- isolate(stats_selected_id())

    stats_restore_token(NULL)
    stats_restore_barrier_state(NULL)
    stats_post_restore_baseline(NULL)
    stats_restoring(FALSE)

    if (isTRUE(had_restore)) {
      diag(
        "STATS-RESTORE-CANCEL",
        paste0("reason=", reason, " previous_id=", as.character(old_id %||% "<none>"))
      )
    }
    invisible(had_restore)
  }

  stats_clear_browser_controls <- function() {
    empty <- stats_default_recipe(name = "")
    stats_ui_factor_n("two")
    stats_restore_static_controls(empty)
    stats_restore_dynamic_controls(empty, include_cor_levels = TRUE)
    invisible(TRUE)
  }

  # Replace all Statistics ownership for the target Graph in one focused
  # boundary. The actual data-dependent recipe UI is restored lazily after the
  # outer GraphState replay completes, so select choices are always derived from
  # the target Graph rather than the previous one.
  stats_replace_graph_context <- function(restored = list(), preferred_id = NULL, legacy_reshape = NULL) {
    restored <- normalize_stats_recipes(restored, legacy_reshape = legacy_reshape)

    stats_cancel_restore("graph-switch")
    pending_stats_ui_restore(NULL)
    stats_recipes(restored)

    ids <- names(restored)
    preferred <- as.character(unlist(preferred_id %||% "", recursive = TRUE, use.names = FALSE))
    preferred <- if (length(preferred)) preferred[[1]] else ""
    target_id <- if (nzchar(preferred) && preferred %in% ids) {
      preferred
    } else if (length(ids)) {
      ids[[1]]
    } else {
      NULL
    }

    stats_selected_id(target_id)
    if (!is.null(target_id)) {
      factor_n <- restored[[target_id]]$factor_n %||% "two"
      if (!factor_n %in% c("one", "two", "three")) factor_n <- "two"
      stats_ui_factor_n(factor_n)
      pending_stats_ui_restore(target_id)
    } else {
      # No Analysis belongs to the target Graph. Clear the persistent browser
      # controls as well as the canonical recipe collection so the previous
      # Graph's settings/result cannot remain visible as a false carry-over.
      stats_clear_browser_controls()
    }

    refresh_stats_choices(target_id)
    diag(
      "STATS-GRAPH-CONTEXT",
      paste0(
        "replace recipes=", length(restored),
        " selected=", as.character(target_id %||% "<none>"),
        " preferred=", if (nzchar(preferred)) preferred else "<none>"
      )
    )
    invisible(target_id)
  }

  stats_selected_id_for_project <- function() {
    id <- stats_selected_id()
    rr <- stats_recipes()
    if (is.null(id) || length(id) != 1L || !nzchar(id) || !id %in% names(rr)) return(NULL)
    as.character(id)[1]
  }

  stats_capture_common_inputs <- function(r) {
    nm <- trimws(input$stats_name %||% r$name %||% "Analysis")
    if (!nzchar(nm)) nm <- "Analysis"
    r$name <- nm
    r$type <- input$stats_type %||% r$type
    r$data_source <- input$stats_data_source %||% r$data_source
    r$custom_data <- if (identical(r$data_source %||% "graph", "custom")) {
      input$stats_custom_data %||% r$custom_data
    } else ""

    r$transform_type <- input$stats_transform_type %||% r$transform_type %||% "as_is"
    r$transform_columns <- as.character(input$stats_transform_columns %||% r$transform_columns %||% character(0))
    r$transform_row_id <- isTRUE(input$stats_transform_row_id %||% r$transform_row_id)
    r$transform_names_to <- input$stats_transform_names_to %||% r$transform_names_to %||% "Condition"
    r$transform_values_to <- input$stats_transform_values_to %||% r$transform_values_to %||% "Value"
    r$factor_n <- input$stats_factor_n %||% r$factor_n
    r$design_one <- input$stats_design_one %||% r$design_one
    r$design_two <- input$stats_design_two %||% r$design_two
    r$design_three <- input$stats_design_three %||% r$design_three
    r$alpha <- input$stats_alpha %||% r$alpha
    r$df_adjust <- input$stats_df_adjust %||% r$df_adjust
    r$multcomp <- input$stats_multcomp %||% r$multcomp
    r$factor1_level <- as.numeric(input$stats_factor1_level %||% r$factor1_level %||% 2)
    r$factor2_level <- as.numeric(input$stats_factor2_level %||% r$factor2_level %||% 3)
    r$factor3_level <- as.numeric(input$stats_factor3_level %||% r$factor3_level %||% 3)
    r
  }

  stats_capture_anova_inputs <- function(r) {
    for (nm in c("anova_id", "anova_dv", "anova_f1", "anova_f2", "anova_f3", "anova_split")) {
      r[[nm]] <- input[[paste0("stats_", nm)]] %||% r[[nm]] %||% ""
    }
    r
  }

  stats_capture_ttest_inputs <- function(r) {
    r$ttest_type <- input$stats_ttest_type %||% r$ttest_type
    for (nm in c("ttest_group", "ttest_dv", "ttest_x", "ttest_y")) {
      r[[nm]] <- input[[paste0("stats_", nm)]] %||% r[[nm]] %||% ""
    }
    r
  }

  stats_capture_correlation_inputs <- function(r) {
    r$cor_method <- input$stats_cor_method %||% r$cor_method
    for (nm in c("cor_x", "cor_y", "cor_group")) {
      r[[nm]] <- input[[paste0("stats_", nm)]] %||% r[[nm]] %||% ""
    }
    if (nzchar(r$cor_group %||% "")) {
      if (!is.null(input$stats_cor_levels)) r$cor_levels <- as.character(input$stats_cor_levels)
    } else {
      r$cor_levels <- character(0)
    }
    r
  }

  stats_capture_recipe_from_inputs <- function(r, active_type = NULL) {
    r <- stats_capture_common_inputs(r)

    # Only the active analysis type owns its mapping inputs. Hidden/dormant
    # type-specific controls can be rebuilt by renderUI and may auto-select a
    # first choice; capturing all types here would leak those browser defaults
    # into an unrelated Analysis recipe during restore/switch.
    type <- active_type %||% r$type %||% "anova"
    if (!type %in% c("anova", "ttest", "correlation")) type <- "anova"
    r$type <- type

    if (identical(type, "anova")) return(stats_capture_anova_inputs(r))
    if (identical(type, "ttest")) return(stats_capture_ttest_inputs(r))
    stats_capture_correlation_inputs(r)
  }

  save_current_stats_recipe <- function() {
    if (isTRUE(isolate(graph_state_replay_active()))) return(invisible(FALSE))
    if (isTRUE(isolate(stats_restoring()))) return(invisible(FALSE))

    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) {
      return(invisible(FALSE))
    }

    id <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return(invisible(FALSE))

    current <- normalize_stats_recipe(
      rr[[id]],
      fallback_name = stats_scalar_chr(rr[[id]]$name, "Analysis")
    )
    candidate <- stats_capture_recipe_from_inputs(current)
    candidate <- normalize_stats_recipe(
      candidate,
      fallback_name = stats_scalar_chr(candidate$name, current$name %||% "Analysis")
    )

    baseline <- isolate(stats_post_restore_baseline())
    if (!is.null(baseline) && identical(baseline$id, id)) {
      if (identical(candidate, baseline$recipe)) return(invisible(FALSE))
      # The first value that differs from the stable restore snapshot is a real
      # edit boundary. From here on normal semantic comparison/commit applies.
      stats_post_restore_baseline(NULL)
    }

    # Dynamic Statistics controls are rebuilt from stats_recipes(). Writing an
    # identical recipe here can therefore create a UI -> input -> save loop.
    # Only a semantic recipe change is allowed to invalidate the collection.
    if (identical(current, candidate)) return(invisible(FALSE))

    rr[[id]] <- candidate
    stats_recipes(rr)
    diag("STATS-RECIPE-COMMIT", paste0("id=", id, " source=inputs"))
    invisible(TRUE)
  }

  observeEvent(input$stats_add, {
    # invalidate any queued restore callbacks from the previously selected Analysis
    stats_restore_token(NULL)
    stats_restore_barrier_state(NULL)

    rr <- isolate(stats_recipes())
    id <- stats_new_id()
    rr[[id]] <- stats_default_recipe(name = stats_next_default_name(rr))
    stats_recipes(rr)

    stats_restoring(TRUE)
    stats_selected_id(id)

    choices <- stats::setNames(
      as.list(names(rr)),
      vapply(rr, function(z) z$name %||% "Analysis", character(1))
    )

    freezeReactiveValue(input, "stats_selected")
    updateSelectInput(session, "stats_selected", choices = choices, selected = id)

    session$onFlushed(function() {
      load_stats_recipe(id)
    }, once = TRUE)
  })

  observeEvent(input$stats_delete, {
    # invalidate any queued restore callbacks from the deleted/current Analysis
    stats_restore_token(NULL)
    stats_restore_barrier_state(NULL)
    stats_post_restore_baseline(NULL)

    id <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return()

    rr[[id]] <- NULL
    stats_recipes(rr)

    next_id <- if (length(rr)) names(rr)[1] else NULL
    stats_selected_id(next_id)

    choices <- if (length(rr)) {
      stats::setNames(
        as.list(names(rr)),
        vapply(rr, function(z) z$name %||% "Analysis", character(1))
      )
    } else {
      character(0)
    }

    freezeReactiveValue(input, "stats_selected")
    updateSelectInput(session, "stats_selected", choices = choices, selected = next_id)

    if (!is.null(next_id)) {
      session$onFlushed(function() load_stats_recipe(next_id), once = TRUE)
    }
  })

  observeEvent(input$stats_selected, {
    if (isTRUE(isolate(graph_state_replay_active()))) return()
    id <- input$stats_selected %||% ""
    if (!nzchar(id)) return()
    if (identical(id, isolate(stats_selected_id()))) return()

    pending_id <- isolate(pending_stats_ui_restore())

    # 通常のAnalysis切替では現在recipeを保存。
    # Project遅延復元中だけはdefault UIを保存してはいけない。
    if (is.null(pending_id) || length(pending_id) != 1L || !nzchar(pending_id)) {
      save_current_stats_recipe()
    }

    load_stats_recipe(id)
    pending_stats_ui_restore(NULL)
  }, ignoreInit = TRUE)

  # v3.58.2: Statistics recipes store only the analysis *recipe* (design,
  # variables, data source, options).  Calculated test results are deliberately
  # not serialized; opening Statistics recalculates them from the selected Analysis dataset.
  #
  # Keep the pending recipe until the Statistics tab is active, then replay it
  # exactly once. Graph ownership/value replay is handled by the outer Editor.
  observe({
    req(identical(input$graph_main_tab, "Statistics"))

    id <- pending_stats_ui_restore()
    req(!is.null(id), length(id) == 1L, nzchar(id))

    rr <- isolate(stats_recipes())
    if (!id %in% names(rr)) {
      diag("STATS-RESTORE", paste0("pending recipe missing id=", id, " recipes=", length(rr)))
      pending_stats_ui_restore(NULL)
      return()
    }


    # A saved Statistics recipe may itself restore graph_main_tab=Statistics.
    # Wait until the outer persistent-Editor value replay has completed before
    # touching recipe controls; this replaces the deleted structural-restore
    # gate without reintroducing a second Graph hydration protocol.
    req(!isTRUE(graph_state_replay_active()))

    diag("STATS-RESTORE", paste0(
      "apply recipe id=", id,
      " name=", rr[[id]]$name %||% "Analysis",
      " type=", rr[[id]]$type %||% "anova",
      " data_source=", rr[[id]]$data_source %||% "graph",
      " results_saved=FALSE recalc_on_open=TRUE"
    ))

    # load_stats_recipe() sets stats_restoring(TRUE) synchronously. Clear the
    # pending marker only after entering that guarded restoration path.
    load_stats_recipe(id)
    pending_stats_ui_restore(NULL)
  })

  observeEvent(input$stats_name, {
    if (isTRUE(isolate(graph_state_replay_active()))) return()
    if (isTRUE(stats_restoring())) return()

    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return()

    id <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return()

    nm <- trimws(input$stats_name %||% "")
    if (!nzchar(nm)) return()
    if (identical(stats_scalar_chr(rr[[id]]$name, ""), nm)) return()

    rr[[id]]$name <- nm
    stats_recipes(rr)

    # Update only the choice labels; preserve the same selected id.
    choices <- stats::setNames(
      as.list(names(rr)),
      vapply(rr, function(z) z$name %||% "Analysis", character(1))
    )
    freezeReactiveValue(input, "stats_selected")
    updateSelectInput(session, "stats_selected", choices = choices, selected = id)
  }, ignoreInit = TRUE)

  observe({
    req(stats_selected_id())
    if (isTRUE(graph_state_replay_active())) return()

    # Project読込後のlazy restore待ちでは、static UIの初期値を無視する。
    pending_id <- pending_stats_ui_restore()
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return()

    input$stats_type
    input$stats_data_source
    input$stats_custom_data
    input$stats_transform_type
    input$stats_transform_columns
    input$stats_transform_row_id
    input$stats_transform_names_to
    input$stats_transform_values_to
    input$stats_factor_n
    input$stats_design_one
    input$stats_design_two
    input$stats_design_three
    input$stats_alpha
    input$stats_df_adjust
    input$stats_multcomp
    input$stats_factor1_level
    input$stats_factor2_level
    input$stats_factor3_level
    input$stats_anova_id
    input$stats_anova_dv
    input$stats_anova_f1
    input$stats_anova_f2
    input$stats_anova_f3
    input$stats_anova_split
    input$stats_ttest_type
    input$stats_ttest_group
    input$stats_ttest_dv
    input$stats_ttest_x
    input$stats_ttest_y
    input$stats_cor_method
    input$stats_cor_x
    input$stats_cor_y
    input$stats_cor_group
    input$stats_cor_levels

    save_current_stats_recipe()
  })


  # ---- Statistics auto calculation -------------------------------------

  # ANOVA君は初回だけsourceして再利用する。
  anovakun_env_05 <- NULL
  anovakun_env_10 <- NULL

  get_anovakun_env <- function(alpha = "0.05") {
    use_10 <- identical(alpha, "0.10")

    if (use_10 && !is.null(anovakun_env_10)) return(anovakun_env_10)
    if (!use_10 && !is.null(anovakun_env_05)) return(anovakun_env_05)

    anova_file <- if (use_10) "anovakun_489_10.txt" else "anovakun_489.txt"

    candidates <- unique(c(
      file.path(getwd(), anova_file),
      anova_file
    ))
    anova_path <- candidates[file.exists(candidates)][1]

    if (length(anova_path) != 1L || is.na(anova_path)) {
      stop(paste0(anova_file, " が見つかりません。"))
    }

    env <- new.env(parent = globalenv())
    source(anova_path, local = env, encoding = "UTF-8")

    if (!exists("anovakun", envir = env, inherits = FALSE)) {
      stop("ANOVA君の読み込みに失敗しました。")
    }

    if (use_10) {
      anovakun_env_10 <<- env
    } else {
      anovakun_env_05 <<- env
    }

    env
  }

  stats_anova_design <- reactive({
    factor_n <- input$stats_factor_n %||% "two"

    code <- switch(
      factor_n,
      one = switch(
        input$stats_design_one %||% "Between",
        Between = "As",
        Within = "sA"
      ),
      two = switch(
        input$stats_design_two %||% "F1B_F2W",
        F1B_F2B = "ABs",
        F1B_F2W = "AsB",
        F1W_F2W = "sAB"
      ),
      three = switch(
        input$stats_design_three %||% "F1B_F2W_F3W",
        F1B_F2B_F3B = "ABCs",
        F1B_F2B_F3W = "ABsC",
        F1B_F2W_F3W = "AsBC",
        F1W_F2W_F3W = "sABC"
      )
    )

    levels <- c(as.integer(input$stats_factor1_level %||% 2))
    if (factor_n %in% c("two", "three")) {
      levels <- c(levels, as.integer(input$stats_factor2_level %||% 3))
    }
    if (identical(factor_n, "three")) {
      levels <- c(levels, as.integer(input$stats_factor3_level %||% 3))
    }

    list(code = code, levels = levels, factor_n = factor_n)
  })

  compute_anovakun_result <- function() {
    d <- stats_source_data()
    des <- stats_anova_design()

    sid <- input$stats_anova_id %||% ""
    dv  <- input$stats_anova_dv %||% ""
    f1  <- input$stats_anova_f1 %||% ""
    f2  <- input$stats_anova_f2 %||% ""
    f3  <- input$stats_anova_f3 %||% ""
    split_var <- input$stats_anova_split %||% ""

    factors <- c(f1)
    if (des$factor_n %in% c("two", "three")) factors <- c(factors, f2)
    if (identical(des$factor_n, "three")) factors <- c(factors, f3)

    shiny::validate(shiny::need(
      nzchar(dv) && dv %in% names(d),
      "従属変数を選択してください。"
    ))
    shiny::validate(shiny::need(
      all(nzchar(factors)) && all(factors %in% names(d)),
      "要因1〜3を選択してください。"
    ))
    shiny::validate(shiny::need(
      length(unique(c(dv, factors))) == length(c(dv, factors)),
      "従属変数と各要因には別々の列を指定してください。"
    ))

    if (nzchar(split_var)) {
      shiny::validate(shiny::need(
        split_var %in% names(d),
        "分割列がデータにありません。"
      ))
      shiny::validate(shiny::need(
        !split_var %in% c(dv, factors, sid),
        "分割列は Subject / ID・従属変数・ANOVA要因とは別の列を指定してください。"
      ))
    }

    # designから被験者内要因の有無を判定
    spos <- regexpr("s", des$code, fixed = TRUE)[1]
    maxfact <- nchar(des$code) - 1L
    withlen <- maxfact - spos + 1L

    if (withlen > 0L) {
      shiny::validate(shiny::need(
        nzchar(sid) && sid %in% names(d),
        "被験者内要因を含む計画では Subject / ID を指定してください。"
      ))
    }

    if (nzchar(sid)) {
      shiny::validate(shiny::need(
        sid %in% names(d),
        "Subject / ID列が見つかりません。"
      ))
      shiny::validate(shiny::need(
        !sid %in% c(dv, factors),
        "Subject / IDはDV・要因とは別の列を指定してください。"
      ))
    }

    alpha <- input$stats_alpha %||% "0.05"
    env <- get_anovakun_env(alpha)

    opts <- list(
      long = TRUE,
      mau = TRUE,
      peta = TRUE
    )

    adj <- input$stats_df_adjust %||% "none"
    if (identical(adj, "gg")) {
      opts$auto <- TRUE
    } else if (identical(adj, "hf")) {
      opts$hf <- TRUE
    }

    mc <- input$stats_multcomp %||% "holm"
    if (identical(mc, "holm")) {
      opts$holm <- TRUE
    } else if (identical(mc, "shaffer")) {
      opts$s2r <- TRUE
    }

    data_label <- if (identical(input$stats_data_source %||% "graph", "graph")) {
      "original Graph dataset"
    } else {
      "custom data"
    }

    run_one_anova <- function(dd, split_label = NULL) {
      if (!nrow(dd)) {
        return(c(
          if (!is.null(split_label)) paste0("===== Split: ", split_label, " =====") else NULL,
          "ERROR: この水準には解析対象行がありません。"
        ))
      }

      sid_local <- sid
      if (nzchar(sid_local)) {
        subj <- dd[[sid_local]]
      } else {
        # 完全被験者間計画では各行を独立subjectとして扱う
        subj <- seq_len(nrow(dd))
        sid_local <- ".Subject"
      }

      ad <- data.frame(
        .Subject = subj,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      for (nm in factors) ad[[nm]] <- dd[[nm]]
      ad[[dv]] <- suppressWarnings(as.numeric(dd[[dv]]))
      names(ad)[1] <- sid_local

      duplicate_cell_warning <- NULL
      if (!identical(sid_local, ".Subject")) {
        cell_keys <- c(sid_local, factors)
        ad_complete_keys <- ad[
          stats::complete.cases(ad[, cell_keys, drop = FALSE]),
          , drop = FALSE
        ]
        dup_cells <- ad_complete_keys %>%
          count(across(all_of(cell_keys)), name = ".n_cell") %>%
          filter(.n_cell > 1L)
        if (nrow(dup_cells) > 0L) {
          duplicate_cell_warning <- paste0(
            "WARNING: 同じSubject × 条件に複数行があります（",
            nrow(dup_cells),
            "セル）。trial-levelデータなら必要に応じて個体×条件ごとに1値へ集約してください。"
          )
        }
      }

      actual_levels <- vapply(
        factors,
        function(nm) length(unique(ad[[nm]][!is.na(ad[[nm]])])),
        integer(1)
      )
      expected_levels <- des$levels

      split_header <- if (!is.null(split_label)) {
        c(
          paste0("========================================"),
          paste0("Split: ", split_var, " = ", split_label),
          paste0("========================================")
        )
      } else {
        character(0)
      }

      if (length(actual_levels) != length(expected_levels)) {
        return(c(
          split_header,
          "ERROR: 要因数とデータ割り当てが一致していません。"
        ))
      }

      if (!all(actual_levels == expected_levels)) {
        return(c(
          split_header,
          paste0(
            "ERROR: 指定した水準数と、この分割データ中の実水準数が一致しません。 ",
            "指定: ", paste(expected_levels, collapse = " × "),
            " / 実データ: ", paste(actual_levels, collapse = " × ")
          )
        ))
      }

      if (!any(is.finite(ad[[dv]]))) {
        return(c(
          split_header,
          "ERROR: 従属変数に有効な数値がありません。"
        ))
      }

      warnings_seen <- character()

      txt <- tryCatch(
        withCallingHandlers(
          capture.output({
            do.call(
              get("anovakun", envir = env, inherits = FALSE),
              c(
                list(
                  dataset = ad,
                  design = des$code
                ),
                opts
              )
            )
          }),
          warning = function(w) {
            warnings_seen <<- c(
              warnings_seen,
              paste0("WARNING: ", conditionMessage(w))
            )
            invokeRestart("muffleWarning")
          }
        ),
        error = function(e) paste0("ERROR: ", conditionMessage(e))
      )

      if (length(warnings_seen)) txt <- c(txt, "", warnings_seen)
      if (!length(txt)) txt <- "(no console output)"

      header <- c(
        split_header,
        paste0("Analysis: ", input$stats_name %||% "ANOVA"),
        paste0("Design: ", des$code),
        paste0(
          "Factors: ",
          paste(
            paste0(factors, " (", actual_levels, ")"),
            collapse = " × "
          )
        ),
        paste0("DV: ", dv),
        paste0("Subject / ID: ", sid_local),
        if (!is.null(split_label)) paste0("Split: ", split_var, " = ", split_label) else NULL,
        paste0("alpha: ", alpha),
        paste0("Data: ", data_label),
        paste0(
          "Rows supplied to ANOVA君: ", nrow(ad),
          " / Subjects: ", length(unique(ad[[1]]))
        ),
        if (!is.null(duplicate_cell_warning)) duplicate_cell_warning else NULL,
        "",
        "===== ANOVA君 output ====="
      )

      c(header, txt)
    }

    if (!nzchar(split_var)) {
      return(paste(run_one_anova(d), collapse = "\n"))
    }

    split_values <- unique(as.character(d[[split_var]]))
    split_values <- split_values[!is.na(split_values) & nzchar(split_values)]

    shiny::validate(shiny::need(
      length(split_values) > 0L,
      "分割列に有効な水準がありません。"
    ))

    blocks <- lapply(split_values, function(lv) {
      dd <- d[
        !is.na(d[[split_var]]) & as.character(d[[split_var]]) == lv,
        ,
        drop = FALSE
      ]
      run_one_anova(dd, split_label = lv)
    })

    intro <- c(
      paste0("Analysis: ", input$stats_name %||% "ANOVA"),
      paste0("Split analysis by: ", split_var),
      paste0("Levels: ", paste(split_values, collapse = ", ")),
      paste0(
        "Each level is analyzed independently with the same ",
        length(factors), "-factor ANOVA recipe."
      ),
      ""
    )

    paste(c(intro, unlist(blocks, use.names = FALSE)), collapse = "\n")
  }

  compute_ttest_result <- function() {
    d <- stats_source_data()

    if (identical(input$stats_ttest_type %||% "welch", "paired")) {
      req(input$stats_ttest_x, input$stats_ttest_y)
      shiny::validate(shiny::need(
        !identical(input$stats_ttest_x, input$stats_ttest_y),
        "Paired t検定では変数1と変数2に別の列を指定してください。"
      ))

      x <- suppressWarnings(as.numeric(d[[input$stats_ttest_x]]))
      y <- suppressWarnings(as.numeric(d[[input$stats_ttest_y]]))
      ok <- complete.cases(x, y) & is.finite(x) & is.finite(y)
      x <- x[ok]
      y <- y[ok]

      shiny::validate(shiny::need(length(x) >= 2, "有効な対応データが2組以上必要です。"))

      tt <- t.test(x, y, paired = TRUE)

      paste(
        "Paired t-test",
        "========================================",
        sprintf("%s vs %s", input$stats_ttest_x, input$stats_ttest_y),
        sprintf("n pairs = %d", length(x)),
        sprintf("Mean 1 = %.6g, SD 1 = %.6g", mean(x), sd(x)),
        sprintf("Mean 2 = %.6g, SD 2 = %.6g", mean(y), sd(y)),
        "",
        sprintf("t = %.6g", unname(tt$statistic)),
        sprintf("df = %.6g", unname(tt$parameter)),
        sprintf("p = %.8g", tt$p.value),
        sprintf("95%% CI = [%.6g, %.6g]", tt$conf.int[1], tt$conf.int[2]),
        sep = "\n"
      )

    } else {
      req(input$stats_ttest_group, input$stats_ttest_dv)
      shiny::validate(shiny::need(
        !identical(input$stats_ttest_group, input$stats_ttest_dv),
        "Welch t検定ではGroup列と従属変数に別の列を指定してください。"
      ))

      gcol <- as.character(d[[input$stats_ttest_group]])
      y <- suppressWarnings(as.numeric(d[[input$stats_ttest_dv]]))
      lev <- unique(gcol[!is.na(gcol)])

      shiny::validate(shiny::need(length(lev) == 2,
                                  "Welch t検定ではGroup列が2水準である必要があります。"))

      a <- y[gcol == lev[1]]
      b <- y[gcol == lev[2]]
      a <- a[is.finite(a)]
      b <- b[is.finite(b)]

      shiny::validate(shiny::need(length(a) >= 2 && length(b) >= 2,
                                  "各群に2個以上の有効値が必要です。"))

      tt <- t.test(a, b, var.equal = FALSE)

      paste(
        "Welch two-sample t-test",
        "========================================",
        sprintf("%s: n=%d, Mean=%.6g, SD=%.6g", lev[1], length(a), mean(a), sd(a)),
        sprintf("%s: n=%d, Mean=%.6g, SD=%.6g", lev[2], length(b), mean(b), sd(b)),
        "",
        sprintf("t = %.6g", unname(tt$statistic)),
        sprintf("df = %.6g", unname(tt$parameter)),
        sprintf("p = %.8g", tt$p.value),
        sprintf("95%% CI = [%.6g, %.6g]", tt$conf.int[1], tt$conf.int[2]),
        sep = "\n"
      )
    }
  }

  compute_correlation_result <- function() {
    d <- stats_source_data()
    req(input$stats_cor_x, input$stats_cor_y)

    x_name <- input$stats_cor_x
    y_name <- input$stats_cor_y
    method <- input$stats_cor_method %||% "pearson"
    grp <- input$stats_cor_group %||% ""

    shiny::validate(shiny::need(
      !identical(x_name, y_name),
      "相関分析では X と Y に別の列を指定してください。"
    ))

    format_one_correlation <- function(dd, group_label = NULL) {
      x <- suppressWarnings(as.numeric(dd[[x_name]]))
      y <- suppressWarnings(as.numeric(dd[[y_name]]))
      ok <- complete.cases(x, y) & is.finite(x) & is.finite(y)
      x <- x[ok]
      y <- y[ok]

      if (length(x) < 3L) {
        return(c(
          if (!is.null(group_label)) paste0("Group: ", group_label) else NULL,
          sprintf("n = %d", length(x)),
          "有効なペアが3組未満のため計算できません。"
        ))
      }

      # 定数列ではcor.testが成立しない。
      if (length(unique(x)) < 2L || length(unique(y)) < 2L) {
        return(c(
          if (!is.null(group_label)) paste0("Group: ", group_label) else NULL,
          sprintf("n = %d", length(x)),
          "XまたはYが一定値のため相関を計算できません。"
        ))
      }

      ct <- tryCatch(
        cor.test(x, y, method = method, exact = FALSE),
        error = function(e) e
      )

      if (inherits(ct, "error")) {
        return(c(
          if (!is.null(group_label)) paste0("Group: ", group_label) else NULL,
          sprintf("n = %d", length(x)),
          paste0("ERROR: ", conditionMessage(ct))
        ))
      }

      est <- unname(ct$estimate)
      label <- if (identical(method, "pearson")) "r" else "rho"

      out <- c(
        if (!is.null(group_label)) paste0("Group: ", group_label) else NULL,
        sprintf("n = %d", length(x)),
        sprintf("%s = %.6g", label, est),
        sprintf("p = %.8g", ct$p.value)
      )

      if (!is.null(ct$conf.int)) {
        out <- c(
          out,
          sprintf("95%% CI = [%.6g, %.6g]", ct$conf.int[1], ct$conf.int[2])
        )
      }

      out
    }

    title <- if (identical(method, "pearson")) {
      "Pearson correlation"
    } else {
      "Spearman correlation"
    }

    header <- c(
      title,
      "========================================",
      sprintf("X = %s", x_name),
      sprintf("Y = %s", y_name)
    )

    # Group未指定: 従来通り全体。
    if (!nzchar(grp)) {
      return(paste(
        c(header, "", format_one_correlation(d)),
        collapse = "\n"
      ))
    }

    shiny::validate(shiny::need(
      grp %in% names(d),
      "選択したGroup列がデータにありません。"
    ))
    shiny::validate(shiny::need(
      !grp %in% c(x_name, y_name),
      "Group列は X / Y とは別の列を指定してください。"
    ))

    selected_levels <- input$stats_cor_levels
    shiny::validate(shiny::need(
      !is.null(selected_levels) && length(selected_levels) > 0L,
      "対象群を1つ以上選択してください。"
    ))

    group_vec <- as.character(d[[grp]])
    blocks <- lapply(as.character(selected_levels), function(lv) {
      dd <- d[!is.na(group_vec) & group_vec == lv, , drop = FALSE]
      c(
        "",
        paste0("----- ", lv, " -----"),
        format_one_correlation(dd, group_label = lv)
      )
    })

    paste(
      c(
        header,
        sprintf("Group column = %s", grp),
        unlist(blocks, use.names = FALSE)
      ),
      collapse = "\n"
    )
  }

  stats_plot_preview_payload <- reactive({
    req(identical(input$graph_main_tab, "Statistics"))
    if (isTRUE(graph_state_replay_active())) {
      return(list(status = "switching", svg = "", width = 600, height = 600))
    }
    statistics_plot_preview()
  })

  output$stats_plot_preview <- renderUI({
    preview <- stats_plot_preview_payload()
    if (is.list(preview) && identical(preview$status %||% "", "switching")) {
      return(div(
        class = "statistics-plot-preview-empty",
        "Graphを切り替えています…"
      ))
    }
    if (!is.list(preview) || !nzchar(preview$svg %||% "")) {
      return(div(
        class = "statistics-plot-preview-empty",
        "Plot previewを準備しています…"
      ))
    }

    w <- suppressWarnings(as.numeric(preview$width %||% 600))
    h <- suppressWarnings(as.numeric(preview$height %||% 600))
    if (!is.finite(w) || w <= 0) w <- 600
    if (!is.finite(h) || h <= 0) h <- 600
    diag(
      "STATS-PLOT-PREVIEW",
      paste0(
        "graph=", as.character(preview$id %||% ""),
        " chars=", nchar(preview$svg %||% ""),
        " dims=", round(w, 1), "x", round(h, 1)
      )
    )

    div(
      class = "statistics-plot-preview-stage",
      `data-statistics-graph-id` = as.character(preview$id %||% ""),
      style = sprintf("aspect-ratio: %.8f / 1;", w / h),
      div(
        class = "statistics-plot-preview-svg",
        shiny::HTML(preview$svg)
      )
    )
  })

  stats_auto_result <- reactive({
    id <- stats_selected_id()
    if (is.null(id) || length(id) != 1L || !nzchar(id)) return("")

    # During Graph/recipe replacement return an explicit empty result instead
    # of a req() cancellation. This clears the previous Graph's visible result
    # immediately rather than leaving stale text on screen until recalculation.
    if (isTRUE(graph_state_replay_active())) return("")
    pending_id <- pending_stats_ui_restore()
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return("")

    # Statisticsタブを実際に開いている時だけ計算する。
    if (!identical(input$graph_main_tab, "Statistics")) return("")

    # recipe復元の途中では中途半端な設定で計算しない。
    if (isTRUE(stats_restoring())) return("")

    typ <- input$stats_type %||% "anova"

    if (identical(typ, "anova")) {
      compute_anovakun_result()
    } else if (identical(typ, "ttest")) {
      compute_ttest_result()
    } else if (identical(typ, "correlation")) {
      compute_correlation_result()
    } else {
      ""
    }
  })

  # 入力を連続変更したときの無駄な再計算だけ少し抑える。
  stats_auto_result_debounced <- debounce(stats_auto_result, 180)

  output$stats_result <- renderText({
    txt <- stats_auto_result_debounced()
    diag(
      "STATS-RESULT",
      paste0(
        "type=", input$stats_type %||% "anova",
        " chars=", nchar(txt %||% "")
      )
    )
    txt
  })


  stats_recipes_for_project <- function() {
    rr <- isolate(stats_recipes())
    if (!length(rr)) return(rr)
    if (isTRUE(isolate(graph_state_replay_active()))) return(rr)
    if (isTRUE(isolate(stats_restoring()))) return(rr)

    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return(rr)

    id <- isolate(stats_selected_id())
    if (is.null(id) || !id %in% names(rr)) return(rr)

    captured <- stats_capture_recipe_from_inputs(rr[[id]])
    captured <- normalize_stats_recipe(captured, fallback_name = captured$name %||% "Analysis")

    baseline <- isolate(stats_post_restore_baseline())
    if (is.null(baseline) || !identical(baseline$id, id) || !identical(captured, baseline$recipe)) {
      rr[[id]] <- captured
    }
    rr <- normalize_stats_recipes(rr)
    diag("STATS-SAVE", paste0(
      "recipes=", length(rr),
      " ids={", paste(names(rr), collapse = ","), "}",
      " selected=", id,
      " results_saved=FALSE"
    ))
    rr
  }
