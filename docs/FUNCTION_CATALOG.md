# Function catalog

This catalog is generated from the **current executable R source tree** for v3.73.2.39. Line numbers are navigation aids, not stable API identifiers. Removed files/functions are intentionally absent.

## Canonical extension points

- **Graph canonical/render semantics:** `graph_state.R`, `graph_render_state.R`, `graph_state_boundary_runtime.R`
- **Persistent Graph Editor ownership/switching:** `server_graph_editor_runtime.R`
- **GraphState value replay:** `server_graph_state_replay_runtime.R`
- **Persistent Editor local primitives:** `graph_editor_primitives_runtime.R`
- **Graph data/Mapping/plot preparation:** `graph_data_runtime.R`, `graph_data_transform.R`, `graph_prepared_data_runtime.R`, `graph_plot_runtime.R`
- **Statistics Analysis recipes:** `graph_statistics_runtime.R`
- **Figure state/ownership/rendering:** `figure_state.R`, `figure_sync_contract.R`, `server_figure_source_snapshot_runtime.R`, `server_figure_workspace_runtime.R`
- **Graph Settings Manager:** `server_graph_settings_manager_runtime.R`, `server_graph_settings_value_runtime.R`, `server_graph_settings_batch_runtime.R`
- **Shared Style:** `shared_style_state.R`, `server_shared_style_runtime.R`
- **Graph export:** `server_graph_export_runtime.R`, `server_export_prepare_runtime.R`
- **Project IO:** `server_project_io_runtime.R`

## Removed architecture (must not appear in the function index)

`server_graph_materialization_runtime.R`, `graph_restore_runtime.R`, hidden per-Graph Editor helpers, Graph remount APIs, Graph restore retry/reconcile APIs, and the old fast/equivalent switch runtime are not current extension points.

## Complete function index
### `app_config.R`
- `app_version()` — line 4, top-level

### `app_function_catalog.R`
- `app_function_catalog()` — line 7, top-level

### `app_shared_helpers.R`
- `scan_app_fonts()` — line 9, top-level
- `app_font_choices()` — line 38, top-level
- `app_font_available()` — line 59, top-level
- `app_normalize_font_family_mode()` — line 69, top-level
- `app_normalize_font_family_custom()` — line 83, top-level
- `app_effective_font_family()` — line 88, top-level
- `normalize_multiline_label()` — line 98, top-level
- `app_open_png_device()` — line 106, top-level
- `app_save_plot_png()` — line 118, top-level
- `apply_fixed_panel_size()` — line 138, top-level
- `measure_plot_geometry_px()` — line 160, top-level
- `empty_bbox()` — line 169, nested/local
- `bbox_for_idx()` — line 213, nested/local
- `guide_is_visible()` — line 242, nested/local
- `legend_visual_bbox_for_idx()` — line 263, nested/local
- `clamp_bbox()` — line 330, nested/local
- `measure_plot_size_px()` — line 363, top-level

### `app_state_diff.R`
- `app_state_diff_paths()` — line 7, top-level
- `walk()` — line 11, nested/local
- `app_state_diff_summary()` — line 44, top-level

### `figure_asset.R`
- `figure_make_internal_asset()` — line 4, top-level
- `figure_asset_has_svg()` — line 26, top-level
- `figure_external_asset_id()` — line 30, top-level
- `figure_file_to_data_uri()` — line 44, top-level
- `figure_import_external_asset()` — line 59, top-level
- `figure_asset_source_choices()` — line 87, top-level
- `figure_decorate_external_asset()` — line 98, top-level
- `figure_external_legend_asset()` — line 114, top-level
- `figure_asset_display_name()` — line 121, top-level

### `figure_export.R`
- `figure_draw_plot_grob_cropped()` — line 4, top-level
- `figure_extract_legend_grob()` — line 43, top-level
- `figure_svg_straight_rgba()` — line 53, top-level
- `figure_svg_snapshot_diagnostics()` — line 94, top-level
- `figure_svg_snapshot_grob()` — line 148, top-level
- `figure_draw_persisted_svg_panel()` — line 156, top-level
- `figure_export_plot_spec()` — line 215, top-level
- `figure_draw_detached_legend_plot()` — line 287, top-level
- `figure_export_inset_record()` — line 339, top-level
- `figure_draw_to_device()` — line 353, top-level
- `figure_svg_escape_text()` — line 604, top-level
- `figure_svg_fragment_parts()` — line 613, top-level
- `attr_value()` — line 619, nested/local
- `figure_svg_place_fragment()` — line 672, top-level
- `figure_inset_export_content_box()` — line 716, top-level
- `figure_write_svg_vector()` — line 744, top-level
- `next_prefix()` — line 754, nested/local
- `make_clip()` — line 755, nested/local

