# ============================================================
# Independent Graph module UI
# ============================================================

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

graphUI <- function(id, initial_state = NULL, cached_svg = NULL, cached_label = NULL, cached_meta = NULL, mode = c("full", "controls")) {
  mode <- match.arg(mode)
  controls_only <- identical(mode, "controls")
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

  div(
    class = paste("graph-module", if (controls_only) "graph-module-controls-only" else "graph-module-full"),
    `data-graph-module` = id,
    `data-graph-ui-mode` = mode,
    sidebarLayout(
        sidebarPanel(
          width = if (controls_only) 12 else 4,

          conditionalPanel(
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

          conditionalPanel(
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

          conditionalPanel(
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

          conditionalPanel(
            condition = "input.graph_main_tab == 'Plot'",

          tags$details(
            class = "control-section",
            `data-ui-section` = "plot",
            tags$summary("2. Plot"),
            div(class = "section-body",
              selectInput(
                "plot_type", "グラフ種類",
                choices = graph_plot_type_choices(),
                selected = "line"
              ),
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
              ),
              conditionalPanel(
                condition = "input.plot_type != 'scatter'",
                checkboxInput("show_raw", "個体値を重ねる", TRUE)
              ),
              conditionalPanel(
                condition = "input.plot_type == 'line' || input.plot_type == 'bar'",
                checkboxInput("connect_id", "IDごとに線で結ぶ", FALSE)
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
                p(class = "help-block",
                  "「データの行順」は、貼り付けた表の上から下へ(x, y)座標を順番に結びます。位置軌跡などに使えます。")
              ),
              conditionalPanel(
                condition = "input.plot_type == 'scatter'",
                tags$hr(),
                tags$b("回帰直線"),
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
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "mapping",
            tags$summary("3. Mapping / Order"),
            div(
              class = "section-body",

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("Mapping"),
                div(
                  class = "subsection-body",
                  selectInput("xvar", "X軸", choices = character(0)),
                  selectInput("yvar", "Y軸", choices = character(0)),
                  tags$hr(),
                  tags$h5("重ね描きの見分け方"),
                  selectInput(
                    "colorvar", "色で分ける",
                    choices = c("使わない（固定）" = "")
                  ),
                  # v3.63.0-editor-shell1: plot-specific Mapping controls are
                  # permanently mounted. conditionalPanel only changes visibility;
                  # the Shiny input bindings survive Graph/plot-type switches.
                  conditionalPanel(
                    condition = "input.plot_type == 'line' || input.plot_type == 'scatter'",
                    selectInput(
                      "linetypevar", "線の種類で分ける",
                      choices = c(
                        "色で分ける要因と同じ" = "__color__",
                        "使わない（固定）" = ""
                      ),
                      selected = "__color__"
                    ),
                    conditionalPanel(
                      condition = "input.plot_type == 'scatter'",
                      p(
                        class = "help-block",
                        "散布図では、Linetypeは点を接続する線に使用します。点だけの場合は見た目に影響しません。"
                      )
                    )
                  ),
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
                    )
                  ),
                  selectInput(
                    "shapevar", "点の形で分ける",
                    choices = c("Color と同じ" = "__color__", "なし（固定）" = "")
                  ),
                  p(
                    class = "help-block",
                    "色・線の種類・点の形には別々の条件列を指定できます。Linetypeは折れ線、および散布図の接続線で使用します。"
                  ),
                  selectInput(
                    "idvar", "個体ID",
                    choices = c("なし" = "")
                  ),
                  p(class = "help-block",
                    "同じ個体をPre/Postなど複数条件で測定した場合に指定します。『IDごとに線で結ぶ』とき、どの点同士が同一個体かを識別します。『各行を1個体として扱う』をONにした場合はRowIDが自動生成されます。"),
                  selectInput(
                    "facetvar", "Facet（分割表示）",
                    choices = c("なし" = "")
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                tags$summary("Category order"),
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
            class = "control-section",
            `data-ui-section` = "appearance",
            tags$summary("4. Appearance"),
            div(
              class = "section-body",

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("Theme / Font"),
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
                tags$summary("色・線種・点形状"),
                div(
                  class = "subsection-body aesthetic-style-stack",
                  tags$details(
                    class = "aesthetic-style-panel",
                    open = TRUE,
                    tags$summary(
                      tags$span(class = "aesthetic-style-title", "色"),
                      tags$span(class = "aesthetic-style-term", "Color")
                    ),
                    div(
                      class = "aesthetic-style-body",
                      p(class="help-block", "Mapping『Colorで分ける』の各水準の色を設定します。"),
                      uiOutput("color_style_ui"),
                      selectInput("palette_preset", "色パレットを一括適用",
                        choices=c("自動 (hue)"="hue","Okabe-Ito (色覚多様性対応)"="okabe_ito","Set2"="set2","Dark2"="dark2"), selected="okabe_ito"),
                      actionButton("apply_palette", "Colorへパレットを適用"),
                      checkboxInput("series_style_override", "Color × 横位置要因ごとに色を上書きする", FALSE),
                      conditionalPanel(condition="input.series_style_override == true", uiOutput("series_style_ui"))
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
                      p(class="help-block", "Mapping『線の種類で分ける』の各水準について、実線・破線などを設定します。"),
                      uiOutput("linetype_style_ui")
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
                      p(class="help-block", "Mapping『点の形で分ける』の各水準について、丸・三角などを設定します。"),
                      uiOutput("shape_style_ui")
                    )
                  )
                )
              ),

              tags$details(
                class = "control-subsection",
                tags$summary("Representative line / point"),
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
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'line' || input.plot_type == 'bar' || input.plot_type == 'box'",
                tags$details(
                  class = "control-subsection",
                  open = TRUE,
                  tags$summary("横位置 / 横ずらし"),
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
                        min = 0, max = 0.95, value = 0.72, step = 0.05
                      ),
                      p(
                        class = "help-block",
                        "横並び条件の中心間隔とは独立して、箱そのものの太さだけを調整します。"
                      )
                    )
                  )
                )
              ),

              conditionalPanel(
                condition = "input.plot_type == 'bar' || input.plot_type == 'box'",
              tags$details(
                class = "control-subsection",
                tags$summary("Plot-specific appearance"),
                div(
                  class = "subsection-body",

                  conditionalPanel(
                    condition = "input.plot_type == 'bar'",
                    sliderInput(
                      "bar_width", "バーの太さ",
                      min = 0, max = 1.00, value = 0.82, step = 0.02
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
              tags$summary("5. Error bars"),
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
                      "Group色" = "group",
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
            tags$summary("6. Individual data"),
            div(
              class = "section-body",

              conditionalPanel(
                condition = "input.plot_type != 'scatter'",
                tags$details(
                  class = "control-subsection",
                  open = TRUE,
                  tags$summary("Point"),
                  div(
                    class = "subsection-body",
                    selectInput(
                      "raw_color_mode", "個体点の色",
                      choices = c(
                        "Colorの色を薄くした色" = "group_light",
                        "Colorの色そのまま" = "group",
                        "水準ごとに個別指定" = "custom_group",
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
                      uiOutput("raw_group_color_ui"),
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
                  tags$summary("Line"),
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
            tags$summary("7. Axes / Legend"),
            div(
              class = "section-body",
              textAreaInput("xlab", "X軸タイトル", "", rows = 2, resize = "vertical"),
              textAreaInput("ylab", "Y軸タイトル", "", rows = 2, resize = "vertical"),
              p(class = "help-block", "Enterで改行できます。文字として入力した \\n も改行として扱います。"),
              textInput("title", "タイトル", ""),

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("軸の長さ / X目盛間隔"),
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
                    "スライダーまたは数値入力で指定できます。Plot横幅 / 縦幅は軸に囲まれたプロット領域そのもののサイズです。凡例の表示/非表示や位置を変えても、この領域の大きさは維持されます。X目盛間隔はカテゴリ同士の距離です。"
                  )
                )
              ),
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
              ),
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
                class = "group-style-box",
                tags$b("凡例の表示"),
                checkboxInput(
                  "legend_colour_show",
                  "色 / 塗り凡例を表示",
                  TRUE
                ),
                checkboxInput(
                  "legend_linetype_show",
                  "線種凡例を表示",
                  TRUE
                ),
                checkboxInput(
                  "legend_shape_show",
                  "点形状凡例を表示",
                  TRUE
                ),
                checkboxInput(
                  "legend_merge_linetype_shape",
                  "同じ変数の線種と点形状を1つの凡例にまとめる",
                  TRUE
                ),
                # Hidden compatibility input: preserves the old Color+Shape
                # merge/split preference when loading pre-v3.73.2.40 projects.
                tags$div(
                  style = "display:none;",
                  checkboxInput("legend_merge_colour_shape", "legacy", TRUE)
                ),
                checkboxInput(
                  "legend_title_show",
                  "色 / 塗り凡例タイトルを表示",
                  FALSE
                ),
                textInput("legend_group_title", "色 / 塗り凡例タイトル", ""),
                checkboxInput("legend_individual_title_show", "線種 / 点形状凡例タイトルを表示", FALSE),
                textInput("legend_individual_title", "線種 / 点形状凡例タイトル", ""),
                p(
                  class = "help-block",
                  "凡例の表示/非表示はPlot本体のMappingを変更しません。線種と点形状が同じ変数を表す場合だけ、上の統合設定で1つの凡例にまとめます。"
                )
              ),
              sliderInput(
                "legend_key_width",
                "凡例の線サンプル長",
                min = 0, max = 4.0, value = 1.8, step = 0.1,
                post = " cm"
              ),
              sliderInput(
                "facet_spacing_x", "Facet間隔（左右）",
                min = 0, max = 1.5, value = 0.12, step = 0.02,
                post = " cm"
              ),
              tags$hr(),
              if (!controls_only) tagList(
                tags$details(
                  class = "control-subsection shared-label-style-subsection",
                  tags$summary("共通Label / Style"),
                  div(
                    class = "subsection-body",
                    p(
                      class = "help-block",
                      "ProjectのShared Libraryへ、群・条件・軸ラベル・凡例タイトルを明示的に対応付けます。自動bindingは行いません。"
                    ),
                    uiOutput("shared_style_binding_ui")
                  )
                ),
                tags$hr()
              ),
              tags$h5("凡例・条件名"),
              p(
                class = "help-block",
                "元データは変更せず、グラフ上の条件名だけを変更します。X軸の条件名やFacet名にも反映されます。凡例タイトルは上の欄で設定します。"
              ),
              uiOutput("display_labels_ui")
            )
          ),

          tags$details(
            class = "control-section",
            `data-ui-section` = "export",
            tags$summary("8. Export"),
            div(
              class = "section-body",
              p(
                "書き出しサイズは現在のPlot横幅・縦幅に連動します。"
              ),
              p(
                class = "help-block",
                "SVG / PDFは本番向けのベクター形式です。PNGは現在のPlotと同じピクセル寸法を基準にした、確認・共有向けの軽量版です。"
              )
            )
          )
          ),
        ),

        if (!controls_only) mainPanel(
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
                class = "graph-global-preview-anchor",
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
