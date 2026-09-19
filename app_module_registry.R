# Graph/Figure module loading order and startup precompile.
source("graph_state.R", local = TRUE)
source("app_state_diff.R", local = TRUE)
source("graph_core_functions.R", local = TRUE)
source("graph_render_state.R", local = TRUE)
source("graph_data_transform.R", local = TRUE)
source("graph_style_state_migration.R", local = TRUE)
source("graph_data_defaults.R", local = TRUE)
source("graph_plot_contract.R", local = TRUE)
source("graph_ui_bindings.R", local = TRUE)
source("shared_style_state.R", local = TRUE)
source("app_function_catalog.R", local = TRUE)
source("graph_ui_module.R", local = TRUE)
source("graph_state_plot.R", local = TRUE)
source("graph_module.R", local = TRUE)

# v3.57: compile graphServer once during application startup, before any Graph
# hydrate begins.  The compiled closure is reused by source Graphs and Figure
# editors; canonical state / restore behavior is unchanged.
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

# v3.3.56 Figure responsibilities are split before ui/server are constructed.
source("figure_state.R", local = TRUE)
source("figure_sync_contract.R", local = TRUE)
source("figure_interaction.R", local = TRUE)
source("figure_layers.R", local = TRUE)
source("figure_layout.R", local = TRUE)
source("figure_asset.R", local = TRUE)
source("figure_renderer.R", local = TRUE)
source("figure_export.R", local = TRUE)
source("figure_ui_module.R", local = TRUE)