### `figure_interaction.R`
- `figure_apply_layout_edit_state()` — line 4, top-level
- `figure_apply_drag_override_state()` — line 96, top-level
- `figure_apply_free_panel_drag_state()` — line 141, top-level
- `figure_content_package()` — line 180, top-level
- `figure_assign_content_package()` — line 190, top-level
- `figure_layout_slot_index()` — line 199, top-level
- `figure_layout_source_at_key()` — line 209, top-level
- `figure_layout_key_for_source()` — line 219, top-level
- `figure_layout_key_position()` — line 229, top-level
- `figure_content_package_signature()` — line 239, top-level
- `num()` — line 240, nested/local
- `figure_slot_owned_signature()` — line 252, top-level
- `figure_validate_reorder_state()` — line 258, top-level
- `figure_reset_content_order_state()` — line 282, top-level
- `rank_for()` — line 293, nested/local
- `figure_reorder_content_state()` — line 320, top-level
- `figure_shift_adjacent_state()` — line 356, top-level
- `figure_override_change_class()` — line 378, top-level

### `figure_layers.R`
- `figure_layer_z()` — line 16, top-level
- `figure_legend_layer_scope()` — line 22, top-level
- `figure_legend_is_detached()` — line 30, top-level
- `figure_legend_source_origin()` — line 34, top-level
- `figure_layer_source_override()` — line 57, top-level
- `figure_layer_valid_bbox()` — line 72, top-level
- `figure_layer_map_bbox_to_body()` — line 82, top-level
- `num()` — line 85, nested/local
- `figure_layer_persisted_owner_meta()` — line 98, top-level
- `figure_layer_scale_bbox()` — line 117, top-level
- `figure_graph_display_frame()` — line 127, top-level
- `figure_layer_inset_local_position()` — line 139, top-level
- `num()` — line 143, nested/local
- `figure_layer_inset_canvas_position()` — line 161, top-level
- `figure_layer_legend_bbox()` — line 174, top-level
- `figure_layer_legend_side()` — line 186, top-level
- `figure_layer_legend_local_position()` — line 205, top-level
- `figure_layer_legend_canvas_position()` — line 223, top-level

### `figure_layout.R`
- `figure_layout_rects()` — line 6, top-level
- `figure_auto_outer_margin()` — line 76, top-level
- `figure_size_basis_bbox()` — line 78, top-level
- `bbox_valid()` — line 80, nested/local
- `bbox_union()` — line 86, nested/local
- `figure_axis_gutter_metrics()` — line 117, top-level
- `bb()` — line 118, nested/local
- `figure_legend_slot_metrics()` — line 151, top-level
- `bb()` — line 152, nested/local
- `figure_title_bbox_metrics()` — line 182, top-level
- `figure_crop_fractions()` — line 194, top-level
- `figure_attach_crop_metadata()` — line 209, top-level
- `figure_apply_crop_footprint()` — line 229, top-level
- `figure_uncropped_rect()` — line 244, top-level
- `figure_crop_render_geometry()` — line 259, top-level
- `figure_natural_graph_size()` — line 288, top-level
- `figure_auto_layout_geometry()` — line 359, top-level
- `figure_expand_auto_canvas_for_free_legends()` — line 639, top-level
- `figure_override_for()` — line 692, top-level
- `scalar_chr()` — line 695, nested/local
- `scalar_num()` — line 699, nested/local
- `figure_apply_layer_style_override()` — line 841, top-level
- `figure_apply_y_range_override()` — line 881, top-level
- `figure_apply_plot_override()` — line 906, top-level
- `figure_label_band()` — line 959, top-level
- `figure_plot_for_scale()` — line 976, top-level
- `figure_graph_target_box()` — line 1042, top-level
- `figure_plot_spec_for_rect()` — line 1089, top-level
- `figure_plot_offsets()` — line 1117, top-level
- `figure_label_position()` — line 1164, top-level
- `figure_plot_panel_zone()` — line 1191, top-level
- `figure_legend_handle_position()` — line 1210, top-level
- `figure_seed_free_geometry()` — line 1222, top-level
- `figure_free_layout_geometry()` — line 1249, top-level
- `figure_crop_css()` — line 1325, top-level
- `figure_fixed_basis_layout_geometry()` — line 1347, top-level
- `align_offset()` — line 1376, nested/local
- `num()` — line 1383, nested/local
- `figure_rebind_frozen_geometry()` — line 1546, top-level

### `figure_renderer.R`
- `figure_svg_viewport_text()` — line 5, top-level
- `figure_detached_legend_background_mode()` — line 18, top-level
- `figure_apply_detached_legend_background()` — line 26, top-level
- `figure_select_guide_box_grob()` — line 37, top-level
- `figure_legend_asset_is_valid()` — line 64, top-level
- `figure_legend_grob_asset()` — line 71, top-level
- `figure_plot_svg_text()` — line 173, top-level
- `figure_fit_cached_geometry()` — line 216, top-level
- `val()` — line 232, nested/local
- `scale_bbox()` — line 236, nested/local
- `figure_scale_geometry_meta()` — line 264, top-level
- `val()` — line 268, nested/local
- `scale_bbox()` — line 272, nested/local
- `figure_plot_spec_for_rect_whole_scale()` — line 293, top-level
- `figure_persisted_spec_for_rect()` — line 333, top-level
- `figure_external_asset_node()` — line 391, top-level
- `figure_valid_bbox()` — line 404, top-level
- `figure_detached_legend_side()` — line 411, top-level
- `figure_detached_svg_parts()` — line 416, top-level
- `svg_node()` — line 430, nested/local
- `figure_build_inset_layer_ui()` — line 442, top-level
- `figure_build_detached_legend_layer_ui()` — line 483, top-level
- `figure_build_label_layer_ui()` — line 543, top-level
- `figure_build_cell_ui()` — line 561, top-level

