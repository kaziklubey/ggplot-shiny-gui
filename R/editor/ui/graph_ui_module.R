# ============================================================
# Independent Graph module UI
# ============================================================


# Persistent browser-owned slot pool for level-dependent controls.
# The pool DOM is stable: the browser preallocates slots in fixed-size chunks
# and only changes labels/values/visibility.  These controls are intentionally
# not Shiny input bindings; one namespaced event channel carries user edits.
graph_slot_pool_ui <- function(ns, pool_id, kind, empty_text = "", chunk = 50L) {
  tags$div(
    id = ns(paste0(pool_id, "_pool")),
    class = "graph-slot-pool",
    `data-pool-id` = pool_id,
    `data-pool-kind` = kind,
    `data-event-input` = ns("graph_slot_pool_event"),
    `data-chunk-size` = as.integer(chunk),
    `data-empty-text` = empty_text,
    tags$div(class = "graph-slot-pool-empty", empty_text),
    tags$div(class = "graph-slot-pool-slots")
  )
}

graph_svg_viewport_text <- function(svg) {
  svg <- as.character(svg %||% "")
  if (!nzchar(svg) || !grepl("<svg\\b", svg, perl = TRUE)) return(svg)
  # Keep the original viewBox but make scaling deterministic inside the browser
  # viewport.  Width/height are controlled by CSS; preserveAspectRatio prevents
  # stretching and keeps all artwork inside the panel.
  if (!grepl("preserveAspectRatio\\s*=", svg, perl = TRUE, ignore.case = TRUE)) {
    svg <- sub("<svg\\b", "<svg preserveAspectRatio=\"xMidYMid meet\"", svg, perl = TRUE)
  }
  svg
}

