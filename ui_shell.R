# Application UI shell.
# v3.67.2: top-level UI regions are explicit functions. Each function owns one
# stable UI responsibility; Graph/Figure controls remain in their modules.

app_head_ui <- function() {
tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = paste0("app_styles.css?v=", utils::URLencode(APP_VERSION, reserved = TRUE))),
      tags$script(src = paste0("app_client.js?v=", utils::URLencode(APP_VERSION, reserved = TRUE))),
      tags$script(src = paste0("graph_settings_popout.js?v=", utils::URLencode(APP_VERSION, reserved = TRUE)))
    )
}

project_load_overlay_ui <- function() {
div(
    id = "project_load_overlay",
    class = "project-load-overlay",
    `aria-hidden` = "true",
    div(
      class = "project-load-card",
      div(class = "project-load-spinner", `aria-hidden` = "true"),
      div(class = "project-load-title", "Projectを準備しています"),
      div(class = "project-load-message", "Projectを読み込んでいます…"),
      div(
        class = "project-load-progress-wrap indeterminate",
        div(
          class = "project-load-progress-track",
          role = "progressbar",
          `aria-label` = "Project読み込み進捗",
          `aria-valuemin` = "0",
          `aria-valuemax` = "100",
          div(class = "project-load-progress-bar")
        ),
        div(class = "project-load-progress-text", "Projectファイルを確認しています…")
      ),
      tags$button(
        type = "button",
        class = "btn btn-danger project-load-reload",
        onclick = "window.location.reload();",
        "アプリを再読み込み"
      )
    )
  )
}

project_manager_ui <- function() {
div(
    class = "project-manager",

    # Project
    div(
      class = "top-row",
      tags$span(class = "top-label", "Project"),
      div(
        class = "project-name-compact",
        textInput("project_name", NULL, value = "MyProject", width = "180px")
      ),
      div(
        class = "project-action-group",
        div(
          class = "project-open-compact",
          fileInput(
            "upload_project_all",
            NULL,
            accept = c(".ggplotproj", ".ggplotpack", ".json"),
            buttonLabel = "開く",
            placeholder = ""
          )
        ),
        actionButton(
          "save_project_as_all",
          "名前を付けて保存",
          title = "保存先を選んで .ggplotpack Projectを作成します。保存先を記憶するがONなら、その保存先も同時に記憶します。"
        ),
        actionButton(
          "overwrite_project_all",
          "上書き保存",
          class = "btn-primary",
          title = "保存先が未設定・無効な場合は保存先を選び直します。"
        ),
        actionButton(
          "close_project_all",
          "閉じる",
          class = "btn-default",
          title = "現在のProjectを閉じて、新しいGraph 1の編集状態へ戻ります。未保存の変更は失われます。"
        ),
        div(
          class = "remember-save-destination",
          checkboxInput(
            "remember_project_save_destination",
            "保存先を記憶する",
            value = FALSE
          )
        ),
        div(
          style = "display:none;",
          downloadButton("download_project_all", ""),
          downloadButton("download_project_overwrite_payload", "")
        )
      ),
      div(
        class = "project-save-note",
        tags$small(
          "※ 「保存先を記憶する」をONにすると、対応ブラウザではこのProjectの上書き保存先をProject ID単位で記憶します。Project名を変更しても保存先は維持されます。ファイルを移動・削除した場合や権限が失われた場合は、次回の上書き保存時に保存先を再選択します。"
        ),
        tags$br(),
        tags$small(
          id = "project-save-destination-status",
          class = "text-muted",
          ""
        )
      ),
      div(
        class = "project-progress-inline",
        uiOutput("project_load_progress")
      )
    ),

    # Graph
    div(
      class = "top-row",
      tags$span(class = "top-label", "Graph"),
      div(
        class = "graph-tabs-wrap",
        uiOutput("graph_tab_bar")
      ),
      actionButton("graph_add", "＋", class = "btn-default btn-sm", title = "新規Graph"),
      div(
        class = "btn-group graph-menu",
        tags$button(
          type = "button",
          class = "btn btn-default btn-sm dropdown-toggle",
          `data-toggle` = "dropdown",
          `aria-haspopup` = "true",
          `aria-expanded` = "false",
          "⋯ ",
          tags$span(class = "caret")
        ),
        tags$ul(
          class = "dropdown-menu dropdown-menu-right",
          tags$li(
            tags$a(
              href = "#",
              onclick = "return window.ggplotGuiGraphAction ? window.ggplotGuiGraphAction('graph_duplicate') : false;",
              "複製"
            )
          ),
          tags$li(
            tags$a(
              href = "#",
              onclick = "return window.ggplotGuiGraphAction ? window.ggplotGuiGraphAction('graph_rename') : false;",
              "名前変更"
            )
          ),
          tags$li(role = "separator", class = "divider"),
          tags$li(
            tags$a(
              href = "#",
              onclick = "return window.ggplotGuiGraphAction ? window.ggplotGuiGraphAction('graph_delete') : false;",
              "削除"
            )
          )
        )
      )
    ),

    # Export
    div(
      class = "top-row",
      tags$span(class = "top-label", "書き出し"),
      div(
        class = "inline-select export-target",
        selectInput(
          "top_export_target",
          NULL,
          choices = c(
            "現在編集中のGraph" = "current",
            "選択したGraph" = "selected",
            "全Graph" = "all"
          ),
          selected = "current",
          width = "155px"
        )
      ),
      div(
        class = "inline-select export-format",
        selectInput(
          "top_export_format",
          NULL,
          choices = c(
            "SVG" = "svg",
            "PNG" = "png",
            "PDF" = "pdf"
          ),
          selected = "svg",
          width = "90px"
        )
      ),
      downloadButton("download_graphs", "書き出す"),
      tags$span(
        class = "export-status",
        textOutput("bulk_export_status", inline = TRUE)
      ),
      tags$small(
        class = "text-muted",
        "SVG / PDF: ベクター本番用　｜　PNG: 軽量な確認・共有用　｜　サイズ比率は現在のPlotに連動"
      )
    ),

    conditionalPanel(
      condition = "input.top_export_target == 'selected'",
      div(
        class = "bulk-choice-box",
        uiOutput("bulk_export_choices")
      )
    ),


  )
}