### `figure_state.R`
- `figure_make_cell()` — line 5, top-level
- `figure_num_or()` — line 47, top-level
- `figure_reindex_layout()` — line 53, top-level
- `figure_sanitize_layout()` — line 110, top-level
- `figure_normalize_legend_title_mode()` — line 144, top-level
- `figure_apply_slot_label_to_override()` — line 152, top-level
- `figure_slot_label_payload()` — line 163, top-level
- `figure_strip_slot_label_fields_from_override()` — line 179, top-level
- `figure_default_appearance_override()` — line 193, top-level
- `figure_default_external_legend()` — line 212, top-level
- `figure_default_crop()` — line 221, top-level
- `figure_default_inset()` — line 225, top-level
- `figure_default_override()` — line 236, top-level
- `figure_reset_slot_free_positions()` — line 276, top-level
- `figure_reset_override_free_positions()` — line 285, top-level
- `figure_default_layout_state()` — line 309, top-level
- `figure_default_workspace_state()` — line 318, top-level

### `figure_sync_contract.R`
- `figure_state_ownership_contract()` — line 9, top-level
- `figure_source_apply_payload()` — line 28, top-level
- `figure_source_apply_diff()` — line 55, top-level
- `figure_graphstate_style_summary()` — line 61, top-level
- `scalar_chr()` — line 65, nested/local
- `tree_txt()` — line 70, nested/local

### `figure_ui_module.R`
- `figureWorkflowHeaderUI()` — line 5, top-level
- `figureImportWorkflowUI()` — line 19, top-level
- `figureCanvasControlsUI()` — line 34, top-level
- `figureLayoutPrimaryControlsUI()` — line 73, top-level
- `figureLayoutWorkflowUI()` — line 104, top-level
- `figureSharedStylePanelUI()` — line 130, top-level
- `figureSelectedPanelDrawerUI()` — line 208, top-level
- `figureExportWorkflowUI()` — line 296, top-level
- `figurePreviewWorkflowUI()` — line 312, top-level
- `figureWorkspaceUI()` — line 338, top-level
- `figureSelectedPanelHeaderUI()` — line 354, top-level
- `figureOverrideDetailUI()` — line 367, top-level
- `fold_class()` — line 373, nested/local

### `graph_core_functions.R`
- `graph_has_selection()` — line 8, top-level
- `graph_safe_num1()` — line 12, top-level
- `graph_restore_size_value()` — line 20, top-level
- `graph_saved_plot_size_from_state()` — line 27, top-level
- `graph_parse_order_text()` — line 40, top-level
- `graph_complete_order()` — line 46, top-level
- `graph_lighten_colour()` — line 52, top-level
- `graph_normalise_colour()` — line 59, top-level
- `graph_default_palette()` — line 68, top-level
- `graph_default_linetypes()` — line 82, top-level
- `graph_default_shapes()` — line 86, top-level
- `graph_style_input_id()` — line 90, top-level
- `graph_series_combo_key()` — line 100, top-level
- `graph_parse_pasted_data()` — line 104, top-level

### `graph_data_defaults.R`
- `graph_sample_data_text()` — line 7, top-level
- `graph_default_reshape_columns()` — line 27, top-level
- `graph_default_mapping_for_data()` — line 44, top-level
- `graph_state_prepare_replay_snapshot()` — line 149, top-level
- `scalar_chr()` — line 170, nested/local
- `graph_sample_graph_state()` — line 192, top-level

### `graph_data_runtime.R`
- `set_reshape_warning()` — line 29, nested/local
- `keep()` — line 190, nested/local
- `choose_column()` — line 289, nested/local
- `release_seed()` — line 353, nested/local
- `effective_position_var()` — line 378, nested/local
- `resolve_color_var()` — line 387, nested/local
- `resolve_linetype_var()` — line 393, nested/local
- `resolve_shape_var()` — line 403, nested/local

### `graph_data_transform.R`
- `graph_normalize_data_transform_recipe()` — line 8, top-level
- `graph_plot_data_transform_recipe()` — line 45, top-level
- `graph_validate_wide_to_long_recipe()` — line 57, top-level
- `graph_apply_wide_to_long()` — line 84, top-level
- `graph_apply_data_transform()` — line 125, top-level

### `graph_editor_primitives_runtime.R`
- `json_chr()` — line 11, nested/local

### `graph_helpers_runtime.R`
- `style_input_id()` — line 37, nested/local
- `legend_title_value()` — line 73, nested/local
- `level_label_values()` — line 86, nested/local
- `get_saved_order()` — line 104, nested/local
- `set_saved_order()` — line 111, nested/local
- `ensure_style_branch()` — line 117, nested/local
- `aesthetic_style_vector()` — line 154, nested/local
- `color_style_vector()` — line 172, nested/local
- `linetype_style_vector()` — line 175, nested/local
- `shape_style_vector()` — line 178, nested/local
- `migrate_legacy_group_styles()` — line 182, nested/local
- `scalar_chr()` — line 184, nested/local
- `scalar_num()` — line 188, nested/local
- `ensure_series_styles()` — line 226, nested/local
- `series_style_vectors()` — line 244, nested/local

