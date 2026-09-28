# R/figure/figure_ui_module.R — Figure workspace UI
# workflow-first Figure shell. Existing geometry/runtime input ids are
# preserved; normal editing controls live in their workflow sections rather than an Advanced bucket.

figureWorkflowHeaderUI <- function() {
  div(
    class = "figure-workspace-header figure-workflow-header",
    div(
      tags$strong("FIGURE"),
      tags$span(class = "figure-workspace-status", textOutput("figure_preview_status", inline = TRUE))
    ),
    tags$span(
      class = "figure-workspace-hint",
      "Layout / Graph Sourcesは必要な時だけ開きます。Figureを見ながらの調整は左の「Figure調整」で個別・まとめて切り替えます。"
    )
  )
}

figureExternalAssetSourceUI <- function() {
  tags$details(
    class = "figure-layout-subsection figure-external-asset-source-subsection",
    tags$summary("External Assets"),
    div(
      class = "figure-asset-load-bar",
      selectInput("figure_asset_role", "種別",
                  choices = c("外部グラフ"="external_graph", "一般画像/SVG"="generic", "凡例のみ"="legend"),
                  selected = "external_graph", width = "135px"),
      selectInput("figure_asset_legend_mode", "外部グラフの凡例",
                  choices = c("画像に凡例込み"="included", "凡例を別ファイル"="separate", "凡例なし"="none"),
                  selected = "included", width = "150px"),
      fileInput(
        "figure_asset_upload", "本体画像 / SVG",
        accept = c("image/png", "image/jpeg", "image/webp", "image/svg+xml", ".svg", ".png", ".jpg", ".jpeg", ".webp"),
        multiple = FALSE, width = "300px"
      ),
      conditionalPanel(
        condition = "input.figure_asset_role == 'external_graph' && input.figure_asset_legend_mode == 'separate'",
        fileInput(
          "figure_asset_legend_upload", "凡例ファイル",
          accept = c("image/png", "image/jpeg", "image/webp", "image/svg+xml", ".svg", ".png", ".jpg", ".jpeg", ".webp"),
          multiple = FALSE, width = "300px"
        )
      ),
      actionButton("figure_asset_add", "Assetを追加", class = "btn-default"),
      actionButton("figure_asset_remove", "選択Assetを削除", class = "btn-default"),
      tags$span(class = "text-muted", textOutput("figure_asset_status", inline = TRUE))
    )
  )
}

figureGraphSourcesUI <- function() {
  tags$details(
    class = "figure-config-section figure-graph-sources-section figure-workflow-step",
    tags$summary(div(class = "figure-workflow-step-title", "Graph Sources")),
    div(
      class = "figure-config-body",
      uiOutput("figure_graph_sources_status"),
      div(
        class = "figure-source-import-bar figure-source-import-above-preview",
        actionButton("figure_graph_load_selected", "選択Graphを読み込む / 再読込", class = "btn-primary"),
        actionButton("figure_graph_load_missing", "未読込Graphをすべて読み込む", class = "btn-default"),
        actionButton("figure_graph_load_all", "すべて元Graphから再読込…", class = "btn-warning")
      ),
      tags$p(
        class = "help-block figure-source-import-help",
        "Panel配置はlayout-onlyです。通常は選択Graph、または未読込Graphだけを読み込みます。『すべて元Graphから再読込』は既存のFigure編集を元Graphの現在値で置き換えます。"
      ),
      figureExternalAssetSourceUI()
    )
  )
}

