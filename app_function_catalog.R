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
      graph_parse_order_text = list(kind = "pure", input = "text", output = "character vector"),
      graph_complete_order = list(kind = "pure", input = "saved + observed order", output = "character vector"),
      graph_normalise_colour = list(kind = "pure", input = "colour + fallback", output = "hex colour"),
      graph_default_palette = list(kind = "pure", input = "n + preset", output = "colour vector"),
      graph_style_input_id = list(kind = "pure", input = "style identity", output = "stable input id"),
      graph_parse_pasted_data = list(kind = "pure parser", input = "pasted text", output = "data.frame or NULL"),
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
      graph_apply_legend_guides = list(kind = "plot guide adapter", input = "ggplot + legend policy + titles", output = "ggplot with guide policy")
    ),
    graph_data = list(
      graph_normalize_data_transform_recipe = list(kind = "pure transform contract", input = "transform recipe", output = "canonical recipe"),
      graph_plot_data_transform_recipe = list(kind = "pure adapter", input = "Plot reshape state", output = "transform recipe"),
      graph_validate_wide_to_long_recipe = list(kind = "pure validator", input = "data + recipe", output = "validation result"),
      graph_apply_wide_to_long = list(kind = "pure transform", input = "data + canonical Wide→Long recipe", output = "transform result"),
      graph_apply_data_transform = list(kind = "pure dispatcher", input = "data + recipe", output = "transform result"),
      graph_default_reshape_columns = list(kind = "pure UI/data default", input = "data.frame", output = "default reshape columns"),
      graph_default_mapping_for_data = list(kind = "pure UI/data default", input = "data.frame", output = "default Mapping"),
      graph_state_materialize_dynamic_style_defaults = list(kind = "pure GraphState style migration", input = "GraphState + prepared data", output = "schema-4 GraphState with deterministic Style defaults"),
      graph_state_prepare_replay_snapshot = list(kind = "pure GraphState migration", input = "GraphState", output = "GraphState with replayable UI snapshot + current style schema")
    ),
    statistics = list(
      normalize_stats_recipe = list(kind = "analysis-state canonicalizer", input = "saved Analysis recipe", output = "canonical recipe"),
      stats_request_restore_barrier = list(kind = "Statistics restore barrier", input = "Analysis id + restore token + attempt", output = "browser round-trip ACK request"),
      stats_settle_restore_barrier = list(kind = "Statistics restore settle", input = "Analysis id + restore token + attempt", output = "stable release or next bounded barrier"),
      stats_capture_recipe_from_inputs = list(kind = "Statistics state adapter", input = "current Analysis recipe + active-type Statistics inputs", output = "updated recipe"),
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
      figureExportWorkflowUI = list(kind = "UI component", input = "none", output = "export step"),
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
      select_graph_preview = list(kind = "server compatibility selection transaction", input = "Graph id + source", output = "selection/Preview publication without browse-mode ownership"),
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
      request_figure_source_snapshot = list(kind = "direct-state Figure snapshot service", input = "Graph id + optional GraphState override", output = "Figure-owned SVG snapshot"),
      registry_commit = list(kind = "server state mutation", input = "Graph id + state", output = "canonical Registry update")
    )
  )
}