### `graph_module.R`
- `graphServer()` — line 6, top-level
- `init_timing_emit()` — line 9, nested/local
- `diag()` — line 29, nested/local
- `statistics_plot_preview()` — line 58, nested/local
- `textInput()` — line 97, nested/local
- `selectInput()` — line 98, nested/local
- `checkboxInput()` — line 99, nested/local
- `checkboxGroupInput()` — line 100, nested/local
- `sliderInput()` — line 101, nested/local
- `numericInput()` — line 102, nested/local
- `actionButton()` — line 103, nested/local
- `downloadButton()` — line 104, nested/local
- `fileInput()` — line 105, nested/local
- `uiOutput()` — line 106, nested/local
- `plotOutput()` — line 107, nested/local
- `tableOutput()` — line 108, nested/local
- `verbatimTextOutput()` — line 109, nested/local
- `colourInput()` — line 110, nested/local

### `graph_output_runtime.R`
- `send_plot_dimensions()` — line 164, nested/local

### `graph_plot_calculation.R`
- `aes_ref()` — line 26, nested/local
- `dynamic_aes()` — line 30, nested/local
- `add_interaction_key()` — line 49, nested/local
- `make_slot_layout()` — line 65, nested/local
- `apply_slot_layout()` — line 100, nested/local
- `decorate_style()` — line 146, nested/local
- `aes_levels()` — line 188, nested/local
- `combo_display_labels()` — line 233, nested/local
- `add_id_line_layers()` — line 362, nested/local
- `add_one()` — line 368, nested/local
- `add_raw_point_layers()` — line 418, nested/local
- `add_one()` — line 421, nested/local
- `add_summary_line_point()` — line 663, nested/local
- `add_summary_errorbar()` — line 688, nested/local
- `add_individual_layers()` — line 720, nested/local
- `legend_title_lab_value()` — line 1371, nested/local
- `set_legend_lab()` — line 1375, nested/local

### `graph_plot_contract.R`
- `graph_plot_type_specs()` — line 8, top-level
- `graph_plot_type_ids()` — line 33, top-level
- `graph_plot_type_choices()` — line 37, top-level
- `graph_plot_type_normalize()` — line 44, top-level
- `graph_plot_type_spec()` — line 54, top-level
- `graph_plot_supports_mapping()` — line 58, top-level

### `graph_plot_data_calculation.R`
- `compute_plot_data()` — line 1, top-level
- `compute_summary_grouping_vars()` — line 174, top-level
- `compute_id_mean_data()` — line 195, top-level
- `compute_display_observation_data()` — line 244, top-level
- `compute_summary_data()` — line 252, top-level
- `compute_direct_value_mode()` — line 273, top-level
- `compute_theme_object()` — line 278, top-level
- `external_error_bounds()` — line 314, top-level
- `add_stable_spread()` — line 370, top-level

### `graph_plot_runtime.R`
- `y_break_values()` — line 6, nested/local

### `graph_prepared_data_runtime.R`
- `apply_font_family_state_to_editor()` — line 107, nested/local

### `graph_render_error_runtime.R`
- `graph_plot_error_placeholder()` — line 5, top-level
- `graph_render_plot_safely()` — line 25, top-level

### `graph_render_state.R`
- `graph_render_state_apply_semantics()` — line 9, top-level
- `graph_render_state()` — line 54, top-level
- `graph_render_diff_paths()` — line 142, top-level
- `graph_render_state_changed()` — line 146, top-level

### `graph_shared_style_runtime.R`
- `shared_style_choices()` — line 6, nested/local
- `shared_style_apply_local()` — line 167, nested/local

### `graph_snapshot_value_helpers.R`
- `manual_y_break_values()` — line 2, top-level
- `scalar_finite()` — line 4, nested/local
- `valid_graph_preview_record()` — line 22, top-level
- `positive_scalar()` — line 23, nested/local

### `graph_state.R`
- `graph_state_scalar()` — line 6, top-level
- `graph_ui_seed_from_state()` — line 13, top-level
- `put()` — line 17, nested/local
- `graph_ui_snapshot_normalize()` — line 84, top-level
- `normalize_panel_tree()` — line 87, nested/local
- `graph_ui_snapshot_merge()` — line 106, top-level
- `graph_state_with_ui_snapshot()` — line 116, top-level

### `graph_state_boundary_runtime.R`
- `is_shiny_control_condition()` — line 9, top-level
- `graph_live_project_state_snapshot()` — line 13, top-level
- `graph_editor_arbitration_state_snapshot()` — line 40, top-level
- `graph_seed_render_target()` — line 59, top-level
- `graph_accept_attached_canonical()` — line 67, top-level
- `graph_release_render_revision()` — line 80, top-level
- `graph_release_attached_render_target()` — line 130, top-level
- `install_graph_render_revision_runtime()` — line 136, top-level