figureCanvasControlsUI <- function() {
  div(
    class = "figure-layout-control-card figure-canvas-control-card",
    div(class = "figure-layout-control-card-title", tags$strong("Canvas")),
    div(
      class = "figure-layout-basics figure-canvas-primary-controls",
      selectInput(
        "figure_size_mode", "Canvasサイズ",
        choices = c("内容に合わせる (Auto)" = "auto", "固定 (Fixed)" = "fixed"),
        selected = "auto", width = "155px"
      ),
      conditionalPanel(
        condition = "input.figure_size_mode == 'fixed'",
        div(
          class = "figure-inline-controls figure-fixed-canvas-size",
          numericInput("figure_canvas_width", "幅 (px)", value = 1600, min = 300, max = 6000, step = 50, width = "105px"),
          numericInput("figure_canvas_height", "高さ (px)", value = 1000, min = 300, max = 6000, step = 50, width = "105px")
        )
      ),
      conditionalPanel(
        condition = "input.figure_size_mode == 'auto'",
        div(
          class = "figure-inline-controls figure-auto-canvas-controls",
          selectInput(
            "figure_autofit_policy", "Auto更新",
            choices = c("常時追従" = "live", "手動更新" = "manual", "固定" = "lock"),
            selected = "live", width = "120px"
          ),
          actionButton("figure_refit_now", "再計算", class = "btn-sm btn-default")
        )
      )
    ),
    tags$p(
      class = "figure-layout-card-help",
      "FixedではCanvas外形を保ったままPanel間隔を確保し、その分だけ各Panel slotを配分します。Autoでは内容bboxからCanvasを決めます。"
    )
  )
}

figureLayoutPrimaryControlsUI <- function() {
  div(
    class = "figure-layout-control-card figure-grid-control-card",
    div(class = "figure-layout-control-card-title", tags$strong("Layout")),
    div(
      class = "figure-layout-basics figure-primary-layout-controls",
      selectInput(
        "figure_layout_mode", "配置方式",
        choices = c("Row" = "row", "Free" = "free"),
        selected = "row", width = "105px"
      ),
      selectInput(
        "figure_size_basis", "整列基準",
        choices = c(
          "Panel本体（凡例除外）" = "panel",
          "Panel本体＋外側凡例（推奨）" = "panel_legend",
          "Panel＋軸（凡例除外）" = "panel_axis",
          "Panel＋軸＋外側凡例" = "panel_axis_legend"
        ),
        selected = "panel_legend", width = "220px"
      ),
      # Backward-compatible input owner. Graph title alignment was an old
      # workaround for panel-label drift and is no longer exposed in the UI.
      div(style = "display:none;", selectInput(
        "figure_title_align", "Graph title整列",
        choices = c("なし" = "none"), selected = "none", width = "1px"
      )),
      numericInput("figure_gap_x", "Panel横間隔 (px)", value = 12, min = 0, step = 2, width = "100px"),
      numericInput("figure_gap_y", "Panel縦間隔 (px)", value = 12, min = 0, step = 2, width = "100px")
    ),
    conditionalPanel(
      condition = "input.figure_size_mode == 'fixed' && input.figure_layout_mode == 'row'",
      div(class = "figure-layout-track-controls", uiOutput("figure_column_ratio_controls"))
    ),
    tags$p(
      class = "figure-layout-card-help",
      "Panel本体を揃える場合はPanel基準を使用します。軸ラベル等は周辺予約として吸収し、外側凡例を共通整列余白へ含めるかを明示できます。Fixedでは列幅比は全Row共通のcolumn track、行高さ比は全Figure共通のrow trackとして扱います。"
    )
  )
}

figureLayoutWorkflowUI <- function() {
  tags$details(
    class = "figure-config-section figure-layout-section figure-layout-above-preview figure-workflow-step",
    tags$summary(div(class = "figure-workflow-step-title", "Layout")),
    div(
      class = "figure-config-body",
      div(
        class = "figure-layout-control-grid",
        figureCanvasControlsUI(),
        figureLayoutPrimaryControlsUI()
      ),
      tags$details(
        class = "figure-layout-subsection figure-layout-structure-subsection",
        tags$summary("Row / Panel構成"),
        div(class = "figure-layout-editor", uiOutput("figure_layout_editor"))
      ),
      tags$details(
        class = "figure-layout-subsection figure-layout-reorder-subsection",
        tags$summary("Graphの並び・全Panel整列"),
        div(class = "figure-layout-reorder-home", uiOutput("figure_reorder_controls"))
      )
    )
  )
}