graphUI <- function(id, initial_state = NULL, cached_svg = NULL, cached_label = NULL, cached_meta = NULL, profile = c("full", "figure_controls")) {
  editor_profile <- graph_editor_profile(match.arg(profile))
  controls_only <- !graph_editor_profile_has(editor_profile, "full_shell")
  ns <- NS(id)

  cached_meta <- cached_meta %||% list()
  cw <- suppressWarnings(as.numeric(cached_meta$width %||% cached_meta$plot_width_px %||% 600))
  ch <- suppressWarnings(as.numeric(cached_meta$height %||% cached_meta$plot_height_px %||% 600))
  if (!is.finite(cw) || cw <= 0) cw <- 600
  if (!is.finite(ch) || ch <= 0) ch <- 600
  cached_ratio <- cw / ch
  if (!is.finite(cached_ratio) || cached_ratio <= 0) cached_ratio <- 1
  cached_svg_view <- graph_svg_viewport_text(cached_svg)
  # Saved SVG pixel dimensions describe the plot device, not the desired
  # on-screen size.  Keep the preview comfortably inside the browser viewport;
  # the live Shiny plot uses the same visual-height cap in ui.R JavaScript.
  cached_viewport_style <- sprintf(
    paste0(
      "width:min(100%%, 700px, calc(60vh * %.8f));",
      "max-height:min(620px, 60vh);aspect-ratio:%.8f / 1;"
    ),
    cached_ratio, cached_ratio
  )

  # ------------------------------------------------------------------
  # v3.3.55 UI/state separation
  # ------------------------------------------------------------------
  # UI is now a pure view of saved Graph state.  Creating this UI does not
  # create graphServer() and therefore must not run data processing / ggplot.
  # The same DOM is kept when the server is later hydrated, avoiding the
  # former cache-only UI -> second live UI replacement.
  ui_seed <- graph_ui_seed_from_state(initial_state)

  # Canonical UI binding factory owns namespacing and saved-value pre-seeding.
  ui_bindings <- graph_ui_seeded_bindings(ns, ui_seed)
  textInput <- ui_bindings$textInput
  textAreaInput <- ui_bindings$textAreaInput
  selectInput <- ui_bindings$selectInput
  selectizeInput <- ui_bindings$selectizeInput
  checkboxInput <- ui_bindings$checkboxInput
  checkboxGroupInput <- ui_bindings$checkboxGroupInput
  radioButtons <- ui_bindings$radioButtons
  sliderInput <- ui_bindings$sliderInput
  numericInput <- ui_bindings$numericInput
  actionButton <- ui_bindings$actionButton
  downloadButton <- ui_bindings$downloadButton
  fileInput <- ui_bindings$fileInput
  uiOutput <- ui_bindings$uiOutput
  plotOutput <- ui_bindings$plotOutput
  tableOutput <- ui_bindings$tableOutput
  verbatimTextOutput <- ui_bindings$verbatimTextOutput
  colourInput <- ui_bindings$colourInput
  aceEditor <- ui_bindings$aceEditor
  conditionalPanel <- ui_bindings$conditionalPanel

  # Figure Controls have no graph_main_tab DOM. Plot-owned controls therefore
  # render directly instead of depending on a missing Full-Editor tab input.
  plotConditionalPanel <- function(condition, ...) {
    if (isTRUE(controls_only)) return(tagList(...))
    conditionalPanel(condition = condition, ...)
  }

  div(
    class = paste("graph-module", if (controls_only) "graph-module-controls-only" else "graph-module-full"),
    `data-graph-module` = id,
    `data-graph-ui-mode` = editor_profile$name,
    sidebarLayout(
        sidebarPanel(
          width = if (controls_only) 12 else 4,

          plotConditionalPanel(
            condition = "input.graph_main_tab == 'Plot'",
            div(
              class = "section-toolbar",
              tags$button(id = ns("open_all_sections"), type = "button", class = "btn btn-default btn-sm", "全部開く"),
              tags$button(id = ns("close_all_sections"), type = "button", class = "btn btn-default btn-sm", "全部閉じる"),
              if (!controls_only) tagList(
                tags$span(
                  class = "sticky-plot-toolbar-control",
                  checkboxInput(
                    "sticky_plot",
                    "グラフをスクロールに追従",
                    TRUE
                  )
                ),
                tags$span(
                  class = "sticky-plot-toolbar-help",
                  "※ グラフが縦に長すぎて画面内に収まらない場合は、スクロール操作を妨げないよう追従表示は自動的に停止します。"
                )
              )
            )
          ),

          if (graph_editor_profile_has(editor_profile, "statistics")) conditionalPanel(
            condition = "input.graph_main_tab == 'Statistics'",
            div(
              class = "statistics-sidebar-fixed-wrap",
              div(
                class = "statistics-sidebar-reference-wrap",
                div(
                  class = "statistics-sidebar-data-note",
                  tags$b("Statistics data"),
                  tags$br(),
                  tags$small(
                    "検定はPlot Mappingとは独立です。各Analysisは元データから独自のData preparationを適用します。"
                  )
                )
              ),
              div(
                class = "statistics-card statistics-plot-card statistics-sidebar-plot-card",
                h4("Plot"),
                uiOutput("stats_plot_preview")
              ),
              div(
                class = "statistics-analysis-nav statistics-analysis-nav-sidebar",
                selectInput(
                  "stats_selected",
                  NULL,
                  choices = character(0)
                )
              ),
            div(
              class = "statistics-sidebar-analysis-actions",
              actionButton("stats_add", "＋ 新規解析を追加", class = "btn-sm"),
              actionButton("stats_delete", "解析を削除", class = "btn-sm")
            ),
            tags$details(
              class = "statistics-sidebar-analysis-details",
              tags$summary("Analysis settings（検定設定）"),
              div(
                class = "statistics-sidebar-analysis-body",
                    conditionalPanel(
                      condition = "input.stats_selected != null && input.stats_selected != ''",

                      textInput(
                        "stats_name",
                        "Analysis name",
                        value = ""
                      ),

                      selectInput(
                        "stats_type",
                        "Type",
                        choices = c(
                          "ANOVA" = "anova",
                          "t検定" = "ttest",
                          "相関分析" = "correlation"
                        ),
                        selected = "anova"
                      ),

                      radioButtons(
                        "stats_data_source",
                        "Data",
                        choices = c(
                          "このGraphの元データを使う" = "graph",
                          "別データを貼り付ける" = "custom"
                        ),
                        selected = "graph"
                      ),

                      conditionalPanel(
                        condition = "input.stats_data_source == 'custom'",
                        aceEditor(
                          "stats_custom_data",
                          value = "",
                          mode = "text",
                          theme = "chrome",
                          height = "180px"
                        )
                      ),

                      tags$details(
                        class = "control-subsection statistics-data-preparation",
                        open = TRUE,
                        tags$summary("Data preparation"),
                        div(
                          class = "subsection-body",
                          radioButtons(
                            "stats_transform_type",
                            "Analysis input",
                            choices = c(
                              "元データをそのまま使う" = "as_is",
                              "このAnalysisだけWide→Long" = "wide_to_long"
                            ),
                            selected = "as_is"
                          ),
                          conditionalPanel(
                            condition = "input.stats_transform_type == 'wide_to_long'",
                            uiOutput("stats_transform_columns_ui"),
                            checkboxInput(
                              "stats_transform_row_id",
                              "各元行にRowIDを追加",
                              FALSE
                            ),
                            textInput(
                              "stats_transform_names_to",
                              "変換後の要因列名",
                              value = "Condition"
                            ),
                            textInput(
                              "stats_transform_values_to",
                              "変換後の値列名",
                              value = "Value"
                            )
                          ),
                          uiOutput("stats_transform_status"),
                          p(
                            class = "help-block",
                            "この設定はAnalysisごとに保存され、Plot側のWide→Long設定とは連動しません。"
                          )
                        )
                      ),

                      conditionalPanel(
                        condition = "input.stats_type == 'anova'",

                        radioButtons(
                          "stats_factor_n",
                          strong("要因数:"),
                          choices = c(
                            "1要因" = "one",
                            "2要因" = "two",
                            "3要因" = "three"
                          ),
                          selected = "two"
                        ),

                        uiOutput("stats_anova_factor_setup_ui"),

                        radioButtons(
                          "stats_alpha",
                          strong("有意水準:"),
                          choices = c(
                            "0.05" = "0.05",
                            "0.10" = "0.10"
                          ),
                          selected = "0.05"
                        ),

                        tags$details(
                          class = "control-subsection",
                          tags$summary("分散分析の追加オプションを表示"),
                          div(
                            class = "subsection-body",
                            radioButtons(
                              "stats_df_adjust",
                              strong("自由度の調整:"),
                              choices = c(
                                "なし" = "none",
                                "Greenhouse-Geisser" = "gg",
                                "Huynh-Feldt" = "hf"
                              ),
                              selected = "none"
                            ),
                            radioButtons(
                              "stats_multcomp",
                              strong("多重比較法:"),
                              choices = c(
                                "Holm" = "holm",
                                "Shaffer" = "shaffer"
                              ),
                              selected = "holm"
                            )
                          )
                        )
                      ),

                      conditionalPanel(
                        condition = "input.stats_type == 'ttest'",
                        radioButtons(
                          "stats_ttest_type",
                          "t検定",
                          choices = c(
                            "対応なし（Welch）" = "welch",
                            "対応あり" = "paired"
                          ),
                          selected = "welch"
                        ),
                        uiOutput("stats_ttest_mapping_ui")
                      ),

                      conditionalPanel(
                        condition = "input.stats_type == 'correlation'",
                        radioButtons(
                          "stats_cor_method",
                          "方法",
                          choices = c(
                            "Pearson" = "pearson",
                            "Spearman" = "spearman"
                          ),
                          selected = "pearson",
                          inline = TRUE
                        ),
                        uiOutput("stats_cor_mapping_ui")
                      ),

                    )
              )
            )
            )
          ),

          if (graph_editor_profile_has(editor_profile, "editable_data")) conditionalPanel(
            condition = "input.graph_main_tab == 'Plot'",
          tags$details(
            class = "control-section",
            `data-ui-section` = "data",
            tags$summary("1. Data"),
            div(class = "section-body",
          
              p("Excel等から、1行目を列名にしたタブ区切りデータを貼り付けてください。"),
              aceEditor(
                "text",
                value = graph_sample_data_text(),
                mode = "text", theme = "chrome", height = "220px"
              ),
              br(),
              checkboxInput(
                "reshape_wide",
                "複数の測定列を1つの軸にまとめる",
                FALSE
              ),
              p(class = "help-block", "※ Wide形式 → Long形式への変換"),
              conditionalPanel(
                condition = "input.reshape_wide == true",
                checkboxGroupInput(
                  "reshape_columns",
                  "1つの軸にまとめる列",
                  choices = character(0),
                  selected = character(0)
                ),
                uiOutput("reshape_warning_ui"),
                checkboxInput(
                  "reshape_row_id",
                  "各行を1個体として扱う（行番号を個体IDにする）",
                  TRUE
                ),
                p(
                  class = "help-block",
                  "元データに個体ID列がない場合に便利です。変換前の各行へ RowID を付け、Pre/Postなど同じ行から作られた値を同一個体として扱います。"
                ),
                textInput("reshape_x_name", "変換後の横軸列名", value = "Time"),
                textInput("reshape_y_name", "変換後の値列名", value = "Value"),
                p(
                  class = "help-block",
                  "選択した列名（例：Pre, Post）が横軸の水準になります。選択した列の元の並び順を横軸順として使用します。"
                )
              )
            )
          )
          ),

          plotConditionalPanel(
            condition = "input.graph_main_tab == 'Plot'",

          tags$details(
            class = "control-section graph-editor-primary-section",
            `data-ui-section` = "mapping",
            `data-default-open` = "true",
            tags$summary("2. Mapping（変数の割り当て）"),
            div(
              class = "section-body",

              div(
                class = "editor-setting-group editor-setting-group-primary",
                tags$h5("グラフの基本設定"),
                selectInput(
                  "plot_type", "グラフ種類",
                  choices = graph_plot_type_choices(),
                  selected = "line"
                ),
                selectInput("xvar", "X軸", choices = character(0)),
                selectInput("yvar", "Y軸", choices = character(0))
              ),

              div(
                class = "editor-setting-group",
                tags$h5("見分け方（Aesthetic Mapping）"),
                p(
                  class = "help-block",
                  "色・線種・点の形に、どの列を割り当てるかを指定します。見た目そのものは『4. 見た目』で調整します。"
                ),
                div(
                  class = "mapping-aesthetic-stack",
                  div(
                    class = "mapping-aesthetic-card",
                    div(
                      class = "mapping-aesthetic-card-title",
                      tags$span(class = "mapping-aesthetic-name", "色 / 塗り"),
                      tags$span(class = "mapping-aesthetic-term", "Color / Fill")
                    ),
                    selectInput(
                      "colorvar", "分ける変数",
                      choices = c("使わない（固定）" = "")
                    )
                  ),
                  # v3.63.0-editor-shell1: plot-specific Mapping controls are
                  # permanently mounted. conditionalPanel only changes visibility;
                  # the Shiny input bindings survive Graph/plot-type switches.
                  conditionalPanel(
                    condition = "input.plot_type == 'line' || input.plot_type == 'scatter'",
                    div(
                      class = "mapping-aesthetic-card",
                      div(
                        class = "mapping-aesthetic-card-title",
                        tags$span(class = "mapping-aesthetic-name", "線種"),
                        tags$span(class = "mapping-aesthetic-term", "Linetype")
                      ),
                      selectInput(
                        "linetypevar", "分ける変数",
                        choices = c(
                          "色 / 塗りと同じ" = "__color__",
                          "使わない（固定）" = ""
                        ),
                        selected = "__color__"
                      ),
                      conditionalPanel(
                        condition = "input.plot_type == 'scatter'",
                        p(
                          class = "help-block",
                          "散布図では、線種は点を接続する線に使用します。点だけの場合は見た目に影響しません。"
                        )
                      )
                    )
                  ),
                  div(
                    class = "mapping-aesthetic-card",
                    div(
                      class = "mapping-aesthetic-card-title",
                      tags$span(class = "mapping-aesthetic-name", "点の形"),
                      tags$span(class = "mapping-aesthetic-term", "Shape")
                    ),
                    selectInput(
                      "shapevar", "分ける変数",
                      choices = c("色 / 塗りと同じ" = "__color__", "使わない（固定）" = "")
                    )
                  )
                )
              ),

              div(
                class = "editor-setting-group",
                tags$h5("配置・個体・分割"),
                conditionalPanel(
                  condition = "input.plot_type == 'line' || input.plot_type == 'bar' || input.plot_type == 'box'",
                  selectInput(
                    "groupvar", "横ずらし / 横並び要因",
                    choices = c("なし" = ""),
                    selected = ""
                  ),
                  p(
                    class = "help-block",
                    "Lineでは系列を左右へずらす要因、Bar/Boxでは追加の横並び要因として使います。"
                  ),
                  uiOutput("position_mapping_notice_ui"),
                  conditionalPanel(
                    condition = "input.plot_type == 'line'",
                    selectInput(
                      "line_series_mode", "線をつなぐ単位",
                      choices = c(
                        "自動（推奨）" = "auto",
                        "Mappingで系列を分ける" = "mapped",
                        "1本としてつなぐ" = "single",
                        "列を指定" = "column"
                      ),
                      selected = "auto"
                    ),
                    conditionalPanel(
                      condition = "input.line_series_mode == 'column'",
                      selectInput(
                        "line_series_var", "系列を識別する列",
                        choices = c("なし" = ""),
                        selected = ""
                      )
                    ),
                    p(
                      class = "help-block",
                      "自動では、同じX位置に複数水準が共存する要因だけを別系列として扱います。色や点形状がXに沿って変わるだけなら線を分断しません。"
                    )
                  )
                ),
                uiOutput("mapping_diagnostics_ui"),
                selectInput(
                  "idvar", "個体ID",
                  choices = c("なし" = "")
                ),
                p(
                  class = "help-block",
                  "同じ個体をPre/Postなど複数条件で測定した場合に指定します。『IDごとに線で結ぶ』とき、どの点同士が同一個体かを識別します。『各行を1個体として扱う』をONにした場合はRowIDが自動生成されます。"
                ),
                selectInput(
                  "facetvar", "Facet（分割表示）",
                  choices = c("なし" = "")
                )
              ),

              tags$details(
                class = "control-subsection",
                tags$summary("Category order（表示順）"),
                div(
                  class = "subsection-body",
                  p(
                    class = "help-block",
                    "Pre/Postなど、データ内の出現順に依存せず表示順を固定できます。設定ファイルにも保存されます。"
                  ),
                  uiOutput("order_ui")
                )
              )
            )
          ),

          tags$details(
            class = "control-section graph-editor-primary-section",
            `data-ui-section` = "plot",
            `data-default-open` = "true",
            tags$summary("3. 表示内容"),
            div(
              class = "section-body",

              div(
                class = "editor-setting-group",
                tags$h5("集計"),
                conditionalPanel(
                  condition = "input.plot_type == 'line' || input.plot_type == 'bar'",
                  selectInput(
                    "summary_type", "集計方法",
                    choices = c(
                      "値（集計しない）" = "value",
                      "平均" = "mean",
                      "平均 ± SD" = "sd",
                      "平均 ± SEM" = "sem",
                      "平均 ± 95% CI" = "ci95"
                    ),
                    selected = "sem"
                  )
                ),
                conditionalPanel(
                  condition = "input.plot_type == 'box' || ((input.plot_type == 'line' || input.plot_type == 'bar') && input.summary_type != 'value')",
                  radioButtons(
                    "summary_unit",
                    "集計単位",
                    choices = c(
                      "各行を1観測として集計" = "row",
                      "個体IDごとに先に平均してから集計" = "id_mean"
                    ),
                    selected = "row"
                  ),
                  uiOutput("summary_unit_status")
                )
              ),

              div(
                class = "editor-setting-group",
                tags$h5("重ね描き・接続"),
                conditionalPanel(
                  condition = "input.plot_type != 'scatter'",
                  checkboxInput("show_raw", "個体値を重ねる", TRUE)
                ),
                conditionalPanel(
                  condition = "input.plot_type == 'line' || input.plot_type == 'bar'",
                  checkboxInput("connect_id", "IDごとに線で結ぶ", FALSE)
                ),
                conditionalPanel(
                  condition = "input.plot_type == 'line'",
                  selectizeInput(
                    "line_breaks",
                    "接続しないX区間",
                    choices = character(0),
                    selected = character(0),
                    multiple = TRUE,
                    options = list(
                      plugins = list("remove_button"),
                      placeholder = "すべて接続"
                    )
                  ),
                  p(
                    class = "help-block",
                    "指定した隣接X目盛の間だけ線を切ります。点・Error bar・元データは変更しません。ID接続線にも同じ境界を適用します。"
                  )
                ),
                conditionalPanel(
                  condition = "input.plot_type == 'scatter'",
                  radioButtons(
                    "scatter_connect_mode", "点の接続",
                    choices = c(
                      "接続しない" = "none",
                      "個体IDごとに接続" = "id",
                      "データの行順に接続" = "row"
                    ),
                    selected = "none"
                  ),
                  p(
                    class = "help-block",
                    "『データの行順』は、貼り付けた表の上から下へ(x, y)座標を順番に結びます。位置軌跡などに使えます。"
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'scatter'",
                tags$details(
                  class = "control-subsection",
                  tags$summary("回帰直線"),
                  div(
                    class = "subsection-body",
                    checkboxInput("scatter_regression", "回帰直線を表示する", FALSE),
                    conditionalPanel(
                      condition = "input.scatter_regression == true",
                      selectInput(
                        "scatter_regression_group",
                        "回帰線の単位",
                        choices = c(
                          "全データで1本" = "overall",
                          "Color ごと" = "style"
                        ),
                        selected = "overall"
                      ),
                      conditionalPanel(
                        condition = "input.scatter_regression_group == 'overall'",
                        colourInput(
                          "scatter_regression_color",
                          "回帰線の色",
                          value = "#333333",
                          showColour = "both"
                        ),
                        selectInput(
                          "scatter_regression_linetype",
                          "回帰線タイプ",
                          choices = c(
                            "実線" = "solid",
                            "破線" = "dashed",
                            "点線" = "dotted",
                            "一点鎖線" = "dotdash",
                            "長い破線" = "longdash",
                            "二重点線" = "twodash"
                          ),
                          selected = "solid"
                        ),
                        sliderInput(
                          "scatter_regression_width",
                          "回帰線幅",
                          min = 0, max = 3, value = 0.9, step = 0.1
                        )
                      ),
                      conditionalPanel(
                        condition = "input.scatter_regression_group != 'overall'",
                        uiOutput("scatter_regression_style_ui")
                      ),
                      checkboxInput(
                        "scatter_regression_se",
                        "95%信頼区間を表示",
                        TRUE
                      ),
                      conditionalPanel(
                        condition = "input.scatter_regression_se == true",
                        sliderInput(
                          "scatter_regression_se_alpha",
                          "信頼区間の透明度",
                          min = 0, max = 0.60, value = 0.20, step = 0.05
                        )
                      ),
                      p(
                        class = "help-block",
                        "XとYが数値列の場合に、線形回帰（lm）を描画します。Groupごとの回帰線では各線の色・線種・線幅を個別設定できます。"
                      )
                    )
                  )
                )
              )
            )
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "appearance",
            tags$summary("4. 見た目"),
            div(
              class = "section-body",

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("全体 / フォント"),
                div(
                  class = "subsection-body",
                  selectInput(
                    "theme", "Theme",
                    choices = c(
                      "classic" = "classic",
                      "bw" = "bw",
                      "minimal" = "minimal",
                      "gray" = "gray"
                    ),
                    selected = "classic"
                  ),
                  sliderInput(
                    "base_size", "基本フォントサイズ",
                    min = 8, max = 24, value = 13, step = 1
                  ),
                  selectizeInput(
                    "font_family_mode", "フォント",
                    choices = app_font_choices(ui_seed[["font_family_mode"]] %||% "sans"),
                    selected = "sans",
                    options = list(placeholder = "フォント名を検索")
                  ),
                  uiOutput("font_family_warning_ui"),
                  p(class = "help-block", "★はこのPCで検出された代表的な日本語向けフォント候補です（個々の文字の収録までは保証しません）。"),
                  conditionalPanel(
                    condition = "input.font_family_mode == 'custom'",
                    textInput(
                      "font_family_custom", "フォント名",
                      value = "",
                      placeholder = "例: Calibri, Helvetica, Noto Sans JP"
                    ),
                    p(
                      class = "help-block",
                      "実行環境に存在するフォント名を指定してください。shinyapps.ioではローカルPCと利用可能フォントが異なる場合があります。"
                    )
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("Mappingの見た目"),
                div(
                  class = "subsection-body aesthetic-style-stack",
                  tags$details(
                    class = "aesthetic-style-panel",
                    open = TRUE,
                    tags$summary(
                      tags$span(class = "aesthetic-style-title", "色 / 塗り"),
                      tags$span(class = "aesthetic-style-term", "Color / Fill")
                    ),
                    div(
                      class = "aesthetic-style-body",
                      p(class="help-block", "Mapping『色 / 塗り』へ割り当てた各水準の色を設定します。"),
                      graph_slot_pool_ui(ns, "color_style", "color_fill", "Colorに使う列がありません。"),
                      selectInput("palette_preset", "色パレットを一括適用",
                        choices=c("自動 (hue)"="hue","Okabe-Ito (色覚多様性対応)"="okabe_ito","Set2"="set2","Dark2"="dark2"), selected="okabe_ito"),
                      actionButton("apply_palette", "色 / 塗りへパレットを適用"),
                      checkboxInput("series_style_override", "色 / 塗り × 横位置要因ごとに色を上書きする", FALSE),
                      conditionalPanel(
                        condition="input.series_style_override == true",
                        selectInput(
                          "series_palette_preset", "組み合わせ色へパレットを一括適用",
                          choices=c("自動 (hue)"="hue","Okabe-Ito (色覚多様性対応)"="okabe_ito","Set2"="set2","Dark2"="dark2"),
                          selected="okabe_ito"
                        ),
                        actionButton("apply_series_palette", "組み合わせ色へパレットを適用"),
                        p(class="help-block", "一括適用後も、下の各組み合わせ色を個別に変更できます。"),
                        graph_slot_pool_ui(ns, "series_style", "color", "Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。")
                      )
                    )
                  ),
                  tags$details(
                    class = "aesthetic-style-panel",
                    tags$summary(
                      tags$span(class = "aesthetic-style-title", "線種"),
                      tags$span(class = "aesthetic-style-term", "Linetype")
                    ),
                    div(
                      class = "aesthetic-style-body",
                      p(class="help-block", "Mapping『線種』へ割り当てた各水準について、実線・破線などを設定します。"),
                      graph_slot_pool_ui(ns, "linetype_style", "linetype", "Linetypeは固定です。")
                    )
                  ),
                  tags$details(
                    class = "aesthetic-style-panel",
                    tags$summary(
                      tags$span(class = "aesthetic-style-title", "点の形"),
                      tags$span(class = "aesthetic-style-term", "Shape")
                    ),
                    div(
                      class = "aesthetic-style-body",
                      p(class="help-block", "Mapping『点の形』へ割り当てた各水準について、丸・三角などを設定します。"),
                      graph_slot_pool_ui(ns, "shape_style", "shape", "Shapeは固定です。")
                    )
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                tags$summary("固定スタイル（Mappingしない場合）"),
                div(
                  class = "subsection-body",
                  p(
                    class = "help-block",
                    "ColorをMappingしない場合の、代表線・代表点・単色バー/箱の色として使用します。"
                  ),
                  colourInput(
                    "mean_color_mode", "色",
                    value = "#000000",
                    showColour = "both"
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'bar' || input.plot_type == 'box'",
                    checkboxInput(
                      "bar_fill_none_fixed",
                      "Bar / Box：塗りなし",
                      FALSE
                    )
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'line'",
                    selectInput(
                      "mean_linetype", "線タイプ",
                      choices = c(
                        "実線" = "solid",
                        "破線" = "dashed",
                        "点線" = "dotted",
                        "一点鎖線" = "dotdash",
                        "長い破線" = "longdash"
                      ),
                      selected = "solid"
                    ),
                    sliderInput(
                      "line_width", "平均線幅",
                      min = 0, max = 3, value = 0.9, step = 0.1
                    ),
                  ),
                  conditionalPanel(
                    condition = "input.plot_type == 'line' || input.plot_type == 'scatter'",
                    selectInput(
                      "mean_shape", "マーカー形状",
                      choices = c(
                        "● 丸" = 16,
                        "○ 白丸" = 1,
                        "■ 四角" = 15,
                        "▲ 三角" = 17,
                        "◆ ひし形" = 18,
                        "+ プラス" = 3,
                        "× クロス" = 4
                      ),
                      selected = 16
                    ),
                    sliderInput(
                      "point_size", "平均マーカーサイズ",
                      min = 0, max = 8, value = 2.8, step = 0.1
                    ),
                    conditionalPanel(
                      condition = "input.plot_type == 'scatter'",
                      sliderInput(
                        "scatter_point_alpha", "点の透明度",
                        min = 0, max = 1, value = 0.90, step = 0.05
                      )
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'scatter'",
                tags$details(
                  class = "control-subsection",
                  open = TRUE,
                  tags$summary("点の配置"),
                  div(
                    class = "subsection-body scatter-jitter-controls",
                    p(
                      class = "help-block",
                      "Scatterの点の位置だけを調整します。Color・ShapeなどのMappingや固定スタイルとは独立した設定です。"
                    ),
                    checkboxInput("scatter_jitter_enabled", "Jitterで点の重なりを散らす", FALSE),
                    conditionalPanel(
                      condition = "input.scatter_jitter_enabled == true",
                      numericInput(
                        "scatter_jitter_x", "X方向 jitter幅（X軸単位）",
                        value = 0.10, min = 0, step = 0.01
                      ),
                      numericInput(
                        "scatter_jitter_y", "Y方向 jitter幅（Y軸単位）",
                        value = 0, min = 0, step = 0.01
                      ),
                      p(
                        class = "help-block",
                        "Scatterの点だけを決定論的に散らします。個体接続線と回帰直線は元のX/Y座標を使用します。"
                      )
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'line' || input.plot_type == 'bar' || input.plot_type == 'box'",
                tags$details(
                  class = "control-subsection",
                  open = TRUE,
                  tags$summary("配置 / 横ずらし"),
                  div(
                    class = "subsection-body",
                    conditionalPanel(
                      condition = "input.plot_type == 'line'",
                      p(class = "help-block", "横ずらし要因は Mapping の同名項目で指定します。"),
                      sliderInput(
                        "line_group_dodge", "横ずらし幅",
                        min = 0, max = 0.40, value = 0.10, step = 0.01
                      ),
                    ),
                    conditionalPanel(
                      condition = "input.plot_type == 'bar' || input.plot_type == 'box'",
                      p(
                        class = "help-block",
                        "横並びに使う条件はMappingの「追加の横並び要因」で指定します。ここでは配置間隔だけを調整します。"
                      ),
                      sliderInput(
                        "group_spacing", "横並び条件の中心間隔",
                        min = 0, max = 1.60, value = 1.00, step = 0.05
                      )
                    ),
                    conditionalPanel(
                      condition = "input.plot_type == 'box'",
                      sliderInput(
                        "box_width_scale", "箱の太さ",
                        min = 0, max = 3.00, value = 0.72, step = 0.05
                      ),
                      p(
                        class = "help-block",
                        "横並び条件の中心間隔とは独立して、箱そのものの太さだけを調整します。1を超える値では意図的に重ねることもできます。"
                      )
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'bar' || input.plot_type == 'box'",
              tags$details(
                class = "control-subsection",
                tags$summary("Bar / Box の見た目"),
                div(
                  class = "subsection-body",

                  conditionalPanel(
                    condition = "input.plot_type == 'bar'",
                    sliderInput(
                      "bar_width", "バーの太さ",
                      min = 0, max = 3.00, value = 0.82, step = 0.02
                    ),
                    p(
                      class = "help-block",
                      "1を超える値では横slot幅より太くでき、必要なら意図的に隣のバーへ重ねられます。多数条件ではPlot横幅も併用してください。"
                    ),
                    sliderInput(
                      "x_category_spacing", "Xカテゴリ（バーの塊）間隔",
                      min = 0, max = 2.50, value = 1.00, step = 0.05
                    ),
                    checkboxInput(
                      "bar_zero_touch",
                      "Y=0 とバーの底を密着させる",
                      TRUE
                    ),
                    p(
                      class = "help-block",
                      "ONではY軸下端を0にし、0とバーの底の余白をなくします（正の値の棒グラフ向け）。"
                    ),
                    p(
                      class = "help-block",
                      "系列 / Dodge間隔は同じX内のバー同士、Xカテゴリ間隔はX軸上のバーの塊同士の距離です。"
                    )
                  ),

                  conditionalPanel(
                    condition = "input.plot_type == 'bar' || input.plot_type == 'box'",
                    radioButtons(
                      "bar_border_mode", "バー・箱の枠線色",
                      choices = c(
                        "固定色" = "fixed",
                        "塗り色と同じ" = "fill"
                      ),
                      selected = "fixed",
                      inline = TRUE
                    ),
                    conditionalPanel(
                      condition = "input.bar_border_mode == 'fixed'",
                      colourInput(
                        "bar_border_color", "固定色",
                        value = "#000000",
                        showColour = "both"
                      )
                    ),
                    sliderInput(
                      "bar_border_width", "枠線幅",
                      min = 0, max = 2, value = 0.5, step = 0.05
                    ),
                    selectInput(
                      "bar_border_linetype", "枠線種",
                      choices = graph_bar_box_border_linetype_choices(),
                      selected = "solid"
                    ),
                    conditionalPanel(
                      condition = "input.bar_border_linetype == 'custom'",
                      numericInput(
                        "bar_border_dash", "Dash length",
                        value = 4, min = 1, max = 15, step = 1
                      ),
                      numericInput(
                        "bar_border_gap", "Gap length",
                        value = 2, min = 1, max = 15, step = 1
                      ),
                      p(
                        class = "help-block",
                        "Dash / Gap は1〜15。値を大きくすると線・隙間が長くなります。"
                      )
                    )
                  ),

                )
              )
            )              )

          ),

          conditionalPanel(
            condition = "(input.plot_type == 'line' || input.plot_type == 'bar') && (input.summary_type == 'value' || input.summary_type == 'sd' || input.summary_type == 'sem' || input.summary_type == 'ci95')",
            tags$details(
              class = "control-section",
              `data-ui-section` = "error-bars",
              tags$summary("5. Error bar"),
              div(
                class = "section-body",
                conditionalPanel(
                  condition = "input.summary_type == 'value'",
                  radioButtons(
                    "external_error_mode", "計算済みError bar",
                    choices = c(
                      "なし" = "none",
                      "± 誤差列（Y ± Error）" = "symmetric",
                      "下限列・上限列" = "bounds"
                    ),
                    selected = "none"
                  ),
                  conditionalPanel(
                    condition = "input.external_error_mode == 'symmetric'",
                    selectInput(
                      "external_error_col", "誤差列",
                      choices = character(0)
                    ),
                    p(class = "help-block", "Y列は再集計せず、ymin = Y - 誤差列、ymax = Y + 誤差列として描画します。")
                  ),
                  conditionalPanel(
                    condition = "input.external_error_mode == 'bounds'",
                    selectInput(
                      "external_ymin_col", "下限列",
                      choices = character(0)
                    ),
                    selectInput(
                      "external_ymax_col", "上限列",
                      choices = character(0)
                    ),
                    p(class = "help-block", "下限列・上限列をそのままError barのymin / ymaxとして使用します。")
                  )
                ),
                conditionalPanel(
                  condition = "input.summary_type != 'value' || input.external_error_mode != 'none'",
                  selectInput(
                    "error_color_mode", "Error bar の色",
                    choices = c(
                      "Color / Fill と同じ色" = "group",
                      "固定色" = "fixed"
                    ),
                    selected = "fixed"
                  ),
                  conditionalPanel(
                    condition = "input.error_color_mode == 'fixed'",
                    colourInput(
                      "error_color", "固定色",
                      value = "#000000",
                      showColour = "both"
                    )
                  ),
                  sliderInput(
                    "error_width", "Error bar 横幅",
                    min = 0, max = 0.8, value = 0.15, step = 0.05
                  ),
                  sliderInput(
                    "error_line_width", "Error bar 線幅",
                    min = 0, max = 2, value = 0.6, step = 0.05
                  )
                )
              )
            )
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "individual",
            tags$summary("6. 個体データ"),
            div(
              class = "section-body",

              conditionalPanel(
                condition = "input.plot_type != 'scatter'",
                tags$details(
                  class = "control-subsection",
                  open = TRUE,
                  tags$summary("個体点"),
                  div(
                    class = "subsection-body",
                    selectInput(
                      "raw_color_mode", "個体点の色",
                      choices = c(
                        "Colorの色を薄くした色" = "group_light",
                        "Colorの色そのまま" = "group",
                        "系列 / 組み合わせごとに個別指定" = "custom_group",
                        "任意の固定色" = "custom_fixed"
                      ),
                      selected = "group_light"
                    ),
                    conditionalPanel(
                      condition = "input.raw_color_mode == 'group_light'",
                      sliderInput(
                        "raw_lighten",
                        "基本色を白へ混ぜる量",
                        min = 0, max = 0.90, value = 0.45, step = 0.05
                      )
                    ),
                    conditionalPanel(
                      condition = "input.raw_color_mode == 'custom_fixed'",
                      colourInput(
                        "raw_fixed_custom",
                        "個体点の固定色",
                        value = "#555555",
                        showColour = "both"
                      )
                    ),
                    conditionalPanel(
                      condition = "input.raw_color_mode == 'custom_group'",
                      graph_slot_pool_ui(ns, "raw_group_color", "color", "Colorに使う系列がありません。"),
                      selectInput(
                        "raw_palette_preset",
                        "個体点用パレット",
                        choices = c(
                          "Okabe-Ito" = "okabe_ito",
                          "Set2" = "set2",
                          "Dark2" = "dark2",
                          "自動 (hue)" = "hue"
                        ),
                        selected = "okabe_ito"
                      ),
                      actionButton(
                        "apply_raw_palette",
                        "個体点パレットを適用"
                      )
                    ),
                    sliderInput(
                      "raw_alpha",
                      "個体点の不透明度",
                      min = 0, max = 1, value = 0.95, step = 0.05
                    ),
                    selectInput(
                      "raw_shape_mode",
                      "個体点の形状",
                      choices = c(
                        "Shape mappingごとの形状" = "group",
                        "固定形状" = "fixed"
                      ),
                      selected = "group"
                    ),
                    conditionalPanel(
                      condition = "input.raw_shape_mode == 'fixed'",
                      selectInput(
                        "raw_shape", "個体点の固定形状",
                        choices = c(
                          "● 丸" = 16,
                          "○ 白丸" = 1,
                          "■ 四角" = 15,
                          "▲ 三角" = 17,
                          "◆ ひし形" = 18,
                          "+ プラス" = 3,
                          "× クロス" = 4
                        ),
                        selected = 16
                      )
                    ),
                    sliderInput(
                      "raw_point_size",
                      "個体点サイズ",
                      min = 0, max = 6, value = 2.2, step = 0.1
                    ),
                    sliderInput(
                      "jitter_width",
                      "個体点の横方向の散らし幅",
                      min = 0, max = 0.45, value = 0.18, step = 0.01
                    ),
                    p(
                      class = "help-block",
                      "折れ線でも有効です。個体接続線を表示する場合、線は散らした各個体点と同じX位置を通ります。"
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'line' || input.plot_type == 'bar' || input.plot_type == 'scatter'",
                tags$details(
                  class = "control-subsection",
                  tags$summary("個体接続線"),
                  div(
                    class = "subsection-body",
                    selectInput(
                      "id_line_color_mode",
                      "接続線の色",
                      choices = c(
                        "Colorの色を薄くした色" = "group_light",
                        "Colorの色そのまま" = "group",
                        "任意の固定色" = "custom_fixed"
                      ),
                      selected = "group_light"
                    ),
                    conditionalPanel(
                      condition = "input.id_line_color_mode == 'group_light'",
                      sliderInput(
                        "id_line_lighten",
                        "Colorの色を白へ混ぜる量",
                        min = 0, max = 0.90, value = 0.60, step = 0.05
                      )
                    ),
                    conditionalPanel(
                      condition = "input.id_line_color_mode == 'custom_fixed'",
                      colourInput(
                        "id_line_custom_color", "接続線の固定色",
                        value = "#4D4D4D",
                        showColour = "both"
                      )
                    ),
                    selectInput(
                      "id_linetype",
                      "接続線の線種",
                      choices = c(
                        "実線" = "solid",
                        "破線" = "dashed",
                        "点線" = "dotted",
                        "一点鎖線" = "dotdash"
                      ),
                      selected = "solid"
                    ),
                    sliderInput(
                      "id_line_width",
                      "接続線の線幅",
                      min = 0, max = 2, value = 0.45, step = 0.05
                    ),
                    sliderInput(
                      "id_line_alpha",
                      "接続線の不透明度",
                      min = 0, max = 1, value = 0.55, step = 0.05
                    ),
                    checkboxInput(
                      "summary_on_top",
                      "平均線・平均点・エラーバーを個体データより手前に描く",
                      TRUE
                    )
                  )
                )
              )
            )
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "axes-legend",
            tags$summary("7. 軸・Label"),
            div(
              class = "section-body",

              div(
                class = "editor-setting-group",
                tags$h5("タイトル / 表示名"),
                textAreaInput("xlab", "X軸タイトル", "", rows = 2, resize = "vertical"),
                textAreaInput("ylab", "Y軸タイトル", "", rows = 2, resize = "vertical"),
                p(class = "help-block", "Enterで改行できます。文字として入力した \\n も改行として扱います。"),
                textInput("title", "グラフタイトル", ""),
                conditionalPanel(
                  condition = "input.plot_type != 'scatter'",
                  checkboxInput(
                    "x_tick_labels_show",
                    "X軸のカテゴリ名（各グループ名）を表示",
                    TRUE
                  )
                ),
                tags$details(
                  class = "control-subsection",
                  tags$summary("X軸カテゴリ名 / Facet名"),
                  div(
                    class = "subsection-body",
                    p(
                      class = "help-block",
                      "元データは変更せず、Normal / ExpertのようなX軸カテゴリ名やFacet名など、グラフ上の表示名だけを変更します。"
                    ),
                    uiOutput("display_labels_ui")
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("軸サイズ / X目盛間隔"),
                div(
                  class = "subsection-body",
                  conditionalPanel(
                    condition = "input.plot_type == 'line'",
                    sliderInput(
                      "line_x_spacing",
                      "X目盛間の間隔",
                      min = 0, max = 1.00, value = 1.00, step = 0.05
                    ),
                    p(
                      class = "help-block",
                      "折れ線グラフ専用。1.00が標準で、値を小さくすると離散Xの目盛同士を詰めます。"
                    )
                  ),
                  sliderInput(
                    "plot_width_px",
                    "Plot横幅",
                    min = 300, max = 1400, value = 600, step = 25
                  ),
                  numericInput(
                    "plot_width_px_direct",
                    "Plot横幅（数値指定）",
                    value = 600, min = 250, max = 2000, step = 10
                  ),
                  sliderInput(
                    "plot_height_px",
                    "Plot縦幅",
                    min = 220, max = 900, value = 600, step = 20
                  ),
                  numericInput(
                    "plot_height_px_direct",
                    "Plot縦幅（数値指定）",
                    value = 600, min = 180, max = 1400, step = 10
                  ),
                  p(
                    class = "help-block",
                    "スライダーまたは数値入力で指定できます。Plot横幅 / 縦幅は軸に囲まれたプロット領域そのもののサイズです。凡例の表示/非表示や位置を変えても、この領域の大きさは維持されます。"
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                tags$summary("Y軸範囲 / 目盛り / 途中省略"),
                div(
                  class = "subsection-body",
                  fluidRow(
                    column(6, textInput("ymin", "Y最小", value = "")),
                    column(6, textInput("ymax", "Y最大", value = ""))
                  ),
                  checkboxInput(
                    "y_breaks_auto",
                    "Y軸目盛り間隔を自動にする",
                    TRUE
                  ),
                  checkboxInput(
                    "y_top_to_tick",
                    "Y軸上端を最終目盛りに合わせる",
                    TRUE
                  ),
                  conditionalPanel(
                    condition = "!input.y_breaks_auto",
                    numericInput(
                      "y_breaks_step",
                      "Y軸目盛り間隔",
                      value = 1,
                      min = 0.000001,
                      step = 0.1
                    )
                  ),
                  checkboxInput(
                    "y_break_enabled",
                    "Y軸の途中の値域を省略する",
                    FALSE
                  ),
                  conditionalPanel(
                    condition = "input.y_break_enabled == true",
                    fluidRow(
                      column(
                        6,
                        numericInput(
                          "y_break_from",
                          "省略開始",
                          value = 2,
                          step = 1
                        )
                      ),
                      column(
                        6,
                        numericInput(
                          "y_break_to",
                          "省略終了",
                          value = 10,
                          step = 1
                        )
                      )
                    ),
                    sliderInput(
                      "y_break_space",
                      "省略部分の見た目の隙間",
                      min = 0.02, max = 0.30, value = 0.08, step = 0.01
                    ),
                    checkboxInput(
                      "y_break_symbol",
                      "省略位置を記号で示す",
                      TRUE
                    ),
                    p(
                      class = "help-block",
                      "例：2〜10を省略すると、2付近から10付近へ軸がジャンプします。≈ は値域を省略したことを示す目印です。データそのものは削除しません。"
                    )
                  )
                )
              ),

              sliderInput(
                "facet_spacing_x", "Facet間隔（左右）",
                min = 0, max = 1.5, value = 0.12, step = 0.02,
                post = " cm"
              )
            )
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "legend",
            tags$summary("8. 凡例"),
            div(
              class = "section-body",
              selectInput(
                "legend_pos",
                "凡例位置",
                choices = c(
                  "右" = "right",
                  "左" = "left",
                  "上" = "top",
                  "下" = "bottom",
                  "非表示" = "none"
                ),
                selected = "right"
              ),
              tags$div(
                class = "group-style-box legend-control-card",
                tags$b("表示する凡例"),
                checkboxInput(
                  "legend_colour_show",
                  "色",
                  TRUE
                ),
                checkboxInput(
                  "legend_fill_show",
                  "塗り",
                  TRUE
                ),
                checkboxInput(
                  "legend_linetype_show",
                  "線種",
                  TRUE
                ),
                checkboxInput(
                  "legend_shape_show",
                  "点の形",
                  TRUE
                ),
                checkboxInput(
                  "legend_merge_linetype_shape",
                  "同じ変数の線種 + 点の形を1つにまとめる",
                  TRUE
                ),
                selectInput("legend_merge_mode", "同じ変数の凡例", choices = c("自動で統合" = "auto", "別々に表示" = "separate"), selected = "auto"),
                # Hidden compatibility input: preserves the old Color+Shape
                # merge/split preference when loading pre-v3.73.2.40 projects.
                tags$div(
                  style = "display:none;",
                  checkboxInput("legend_merge_colour_shape", "legacy", TRUE)
                )
              ),
              tags$details(
                class = "control-subsection",
                tags$summary("凡例の項目名"),
                div(
                  class = "subsection-body",
                  p(
                    class = "help-block",
                    "凡例に表示する各項目名だけを変更します。X軸やFacetの条件名は変更しません。空欄にすると条件名（表示名）へ戻ります。"
                  ),
                  uiOutput("legend_item_labels_ui")
                )
              ),
              tags$details(
                class = "control-subsection",
                tags$summary("凡例タイトル"),
                div(
                  class = "subsection-body",
                  lapply(c("colour", "fill", "linetype", "shape"), function(aes) {
                    label <- c(colour = "色", fill = "塗り", linetype = "線種", shape = "点の形")[[aes]]
                    tags$div(
                      class = "legend-control-card",
                      tags$b(label),
                      checkboxInput(paste0("legend_", aes, "_title_show"), "タイトルを表示", FALSE),
                      textInput(paste0("legend_", aes, "_title"), "タイトル", ""),
                      selectInput(paste0("legend_", aes, "_order"), "表示順", choices = as.character(1:4), selected = as.character(match(aes, c("colour", "fill", "linetype", "shape"))))
                    )
                  }),
                  tags$div(style = "display:none;",
                    checkboxInput("legend_title_show", "legacy", FALSE),
                    textInput("legend_group_title", "legacy", ""),
                    checkboxInput("legend_individual_title_show", "legacy", FALSE),
                    textInput("legend_individual_title", "legacy", "")
                  ),
                  tags$hr(),
                  selectInput(
                    "legend_wrap_mode", "凡例項目の折り返し",
                    choices = c(
                      "自動" = "auto",
                      "列数を指定" = "ncol",
                      "行数を指定" = "nrow"
                    ),
                    selected = "auto"
                  ),
                  conditionalPanel(
                    condition = "input.legend_wrap_mode != 'auto'",
                    sliderInput(
                      "legend_wrap_count", "列 / 行数",
                      min = 1, max = 12, value = 2, step = 1
                    )
                  ),
                  numericInput(
                    "legend_item_spacing",
                    "凡例項目の間隔（-1 = Theme自動）",
                    value = -1, min = -1, max = 2, step = 0.05
                  ),
                  numericInput(
                    "legend_text_size",
                    "凡例文字サイズ（0 = Theme自動）",
                    value = 0, min = 0, max = 48, step = 0.5
                  )
                )
              ),
              p(
                class = "help-block",
                "各凡例の表示、タイトル、並び順を個別に設定できます。表示/非表示はPlot本体のMappingを変更しません。凡例内の条件順は Mapping → Category order に連動します。同じ変数の凡例は、タイトルが一致すれば自動で統合されます。別々に表示することもできます。"
              ),
              sliderInput(
                "legend_key_width",
                "凡例の線サンプル長",
                min = 0, max = 4.0, value = 1.8, step = 0.1,
                post = " cm"
              )
            )
          ),

          if (graph_editor_profile_has(editor_profile, "shared_style")) tags$details(
            class = "control-section shared-label-style-section",
            `data-ui-section` = "shared-style",
            tags$summary("9. 共通 Label / Style"),
            div(
              class = "section-body",
              p(
                class = "help-block",
                "ProjectのShared Libraryへ、群・条件・軸ラベル・凡例タイトルを明示的に対応付けます。自動bindingは行いません。"
              ),
              uiOutput("shared_style_binding_ui")
            )
          ),

          ),
        ),

        if (graph_editor_profile_has(editor_profile, "full_shell")) mainPanel(
          width = 8,
          div(
            class = "graph-internal-main-tabs",
            tabsetPanel(
            id = ns("graph_main_tab"),
            tabPanel("Plot",
              br(),
              # v3.73.2.18: the Graph workspace owns one fixed persistent live
              # plot anchor. Graph identity is replayed into the same Editor;
              # no cached/live Graph preview stage participates in switching.
              div(
                id = ns("preview_anchor"),
                class = "graph-live-plot-anchor",
                `data-graph-id` = id,
                # v3.73.2.18: the normal Graph workspace owns one permanently
                # mounted live output. Background/source graphUI instances stay
                # output-free and are used only as state/figure materializers.
                if (identical(id, "graph_editor_single")) uiOutput("plot_container")
              )
            ),

            tabPanel(
              "Statistics",
              br(),
              div(
                class = "graph-statistics-header",
                h3("Statistics for this Graph"),
                p(
                  class = "help-block",
                  "このGraphに関連する解析設定を保持します。GraphのMappingと統計の要因計画は独立です。各Analysisは元データ（または別データ）から独自のData preparationを適用し、結果を都度計算します。"
                )
              ),

              div(
                class = "statistics-card statistics-result-card statistics-result-focus",
                h4("Result"),
                uiOutput("stats_link_summary"),
                div(
                  class = "statistics-result-scroll",
                  verbatimTextOutput("stats_result")
                )
              ),


            ),

            tabPanel("Data View",
              br(),
              p(class = "help-block", "現在のPlotへ実際に渡しているデータ（Plot側Wide→Long適用後）を表示します。"),
              uiOutput("data_view_status"),
              tableOutput("data_view")
            ),
          tabPanel(
            "製作者コメント",
            div(
              style = "max-width: 900px; padding: 20px 10px;",
              h3("本アプリケーションについて"),
              p(
                "本アプリケーションは、Rの ",
                tags$code("ggplot2"),
                " をより簡便に利用し、グラフ作成を支援することを目的として作成したものです。"
              ),
              h4("統計解析について"),
              p(
                "分散分析には井関龍太先生の ",
                tags$a(
                  href = "https://riseki.cloudfree.jp/?ANOVA%E5%90%9B",
                  target = "_blank",
                  rel = "noopener noreferrer",
                  "ANOVA君"
                ),
                " を使用しています。"
              ),
              p(
                "t検定および相関分析には、Rの標準関数である ",
                tags$code("stats::t.test()"),
                " および ",
                tags$code("stats::cor.test()"),
                " を使用しています。"
              ),
              p(
                "本アプリケーションは、入力データおよびユーザーが指定した設定に基づいてグラフを生成しますが、",
                "解析内容、図の妥当性、表示内容の正確性を保証するものではありません。"
              ),
              p(
                "論文、学会発表、報告書等に使用する場合は、必ず元データおよび生成された図の内容を利用者自身で確認してください。"
              ),
              p(
                "本アプリケーションの利用により生じた誤り、損失、不利益、その他いかなる損害についても、製作者は責任を負いません。"
              ),
              p(
                strong("本アプリケーションは作図作業の補助ツールとしてご利用ください。")
              )
            )
          )
    )
          )
        ) else mainPanel(
          width = 8,
          style = "display:none !important;",
          selectInput(
            "graph_main_tab",
            NULL,
            choices = c("Plot" = "Plot"),
            selected = "Plot"
          ),
          checkboxInput("sticky_plot", NULL, TRUE)
        )
      )
  )
}