### `graph_state_plot.R`
- `graph_build_plot()` — line 8, top-level
- `graph_snapshot_input_defaults()` — line 16, top-level
- `graph_snapshot_inputs()` — line 52, top-level
- `graph_snapshot_data()` — line 66, top-level
- `graph_snapshot_store()` — line 83, top-level
- `graph_snapshot_memo()` — line 91, top-level
- `graph_snapshot_context()` — line 104, top-level
- `resolved_xvar()` — line 124, nested/local
- `resolved_yvar()` — line 125, nested/local
- `selected_font_family()` — line 126, nested/local
- `graph_state_figure_snapshot()` — line 136, top-level
- `graph_state_export_snapshot()` — line 158, top-level

### `graph_state_plot_helpers.R`
- `legend_title_value()` — line 2, top-level
- `level_label_values()` — line 15, top-level
- `get_saved_order()` — line 33, top-level
- `ensure_style_branch()` — line 40, top-level
- `aesthetic_style_vector()` — line 77, top-level
- `color_style_vector()` — line 95, top-level
- `linetype_style_vector()` — line 99, top-level
- `shape_style_vector()` — line 103, top-level
- `ensure_series_styles()` — line 107, top-level
- `series_style_vectors()` — line 125, top-level
- `series_combo_levels()` — line 130, top-level
- `effective_position_var()` — line 143, top-level
- `resolve_color_var()` — line 152, top-level
- `resolve_linetype_var()` — line 158, top-level
- `resolve_shape_var()` — line 168, top-level
- `style_levels()` — line 176, top-level
- `ensure_regression_styles()` — line 184, top-level
- `ensure_raw_group_colors()` — line 226, top-level
- `y_break_values()` — line 235, top-level

### `graph_statistics_runtime.R`
- `stats_new_id()` — line 39, nested/local
- `stats_next_default_name()` — line 46, nested/local
- `stats_default_recipe()` — line 57, nested/local
- `stats_scalar_chr()` — line 102, nested/local
- `stats_scalar_num()` — line 109, nested/local
- `normalize_stats_recipe()` — line 116, nested/local
- `normalize_stats_recipes()` — line 170, nested/local
- `refresh_stats_choices()` — line 323, nested/local
- `choose_saved()` — line 399, nested/local
- `fallback_factor()` — line 435, nested/local
- `current_level()` — line 475, nested/local
- `choose_saved()` — line 605, nested/local
- `choose_saved()` — line 666, nested/local
- `stats_restore_token_is_current()` — line 738, nested/local
- `stats_restore_static_controls()` — line 743, nested/local
- `stats_restore_dynamic_controls()` — line 761, nested/local
- `stats_request_restore_barrier()` — line 799, nested/local
- `stats_restore_recipe_phase()` — line 821, nested/local
- `stats_restore_input_snapshot()` — line 858, nested/local
- `stats_settle_restore_barrier()` — line 875, nested/local
- `load_stats_recipe()` — line 942, nested/local
- `stats_capture_common_inputs()` — line 967, nested/local
- `stats_capture_anova_inputs()` — line 995, nested/local
- `stats_capture_ttest_inputs()` — line 1002, nested/local
- `stats_capture_correlation_inputs()` — line 1010, nested/local
- `stats_capture_recipe_from_inputs()` — line 1023, nested/local
- `save_current_stats_recipe()` — line 1039, nested/local
- `get_anovakun_env()` — line 1274, nested/local
- `compute_anovakun_result()` — line 1344, nested/local
- `run_one_anova()` — line 1435, nested/local
- `compute_ttest_result()` — line 1615, nested/local
- `compute_correlation_result()` — line 1689, nested/local
- `format_one_correlation()` — line 1703, nested/local
- `stats_recipes_for_project()` — line 1895, nested/local

### `graph_style_persistence_runtime.R`
- `parse_style_tree()` — line 106, nested/local
- `legacy_mapping_vars()` — line 122, nested/local
- `json_safe_tree()` — line 136, nested/local
- `apply_style_config()` — line 174, nested/local

### `graph_style_state_migration.R`
- `graph_style_migration_scalar_chr()` — line 7, top-level
- `graph_style_migration_prepared_data()` — line 13, top-level
- `graph_style_migration_observed_levels()` — line 36, top-level
- `graph_style_migration_factor_levels()` — line 43, top-level
- `graph_style_migration_normalize_branch()` — line 52, top-level
- `graph_style_migration_mapping_vars()` — line 90, top-level
- `graph_style_migration_normalize_raw_colors()` — line 109, top-level
- `graph_state_materialize_dynamic_style_defaults()` — line 137, top-level

### `graph_style_ui_runtime.R`
- `ensure_regression_styles()` — line 136, nested/local
- `ensure_raw_group_colors()` — line 275, nested/local

### `graph_ui_bindings.R`
- `graph_ui_seeded_args()` — line 6, top-level
- `graph_ui_seeded_bindings()` — line 21, top-level
- `call_seeded()` — line 22, nested/local

### `graph_ui_module.R`
- `graph_svg_viewport_text()` — line 5, top-level
- `graphUI()` — line 17, top-level

### `run.R`
- `ensure_package()` — line 8, top-level