figureCommonQuickSettingsUI <- function() {
  div(
    class = "figure-common-subsection figure-common-quick-section",
    div(class = "figure-common-inline-heading", tags$strong("見た目をまとめて揃える")),
    tags$p(
      class = "help-block figure-common-quick-help",
      "よく使う項目だけを変更します。Graph間で値が違う項目は Mixed と表示されます。"
    ),
    uiOutput("figure_common_quick_controls"),
    div(
      class = "figure-common-apply-row",
      actionButton("figure_common_quick_apply", "変更をFigureに適用", class = "btn-sm btn-primary"),
      tags$span(class = "text-muted", "元Graphは変更しません。")
    )
  )
}
figureCommonWorkspaceLaunchersUI <- function() {
  div(
    class = "figure-common-drawer-launchers",
    actionButton("figure_common_open_semantic", "群・条件を揃える…", class = "btn-sm btn-primary"),
    actionButton("figure_common_open_library", "共通スタイル管理…", class = "btn-sm btn-default"),
    actionButton("figure_common_open_advanced", "詳細設定…", class = "btn-sm btn-default")
  )
}
figureSemanticWorkspaceModalUI <- function() {
  modalDialog(
    title = "群・条件の見た目を揃える",
    size = "l",
    easyClose = TRUE,
    footer = modalButton("閉じる"),
    div(
      class = "figure-common-workspace-modal figure-common-semantic-workspace",
      div(
        class = "figure-common-modal-intro",
        tags$strong("同じ意味の群・条件を、Graphをまたいで同じ見た目に揃えます。"),
        tags$span(" 元Graphは変更しません。ここで『Figureに適用』したときだけFigure側が更新されます。")
      ),
      div(
        class = "figure-common-modal-toolbar",
        div(
          class = "figure-common-modal-targets",
          tags$strong("対象Graph"),
          uiOutput("figure_common_modal_target_summary")
        ),
        div(
          class = "figure-common-semantic-actions",
          actionButton("figure_common_semantic_auto_match", "同じ名前を自動で揃える", class = "btn-sm btn-default"),
          actionButton("figure_common_semantic_open_library", "共通グループを管理…", class = "btn-sm btn-default"),
          actionButton("figure_common_semantic_apply", "対応を保存してFigureに適用", class = "btn-sm btn-primary")
        )
      ),
      uiOutput("figure_common_semantic_bindings")
    )
  )
}

figureSharedStyleNewModalUI <- function() {
  modalDialog(
    title = "新しい共通スタイル",
    size = "s",
    easyClose = TRUE,
    footer = tagList(
      actionButton("figure_common_library_new_cancel", "戻る", class = "btn-default"),
      actionButton("shared_style_add", "追加", class = "btn-primary")
    ),
    div(
      class = "shared-style-new-modal",
      textInput("shared_style_new_display", "名前", value = "", placeholder = "例: Control", width = "100%"),
      selectInput(
        "shared_style_new_kind", "用途",
        choices = c("群・条件" = "level", "軸ラベル" = "axis_label", "凡例タイトル" = "legend_title"),
        selected = "level", width = "180px"
      ),
      tags$p(class = "help-block", "追加後に色・形・線などを編集できます。")
    )
  )
}

figureSharedStyleLibraryModalUI <- function() {
  modalDialog(
    title = "共通スタイルを管理",
    size = "l",
    easyClose = TRUE,
    footer = tagList(
      actionButton("figure_common_library_back_semantic", "群・条件の設定へ", class = "btn-default"),
      modalButton("閉じる")
    ),
    div(
      class = "figure-common-workspace-modal figure-common-library-workspace",
      div(
        class = "figure-common-modal-intro",
        tags$strong("複数Graphで共通に使う名前と見た目を管理します。"),
        tags$span(" ここで変更してもFigureは自動では変わりません。Figure側は『群・条件を揃える』から明示的に適用します。")
      ),
      div(
        class = "shared-style-library-workspace-grid",
        div(
          class = "shared-style-library-nav-pane",
          div(
            class = "shared-style-library-list-heading",
            tags$strong("共通スタイル一覧"),
            actionButton("figure_common_library_new", "＋ 新しいスタイル", class = "btn-sm btn-primary")
          ),
          uiOutput("shared_style_summary"),
          tags$hr(),
          div(
            class = "shared-style-portable-row",
            fileInput("shared_style_import", "スタイルを読み込む", accept = c("application/json", ".json"), multiple = FALSE, width = "100%"),
            downloadButton("download_shared_style", "スタイルを書き出す")
          )
        ),
        div(
          class = "shared-style-library-editor-pane",
          div(class = "figure-common-card-title", tags$strong("選択中のスタイルを編集")),
          uiOutput("shared_style_selector"),
          uiOutput("shared_style_editor"),
          div(
            class = "shared-style-editor-delete-row",
            actionButton("shared_style_delete", "このスタイルを削除", class = "btn-sm btn-danger")
          )
        )
      )
    )
  )
}
figureAdvancedSettingsModalUI <- function() {
  modalDialog(
    title = "詳細設定",
    size = "l",
    easyClose = TRUE,
    footer = modalButton("閉じる"),
    div(
      class = "figure-common-workspace-modal figure-common-advanced-workspace",
      tags$p(class = "help-block", "『見た目をまとめて揃える』にない項目を比較・一括編集します。適用先を確認して使用してください。"),
      div(class = "graph-settings-manager-modal-home", uiOutput("graph_settings_manager"))
    )
  )
}

