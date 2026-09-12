# ============================================================
# Independent Graph module UI
# ============================================================

graphUI <- function(id) {
  ns <- NS(id)

  # Local wrappers: all Shiny input/output IDs are namespaced automatically.
  textInput <- function(inputId, ...) shiny::textInput(ns(inputId), ...)
  selectInput <- function(inputId, ...) shiny::selectInput(ns(inputId), ...)
  checkboxInput <- function(inputId, ...) shiny::checkboxInput(ns(inputId), ...)
  checkboxGroupInput <- function(inputId, ...) shiny::checkboxGroupInput(ns(inputId), ...)
  radioButtons <- function(inputId, ...) shiny::radioButtons(ns(inputId), ...)
  sliderInput <- function(inputId, ...) shiny::sliderInput(ns(inputId), ...)
  numericInput <- function(inputId, ...) shiny::numericInput(ns(inputId), ...)
  actionButton <- function(inputId, ...) shiny::actionButton(ns(inputId), ...)
  downloadButton <- function(outputId, ...) shiny::downloadButton(ns(outputId), ...)
  fileInput <- function(inputId, ...) shiny::fileInput(ns(inputId), ...)
  uiOutput <- function(outputId, ...) shiny::uiOutput(ns(outputId), ...)
  plotOutput <- function(outputId, ...) shiny::plotOutput(ns(outputId), ...)
  tableOutput <- function(outputId, ...) shiny::tableOutput(ns(outputId), ...)
  verbatimTextOutput <- function(outputId, ...) shiny::verbatimTextOutput(ns(outputId), ...)
  colourInput <- function(inputId, ...) colourpicker::colourInput(ns(inputId), ...)
  aceEditor <- function(outputId, ...) shinyAce::aceEditor(ns(outputId), ...)
  conditionalPanel <- function(condition, ..., ns_unused = NULL) {
    shiny::conditionalPanel(condition = condition, ..., ns = ns)
  }

  div(
    class = "graph-module",
    `data-graph-module` = id,
    sidebarLayout(
        sidebarPanel(
          width = 4,

          conditionalPanel(
            condition = "input.graph_main_tab != 'Statistics'",
            div(
              class = "section-toolbar",
              tags$button(id = ns("open_all_sections"), type = "button", class = "btn btn-default btn-sm", "全部開く"),
              tags$button(id = ns("close_all_sections"), type = "button", class = "btn btn-default btn-sm", "全部閉じる")
            )
          ),

          conditionalPanel(
            condition = "input.graph_main_tab == 'Statistics'",
            div(
              class = "statistics-sidebar-fixed-wrap",
              div(
                class = "statistics-sidebar-reference-wrap",
                div(
                  class = "statistics-sidebar-reference-box",
                  plotOutput(
                    "stats_reference_plot",
                    width = "100%",
                    height = "100%"
                  )
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
                          "このGraphのデータを使う" = "graph",
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
            condition = "input.graph_main_tab != 'Statistics'",
          tags$details(
            class = "control-section",
            tags$summary("1. Data"),
            div(class = "section-body",
          
              p("Excel等から、1行目を列名にしたタブ区切りデータを貼り付けてください。"),
              aceEditor(
                "text",
                value = paste(
                  "ID\tGroup\tPre\tPost",
                  "1\tCTL\t10.2\t13.8",
                  "2\tCTL\t11.4\t14.6",
                  "3\tCTL\t9.8\t13.2",
                  "4\tCTL\t10.9\t14.1",
                  "5\tCTL\t11.8\t15.0",
                  "6\tCTL\t10.5\t13.9",
                  "7\tEXP\t9.4\t11.6",
                  "8\tEXP\t10.1\t12.3",
                  "9\tEXP\t9.7\t11.2",
                  "10\tEXP\t10.4\t12.0",
                  "11\tEXP\t9.9\t11.8",
                  "12\tEXP\t10.6\t12.5",
                  sep = "\n"
                ),
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
                uiOutput("reshape_columns_ui"),
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
            condition = "input.graph_main_tab != 'Statistics'",

          tags$details(
            class = "control-section",
            tags$summary("2. Plot"),
            div(class = "section-body",
              selectInput(
                "plot_type", "グラフ種類",
                choices = c(
                  "折れ線" = "line",
                  "棒" = "bar",
                  "散布図" = "scatter",
                  "箱ひげ" = "box"
                ),
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
            tags$summary("3. Mapping / Order"),
            div(
              class = "section-body",

              tags$details(
                class = "control-subsection",
                open = TRUE,
                tags$summary("Mapping"),
                div(
                  class = "subsection-body",
                  uiOutput("mapping_ui")
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
                  selectInput(
                    "font_family_mode", "フォント",
                    choices = c(
                      "Sans serif（標準）" = "sans",
                      "Serif" = "serif",
                      "Monospace" = "mono",
                      "Arial" = "Arial",
                      "Times New Roman" = "Times New Roman",
                      "Yu Gothic" = "Yu Gothic",
                      "Meiryo" = "Meiryo",
                      "任意のフォント名" = "custom"
                    ),
                    selected = "sans"
                  ),
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
                tags$summary("Color / Linetype / Shape"),
                div(
                  class = "subsection-body",
                  tags$details(
                    open = TRUE,
                    tags$summary("Color"),
                    p(class="help-block", "MappingのColorに使われている変数を、水準ごとに独立して設定します。"),
                    uiOutput("color_style_ui"),
                    selectInput("palette_preset", "色パレットを一括適用",
                      choices=c("自動 (hue)"="hue","Okabe-Ito (色覚多様性対応)"="okabe_ito","Set2"="set2","Dark2"="dark2"), selected="okabe_ito"),
                    actionButton("apply_palette", "Colorへパレットを適用"),
                    checkboxInput("series_style_override", "Color × 横位置要因ごとに色を上書きする", FALSE),
                    conditionalPanel(condition="input.series_style_override == true", uiOutput("series_style_ui"))
                  ),
                  tags$details(
                    tags$summary("Linetype"),
                    p(class="help-block", "Mappingの『線の種類で分ける』に対応します。Colorとは別の変数でも独立設定できます。"),
                    uiOutput("linetype_style_ui")
                  ),
                  tags$details(
                    tags$summary("Shape"),
                    p(class="help-block", "Mappingの『点の形で分ける』に対応します。Color/Linetypeとは別の変数でも独立設定できます。"),
                    uiOutput("shape_style_ui")
                  ),
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
                      uiOutput("position_var_ui"),
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
            tags$summary("7. Axes / Legend"),
            div(
              class = "section-body",
              textInput("xlab", "X軸タイトル", ""),
              textInput("ylab", "Y軸タイトル", ""),
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
                    "スライダーまたは数値入力で指定できます。Plot横幅 / 縦幅はプロット領域そのもののサイズ、X目盛間隔はカテゴリ同士の距離です。"
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
              tags$h5("凡例・条件名"),
              p(
                class = "help-block",
                "元データは変更せず、グラフ上に表示する凡例タイトルや条件名だけを変更します。X軸の条件名やFacet名にも反映されます。"
              ),
              uiOutput("display_labels_ui"),
              checkboxInput(
                "sticky_plot",
                "グラフをスクロールに追従",
                TRUE
              ),
              p(
                class = "help-block",
                "※ グラフが縦に長すぎて画面内に収まらない場合は、スクロール操作を妨げないよう追従表示は自動的に停止します。"
              )
            )
          ),

          tags$details(
            class = "control-section",
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

        mainPanel(
          width = 8,
          tabsetPanel(
            id = ns("graph_main_tab"),
            tabPanel("Plot",
              br(),
              uiOutput("plot_container")
            ),

            tabPanel(
              "Statistics",
              br(),
              div(
                class = "graph-statistics-header",
                h3("Statistics for this Graph"),
                p(
                  class = "help-block",
                  "このGraphに関連する解析設定を保持します。GraphのMappingと統計の要因計画は独立です。結果は現在のデータから都度計算します。"
                )
              ),

              div(
                class = "statistics-analysis-nav",
                selectInput(
                  "stats_selected",
                  NULL,
                  choices = character(0)
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
      )
  )
}


# ============================================================
# Independent Graph module server
# Each module owns its own input/reactive/style/data state.
# ============================================================

graphServer <- function(id, initial_state = NULL, style_clipboard = NULL) {
  moduleServer(id, function(input, output, session) {

  # server.Rからsession単位の共有clipboardを受け取る。
  # 単独利用時にも壊れないようfallbackを持つ。
  if (is.null(style_clipboard) || !is.function(style_clipboard)) {
    style_clipboard <- reactiveVal(NULL)
  }

  # Dynamic UI generated inside moduleServer also needs namespace wrappers.
  textInput <- function(inputId, ...) shiny::textInput(session$ns(inputId), ...)
  selectInput <- function(inputId, ...) shiny::selectInput(session$ns(inputId), ...)
  checkboxInput <- function(inputId, ...) shiny::checkboxInput(session$ns(inputId), ...)
  checkboxGroupInput <- function(inputId, ...) shiny::checkboxGroupInput(session$ns(inputId), ...)
  sliderInput <- function(inputId, ...) shiny::sliderInput(session$ns(inputId), ...)
  numericInput <- function(inputId, ...) shiny::numericInput(session$ns(inputId), ...)
  actionButton <- function(inputId, ...) shiny::actionButton(session$ns(inputId), ...)
  downloadButton <- function(outputId, ...) shiny::downloadButton(session$ns(outputId), ...)
  fileInput <- function(inputId, ...) shiny::fileInput(session$ns(inputId), ...)
  uiOutput <- function(outputId, ...) shiny::uiOutput(session$ns(outputId), ...)
  plotOutput <- function(outputId, ...) shiny::plotOutput(session$ns(outputId), ...)
  tableOutput <- function(outputId, ...) shiny::tableOutput(session$ns(outputId), ...)
  verbatimTextOutput <- function(outputId, ...) shiny::verbatimTextOutput(session$ns(outputId), ...)
  colourInput <- function(inputId, ...) colourpicker::colourInput(session$ns(inputId), ...)


  # ============================================================
  # Helpers
  # ============================================================
  has_selection <- function(x) {
    !is.null(x) && length(x) == 1 && nzchar(x)
  }

  # Shinyの復元途中ではinputがNULL / numeric(0)になることがある。
  # Plot size系では必ず長さ1のfinite numericへ正規化してから使う。
  safe_num1 <- function(x, default = NA_real_) {
    z <- suppressWarnings(as.numeric(x))
    if (!length(z)) return(as.numeric(default)[1])
    z <- z[1]
    if (!is.finite(z)) return(as.numeric(default)[1])
    z
  }

  # Project復元ではPlotサイズを他のAppearanceより先に確定する。
  # initial_stateはjsonlite由来のlist/atomicどちらでも来るためscalar化する。
  restore_size_value <- function(x, default) {
    if (is.null(x)) return(as.numeric(default)[1])
    z <- suppressWarnings(as.numeric(unlist(x, use.names = FALSE)))
    if (!length(z) || !is.finite(z[1])) return(as.numeric(default)[1])
    z[1]
  }

  saved_plot_size_from_state <- function(cfg) {
    a <- NULL
    if (!is.null(cfg) && !is.null(cfg$style)) a <- cfg$style$appearance

    w <- if (!is.null(a)) restore_size_value(a$plot_width_px, 600) else 600
    h <- if (!is.null(a)) restore_size_value(a$plot_height_px, 600) else 600

    list(
      width = max(250, min(2000, w)),
      height = max(180, min(1400, h))
    )
  }

  initial_plot_size_seed <- saved_plot_size_from_state(initial_state)
  plot_width_restore_seed <- reactiveVal(
    if (is.null(initial_state)) NULL else initial_plot_size_seed$width
  )
  plot_height_restore_seed <- reactiveVal(
    if (is.null(initial_state)) NULL else initial_plot_size_seed$height
  )

  parse_order_text <- function(txt) {
    if (is.null(txt) || !nzchar(trimws(txt))) return(character(0))
    vals <- trimws(unlist(strsplit(txt, ",", fixed = TRUE)))
    vals[nzchar(vals)]
  }

  complete_order <- function(existing, observed) {
    observed <- as.character(observed)
    existing <- as.character(existing)
    c(existing[existing %in% observed], setdiff(observed, existing)) |> unique()
  }

  lighten_colour <- function(colour, amount = 0.45) {
    amount <- max(0, min(1, as.numeric(amount)))
    rgb <- grDevices::col2rgb(colour)
    mixed <- round(rgb + (255 - rgb) * amount)
    grDevices::rgb(mixed[1, ], mixed[2, ], mixed[3, ], maxColorValue = 255)
  }

  normalise_colour <- function(colour, fallback = "#000000") {
    z <- as.character(colour %||% fallback)[1]
    if (is.na(z) || !nzchar(z)) z <- fallback
    tryCatch({
      rgb <- grDevices::col2rgb(z)
      grDevices::rgb(rgb[1, 1], rgb[2, 1], rgb[3, 1], maxColorValue = 255)
    }, error = function(e) fallback)
  }

  default_palette <- function(n, preset = "okabe_ito") {
    vals <- switch(
      preset,
      okabe_ito = c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                    "#0072B2", "#D55E00", "#CC79A7", "#000000"),
      set2 = c("#66C2A5", "#FC8D62", "#8DA0CB", "#E78AC3",
               "#A6D854", "#FFD92F", "#E5C494", "#B3B3B3"),
      dark2 = c("#1B9E77", "#D95F02", "#7570B3", "#E7298A",
                "#66A61E", "#E6AB02", "#A6761D", "#666666"),
      scales::hue_pal()(max(n, 1))
    )
    rep(vals, length.out = n)
  }

  default_linetypes <- c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")
  default_shapes <- c(16, 17, 15, 18, 3, 4, 1, 2, 0, 5)

  # Groupの表示順を変えても入力欄が別Groupへずれないよう、Group名由来の固定IDを作る
  style_input_id <- function(prefix, variable_name, level_name = NULL) {
    key <- if (is.null(level_name)) {
      as.character(variable_name)
    } else {
      paste(as.character(variable_name), as.character(level_name), sep = "::")
    }
    raw <- charToRaw(enc2utf8(key))
    paste0(prefix, "_", paste(sprintf("%02x", as.integer(raw)), collapse = ""))
  }

  # Color / Linetype / Shape は変数名ごとに完全分離して保持する。
  # list(variable = list(level = value, ...), ...)
  color_styles <- reactiveVal(list())
  linetype_styles <- reactiveVal(list())
  shape_styles <- reactiveVal(list())

  # Color × 横位置要因の組み合わせ別「色」上書き
  # key: "CTL × Pre" など
  series_styles <- reactiveVal(list())

  # 散布図の回帰線スタイル（回帰グループ名をキーに保存）
  regression_styles <- reactiveVal(list())

  # 個体点の水準別カスタム色
  raw_group_colors <- reactiveVal(list())

  # 変数名ごとのカテゴリ順序を保持
  order_state <- reactiveVal(list(x = list(), group = list(), facet = list()))

  # グラフ表示専用の名称。元データの列名・水準値は変更しない。
  # legend_titles: legend key -> displayed title
  # level_labels: data variable -> original level -> displayed level
  legend_titles <- reactiveVal(list())
  level_labels <- reactiveVal(list())

  legend_title_value <- function(key, default_title) {
    st <- legend_titles()
    z <- st[[key]]
    if (is.null(z) || !length(z) || !nzchar(trimws(as.character(z)[1]))) {
      default_title
    } else {
      as.character(z)[1]
    }
  }

  level_label_values <- function(var_name, levels_now) {
    levels_now <- as.character(levels_now)
    if (!length(levels_now) || !nzchar(var_name)) return(levels_now)

    st <- level_labels()
    branch <- st[[var_name]]
    if (is.null(branch)) branch <- list()

    vapply(
      levels_now,
      function(lv) {
        z <- branch[[lv]]
        if (is.null(z) || !length(z) || !nzchar(trimws(as.character(z)[1]))) lv else as.character(z)[1]
      },
      character(1)
    )
  }

  get_saved_order <- function(kind, var_name, observed) {
    st <- order_state()
    saved <- st[[kind]][[var_name]]
    if (is.null(saved)) saved <- character(0)
    complete_order(saved, observed)
  }

  set_saved_order <- function(kind, var_name, values) {
    st <- isolate(order_state())
    st[[kind]][[var_name]] <- values
    order_state(st)
  }

  ensure_style_branch <- function(kind, variable_name, levels_now) {
    variable_name <- as.character(variable_name %||% "")
    levels_now <- as.character(levels_now)
    if (!nzchar(variable_name) || !length(levels_now)) return(invisible(FALSE))

    rv <- switch(kind,
      color = color_styles,
      linetype = linetype_styles,
      shape = shape_styles
    )
    tree <- isolate(rv())
    branch <- tree[[variable_name]]
    if (is.null(branch)) branch <- list()
    changed <- FALSE

    if (identical(kind, "color")) {
      defaults <- default_palette(length(levels_now), "okabe_ito")
    } else if (identical(kind, "linetype")) {
      defaults <- rep(default_linetypes, length.out = length(levels_now))
    } else {
      defaults <- rep(default_shapes, length.out = length(levels_now))
    }

    for (i in seq_along(levels_now)) {
      lv <- levels_now[i]
      if (is.null(branch[[lv]])) {
        branch[[lv]] <- unname(defaults[i])
        changed <- TRUE
      }
    }
    if (changed) {
      tree[[variable_name]] <- branch
      rv(tree)
    }
    invisible(changed)
  }

  aesthetic_style_vector <- function(kind, variable_name, levels_now) {
    ensure_style_branch(kind, variable_name, levels_now)
    rv <- switch(kind,
      color = color_styles,
      linetype = linetype_styles,
      shape = shape_styles
    )
    branch <- rv()[[variable_name]]
    if (is.null(branch)) branch <- list()
    vals <- vapply(levels_now, function(lv) {
      z <- branch[[lv]]
      if (identical(kind, "color")) as.character(z %||% "#333333")
      else if (identical(kind, "linetype")) as.character(z %||% "solid")
      else as.numeric(z %||% 16)
    }, if (identical(kind, "shape")) numeric(1) else character(1))
    setNames(vals, levels_now)
  }

  color_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("color", variable_name, levels_now)
  }
  linetype_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("linetype", variable_name, levels_now)
  }
  shape_style_vector <- function(variable_name, levels_now) {
    aesthetic_style_vector("shape", variable_name, levels_now)
  }

  migrate_legacy_group_styles <- function(legacy, color_var = "", line_var = "", shape_var = "") {
    if (is.null(legacy) || !length(legacy)) return(invisible(FALSE))
    scalar_chr <- function(x, default) {
      z <- unlist(x, use.names = FALSE)
      if (!length(z)) default else as.character(z[[1]])
    }
    scalar_num <- function(x, default) {
      z <- suppressWarnings(as.numeric(scalar_chr(x, as.character(default))))
      if (!is.finite(z)) default else z
    }

    if (nzchar(color_var)) {
      tree <- isolate(color_styles()); br <- tree[[color_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_chr(legacy[[lv]]$color, "#333333")
      tree[[color_var]] <- br; color_styles(tree)
    }
    if (nzchar(line_var)) {
      tree <- isolate(linetype_styles()); br <- tree[[line_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_chr(legacy[[lv]]$linetype, "solid")
      tree[[line_var]] <- br; linetype_styles(tree)
    }
    if (nzchar(shape_var)) {
      tree <- isolate(shape_styles()); br <- tree[[shape_var]] %||% list()
      for (lv in names(legacy)) br[[lv]] <- scalar_num(legacy[[lv]]$shape, 16)
      tree[[shape_var]] <- br; shape_styles(tree)
    }
    invisible(TRUE)
  }

  series_combo_key <- function(style_level, series_level) {
    paste(style_level, series_level, sep = " × ")
  }

  series_combo_levels <- reactive({
    if (!isTRUE(input$series_style_override)) return(character(0))
    d <- dat()
    g0 <- effective_position_var(d)
    cvar0 <- resolve_color_var(d)
    if (!nzchar(cvar0) || !nzchar(g0) || identical(cvar0, g0)) return(character(0))
    sl0 <- unique(as.character(d[[cvar0]]))
    gl0 <- unique(as.character(d[[g0]]))
    sl0 <- sl0[!is.na(sl0)]
    gl0 <- gl0[!is.na(gl0)]
    as.vector(outer(sl0, gl0, series_combo_key))
  })

  ensure_series_styles <- function(keys_now) {
    if (!length(keys_now)) return()
    d <- dat(); cv <- resolve_color_var(d)
    base_levels <- if (nzchar(cv)) unique(as.character(d[[cv]])) else character(0)
    base_levels <- base_levels[!is.na(base_levels)]
    if (nzchar(cv) && length(base_levels)) ensure_style_branch("color", cv, base_levels)
    base <- if (nzchar(cv)) isolate(color_styles())[[cv]] else list()
    ss <- isolate(series_styles()); changed <- FALSE
    for (key in keys_now) {
      if (is.null(ss[[key]])) {
        parts <- strsplit(key, " × ", fixed = TRUE)[[1]]; style_nm <- parts[1]
        ss[[key]] <- list(color = as.character(base[[style_nm]] %||% "#333333"))
        changed <- TRUE
      }
    }
    if (changed) series_styles(ss)
  }

  series_style_vectors <- function(keys_now) {
    ensure_series_styles(keys_now); ss <- series_styles()
    list(color = setNames(vapply(keys_now, function(k) as.character(ss[[k]]$color %||% "#333333"), character(1)), keys_now))
  }

  # ============================================================
  # Data
  # ============================================================
  raw_dat <- reactive({
    req(input$text)

    # 通常はExcel貼り付けのタブ区切りを最優先。
    x <- tryCatch(
      read.delim(
        text = input$text,
        header = TRUE,
        check.names = FALSE,
        stringsAsFactors = FALSE,
        na.strings = c("", "NA", "NaN")
      ),
      error = function(e) NULL
    )

    # Chat / plain textからコピーするとタブが空白へ変わることがある。
    # タブ読込で1列しか得られなかった場合だけ、任意空白区切りを試す。
    if (is.null(x) || ncol(x) < 2L) {
      x_ws <- tryCatch(
        read.table(
          text = input$text,
          header = TRUE,
          sep = "",
          check.names = FALSE,
          stringsAsFactors = FALSE,
          na.strings = c("", "NA", "NaN"),
          fill = TRUE,
          comment.char = "",
          quote = "\""
        ),
        error = function(e) NULL
      )
      if (!is.null(x_ws) && ncol(x_ws) >= 2L) x <- x_ws
    }

    shiny::validate(shiny::need(
      !is.null(x),
      "データを読み込めませんでした。タブ区切り、または空白区切りか確認してください。"
    ))
    shiny::validate(shiny::need(ncol(x) >= 2, "2列以上のデータが必要です。"))
    x
  })


  # Wide→Long変換エラーはアプリ全体へ伝播させず、
  # 元データへフォールバックして利用者へ表示する。
  reshape_warning <- reactiveVal(NULL)

  set_reshape_warning <- function(msg = NULL) {
    old <- isolate(reshape_warning())
    if (identical(old, msg)) return(invisible(FALSE))
    reshape_warning(msg)
    invisible(TRUE)
  }

  output$reshape_warning_ui <- renderUI({
    msg <- reshape_warning()
    if (is.null(msg) || !nzchar(msg)) return(NULL)

    div(
      class = "alert alert-warning",
      style = "padding:6px 9px; margin-top:6px; margin-bottom:8px;",
      tags$b("Wide→Long変換を停止しました。"),
      tags$br(),
      "元データをそのまま使用しています。",
      tags$br(),
      tags$small(msg)
    )
  })

  output$reshape_columns_ui <- renderUI({
    d0 <- raw_dat()
    req(d0)
    cols <- names(d0)

    numeric_cols <- cols[vapply(d0, is.numeric, logical(1))]
    default_cols <- setdiff(numeric_cols, c("ID", "Id", "id", "Subject", "subject", "SubjectID", "subject_id"))

    common <- cols[tolower(cols) %in% c(
      "pre", "post", "baseline", "test", "followup", "follow_up",
      "day1", "day2", "day3", "day4", "day5"
    )]
    if (length(common) >= 2) default_cols <- common

    # UI再生成時にユーザー/Projectの選択を勝手に初期値へ戻さない
    current_cols <- isolate(input$reshape_columns)
    selected_cols <- if (!is.null(current_cols) && length(current_cols)) {
      keep <- current_cols[current_cols %in% cols]
      if (length(keep)) keep else default_cols
    } else {
      default_cols
    }

    checkboxGroupInput(
      "reshape_columns",
      "1つの軸にまとめる列",
      choices = cols,
      selected = selected_cols
    )
  })

  dat <- reactive({
    d0 <- raw_dat()

    if (!isTRUE(input$reshape_wide)) {
      set_reshape_warning(NULL)
      return(d0)
    }

    cols <- input$reshape_columns

    # Dynamic UI may momentarily have no valid selection while a Project/data
    # source is changing. Do not collapse every downstream output in that gap.
    if (is.null(cols) || length(cols) < 2L) {
      return(d0)
    }

    cols <- as.character(cols)
    cols <- cols[cols %in% names(d0)]
    if (length(cols) < 2L) {
      return(d0)
    }

    xname <- input$reshape_x_name
    yname <- input$reshape_y_name
    if (is.null(xname) || !nzchar(trimws(xname))) xname <- "Time"
    if (is.null(yname) || !nzchar(trimws(yname))) yname <- "Value"
    xname <- trimws(xname)
    yname <- trimws(yname)

    # Invalid output column names are a UI configuration issue rather than a
    # data-frame fatal error; keep raw data visible while the user fixes it.
    if (identical(xname, yname) ||
        xname %in% setdiff(names(d0), cols) ||
        yname %in% setdiff(names(d0), cols)) {
      set_reshape_warning(
        "変換後の列名が既存列と重複しているか、横軸列名と値列名が同じです。"
      )
      return(d0)
    }

    d1 <- d0

    if (isTRUE(input$reshape_row_id)) {
      row_id_name <- "RowID"
      if (row_id_name %in% names(d1)) row_id_name <- ".RowID"
      d1[[row_id_name]] <- seq_len(nrow(d1))
    }

    # Original column order determines the generated X factor order.
    cols <- names(d1)[names(d1) %in% cols]

    out <- tryCatch(
      tidyr::pivot_longer(
        d1,
        cols = dplyr::all_of(cols),
        names_to = xname,
        values_to = yname
      ),
      error = function(e) {
        set_reshape_warning(
          paste0(
            "選択列を1つの値列へ結合できません: ",
            conditionMessage(e),
            "  Long形式のデータなら、この変換は不要です。"
          )
        )
        NULL
      }
    )

    if (is.null(out)) {
      return(d0)
    }

    set_reshape_warning(NULL)
    out[[xname]] <- factor(out[[xname]], levels = cols)
    out
  })

  # Incompatible selected columns (for example integer ID + character Group)
  # mean this is not a valid wide measurement selection. Automatically switch
  # the converter off so Project restore and Mapping can continue on raw data.
  observe({
    msg <- reshape_warning()
    if (is.null(msg) || !nzchar(msg)) return()
    if (!isTRUE(input$reshape_wide)) return()

    if (grepl("結合できません", msg, fixed = TRUE)) {
      updateCheckboxInput(
        session,
        "reshape_wide",
        value = FALSE
      )
    }
  })

  # Project復元時、plot-type依存のdynamic UIが生成される前に
  # 保存済み値を保持しておく。updateSelectInput()のタイミング依存を避ける。
  restore_position_seed <- reactiveVal(NULL)
  restore_linetype_seed <- reactiveVal(NULL)
  # Project restore中、Error bar列のdynamic selectInputが自動候補で
  # 保存値を上書きしないよう一時的に保持するseed。
  restore_external_error_seed <- reactiveVal(NULL)
  restore_external_ymin_seed <- reactiveVal(NULL)
  restore_external_ymax_seed <- reactiveVal(NULL)

  observe({
    seed <- restore_position_seed()
    if (is.null(seed) || !length(seed)) return()
    expected <- as.character(seed)[1]
    actual <- input$groupvar %||% ""
    if (identical(actual, expected)) {
      restore_position_seed(NULL)
    }
  })

  observe({
    seed <- restore_linetype_seed()
    if (is.null(seed) || !length(seed)) return()
    expected <- as.character(seed)[1]
    actual <- input$linetypevar %||% "__color__"
    if (identical(actual, expected)) {
      restore_linetype_seed(NULL)
    }
  })

  output$mapping_ui <- renderUI({
    d <- dat()
    cols <- names(d)
    numeric_cols <- cols[vapply(d, is.numeric, logical(1))]
    shiny::validate(shiny::need(length(numeric_cols) > 0, "数値列が1列以上必要です。"))

    id_candidates <- cols[tolower(cols) %in% c(
      "id", "subject", "subjectid", "subject_id",
      "rat", "ratid", "rat_id", "rowid", ".rowid"
    )]

    default_id <- if ("RowID" %in% cols) {
      "RowID"
    } else if (".RowID" %in% cols) {
      ".RowID"
    } else if ("ID" %in% cols) {
      "ID"
    } else if (length(id_candidates)) {
      id_candidates[1]
    } else ""

    numeric_measure_cols <- setdiff(numeric_cols, id_candidates)
    if (!length(numeric_measure_cols)) numeric_measure_cols <- numeric_cols

    factor_like_names <- c(
      "group", "condition", "cond", "treatment", "route", "phase",
      "block", "day", "trial", "session", "time", "period", "category",
      "factor", "type", "sex"
    )
    value_like_names <- c(
      "value", "mean", "average", "avg", "estimate", "dv", "score", "response",
      "duration", "latency", "time_sec", "distance", "speed", "count", "rate",
      "percent", "percentage", "measure"
    )

    value_named <- numeric_measure_cols[tolower(numeric_measure_cols) %in% value_like_names]
    numeric_dv_candidates <- numeric_measure_cols[
      !tolower(numeric_measure_cols) %in% factor_like_names
    ]

    default_y <- if ("Value" %in% numeric_measure_cols) {
      "Value"
    } else if (length(value_named)) {
      value_named[1]
    } else if (length(numeric_dv_candidates)) {
      # Long-format tables commonly put the DV at the rightmost numeric column.
      numeric_dv_candidates[length(numeric_dv_candidates)]
    } else {
      numeric_measure_cols[length(numeric_measure_cols)]
    }

    non_id_cols <- setdiff(cols, id_candidates)
    named_factor_candidates <- non_id_cols[
      tolower(non_id_cols) %in% factor_like_names & non_id_cols != default_y
    ]
    categorical_candidates <- non_id_cols[
      !vapply(d[non_id_cols], is.numeric, logical(1)) & non_id_cols != default_y
    ]

    default_x <- if ("Time" %in% cols && !identical("Time", default_y)) {
      "Time"
    } else if ("Group" %in% cols && !identical("Group", default_y)) {
      "Group"
    } else if (length(named_factor_candidates)) {
      named_factor_candidates[1]
    } else if (length(categorical_candidates)) {
      categorical_candidates[1]
    } else if (nzchar(default_id) && !identical(default_id, default_y)) {
      default_id
    } else {
      other_cols <- setdiff(cols, default_y)
      if (length(other_cols)) other_cols[1] else cols[1]
    }

    default_series <- if (
      identical(default_x, "Time") &&
      "Group" %in% cols &&
      !identical("Group", default_y)
    ) "Group" else ""

    # A simple one-factor table such as Group | Value starts as X=Group,
    # without redundantly assigning Group to Series/Color as well.
    default_color <- if (nzchar(default_series)) default_series else ""

    # renderUI()が再実行されても、現在の選択が有効なら保持する。
    keep_choice <- function(current, choices, fallback, allow_empty = FALSE) {
      current <- isolate(current)
      if (is.null(current)) return(fallback)
      current <- as.character(current)[1]
      if (allow_empty && identical(current, "")) return("")
      if (nzchar(current) && current %in% choices) return(current)
      fallback
    }

    selected_x <- keep_choice(input$xvar, cols, default_x)
    selected_y <- keep_choice(input$yvar, numeric_cols, default_y)

    # renderUI直後にbrowserのinput bindingが戻る前でもplot_dataが使えるよう、
    # 画面へ出す選択値そのものをlast-valid stateへ先に保存する。
    if (exists("last_valid_xvar", inherits = FALSE)) last_valid_xvar(selected_x)
    if (exists("last_valid_yvar", inherits = FALSE)) last_valid_yvar(selected_y)

    selected_series <- keep_choice(input$groupvar, cols, default_series, allow_empty = TRUE)
    selected_color <- {
      cur <- isolate(input$colorvar)
      if (!is.null(cur) && identical(as.character(cur)[1], "__fixed__")) {
        "__fixed__"
      } else {
        keep_choice(input$colorvar, cols, default_color, allow_empty = TRUE)
      }
    }

    keep_multi_aes_choice <- function(current, fallback = "__color__") {
      current <- isolate(current)
      if (is.null(current) || !length(current)) return(fallback)
      current <- as.character(current)[1]
      if (current %in% c("", "__color__")) return(current)
      if (nzchar(current) && current %in% cols) return(current)
      fallback
    }

    selected_linetype <- keep_multi_aes_choice(input$linetypevar, "__color__")
    selected_shape <- keep_multi_aes_choice(input$shapevar, "__color__")

    selected_id <- keep_choice(input$idvar, cols, default_id, allow_empty = TRUE)
    selected_facet <- keep_choice(input$facetvar, cols, "", allow_empty = TRUE)

    tagList(
      selectInput("xvar", "X軸", choices = cols, selected = selected_x),
      selectInput("yvar", "Y軸", choices = numeric_cols, selected = selected_y),
      tags$hr(),
      tags$h5("重ね描きの見分け方"),
      selectInput(
        "colorvar", "色で分ける",
        choices = c("使わない（固定）" = "", cols),
        selected = if (identical(selected_color, "__fixed__")) "" else selected_color
      ),
      uiOutput("plot_specific_mapping_ui"),
      selectInput(
        "shapevar", "点の形で分ける",
        choices = c("Color と同じ" = "__color__", "なし（固定）" = "", cols),
        selected = selected_shape
      ),
      p(
        class = "help-block",
        "色・線の種類・点の形には別々の条件列を指定できます。Linetypeは折れ線、および散布図の接続線で使用します。"
      ),
      selectInput(
        "idvar", "個体ID",
        choices = c("なし" = "", cols),
        selected = selected_id
      ),
      p(class = "help-block",
        "同じ個体をPre/Postなど複数条件で測定した場合に指定します。『IDごとに線で結ぶ』とき、どの点同士が同一個体かを識別します。『各行を1個体として扱う』をONにした場合はRowIDが自動生成されます。"),
      selectInput("facetvar", "Facet（分割表示）", choices = c("なし" = "", cols), selected = selected_facet)
    )
  })

  output$plot_specific_mapping_ui <- renderUI({
    d <- dat()
    cols <- names(d)
    plot_now <- input$plot_type %||% "line"

    keep_choice_local <- function(current, choices, fallback = "", allow_special = character(0)) {
      current <- isolate(current)
      if (is.null(current) || !length(current)) return(fallback)
      current <- as.character(current)[1]
      if (current %in% allow_special) return(current)
      if (nzchar(current) && current %in% choices) return(current)
      fallback
    }

    color_now <- resolve_color_var(d)
    default_linetype <- if (nzchar(color_now)) "__color__" else ""
    restore_linetype_now <- restore_linetype_seed()
    selected_linetype <- if (
      !is.null(restore_linetype_now) &&
      as.character(restore_linetype_now)[1] %in% c("", "__color__", cols)
    ) {
      as.character(restore_linetype_now)[1]
    } else {
      keep_choice_local(
        input$linetypevar,
        cols,
        default_linetype,
        allow_special = c("", "__color__")
      )
    }

    restore_position_now <- restore_position_seed()
    current_position <- if (
      !is.null(restore_position_now) &&
      nzchar(as.character(restore_position_now)[1]) &&
      as.character(restore_position_now)[1] %in% cols
    ) {
      as.character(restore_position_now)[1]
    } else {
      keep_choice_local(
        input$groupvar,
        cols,
        "",
        allow_special = ""
      )
    }

    if (plot_now %in% c("line", "scatter")) {
      return(tagList(
        selectInput(
          "linetypevar", "線の種類で分ける",
          choices = c(
            "色で分ける要因と同じ" = "__color__",
            "使わない（固定）" = "",
            cols
          ),
          selected = selected_linetype
        ),
        if (identical(plot_now, "scatter")) {
          p(
            class = "help-block",
            "散布図では、Linetypeは点を接続する線に使用します。点だけの場合は見た目に影響しません。"
          )
        }
      ))
    }

    if (plot_now %in% c("bar", "box")) {
      return(tagList(
        selectInput(
          "groupvar", "追加の横並び要因",
          choices = c("なし" = "", cols),
          selected = current_position
        ),
        p(
          class = "help-block",
          "Colorは自動的に横並びへ反映されます。さらに別の条件でも棒・箱を横に分けたい場合に指定します。"
        )
      ))
    }

    NULL
  })

  # 計算済み値をそのまま描画する value モード用Error bar列。
  # 列名はデータ依存のMappingとして扱い、数値列だけを候補にする。
  observe({
    d <- dat()
    numeric_cols <- names(d)[vapply(d, is.numeric, logical(1))]
    if (!length(numeric_cols)) return()

    y_now <- input$yvar %||% ""
    other_numeric <- setdiff(numeric_cols, y_now)
    if (!length(other_numeric)) other_numeric <- numeric_cols

    choose_column <- function(current, preferred_names, fallback_pool, restore_seed = NULL) {
      # Project復元中は保存列を最優先する。dynamic selectInputのbrowser
      # commitより先にこのobserverが走ってもdefault候補へ戻さない。
      seed <- if (is.function(restore_seed)) restore_seed() else NULL
      if (!is.null(seed) && length(seed)) {
        sv <- as.character(seed)[1]
        if (nzchar(sv) && sv %in% numeric_cols) return(sv)
      }

      current <- isolate(current)
      if (!is.null(current) && length(current)) {
        cur <- as.character(current)[1]
        if (nzchar(cur) && cur %in% numeric_cols) return(cur)
      }

      low <- tolower(numeric_cols)
      idx <- match(preferred_names, low, nomatch = 0L)
      idx <- idx[idx > 0L]
      if (length(idx)) return(numeric_cols[idx[1]])
      fallback_pool[1]
    }

    sym_selected <- choose_column(
      input$external_error_col,
      c("sem", "se", "stderr", "std_error", "sd", "error", "err"),
      other_numeric,
      restore_external_error_seed
    )
    low_selected <- choose_column(
      input$external_ymin_col,
      c("ci_low", "ci_lower", "lower", "low", "lwr", "ymin"),
      other_numeric,
      restore_external_ymin_seed
    )
    high_selected <- choose_column(
      input$external_ymax_col,
      c("ci_high", "ci_upper", "upper", "high", "upr", "ymax"),
      other_numeric,
      restore_external_ymax_seed
    )

    updateSelectInput(
      session, "external_error_col",
      choices = numeric_cols,
      selected = sym_selected
    )
    updateSelectInput(
      session, "external_ymin_col",
      choices = numeric_cols,
      selected = low_selected
    )
    updateSelectInput(
      session, "external_ymax_col",
      choices = numeric_cols,
      selected = high_selected
    )
  })

  # 保存値が実inputへ反映されたらseedを解放する。
  # 反映前はseedを維持するため、hidden/lazy Graphでも復元値が失われない。
  observe({
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()
    numeric_cols <- names(d)[vapply(d, is.numeric, logical(1))]

    release_seed <- function(seed_rv, current) {
      seed <- seed_rv()
      if (is.null(seed) || !length(seed)) return(invisible(NULL))
      sv <- as.character(seed)[1]
      cv <- current %||% ""
      if (nzchar(sv) && sv %in% numeric_cols && identical(as.character(cv)[1], sv)) {
        seed_rv(NULL)
      }
      invisible(NULL)
    }

    release_seed(restore_external_error_seed, input$external_error_col)
    release_seed(restore_external_ymin_seed, input$external_ymin_col)
    release_seed(restore_external_ymax_seed, input$external_ymax_col)
  })

  observeEvent(input$plot_type, {
    # Project復元中はtarget plot typeへ切替中なのでseedを保持する。
    if (project_restore_stage() != 0) return()

    pt <- input$plot_type %||% "line"
    if (!pt %in% c("line", "bar", "box")) restore_position_seed(NULL)
    if (!pt %in% c("line", "scatter")) restore_linetype_seed(NULL)
  }, ignoreInit = TRUE)

  output$position_var_ui <- renderUI({
    if (!identical(input$plot_type %||% "line", "line")) return(NULL)

    d <- dat()
    cols <- names(d)
    seed_position <- restore_position_seed()
    current <- if (
      !is.null(seed_position) &&
      nzchar(as.character(seed_position)[1]) &&
      as.character(seed_position)[1] %in% cols
    ) {
      as.character(seed_position)[1]
    } else {
      isolate(input$groupvar %||% "")
    }
    if (!nzchar(current) || !current %in% cols) current <- ""

    tagList(
      selectInput(
        "groupvar", "横ずらし要因",
        choices = c("なし" = "", cols),
        selected = current
      ),
      p(class = "help-block",
        "Color/Linetype/Shapeから線の系列は自動判定します。ここでは左右へずらしたい要因だけを指定します。")
    )
  })

  effective_position_var <- function(d = NULL) {
    plot_now <- input$plot_type %||% "line"
    if (!plot_now %in% c("line", "bar", "box")) return("")
    v <- input$groupvar %||% ""
    if (!has_selection(v)) return("")
    if (!is.null(d) && !v %in% names(d)) return("")
    v
  }

  resolve_color_var <- function(d) {
    mode <- input$colorvar %||% ""
    if (identical(mode, "__fixed__") || !nzchar(mode)) return("")
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  resolve_linetype_var <- function(d) {
    # LinetypeはLine、またはScatterの接続線で使用する。
    if (!(input$plot_type %||% "line") %in% c("line", "scatter")) return("")
    mode <- input$linetypevar %||% "__color__"
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  resolve_shape_var <- function(d) {
    mode <- input$shapevar %||% "__color__"
    if (identical(mode, "__color__")) {
      return(resolve_color_var(d))
    }
    if (has_selection(mode) && mode %in% names(d)) mode else ""
  }

  active_display_label_vars <- reactive({
    d <- dat()
    vars <- c(
      input$xvar %||% "",
      effective_position_var(d),
      resolve_color_var(d),
      resolve_linetype_var(d),
      resolve_shape_var(d),
      input$facetvar %||% ""
    )
    vars <- unique(vars[nzchar(vars) & vars %in% names(d)])

    # Scatterの数値Xはカテゴリ名変更の対象外。
    if (identical(input$plot_type, "scatter") &&
        has_selection(input$xvar) &&
        input$xvar %in% vars) {
      vars <- setdiff(vars, input$xvar)
    }
    vars
  })

  active_legend_specs <- reactive({
    d <- dat()
    cvar0 <- resolve_color_var(d)
    lvar0 <- resolve_linetype_var(d)
    svar0 <- resolve_shape_var(d)
    g0 <- effective_position_var(d)

    combo0 <- isTRUE(input$series_style_override) &&
      nzchar(g0) && nzchar(cvar0) && !identical(g0, cvar0)

    color_key <- if (combo0) paste0("__combo__::", cvar0, "::", g0) else cvar0
    color_default <- if (combo0) paste0(cvar0, " × ", g0) else cvar0

    specs <- list()

    if (nzchar(cvar0)) {
      specs[[color_key]] <- list(
        key = color_key,
        default = color_default,
        used_by = "色"
      )
    }

    line_mode <- input$linetypevar %||% "__color__"
    if (!identical(line_mode, "") && nzchar(lvar0)) {
      k <- if (identical(line_mode, "__color__") && !combo0) color_key else lvar0
      def <- if (identical(line_mode, "__color__") && !combo0) color_default else lvar0
      if (!is.null(specs[[k]])) {
        specs[[k]]$used_by <- paste(specs[[k]]$used_by, "線の種類", sep = "・")
      } else {
        specs[[k]] <- list(key = k, default = def, used_by = "線の種類")
      }
    }

    shape_mode0 <- input$shapevar %||% "__color__"
    if (!identical(shape_mode0, "") && nzchar(svar0)) {
      k <- if (identical(shape_mode0, "__color__") && !combo0) color_key else svar0
      def <- if (identical(shape_mode0, "__color__") && !combo0) color_default else svar0
      if (!is.null(specs[[k]])) {
        specs[[k]]$used_by <- paste(specs[[k]]$used_by, "点の形", sep = "・")
      } else {
        specs[[k]] <- list(key = k, default = def, used_by = "点の形")
      }
    }

    specs
  })

  output$display_labels_ui <- renderUI({
    style_restore_epoch()

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return(NULL)

    specs <- active_legend_specs()
    vars <- active_display_label_vars()

    title_state <- isolate(legend_titles())
    label_state <- isolate(level_labels())

    title_ui <- if (length(specs)) {
      tagList(
        tags$b("凡例タイトル"),
        lapply(specs, function(sp) {
          val <- title_state[[sp$key]]
          if (is.null(val) || !length(val) || !nzchar(as.character(val)[1])) {
            val <- sp$default
          }
          textInput(
            style_input_id("legend_title", sp$key),
            paste0(sp$used_by, "："),
            value = as.character(val)[1]
          )
        })
      )
    } else {
      tags$em("現在のMappingでは編集対象の凡例はありません。")
    }

    var_ui <- lapply(vars, function(v) {
      z <- d[[v]]
      if (is.numeric(z) && identical(v, input$xvar) && identical(input$plot_type, "scatter")) {
        return(NULL)
      }

      observed <- unique(as.character(z))
      observed <- observed[!is.na(observed)]
      if (!length(observed)) return(NULL)

      branch <- label_state[[v]]
      if (is.null(branch)) branch <- list()

      tags$div(
        class = "group-style-box",
        tags$b(paste0(v, " の条件名")),
        lapply(observed, function(lv) {
          val <- branch[[lv]]
          if (is.null(val) || !length(val) || !nzchar(as.character(val)[1])) val <- lv

          fluidRow(
            column(5, tags$div(style = "padding-top:7px;", lv)),
            column(
              7,
              textInput(
                style_input_id("level_label", paste0(v, "::", lv)),
                label = NULL,
                value = as.character(val)[1]
              )
            )
          )
        })
      )
    })

    tagList(
      title_ui,
      tags$hr(),
      tags$b("条件名（表示名）"),
      p(class = "help-block", "左が元データの値、右がグラフに表示する名前です。"),
      var_ui
    )
  })

  observe({
    if (isTRUE(restoring_style_state())) return()

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) return()

    specs <- active_legend_specs()
    vars <- active_display_label_vars()

    ts <- isolate(legend_titles())
    ls <- isolate(level_labels())
    changed_title <- FALSE
    changed_label <- FALSE

    for (sp in specs) {
      id0 <- style_input_id("legend_title", sp$key)
      z <- input[[id0]]
      if (!is.null(z)) {
        z <- as.character(z)[1]
        old <- ts[[sp$key]]
        old <- if (is.null(old)) "" else as.character(old)[1]
        if (!identical(old, z)) {
          ts[[sp$key]] <- z
          changed_title <- TRUE
        }
      }
    }

    for (v in vars) {
      observed <- unique(as.character(d[[v]]))
      observed <- observed[!is.na(observed)]
      if (!length(observed)) next

      branch <- ls[[v]]
      if (is.null(branch)) branch <- list()

      for (lv in observed) {
        id0 <- style_input_id("level_label", paste0(v, "::", lv))
        z <- input[[id0]]
        if (is.null(z)) next
        z <- as.character(z)[1]
        old <- branch[[lv]]
        old <- if (is.null(old)) "" else as.character(old)[1]
        if (!identical(old, z)) {
          branch[[lv]] <- z
          changed_label <- TRUE
        }
      }

      ls[[v]] <- branch
    }

    if (changed_title) legend_titles(ts)
    if (changed_label) level_labels(ls)
  })

  group_levels <- reactive({
    d <- dat()
    v <- effective_position_var(d)
    if (!nzchar(v)) return(character(0))
    observed <- unique(as.character(d[[v]]))
    observed <- observed[!is.na(observed)]
    get_saved_order("group", v, observed)
  })

  style_levels <- reactive({
    d <- dat()
    v <- resolve_color_var(d)
    if (!nzchar(v)) return(character(0))
    observed <- unique(as.character(d[[v]]))
    observed[!is.na(observed)]
  })

  linetype_style_levels <- reactive({
    d <- dat(); v <- resolve_linetype_var(d)
    if (!nzchar(v) || !v %in% names(d)) return(character(0))
    z <- levels(d[[v]]); if (is.null(z) || !length(z)) z <- unique(as.character(d[[v]]))
    z[!is.na(z)]
  })

  shape_style_levels <- reactive({
    d <- dat(); v <- resolve_shape_var(d)
    if (!nzchar(v) || !v %in% names(d)) return(character(0))
    z <- levels(d[[v]]); if (is.null(z) || !length(z)) z <- unique(as.character(d[[v]]))
    z[!is.na(z)]
  })

  x_levels <- reactive({
    d <- dat()
    if (!has_selection(input$xvar) || !input$xvar %in% names(d)) return(character(0))
    observed <- unique(as.character(d[[input$xvar]]))
    observed <- observed[!is.na(observed)]
    get_saved_order("x", input$xvar, observed)
  })

  observe({
    d <- dat()
    cv <- resolve_color_var(d); lv <- resolve_linetype_var(d); sv <- resolve_shape_var(d)
    cl <- style_levels(); ll <- linetype_style_levels(); shl <- shape_style_levels()
    if (nzchar(cv) && length(cl)) ensure_style_branch("color", cv, cl)
    if (nzchar(lv) && length(ll)) ensure_style_branch("linetype", lv, ll)
    if (nzchar(sv) && length(shl)) ensure_style_branch("shape", sv, shl)
  })

  # ============================================================
  # Order UI
  # ============================================================
  output$order_ui <- renderUI({
    d <- dat()
    req(input$xvar)

    xobs <- unique(as.character(d[[input$xvar]]))
    xobs <- xobs[!is.na(xobs)]
    xord <- get_saved_order("x", input$xvar, xobs)

    items <- list(
      tags$div(class = "order-box",
        tags$b(paste0("X軸（", input$xvar, "）の順序")),
        p(class = "help-block", "カンマ区切りで左から表示したい順に指定します。"),
        textInput("x_order_text", NULL, value = paste(xord, collapse = ", ")),
        actionButton("apply_x_order", "X順序を適用", class = "btn-sm")
      )
    )

    g_order_var <- effective_position_var(d)
    if (nzchar(g_order_var)) {
      gobs <- unique(as.character(d[[g_order_var]]))
      gobs <- gobs[!is.na(gobs)]
      gord <- get_saved_order("group", g_order_var, gobs)
      items <- c(items, list(
        tags$div(class = "order-box",
          tags$b(paste0("追加横並び / 横ずらし要因（", g_order_var, "）の順序")),
          p(class = "help-block", "横ずらし・横並び条件の左右順に反映します。"),
          textInput("group_order_text", NULL, value = paste(gord, collapse = ", ")),
          actionButton("apply_group_order", "横位置順序を適用", class = "btn-sm")
        )
      ))
    }

    if (has_selection(input$facetvar) && input$facetvar %in% names(d)) {
      fobs <- unique(as.character(d[[input$facetvar]]))
      fobs <- fobs[!is.na(fobs)]
      ford <- get_saved_order("facet", input$facetvar, fobs)
      items <- c(items, list(
        tags$div(
          class = "order-box",
          tags$b(paste0("Facet（", input$facetvar, "）の順序")),
          p(
            class = "help-block",
            "カンマ区切りで、左上から表示したいFacetの順に指定します。"
          ),
          textInput("facet_order_text", NULL, value = paste(ford, collapse = ", ")),
          actionButton("apply_facet_order", "Facet順序を適用", class = "btn-sm")
        )
      ))
    }

    tagList(items)
  })

  observeEvent(input$apply_x_order, {
    req(input$xvar)
    observed <- unique(as.character(dat()[[input$xvar]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(input$x_order_text)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(paste("データにないX水準を無視しました:", paste(unknown, collapse = ", ")), type = "warning")
    }
    set_saved_order("x", input$xvar, complete_order(requested, observed))
  })

  observeEvent(input$apply_group_order, {
    d <- dat()
    v <- effective_position_var(d)
    req(nzchar(v))
    observed <- unique(as.character(d[[v]]))
    observed <- observed[!is.na(observed)]
    requested <- parse_order_text(input$group_order_text)
    unknown <- setdiff(requested, observed)
    if (length(unknown)) {
      showNotification(paste("データにない横位置水準を無視しました:", paste(unknown, collapse = ", ")), type = "warning")
    }
    set_saved_order("group", v, complete_order(requested, observed))
  })

  observeEvent(input$apply_facet_order, {
    req(input$facetvar)
    d <- dat()
    req(input$facetvar %in% names(d))

    observed <- unique(as.character(d[[input$facetvar]]))
    observed <- observed[!is.na(observed)]

    requested <- parse_order_text(input$facet_order_text)
    unknown <- setdiff(requested, observed)

    if (length(unknown)) {
      showNotification(
        paste("データにないFacet水準を無視しました:", paste(unknown, collapse = ", ")),
        type = "warning"
      )
    }

    set_saved_order(
      "facet",
      input$facetvar,
      complete_order(requested, observed)
    )
  })

  # ============================================================
  # Independent Color / Linetype / Shape appearance editors
  # ============================================================
  output$color_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Colorに使う列がありません。"))
    ensure_style_branch("color", v, lev); br <- isolate(color_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      colourInput(style_input_id("color_colour", v, lv), "色", value = br[[lv]], showColour = "both")
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("color", v, lev)
    tree <- isolate(color_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("color_colour", v, lv)]]
      if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) { br[[lv]] <- val; changed <- TRUE }
    }
    if (changed) { tree[[v]] <- br; color_styles(tree) }
  })

  observeEvent(input$apply_palette, {
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return()
    tree <- isolate(color_styles()); br <- tree[[v]] %||% list(); pal <- default_palette(length(lev), input$palette_preset)
    for (i in seq_along(lev)) br[[lev[i]]] <- pal[i]
    tree[[v]] <- br; color_styles(tree); style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

  output$linetype_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_linetype_var(d); lev <- linetype_style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Linetypeは固定です。"))
    ensure_style_branch("linetype", v, lev); br <- isolate(linetype_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      selectInput(style_input_id("line_type", v, lv), "線タイプ",
        choices = c("実線"="solid","破線"="dashed","点線"="dotted","一点鎖線"="dotdash","長い破線"="longdash","二重点線"="twodash"),
        selected = br[[lv]])
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_linetype_var(d); lev <- linetype_style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("linetype", v, lev)
    tree <- isolate(linetype_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("line_type", v, lv)]]
      if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) { br[[lv]] <- val; changed <- TRUE }
    }
    if (changed) { tree[[v]] <- br; linetype_styles(tree) }
  })

  output$shape_style_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_shape_var(d); lev <- shape_style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Shapeは固定です。"))
    ensure_style_branch("shape", v, lev); br <- isolate(shape_styles())[[v]]
    tagList(lapply(lev, function(lv) tags$div(
      class = "group-style-box", tags$b(lv),
      selectInput(style_input_id("point_shape", v, lv), "点の形",
        choices = c("● 丸"=16,"▲ 三角"=17,"■ 四角"=15,"◆ ひし形"=18,"+ プラス"=3,"× クロス"=4,"○ 白丸"=1,"△ 白三角"=2,"□ 白四角"=0,"◇ 白ひし形"=5),
        selected = as.character(br[[lv]]))
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_shape_var(d); lev <- shape_style_levels()
    if (!nzchar(v) || !length(lev)) return()
    ensure_style_branch("shape", v, lev)
    tree <- isolate(shape_styles()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) {
      val <- input[[style_input_id("point_shape", v, lv)]]
      if (!is.null(val) && nzchar(val)) {
        num <- suppressWarnings(as.numeric(val)); if (is.finite(num) && !identical(as.numeric(br[[lv]]), num)) { br[[lv]] <- num; changed <- TRUE }
      }
    }
    if (changed) { tree[[v]] <- br; shape_styles(tree) }
  })

  # ============================================================
  # Series-specific style overrides
  # ============================================================
  output$series_style_ui <- renderUI({
    style_restore_epoch(); keys <- series_combo_levels()
    if (!isTRUE(input$series_style_override)) return(NULL)
    if (!length(keys)) return(tags$em("Colorと横位置要因に異なる列を選択すると、組み合わせ別の色設定が表示されます。"))
    ensure_series_styles(keys); ss <- isolate(series_styles())
    tagList(lapply(keys, function(key) tags$div(
      class = "group-style-box", tags$b(key),
      colourInput(style_input_id("series_colour", key), "色", value = ss[[key]]$color, showColour = "both")
    )))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    keys <- series_combo_levels(); if (!length(keys)) return(); ensure_series_styles(keys)
    ss <- isolate(series_styles()); changed <- FALSE
    for (key in keys) {
      col <- input[[style_input_id("series_colour", key)]]
      if (!is.null(col) && nzchar(col) && !identical(ss[[key]]$color, col)) { ss[[key]]$color <- col; changed <- TRUE }
    }
    if (changed) series_styles(ss)
  })

  # ============================================================
  # Scatter regression styles

  # ============================================================
  regression_levels <- reactive({
    if (!isTRUE(input$scatter_regression)) return(character(0))
    mode <- input$scatter_regression_group %||% "overall"
    if (identical(mode, "overall")) return(character(0))

    d <- dat()

    if (!identical(mode, "style")) return(character(0))
    v <- resolve_color_var(d)

    if (!nzchar(v)) return(character(0))
    z <- unique(as.character(d[[v]]))
    z[!is.na(z)]
  })

  ensure_regression_styles <- function(levels_now) {
    if (!length(levels_now)) return()

    rs <- isolate(regression_styles())
    changed <- FALSE

    # 現在のColor/Linetype styleを初期値に利用
    d0 <- dat(); cv0 <- resolve_color_var(d0); lv0 <- resolve_linetype_var(d0)
    cbranch <- if (nzchar(cv0)) isolate(color_styles())[[cv0]] else list()
    lbranch <- if (nzchar(lv0)) isolate(linetype_styles())[[lv0]] else list()
    fallback_cols <- default_palette(length(levels_now), "okabe_ito")

    for (i in seq_along(levels_now)) {
      nm <- levels_now[i]
      if (is.null(rs[[nm]])) {
        col0 <- cbranch[[nm]]
        lt0 <- lbranch[[nm]]

        if (is.null(col0) || !length(col0) || is.na(col0[[1]]) || !nzchar(as.character(col0[[1]]))) {
          col0 <- fallback_cols[i]
        } else {
          col0 <- as.character(col0[[1]])
        }

        if (is.null(lt0) || !length(lt0) || is.na(lt0[[1]]) || !nzchar(as.character(lt0[[1]]))) {
          lt0 <- "solid"
        } else {
          lt0 <- as.character(lt0[[1]])
        }

        rs[[nm]] <- list(
          color = col0,
          linetype = lt0,
          width = 0.9
        )
        changed <- TRUE
      }
    }

    if (changed) regression_styles(rs)
  }

  output$scatter_regression_style_ui <- renderUI({
    style_restore_epoch()
    lev <- regression_levels()

    if (!length(lev)) {
      return(tags$em("回帰線を分けるための列をMappingで指定してください。"))
    }

    ensure_regression_styles(lev)
    # 重要: slider操作で regression_styles() が更新されても
    # renderUI自体を再生成しない。これが線幅の「戻る/飛ぶ」を防ぐ。
    rs <- isolate(regression_styles())

    tagList(lapply(lev, function(nm) {
      st <- rs[[nm]]

      tags$div(
        class = "group-style-box",
        tags$b(nm),
        fluidRow(
          column(
            4,
            colourInput(
              style_input_id("reg_colour", nm),
              "線色",
              value = st$color,
              showColour = "both"
            )
          ),
          column(
            4,
            selectInput(
              style_input_id("reg_linetype", nm),
              "線タイプ",
              choices = c(
                "実線" = "solid",
                "破線" = "dashed",
                "点線" = "dotted",
                "一点鎖線" = "dotdash",
                "長い破線" = "longdash",
                "二重点線" = "twodash"
              ),
              selected = st$linetype
            )
          ),
          column(
            4,
            sliderInput(
              style_input_id("reg_width", nm),
              "線幅",
              min = 0, max = 3,
              value = st$width, step = 0.1
            )
          )
        )
      )
    }))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    lev <- regression_levels()
    if (!length(lev)) return()

    ensure_regression_styles(lev)

    rs <- isolate(regression_styles())
    changed <- FALSE

    for (nm in lev) {
      col <- input[[style_input_id("reg_colour", nm)]]
      lt <- input[[style_input_id("reg_linetype", nm)]]
      wd <- input[[style_input_id("reg_width", nm)]]

      if (is.null(rs[[nm]])) next

      if (!is.null(col) && nzchar(col) && !identical(rs[[nm]]$color, col)) {
        rs[[nm]]$color <- col
        changed <- TRUE
      }
      if (!is.null(lt) && nzchar(lt) && !identical(rs[[nm]]$linetype, lt)) {
        rs[[nm]]$linetype <- lt
        changed <- TRUE
      }
      if (!is.null(wd) && is.finite(as.numeric(wd)) &&
          !isTRUE(all.equal(as.numeric(rs[[nm]]$width), as.numeric(wd)))) {
        rs[[nm]]$width <- as.numeric(wd)
        changed <- TRUE
      }
    }

    if (changed) regression_styles(rs)
  })

  # ============================================================
  # 個体点 custom colours
  # ============================================================
  ensure_raw_group_colors <- function(variable_name, levels_now) {
    if (!nzchar(variable_name) || !length(levels_now)) return()
    ensure_style_branch("color", variable_name, levels_now)
    base <- isolate(color_styles())[[variable_name]] %||% list()
    tree <- isolate(raw_group_colors()); br <- tree[[variable_name]] %||% list(); changed <- FALSE
    for (lv in levels_now) if (is.null(br[[lv]])) { br[[lv]] <- lighten_colour(base[[lv]] %||% "#333333", amount = 0.45); changed <- TRUE }
    if (changed) { tree[[variable_name]] <- br; raw_group_colors(tree) }
  }

  output$raw_group_color_ui <- renderUI({
    style_restore_epoch(); d <- dat(); v <- resolve_color_var(d); lev <- style_levels()
    if (!nzchar(v) || !length(lev)) return(tags$em("Colorに使う列がありません。"))
    ensure_raw_group_colors(v, lev); br <- isolate(raw_group_colors())[[v]]
    tagList(lapply(lev, function(lv) tags$div(class="group-style-box", tags$b(lv),
      colourInput(style_input_id("raw_colour", v, lv), "個体点色", value=br[[lv]], showColour="both"))))
  })

  observe({
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels(); if (!nzchar(v) || !length(lev)) return()
    ensure_raw_group_colors(v, lev); tree <- isolate(raw_group_colors()); br <- tree[[v]]; changed <- FALSE
    for (lv in lev) { val <- input[[style_input_id("raw_colour", v, lv)]]; if (!is.null(val) && nzchar(val) && !identical(br[[lv]], val)) { br[[lv]] <- val; changed <- TRUE } }
    if (changed) { tree[[v]] <- br; raw_group_colors(tree) }
  })

  observeEvent(input$apply_raw_palette, {
    if (isTRUE(restoring_style_state())) return()
    d <- dat(); v <- resolve_color_var(d); lev <- style_levels(); if (!nzchar(v) || !length(lev)) return()
    pal <- default_palette(length(lev), input$raw_palette_preset); tree <- isolate(raw_group_colors()); br <- tree[[v]] %||% list()
    for (i in seq_along(lev)) br[[lev[i]]] <- pal[i]
    tree[[v]] <- br; raw_group_colors(tree); style_restore_epoch(isolate(style_restore_epoch()) + 1L)
  })

  # ============================================================
  # Prepared data
  # ============================================================
  last_valid_xvar <- reactiveVal(NULL)
  last_valid_yvar <- reactiveVal(NULL)

  resolved_xvar <- reactive({
    d <- dat()
    z <- input$xvar
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    z <- last_valid_xvar()
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    ""
  })

  resolved_yvar <- reactive({
    d <- dat()
    z <- input$yvar
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    z <- last_valid_yvar()
    if (!is.null(z) && length(z) && z %in% names(d)) return(as.character(z)[1])
    ""
  })

  observe({
    d <- dat()
    xv <- input$xvar
    yv <- input$yvar
    if (!is.null(xv) && length(xv) && xv %in% names(d)) last_valid_xvar(as.character(xv)[1])
    if (!is.null(yv) && length(yv) && yv %in% names(d)) last_valid_yvar(as.character(yv)[1])
  })

  plot_data <- reactive({
    d <- dat()

    x_now <- resolved_xvar()
    y_now <- resolved_yvar()

    shiny::validate(shiny::need(
      !is.null(y_now) && length(y_now) && y_now %in% names(d),
      "Y列を選択してください。"
    ))
    shiny::validate(shiny::need(
      !is.null(x_now) && length(x_now) && x_now %in% names(d),
      "X列を選択してください。"
    ))
    shiny::validate(shiny::need(
      !identical(x_now, y_now),
      "Mappingエラー: X と Y には別の列を指定してください。"
    ))

    # このreactive内では、UI再生成中でも最後の有効Mappingを使う。
    xvar_now <- as.character(x_now)[1]
    yvar_now <- as.character(y_now)[1]

    # 現行GUIでは 横位置要因 / Color / ID / Facet は離散的な割り当て。
    # Yと同じ列を使うと後段でfactor化され、sd()等が失敗するため明示的に止める。
    cvar_guard <- resolve_color_var(d)
    lvar_guard <- resolve_linetype_var(d)
    svar_guard <- resolve_shape_var(d)

    categorical_map <- c(
      effective_position_var(d),
      cvar_guard,
      lvar_guard,
      svar_guard,
      if (has_selection(input$idvar)) input$idvar else "",
      if (has_selection(input$facetvar)) input$facetvar else ""
    )
    categorical_map <- unique(categorical_map[nzchar(categorical_map)])

    shiny::validate(shiny::need(
      !yvar_now %in% categorical_map,
      paste0(
        "Mappingエラー: Y列「", yvar_now,
        "」が 横位置要因 / Color / ID / Facet と重複しています。",
        " Project復元時にこの表示が出た場合はMappingを確認して再保存してください。"
      )
    ))

    d[[yvar_now]] <- suppressWarnings(as.numeric(d[[yvar_now]]))
    d <- d[!is.na(d[[yvar_now]]), , drop = FALSE]
    shiny::validate(shiny::need(nrow(d) > 0, "Y列に数値データがありません。"))

    if (identical(input$plot_type %||% "line", "scatter")) {
      x_num_test <- suppressWarnings(as.numeric(d[[xvar_now]]))
      shiny::validate(shiny::need(
        sum(is.finite(x_num_test)) > 0L,
        "散布図のX軸には数値列を選択してください。"
      ))
    }

    # X軸:
    # 散布図では回帰・相関用に数値Xを保持する。
    # それ以外のカテゴリ型プロットでは設定順をfactor levelへ反映する。
    if (has_selection(xvar_now) && xvar_now %in% names(d)) {
      if (identical(input$plot_type, "scatter")) {
        if (!is.numeric(d[[xvar_now]])) {
          x_chr <- trimws(as.character(d[[xvar_now]]))
          present <- !is.na(x_chr) & nzchar(x_chr)
          x_num <- suppressWarnings(as.numeric(x_chr))

          # Convert character numerics only when every present value converts.
          # Mixed columns such as 1, 2, Control remain categorical instead of
          # silently dropping Control.
          if (any(present) && all(is.finite(x_num[present]))) {
            d[[xvar_now]] <- x_num
          } else {
            obs_x <- unique(x_chr[present])
            d[[xvar_now]] <- factor(x_chr, levels = obs_x)
          }
        }
      } else {
        xl <- get_saved_order("x", xvar_now, unique(as.character(d[[xvar_now]])))
        d[[xvar_now]] <- factor(as.character(d[[xvar_now]]), levels = xl)
      }
    }

    if (has_selection(input$groupvar) && input$groupvar %in% names(d)) {
      observed_group <- unique(as.character(d[[input$groupvar]]))
      observed_group <- observed_group[!is.na(observed_group)]

      gl <- get_saved_order("group", input$groupvar, observed_group)

      # Project復元途中などで保存orderが空・staleでも、
      # 実データの水準へ必ずフォールバックする。
      if (length(gl) == 0L) {
        gl <- observed_group
      } else {
        gl <- c(gl[gl %in% observed_group], setdiff(observed_group, gl))
      }

      d[[input$groupvar]] <- factor(as.character(d[[input$groupvar]]), levels = gl)
    }

    cvar_plot <- resolve_color_var(d)
    if (nzchar(cvar_plot) && cvar_plot %in% names(d)) {
      observed_style <- unique(as.character(d[[cvar_plot]]))
      observed_style <- observed_style[!is.na(observed_style)]

      # If the same variable was already ordered as X or Group, preserve that
      # factor order. A factor that merely came from Wide→Long is not enough to
      # suppress Color's own ordering.
      preserve_color_order <- cvar_plot %in% c(
        xvar_now %||% "",
        if (has_selection(input$groupvar)) input$groupvar else ""
      ) && is.factor(d[[cvar_plot]])
      existing_levels <- if (preserve_color_order) levels(d[[cvar_plot]]) else character(0)
      if (length(existing_levels)) {
        sl <- existing_levels
      } else {
        sl <- style_levels()
        if (length(sl) == 0L) {
          sl <- observed_style
        } else {
          sl <- c(sl[sl %in% observed_style], setdiff(observed_style, sl))
        }
      }

      d[[cvar_plot]] <- factor(as.character(d[[cvar_plot]]), levels = sl)
    }

    # Linetype / Shape がColorとは別の列なら独立factorとして保持する。
    # 同じ列がすでにX/Group/Colorとして明示的に順序付けされた場合だけ保護する。
    extra_aes_vars <- unique(c(resolve_linetype_var(d), resolve_shape_var(d)))
    extra_aes_vars <- extra_aes_vars[nzchar(extra_aes_vars)]
    already_ordered_vars <- unique(c(
      xvar_now %||% "",
      if (has_selection(input$groupvar)) input$groupvar else "",
      cvar_plot
    ))
    for (v in extra_aes_vars) {
      if (!v %in% names(d)) next
      if (identical(v, cvar_plot)) next
      if (v %in% already_ordered_vars && is.factor(d[[v]])) next
      obs <- unique(as.character(d[[v]]))
      obs <- obs[!is.na(obs)]
      d[[v]] <- factor(as.character(d[[v]]), levels = obs)
    }

    # Facetは専用順序を使う。ただし同じ列が先にX/Group/Color/Linetype/Shape
    # として順序付け済みなら、最後にFacetがその順序を壊さない。
    if (has_selection(input$facetvar) && input$facetvar %in% names(d)) {
      facet_prior_role <- input$facetvar %in% unique(c(already_ordered_vars, extra_aes_vars))
      if (!(facet_prior_role && is.factor(d[[input$facetvar]]))) {
        observed_facet <- unique(as.character(d[[input$facetvar]]))
        observed_facet <- observed_facet[!is.na(observed_facet)]

        fl <- get_saved_order("facet", input$facetvar, observed_facet)
        if (length(fl) == 0L) {
          fl <- observed_facet
        } else {
          fl <- c(fl[fl %in% observed_facet], setdiff(observed_facet, fl))
        }

        d[[input$facetvar]] <- factor(
          as.character(d[[input$facetvar]]),
          levels = fl
        )
      }
    }

    d
  })

  # Summaryの条件セルは現在のMappingから自動決定する。
  # 「追加横並び / 横ずらし要因」は必要な場合だけ追加し、Lineでは
  # Color/Linetype/Shapeもtrajectory/summary groupingへ自動的に入る。
  summary_grouping_vars <- reactive({
    d <- plot_data()
    grouping <- resolved_xvar()

    pos_var <- effective_position_var(d)
    if (nzchar(pos_var)) grouping <- c(grouping, pos_var)

    cvar_sum <- resolve_color_var(d)
    if (nzchar(cvar_sum)) grouping <- c(grouping, cvar_sum)

    if (identical(input$plot_type, "line")) {
      lvar_sum <- resolve_linetype_var(d)
      svar_sum <- resolve_shape_var(d)
      if (nzchar(lvar_sum)) grouping <- c(grouping, lvar_sum)
      if (nzchar(svar_sum)) grouping <- c(grouping, svar_sum)
    }

    if (has_selection(input$facetvar)) grouping <- c(grouping, input$facetvar)
    unique(grouping[nzchar(grouping) & grouping %in% names(d)])
  })

  # ID内平均モードでは、各 ID × 条件セル内の複数trialを先に1値へまとめる。
  # これによりSEMのnはtrial数ではなく個体数になる。
  id_mean_data <- reactive({
    d <- plot_data()
    if (!identical(input$summary_unit %||% "row", "id_mean")) return(d)

    idv <- input$idvar %||% ""
    shiny::validate(
      shiny::need(
        has_selection(idv) && idv %in% names(d),
        "「個体IDごとに先に平均」を使うには、Mappingで「個体ID」を指定してください。"
      )
    )

    grouping <- summary_grouping_vars()

    # Bar/BoxのShapeはsummaryを分割しないが、個体点の表示属性として保持する。
    # 同じID×条件セル内でShape水準が複数ある場合は一意に決められないためNAにする。
    shape_var <- resolve_shape_var(d)
    shape_extra <- nzchar(shape_var) && !shape_var %in% grouping && shape_var %in% names(d)

    first_group <- unique(c(idv, grouping))
    out <- d %>%
      group_by(across(all_of(first_group))) %>%
      summarise(
        .id_mean_y__ = mean(.data[[resolved_yvar()]], na.rm = TRUE),
        .groups = "drop"
      )

    if (shape_extra) {
      shape_lookup <- d %>%
        group_by(across(all_of(first_group))) %>%
        summarise(
          .shape_value__ = {
            z <- as.character(.data[[shape_var]])
            z <- unique(z[!is.na(z)])
            if (length(z) == 1L) z[[1]] else NA_character_
          },
          .groups = "drop"
        )
      names(shape_lookup)[names(shape_lookup) == ".shape_value__"] <- shape_var
      out <- left_join(out, shape_lookup, by = first_group)
      original_levels <- levels(d[[shape_var]])
      if (!is.null(original_levels) && length(original_levels)) {
        out[[shape_var]] <- factor(out[[shape_var]], levels = original_levels)
      }
    }

    out
  })

  # Raw point / ID lineも、ID内平均モードではtrial値ではなく個体平均値を描く。
  display_observation_data <- reactive({
    if (!identical(input$summary_unit %||% "row", "id_mean")) return(plot_data())
    d <- id_mean_data()
    d[[resolved_yvar()]] <- d$.id_mean_y__
    d$.id_mean_y__ <- NULL
    d
  })

  summary_data <- reactive({
    d <- id_mean_data()
    grouping <- summary_grouping_vars()
    y_source <- if (identical(input$summary_unit %||% "row", "id_mean")) {
      ".id_mean_y__"
    } else {
      resolved_yvar()
    }

    d %>%
      group_by(across(all_of(grouping))) %>%
      summarise(
        n = sum(!is.na(.data[[y_source]])),
        mean = mean(.data[[y_source]], na.rm = TRUE),
        sd = stats::sd(.data[[y_source]], na.rm = TRUE),
        sem = sd / sqrt(n),
        ci95 = ifelse(n > 1, stats::qt(0.975, df = n - 1) * sem, NA_real_),
        .groups = "drop"
      )
  })

  # Line/Bar の「値（集計しない）」は入力行をそのまま描画する。
  # summary_unit や ID 内平均はこのモードでは一切適用しない。
  direct_value_mode <- reactive({
    identical(input$summary_type %||% "mean", "value") &&
      (input$plot_type %||% "line") %in% c("line", "bar")
  })

  # value モードで外部計算済みError barを描画座標へ変換するだけのhelper。
  # mean / SD / SEM / n / CI の再計算は行わない。
  external_error_bounds <- function(z, ycol) {
    mode <- input$external_error_mode %||% "none"
    if (!isTRUE(direct_value_mode()) || identical(mode, "none")) return(NULL)

    shiny::validate(
      shiny::need(ycol %in% names(z), "Y列が見つかりません。")
    )
    yv <- z[[ycol]]

    if (identical(mode, "symmetric")) {
      ecol <- input$external_error_col %||% ""
      shiny::validate(
        shiny::need(nzchar(ecol) && ecol %in% names(z), "Error barに使用する誤差列を指定してください。"),
        shiny::need(is.numeric(z[[ecol]]), "Error barの誤差列には数値列を指定してください。")
      )
      ev <- z[[ecol]]
      shiny::validate(
        shiny::need(!any(is.finite(ev) & ev < 0, na.rm = TRUE), "±誤差列には0以上の値を指定してください。")
      )
      return(list(
        ymin = yv - ev,
        ymax = yv + ev,
        mode = mode,
        error = ecol
      ))
    }

    if (identical(mode, "bounds")) {
      low_col <- input$external_ymin_col %||% ""
      high_col <- input$external_ymax_col %||% ""
      shiny::validate(
        shiny::need(nzchar(low_col) && low_col %in% names(z), "Error barの下限列を指定してください。"),
        shiny::need(nzchar(high_col) && high_col %in% names(z), "Error barの上限列を指定してください。"),
        shiny::need(is.numeric(z[[low_col]]), "Error barの下限列には数値列を指定してください。"),
        shiny::need(is.numeric(z[[high_col]]), "Error barの上限列には数値列を指定してください。")
      )
      lo <- z[[low_col]]
      hi <- z[[high_col]]
      shiny::validate(
        shiny::need(
          !any(is.finite(lo) & is.finite(hi) & lo > hi, na.rm = TRUE),
          "Error barの下限列に上限列より大きい値があります。"
        )
      )
      return(list(
        ymin = lo,
        ymax = hi,
        mode = mode,
        lower = low_col,
        upper = high_col
      ))
    }

    NULL
  }

  output$summary_unit_status <- renderUI({
    if (identical(input$plot_type, "scatter") || isTRUE(direct_value_mode())) return(NULL)
    d <- tryCatch(plot_data(), error = function(e) NULL)
    if (is.null(d)) return(NULL)

    idv <- input$idvar %||% ""
    if (!has_selection(idv) || !idv %in% names(d)) {
      return(p(
        class = "help-block",
        "「個体IDごとに先に平均」を選ぶ場合は、Mappingで個体IDを指定してください。"
      ))
    }

    grouping <- summary_grouping_vars()
    cell_vars <- unique(c(idv, grouping))
    repeated <- d %>%
      count(across(all_of(cell_vars)), name = ".n_trial__") %>%
      summarise(any_repeat = any(.n_trial__ > 1L)) %>%
      pull(.data$any_repeat)

    if (identical(input$summary_unit %||% "row", "id_mean")) {
      return(p(
        class = "help-block",
        "現在はID内の複数trialを各条件セルで先に平均します。平均・SD・SEM・95%CIのnは個体数です。"
      ))
    }

    if (isTRUE(repeated)) {
      p(
        class = "help-block",
        style = "color:#8a6d3b;",
        "同じID・同じ条件セルに複数行があります。各個体をexperimental unitとして扱う場合は「個体IDごとに先に平均」を推奨します。"
      )
    } else {
      p(class = "help-block", "現在の条件セルでは各IDは1行なので、2つの集計単位は同じ平均になります。")
    }
  })

  selected_font_family <- reactive({
    mode <- input$font_family_mode %||% "sans"
    if (identical(mode, "custom")) {
      fam <- trimws(input$font_family_custom %||% "")
      if (nzchar(fam)) fam else "sans"
    } else {
      mode
    }
  })

  theme_object <- reactive({
    fam <- selected_font_family()

    legend_key_width <- suppressWarnings(as.numeric(input$legend_key_width))
    if (!is.finite(legend_key_width) || legend_key_width < 0) {
      legend_key_width <- 1.8
    }

    th <- switch(
      input$theme,
      classic = theme_classic(base_size = input$base_size, base_family = fam),
      bw = theme_bw(base_size = input$base_size, base_family = fam),
      minimal = theme_minimal(base_size = input$base_size, base_family = fam),
      gray = theme_gray(base_size = input$base_size, base_family = fam)
    )
    th + theme(
      legend.position = input$legend_pos,
      legend.key.width = grid::unit(legend_key_width, "cm"),
      panel.spacing.x = grid::unit(
        suppressWarnings(as.numeric(input$facet_spacing_x %||% 0.12)), "cm"
      ),
      text = element_text(family = fam),
      plot.title = element_text(family = fam),
      axis.title = element_text(family = fam),
      axis.text = element_text(family = fam),
      legend.title = element_text(family = fam),
      legend.text = element_text(family = fam),
      strip.text = element_text(family = fam)
    )
  })

  # 同一X × Group × Facet内で横方向へ規則的に散らす。
  # 乱数ではないので再描画やチェックON/OFFで位置が動かない。
  add_stable_spread <- function(d, x_col, group_col = NULL, facet_col = NULL,
                                id_col = NULL, width = 0.18) {
    d$.row_order__ <- seq_len(nrow(d))
    grouping <- c(x_col)
    if (!is.null(group_col) && nzchar(group_col)) grouping <- c(grouping, group_col)
    if (!is.null(facet_col) && nzchar(facet_col)) grouping <- c(grouping, facet_col)
    grouping <- unique(grouping)

    if (!is.null(id_col) && nzchar(id_col)) {
      d <- d %>%
        group_by(across(all_of(grouping))) %>%
        arrange(.data[[id_col]], .by_group = TRUE) %>%
        mutate(
          .spread_n__ = n(),
          .spread_rank__ = row_number(),
          .spread__ = ifelse(
            .spread_n__ <= 1, 0,
            ((.spread_rank__ - 1) / (.spread_n__ - 1) - 0.5) * 2 * width
          )
        ) %>%
        ungroup()
    } else {
      d <- d %>%
        group_by(across(all_of(grouping))) %>%
        mutate(
          .spread_n__ = n(),
          .spread_rank__ = row_number(),
          .spread__ = ifelse(
            .spread_n__ <= 1, 0,
            ((.spread_rank__ - 1) / (.spread_n__ - 1) - 0.5) * 2 * width
          )
        ) %>%
        ungroup()
    }

    d %>% arrange(.row_order__)
  }

  # ============================================================
  # Plot notes / warnings
  # ============================================================
  plot_note <- reactive({
    d <- if (identical(input$plot_type, "scatter") || isTRUE(direct_value_mode())) {
      plot_data()
    } else {
      display_observation_data()
    }

    if (identical(input$plot_type, "scatter") &&
        has_selection(input$xvar) && input$xvar %in% names(dat())) {
      raw_x <- dat()[[input$xvar]]
      if (!is.numeric(raw_x)) {
        x_chr <- trimws(as.character(raw_x))
        present <- !is.na(x_chr) & nzchar(x_chr)
        x_num <- suppressWarnings(as.numeric(x_chr))
        if (any(present) && any(is.finite(x_num[present])) &&
            any(!is.finite(x_num[present]))) {
          return(paste0(
            "散布図のX列「", input$xvar,
            "」には数値と文字が混在しています。文字の行を捨てず、離散Xとして表示しています。",
            "数値Xとして回帰したい場合はX列を数値だけに整理してください。"
          ))
        }
      }
    }

    if (input$plot_type == "bar" && identical(input$summary_type, "value")) {
      grouping <- c(input$xvar)
      if (has_selection(input$groupvar)) grouping <- c(grouping, input$groupvar)
      if (has_selection(input$facetvar)) grouping <- c(grouping, input$facetvar)
      dup <- d %>% count(across(all_of(unique(grouping)))) %>% filter(n > 1)
      if (nrow(dup) > 0) {
        return("『値（集計しない）』の棒グラフで同じ X × Group × Facet に複数行があります。平均化はしていないため、棒が同じ位置に重なります。必要ならIDをX/Group側に含めるか、事前に1値へ整理してください。")
      }
    }
    NULL
  })

  output$plot_note <- renderUI({
    note <- plot_note()
    if (is.null(note)) return(NULL)
    div(class = "alert alert-warning plot-note-wrap", note)
  })

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
    use_value <- isTRUE(direct_value_mode())
    d <- if (identical(input$plot_type, "scatter") || use_value) {
      plot_data()
    } else {
      display_observation_data()
    }
    x <- resolved_xvar()
    y <- resolved_yvar()
    g <- effective_position_var(d)
    cvar <- resolve_color_var(d)
    lvar <- resolve_linetype_var(d)
    svar <- resolve_shape_var(d)
    facet <- if (has_selection(input$facetvar)) input$facetvar else ""
    id <- if (has_selection(input$idvar)) input$idvar else ""

    has_group <- nzchar(g)
    has_style <- nzchar(cvar)       # legacy name: Color mapping exists
    has_color <- nzchar(cvar)
    has_linetype <- nzchar(lvar)
    has_shape <- nzchar(svar)
    has_id <- nzchar(id)

    # Dynamic ggplot mapping helper. aes_string() is wrapped here so arbitrary
    # column names can be passed through .data[[...]] expressions.
    aes_ref <- function(nm) {
      paste0(".data[[", deparse(as.character(nm)), "]]")
    }

    dynamic_aes <- function(xcol = "", ycol = "", groupcol = "",
                            colourcol = "", linetypecol = "", shapecol = "",
                            ymincol = "", ymaxcol = "", fillcol = "",
                            xendcol = "", yendcol = "") {
      args <- list()
      if (nzchar(xcol)) args$x <- aes_ref(xcol)
      if (nzchar(ycol)) args$y <- aes_ref(ycol)
      if (nzchar(groupcol)) args$group <- aes_ref(groupcol)
      if (nzchar(colourcol)) args$colour <- aes_ref(colourcol)
      if (nzchar(linetypecol)) args$linetype <- aes_ref(linetypecol)
      if (nzchar(shapecol)) args$shape <- aes_ref(shapecol)
      if (nzchar(ymincol)) args$ymin <- aes_ref(ymincol)
      if (nzchar(ymaxcol)) args$ymax <- aes_ref(ymaxcol)
      if (nzchar(fillcol)) args$fill <- aes_ref(fillcol)
      if (nzchar(xendcol)) args$xend <- aes_ref(xendcol)
      if (nzchar(yendcol)) args$yend <- aes_ref(yendcol)
      suppressWarnings(do.call(ggplot2::aes_string, args))
    }

    add_interaction_key <- function(z, vars, name = ".auto_group__") {
      vars <- unique(vars[nzchar(vars) & vars %in% names(z)])
      if (!length(vars)) {
        z[[name]] <- factor(rep("all", nrow(z)))
      } else if (length(vars) == 1L) {
        z[[name]] <- factor(as.character(z[[vars[1]]]))
      } else {
        z[[name]] <- do.call(
          interaction,
          c(lapply(vars, function(v) z[[v]]), list(drop = TRUE, lex.order = TRUE))
        )
      }
      z
    }

    # Bar/Box: X×Facet内に実在する条件だけで横位置を中央揃えする。
    make_slot_layout <- function(raw, xcol, slot_vars, facetcol = "",
                                 x_positions, total_width = 0.80,
                                 spacing = 1.0, slot_name = ".slot__") {
      z <- add_interaction_key(raw, slot_vars, slot_name)
      z[[slot_name]] <- as.character(z[[slot_name]])
      global_slots <- unique(z[[slot_name]])
      global_slots <- global_slots[!is.na(global_slots)]

      key_vars <- unique(c(xcol, if (nzchar(facetcol)) facetcol else "", slot_name))
      key_vars <- key_vars[nzchar(key_vars)]
      grp <- unique(c(xcol, if (nzchar(facetcol)) facetcol else ""))
      grp <- grp[nzchar(grp)]

      lay <- z %>% distinct(across(all_of(key_vars)))
      lay$.global_order__ <- match(lay[[slot_name]], global_slots)

      lay <- lay %>%
        group_by(across(all_of(grp))) %>%
        arrange(.global_order__, .by_group = TRUE) %>%
        mutate(
          .slot_n__ = n(),
          .slot_i__ = row_number(),
          # slot幅は条件数だけで決める。spacingは中心距離だけに作用させる。
          .slot_width__ = total_width / pmax(.slot_n__, 1),
          .slot_step__ = .slot_width__ * spacing,
          .x_group__ = unname(x_positions[as.character(.data[[xcol]])]) +
            (.slot_i__ - (.slot_n__ + 1) / 2) * .slot_step__
        ) %>%
        ungroup()

      list(data=z, layout=lay, key_vars=key_vars,
           global_slots=global_slots, slot_vars=slot_vars,
           slot_name=slot_name)
    }

    apply_slot_layout <- function(z, obj) {
      z <- add_interaction_key(z, obj$slot_vars, obj$slot_name)
      z[[obj$slot_name]] <- as.character(z[[obj$slot_name]])
      keep <- unique(c(obj$key_vars, ".x_group__", ".slot_width__"))
      left_join(z, obj$layout[, keep, drop=FALSE], by=obj$key_vars)
    }

    # 横位置要因とColorは別々に扱う
    gl <- if (has_group) levels(d[[g]]) else character(0)
    if (has_group && (is.null(gl) || length(gl) == 0L)) {
      gl <- unique(as.character(d[[g]]))
    }
    gl <- gl[!is.na(gl)]

    sl <- if (has_style) levels(d[[cvar]]) else character(0)
    if (has_style && (is.null(sl) || length(sl) == 0L)) {
      sl <- unique(as.character(d[[cvar]]))
    }
    sl <- sl[!is.na(sl)]

    combo_override <- isTRUE(input$series_style_override) &&
      has_group && has_style && !identical(g, cvar)

    if (combo_override) {
      d$.style_display <- series_combo_key(
        as.character(d[[cvar]]),
        as.character(d[[g]])
      )
      style_var <- ".style_display"

      combo_levels <- series_combo_levels()
      # データに存在する組み合わせだけを残す
      observed_combo <- unique(as.character(d$.style_display))
      display_levels <- combo_levels[combo_levels %in% observed_combo]
      display_levels <- c(display_levels, setdiff(observed_combo, display_levels))
      styles <- series_style_vectors(display_levels)
    } else {
      style_var <- cvar
      display_levels <- sl
      if (has_style) {
        styles <- list(color = color_style_vector(cvar, display_levels))
      } else {
        styles <- NULL
      }
    }

    decorate_style <- function(z) {
      if (combo_override && nrow(z) > 0) {
        z$.style_display <- series_combo_key(
          as.character(z[[cvar]]),
          as.character(z[[g]])
        )
        z$.style_display <- factor(z$.style_display, levels = display_levels)
      }
      z
    }

    if (combo_override) {
      d <- decorate_style(d)
    }

    # Color mapping may use the existing Color × position override key.
    color_map_var <- if (has_color) style_var else ""

    # Linetype/Shape can either follow Color (backward-compatible default),
    # be fixed, or use an entirely different column.
    linetype_mode <- input$linetypevar %||% "__color__"
    shape_mode <- input$shapevar %||% "__color__"

    linetype_map_var <- if (identical(linetype_mode, "__color__")) {
      if (has_color) cvar else ""
    } else if (has_linetype) {
      lvar
    } else {
      ""
    }

    shape_map_var <- if (identical(shape_mode, "__color__")) {
      if (has_color) cvar else ""
    } else if (has_shape) {
      svar
    } else {
      ""
    }

    effective_has_linetype <- nzchar(linetype_map_var)
    effective_has_shape <- nzchar(shape_map_var)

    aes_levels <- function(z, var, preferred = NULL) {
      if (!nzchar(var) || !var %in% names(z)) return(character(0))
      if (!is.null(preferred) && length(preferred)) return(preferred)
      lv <- levels(z[[var]])
      if (is.null(lv) || !length(lv)) lv <- unique(as.character(z[[var]]))
      lv[!is.na(lv)]
    }

    linetype_levels <- if (effective_has_linetype) {
      if (identical(linetype_map_var, color_map_var) && has_color) {
        display_levels
      } else {
        aes_levels(d, linetype_map_var)
      }
    } else character(0)

    shape_levels <- if (effective_has_shape) {
      if (identical(shape_map_var, color_map_var) && has_color) {
        display_levels
      } else {
        aes_levels(d, shape_map_var)
      }
    } else character(0)

    linetype_values <- if (length(linetype_levels)) {
      line_style_var <- if (identical(linetype_mode, "__color__")) cvar else lvar
      linetype_style_vector(line_style_var, linetype_levels)
    } else NULL

    shape_values <- if (length(shape_levels)) {
      shape_style_var <- if (identical(shape_mode, "__color__")) cvar else svar
      shape_style_vector(shape_style_var, shape_levels)
    } else NULL

    color_legend_key <- if (combo_override) {
      paste0("__combo__::", cvar, "::", g)
    } else {
      cvar
    }

    color_title_default <- if (combo_override) paste0(cvar, " × ", g) else cvar
    color_legend_title <- if (has_color) {
      legend_title_value(color_legend_key, color_title_default)
    } else ""

    combo_display_labels <- function(keys_now) {
      if (!combo_override) return(level_label_values(cvar, keys_now))
      vapply(
        keys_now,
        function(k) {
          parts <- strsplit(k, " × ", fixed = TRUE)[[1]]
          if (length(parts) < 2L) return(k)
          a <- level_label_values(cvar, parts[1])
          b <- level_label_values(g, paste(parts[-1], collapse = " × "))
          paste0(a, " × ", b)
        },
        character(1)
      )
    }

    color_display_labels <- if (has_color) combo_display_labels(display_levels) else character(0)

    linetype_legend_key <- if (
      effective_has_linetype &&
      identical(linetype_map_var, color_map_var) &&
      has_color
    ) {
      color_legend_key
    } else {
      lvar
    }
    linetype_title_default <- if (
      effective_has_linetype &&
      identical(linetype_map_var, color_map_var) &&
      has_color
    ) color_title_default else lvar
    linetype_legend_title <- if (effective_has_linetype) {
      legend_title_value(linetype_legend_key, linetype_title_default)
    } else ""
    linetype_display_labels <- if (effective_has_linetype) {
      if (identical(linetype_map_var, color_map_var) && has_color) {
        color_display_labels
      } else {
        level_label_values(lvar, linetype_levels)
      }
    } else character(0)

    shape_legend_key <- if (
      effective_has_shape &&
      identical(shape_map_var, color_map_var) &&
      has_color
    ) {
      color_legend_key
    } else {
      svar
    }
    shape_title_default <- if (
      effective_has_shape &&
      identical(shape_map_var, color_map_var) &&
      has_color
    ) color_title_default else svar
    shape_legend_title <- if (effective_has_shape) {
      legend_title_value(shape_legend_key, shape_title_default)
    } else ""
    shape_display_labels <- if (effective_has_shape) {
      if (identical(shape_map_var, color_map_var) && has_color) {
        color_display_labels
      } else {
        level_label_values(svar, shape_levels)
      }
    } else character(0)

    raw_fixed_color <- if (identical(input$raw_color_mode, "custom_fixed")) {
      input$raw_fixed_custom
    } else {
      "gray30"
    }

    id_fixed_color <- if (identical(input$id_line_color_mode, "custom_fixed")) {
      input$id_line_custom_color
    } else {
      "gray50"
    }

    if (has_style) {
      style_key <- as.character(d[[style_var]])
      base_cols <- styles$color

      raw_cols <- if (identical(input$raw_color_mode, "group_light")) {
        setNames(vapply(base_cols, lighten_colour, character(1), amount = input$raw_lighten), names(base_cols))
      } else if (identical(input$raw_color_mode, "group")) {
        base_cols
      } else if (identical(input$raw_color_mode, "custom_group")) {
        if (combo_override) {
          # 組み合わせ上書き時は、その組み合わせの基本色を個体点にも反映
          base_cols
        } else {
          ensure_raw_group_colors(cvar, display_levels)
          rc <- raw_group_colors()[[cvar]] %||% list()
          setNames(vapply(display_levels, function(nm) as.character(rc[[nm]] %||% "#777777"), character(1)), display_levels)
        }
      } else if (identical(input$raw_color_mode, "custom_fixed")) {
        setNames(rep(input$raw_fixed_custom, length(display_levels)), display_levels)
      } else {
        setNames(rep("gray30", length(display_levels)), display_levels)
      }

      id_cols <- if (identical(input$id_line_color_mode, "group_light")) {
        setNames(vapply(base_cols, lighten_colour, character(1), amount = input$id_line_lighten), names(base_cols))
      } else if (identical(input$id_line_color_mode, "group")) {
        base_cols
      } else if (identical(input$id_line_color_mode, "custom_fixed")) {
        setNames(rep(input$id_line_custom_color, length(display_levels)), display_levels)
      } else {
        setNames(rep("gray50", length(display_levels)), display_levels)
      }
    } else {
      style_key <- rep(NA_character_, nrow(d))
      raw_cols <- NULL
      id_cols <- NULL
    }

    # ----------------------------------------------------------
    # Individual-data layer helpers
    #
    # geom_line() sorts observations by group/x internally. Passing an
    # n-row fixed colour vector outside aes() can therefore detach colours
    # from rows. Instead, draw one fixed-colour layer per Color level.
    #
    # Individual connection grouping is handled separately with
    # .id_group__, which combines ID with the currently mapped overlay
    # conditions (Series/Color/Linetype/Shape). This prevents Route a and
    # Route b of the same rat from being connected into one zig-zag line.
    # ----------------------------------------------------------
    add_id_line_layers <- function(
      p0, z, xcol, ycol, groupcol = ".id_group__",
      map_linetype = FALSE
    ) {
      if (!nrow(z)) return(p0)

      add_one <- function(p1, zz, col) {
        if (!nrow(zz)) return(p1)

        lt_col <- if (
          isTRUE(map_linetype) &&
          nzchar(linetype_map_var) &&
          linetype_map_var %in% names(zz)
        ) linetype_map_var else ""

        mp <- dynamic_aes(
          xcol = xcol,
          ycol = ycol,
          groupcol = groupcol,
          linetypecol = lt_col
        )

        args <- list(
          data = zz,
          mapping = mp,
          colour = col,
          linewidth = input$id_line_width,
          alpha = input$id_line_alpha,
          inherit.aes = FALSE
        )
        if (!nzchar(lt_col)) args$linetype <- input$id_linetype

        p1 + do.call(geom_line, args)
      }

      if (!has_color || is.null(id_cols)) {
        return(add_one(p0, z, id_fixed_color))
      }

      lev <- unique(as.character(z[[color_map_var]]))
      lev <- lev[!is.na(lev)]

      for (nm in lev) {
        zz <- z[as.character(z[[color_map_var]]) == nm, , drop = FALSE]
        col <- unname(id_cols[[nm]])

        if (is.null(col) || !length(col) || is.na(col) || !nzchar(col)) {
          col <- id_fixed_color
        }

        p0 <- add_one(p0, zz, col)
      }

      p0
    }

    add_raw_point_layers <- function(p0, z, xcol, ycol, shape_var = "") {
      if (!nrow(z)) return(p0)

      add_one <- function(p1, zz, col) {
        if (!nrow(zz)) return(p1)

        mp <- dynamic_aes(
          xcol = xcol,
          ycol = ycol,
          shapecol = shape_var
        )

        args <- list(
          mapping = mp,
          data = zz,
          colour = col,
          size = input$raw_point_size,
          alpha = input$raw_alpha,
          inherit.aes = FALSE
        )

        if (!nzchar(shape_var)) {
          args$shape <- as.numeric(input$raw_shape)
        }

        p1 + do.call(geom_point, args)
      }

      if (!has_color || is.null(raw_cols)) {
        return(add_one(p0, z, raw_fixed_color))
      }

      lev <- unique(as.character(z[[color_map_var]]))
      lev <- lev[!is.na(lev)]

      for (nm in lev) {
        zz <- z[as.character(z[[color_map_var]]) == nm, , drop = FALSE]
        col <- unname(raw_cols[[nm]])

        if (is.null(col) || !length(col) || is.na(col) || !nzchar(col)) {
          col <- raw_fixed_color
        }

        p0 <- add_one(p0, zz, col)
      }

      p0
    }

    # ---------------------------------------
    # LINE
    # ---------------------------------------
    if (input$plot_type == "line") {

      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))

      # Line専用 X目盛間隔。
      # 単純に座標を一律倍するとggplotがscaleを再調整して見た目の
      # 目盛間隔がほぼ変わらないため、通常の1..N軸範囲を固定したまま
      # category centerだけを中央方向へ圧縮する。
      base_x_positions <- seq_along(xl)
      line_x_spacing <- suppressWarnings(as.numeric(input$line_x_spacing))
      if (!is.finite(line_x_spacing)) line_x_spacing <- 1.00
      line_x_spacing <- max(0, min(1.00, line_x_spacing))

      if (length(base_x_positions) <= 1L) {
        x_positions <- base_x_positions
      } else {
        x_center <- mean(range(base_x_positions))
        x_positions <- x_center + (base_x_positions - x_center) * line_x_spacing
      }

      d$.x_base <- x_positions[match(as.character(d[[x]]), xl)]

      # Series / Dodge controls horizontal position only.
      if (has_group) {
        n_group <- max(length(gl), 1)
        dodge_total <- suppressWarnings(as.numeric(input$line_group_dodge))
        if (!is.finite(dodge_total)) dodge_total <- 0.10
        dodge_total <- max(0, min(0.40, dodge_total))

        if (length(gl) == 0L) {
          gl <- unique(as.character(d[[g]]))
          gl <- gl[!is.na(gl)]
          n_group <- length(gl)
        }

        shiny::validate(shiny::need(
          length(gl) > 0L,
          paste0("Mappingエラー: Group列「", g, "」に有効な水準がありません。")
        ))

        if (n_group <= 1 || dodge_total == 0) {
          group_offsets <- setNames(rep(0, length(gl)), gl)
        } else {
          group_offsets <- setNames(
            seq(-dodge_total / 2, dodge_total / 2, length.out = length(gl)),
            gl
          )
        }

        mapped_offsets <- unname(group_offsets[as.character(d[[g]])])
        if (length(mapped_offsets) != nrow(d)) {
          mapped_offsets <- rep(0, nrow(d))
        } else {
          mapped_offsets[is.na(mapped_offsets)] <- 0
        }

        d$.x_group <- d$.x_base + mapped_offsets

        d <- add_stable_spread(
          d,
          x_col = x,
          group_col = g,
          facet_col = if (nzchar(facet)) facet else NULL,
          id_col = if (has_id) id else NULL,
          width = input$jitter_width
        )

        spread_scale <- max(0.02, (1 - dodge_total) / max(length(gl), 1))
        d$.x_raw <- d$.x_group + d$.spread__ * spread_scale

      } else {
        d$.x_group <- d$.x_base
        d <- add_stable_spread(
          d,
          x_col = x,
          group_col = NULL,
          facet_col = if (nzchar(facet)) facet else NULL,
          id_col = if (has_id) id else NULL,
          width = input$jitter_width
        )
        d$.x_raw <- d$.x_base + d$.spread__
      }

      # Every mapped overlay factor contributes to the actual mean/raw
      # trajectory grouping.
      overlay_vars_d <- unique(c(g, color_map_var, linetype_map_var, shape_map_var))
      if (has_id && use_value) overlay_vars_d <- unique(c(id, overlay_vars_d))
      d <- add_interaction_key(d, overlay_vars_d, ".line_group__")

      # Individual connection lines must never bridge different routes /
      # conditions of the same ID. Example:
      # ID5 × Route a and ID5 × Route b are two independent trajectories.
      if (has_id) {
        id_overlay_vars <- unique(c(
          id, g, color_map_var, linetype_map_var, shape_map_var
        ))
        d <- add_interaction_key(d, id_overlay_vars, ".id_group__")
      }

      if (use_value) {
        ext_bounds <- external_error_bounds(d, y)
        if (!is.null(ext_bounds)) {
          d$.ymin <- ext_bounds$ymin
          d$.ymax <- ext_bounds$ymax
        }

        p <- ggplot()

        line_map <- dynamic_aes(
          xcol = if (has_id) ".x_raw" else ".x_group",
          ycol = y,
          groupcol = ".line_group__",
          colourcol = color_map_var,
          linetypecol = linetype_map_var
        )

        line_args <- list(
          mapping = line_map,
          data = d,
          linewidth = input$line_width
        )
        if (!has_color) line_args$colour <- input$mean_color_mode
        if (!effective_has_linetype) line_args$linetype <- input$mean_linetype
        p <- p + do.call(geom_line, line_args)

        point_map <- dynamic_aes(
          xcol = if (has_id) ".x_raw" else ".x_group",
          ycol = y,
          colourcol = color_map_var,
          shapecol = shape_map_var
        )
        point_args <- list(mapping = point_map, data = d, size = input$point_size)
        if (!has_color) point_args$colour <- input$mean_color_mode
        if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)
        p <- p + do.call(geom_point, point_args)

        if (!is.null(ext_bounds)) {
          err_colour_var <- if (identical(input$error_color_mode, "group") && has_color) {
            color_map_var
          } else {
            ""
          }
          err_map <- dynamic_aes(
            xcol = if (has_id) ".x_raw" else ".x_group",
            ymincol = ".ymin",
            ymaxcol = ".ymax",
            colourcol = err_colour_var
          )
          err_args <- list(
            mapping = err_map,
            data = d,
            width = input$error_width,
            linewidth = input$error_line_width,
            inherit.aes = FALSE
          )
          if (!nzchar(err_colour_var)) {
            err_args$colour <- if (identical(input$error_color_mode, "fixed")) {
              input$error_color
            } else {
              input$mean_color_mode
            }
          }
          p <- p + do.call(geom_errorbar, err_args)
        }

      } else {
        s <- decorate_style(summary_data())
        s$.x_base <- x_positions[match(as.character(s[[x]]), xl)]

        if (has_group) {
          so <- unname(group_offsets[as.character(s[[g]])])
          if (length(so) != nrow(s)) so <- rep(0, nrow(s))
          so[is.na(so)] <- 0
          s$.x_group <- s$.x_base + so
        } else {
          s$.x_group <- s$.x_base
        }

        s <- add_interaction_key(
          s,
          unique(c(g, color_map_var, linetype_map_var, shape_map_var)),
          ".line_group__"
        )

        errcol <- switch(input$summary_type, sd = "sd", sem = "sem", ci95 = "ci95", NULL)
        if (!is.null(errcol)) {
          s$.ymin <- s$mean - s[[errcol]]
          s$.ymax <- s$mean + s[[errcol]]
        }

        p <- ggplot()

        add_summary_line_point <- function(p0) {
          line_map <- dynamic_aes(
            xcol = ".x_group",
            ycol = "mean",
            groupcol = ".line_group__",
            colourcol = color_map_var,
            linetypecol = linetype_map_var
          )
          line_args <- list(mapping = line_map, data = s, linewidth = input$line_width)
          if (!has_color) line_args$colour <- input$mean_color_mode
          if (!effective_has_linetype) line_args$linetype <- input$mean_linetype
          p0 <- p0 + do.call(geom_line, line_args)

          point_map <- dynamic_aes(
            xcol = ".x_group",
            ycol = "mean",
            colourcol = color_map_var,
            shapecol = shape_map_var
          )
          point_args <- list(mapping = point_map, data = s, size = input$point_size)
          if (!has_color) point_args$colour <- input$mean_color_mode
          if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)
          p0 + do.call(geom_point, point_args)
        }

        add_summary_errorbar <- function(p0) {
          if (is.null(errcol)) return(p0)

          err_colour_var <- if (identical(input$error_color_mode, "group") && has_color) {
            color_map_var
          } else {
            ""
          }

          err_map <- dynamic_aes(
            xcol = ".x_group",
            ymincol = ".ymin",
            ymaxcol = ".ymax",
            colourcol = err_colour_var
          )
          err_args <- list(
            mapping = err_map,
            data = s,
            width = input$error_width,
            linewidth = input$error_line_width,
            inherit.aes = FALSE
          )
          if (!nzchar(err_colour_var)) {
            err_args$colour <- if (identical(input$error_color_mode, "fixed")) {
              input$error_color
            } else {
              input$mean_color_mode
            }
          }
          p0 + do.call(geom_errorbar, err_args)
        }

        add_individual_layers <- function(p0) {
          if (isTRUE(input$connect_id) && has_id) {
            p0 <- add_id_line_layers(
              p0,
              d,
              xcol = ".x_raw",
              ycol = y,
              groupcol = ".id_group__"
            )
          }

          if (isTRUE(input$show_raw)) {
            raw_shape_var <- if (
              identical(input$raw_shape_mode, "group") && effective_has_shape
            ) shape_map_var else ""

            p0 <- add_raw_point_layers(
              p0,
              d,
              xcol = ".x_raw",
              ycol = y,
              shape_var = raw_shape_var
            )
          }

          p0
        }

        # 論文図では個体値を背景、平均・エラーバーを前景にするのを既定にする。
        if (isTRUE(input$summary_on_top)) {
          p <- add_individual_layers(p)
          p <- add_summary_line_point(p)
          p <- add_summary_errorbar(p)
        } else {
          p <- add_summary_line_point(p)
          p <- add_summary_errorbar(p)
          p <- add_individual_layers(p)
        }
      }

      if (input$plot_type != "box") {
        # Keep a predictable visible X frame without adding a second
        # coordinate system. `oob_keep` preserves dodge/jitter observations
        # outside the scale limits instead of censoring/removing those rows.
        edge_pad <- 0.55

        line_x_view <- if (length(xl) <= 1L) {
          c(x_positions[1] - edge_pad, x_positions[1] + edge_pad)
        } else {
          c(1 - edge_pad, length(xl) + edge_pad)
        }

        p <- p + scale_x_continuous(
          breaks = x_positions,
          labels = level_label_values(x, xl),
          limits = line_x_view,
          oob = scales::oob_keep,
          expand = expansion(mult = c(0, 0))
        )
      }
    }

    # ---------------------------------------
    # BAR
    # ---------------------------------------
    if (input$plot_type == "bar") {
      sbar <- if (use_value) d else decorate_style(summary_data())
      value_col <- if (use_value) y else "mean"
      has_errorbar <- FALSE

      if (!use_value) {
        errcol <- switch(input$summary_type, sd="sd", sem="sem", ci95="ci95", NULL)
        if (!is.null(errcol)) {
          sbar$.ymin <- sbar$mean - sbar[[errcol]]
          sbar$.ymax <- sbar$mean + sbar[[errcol]]
          has_errorbar <- TRUE
        }
      } else {
        errcol <- NULL
        ext_bounds_bar <- external_error_bounds(sbar, y)
        if (!is.null(ext_bounds_bar)) {
          sbar$.ymin <- ext_bounds_bar$ymin
          sbar$.ymax <- ext_bounds_bar$ymax
          has_errorbar <- TRUE
        }
      }

      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))

      # Xカテゴリ間隔は、先頭カテゴリを固定して右へだけ伸ばすのではなく、
      # 1..N の中央を基準に左右対称に伸縮する。
      # spacing = 1.0 では従来の 1..N と完全に同じ位置になる。
      base_x_positions <- seq_along(xl)
      x_center <- if (length(base_x_positions)) mean(base_x_positions) else 1
      x_spacing <- suppressWarnings(as.numeric(input$x_category_spacing))
      if (!is.finite(x_spacing)) x_spacing <- 1.0
      x_positions <- setNames(
        x_center + (base_x_positions - x_center) * x_spacing,
        xl
      )

      slot_vars <- unique(c(
        if (has_group) g else "",
        if (has_color) color_map_var else ""
      ))
      slot_vars <- slot_vars[nzchar(slot_vars)]

      slot_obj <- make_slot_layout(
        d, x, slot_vars, facet, x_positions,
        total_width=0.80, spacing=input$group_spacing,
        slot_name=".bar_slot__"
      )
      d <- slot_obj$data
      keep <- unique(c(slot_obj$key_vars, ".x_group__", ".slot_width__"))
      d <- left_join(d, slot_obj$layout[, keep, drop=FALSE], by=slot_obj$key_vars)
      sbar <- apply_slot_layout(sbar, slot_obj)

      slot_width <- 0.80 / max(length(slot_obj$global_slots), 1L)

      d <- add_stable_spread(
        d, x_col=x, group_col=".bar_slot__", facet_col=if (nzchar(facet)) facet else NULL,
        id_col=if (has_id) id else NULL, width=input$jitter_width
      )
      d$.x_raw <- d$.x_group__ + d$.spread__ * slot_width

      if (has_id) {
        # Barの個体線:
        # ID × Color × 追加横並び要因を基本系列とする。
        # その系列内で同じXに複数点が残る場合は、行順に反復track番号を付け、
        # 同一block内の点同士を縦につながない。
        bar_id_vars <- unique(c(
          id,
          color_map_var,
          if (has_group) g else "",
          if (nzchar(facet)) facet else ""
        ))
        bar_id_vars <- bar_id_vars[nzchar(bar_id_vars)]

        repeat_group_vars <- unique(c(bar_id_vars, x))
        d <- d %>%
          group_by(across(all_of(repeat_group_vars))) %>%
          mutate(.bar_repeat_track__ = row_number()) %>%
          ungroup()

        bar_line_vars <- unique(c(bar_id_vars, ".bar_repeat_track__"))
        d <- add_interaction_key(d, bar_line_vars, ".id_group__")
      }

      border_matches_fill <- identical(input$bar_border_mode %||% "fixed", "fill")
      border_map_var <- if (border_matches_fill && has_color) color_map_var else ""
      bar_map <- dynamic_aes(
        xcol=".x_group__", ycol=value_col,
        fillcol=color_map_var, colourcol=border_map_var
      )
      bar_args <- list(
        mapping = bar_map,
        data = sbar,
        width = slot_width * input$bar_width,
        position = "identity",
        linewidth = input$bar_border_width
      )
      if (!has_color) bar_args$fill <- input$mean_color_mode
      if (!nzchar(border_map_var)) {
        bar_args$colour <- if (border_matches_fill) input$mean_color_mode else input$bar_border_color
      }
      p <- ggplot() + do.call(geom_col, bar_args)

      if (isTRUE(has_errorbar)) {
        err_colour_var <- if (identical(input$error_color_mode,"group") && has_color) color_map_var else ""
        err_map <- dynamic_aes(xcol=".x_group__", ymincol=".ymin", ymaxcol=".ymax", colourcol=err_colour_var)
        err_args <- list(mapping=err_map, data=sbar, width=input$error_width,
                         linewidth=input$error_line_width, inherit.aes=FALSE)
        if (!nzchar(err_colour_var)) err_args$colour <- if (identical(input$error_color_mode,"fixed")) input$error_color else input$mean_color_mode
        p <- p + do.call(geom_errorbar, err_args)
      }

      if (isTRUE(input$connect_id) && has_id) {
        p <- add_id_line_layers(p,d,xcol=".x_raw",ycol=y,groupcol=".id_group__")
      }
      if (isTRUE(input$show_raw)) {
        raw_shape_var <- if (identical(input$raw_shape_mode,"group") && effective_has_shape) shape_map_var else ""
        p <- add_raw_point_layers(p,d,xcol=".x_raw",ycol=y,shape_var=raw_shape_var)
      }

      if (input$plot_type != "box") {
        # カテゴリ間隔を大きくしても左端だけがY軸へ張り付かないよう、
        # 実際に描くバー・raw点・error barの横方向の端を集め、
        # Xカテゴリ列の中央を基準に左右対称の表示範囲を作る。
        # 余白は相対%ではなく一定量を足すため、spacingを広げたときも
        # 外側のバーとpanel端の余白が極端に小さくならない。
        bar_half_width <- 0.5 * slot_width * input$bar_width
        x_extent <- c(
          sbar$.x_group__ - bar_half_width,
          sbar$.x_group__ + bar_half_width
        )

        if (isTRUE(has_errorbar)) {
          err_half_width <- 0.5 * suppressWarnings(as.numeric(input$error_width))
          if (!is.finite(err_half_width)) err_half_width <- 0
          x_extent <- c(
            x_extent,
            sbar$.x_group__ - err_half_width,
            sbar$.x_group__ + err_half_width
          )
        }

        if ((isTRUE(input$show_raw) || (isTRUE(input$connect_id) && has_id)) &&
            ".x_raw" %in% names(d)) {
          x_extent <- c(x_extent, d$.x_raw)
        }

        x_extent <- x_extent[is.finite(x_extent)]
        frame_center <- if (length(base_x_positions)) mean(base_x_positions) else 1
        frame_pad <- 0.35
        if (length(x_extent)) {
          frame_radius <- max(abs(x_extent - frame_center), na.rm = TRUE) + frame_pad
        } else {
          frame_radius <- 0.55
        }
        # 1カテゴリでも通常の離散Xらしい左右余白を確保する。
        frame_radius <- max(frame_radius, 0.55)
        bar_x_view <- c(frame_center - frame_radius, frame_center + frame_radius)

        p <- p + scale_x_continuous(
          breaks = unname(x_positions),
          labels = level_label_values(x, xl),
          limits = bar_x_view,
          oob = scales::oob_keep,
          expand = expansion(mult = c(0, 0))
        )
      }
    }

    # ---------------------------------------
    # SCATTER
    # ---------------------------------------
    if (input$plot_type == "scatter") {
      scatter_map <- dynamic_aes(
        xcol = x,
        ycol = y,
        colourcol = color_map_var,
        shapecol = shape_map_var
      )

      point_args <- list(
        mapping = scatter_map,
        data = d,
        size = input$point_size,
        alpha = 0.90
      )
      if (!has_color) point_args$colour <- input$mean_color_mode
      if (!effective_has_shape) point_args$shape <- as.numeric(input$mean_shape)

      p <- ggplot() + do.call(geom_point, point_args)

      scatter_connect_mode <- input$scatter_connect_mode %||% "none"

      if (identical(scatter_connect_mode, "id") && has_id) {
        scatter_id_vars <- unique(c(id, color_map_var, linetype_map_var, shape_map_var))
        d <- add_interaction_key(d, scatter_id_vars, ".id_group__")
        p <- add_id_line_layers(
          p, d, xcol=x, ycol=y, groupcol=".id_group__",
          map_linetype = TRUE
        )
      }

      if (identical(scatter_connect_mode, "row")) {
        # 行i -> 行i+1を独立segmentとして描く。
        # geom_path()は非solid線で途中のcolour/linetypeが変わると
        # draw_panel()でエラーになるため、segment単位に分離する。
        if (nrow(d) >= 2L) {
          starts <- seq_len(nrow(d) - 1L)
          ends <- seq.int(2L, nrow(d))
          keep_segment <- rep(TRUE, length(starts))

          if (nzchar(facet) && facet %in% names(d)) {
            facet_start <- as.character(d[[facet]][starts])
            facet_end <- as.character(d[[facet]][ends])
            keep_segment <- !is.na(facet_start) & !is.na(facet_end) &
              facet_start == facet_end
          }

          seg <- d[starts[keep_segment], , drop = FALSE]
          seg$.xend__ <- d[[x]][ends[keep_segment]]
          seg$.yend__ <- d[[y]][ends[keep_segment]]

          seg_map <- dynamic_aes(
            xcol = x,
            ycol = y,
            xendcol = ".xend__",
            yendcol = ".yend__",
            colourcol = if (has_color) color_map_var else "",
            linetypecol = if (effective_has_linetype) linetype_map_var else ""
          )

          seg_args <- list(
            mapping = seg_map,
            data = seg,
            linewidth = input$id_line_width,
            alpha = input$id_line_alpha,
            inherit.aes = FALSE
          )
          if (!has_color) seg_args$colour <- input$mean_color_mode
          if (!effective_has_linetype) seg_args$linetype <- input$id_linetype

          p <- p + do.call(geom_segment, seg_args)
        }
      }

      # 線形回帰
      if (isTRUE(input$scatter_regression)) {
        shiny::validate(
          shiny::need(
            is.numeric(d[[x]]) && is.numeric(d[[y]]) &&
              sum(is.finite(d[[x]]) & is.finite(d[[y]])) >= 2 &&
              length(unique(d[[x]][is.finite(d[[x]])])) >= 2,
            "回帰直線には、数値のX/Yと2つ以上の異なるX値が必要です。"
          )
        )

        reg_mode <- input$scatter_regression_group %||% "overall"
        if (!reg_mode %in% c("overall", "style")) reg_mode <- "overall"
        reg_se <- isTRUE(input$scatter_regression_se)
        reg_alpha <- suppressWarnings(as.numeric(input$scatter_regression_se_alpha))
        if (!is.finite(reg_alpha)) reg_alpha <- 0.20

        if (identical(reg_mode, "overall")) {
          p <- p + geom_smooth(
            data = d,
            aes(x = .data[[x]], y = .data[[y]]),
            method = "lm",
            formula = y ~ x,
            se = reg_se,
            colour = input$scatter_regression_color,
            fill = input$scatter_regression_color,
            linetype = input$scatter_regression_linetype,
            linewidth = input$scatter_regression_width,
            alpha = reg_alpha,
            inherit.aes = FALSE
          )
        } else {
          reg_var <- if (identical(reg_mode, "style") && has_style) style_var else ""

          if (nzchar(reg_var)) {
            lev <- unique(as.character(d[[reg_var]]))
            lev <- lev[!is.na(lev)]
            ensure_regression_styles(lev)
            rs <- regression_styles()

            # 各回帰線を別レイヤーで描くことで、線ごとの色・線種・線幅を独立設定
            for (nm in lev) {
              dd <- d[as.character(d[[reg_var]]) == nm, , drop = FALSE]

              # lmには少なくとも2つの異なるXが必要
              if (nrow(dd) >= 2 && length(unique(dd[[x]])) >= 2) {
                st <- rs[[nm]]
                p <- p + geom_smooth(
                  data = dd,
                  aes(x = .data[[x]], y = .data[[y]]),
                  method = "lm",
                  formula = y ~ x,
                  se = reg_se,
                  colour = st$color,
                  fill = st$color,
                  linetype = st$linetype,
                  linewidth = st$width,
                  alpha = reg_alpha,
                  inherit.aes = FALSE
                )
              }
            }
          }
        }
      }

    }

    # ---------------------------------------
    # BOXPLOT
    # ---------------------------------------
    if (input$plot_type == "box") {
      xl <- levels(d[[x]])
      if (is.null(xl)) xl <- unique(as.character(d[[x]]))
      x_positions <- setNames(seq_along(xl), xl)

      slot_vars <- unique(c(
        if (has_group) g else "",
        if (has_color) color_map_var else ""
      ))
      slot_vars <- slot_vars[nzchar(slot_vars)]

      slot_obj <- make_slot_layout(
        d, x, slot_vars, facet, x_positions,
        total_width=0.78, spacing=input$group_spacing,
        slot_name=".box_slot__"
      )
      d <- slot_obj$data
      keep <- unique(c(slot_obj$key_vars, ".x_group__", ".slot_width__"))
      d <- left_join(d, slot_obj$layout[, keep, drop=FALSE], by=slot_obj$key_vars)

      # 箱の太さは中心間隔とは独立。
      # 各X×Facet内のslot幅に対する割合として決める。
      box_width_scale <- suppressWarnings(as.numeric(input$box_width_scale %||% 0.72))
      if (!is.finite(box_width_scale)) box_width_scale <- 0.72
      box_width_scale <- max(0, min(0.95, box_width_scale))
      d$.box_width__ <- d$.slot_width__ * box_width_scale

      # x is now an explicit numeric position, so geom_boxplot must be
      # grouped by X × slot. Grouping only by slot would pool all X levels
      # into one box near the middle of the axis.
      d <- add_interaction_key(
        d,
        c(x, ".box_slot__"),
        ".box_group__"
      )

      border_matches_fill <- identical(input$bar_border_mode %||% "fixed", "fill")
      border_map_var <- if (border_matches_fill && has_color) color_map_var else ""
      box_map <- dynamic_aes(
        xcol=".x_group__", ycol=y,
        groupcol=".box_group__", fillcol=color_map_var,
        colourcol=border_map_var
      )
      box_map$width <- rlang::sym(".box_width__")
      box_args <- list(
        mapping=box_map, data=d,
        linewidth=input$bar_border_width,
        outlier.shape=NA,
        orientation="x"
      )
      if (!has_color) box_args$fill <- input$mean_color_mode
      if (!nzchar(border_map_var)) {
        box_args$colour <- if (border_matches_fill) input$mean_color_mode else input$bar_border_color
      }
      p <- ggplot() + do.call(geom_boxplot, box_args)

      if (isTRUE(input$show_raw)) {
        d <- add_stable_spread(
          d, x_col=x, group_col=".box_slot__",
          facet_col=if (nzchar(facet)) facet else NULL,
          id_col=if (has_id) id else NULL,
          width=input$jitter_width
        )
        # 個体点は各Box中心の近傍だけに散らす。
        # jitter_width=1でも隣のBoxへ侵食しにくいよう最大45%に制限。
        raw_half_width <- d$.box_width__ * 0.45
        d$.x_raw <- d$.x_group__ + d$.spread__ * raw_half_width

        raw_shape_var <- if (
          identical(input$raw_shape_mode,"group") && effective_has_shape
        ) shape_map_var else ""

        p <- add_raw_point_layers(
          p, d, xcol=".x_raw", ycol=y, shape_var=raw_shape_var
        )
      }

      p <- p + scale_x_continuous(
        breaks=unname(x_positions),
        labels=level_label_values(x,xl),
        expand=expansion(mult=c(0.06,0.06))
      ) +
      theme(
        axis.line.x = element_line(
          colour = "black",
          linewidth = 0.5
        ),
        axis.ticks.x = element_line(
          colour = "black",
          linewidth = 0.5
        ),
        axis.ticks.length.x = grid::unit(0.12, "cm"),
        axis.text.x = element_text(colour = "black")
      )
    }

    # ---------------------------------------
    # Manual colour / linetype / shape scales
    # ---------------------------------------
    if (has_color) {
      if (input$plot_type %in% c("bar", "box")) {
        fill_values <- styles$color
        fill_levels_now <- display_levels

        if (nzchar(color_map_var) && color_map_var %in% names(d)) {
          mapped_levels <- unique(as.character(d[[color_map_var]]))
          mapped_levels <- mapped_levels[!is.na(mapped_levels)]
          keep_levels <- intersect(names(fill_values), mapped_levels)
          if (length(keep_levels)) {
            fill_values <- fill_values[keep_levels]
            fill_levels_now <- fill_levels_now[fill_levels_now %in% keep_levels]
          }
        }

        if (length(fill_values)) {
          p <- p + scale_fill_manual(
            values = fill_values,
            breaks = fill_levels_now,
            labels = color_display_labels[match(fill_levels_now, display_levels)],
            drop = FALSE
          )
        }
      }

      needs_colour_scale <- input$plot_type %in% c("line", "scatter")
      if (input$plot_type %in% c("bar", "box") &&
          identical(input$bar_border_mode %||% "fixed", "fill") &&
          nzchar(color_map_var) && color_map_var %in% names(d)) {
        needs_colour_scale <- TRUE
      }
      if (input$plot_type == "bar" &&
          identical(input$error_color_mode, "group") &&
          nzchar(color_map_var) && color_map_var %in% names(d)) {
        needs_colour_scale <- TRUE
      }

      if (isTRUE(needs_colour_scale)) {
        colour_values <- styles$color
        colour_levels_now <- display_levels

        # Manual scale should only contain levels actually represented by
        # the mapped colour variable. This prevents stale style names from
        # generating "No shared levels found" warnings.
        if (nzchar(color_map_var) && color_map_var %in% names(d)) {
          mapped_levels <- unique(as.character(d[[color_map_var]]))
          mapped_levels <- mapped_levels[!is.na(mapped_levels)]
          keep_levels <- intersect(names(colour_values), mapped_levels)
          if (length(keep_levels)) {
            colour_values <- colour_values[keep_levels]
            colour_levels_now <- colour_levels_now[colour_levels_now %in% keep_levels]
          }
        }

        if (length(colour_values)) {
          p <- p + scale_colour_manual(
            values = colour_values,
            breaks = colour_levels_now,
            labels = color_display_labels[match(colour_levels_now, display_levels)],
            drop = FALSE
          )
        }
      }
    }

    uses_mapped_linetype <- identical(input$plot_type, "line")
    if (identical(input$plot_type, "scatter")) {
      scatter_mode_now <- input$scatter_connect_mode %||% "none"
      uses_mapped_linetype <- scatter_mode_now %in% c("id", "row")
    }

    if (isTRUE(uses_mapped_linetype) &&
        effective_has_linetype && length(linetype_levels)) {
      lt_values_now <- linetype_values
      lt_levels_now <- linetype_levels
      lt_labels_now <- linetype_display_labels

      if (nzchar(linetype_map_var) && linetype_map_var %in% names(d)) {
        mapped_lt <- unique(as.character(d[[linetype_map_var]]))
        mapped_lt <- mapped_lt[!is.na(mapped_lt)]
        keep_lt <- intersect(names(lt_values_now), mapped_lt)

        if (length(keep_lt)) {
          lt_values_now <- lt_values_now[keep_lt]
          idx_lt <- match(keep_lt, lt_levels_now)
          idx_lt <- idx_lt[!is.na(idx_lt)]
          lt_levels_now <- lt_levels_now[idx_lt]
          lt_labels_now <- lt_labels_now[idx_lt]
        } else {
          lt_values_now <- character(0)
          lt_levels_now <- character(0)
          lt_labels_now <- character(0)
        }
      }

      if (length(lt_values_now) && length(lt_levels_now)) {
        p <- p + scale_linetype_manual(
          values = lt_values_now,
          breaks = lt_levels_now,
          labels = lt_labels_now,
          drop = FALSE
        )
      }
    }

    if (input$plot_type %in% c("line", "scatter", "bar", "box") &&
        effective_has_shape && length(shape_levels)) {
      p <- p + scale_shape_manual(
        values = shape_values,
        breaks = shape_levels,
        labels = shape_display_labels,
        drop = FALSE
      )
    }

    # Facet
    if (nzchar(facet)) {
      flev <- levels(d[[facet]])
      if (is.null(flev) || !length(flev)) {
        flev <- unique(as.character(d[[facet]]))
      }
      flev <- flev[!is.na(flev)]

      flab <- stats::setNames(
        level_label_values(facet, flev),
        flev
      )

      p <- p + facet_wrap(
        vars(.data[[facet]]),
        labeller = ggplot2::as_labeller(flab)
      )
    }

    # Labels
    label_args <- list(
      x = if (nzchar(input$xlab)) input$xlab else x,
      y = if (nzchar(input$ylab)) input$ylab else y,
      title = if (nzchar(input$title)) input$title else NULL
    )

    if (has_color) {
      if (input$plot_type %in% c("bar", "box")) {
        label_args$fill <- color_legend_title
      }
      if (input$plot_type %in% c("line", "scatter") ||
          (!use_value && input$plot_type == "bar" &&
             identical(input$error_color_mode, "group"))) {
        label_args$colour <- color_legend_title
      }
    }

    if (input$plot_type == "line" && effective_has_linetype) {
      label_args$linetype <- linetype_legend_title
    }

    if (input$plot_type %in% c("line", "scatter") && effective_has_shape) {
      label_args$shape <- shape_legend_title
    }

    p <- p + do.call(labs, label_args) + theme_object()

    # ---------------------------------------
    # Stable Y range
    # ---------------------------------------
    if (use_value) {
      y_candidates <- d[[y]]
      ext_range <- external_error_bounds(d, y)
      if (!is.null(ext_range)) {
        y_candidates <- c(y_candidates, ext_range$ymin, ext_range$ymax)
      }
    } else if (input$plot_type %in% c("line", "bar")) {
      s2 <- summary_data()
      y_candidates <- c(d[[y]], s2$mean)
      if (input$summary_type %in% c("sd", "sem", "ci95")) {
        errcol2 <- switch(input$summary_type, sd = "sd", sem = "sem", ci95 = "ci95")
        y_candidates <- c(y_candidates, s2$mean - s2[[errcol2]], s2$mean + s2[[errcol2]])
      }
    } else {
      y_candidates <- d[[y]]
    }

    if (input$plot_type == "bar") y_candidates <- c(y_candidates, 0)
    y_candidates <- y_candidates[is.finite(y_candidates)]
    bar_all_nonnegative <- !length(y_candidates) || min(y_candidates) >= 0

    auto_min <- if (length(y_candidates)) min(y_candidates) else 0
    auto_max <- if (length(y_candidates)) max(y_candidates) else 1
    span <- auto_max - auto_min
    if (!is.finite(span) || span <= 0) span <- max(abs(c(auto_min, auto_max)), 1)
    pad <- span * 0.05
    auto_min <- auto_min - pad
    auto_max <- auto_max + pad

    user_ymin <- suppressWarnings(as.numeric(input$ymin))
    user_ymax <- suppressWarnings(as.numeric(input$ymax))
    final_ymin <- if (is.finite(user_ymin)) user_ymin else auto_min
    final_ymax <- if (is.finite(user_ymax)) user_ymax else auto_max

    # 論文図向け: Y軸上端を最終目盛りに合わせる。
    # 手動stepでは現在上端以上の最初のtickへ、autoではpretty breakの
    # 現在上端以上のtickへ上端を合わせる。データを切らない方向にのみ調整する。
    if (isTRUE(input$y_top_to_tick) && is.finite(final_ymax) && is.finite(final_ymin) &&
        final_ymax > final_ymin) {
      if (!isTRUE(input$y_breaks_auto)) {
        step_top <- suppressWarnings(as.numeric(input$y_breaks_step))
        if (is.finite(step_top) && step_top > 0) {
          top_tick <- ceiling(final_ymax / step_top) * step_top
          if (is.finite(top_tick) && top_tick >= final_ymax) final_ymax <- top_tick
        }
      } else {
        pretty_ticks <- pretty(c(final_ymin, final_ymax), n = 5)
        pretty_ticks <- pretty_ticks[is.finite(pretty_ticks) & pretty_ticks >= final_ymax]
        if (length(pretty_ticks)) final_ymax <- min(pretty_ticks)
      }
    }

    # 正の棒グラフでは0とバー底の余白をなくす
    zero_touch <- isTRUE(
      input$plot_type == "bar" && input$bar_zero_touch && bar_all_nonnegative
    )
    if (zero_touch && (!is.finite(user_ymin) || user_ymin >= 0)) {
      final_ymin <- 0
    }

    break_is_valid <- FALSE
    break_from <- suppressWarnings(as.numeric(input$y_break_from))
    break_to <- suppressWarnings(as.numeric(input$y_break_to))

    if (isTRUE(input$y_break_enabled) &&
        is.finite(break_from) && is.finite(break_to) &&
        break_to > break_from &&
        break_from > final_ymin &&
        break_to < final_ymax) {
      break_is_valid <- TRUE
    }

    if (break_is_valid) {
      # Do not combine coord_cartesian() with ggbreak.  Applying both creates
      # duplicated/compressed panels and overlapping tick labels.
      gap_space <- suppressWarnings(as.numeric(input$y_break_space))
      if (!is.finite(gap_space)) gap_space <- 0.08
      gap_space <- max(0.02, min(0.30, gap_space))

      p <- p +
        scale_y_continuous(
          limits = c(final_ymin, final_ymax),
          breaks = y_break_values(final_ymin, final_ymax),
          expand = expansion(mult = c(if (zero_touch) 0 else 0.02, if (isTRUE(input$y_top_to_tick)) 0 else 0.05))
        ) +
        ggbreak::scale_y_break(
          c(break_from, break_to),
          scales = 1,
          space = gap_space
        )

      # ggbreak supplies the actual discontinuous scale.  A custom text
      # annotation inside the data panel caused label collisions in v1.8,
      # so the visual cue is now a small caption outside the plotting data.
      if (isTRUE(input$y_break_symbol)) {
        p <- p +
          labs(caption = paste0("∿  Y-axis omitted: ", break_from, " – ", break_to)) +
          theme(
            plot.caption = element_text(
              hjust = 0,
              size = max(7, input$base_size * 0.70),
              margin = margin(t = 4)
            )
          )
      }

    } else {
      if (final_ymax > final_ymin) {
        p <- p +
          scale_y_continuous(
            breaks = y_break_values(final_ymin, final_ymax),
            expand = expansion(mult = c(if (zero_touch) 0 else 0.05, if (isTRUE(input$y_top_to_tick)) 0 else 0.05))
          ) +
          coord_cartesian(
            ylim = c(final_ymin, final_ymax),
            clip = "off"
          )
      }
    }

    p
  })

  # ============================================================
  # Outputs
  # ============================================================
  # Plot size: sliderと直接数値入力を同期
  observeEvent(input$plot_width_px, {
    z <- safe_num1(input$plot_width_px, NA_real_)
    if (is.finite(z)) {
      cur <- safe_num1(input$plot_width_px_direct, NA_real_)
      if (!is.finite(cur) || abs(cur - z) > 0.5) {
        updateNumericInput(session, "plot_width_px_direct", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_width_px_direct, {
    z <- safe_num1(input$plot_width_px_direct, NA_real_)
    if (is.finite(z)) {
      z <- max(250, min(2000, z))
      cur <- safe_num1(input$plot_width_px, NA_real_)
      if (z >= 300 && z <= 1400 && (!is.finite(cur) || abs(cur - z) > 0.5)) {
        updateSliderInput(session, "plot_width_px", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_height_px, {
    z <- safe_num1(input$plot_height_px, NA_real_)
    if (is.finite(z)) {
      cur <- safe_num1(input$plot_height_px_direct, NA_real_)
      if (!is.finite(cur) || abs(cur - z) > 0.5) {
        updateNumericInput(session, "plot_height_px_direct", value = z)
      }
    }
  }, ignoreInit = FALSE)

  observeEvent(input$plot_height_px_direct, {
    z <- safe_num1(input$plot_height_px_direct, NA_real_)
    if (is.finite(z)) {
      z <- max(180, min(1400, z))
      cur <- safe_num1(input$plot_height_px, NA_real_)
      if (z >= 220 && z <= 900 && (!is.finite(cur) || abs(cur - z) > 0.5)) {
        updateSliderInput(session, "plot_height_px", value = z)
      }
    }
  }, ignoreInit = FALSE)

  effective_plot_width_px <- reactive({
    seed <- plot_width_restore_seed()
    if (!is.null(seed) && length(seed) && is.finite(seed[1])) {
      return(max(250, min(2000, as.numeric(seed[1]))))
    }

    z <- safe_num1(input$plot_width_px_direct, NA_real_)
    if (!is.finite(z)) z <- safe_num1(input$plot_width_px, 600)
    max(250, min(2000, z))
  })

  effective_plot_height_px <- reactive({
    seed <- plot_height_restore_seed()
    if (!is.null(seed) && length(seed) && is.finite(seed[1])) {
      return(max(180, min(1400, as.numeric(seed[1]))))
    }

    z <- safe_num1(input$plot_height_px_direct, NA_real_)
    if (!is.finite(z)) z <- safe_num1(input$plot_height_px, 600)
    max(180, min(1400, z))
  })

  # Browser側の直接数値inputが保存値へ追いついたらseedを解除する。
  # それまではhidden Graphのpanel/device寸法を保存値で固定する。
  observe({
    sw <- plot_width_restore_seed()
    if (!is.null(sw) && length(sw) && is.finite(sw[1])) {
      cur <- safe_num1(input$plot_width_px_direct, NA_real_)
      if (is.finite(cur) && abs(cur - as.numeric(sw[1])) <= 0.5) {
        plot_width_restore_seed(NULL)
      }
    }

    sh <- plot_height_restore_seed()
    if (!is.null(sh) && length(sh) && is.finite(sh[1])) {
      cur <- safe_num1(input$plot_height_px_direct, NA_real_)
      if (is.finite(cur) && abs(cur - as.numeric(sh[1])) <= 0.5) {
        plot_height_restore_seed(NULL)
      }
    }
  })

  output$plot_container <- renderUI({
    # IMPORTANT:
    # Plot width/height changes must NOT recreate this DOM.
    # Rebuilding plot_follow while sticky caused a temporary vertical jump.
    # Dimensions are applied in-place by JavaScript instead.
    div(
      id = session$ns("plot_anchor"),
      div(
        id = session$ns("plot_follow"),
        class = "plot-follow",
        `data-follow` = "true",
        uiOutput("plot_note"),
        div(
          id = session$ns("plot_panel"),
          class = "plot-panel",
          style = sprintf(
            "width:min(100%%, %dpx); max-width:%dpx; margin-left:auto; margin-right:auto;",
            as.integer(round(initial_plot_size_seed$width + 26)),
            as.integer(round(initial_plot_size_seed$width + 26))
          ),
          plotOutput(
            "plot",
            width = "100%",
            height = paste0(as.integer(round(initial_plot_size_seed$height)), "px")
          )
        ),
        div(
          class = "plot-style-toolbar",
          div(class = "plot-style-toolbar-title", "Graph書式"),
          fluidRow(
            column(3, actionButton("copy_style", "書式をコピー", class = "btn-sm btn-block")),
            column(3, actionButton("paste_style", "書式を貼り付け", class = "btn-sm btn-block")),
            column(3, downloadButton("download_style", "書式設定を保存", class = "btn-sm btn-block")),
            column(
              3,
              fileInput(
                "upload_style",
                NULL,
                accept = ".json",
                buttonLabel = "書式設定を読込",
                placeholder = "JSON"
              )
            )
          ),
          p(
            class = "help-block",
            "Data / Mapping / Statisticsは変更せず、Graphの書式だけを移します。コピー / 貼り付けは同じ起動中の別Graph・別Projectでも使用できます。"
          )
        )
      )
    )
  })

  # Plot DOMは固定したまま、CSS寸法だけをbrowser側で更新する。
  observe({
    pw <- effective_plot_width_px()
    ph <- effective_plot_height_px()

    session$sendCustomMessage(
      "set-plot-dimensions",
      list(
        panelId = session$ns("plot_panel"),
        plotId = session$ns("plot"),
        followId = session$ns("plot_follow"),
        anchorId = session$ns("plot_anchor"),
        width = as.integer(round(pw)),
        panelWidth = as.integer(round(pw + 26)),
        height = as.integer(round(ph))
      )
    )
  })

  observeEvent(input$sticky_plot, {
    session$sendCustomMessage(
      "set-follow-state",
      list(
        id = session$ns("plot_follow"),
        value = if (isTRUE(input$sticky_plot)) "true" else "false"
      )
    )
  }, ignoreInit = FALSE)

  output$plot <- renderPlot({
    # Project/duplicate Graphは、全設定の復元完了前にはPlotを描かない。
    # cancelOutput=TRUEにより、途中のdefault色・default Mappingの一瞬の描画を禁止。
    shiny::req(
      isTRUE(initial_restore_done()) &&
        !isTRUE(restoring_style_state()) &&
        project_restore_stage() == 0,
      cancelOutput = TRUE
    )

    # Statisticsタブ表示中はhidden Plotを更新しない。
    # graph_main_tabはmodule生成時にPlotが既定なので、Projectのhidden restore時に
    # 必要な最初の描画はこれまで通り可能。
    # 実際のPNG deviceは下の固定1000×600で生成し、タブ切替時の一時的な
    # client幅0/極小値による "figure margins too large" を回避する。
    shiny::req(
      is.null(input$graph_main_tab) || identical(input$graph_main_tab, "Plot"),
      cancelOutput = TRUE
    )

    p <- tryCatch(
      make_plot(),
      error = function(e) {
        # 85%で永久待機させないため、Plot生成エラーも描画可能なggplotへ変換する。
        ggplot() +
          annotate(
            "text",
            x = 0,
            y = 0,
            label = paste0(
              "Plot error:\n",
              paste(strwrap(conditionMessage(e), width = 58), collapse = "\n")
            ),
            hjust = 0
          ) +
          xlim(0, 1) +
          ylim(-1, 1) +
          theme_void()
      }
    )

    plot_drawn(TRUE)
    p
  },
  # Browserの瞬間的なoutput幅には依存せず、Axes設定の明示値を
  # device sizeとして使う。これによりPlot横幅/縦幅を安定して変更できる。
  width = function() {
    effective_plot_width_px()
  },
  height = function() {
    effective_plot_height_px()
  },
  res = 120,
  execOnResize = FALSE
  )

  output$stats_reference_plot <- renderPlot({
    # Statisticsで検定結果を読む際、左サイドバーへ出す参照専用Plot。
    # Statistics側からPlot設定は変更せず、現在のmake_plot()をそのまま再利用する。
    # Statisticsタブ表示中だけ描画するため、browser側の実寸に合わせて再描画してよい。
    shiny::req(
      isTRUE(initial_restore_done()) &&
        !isTRUE(restoring_style_state()) &&
        project_restore_stage() == 0,
      cancelOutput = TRUE
    )
    shiny::req(
      identical(input$graph_main_tab, "Statistics"),
      cancelOutput = TRUE
    )

    tryCatch(
      make_plot(),
      error = function(e) {
        ggplot() +
          annotate(
            "text",
            x = 0,
            y = 0,
            label = paste0(
              "Plot error:\n",
              paste(strwrap(conditionMessage(e), width = 38), collapse = "\n")
            ),
            hjust = 0
          ) +
          xlim(0, 1) +
          ylim(-1, 1) +
          theme_void()
      }
    )
  },
  width = "auto",
  height = "auto",
  res = 110,
  execOnResize = TRUE
  )

  last_valid_data_view <- reactiveVal(NULL)
  data_view_is_stale <- reactiveVal(FALSE)

  data_view_data <- reactive({
    # input$textを明示依存にして、貼り付け更新を確実に拾う。
    input$text
    dnow <- tryCatch(dat(), error = function(e) NULL)

    if (!is.null(dnow) && is.data.frame(dnow)) {
      last_valid_data_view(dnow)
      data_view_is_stale(FALSE)
      return(dnow)
    }

    data_view_is_stale(TRUE)
    last_valid_data_view()
  })

  output$data_view_status <- renderUI({
    if (!isTRUE(data_view_is_stale())) return(NULL)
    div(
      class = "alert alert-warning",
      style = "padding:6px 9px; margin-bottom:8px;",
      "現在の貼り付け内容をまだ解析できないため、直前の正常なData Viewを表示しています。"
    )
  })
  outputOptions(output, "data_view_status", suspendWhenHidden = FALSE)

  output$data_view <- renderTable({
    dv <- data_view_data()
    shiny::validate(shiny::need(
      !is.null(dv) && is.data.frame(dv),
      "表示できるデータがありません。"
    ))
    head(dv, 100)
  }, striped = TRUE, bordered = TRUE, spacing = "s")

  outputOptions(output, "data_view", suspendWhenHidden = FALSE)

  code_text <- reactive({
    x0 <- resolved_xvar()
    y0 <- resolved_yvar()
    x <- if (!nzchar(x0)) "X" else x0
    y <- if (!nzchar(y0)) "Y" else y0
    g <- effective_position_var(dat())
    summary_label <- switch(input$summary_type,
                            value = "値（集計しない）",
                            mean = "平均",
                            sd = "平均 ± SD",
                            sem = "平均 ± SEM",
                            ci95 = "平均 ± 95% CI",
                            "")

    summary_unit_label <- if (isTRUE(direct_value_mode())) {
      "使用しない（入力行をそのまま使用）"
    } else if (identical(input$summary_unit %||% "row", "id_mean")) {
      "ID mean -> between-ID summary"
    } else {
      "row"
    }

    external_error_label <- if (isTRUE(direct_value_mode())) {
      switch(
        input$external_error_mode %||% "none",
        symmetric = paste0("Y ± ", input$external_error_col %||% ""),
        bounds = paste0(
          "lower=", input$external_ymin_col %||% "",
          " / upper=", input$external_ymax_col %||% ""
        ),
        "なし"
      )
    } else {
      switch(
        input$summary_type %||% "mean",
        sd = "GUI計算 SD",
        sem = "GUI計算 SEM",
        ci95 = "GUI計算 95% CI",
        "なし"
      )
    }

    paste0(
      "# GUIで作成した図の主要設定\n",
      "# Plot: ", input$plot_type, "\n",
      "# X: ", x, " / Y: ", y, if (nzchar(g)) paste0(" / Position: ", g) else "", if (!is.null(input$colorvar) && nzchar(input$colorvar)) paste0(" / Color: ", input$colorvar) else "",
      if (!is.null(input$linetypevar) && nzchar(input$linetypevar) && input$linetypevar != "__color__") paste0(" / Linetype: ", input$linetypevar) else "",
      if (!is.null(input$shapevar) && nzchar(input$shapevar) && input$shapevar != "__color__") paste0(" / Shape: ", input$shapevar) else "", "\n",
      "# Summary: ", summary_label, "\n",
      "# Summary unit: ", summary_unit_label, "\n",
      "# Error bar: ", external_error_label, "\n",
      "# X order: ", paste(x_levels(), collapse = ", "), "\n",
      if (length(group_levels())) paste0("# Position order: ", paste(group_levels(), collapse = ", "), "\n") else "",
      if (!is.null(input$facetvar) && nzchar(input$facetvar)) {
        fobs <- unique(as.character(dat()[[input$facetvar]]))
        fobs <- fobs[!is.na(fobs)]
        paste0(
          "# Facet order: ",
          paste(get_saved_order("facet", input$facetvar, fobs), collapse = ", "),
          "\n"
        )
      } else "",
      "# Color / Linetype / Shape and detailed appearance are stored in the downloadable JSON settings file."
    )
  })

  output$ggcode <- renderText(code_text())

  observeEvent(input$copy_code, {
    session$sendCustomMessage("copy-code", code_text())
  })

  # ============================================================
  # Settings save / load
  # ============================================================
  style_settings <- reactive({
    list(
      version = "3.3.38",
      schema_version = 2L,
      color_styles = color_styles(),
      linetype_styles = linetype_styles(),
      shape_styles = shape_styles(),
      series_styles = series_styles(),
      regression_styles = regression_styles(),
      raw_group_colors = raw_group_colors(),
      orders = order_state(),
      legend_titles = legend_titles(),
      level_labels = level_labels(),
      appearance = list(
        series_style_override = input$series_style_override,
        palette_preset = input$palette_preset,
        raw_palette_preset = input$raw_palette_preset,
        scatter_regression = input$scatter_regression,
        scatter_regression_group = input$scatter_regression_group,
        scatter_regression_color = input$scatter_regression_color,
        scatter_regression_linetype = input$scatter_regression_linetype,
        scatter_regression_width = input$scatter_regression_width,
        scatter_regression_se = input$scatter_regression_se,
        scatter_regression_se_alpha = input$scatter_regression_se_alpha,
        theme = input$theme,
        font_family_mode = input$font_family_mode,
        font_family_custom = input$font_family_custom,
        base_size = input$base_size,
        summary_type = input$summary_type,
        summary_unit = input$summary_unit %||% "row",
        mean_color_mode = input$mean_color_mode,
        mean_linetype = input$mean_linetype,
        mean_shape = input$mean_shape,
        point_size = input$point_size,
        line_width = input$line_width,
        line_group_dodge = input$line_group_dodge,
        line_x_spacing = input$line_x_spacing,
        plot_width_px = effective_plot_width_px(),
        plot_height_px = effective_plot_height_px(),
        bar_width = input$bar_width,
        bar_zero_touch = input$bar_zero_touch,
        group_spacing = input$group_spacing,
        box_width_scale = input$box_width_scale,
        x_category_spacing = input$x_category_spacing,
        bar_border_mode = input$bar_border_mode,
        bar_border_color = input$bar_border_color,
        bar_border_width = input$bar_border_width,
        raw_color_mode = input$raw_color_mode,
        raw_fixed_custom = input$raw_fixed_custom,
        raw_lighten = input$raw_lighten,
        raw_alpha = input$raw_alpha,
        raw_shape_mode = input$raw_shape_mode,
        raw_shape = input$raw_shape,
        raw_point_size = input$raw_point_size,
        jitter_width = input$jitter_width,
        id_line_color_mode = input$id_line_color_mode,
        id_line_custom_color = input$id_line_custom_color,
        id_line_lighten = input$id_line_lighten,
        id_linetype = input$id_linetype,
        id_line_width = input$id_line_width,
        id_line_alpha = input$id_line_alpha,
        summary_on_top = input$summary_on_top,
        error_color_mode = input$error_color_mode,
        error_color = input$error_color,
        error_width = input$error_width,
        error_line_width = input$error_line_width,
        y_break_enabled = input$y_break_enabled,
        y_breaks_auto = input$y_breaks_auto,
        y_breaks_step = input$y_breaks_step,
        y_break_from = input$y_break_from,
        y_break_to = input$y_break_to,
        y_break_space = input$y_break_space,
        y_break_symbol = input$y_break_symbol,
        legend_pos = input$legend_pos,
        legend_key_width = input$legend_key_width,
        facet_spacing_x = input$facet_spacing_x,
        sticky_plot = input$sticky_plot
      )
    )
  })

  parse_style_tree <- function(x, kind) {
    out <- list(); if (is.null(x) || !length(x)) return(out)
    for (vn in names(x)) {
      br <- list(); src <- x[[vn]]
      for (lv in names(src)) {
        z <- unlist(src[[lv]], use.names = FALSE)
        if (!length(z)) next
        br[[lv]] <- if (identical(kind, "shape")) {
          q <- suppressWarnings(as.numeric(z[[1]])); if (is.finite(q)) q else 16
        } else as.character(z[[1]])
      }
      out[[vn]] <- br
    }
    out
  }

  legacy_mapping_vars <- function(mapping = NULL) {
    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(mapping)) {
      cv <- if (!is.null(d)) resolve_color_var(d) else ""
      lv <- if (!is.null(d)) resolve_linetype_var(d) else ""
      sv <- if (!is.null(d)) resolve_shape_var(d) else ""
    } else {
      cv <- json_chr(mapping$color); if (!nzchar(cv)) cv <- json_chr(mapping$series)
      lm <- json_chr(mapping$linetype, "__color__"); lv <- if (identical(lm,"__color__")) cv else lm
      sm <- json_chr(mapping$shape, "__color__"); sv <- if (identical(sm,"__color__")) cv else sm
    }
    list(color=cv, linetype=lv, shape=sv)
  }

  json_safe_tree <- function(x) {
    # jsonliteのkeep_vec_names warningを避ける。
    # JSON objectとして保持したいnamed atomic vectorはnamed listへ変換する。
    if (is.data.frame(x)) {
      return(x)
    }

    if (is.atomic(x) && !is.null(names(x))) {
      nm <- names(x)
      if (length(nm) && any(nzchar(nm))) {
        out <- as.list(unname(x))
        names(out) <- nm
        return(out)
      }
      return(unname(x))
    }

    if (is.list(x)) {
      out <- lapply(x, json_safe_tree)
      names(out) <- names(x)
      return(out)
    }

    x
  }

  output$download_style <- downloadHandler(
    filename = function() paste0("ggplot_style_", Sys.Date(), ".json"),
    content = function(file) {
      jsonlite::write_json(json_safe_tree(style_settings()), file, pretty = TRUE, auto_unbox = TRUE)
    }
  )

  apply_style_config <- function(cfg, success_message = "書式を適用しました。") {
    restoring_style_state(TRUE)
    restore_release_scheduled <- FALSE
    on.exit({
      # If any schema/type error occurs before the normal onFlushed release is
      # scheduled, never leave this Graph permanently frozen in restore mode.
      if (!isTRUE(restore_release_scheduled)) restoring_style_state(FALSE)
    }, add = TRUE)

    if (!is.null(cfg$color_styles)) color_styles(parse_style_tree(cfg$color_styles, "color"))
    if (!is.null(cfg$linetype_styles)) linetype_styles(parse_style_tree(cfg$linetype_styles, "linetype"))
    if (!is.null(cfg$shape_styles)) shape_styles(parse_style_tree(cfg$shape_styles, "shape"))
    if (is.null(cfg$color_styles) && !is.null(cfg$group_styles) && length(cfg$group_styles)) {
      mv <- legacy_mapping_vars(NULL)
      migrate_legacy_group_styles(cfg$group_styles, mv$color, mv$linetype, mv$shape)
    }

    if (!is.null(cfg$series_styles) && length(cfg$series_styles)) {
      ss <- list()
      for (nm in names(cfg$series_styles)) {
        st <- cfg$series_styles[[nm]]
        ss[[nm]] <- list(color = as.character(st$color %||% "#333333"))
      }
      series_styles(ss)
    }

    if (!is.null(cfg$regression_styles) && length(cfg$regression_styles)) {
      rs <- list()
      for (nm in names(cfg$regression_styles)) {
        st <- cfg$regression_styles[[nm]]
        rs[[nm]] <- list(
          color = json_chr(st$color, "#333333"),
          linetype = json_chr(st$linetype, "solid"),
          width = as.numeric(json_chr(st$width, "0.9"))
        )
      }
      regression_styles(rs)
    }

    if (!is.null(cfg$raw_group_colors) && length(cfg$raw_group_colors)) {
      # v3.1+: variable -> level -> color. Legacy flat level -> color is migrated.
      first_val <- cfg$raw_group_colors[[1]]
      if (is.list(first_val) && !is.null(names(first_val))) {
        raw_group_colors(parse_style_tree(cfg$raw_group_colors, "color"))
      } else {
        mv <- legacy_mapping_vars(NULL); rc <- list(); br <- list()
        for (nm in names(cfg$raw_group_colors)) br[[nm]] <- as.character(unlist(cfg$raw_group_colors[[nm]])[[1]])
        if (nzchar(mv$color)) rc[[mv$color]] <- br
        raw_group_colors(rc)
      }
    }

    if (!is.null(cfg$orders)) {
      os <- list(x = list(), group = list(), facet = list())
      if (!is.null(cfg$orders$x)) os$x <- cfg$orders$x
      if (!is.null(cfg$orders$group)) os$group <- cfg$orders$group
      if (!is.null(cfg$orders$facet)) os$facet <- cfg$orders$facet
      order_state(os)
    }

    if (!is.null(cfg$legend_titles)) {
      lt <- list()
      for (nm in names(cfg$legend_titles)) {
        lt[[nm]] <- json_chr(cfg$legend_titles[[nm]], "")
      }
      legend_titles(lt)
    }

    if (!is.null(cfg$level_labels)) {
      ll <- list()
      for (vn in names(cfg$level_labels)) {
        branch <- cfg$level_labels[[vn]]
        bb <- list()
        for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
        ll[[vn]] <- bb
      }
      level_labels(ll)
    }

    a <- cfg$appearance
    if (!is.null(a)) {
      if (!is.null(a$series_style_override)) updateCheckboxInput(session, "series_style_override", value = isTRUE(a$series_style_override))
      if (!is.null(a$palette_preset)) updateSelectInput(session, "palette_preset", selected = json_chr(a$palette_preset))
      if (!is.null(a$raw_palette_preset)) updateSelectInput(session, "raw_palette_preset", selected = json_chr(a$raw_palette_preset))
      if (!is.null(a$scatter_regression)) updateCheckboxInput(session, "scatter_regression", value = isTRUE(a$scatter_regression))
      if (!is.null(a$scatter_regression_group)) updateSelectInput(session, "scatter_regression_group", selected = json_chr(a$scatter_regression_group))
      if (!is.null(a$scatter_regression_color)) colourpicker::updateColourInput(session, "scatter_regression_color", value = json_chr(a$scatter_regression_color))
      if (!is.null(a$scatter_regression_linetype)) updateSelectInput(session, "scatter_regression_linetype", selected = json_chr(a$scatter_regression_linetype))
      if (!is.null(a$scatter_regression_width)) updateSliderInput(session, "scatter_regression_width", value = as.numeric(a$scatter_regression_width))
      if (!is.null(a$scatter_regression_se)) updateCheckboxInput(session, "scatter_regression_se", value = isTRUE(a$scatter_regression_se))
      if (!is.null(a$scatter_regression_se_alpha)) updateSliderInput(session, "scatter_regression_se_alpha", value = as.numeric(a$scatter_regression_se_alpha))
      if (!is.null(a$theme)) updateSelectInput(session, "theme", selected = a$theme)
      if (!is.null(a$font_family_mode)) updateSelectInput(session, "font_family_mode", selected = json_chr(a$font_family_mode))
      if (!is.null(a$font_family_custom)) updateTextInput(session, "font_family_custom", value = json_chr(a$font_family_custom))
      if (!is.null(a$base_size)) updateSliderInput(session, "base_size", value = as.numeric(a$base_size))
      if (!is.null(a$summary_type)) updateSelectInput(session, "summary_type", selected = a$summary_type)
      if (!is.null(a$summary_unit)) {
        updateRadioButtons(session, "summary_unit", selected = json_chr(a$summary_unit, "row"))
      }
      if (!is.null(a$mean_color_mode)) {
        colourpicker::updateColourInput(session, "mean_color_mode", value = normalise_colour(a$mean_color_mode, "#000000"))
      }
      if (!is.null(a$mean_linetype)) updateSelectInput(session, "mean_linetype", selected = a$mean_linetype)
      if (!is.null(a$mean_shape)) updateSelectInput(session, "mean_shape", selected = as.character(a$mean_shape))
      if (!is.null(a$point_size)) updateSliderInput(session, "point_size", value = as.numeric(a$point_size))
      if (!is.null(a$line_width)) updateSliderInput(session, "line_width", value = as.numeric(a$line_width))
      if (!is.null(a$line_group_dodge)) updateSliderInput(session, "line_group_dodge", value = as.numeric(a$line_group_dodge))
      if (!is.null(a$line_x_spacing)) updateSliderInput(session, "line_x_spacing", value = as.numeric(a$line_x_spacing))
      if (!is.null(a$plot_width_px)) {
        pw <- safe_num1(a$plot_width_px, NA_real_)
        updateNumericInput(session, "plot_width_px_direct", value = pw)
        if (is.finite(pw) && pw >= 300 && pw <= 1400) updateSliderInput(session, "plot_width_px", value = pw)
      }
      if (!is.null(a$plot_height_px)) {
        ph <- safe_num1(a$plot_height_px, NA_real_)
        updateNumericInput(session, "plot_height_px_direct", value = ph)
        if (is.finite(ph) && ph >= 220 && ph <= 900) updateSliderInput(session, "plot_height_px", value = ph)
      }
      if (!is.null(a$bar_width)) updateSliderInput(session, "bar_width", value = as.numeric(a$bar_width))
      if (!is.null(a$bar_zero_touch)) updateCheckboxInput(session, "bar_zero_touch", value = isTRUE(a$bar_zero_touch))
      if (!is.null(a$group_spacing)) updateSliderInput(session, "group_spacing", value = as.numeric(a$group_spacing))
      if (!is.null(a$box_width_scale)) updateSliderInput(session, "box_width_scale", value = as.numeric(a$box_width_scale))
      if (!is.null(a$x_category_spacing)) updateSliderInput(session, "x_category_spacing", value = as.numeric(a$x_category_spacing))
      updateRadioButtons(session, "bar_border_mode", selected = json_chr(a$bar_border_mode, "fixed"))
      if (!is.null(a$bar_border_color)) {
        colourpicker::updateColourInput(session, "bar_border_color", value = normalise_colour(a$bar_border_color, "#000000"))
      }
      if (!is.null(a$bar_border_width)) updateSliderInput(session, "bar_border_width", value = as.numeric(a$bar_border_width))
      if (!is.null(a$raw_fixed_custom)) colourpicker::updateColourInput(session, "raw_fixed_custom", value = normalise_colour(a$raw_fixed_custom, "#555555"))
      if (!is.null(a$raw_color_mode)) {
        raw_mode_saved <- json_chr(a$raw_color_mode, "group_light")
        if (raw_mode_saved %in% c("black", "gray30", "white", "red3", "blue3", "darkgreen")) {
          updateSelectInput(session, "raw_color_mode", selected = "custom_fixed")
          colourpicker::updateColourInput(session, "raw_fixed_custom", value = normalise_colour(raw_mode_saved, "#555555"))
        } else {
          updateSelectInput(session, "raw_color_mode", selected = raw_mode_saved)
        }
      }
      if (!is.null(a$raw_lighten)) updateSliderInput(session, "raw_lighten", value = as.numeric(a$raw_lighten))
      if (!is.null(a$raw_alpha)) updateSliderInput(session, "raw_alpha", value = as.numeric(a$raw_alpha))
      if (!is.null(a$raw_shape_mode)) updateSelectInput(session, "raw_shape_mode", selected = a$raw_shape_mode)
      if (!is.null(a$raw_shape)) updateSelectInput(session, "raw_shape", selected = as.character(a$raw_shape))
      if (!is.null(a$raw_point_size)) updateSliderInput(session, "raw_point_size", value = as.numeric(a$raw_point_size))
      if (!is.null(a$jitter_width)) updateSliderInput(session, "jitter_width", value = as.numeric(a$jitter_width))
      if (!is.null(a$id_line_color_mode)) {
        id_mode_saved <- json_chr(a$id_line_color_mode, "group_light")
        if (id_mode_saved %in% c("black", "gray30", "gray50", "white", "red3", "blue3", "darkgreen")) {
          updateSelectInput(session, "id_line_color_mode", selected = "custom_fixed")
          colourpicker::updateColourInput(session, "id_line_custom_color", value = normalise_colour(id_mode_saved, "#4D4D4D"))
        } else {
          updateSelectInput(session, "id_line_color_mode", selected = id_mode_saved)
        }
      }
      if (!is.null(a$id_line_custom_color)) colourpicker::updateColourInput(session, "id_line_custom_color", value = normalise_colour(a$id_line_custom_color, "#4D4D4D"))
      if (!is.null(a$id_line_lighten)) updateSliderInput(session, "id_line_lighten", value = as.numeric(a$id_line_lighten))
      if (!is.null(a$id_linetype)) updateSelectInput(session, "id_linetype", selected = a$id_linetype)
      if (!is.null(a$id_line_width)) updateSliderInput(session, "id_line_width", value = as.numeric(a$id_line_width))
      if (!is.null(a$id_line_alpha)) updateSliderInput(session, "id_line_alpha", value = as.numeric(a$id_line_alpha))
      if (!is.null(a$summary_on_top)) updateCheckboxInput(session, "summary_on_top", value = isTRUE(a$summary_on_top))
      if (!is.null(a$error_color_mode)) updateSelectInput(session, "error_color_mode", selected = a$error_color_mode)
      if (!is.null(a$error_color)) colourpicker::updateColourInput(session, "error_color", value = a$error_color)
      if (!is.null(a$error_width)) updateSliderInput(session, "error_width", value = as.numeric(a$error_width))
      if (!is.null(a$error_line_width)) updateSliderInput(session, "error_line_width", value = as.numeric(a$error_line_width))
      if (!is.null(a$y_break_enabled)) updateCheckboxInput(session, "y_break_enabled", value = isTRUE(a$y_break_enabled))
      if (!is.null(a$y_breaks_auto)) updateCheckboxInput(session, "y_breaks_auto", value = isTRUE(a$y_breaks_auto))
      if (!is.null(a$y_breaks_step)) updateNumericInput(session, "y_breaks_step", value = as.numeric(a$y_breaks_step))
      if (!is.null(a$y_break_from)) updateNumericInput(session, "y_break_from", value = as.numeric(a$y_break_from))
      if (!is.null(a$y_break_to)) updateNumericInput(session, "y_break_to", value = as.numeric(a$y_break_to))
      if (!is.null(a$y_break_space)) updateSliderInput(session, "y_break_space", value = as.numeric(a$y_break_space))
      if (!is.null(a$y_break_symbol)) updateCheckboxInput(session, "y_break_symbol", value = isTRUE(a$y_break_symbol))
      if (!is.null(a$legend_pos)) updateSelectInput(session, "legend_pos", selected = a$legend_pos)
      if (!is.null(a$legend_key_width)) {
        updateSliderInput(
          session, "legend_key_width",
          value = as.numeric(a$legend_key_width)
        )
      }
      if (!is.null(a$facet_spacing_x)) {
        updateSliderInput(session, "facet_spacing_x", value = as.numeric(a$facet_spacing_x))
      }
      if (!is.null(a$sticky_plot)) updateCheckboxInput(session, "sticky_plot", value = isTRUE(a$sticky_plot))
    }

    style_restore_epoch(isolate(style_restore_epoch()) + 1L)
    restore_release_scheduled <- TRUE
    session$onFlushed(function() {
      restoring_style_state(FALSE)
      showNotification(success_message, type = "message")
    }, once = TRUE)
    invisible(TRUE)
  }

  observeEvent(input$upload_style, {
    req(input$upload_style$datapath)

    cfg <- tryCatch(
      jsonlite::read_json(input$upload_style$datapath, simplifyVector = FALSE),
      error = function(e) {
        showNotification(
          paste0("設定ファイルを読み込めませんでした: ", conditionMessage(e)),
          type = "error", duration = 5
        )
        NULL
      }
    )
    if (is.null(cfg)) {
      restoring_style_state(FALSE)
      return(invisible(NULL))
    }

    apply_style_config(cfg, "設定を読み込みました。")
  })

  observeEvent(input$copy_style, {
    style_clipboard(isolate(style_settings()))
    showNotification(
      "このGraphの書式をコピーしました。別のGraph / Projectで「書式を貼り付け」を押せます。",
      type = "message", duration = 4
    )
  })

  observeEvent(input$paste_style, {
    cfg <- isolate(style_clipboard())
    if (is.null(cfg)) {
      showNotification(
        "コピーされた書式がありません。先にコピー元Graphで「書式をコピー」を押してください。",
        type = "warning", duration = 5
      )
      return(invisible(NULL))
    }

    apply_style_config(cfg, "書式を貼り付けました。Data / Mapping / Statisticsは変更していません。")
  })

  # local null-coalescing helper used above
  `%||%` <- function(a, b) if (is.null(a)) b else a

  # Project読込は動的UIの再生成をまたぐため、段階的に復元する。
  pending_project <- reactiveVal(NULL)
  project_restore_stage <- reactiveVal(0)
  project_restore_wait_count <- reactiveVal(0L)
  project_restore_wait_limit <- 120L  # 75 ms × 120 ≈ 9 seconds per stage

  abort_project_restore <- function(message) {
    project_restore_stage(0)
    project_restore_wait_count(0L)
    pending_project(NULL)
    initial_restore_done(TRUE)
    deferred_initial_state(NULL)
    restoring_style_state(FALSE)
    restore_notify(FALSE)
    showNotification(
      paste0("Graph設定の復元を中止しました: ", message),
      type = "error", duration = 8
    )
    invisible(FALSE)
  }

  restore_wait <- function(message) {
    n <- isolate(project_restore_wait_count()) + 1L
    project_restore_wait_count(n)
    if (n >= project_restore_wait_limit) {
      abort_project_restore(message)
      return(FALSE)
    }
    TRUE
  }

  # Project全体から渡されたinitial_stateは、必要になるまで復元しない。
  # 表示中Graphを先に復元し、残りはProject Managerが順次activateする。
  deferred_initial_state <- reactiveVal(initial_state)
  initial_restore_started <- reactiveVal(is.null(initial_state))
  initial_restore_done <- reactiveVal(is.null(initial_state))
  restore_notify <- reactiveVal(FALSE)
  plot_drawn <- reactiveVal(FALSE)

  # Dynamic Style UIは復元中に一度古い/default input値を持つことがある。
  # その値が保存済みstyleを逆上書きしないよう、復元完了flushまでobserverを止める。
  restoring_style_state <- reactiveVal(FALSE)
  style_restore_epoch <- reactiveVal(0L)


  json_chr <- function(x, default = "") {
    if (is.null(x)) return(default)
    z <- unlist(x, use.names = FALSE)
    if (!length(z)) return(default)
    as.character(z[[1]])
  }

  json_vec <- function(x) {
    if (is.null(x)) return(character(0))
    as.character(unlist(x, use.names = FALSE))
  }

  normalize_order_tree <- function(x) {
    out <- list(x = list(), group = list(), facet = list())
    if (is.null(x)) return(out)

    for (kind in c("x", "group", "facet")) {
      branch <- x[[kind]]
      if (is.null(branch)) next
      for (nm in names(branch)) {
        out[[kind]][[nm]] <- json_vec(branch[[nm]])
      }
    }
    out
  }


  # ------------------------------------------------------------
  # Fast seed: Projectから生成したmoduleでは、画面UIの復元より先に
  # Plotに使う内部Style / order stateだけを保存値で初期化する。
  # これにより復元途中にdefault paletteでPlotが作られるのを防ぐ。
  # ------------------------------------------------------------
  seed_internal_state <- function(cfg) {
    if (is.null(cfg)) return(invisible(FALSE))

    st <- cfg$style
    if (!is.null(st)) {
      if (!is.null(st$color_styles)) color_styles(parse_style_tree(st$color_styles, "color"))
      if (!is.null(st$linetype_styles)) linetype_styles(parse_style_tree(st$linetype_styles, "linetype"))
      if (!is.null(st$shape_styles)) shape_styles(parse_style_tree(st$shape_styles, "shape"))
      if (is.null(st$color_styles) && !is.null(st$group_styles) && length(st$group_styles)) {
        mv <- legacy_mapping_vars(cfg$mapping)
        migrate_legacy_group_styles(st$group_styles, mv$color, mv$linetype, mv$shape)
      }

      if (!is.null(st$series_styles) && length(st$series_styles)) {
        ss <- list()
        for (nm in names(st$series_styles)) {
          z <- st$series_styles[[nm]]
          col <- json_chr(z$color, "#333333")
          ss[[nm]] <- list(color = col)
        }
        series_styles(ss)
      }

      if (!is.null(st$regression_styles) && length(st$regression_styles)) {
        rs <- list()
        for (nm in names(st$regression_styles)) {
          z <- st$regression_styles[[nm]]
          rs[[nm]] <- list(
            color = json_chr(z$color, "#333333"),
            linetype = json_chr(z$linetype, "solid"),
            width = suppressWarnings(as.numeric(json_chr(z$width, "1")))
          )
        }
        regression_styles(rs)
      }

      if (!is.null(st$raw_group_colors) && length(st$raw_group_colors)) {
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

      if (!is.null(st$orders)) {
        order_state(normalize_order_tree(st$orders))
      }

      if (!is.null(st$legend_titles)) {
        lt <- list()
        for (nm in names(st$legend_titles)) {
          lt[[nm]] <- json_chr(st$legend_titles[[nm]], "")
        }
        legend_titles(lt)
      }

      if (!is.null(st$level_labels)) {
        ll <- list()
        for (vn in names(st$level_labels)) {
          branch <- st$level_labels[[vn]]
          bb <- list()
          for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
          ll[[vn]] <- bb
        }
        level_labels(ll)
      }
    }

    invisible(TRUE)
  }

  # initial_stateがあるGraphはmodule生成時点で内部stateを先にhydrate。
  # UI inputの段階復元は後で行う。
  if (!is.null(initial_state)) {
    seed_internal_state(initial_state)
  }

  mapping_matches_project <- function(cfg) {
    mp <- cfg$mapping
    if (is.null(mp)) return(TRUE)

    target_plot_type <- json_chr(cfg$plot$type, input$plot_type %||% "line")
    if (identical(target_plot_type, "violin")) target_plot_type <- "box"

    expected <- c(
      x = json_chr(mp$x),
      y = json_chr(mp$y),
      color = json_chr(mp$color),
      shape = json_chr(mp$shape, "__color__"),
      id = json_chr(mp$id),
      facet = json_chr(mp$facet)
    )
    actual <- c(
      x = input$xvar %||% "",
      y = input$yvar %||% "",
      color = input$colorvar %||% "",
      shape = input$shapevar %||% "__color__",
      id = input$idvar %||% "",
      facet = input$facetvar %||% ""
    )

    if (target_plot_type %in% c("line", "bar", "box")) {
      expected_position <- json_chr(mp$position, json_chr(mp$series))
      actual_position <- input$groupvar %||% ""

      # dynamic UIのinputがまだbrowserから返っていない間はseedを利用してよい。
      # ただしseed解除はmapping_matches_project()では行わない。
      if (!identical(actual_position, expected_position) &&
          !is.null(restore_position_seed())) {
        seeded_position <- as.character(restore_position_seed())[1]
        if (identical(seeded_position, expected_position)) {
          actual_position <- seeded_position
        }
      }

      expected <- c(expected, position = expected_position)
      actual <- c(actual, position = actual_position)
    }

    if (target_plot_type %in% c("line", "scatter")) {
      expected_linetype <- json_chr(mp$linetype, "__color__")
      actual_linetype <- input$linetypevar %||% "__color__"

      if (!identical(actual_linetype, expected_linetype) &&
          !is.null(restore_linetype_seed())) {
        seeded_linetype <- as.character(restore_linetype_seed())[1]
        if (identical(seeded_linetype, expected_linetype)) {
          actual_linetype <- seeded_linetype
        }
      }

      expected <- c(expected, linetype = expected_linetype)
      actual <- c(actual, linetype = actual_linetype)
    }

    all(as.character(actual[names(expected)]) == as.character(expected))
  }



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

  # Dynamic ANOVA UI (1/2/3-factor design choices) must not depend on the
  # browser radio input arriving in the same flush. Keep an R-side source of
  # truth so Project restore / Analysis switching can rebuild the correct UI
  # immediately and deterministically.
  stats_ui_factor_n <- reactiveVal("two")

  # Project読込時はStatistics UIをGraph復元と同時に触らない。
  # recipe本体だけ保持し、Statisticsタブを開いた時にUIへ反映する。
  pending_stats_ui_restore <- reactiveVal(NULL)

  stats_new_id <- function() {
    paste0("analysis_", as.integer(Sys.time()), "_", sample.int(99999, 1))
  }

  stats_default_recipe <- function(name = NULL) {
    if (is.null(name)) {
      name <- paste0("Analysis ", length(isolate(stats_recipes())) + 1L)
    }
    list(
      name = name,
      type = "anova",
      data_source = "graph",
      custom_data = "",
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

  normalize_stats_recipe <- function(r, fallback_name = "Analysis") {
    if (is.null(r) || !is.list(r)) r <- list()

    out <- stats_default_recipe(name = stats_scalar_chr(r$name, fallback_name))

    # Character/scalar fields
    chr_fields <- c(
      "name", "type", "data_source", "custom_data", "factor_n",
      "design_one", "design_two", "design_three",
      "alpha", "df_adjust", "multcomp",
      "anova_id", "anova_dv", "anova_f1", "anova_f2", "anova_f3", "anova_split",
      "ttest_type", "ttest_group", "ttest_dv", "ttest_x", "ttest_y",
      "cor_method", "cor_x", "cor_y", "cor_group"
    )
    for (nm in chr_fields) {
      if (!is.null(r[[nm]])) out[[nm]] <- stats_scalar_chr(r[[nm]], out[[nm]])
    }

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

  normalize_stats_recipes <- function(rr) {
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
        fallback_name = paste0("Analysis ", i)
      )
    }

    out
  }

  stats_custom_parsed_data <- reactive({
    txt <- input$stats_custom_data %||% ""
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

  stats_source_data <- reactive({
    if (identical(input$stats_data_source %||% "graph", "custom")) {
      return(stats_custom_parsed_data())
    }

    # t検定・相関は現在のGraph描画用データ（Wide→Long後を含む）を使う。
    dat()
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
        if (identical(r$data_source %||% "graph", "graph")) {
          "Data: current Graph data"
        } else {
          "Data: custom data"
        }
      )
    )
  })


  observeEvent(input$stats_factor_n, {
    # Normal user operation: radioButtons -> dynamic ANOVA UI.
    # During recipe restoration, load_stats_recipe() already sets the correct
    # R-side value synchronously; ignore transient browser values until restore ends.
    if (isTRUE(isolate(stats_restoring()))) return()
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

    # Graph mapping is used only as an initial suggestion.
    id_guess <- isolate(input$idvar %||% "")
    if (!nzchar(id_guess) || !id_guess %in% cols) {
      id_names <- cols[tolower(cols) %in% c(
        "id", "subject", "subjectid", "subject_id",
        "rat", "ratid", "rat_id"
      )]
      id_guess <- if (length(id_names)) id_names[1] else ""
    }

    dv_guess <- isolate(input$yvar %||% "")
    if (!nzchar(dv_guess) || !dv_guess %in% cols) {
      dv_guess <- if (length(cols)) cols[length(cols)] else ""
    }

    candidate_factors <- unique(c(
      isolate(input$colorvar %||% ""),
      isolate(input$xvar %||% ""),
      isolate(input$groupvar %||% ""),
      isolate(input$facetvar %||% ""),
      cols
    ))
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
      if (isTRUE(isolate(stats_restoring()))) {
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

  load_stats_recipe <- function(id) {
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return(invisible(FALSE))

    r <- rr[[id]]

    # Restore generation token:
    # rapid Analysis switching can leave queued onFlushed callbacks from the
    # previous Analysis. Only callbacks carrying the latest token may apply.
    token <- paste0(
      id, "::",
      format(Sys.time(), "%Y%m%d%H%M%OS6"), "::",
      sample.int(999999L, 1L)
    )
    stats_restore_token(token)
    stats_restoring(TRUE)
    stats_selected_id(id)

    # Rebuild factor-plan UI from the selected recipe immediately on the R side.
    # Do this before the browser receives updateRadioButtons().
    factor_n_saved <- r$factor_n %||% "two"
    if (!factor_n_saved %in% c("one", "two", "three")) factor_n_saved <- "two"
    stats_ui_factor_n(factor_n_saved)

    token_is_current <- function() {
      identical(isolate(stats_restore_token()), token) &&
        identical(isolate(stats_selected_id()), id)
    }

    # Static controls first. Dynamic ANOVA mapping UI will be rebuilt from the
    # selected recipe after factor_n/type changes reach the browser.
    updateTextInput(session, "stats_name", value = r$name %||% "")
    updateSelectInput(session, "stats_type", selected = r$type %||% "anova")
    updateRadioButtons(session, "stats_data_source", selected = r$data_source %||% "graph")
    shinyAce::updateAceEditor(session, "stats_custom_data", value = r$custom_data %||% "")
    updateRadioButtons(session, "stats_factor_n", selected = r$factor_n %||% "two")
    updateRadioButtons(session, "stats_alpha", selected = r$alpha %||% "0.05")
    updateRadioButtons(session, "stats_df_adjust", selected = r$df_adjust %||% "none")
    updateRadioButtons(session, "stats_multcomp", selected = r$multcomp %||% "holm")
    updateRadioButtons(session, "stats_ttest_type", selected = r$ttest_type %||% "welch")
    updateRadioButtons(session, "stats_cor_method", selected = r$cor_method %||% "pearson")

    # First flush: factor_n/type change has rebuilt the dynamic UI.
    session$onFlushed(function() {
      if (!token_is_current()) return()

      rr2 <- isolate(stats_recipes())
      if (!id %in% names(rr2)) {
        if (token_is_current()) stats_restoring(FALSE)
        return()
      }
      r2 <- rr2[[id]]

      # ANOVA design + mapping + level count.
      if (identical(r2$factor_n %||% "two", "one")) {
        updateSelectInput(session, "stats_design_one", selected = r2$design_one %||% "Between")
      } else if (identical(r2$factor_n %||% "two", "two")) {
        updateSelectInput(session, "stats_design_two", selected = r2$design_two %||% "F1B_F2W")
      } else {
        updateSelectInput(session, "stats_design_three", selected = r2$design_three %||% "F1B_F2W_F3W")
      }

      updateNumericInput(session, "stats_factor1_level", value = as.numeric(r2$factor1_level %||% 2))
      updateNumericInput(session, "stats_factor2_level", value = as.numeric(r2$factor2_level %||% 3))
      updateNumericInput(session, "stats_factor3_level", value = as.numeric(r2$factor3_level %||% 3))

      updateSelectInput(session, "stats_anova_id", selected = r2$anova_id %||% "")
      updateSelectInput(session, "stats_anova_dv", selected = r2$anova_dv %||% "")
      updateSelectInput(session, "stats_anova_f1", selected = r2$anova_f1 %||% "")
      updateSelectInput(session, "stats_anova_f2", selected = r2$anova_f2 %||% "")
      updateSelectInput(session, "stats_anova_f3", selected = r2$anova_f3 %||% "")
      updateSelectInput(session, "stats_anova_split", selected = r2$anova_split %||% "")

      updateSelectInput(session, "stats_ttest_group", selected = r2$ttest_group %||% "")
      updateSelectInput(session, "stats_ttest_dv", selected = r2$ttest_dv %||% "")
      updateSelectInput(session, "stats_ttest_x", selected = r2$ttest_x %||% "")
      updateSelectInput(session, "stats_ttest_y", selected = r2$ttest_y %||% "")

      updateSelectInput(session, "stats_cor_x", selected = r2$cor_x %||% "")
      updateSelectInput(session, "stats_cor_y", selected = r2$cor_y %||% "")
      updateSelectInput(session, "stats_cor_group", selected = r2$cor_group %||% "")

      # Second flush: values above have reached the dynamic inputs.
      # Apply once more, then and only then release the save guard.
      session$onFlushed(function() {
        if (!token_is_current()) return()

        rr3 <- isolate(stats_recipes())
        if (!id %in% names(rr3)) {
          if (token_is_current()) stats_restoring(FALSE)
          return()
        }
        r3 <- rr3[[id]]

        if (identical(r3$factor_n %||% "two", "one")) {
          updateSelectInput(session, "stats_design_one", selected = r3$design_one %||% "Between")
        } else if (identical(r3$factor_n %||% "two", "two")) {
          updateSelectInput(session, "stats_design_two", selected = r3$design_two %||% "F1B_F2W")
        } else {
          updateSelectInput(session, "stats_design_three", selected = r3$design_three %||% "F1B_F2W_F3W")
        }

        updateNumericInput(session, "stats_factor1_level", value = as.numeric(r3$factor1_level %||% 2))
        updateNumericInput(session, "stats_factor2_level", value = as.numeric(r3$factor2_level %||% 3))
        updateNumericInput(session, "stats_factor3_level", value = as.numeric(r3$factor3_level %||% 3))

        updateSelectInput(session, "stats_anova_id", selected = r3$anova_id %||% "")
        updateSelectInput(session, "stats_anova_dv", selected = r3$anova_dv %||% "")
        updateSelectInput(session, "stats_anova_f1", selected = r3$anova_f1 %||% "")
        updateSelectInput(session, "stats_anova_f2", selected = r3$anova_f2 %||% "")
        updateSelectInput(session, "stats_anova_f3", selected = r3$anova_f3 %||% "")
        updateSelectInput(session, "stats_anova_split", selected = r3$anova_split %||% "")

        updateSelectInput(session, "stats_ttest_group", selected = r3$ttest_group %||% "")
        updateSelectInput(session, "stats_ttest_dv", selected = r3$ttest_dv %||% "")
        updateSelectInput(session, "stats_ttest_x", selected = r3$ttest_x %||% "")
        updateSelectInput(session, "stats_ttest_y", selected = r3$ttest_y %||% "")

        updateSelectInput(session, "stats_cor_x", selected = r3$cor_x %||% "")
        updateSelectInput(session, "stats_cor_y", selected = r3$cor_y %||% "")
        updateSelectInput(session, "stats_cor_group", selected = r3$cor_group %||% "")

        lv3 <- r3$cor_levels
        if (!is.null(lv3) && length(lv3)) {
          updateCheckboxGroupInput(
            session,
            "stats_cor_levels",
            selected = as.character(unlist(lv3, use.names = FALSE))
          )
        }

        # A final flush is needed because update*Input() messages above are
        # delivered after this callback. Keep stats_restoring TRUE until then,
        # otherwise the autosave observer can capture a mixed old/new state.
        session$onFlushed(function() {
          if (!token_is_current()) return()

          rr4 <- isolate(stats_recipes())
          if (id %in% names(rr4)) {
            fn4 <- rr4[[id]]$factor_n %||% "two"
            if (!fn4 %in% c("one", "two", "three")) fn4 <- "two"
            stats_ui_factor_n(fn4)
          }

          stats_restoring(FALSE)
        }, once = TRUE)
      }, once = TRUE)
    }, once = TRUE)

    invisible(TRUE)
  }

  save_current_stats_recipe <- function() {
    if (isTRUE(isolate(stats_restoring()))) return(invisible(FALSE))

    # Project読込後、保存recipeをStatistics UIへまだ適用していない間は、
    # 画面上のdefault値（Type=ANOVA等）をrecipeへ書き戻さない。
    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) {
      return(invisible(FALSE))
    }

    id <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return(invisible(FALSE))

    r <- rr[[id]]

    nm <- trimws(input$stats_name %||% r$name %||% "Analysis")
    if (!nzchar(nm)) nm <- "Analysis"

    r$name <- nm
    r$type <- input$stats_type %||% r$type
    r$data_source <- input$stats_data_source %||% r$data_source

    # current Graph data使用時は、以前貼り付けたcustom statistics dataを
    # Projectへ持ち回らない。
    if (identical(r$data_source %||% "graph", "custom")) {
      r$custom_data <- input$stats_custom_data %||% r$custom_data
    } else {
      r$custom_data <- ""
    }
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

    r$anova_id <- input$stats_anova_id %||% r$anova_id
    r$anova_dv <- input$stats_anova_dv %||% r$anova_dv
    r$anova_f1 <- input$stats_anova_f1 %||% r$anova_f1
    r$anova_f2 <- input$stats_anova_f2 %||% r$anova_f2
    r$anova_f3 <- input$stats_anova_f3 %||% r$anova_f3
    r$anova_split <- input$stats_anova_split %||% r$anova_split %||% ""

    r$ttest_type <- input$stats_ttest_type %||% r$ttest_type
    r$ttest_group <- input$stats_ttest_group %||% r$ttest_group
    r$ttest_dv <- input$stats_ttest_dv %||% r$ttest_dv
    r$ttest_x <- input$stats_ttest_x %||% r$ttest_x
    r$ttest_y <- input$stats_ttest_y %||% r$ttest_y

    r$cor_method <- input$stats_cor_method %||% r$cor_method
    r$cor_x <- input$stats_cor_x %||% r$cor_x
    r$cor_y <- input$stats_cor_y %||% r$cor_y
    r$cor_group <- input$stats_cor_group %||% r$cor_group %||% ""

    if (nzchar(r$cor_group %||% "")) {
      lv <- input$stats_cor_levels
      if (!is.null(lv)) r$cor_levels <- as.character(lv)
    } else {
      r$cor_levels <- character(0)
    }

    rr[[id]] <- r
    stats_recipes(rr)

    invisible(TRUE)
  }

  observeEvent(input$stats_add, {
    # invalidate any queued restore callbacks from the previously selected Analysis
    stats_restore_token(NULL)

    rr <- isolate(stats_recipes())
    id <- stats_new_id()
    rr[[id]] <- stats_default_recipe()
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

  observeEvent(input$graph_main_tab, {
    if (!identical(input$graph_main_tab, "Statistics")) return()

    id <- isolate(pending_stats_ui_restore())
    if (is.null(id) || !nzchar(id)) return()

    rr <- isolate(stats_recipes())
    if (!id %in% names(rr)) {
      pending_stats_ui_restore(NULL)
      return()
    }

    # Graph本体の復元が完了してからのみStatistics UIへrecipeを適用。
    if (!isTRUE(isolate(initial_restore_done())) ||
        isolate(project_restore_stage()) != 0) {
      return()
    }

    # load_stats_recipe() は冒頭で stats_restoring(TRUE) にする。
    # 先に復元処理へ入り、その後pendingを解除して、
    # default UIがrecipeへ割り込んで保存される隙間を作らない。
    load_stats_recipe(id)
    pending_stats_ui_restore(NULL)
  }, ignoreInit = TRUE)

  observeEvent(input$stats_name, {
    if (isTRUE(stats_restoring())) return()

    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return()

    id <- isolate(stats_selected_id())
    rr <- isolate(stats_recipes())
    if (is.null(id) || !id %in% names(rr)) return()

    nm <- trimws(input$stats_name %||% "")
    if (!nzchar(nm)) return()

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

    # Project読込後のlazy restore待ちでは、static UIの初期値を無視する。
    pending_id <- pending_stats_ui_restore()
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) return()

    input$stats_type
    input$stats_data_source
    input$stats_custom_data
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
      "current Graph data"
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

  stats_auto_result <- reactive({
    req(stats_selected_id())

    # Graph本体のProject復元が完全に終わるまではStatisticsを動かさない。
    req(isTRUE(initial_restore_done()))
    req(project_restore_stage() == 0)

    # Statisticsタブを実際に開いている時だけ計算する。
    req(identical(input$graph_main_tab, "Statistics"))

    # recipe復元の途中では中途半端な設定で計算しない。
    req(!isTRUE(stats_restoring()))

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
    stats_auto_result_debounced()
  })


  stats_recipes_for_project <- function() {
    rr <- isolate(stats_recipes())
    if (!length(rr)) return(rr)

    # During an active restore, stored recipes are the authoritative state.
    if (isTRUE(isolate(stats_restoring()))) return(rr)

    pending_id <- isolate(pending_stats_ui_restore())
    if (!is.null(pending_id) && length(pending_id) == 1L && nzchar(pending_id)) {
      return(rr)
    }

    id <- isolate(stats_selected_id())
    if (is.null(id) || !id %in% names(rr)) return(rr)

    r <- rr[[id]]

    # Capture exactly what is visibly configured in the selected Analysis at
    # Project-save time, rather than waiting for the autosave observer.
    r$name <- trimws(input$stats_name %||% r$name %||% "Analysis")
    if (!nzchar(r$name)) r$name <- "Analysis"

    r$type <- input$stats_type %||% r$type
    r$data_source <- input$stats_data_source %||% r$data_source
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

    r$anova_id <- input$stats_anova_id %||% r$anova_id
    r$anova_dv <- input$stats_anova_dv %||% r$anova_dv
    r$anova_f1 <- input$stats_anova_f1 %||% r$anova_f1
    r$anova_f2 <- input$stats_anova_f2 %||% r$anova_f2
    r$anova_f3 <- input$stats_anova_f3 %||% r$anova_f3
    r$anova_split <- input$stats_anova_split %||% r$anova_split %||% ""

    r$ttest_type <- input$stats_ttest_type %||% r$ttest_type
    r$ttest_group <- input$stats_ttest_group %||% r$ttest_group
    r$ttest_dv <- input$stats_ttest_dv %||% r$ttest_dv
    r$ttest_x <- input$stats_ttest_x %||% r$ttest_x
    r$ttest_y <- input$stats_ttest_y %||% r$ttest_y

    r$cor_method <- input$stats_cor_method %||% r$cor_method
    r$cor_x <- input$stats_cor_x %||% r$cor_x
    r$cor_y <- input$stats_cor_y %||% r$cor_y
    r$cor_group <- input$stats_cor_group %||% r$cor_group %||% ""
    if (nzchar(r$cor_group %||% "") && !is.null(input$stats_cor_levels)) {
      r$cor_levels <- as.character(input$stats_cor_levels)
    } else if (!nzchar(r$cor_group %||% "")) {
      r$cor_levels <- character(0)
    }

    if (identical(r$data_source %||% "graph", "custom")) {
      r$custom_data <- input$stats_custom_data %||% r$custom_data
    } else {
      r$custom_data <- ""
    }

    rr[[id]] <- normalize_stats_recipe(r, fallback_name = r$name)
    rr
  }

  # ============================================================
  # Project save / load
  # ============================================================
  project_settings <- reactive({
    list(
      version = "3.3.38",
      schema_version = 2L,
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
        xlab = input$xlab,
        ylab = input$ylab,
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
      statistics_recipes = stats_recipes_for_project()
    )
  })

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

  start_state_restore <- function(cfg, notify = FALSE) {
    if (is.null(cfg)) return(invisible(FALSE))

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
    restored_stats <- normalize_stats_recipes(restored_stats)
    stats_recipes(restored_stats)

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
    if (!is.null(r)) {
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

    invalidateLater(75, session)

    d0 <- tryCatch(raw_dat(), error = function(e) NULL)
    if (is.null(d0)) {
      restore_wait("元データを再構成できませんでした。")
      return()
    }
    project_restore_wait_count(0L)

    r <- cfg$reshape
    if (!is.null(r) && isTRUE(r$enabled)) {
      wanted <- json_vec(r$columns)
      if (length(wanted)) {
        wanted <- wanted[wanted %in% names(d0)]

        if (length(wanted)) {
          freezeReactiveValue(input, "reshape_columns")
          updateCheckboxGroupInput(
            session, "reshape_columns",
            choices = names(d0),
            selected = wanted
          )
        }
      }
    }

    project_restore_wait_count(0L)
    project_restore_stage(2)
  })

  # 第3段階: 変換後データにMapping列が揃ってからMappingを戻す
  observe({
    cfg <- pending_project()
    if (is.null(cfg) || project_restore_stage() != 2) return()

    invalidateLater(75, session)

    target_plot_type <- json_chr(cfg$plot$type, input$plot_type %||% "line")
    if (identical(target_plot_type, "violin")) target_plot_type <- "box"
    if (!target_plot_type %in% c("line", "bar", "scatter", "box")) {
      target_plot_type <- "line"
    }

    if (!identical(input$plot_type %||% "", target_plot_type)) {
      freezeReactiveValue(input, "plot_type")
      updateSelectInput(session, "plot_type", selected = target_plot_type)
      return()
    }

    d <- tryCatch(dat(), error = function(e) NULL)
    if (is.null(d)) {
      restore_wait("Wide→Long変換後のデータを準備できませんでした。")
      return()
    }

    mp <- cfg$mapping
    if (!is.null(mp)) {
      wanted <- c(
        json_chr(mp$x),
        json_chr(mp$y),
        if (target_plot_type %in% c("line", "bar", "box")) {
          json_chr(mp$position, json_chr(mp$series))
        } else "",
        json_chr(mp$color),
        if (target_plot_type %in% c("line", "scatter")) json_chr(mp$linetype) else "",
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
        ))
        return()
      }

      restore_inputs <- c("xvar", "yvar", "colorvar", "shapevar", "idvar", "facetvar")
      if (target_plot_type %in% c("line", "bar", "box")) restore_inputs <- c(restore_inputs, "groupvar")
      if (target_plot_type %in% c("line", "scatter")) restore_inputs <- c(restore_inputs, "linetypevar")

      for (nm in unique(restore_inputs)) freezeReactiveValue(input, nm)

      updateSelectInput(session, "xvar", selected = json_chr(mp$x))
      updateSelectInput(session, "yvar", selected = json_chr(mp$y))
      if (target_plot_type %in% c("line", "bar", "box")) {
        updateSelectInput(session, "groupvar", selected = json_chr(mp$position, json_chr(mp$series)))
      }
      restored_color <- json_chr(mp$color)
      if (!nzchar(restored_color) && is.null(mp$position) && nzchar(json_chr(mp$series))) {
        restored_color <- json_chr(mp$series)
      }
      if (identical(restored_color, "__fixed__")) restored_color <- ""
      updateSelectInput(session, "colorvar", selected = restored_color)
      if (target_plot_type %in% c("line", "scatter")) {
        updateSelectInput(
          session, "linetypevar",
          selected = json_chr(mp$linetype, "__color__")
        )
      }
      updateSelectInput(
        session, "shapevar",
        selected = json_chr(mp$shape, "__color__")
      )
      updateSelectInput(session, "idvar", selected = json_chr(mp$id))
      updateSelectInput(session, "facetvar", selected = json_chr(mp$facet))

      # dynamic inputのbrowser commitはここでは待たない。
      # 待つと、input bindingイベントが発生しない環境で復元が停止する。
      # seedを保持したままstage 4へ進み、実inputが追いついた時点でseedを解除する。
    }

    project_restore_wait_count(0L)
    project_restore_stage(3)
  })

  # 第4段階: Mappingが実際に反映されたことを確認して残りを復元
  observe({
    cfg <- pending_project()
    if (is.null(cfg) || project_restore_stage() != 3) return()

    invalidateLater(75, session)

    if (!mapping_matches_project(cfg)) {
      restore_wait("保存済みMappingをUIへ反映できませんでした。")
      return()
    }
    project_restore_wait_count(0L)

    # seedはここでは消さない。
    # dynamic UIの実inputが保存値へ追いついたことを別observerで確認してから解除する。

    pl <- cfg$plot
    if (!is.null(pl)) {
      if (!is.null(pl$summary)) updateSelectInput(session, "summary_type", selected = json_chr(pl$summary))
      updateRadioButtons(
        session, "summary_unit",
        selected = json_chr(pl$summary_unit, "row")
      )
      updateRadioButtons(
        session, "external_error_mode",
        selected = json_chr(pl$external_error_mode, "none")
      )
      mp_error <- cfg$mapping
      if (!is.null(mp_error)) {
        d_error <- tryCatch(dat(), error = function(e) NULL)
        error_choices <- if (is.null(d_error)) character(0) else {
          names(d_error)[vapply(d_error, is.numeric, logical(1))]
        }
        if (!is.null(mp_error$external_error)) {
          saved_error <- json_chr(mp_error$external_error)
          if (nzchar(saved_error) && saved_error %in% error_choices) {
            updateSelectInput(
              session, "external_error_col",
              choices = error_choices, selected = saved_error
            )
          }
        }
        if (!is.null(mp_error$external_ymin)) {
          saved_ymin <- json_chr(mp_error$external_ymin)
          if (nzchar(saved_ymin) && saved_ymin %in% error_choices) {
            updateSelectInput(
              session, "external_ymin_col",
              choices = error_choices, selected = saved_ymin
            )
          }
        }
        if (!is.null(mp_error$external_ymax)) {
          saved_ymax <- json_chr(mp_error$external_ymax)
          if (nzchar(saved_ymax) && saved_ymax %in% error_choices) {
            updateSelectInput(
              session, "external_ymax_col",
              choices = error_choices, selected = saved_ymax
            )
          }
        }
      }
      if (!is.null(pl$show_raw)) updateCheckboxInput(session, "show_raw", value = isTRUE(pl$show_raw))
      if (!is.null(pl$connect_id)) updateCheckboxInput(session, "connect_id", value = isTRUE(pl$connect_id))
      updateRadioButtons(
        session, "scatter_connect_mode",
        selected = json_chr(pl$scatter_connect_mode, if (isTRUE(pl$connect_id)) "id" else "none")
      )
    }

    lb <- cfg$labels
    if (!is.null(lb)) {
      if (!is.null(lb$xlab)) updateTextInput(session, "xlab", value = json_chr(lb$xlab))
      if (!is.null(lb$ylab)) updateTextInput(session, "ylab", value = json_chr(lb$ylab))
      if (!is.null(lb$title)) updateTextInput(session, "title", value = json_chr(lb$title))
      if (!is.null(lb$ymin)) updateTextInput(session, "ymin", value = json_chr(lb$ymin))
      if (!is.null(lb$ymax)) updateTextInput(session, "ymax", value = json_chr(lb$ymax))
      if (!is.null(lb$y_top_to_tick)) {
        updateCheckboxInput(session, "y_top_to_tick", value = isTRUE(lb$y_top_to_tick))
      }
    }

    # Legacy Project export width/height/dpi are intentionally ignored.
    # v3.3.31+ export geometry follows the restored Plot pixel dimensions.

    st <- cfg$style
    if (!is.null(st)) {
      if (!is.null(st$color_styles)) color_styles(parse_style_tree(st$color_styles, "color"))
      if (!is.null(st$linetype_styles)) linetype_styles(parse_style_tree(st$linetype_styles, "linetype"))
      if (!is.null(st$shape_styles)) shape_styles(parse_style_tree(st$shape_styles, "shape"))
      if (is.null(st$color_styles) && !is.null(st$group_styles) && length(st$group_styles)) {
        mv <- legacy_mapping_vars(cfg$mapping)
        migrate_legacy_group_styles(st$group_styles, mv$color, mv$linetype, mv$shape)
      }

      if (!is.null(st$series_styles) && length(st$series_styles)) {
        ss <- list()
        for (nm in names(st$series_styles)) {
          z <- st$series_styles[[nm]]
          ss[[nm]] <- list(color = json_chr(z$color, "#333333"))
        }
        series_styles(ss)
      }

      if (!is.null(st$regression_styles) && length(st$regression_styles)) {
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

      if (!is.null(st$raw_group_colors) && length(st$raw_group_colors)) {
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

      if (!is.null(st$orders)) {
        order_state(normalize_order_tree(st$orders))
      }

      if (!is.null(st$legend_titles)) {
        lt <- list()
        for (nm in names(st$legend_titles)) {
          lt[[nm]] <- json_chr(st$legend_titles[[nm]], "")
        }
        legend_titles(lt)
      }

      if (!is.null(st$level_labels)) {
        ll <- list()
        for (vn in names(st$level_labels)) {
          branch <- st$level_labels[[vn]]
          bb <- list()
          for (lv in names(branch)) bb[[lv]] <- json_chr(branch[[lv]], lv)
          ll[[vn]] <- bb
        }
        level_labels(ll)
      }

      a <- st$appearance
      if (!is.null(a)) {
        if (!is.null(a$series_style_override)) {
          updateCheckboxInput(
            session, "series_style_override",
            value = isTRUE(a$series_style_override)
          )
        }
        if (!is.null(a$scatter_regression)) {
          updateCheckboxInput(session, "scatter_regression", value = isTRUE(a$scatter_regression))
        }
        if (!is.null(a$scatter_regression_se)) {
          updateCheckboxInput(session, "scatter_regression_se", value = isTRUE(a$scatter_regression_se))
        }
        if (!is.null(a$scatter_regression_color)) {
          colourpicker::updateColourInput(
            session, "scatter_regression_color",
            value = json_chr(a$scatter_regression_color)
          )
        }

        simple_select <- c(
          theme = "theme",
          palette_preset = "palette_preset",
          raw_palette_preset = "raw_palette_preset",
          font_family_mode = "font_family_mode",
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
          if (!is.null(a[[nm]])) {
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

        if (!is.null(a$font_family_custom)) {
          updateTextInput(
            session, "font_family_custom",
            value = json_chr(a$font_family_custom)
          )
        }
        if (!is.null(a$mean_color_mode)) {
          colourpicker::updateColourInput(
            session, "mean_color_mode",
            value = normalise_colour(json_chr(a$mean_color_mode), "#000000")
          )
        }
        updateRadioButtons(
          session, "bar_border_mode",
          selected = json_chr(a$bar_border_mode, "fixed")
        )
        if (!is.null(a$bar_border_color)) {
          colourpicker::updateColourInput(
            session, "bar_border_color",
            value = normalise_colour(json_chr(a$bar_border_color), "#000000")
          )
        }
        if (!is.null(a$raw_fixed_custom)) {
          colourpicker::updateColourInput(
            session, "raw_fixed_custom",
            value = normalise_colour(json_chr(a$raw_fixed_custom), "#555555")
          )
        }
        if (!is.null(a$raw_color_mode)) {
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
        if (!is.null(a$id_line_color_mode)) {
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
        if (!is.null(a$id_line_custom_color)) {
          colourpicker::updateColourInput(
            session, "id_line_custom_color",
            value = normalise_colour(json_chr(a$id_line_custom_color), "#4D4D4D")
          )
        }
        if (!is.null(a$error_color)) {
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
          if (!is.null(a[[nm]])) {
            updateSliderInput(
              session, sliders[[nm]],
              value = as.numeric(a[[nm]])
            )
          }
        }

        # Plot width/height are restored in Stage 0 before panel reveal.
        # Do not touch them again here; late geometry changes caused oversized
        # Project layouts to collide with the Graph style panel.

        if (!is.null(a$summary_on_top)) {
          updateCheckboxInput(
            session, "summary_on_top",
            value = isTRUE(a$summary_on_top)
          )
        }
        if (!is.null(a$bar_zero_touch)) {
          updateCheckboxInput(session, "bar_zero_touch", value = isTRUE(a$bar_zero_touch))
        }
        if (!is.null(a$sticky_plot)) {
          updateCheckboxInput(session, "sticky_plot", value = isTRUE(a$sticky_plot))
        }
        if (!is.null(a$y_break_enabled)) {
          updateCheckboxInput(session, "y_break_enabled", value = isTRUE(a$y_break_enabled))
        }
        if (!is.null(a$y_breaks_auto)) {
          updateCheckboxInput(session, "y_breaks_auto", value = isTRUE(a$y_breaks_auto))
        }
        if (!is.null(a$y_breaks_step)) {
          updateNumericInput(session, "y_breaks_step", value = as.numeric(a$y_breaks_step))
        }
        if (!is.null(a$y_break_from)) {
          updateNumericInput(session, "y_break_from", value = as.numeric(a$y_break_from))
        }
        if (!is.null(a$y_break_to)) {
          updateNumericInput(session, "y_break_to", value = as.numeric(a$y_break_to))
        }
        if (!is.null(a$y_break_space)) {
          updateSliderInput(session, "y_break_space", value = as.numeric(a$y_break_space))
        }
        if (!is.null(a$y_break_symbol)) {
          updateCheckboxInput(session, "y_break_symbol", value = isTRUE(a$y_break_symbol))
        }
      }
    }

    # 保存済みstyleをreactiveValへ入れ終えた後、dynamic style UIを
    # もう一度だけ保存値から作り直す。observerはまだguard中。
    style_restore_epoch(isolate(style_restore_epoch()) + 1L)

    # ブラウザへ新しいStyle UIをflushしてからguardを解除する。
    # これにより古い/default input値で保存色を上書きする競合を防ぐ。
    session$onFlushed(function() {
      project_restore_stage(0)
      project_restore_wait_count(0L)
      pending_project(NULL)

      initial_restore_done(TRUE)
      deferred_initial_state(NULL)
      restoring_style_state(FALSE)

      if (isTRUE(isolate(restore_notify()))) {
        showNotification("Graphの設定を読み込みました。", type = "message")
      }
      restore_notify(FALSE)
    }, once = TRUE)
  })

  # Hidden Graphでもstate復元に必要な動的UIだけは動かす。
  # Plot本体はhidden時にShiny標準どおりsuspendする。
  # Project Managerはready()で先にGraphを表示し、表示後の正常サイズでPlotを描く。
  for (nm in c(
    "reshape_columns_ui", "reshape_warning_ui", "mapping_ui",
    "plot_specific_mapping_ui", "position_var_ui", "order_ui",
    "color_style_ui", "linetype_style_ui", "shape_style_ui", "series_style_ui", "scatter_regression_style_ui", "raw_group_color_ui",
    "display_labels_ui"
  )) {
    try(outputOptions(output, nm, suspendWhenHidden = FALSE), silent = TRUE)
  }

  activate_initial_state <- function() {
    if (isTRUE(isolate(initial_restore_done()))) return(invisible(TRUE))
    if (isTRUE(isolate(initial_restore_started()))) return(invisible(FALSE))

    cfg <- isolate(deferred_initial_state())
    if (is.null(cfg)) {
      initial_restore_started(TRUE)
      initial_restore_done(TRUE)
      return(invisible(TRUE))
    }

    initial_restore_started(TRUE)
    session$onFlushed(function() {
      start_state_restore(cfg, notify = FALSE)
    }, once = TRUE)
    invisible(TRUE)
  }

  # ============================================================
  # Downloads
  # ============================================================
  # Export geometry follows the on-screen Plot device (renderPlot res = 120).
  # This keeps aspect ratio, text/line proportions, and layout consistent.
  export_reference_res <- 120

  output$download_png <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".png"),
    content = function(file) {
      pw <- effective_plot_width_px()
      ph <- effective_plot_height_px()
      ggsave(
        file,
        plot = make_plot(),
        width = pw / export_reference_res,
        height = ph / export_reference_res,
        dpi = export_reference_res,
        units = "in",
        device = "png"
      )
    }
  )

  output$download_pdf <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".pdf"),
    content = function(file) {
      pw <- effective_plot_width_px()
      ph <- effective_plot_height_px()
      ggsave(
        file,
        plot = make_plot(),
        width = pw / export_reference_res,
        height = ph / export_reference_res,
        units = "in",
        device = grDevices::cairo_pdf
      )
    }
  )

  output$download_svg <- downloadHandler(
    filename = function() paste0("ggplot_", Sys.Date(), ".svg"),
    content = function(file) {
      pw <- effective_plot_width_px()
      ph <- effective_plot_height_px()
      svglite::svglite(
        file,
        width = pw / export_reference_res,
        height = ph / export_reference_res
      )
      on.exit(grDevices::dev.off(), add = TRUE)
      print(make_plot())
    }
  )

  list(
    # 未初期化Graphは、ブラウザinputではなく保存済みstateをそのまま返す。
    state = reactive({
      if (!isTRUE(initial_restore_done()) && !is.null(deferred_initial_state())) {
        return(deferred_initial_state())
      }
      project_settings()
    }),

    # SVG一括出力ではreadyなGraphだけPlotを生成する。
    plot = reactive({
      shiny::req(isTRUE(initial_restore_done()))
      make_plot()
    }),

    export = reactive({
      if (!isTRUE(initial_restore_done()) && !is.null(deferred_initial_state())) {
        sz <- saved_plot_size_from_state(deferred_initial_state())
        return(list(
          plot_width_px = as.numeric(sz$width),
          plot_height_px = as.numeric(sz$height),
          reference_res = 120
        ))
      }

      list(
        plot_width_px = as.numeric(effective_plot_width_px()),
        plot_height_px = as.numeric(effective_plot_height_px()),
        reference_res = 120
      )
    }),

    ready = reactive({
      geometry_ready <- is.null(plot_width_restore_seed()) &&
        is.null(plot_height_restore_seed())

      isTRUE(initial_restore_done()) &&
        isTRUE(geometry_ready) &&
        is.null(pending_project()) &&
        project_restore_stage() == 0
    }),

    # drawnは表示確認用の情報として残すが、Project復元完了条件には使わない。
    drawn = reactive({ isTRUE(plot_drawn()) }),

    activate = activate_initial_state
  )


  })
}