graph_workspace_ui <- function() {
tabsetPanel(
    id = "workspace_main_tab",
    tabPanel(
      "Graph",
      value = "graph_workspace",
      div(
        id = "graph_editor_shell_bar",
        tags$span(id = "graph_editor_shell_label", "Editor"),
        tags$span(id = "graph_editor_shell_name", "Graph 1"),
        tags$span(id = "graph_editor_shell_state", "Graph設定を準備中…"),
        tags$button(
          id = "graph_editor_shell_edit", type = "button", class = "btn btn-primary btn-sm",
          style = "display:none;",
          "編集中"
        )
      ),
      div(
        id = "graph_workspace_section_bar",
        class = "graph-workspace-section-bar",
        role = "tablist",
        tags$button(
          type = "button", class = "btn btn-default btn-sm graph-workspace-section active",
          `data-graph-main-tab` = "Plot", onclick = "return window.ggplotGuiSelectGraphMainTab ? window.ggplotGuiSelectGraphMainTab('Plot') : false;",
          "Plot"
        ),
        tags$button(
          type = "button", class = "btn btn-default btn-sm graph-workspace-section",
          `data-graph-main-tab` = "Statistics", onclick = "return window.ggplotGuiSelectGraphMainTab ? window.ggplotGuiSelectGraphMainTab('Statistics') : false;",
          "Statistics"
        ),
        tags$button(
          type = "button", class = "btn btn-default btn-sm graph-workspace-section",
          `data-graph-main-tab` = "Data View", onclick = "return window.ggplotGuiSelectGraphMainTab ? window.ggplotGuiSelectGraphMainTab('Data View') : false;",
          "Data View"
        ),
        tags$button(
          type = "button", class = "btn btn-default btn-sm graph-workspace-section",
          `data-graph-main-tab` = "製作者コメント", onclick = "return window.ggplotGuiSelectGraphMainTab ? window.ggplotGuiSelectGraphMainTab('製作者コメント') : false;",
          "製作者コメント"
        )
      ),
      div(
        id = "graph_workspace_body",
        div(
          id = "graph_client_browser",
        div(
          id = "graph_client_browser_header",
          tags$span(id = "graph_client_browser_title", "Graph preview"),
          tags$span(id = "graph_client_browser_status", "SVG preview")
        ),
        div(
          id = "graph_client_preview_viewport",
          div(id = "graph_client_preview_canvas")
        )
        ),
        div(
          id = "graph_panels",
        # The singleton Editor DOM stays mounted and is the primary Graph workspace.
        # Graph selection automatically hydrates/synchronizes this persistent shell.
        # v3.73.2.18: Graph Preview is no longer a cached/live singleton
        # router. graph_editor_single owns one permanently mounted plot_container
        # inside its own Plot anchor; Graph switches only replay state into it.
          div(
            id = "panel_graph_editor_single",
            class = "graph-module-panel graph-single-editor-panel",
            graphUI("graph_editor_single")
          )
        )
      )
    ),
    tabPanel(
      "Figure",
      value = "figure_workspace",
      figureWorkspaceUI()
    )
  )
}

appUI <- function() {
  fluidPage(
    useShinyjs(),
    app_head_ui(),
    titlePanel("ggplot GUI"),
    project_load_overlay_ui(),
    project_manager_ui(),
    graph_workspace_ui()
  )
}