figureCommonDrawerPaneUI <- function() {
  div(
    class = "figure-common-drawer-pane",
    div(
      class = "figure-common-target-card",
      div(class = "figure-common-target-heading", tags$strong("対象Graph"), tags$span("読込済みのGraphから選択")),
      uiOutput("figure_common_target_selector")
    ),
    figureCommonQuickSettingsUI(),
    figureCommonWorkspaceLaunchersUI()
  )
}

figureSelectedPanelControlsUI <- function() {
  div(
    class = "figure-selected-drawer-pane",
    div(class = "figure-drawer-selection", uiOutput("figure_selected_panel_header")),
    div(
      class = "figure-drawer-placement-reset",
      actionButton("figure_position_reset", "自由配置の位置を初期化", class = "btn-sm btn-default"),
      tags$span(class = "text-muted", "凡例・Panel label・Insetなどの位置だけを戻します。内容・Crop・Graph順は変更しません。")
    ),

    tags$details(
      class = "figure-config-section figure-inspector-section figure-drawer-section",
      tags$summary("Figure Panel"),
      div(
        class = "figure-config-body",
        p(class = "help-block", "Panel label・Crop・個別配置など、FigureのPanel固有設定です。"),
        div(class = "figure-override-detail figure-panel-detail", uiOutput("figure_panel_detail"))
      )
    ),

    tags$details(
      class = "figure-config-section figure-overlay-section figure-drawer-section",
      tags$summary("Legend / Inset"),
      div(
        class = "figure-config-body",
        p(class = "help-block", "Figure凡例・Insetなど、Panel上に重ねる要素の設定です。"),
        div(class = "figure-override-detail figure-overlay-detail", uiOutput("figure_overlay_detail"))
      )
    ),

    tags$details(
      class = "figure-config-section figure-graph-editor-section figure-drawer-section",
      tags$summary("Graph個別編集"),
      div(
        class = "figure-config-body figure-graph-editor-body",
        div(
          class = "figure-graph-editor-actions",
          actionButton("figure_graph_edit_selected", "このPanelをFigure内で編集", class = "btn-sm btn-primary"),
          tags$span(class = "text-muted", "Panel選択は軽量です。編集開始時だけ共通Figure Editorへ読み込みます。Graphからの読込/再読込は上のGraph Sourcesで行います。")
        ),
        textOutput("figure_graph_editor_status"),
        div(id = "figure_graph_editor_host", class = "figure-graph-editor-host")
      )
    ),

    tags$details(
      class = "figure-config-section figure-apply-output-section figure-drawer-section",
      tags$summary("Apply / Output"),
      div(
        class = "figure-config-body",
        actionButton("figure_apply_to_source", "選択Figure設定を元Graphへ反映", class = "btn-sm btn-warning"),
        tags$p(class = "help-block", "Figureで編集可能なMapping / Plot / Labels / Styleだけを元Graphへ反映します。Data / Reshape / Statisticsは変更しません。Figure出力は画面上部の『Figure出力』から行います。")
      )
    )
  )
}

