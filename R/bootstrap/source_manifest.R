# Graph/Figure module loading order and startup precompile.
source("R/state/graph_state.R", local = TRUE)
source("R/editor/editor_profile.R", local = TRUE)
source("R/state/graph_state_overlay.R", local = TRUE)
source("R/style/graph_legend_policy.R", local = TRUE)
source("R/state/app_state_diff.R", local = TRUE)
source("R/editor/replay_plan.R", local = TRUE)
source("R/plot/graph_core_functions.R", local = TRUE)
source("R/mapping/graph_category_order.R", local = TRUE)
source("R/plot/scatter/graph_scatter_position.R", local = TRUE)
source("R/plot/bar_box/graph_bar_box_appearance.R", local = TRUE)
source("R/state/graph_snapshot_value_helpers.R", local = TRUE)
source("R/state/graph_render_state.R", local = TRUE)
source("R/data/graph_data_transform.R", local = TRUE)
source("R/state/graph_style_state_migration.R", local = TRUE)
source("R/data/graph_data_defaults.R", local = TRUE)
source("R/plot/line/graph_line_connection.R", local = TRUE)
source("R/mapping/graph_mapping_replay_helpers.R", local = TRUE)
source("R/mapping/graph_mapping_design.R", local = TRUE)
source("R/plot/graph_plot_contract.R", local = TRUE)
source("R/editor/ui/graph_ui_bindings.R", local = TRUE)
source("R/style/shared_style_state.R", local = TRUE)
source("R/diagnostics/app_function_catalog.R", local = TRUE)
source("R/editor/ui/graph_ui_module.R", local = TRUE)
source("R/plot/graph_state_plot.R", local = TRUE)
source("R/state/graph_input_value_semantics.R", local = TRUE)
source("R/export/export_text_normalization.R", local = TRUE)
source("R/export/pptx_editable_export.R", local = TRUE)
source("R/editor/graph_module.R", local = TRUE)

# v3.57: compile graphServer once during application startup, before any Graph
# replay begins. The compiled closure is reused by the one persistent Graph
# Editor and the one reusable Figure Editor.
graph_server_precompile_info <- list(
  ok = FALSE,
  elapsed_ms = NA_real_,
  error = NULL,
  env_R_ENABLE_JIT = Sys.getenv("R_ENABLE_JIT", unset = "<unset>"),
  body_type_before = typeof(body(graphServer)),
  body_type_after = NA_character_
)
.graph_server_compile_t0 <- as.numeric(proc.time()[["elapsed"]]) * 1000
.graph_server_compiled <- tryCatch(compiler::cmpfun(graphServer), error = function(e) e)
graph_server_precompile_info$elapsed_ms <- as.numeric(proc.time()[["elapsed"]]) * 1000 - .graph_server_compile_t0
if (inherits(.graph_server_compiled, "error")) {
  graph_server_precompile_info$error <- conditionMessage(.graph_server_compiled)
  graphServerCompiled <- graphServer
} else {
  graph_server_precompile_info$ok <- TRUE
  graph_server_precompile_info$body_type_after <- typeof(body(.graph_server_compiled))
  graphServerCompiled <- .graph_server_compiled
}
rm(.graph_server_compile_t0, .graph_server_compiled)

# Figure responsibilities are split before ui/server are constructed.
# v3.80.7 centralizes Figure layout semantics before state/geometry modules.
source("R/figure/layout/figure_layout_contract.R", local = TRUE)
source("R/figure/figure_state.R", local = TRUE)
source("R/figure/figure_sync_contract.R", local = TRUE)
source("R/figure/figure_interaction.R", local = TRUE)
source("R/figure/figure_layers.R", local = TRUE)
source("R/figure/layout/figure_layout_tracks.R", local = TRUE)
source("R/figure/layout/figure_layout_track_controls.R", local = TRUE)
source("R/figure/layout/figure_layout_core.R", local = TRUE)
source("R/figure/layout/figure_layout_plot.R", local = TRUE)
source("R/figure/layout/figure_layout_alignment_plan.R", local = TRUE)
source("R/figure/layout/figure_layout_auto.R", local = TRUE)
source("R/figure/layout/figure_layout_free.R", local = TRUE)
source("R/figure/layout/figure_layout_fixed_alignment.R", local = TRUE)
source("R/figure/layout/figure_layout_fixed.R", local = TRUE)
source("R/figure/figure_asset.R", local = TRUE)
source("R/figure/figure_renderer.R", local = TRUE)
source("R/export/figure_export.R", local = TRUE)
source("R/export/figure_pptx_export.R", local = TRUE)
source("R/figure/figure_ui_module.R", local = TRUE)
