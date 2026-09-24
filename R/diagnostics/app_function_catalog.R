# ============================================================
# Maintainer-facing function catalog
# ============================================================
# This is metadata, not a dispatcher.  It identifies canonical entry points
# that new work should extend/reuse rather than bypassing with new ad-hoc logic.

app_function_catalog <- function() {
  list(
    app = list(
      app_version = list(kind = "pure", input = "none", output = "version string"),
      appUI = list(kind = "UI composition", input = "none", output = "Shiny tag tree"),
      project_manager_ui = list(kind = "UI component", input = "none", output = "Shiny tag tree"),
      graph_workspace_ui = list(kind = "UI component", input = "none", output = "Shiny tag tree")
    ),
    graph_core = list(
      graph_has_selection = list(kind = "pure", input = "value", output = "logical"),
      graph_safe_num1 = list(kind = "pure", input = "value + default", output = "scalar numeric"),
      graph_saved_plot_size_from_state = list(kind = "pure", input = "GraphState", output = "width/height list"),
      graph_complete_order = list(kind = "pure", input = "saved + observed order", output = "character vector"),
      graph_normalize_order_state = list(kind = "pure category-order canonicalizer", input = "saved order tree", output = "structured x/group/display/facet vectors"),
      graph_category_order_move = list(kind = "pure category-order transition", input = "order + index + direction", output = "reordered character vector"),
      graph_scatter_jitter_spec = list(kind = "pure scatter-position contract", input = "enabled + X/Y widths", output = "canonical jitter spec"),
      graph_bar_box_border_linetype = list(kind = "pure Bar/Box border contract", input = "linetype mode + dash/gap", output = "ggplot linetype"),
      graph_bar_box_apply_no_fill = list(kind = "pure Bar/Box fill resolver", input = "named fill colours + no-fill keys", output = "named fill vector with semantic NA fills"),
      graph_normalise_colour = list(kind = "pure", input = "colour + fallback", output = "hex colour"),
      graph_default_palette = list(kind = "pure", input = "n + preset", output = "colour vector"),
      graph_mapping_is_x_determined = list(kind = "pure Mapping semantics", input = "data + X + variable + facet", output = "logical"),
      graph_effective_slot_vars = list(kind = "pure Mapping semantics", input = "data + X + Bar/Box slot candidates + facet", output = "effective stable-track variables"),
      graph_stable_track_order = list(kind = "pure Mapping semantics", input = "data + effective Bar/Box track variables", output = "observed global track order"),
      graph_line_series_vars = list(kind = "pure Mapping semantics", input = "data + X + visual Mapping candidates + series mode", output = "line-series identity variables"),
      graph_mapping_diagnostics = list(kind = "pure visual diagnostic", input = "data + Mapping + plot type", output = "non-canonical diagnostic messages"),
      graph_style_input_id = list(kind = "pure", input = "style identity", output = "stable input id"),
      graph_parse_pasted_data = list(kind = "pure parser", input = "pasted text", output = "data.frame or NULL"),
      graph_line_break_choices = list(kind = "pure line-connection helper", input = "ordered X levels + display labels", output = "adjacent X-boundary choices"),
      graph_line_break_apply_group = list(kind = "pure line-connection helper", input = "data + X order + selected boundaries + existing group", output = "line-only segmented grouping"),
      graph_line_break_plan = list(kind = "pure replay helper", input = "GraphState + Mapping replay plan", output = "target-derived line-break choices + selection"),
      app_state_diff_paths = list(kind = "pure diagnostic", input = "old/new state", output = "changed paths"),
      app_state_diff_summary = list(kind = "pure diagnostic", input = "old/new state", output = "compact diff summary"),
      graph_render_state_apply_semantics = list(kind = "pure render canonicalizer", input = "GraphState", output = "GraphState with inactive render controls collapsed"),
      graph_render_state = list(kind = "pure render contract", input = "GraphState", output = "canonical RenderState"),
      graph_render_state_changed = list(kind = "pure render contract", input = "old/new GraphState", output = "logical"),
      app_normalize_font_family_mode = list(kind = "pure canonicalizer", input = "font selector value", output = "canonical mode/family"),
      app_normalize_font_family_custom = list(kind = "pure canonicalizer", input = "custom font text", output = "trimmed family"),
      app_effective_font_family = list(kind = "pure resolver", input = "mode + custom", output = "ggplot family"),
      graph_build_legend_policy = list(kind = "pure Legend Policy", input = "effective Mapping + appearance + plot/layer context", output = "aesthetic guide policy"),
      graph_legend_merge_plan = list(kind = "pure Legend Policy", input = "legend policy", output = "aesthetic merge components"),
      graph_legend_layer_flags = list(kind = "pure Legend Policy", input = "legend policy + layer role", output = "named show.legend flags"),
      graph_legend_layout_args = list(kind = "pure Legend Policy", input = "legend wrap mode + count", output = "guide_legend layout args"),
      graph_apply_legend_guides = list(kind = "plot guide adapter", input = "ggplot + legend policy + titles + layout", output = "ggplot with guide policy")
    ),
    graph_data = list(
      graph_normalize_data_transform_recipe = list(kind = "pure transform contract", input = "transform recipe", output = "canonical recipe"),
      graph_plot_data_transform_recipe = list(kind = "pure adapter", input = "Plot reshape state", output = "transform recipe"),
      graph_validate_wide_to_long_recipe = list(kind = "pure validator", input = "data + recipe", output = "validation result"),
      graph_apply_wide_to_long = list(kind = "pure transform", input = "data + canonical Wide→Long recipe", output = "transform result"),
      graph_apply_data_transform = list(kind = "pure dispatcher", input = "data + recipe", output = "transform result"),
      graph_default_reshape_columns = list(kind = "pure UI/data default", input = "data.frame", output = "default reshape columns"),
      graph_default_mapping_for_data = list(kind = "pure UI/data default", input = "data.frame", output = "default Mapping"),
      graph_data_column_name_status = list(kind = "pure data validation", input = "data.frame", output = "column-name validity/status"),
      graph_usable_column_names = list(kind = "pure data validation", input = "data.frame", output = "safe unique nonblank column names"),
      graph_style_migrate_v6 = list(kind = "pure Style migration", input = "saved Style", output = "style schema 6 with Bar/Box fill/border defaults"),
      graph_state_materialize_dynamic_style_defaults = list(kind = "pure GraphState style migration", input = "GraphState + prepared data", output = "GraphState with deterministic Style defaults"),
      graph_state_migrate_v5 = list(kind = "pure GraphState migration", input = "GraphState", output = "schema-5 GraphState with current Mapping/Appearance defaults"),
      graph_state_prepare_replay_snapshot = list(kind = "pure GraphState migration", input = "GraphState", output = "schema-5 GraphState with replayable UI snapshot + current style schema")
    ),
    statistics = list(
      normalize_stats_recipe = list(kind = "analysis-state canonicalizer", input = "saved Analysis recipe", output = "canonical recipe"),
      stats_request_restore_barrier = list(kind = "Statistics restore barrier", input = "Analysis id + restore token + attempt", output = "browser round-trip ACK request"),
      stats_settle_restore_barrier = list(kind = "Statistics restore settle", input = "Analysis id + restore token + attempt", output = "stable release or next bounded barrier"),
      stats_replace_graph_context = list(kind = "Statistics Graph-switch boundary", input = "target Graph recipes + preferred Analysis", output = "replaced persistent Statistics context"),
      stats_capture_recipe_from_inputs = list(kind = "Statistics state adapter", input = "current Analysis recipe + active-type Statistics inputs", output = "updated recipe"),
      stats_selected_id_for_project = list(kind = "Statistics persistence boundary", input = "current selected Analysis + recipes", output = "Graph-local Analysis id or NULL"),
      stats_recipes_for_project = list(kind = "Statistics persistence boundary", input = "current Analysis state", output = "serializable recipes")
    ),
    shared_style = list(
      shared_style_normalize_library = list(kind = "pure canonicalizer", input = "Library definition", output = "canonical Shared Library"),
      shared_style_normalize_binding = list(kind = "pure canonicalizer", input = "per-Graph semantic binding", output = "canonical binding"),
      shared_style_normalize_graph_state = list(kind = "pure compatibility canonicalizer", input = "GraphState", output = "GraphState with explicit binding metadata"),
      shared_style_apply_to_graph_state = list(kind = "pure semantic materializer", input = "GraphState + Shared Library", output = "GraphState with concrete style values"),
      shared_style_update_library_from_graph_state = list(kind = "pure write-through adapter", input = "Shared Library + linked GraphState", output = "updated Library definition"),
      shared_style_resolve_writeback = list(kind = "pure conflict resolver", input = "current semantic value + linked candidates", output = "unambiguous write-through value"),
      shared_style_commit_library = list(kind = "server semantic transaction", input = "Shared Library + source", output = "affected Graph/Figure propagation"),
      shared_style_apply_figure_states = list(kind = "Figure semantic transaction", input = "Shared Library + reason", output = "direct-state Figure snapshot rebuilds")
    ),
    figure_workflow = list(
      figureWorkflowHeaderUI = list(kind = "UI component", input = "none", output = "workflow header"),
      figureImportWorkflowUI = list(kind = "UI component", input = "none", output = "Figure import step"),
      figureLayoutWorkflowUI = list(kind = "UI component", input = "none", output = "layout/alignment step"),
      figureCanvasControlsUI = list(kind = "UI component", input = "none", output = "visible Canvas controls"),
      figureLayoutPrimaryControlsUI = list(kind = "UI component", input = "none", output = "visible primary layout controls"),
      figureSharedStylePanelUI = list(kind = "UI component", input = "none", output = "Shared Style step"),
      figureSelectedPanelDrawerUI = list(kind = "UI component", input = "none", output = "individual adjustment drawer"),
      figureTopExportUI = list(kind = "UI component", input = "none", output = "workspace-aware top Figure output bar"),
      figurePreviewWorkflowUI = list(kind = "UI component", input = "none", output = "Figure preview shell"),
      figureWorkspaceUI = list(kind = "UI composition", input = "none", output = "workflow-first Figure workspace"),
      figure_reorder_content_state = list(kind = "pure Figure reorder transition", input = "layout + source/destination slot + swap/shift mode", output = "validated layout transition"),
      figure_reset_content_order_state = list(kind = "pure Figure reorder transition", input = "layout + canonical source order", output = "validated default-order transition"),
      figure_validate_reorder_state = list(kind = "pure Figure ownership validator", input = "before/after layout", output = "slot/content invariant result")
    ),
    plot_type_contract = list(
      graph_plot_type_specs = list(kind = "pure contract", input = "none", output = "plot specs"),
      graph_plot_type_normalize = list(kind = "pure contract", input = "plot type", output = "canonical plot type"),
      graph_plot_supports_mapping = list(kind = "pure contract", input = "plot type + mapping", output = "logical"),
    ),
    graph_ui = list(
      graph_ui_seeded_args = list(kind = "pure UI helper", input = "seed + args", output = "seeded args"),
      graph_ui_seeded_bindings = list(kind = "UI factory", input = "namespace + GraphState seed", output = "namespaced control functions"),
      graphUI = list(kind = "UI composition", input = "Graph id + state", output = "Graph editor tag tree")
    ),
    figure_sync = list(
      figure_state_ownership_contract = list(kind = "pure contract", input = "none", output = "Graph/Figure ownership contract"),
      figure_source_apply_payload = list(kind = "pure contract", input = "Figure GraphState + canonical source GraphState", output = "source-owned GraphState payload"),
      figure_source_apply_diff = list(kind = "pure diagnostic", input = "source/Figure GraphState", output = "changed paths"),
      figure_graphstate_style_summary = list(kind = "pure diagnostic", input = "GraphState", output = "compact style summary")
    ),
    graph_lifecycle = list(
      graphServer = list(kind = "Shiny module owner", input = "id/state/callbacks", output = "module API"),
      request_graph_editor = list(kind = "server editor-first transaction", input = "Graph id + source", output = "persistent Editor replay or latest-target queue"),
      resume_graph_workspace = list(kind = "server workspace lifecycle", input = "current selection/owner", output = "same-owner canonical resync or selected Graph replay"),
      graph_single_load = list(kind = "internal editor transaction", input = "Graph id", output = "side effects: canonical value replay + one live render"),
      graph_single_default_state_snapshot = list(kind = "editor default-state source", input = "reason", output = "deep-copied canonical default GraphState"),
      graph_accept_attached_canonical = list(kind = "render acceptance boundary", input = "outer-accepted canonical GraphState", output = "module attachment + pending render target"),
      graph_apply_state_replay = list(kind = "persistent Editor replay", input = "canonical GraphState + UI snapshot", output = "target-derived choices + batched value replay + one browser completion barrier"),
      graph_release_attached_render_target = list(kind = "render transaction boundary", input = "accepted attached GraphState", output = "single render revision release"),
      seed_new_graph_default_state = list(kind = "new-Graph canonical initializer", input = "Graph id + reason", output = "Registry default-state commit"),
      graph_single_abort_activation = list(kind = "editor transaction fail-safe", input = "Graph id + reason", output = "stale shell clear + explicit reselection"),
      graph_preview_record_from_plot = list(kind = "direct-state vector snapshot helper", input = "GraphState + plot + export meta", output = "caller-owned SVG record or NULL"),
      graph_state_export_snapshot = list(kind = "pure direct-state export renderer", input = "GraphState", output = "plot + measured export metadata"),
      export_text_normalize_character = list(kind = "export-only compatibility normalizer", input = "external text payload", output = "confirmed fullwidth percent substitutions only"),
      export_text_normalize_utf8_file = list(kind = "export-only UTF-8 postprocessor", input = "SVG/XML path", output = "normalized external payload + replacement count"),
      pptx_write_ggplot_editable = list(kind = "Graph PowerPoint export boundary", input = "ggplot + physical export size", output = "editable DrawingML pptx with safe wrapper flattening"),
      pptx_flatten_editable_groups = list(kind = "PowerPoint postprocessor", input = "generated pptx + owned label prefix", output = "identity wrapper groups flattened; child shapes exposed"),
      pptx_validate_package_structure = list(kind = "PowerPoint package guard", input = "pptx path", output = "required OPC paths validated before/after postprocessing"),
      figure_pptx_prepare_editable_sources = list(kind = "Figure PowerPoint source materializer", input = "Figure ids + in-memory plots + Figure-owned GraphStates", output = "export-local editable ggplot sources + legacy fallback ids"),
      request_figure_source_snapshot = list(kind = "direct-state Figure snapshot service", input = "Graph id + optional GraphState override", output = "Figure-owned SVG snapshot"),
      registry_commit = list(kind = "server state mutation", input = "Graph id + state", output = "canonical Registry update")
    )
  )
}