### `server.R`
- `diag_log()` — line 7, nested/local
- `diag_svg_colors()` — line 68, nested/local
- `graph_state_revision_value()` — line 86, nested/local
- `project_graph_label()` — line 174, nested/local
- `send_project_load_overlay()` — line 181, nested/local
- `project_load_action_blocked()` — line 205, nested/local
- `begin_project_load_lock()` — line 215, nested/local
- `update_project_load_lock()` — line 224, nested/local
- `complete_project_load_lock()` — line 251, nested/local
- `fail_project_load_lock()` — line 260, nested/local
- `new_project_uuid()` — line 277, nested/local
- `valid_project_uuid()` — line 291, nested/local
- `release_figure_geometry_bootstrap()` — line 364, nested/local
- `bump_graph_render_state_revision()` — line 430, nested/local
- `figure_referenced_graph_ids()` — line 443, nested/local
- `figure_source_cache_ids()` — line 469, nested/local
- `figure_evict_source_state()` — line 481, nested/local
- `drop_named()` — line 488, nested/local
- `figure_gc_unreferenced_sources()` — line 527, nested/local
- `figure_mark_new_import()` — line 540, nested/local
- `figure_clear_new_import()` — line 547, nested/local
- `publish_client_preview_catalog()` — line 555, nested/local
- `selected_graph_id()` — line 596, nested/local
- `clear_figure_svg_cache()` — line 624, nested/local
- `clear_figure_geometry_cache()` — line 648, nested/local
- `clear_figure_geometry_source_state()` — line 661, nested/local
- `figure_geometry_override_signature()` — line 681, nested/local
- `figure_geometry_cache_key()` — line 701, nested/local
- `num1()` — line 702, nested/local
- `figure_measure_source_geometry_cached()` — line 726, nested/local
- `bump_figure_layout_ui()` — line 787, nested/local
- `bump_figure_panel_display_revision()` — line 792, nested/local
- `sync_figure_inspector()` — line 800, nested/local
- `figure_commit_field_values()` — line 821, nested/local
- `bump_figure_commit_edit_revisions()` — line 831, nested/local
- `bump_figure_snapshot_revision()` — line 847, nested/local
- `refresh_figure_geometry_source_revision()` — line 858, nested/local
- `close_figure_load_progress()` — line 886, nested/local
- `safe_name()` — line 897, nested/local
- `next_id()` — line 903, nested/local
- `graph_single_mod()` — line 909, nested/local
- `graph_single_owner()` — line 911, nested/local
- `graph_single_ready()` — line 915, nested/local
- `cache_has()` — line 924, nested/local
- `cache_get()` — line 928, nested/local
- `cache_set()` — line 934, nested/local
- `registry_merge_nonnull()` — line 954, nested/local
- `registry_commit()` — line 980, nested/local
- `cache_remove()` — line 1011, nested/local
- `graph_preview_record_from_plot()` — line 1025, nested/local
- `figure_editor_module_id()` — line 1091, nested/local
- `figure_editor_wrapper_id()` — line 1094, nested/local
- `figure_editor_module()` — line 1098, nested/local
- `store_figure_edit_state()` — line 1106, nested/local
- `figure_editor_snapshot_available()` — line 1116, nested/local
- `capture_ready_figure_editor_payload()` — line 1124, nested/local
- `preserve_figure_inset_snapshot_before_main_replace()` — line 1156, nested/local
- `snapshot_ready_figure_editor()` — line 1172, nested/local
- `invalidate_figure_main_snapshot_for_import()` — line 1239, nested/local
- `seed_figure_editor_from_source()` — line 1253, nested/local
- `reload_visible_figure_editor_after_snapshot()` — line 1262, nested/local
- `reload_selected_figure_editor_after_bulk()` — line 1276, nested/local
- `show_figure_editor_wrapper()` — line 1280, nested/local
- `reset_figure_editors()` — line 1287, nested/local
- `request_figure_editor_mount_ack()` — line 1311, nested/local
- `ensure_figure_editor()` — line 1347, nested/local
- `next_graph_default_name()` — line 1549, nested/local
- `show_new_graph_modal()` — line 1561, nested/local
- `create_new_graph_from_modal()` — line 1593, nested/local
- `show_rename_graph_modal()` — line 1666, nested/local
- `apply_graph_rename()` — line 1705, nested/local
- `figure_graph_reference_summary()` — line 1738, nested/local

### `server_export_prepare_runtime.R`
- `export_ids_now()` — line 7, nested/local
- `graph_export_state_ready()` — line 24, nested/local

### `server_figure_controls_runtime.R`
- `auto_panel_size_for()` — line 126, nested/local
- `option_tag()` — line 137, nested/local
- `used_elsewhere_for()` — line 145, nested/local
- `selected_row_detail()` — line 153, nested/local
- `label_for()` — line 327, nested/local
- `figure_source_map()` — line 628, nested/local
- `send_figure_browser_selection()` — line 635, nested/local
- `verify_figure_reorder_after_flush()` — line 640, nested/local
- `commit_figure_reorder()` — line 661, nested/local
- `do_figure_adjacent_shift()` — line 710, nested/local
- `figure_source_load_status()` — line 914, nested/local
- `figure_explicit_load_status()` — line 921, nested/local
- `build_figure_override_ui()` — line 997, nested/local
- `send_figure_label_overlay_update()` — line 1035, nested/local
- `capture_current_figure_override()` — line 1055, nested/local
- `copy_figure_style_fields()` — line 1477, nested/local
- `refresh_export_choices()` — line 1933, nested/local