figureAdjustmentDrawerUI <- function() {
  tags$details(
    class = "figure-control-drawer",
    tags$summary(tags$span(class = "figure-control-drawer-title", "Figure調整")),
    div(
      class = "figure-control-drawer-body",
      div(
        class = "figure-drawer-mode-switch",
        radioButtons(
          "figure_drawer_mode", NULL,
          choices = c("個別調整" = "selected", "まとめて調整" = "common"),
          selected = "selected", inline = TRUE
        )
      ),
      conditionalPanel(
        condition = "input.figure_drawer_mode == 'selected'",
        figureSelectedPanelControlsUI()
      ),
      conditionalPanel(
        condition = "input.figure_drawer_mode == 'common'",
        figureCommonDrawerPaneUI()
      )
    )
  )
}
figureTopExportUI <- function() {
  div(
    class = "top-row top-output-row figure-output-row",
    tags$span(class = "top-label", "Figure出力"),
    div(
      class = "inline-select figure-top-export-format",
      selectInput(
        "figure_export_format",
        NULL,
        choices = c(
          "SVG" = "svg",
          "PowerPoint (.pptx)" = "pptx",
          "PDF" = "pdf",
          "PNG" = "png"
        ),
        selected = "svg", width = "155px", selectize = FALSE
      )
    ),
    downloadButton("download_figure", "Figureを書き出す"),
    conditionalPanel(
      condition = "input.figure_export_format == 'pptx'",
      tags$small(
        class = "top-export-note",
        "線・点・文字をPowerPoint上で編集可能"
      )
    )
  )
}

figurePreviewWorkflowUI <- function() {
  div(
    class = "figure-preview-section",
    div(
      class = "figure-preview-toolbar",
      tags$strong("Preview"),
      tags$span("Panelクリックは選択のみ。個別編集は左Drawerから開始します。FreeではPanel/Label/Legend/Insetをドラッグできます。"),
      span(
        class = "figure-preview-zoom-control",
        tags$span("表示倍率"),
        selectInput(
          "figure_view_zoom", NULL,
          choices = c("50%"="0.50", "75%"="0.75", "100%"="1.00", "125%"="1.25", "150%"="1.50", "175%"="1.75", "200%"="2.00"),
          selected = "1.00", width = "92px"
        )
      ),
      span(
        class = "figure-preview-renderer-toggle",
        checkboxInput("figure_svg_preview", "SVG preview", value = TRUE)
      )
    ),
    div(class = "figure-preview-note", "セル枠・Graph名はPreview専用です。Drawerを開いたままFigureを確認できます。"),
    uiOutput("figure_preview_area")
  )
}

figureWorkspaceUI <- function() {
  div(
    class = "figure-workspace figure-editor-v346 figure-editor-v347 figure-workflow-v373",
    figureWorkflowHeaderUI(),
    figureLayoutWorkflowUI(),
    figureGraphSourcesUI(),
    div(
      class = "figure-editor-shell",
      figureAdjustmentDrawerUI(),
      div(class = "figure-canvas-column", figurePreviewWorkflowUI())
    )
  )
}

figureSelectedPanelHeaderUI <- function(id, key, meta) {
  if (!nzchar(as.character(id %||% ""))) {
    return(div(class = "figure-inspector-empty", "PreviewでPanelをクリックしてください。"))
  }
  nm <- meta$name[match(id, meta$id)]
  if (!length(nm) || is.na(nm)) nm <- id
  div(
    class = "figure-inspector-selection",
    tags$strong(paste0("選択中: ", nm)),
    if (nzchar(as.character(key %||% ""))) tags$span(class = "text-muted", paste0("  ·  ", key))
  )
}