### `server_figure_inset_persistence_runtime.R`
- `collect_figure_inset_preview_records()` — line 2, top-level
- `write_figure_inset_preview_entries()` — line 15, top-level

### `server_figure_legend_reactivity_runtime.R`
- `reset_figure_legend_materializer()` — line 6, top-level
- `figure_legend_materializer_signature()` — line 11, top-level
- `figure_legend_materializer_legacy_seed()` — line 22, top-level
- `figure_legend_materializer_state()` — line 44, top-level
- `figure_legend_materializer_pending()` — line 51, top-level
- `figure_legend_materializer_publish_latest()` — line 58, top-level
- `figure_legend_materializer_on_override_change()` — line 84, top-level

### `server_figure_lifecycle_runtime.R`
- `figure_workspace_is_active()` — line 6, nested/local
- `figure_main_panel_source_ids()` — line 10, nested/local
- `figure_main_snapshot_exists()` — line 23, nested/local
- `figure_bootstrap_missing_main_snapshots()` — line 33, nested/local
- `enter_figure_workspace()` — line 67, nested/local
- `leave_figure_workspace()` — line 81, nested/local
- `sync_figure_workspace_lifecycle()` — line 88, nested/local

### `server_figure_source_snapshot_runtime.R`
- `reset_figure_source_snapshot_service()` — line 11, top-level
- `figure_source_snapshot_key()` — line 25, top-level
- `figure_source_snapshot_completed_revision()` — line 35, top-level
- `figure_source_snapshot_success()` — line 40, top-level
- `figure_source_snapshot_pending()` — line 45, top-level
- `figure_source_snapshot_busy()` — line 58, top-level
- `figure_source_snapshot_target_pending()` — line 66, top-level
- `cancel_figure_source_snapshot_jobs()` — line 89, top-level
- `figure_source_snapshot_next_revision()` — line 121, top-level
- `request_figure_source_snapshot()` — line 127, top-level
- `request_figure_inset_snapshot()` — line 179, top-level
- `figure_source_snapshot_store_inset()` — line 189, top-level
- `figure_source_snapshot_finish_job()` — line 221, top-level
- `figure_source_snapshot_run_job()` — line 235, top-level
- `figure_source_snapshot_start_next()` — line 251, top-level

### `server_figure_workspace_runtime.R`
- `figure_collect_live_layout()` — line 6, nested/local
- `figure_visible_requested_overrides()` — line 69, nested/local
- `bbox_sig()` — line 600, nested/local
- `figure_live_base_asset()` — line 896, nested/local
- `write_figure_export()` — line 1479, nested/local

### `server_graph_editor_runtime.R`
- `graph_single_mark_editor_visit()` — line 4, nested/local
- `graph_single_claim_revision()` — line 16, nested/local
- `graph_single_revision_is_current()` — line 34, nested/local
- `graph_single_mark_stale()` — line 42, nested/local
- `graph_ui_panels_for_id()` — line 58, nested/local
- `graph_store_ui_panels()` — line 67, nested/local
- `graph_single_publish_state()` — line 92, nested/local
- `finalize_graph_single_default_state()` — line 116, nested/local
- `graph_single_accept_loaded_state()` — line 145, nested/local
- `graph_single_abort_activation()` — line 171, nested/local
- `capture_graph_single_default_state()` — line 204, nested/local
- `graph_single_default_state_snapshot()` — line 229, nested/local
- `seed_new_graph_default_state()` — line 245, nested/local
- `ensure_graph_single_editor_module()` — line 267, nested/local
- `graph_single_commit()` — line 376, nested/local
- `graph_single_begin_live_target()` — line 387, nested/local
- `show_graph_single_editor()` — line 403, nested/local
- `graph_single_finish_live_transaction()` — line 415, nested/local
- `graph_single_release_live_render()` — line 447, nested/local
- `graph_single_load()` — line 508, nested/local

### `server_graph_export_runtime.R`
- `graph_export_sync_visible_owner()` — line 4, nested/local
- `graph_export_payload()` — line 12, nested/local
- `write_one_graph()` — line 22, nested/local
- `write_graph_export()` — line 74, nested/local
- `export_filename_now()` — line 124, nested/local

### `server_graph_selection_runtime.R`
- `graph_selection_valid_id()` — line 5, nested/local
- `select_graph_preview()` — line 10, nested/local
- `request_graph_editor()` — line 25, nested/local
- `resume_graph_workspace()` — line 97, nested/local

### `server_graph_settings_batch_runtime.R`
- `graph_settings_manager_set_path()` — line 6, nested/local
- `set_rec()` — line 11, nested/local
- `graph_settings_manager_commit_exact()` — line 30, nested/local
- `graph_settings_manager_finalize_graph_changes()` — line 53, nested/local

### `server_graph_settings_manager_runtime.R`
- `graph_settings_manager_get_result()` — line 7, nested/local
- `graph_settings_manager_get()` — line 20, nested/local
- `graph_settings_manager_scalar()` — line 25, nested/local
- `graph_settings_manager_rows()` — line 39, nested/local
- `editor_text()` — line 40, nested/local
- `editor_number()` — line 41, nested/local
- `editor_axis_number()` — line 48, nested/local
- `editor_boolean()` — line 49, nested/local
- `editor_select()` — line 50, nested/local
- `graph_settings_manager_row_for_path()` — line 100, nested/local
- `graph_settings_manager_jump_js()` — line 107, nested/local
- `graph_settings_manager_display_value()` — line 116, nested/local
- `graph_settings_manager_value_key()` — line 125, nested/local
- `graph_settings_manager_raw_value()` — line 136, nested/local
- `graph_settings_manager_shared_summary()` — line 149, nested/local
- `graph_settings_manager_shared_marker()` — line 157, nested/local
- `graph_settings_manager_cell()` — line 238, nested/local

### `server_graph_settings_value_runtime.R`
- `graph_settings_manager_feedback()` — line 5, nested/local
- `graph_settings_manager_value_diag()` — line 19, nested/local
- `graph_settings_manager_normalize_input_value()` — line 31, nested/local
- `fail()` — line 34, nested/local
- `pass()` — line 35, nested/local
- `graph_settings_manager_apply_graph_value()` — line 84, nested/local
- `graph_settings_manager_figure_base_state()` — line 101, nested/local
- `graph_settings_manager_reload_visible_figure_editor()` — line 113, nested/local
- `graph_settings_manager_apply_figure_value()` — line 134, nested/local
- `graph_settings_manager_refresh_figure_from_graph()` — line 181, nested/local

### `server_graph_state_replay_runtime.R`
- `graph_capture_editor_ui_snapshot()` — line 7, nested/local
- `graph_replay_selected()` — line 18, nested/local
- `graph_replay_mapping_plan()` — line 24, nested/local
- `choose()` — line 53, nested/local
- `graph_replay_apply_mapping_values()` — line 93, nested/local
- `graph_replay_apply_scalar_controls()` — line 154, nested/local
- `graph_replay_apply_statistics()` — line 202, nested/local
- `graph_replay_finish()` — line 215, nested/local
- `graph_apply_state_replay()` — line 250, nested/local

### `server_graph_workspace_runtime.R`
- `create_graph()` — line 38, nested/local

### `server_project_io_runtime.R`
- `flush_active_graph_to_registry()` — line 12, nested/local
- `graph_state_for_save()` — line 49, nested/local
- `figure_state_for_save()` — line 74, nested/local
- `reset_figure_workspace()` — line 125, nested/local
- `figure_layout_diag()` — line 177, nested/local
- `restore_figure_project_state()` — line 185, nested/local
- `build_project()` — line 516, nested/local
- `project_filename()` — line 569, nested/local
- `project_bundle_filename()` — line 587, nested/local
- `collect_figure_snapshot_preview_records()` — line 593, nested/local
- `write_project_package()` — line 725, nested/local
- `read_project_file()` — line 1080, nested/local
- `read_preview_entries()` — line 1180, nested/local
- `project_stage_state_target()` — line 1315, nested/local
- `map_preview_records()` — line 1544, nested/local

### `server_shared_style_runtime.R`
- `shared_style_prune_binding_to_library()` — line 5, nested/local
- `shared_style_prune_graph_state()` — line 31, nested/local
- `shared_style_request_visible_graph_replay()` — line 39, nested/local
- `shared_style_apply_to_registry()` — line 68, nested/local
- `shared_style_apply_figure_states()` — line 101, nested/local
- `shared_style_commit_library()` — line 209, nested/local

### `shared_style_state.R`
- `shared_style_scalar_chr()` — line 6, top-level
- `shared_style_scalar_num()` — line 13, top-level
- `shared_style_scalar_lgl()` — line 18, top-level
- `shared_style_safe_id()` — line 25, top-level
- `shared_style_default_item()` — line 32, top-level
- `shared_style_normalize_item()` — line 55, top-level
- `shared_style_default_library()` — line 82, top-level
- `shared_style_normalize_library()` — line 86, top-level
- `shared_style_library_items()` — line 103, top-level
- `shared_style_default_binding()` — line 111, top-level
- `shared_style_normalize_binding()` — line 122, top-level
- `shared_style_binding_has_links()` — line 161, top-level
- `shared_style_normalize_graph_state()` — line 167, top-level
- `shared_style_set_nested()` — line 176, top-level
- `shared_style_apply_to_graph_state()` — line 185, top-level
- `shared_style_resolve_writeback()` — line 240, top-level
- `shared_style_update_library_from_graph_state()` — line 252, top-level
- `add_candidate()` — line 261, nested/local
- `shared_style_item_label()` — line 342, top-level

### `ui_shell.R`
- `app_head_ui()` — line 5, top-level
- `project_load_overlay_ui()` — line 13, top-level
- `project_manager_ui()` — line 45, top-level
- `graph_workspace_ui()` — line 217, top-level
- `appUI()` — line 296, top-level