figureOverrideDetailUI <- function(id, ov, source_choices = character(0), is_external = FALSE, asset_info = NULL, sync_generation = 0L, section = c("all", "panel", "overlay"), fold_state = list()) {
  if (!nzchar(as.character(id %||% ""))) return(NULL)
  section <- match.arg(section)
  ov <- modifyList(figure_default_override(id), ov %||% list())

  # Figure Inspector subgroups use the same native details/summary folding
  # contract as the rest of the Figure UI. Fold state remains presentation-only
  # and is restored across selected-panel renderUI replacement.
  fold_group <- function(key, title, default = FALSE, ...) {
    collapsed <- isTRUE(fold_state[[key]] %||% default)
    tags$details(
      class = "figure-inspector-group",
      `data-figure-fold-key` = key,
      open = if (!collapsed) "open" else NULL,
      tags$summary(title),
      ...
    )
  }
  panel_groups <- tagList(
    fold_group("label", "Panel label", FALSE,
      textInput("figure_panel_label", "文字", value = ov$panel_label %||% "", width = "150px", placeholder = "例: A / Fig. 2A"),
      numericInput("figure_panel_label_size", "文字サイズ", value = ov$label_size %||% 18, min = 1, step = 1, width = "110px"),
      numericInput("figure_top_gutter", "上側余白 (px)", value = ov$top_gutter %||% 48, min = 0, step = 2, width = "120px"),
      radioButtons("figure_label_mode", "配置", choices = c("整列" = "align", "自由配置" = "free"), selected = ov$label_mode %||% "align", inline = TRUE),
      conditionalPanel(
        condition = "input.figure_label_mode == 'align'",
        selectInput("figure_label_anchor", "基準位置", choices = c("Plot panel左端（推奨）" = "panel", "Graph左端" = "plot_left", "セル左端" = "cell_left"), selected = ov$label_anchor %||% "panel", width = "180px"),
        div(class = "figure-inline-controls",
            numericInput("figure_label_x_offset", "X微調整", value = ov$label_x_offset %||% 0, step = 1, width = "105px"),
            numericInput("figure_label_y_offset", "Y微調整", value = ov$label_y_offset %||% 0, step = 1, width = "105px"))
      ),
      conditionalPanel(
        condition = "input.figure_label_mode == 'free'",
        tags$p(class = "help-block", "Preview上のラベルをドラッグして移動できます。数値はPanel内の相対位置です。"),
        div(class = "figure-inline-controls",
            numericInput("figure_label_x", "X", value = ov$label_x %||% 0.06, step = 0.01, width = "90px"),
            numericInput("figure_label_y", "Y", value = ov$label_y %||% 0.02, step = 0.01, width = "90px"))
      )
    ),
    fold_group("crop", "Crop (非破壊 / alpha)", TRUE,
      checkboxInput("figure_crop_enabled", "Cropを有効化", value = isTRUE(ov$crop$enabled)),
      tags$p(class = "help-block", "0–0.49 の割合でPlot viewportだけを切り抜きます。元Graphは変更しません。"),
      div(class = "figure-inline-controls",
          numericInput("figure_crop_left", "左", value = ov$crop$left %||% 0, min = 0, max = 0.49, step = 0.01, width = "85px"),
          numericInput("figure_crop_right", "右", value = ov$crop$right %||% 0, min = 0, max = 0.49, step = 0.01, width = "85px"),
          numericInput("figure_crop_top", "上", value = ov$crop$top %||% 0, min = 0, max = 0.49, step = 0.01, width = "85px"),
          numericInput("figure_crop_bottom", "下", value = ov$crop$bottom %||% 0, min = 0, max = 0.49, step = 0.01, width = "85px"))
    ),
    fold_group("alignment", "Panel内のGraph位置（高度な設定）", TRUE,
      selectInput("figure_align_h", "横位置", choices = c("左" = "left", "中央" = "center", "右" = "right"), selected = ov$align_h %||% "center", width = "120px"),
      selectInput("figure_align_v", "縦位置", choices = c("上" = "top", "中央" = "center", "下" = "bottom"), selected = ov$align_v %||% "center", width = "120px")
    )
  )

  overlay_groups <- tagList(
    fold_group("legend", "Legend", FALSE,
      selectInput("figure_legend_override", "表示位置", choices = c("元Graph設定" = "inherit", "非表示" = "none", "右" = "right", "左" = "left", "上" = "top", "下" = "bottom", "自由配置" = "free"), selected = ov$legend %||% "inherit", width = "180px"),
      selectInput("figure_legend_title", "凡例タイトル", choices = c("元Graph設定" = "inherit", "表示" = "show", "非表示" = "hide"), selected = figure_normalize_legend_title_mode(ov$legend_title), width = "130px"),
      numericInput("figure_legend_gap", "Graphとの間隔 (px)", value = ov$legend_gap %||% 8, min = 0, step = 1, width = "130px"),
      conditionalPanel(
        condition = "input.figure_legend_override == 'free'",
        tags$p(class = "help-block", "凡例は紐づくGraphの表示フレームを基準に相対配置されます。Graphの移動・リサイズには追従し、Panel境界ではclipされません。"),
        selectInput("figure_legend_background", "凡例背景", choices = c("透明" = "transparent", "白" = "white"), selected = ov$legend_background %||% "transparent", width = "120px"),
        div(class = "figure-inline-controls",
            numericInput("figure_legend_x", "相対 X", value = ov$legend_free_x %||% ov$legend_x %||% 0.72, step = 0.01, width = "90px"),
            numericInput("figure_legend_y", "相対 Y", value = ov$legend_free_y %||% ov$legend_y %||% 0.08, step = 0.01, width = "90px"))
      )
    ),
    fold_group("inset", "Inset", TRUE,
      checkboxInput("figure_inset_enabled", "Insetを有効化", value = isTRUE(ov$inset$enabled)),
      tags$p(class = "help-block", "owner Graph基準の自由配置です。ドラッグで移動、右下ハンドルで拡大縮小できます。Panel外にも配置できます。"),
      selectInput("figure_inset_source", "Inset source", choices = c("未選択" = "", source_choices), selected = ov$inset$source_id %||% "", width = "190px"),
      actionButton("figure_inset_refresh", "InsetをGraphから更新", class = "btn-sm btn-default"),
      tags$p(class = "help-block", "Graphタブ側の変更は自動反映されません。このボタンを押した時点のGraphをInsetへ取り込みます。"),
      div(class = "figure-inline-controls",
          numericInput("figure_inset_x", "相対 X", value = ov$inset$x %||% 0.62, step = 0.01, width = "90px"),
          numericInput("figure_inset_y", "相対 Y", value = ov$inset$y %||% 0.08, step = 0.01, width = "90px"),
          numericInput("figure_inset_width", "幅", value = ov$inset$width %||% 0.32, min = 0.01, step = 0.01, width = "80px"),
          numericInput("figure_inset_height", "高さ", value = ov$inset$height %||% 0.32, min = 0.01, step = 0.01, width = "80px")),
      checkboxInput("figure_inset_border", "枠線", value = isTRUE(ov$inset$border))
    ),
    if (isTRUE(is_external) && identical(as.character(asset_info$asset_role %||% "generic"), "external_graph")) div(
      class = "figure-inspector-group",
      tags$h5("External graph legend"),
      tags$p(class="help-block", paste0("Import mode: ", as.character(asset_info$legend_mode %||% "included"))),
      selectInput("figure_external_legend_mode", "Figureでの扱い", choices=c("Import設定を継承"="inherit","凡例込み"="included","別凡例"="separate","凡例なし"="none"), selected=ov$external_legend$mode %||% "inherit", width="150px"),
      selectInput("figure_external_legend_position", "別凡例位置", choices=c("右"="right","左"="left","上"="top","下"="bottom","自由"="free"), selected=ov$external_legend$position %||% "right", width="110px"),
      div(class="figure-inline-controls",
          numericInput("figure_external_legend_x", "X", value=ov$external_legend$x %||% .76, step=.01, width="80px"),
          numericInput("figure_external_legend_y", "Y", value=ov$external_legend$y %||% .08, step=.01, width="80px"),
          numericInput("figure_external_legend_width", "幅", value=ov$external_legend$width %||% .22, min=.01, step=.01, width="80px"),
          numericInput("figure_external_legend_height", "高さ", value=ov$external_legend$height %||% .30, min=.01, step=.01, width="80px"))
    )
  )

  groups <- switch(section, panel = panel_groups, overlay = overlay_groups, all = tagList(panel_groups, overlay_groups))
  tagList(
    if (section %in% c("all", "panel")) div(style = "display:none;", textInput("figure_inspector_graph_id", NULL, value = id)),
    if (section %in% c("all", "panel")) div(style = "display:none;", textInput("figure_inspector_sync_generation", NULL, value = as.character(sync_generation %||% 0L))),
    div(class = "figure-inspector-grid", groups)
  )
}

