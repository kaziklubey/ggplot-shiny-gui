# Function catalog

This document is the maintainer-facing map of the function-first source layout.

## Canonical functions to extend first

### `graph_render_state.R`
- `graph_render_state_apply_semantics()`
- `graph_render_state()`
- `graph_render_state_changed()`

### `graph_state_boundary_runtime.R`
- `graph_editor_arbitration_state_snapshot()`
- `graph_seed_render_target()`
- `graph_release_render_revision()`
- `graph_release_attached_render_target()`

### `graph_data_defaults.R`
- `graph_default_reshape_columns()`
- `graph_default_mapping_for_data()`

### `graph_data_transform.R`
- `graph_normalize_data_transform_recipe()`
- `graph_plot_data_transform_recipe()`
- `graph_validate_wide_to_long_recipe()`
- `graph_apply_wide_to_long()`
- `graph_apply_data_transform()`

### `graph_statistics_runtime.R`
- `normalize_stats_recipe()`
- `stats_request_restore_barrier()`
- `stats_capture_recipe_from_inputs()`
- `stats_recipes_for_project()`

### `shared_style_state.R`
- `shared_style_normalize_library()`
- `shared_style_normalize_binding()`
- `shared_style_normalize_graph_state()`
- `shared_style_apply_to_graph_state()`
- `shared_style_update_library_from_graph_state()`
- `shared_style_resolve_writeback()`

### `figure_sync_contract.R`
- `figure_state_ownership_contract()`
- `figure_source_apply_payload()`
- `figure_source_apply_diff()`

### `figure_ui_module.R`
- `figureWorkspaceUI()`
- `figureLayoutWorkflowUI()`
- `figureCanvasControlsUI()`
- `figureLayoutPrimaryControlsUI()`
- `figureSharedStylePanelUI()`
- `figureSelectedPanelDrawerUI()`
- `figureExportWorkflowUI()`

### `figure_interaction.R`
- `figure_reorder_content_state()`
- `figure_reset_content_order_state()`
- `figure_validate_reorder_state()`

### `server_graph_editor_runtime.R`
- `graph_single_load()`
- `graph_single_request_reconcile_barrier()`

## Responsibility map

- **GraphState → RenderState semantics:** `graph_render_state.R`
- **Persistent Editor arbitration / single render release:** `graph_state_boundary_runtime.R`
- **Shared Data/Mapping UI defaults:** `graph_data_defaults.R`
- **Original Graph dataset parser / Plot transform state:** `graph_data_runtime.R`
- **Reusable pure data transforms:** `graph_data_transform.R`
- **Statistics Analysis recipes / independent preparation / tests:** `graph_statistics_runtime.R`
- **GraphState restore:** `graph_restore_runtime.R`
- **Data View and Plot outputs:** `graph_output_runtime.R`
- **Figure/source ownership:** `figure_sync_contract.R`
- **Figure workflow UI composition:** `figure_ui_module.R`
- **Shared semantic style state:** `shared_style_state.R`
- **Shared semantic style server transaction:** `server_shared_style_runtime.R`
- **Persistent Editor transaction:** `server_graph_editor_runtime.R`
- **Editor-first Graph selection / Preview client boundary:** `www/app_client.js`

Statistics Analysis preparation and Plot preparation may call the same pure transform engine, but must not share mutable recipe state. Registry/GraphState remains canonical; DOM inputs and plots are derived views.

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
- `bbox_for_idx()` — line 212, nested/local
- `guide_is_visible()` — line 240, nested/local
- `legend_visual_bbox_for_idx()` — line 260, nested/local
- `clamp_bbox()` — line 326, nested/local
- `measure_plot_size_px()` — line 358, top-level

### `app_state_diff.R`
- `app_state_diff_paths()` — line 7, top-level
- `walk()` — line 11, nested/local
- `app_state_diff_summary()` — line 44, top-level

### `figure_asset.R`
- `figure_make_internal_asset()` — line 4, top-level
- `figure_asset_has_svg()` — line 23, top-level
- `figure_external_asset_id()` — line 27, top-level
- `figure_file_to_data_uri()` — line 41, top-level
- `figure_import_external_asset()` — line 56, top-level
- `figure_asset_source_choices()` — line 84, top-level
- `figure_decorate_external_asset()` — line 95, top-level
- `figure_external_legend_asset()` — line 111, top-level
- `figure_asset_display_name()` — line 118, top-level

### `figure_export.R`
- `figure_draw_plot_grob_cropped()` — line 4, top-level
- `figure_extract_legend_grob()` — line 43, top-level
- `figure_svg_straight_rgba()` — line 53, top-level
- `figure_svg_snapshot_diagnostics()` — line 94, top-level
- `figure_svg_snapshot_grob()` — line 148, top-level
- `figure_draw_persisted_svg_panel()` — line 156, top-level
- `figure_export_plot_spec()` — line 215, top-level
- `figure_draw_detached_legend_plot()` — line 287, top-level
- `figure_draw_to_device()` — line 339, top-level
- `figure_svg_escape_text()` — line 562, top-level
- `figure_svg_fragment_parts()` — line 571, top-level
- `attr_value()` — line 577, nested/local
- `figure_svg_place_fragment()` — line 630, top-level
- `figure_write_svg_vector()` — line 648, top-level
- `next_prefix()` — line 658, nested/local
- `make_clip()` — line 659, nested/local

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
- `figure_axis_gutter_metrics()` — line 102, top-level
- `bb()` — line 103, nested/local
- `figure_legend_slot_metrics()` — line 136, top-level
- `bb()` — line 137, nested/local
- `figure_crop_fractions()` — line 169, top-level
- `figure_attach_crop_metadata()` — line 184, top-level
- `figure_apply_crop_footprint()` — line 204, top-level
- `figure_uncropped_rect()` — line 219, top-level
- `figure_crop_render_geometry()` — line 234, top-level
- `figure_natural_graph_size()` — line 263, top-level
- `figure_auto_layout_geometry()` — line 334, top-level
- `figure_expand_auto_canvas_for_free_legends()` — line 584, top-level
- `figure_override_for()` — line 637, top-level
- `scalar_chr()` — line 640, nested/local
- `scalar_num()` — line 644, nested/local
- `figure_apply_layer_style_override()` — line 786, top-level
- `figure_apply_y_range_override()` — line 826, top-level
- `figure_apply_plot_override()` — line 851, top-level
- `figure_label_band()` — line 904, top-level
- `figure_plot_for_scale()` — line 921, top-level
- `figure_graph_target_box()` — line 986, top-level
- `figure_plot_spec_for_rect()` — line 1033, top-level
- `figure_plot_offsets()` — line 1061, top-level
- `figure_label_position()` — line 1108, top-level
- `figure_plot_panel_zone()` — line 1135, top-level
- `figure_legend_handle_position()` — line 1154, top-level
- `figure_seed_free_geometry()` — line 1166, top-level
- `figure_free_layout_geometry()` — line 1193, top-level
- `figure_crop_css()` — line 1266, top-level
- `figure_fixed_basis_layout_geometry()` — line 1288, top-level
- `align_offset()` — line 1314, nested/local
- `num()` — line 1321, nested/local
- `figure_rebind_frozen_geometry()` — line 1484, top-level

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
- `figure_scale_geometry_meta()` — line 263, top-level
- `val()` — line 267, nested/local
- `scale_bbox()` — line 271, nested/local
- `figure_plot_spec_for_rect_whole_scale()` — line 291, top-level
- `figure_persisted_spec_for_rect()` — line 331, top-level
- `figure_external_asset_node()` — line 389, top-level
- `figure_valid_bbox()` — line 402, top-level
- `figure_detached_legend_side()` — line 409, top-level
- `figure_detached_svg_parts()` — line 414, top-level
- `svg_node()` — line 428, nested/local
- `figure_build_inset_layer_ui()` — line 440, top-level
- `figure_build_detached_legend_layer_ui()` — line 481, top-level
- `figure_build_label_layer_ui()` — line 541, top-level
- `figure_build_cell_ui()` — line 559, top-level

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
- `figureLayoutWorkflowUI()` — line 99, top-level
- `figureSharedStylePanelUI()` — line 125, top-level
- `figureSelectedPanelDrawerUI()` — line 173, top-level
- `figureExportWorkflowUI()` — line 261, top-level
- `figurePreviewWorkflowUI()` — line 277, top-level
- `figureWorkspaceUI()` — line 303, top-level
- `figureSelectedPanelHeaderUI()` — line 319, top-level
- `figureOverrideDetailUI()` — line 332, top-level
- `fold_class()` — line 338, nested/local

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
- `graph_sample_graph_state()` — line 144, top-level

### `graph_data_runtime.R`
- `restore_timing_now_ms()` — line 40, nested/local
- `restore_timing_reset()` — line 44, nested/local
- `restore_timing_mark()` — line 53, nested/local
- `reset_reshape_binding_wait()` — line 69, nested/local
- `request_reshape_parent_binding_ack()` — line 84, nested/local
- `request_reshape_binding_ack()` — line 124, nested/local
- `set_reshape_warning()` — line 162, nested/local
- `keep()` — line 344, nested/local
- `keep_choice()` — line 431, nested/local
- `keep_multi_aes_choice()` — line 468, nested/local
- `keep_choice_local()` — line 532, nested/local
- `choose_column()` — line 622, nested/local
- `release_seed()` — line 687, nested/local
- `effective_position_var()` — line 740, nested/local
- `resolve_color_var()` — line 749, nested/local
- `resolve_linetype_var()` — line 755, nested/local
- `resolve_shape_var()` — line 765, nested/local

### `graph_data_transform.R`
- `graph_normalize_data_transform_recipe()` — line 8, top-level
- `graph_plot_data_transform_recipe()` — line 45, top-level
- `graph_validate_wide_to_long_recipe()` — line 57, top-level
- `graph_apply_wide_to_long()` — line 84, top-level
- `graph_apply_data_transform()` — line 125, top-level

### `graph_helpers_runtime.R`
- `style_input_id()` — line 51, nested/local
- `legend_title_value()` — line 87, nested/local
- `level_label_values()` — line 100, nested/local
- `get_saved_order()` — line 118, nested/local
- `set_saved_order()` — line 125, nested/local
- `ensure_style_branch()` — line 131, nested/local
- `aesthetic_style_vector()` — line 168, nested/local
- `color_style_vector()` — line 186, nested/local
- `linetype_style_vector()` — line 189, nested/local
- `shape_style_vector()` — line 192, nested/local
- `migrate_legacy_group_styles()` — line 196, nested/local
- `scalar_chr()` — line 198, nested/local
- `scalar_num()` — line 202, nested/local
- `ensure_series_styles()` — line 240, nested/local
- `series_style_vectors()` — line 258, nested/local

### `graph_module.R`
- `graphServer()` — line 6, top-level
- `init_timing_emit()` — line 9, nested/local
- `diag()` — line 29, nested/local
- `statistics_plot_preview()` — line 58, nested/local
- `textInput()` — line 87, nested/local
- `selectInput()` — line 88, nested/local
- `checkboxInput()` — line 89, nested/local
- `checkboxGroupInput()` — line 90, nested/local
- `sliderInput()` — line 91, nested/local
- `numericInput()` — line 92, nested/local
- `actionButton()` — line 93, nested/local
- `downloadButton()` — line 94, nested/local
- `fileInput()` — line 95, nested/local
- `uiOutput()` — line 96, nested/local
- `plotOutput()` — line 97, nested/local
- `tableOutput()` — line 98, nested/local
- `verbatimTextOutput()` — line 99, nested/local
- `colourInput()` — line 100, nested/local

### `graph_output_runtime.R`
- `send_plot_dimensions()` — line 191, nested/local

### `graph_plot_contract.R`
- `graph_plot_type_specs()` — line 8, top-level
- `graph_plot_type_ids()` — line 33, top-level
- `graph_plot_type_choices()` — line 37, top-level
- `graph_plot_type_normalize()` — line 44, top-level
- `graph_plot_type_spec()` — line 54, top-level
- `graph_plot_supports_mapping()` — line 58, top-level
- `graph_plot_restore_input_ids()` — line 62, top-level

### `graph_plot_runtime.R`
- `y_break_values()` — line 6, nested/local
- `aes_ref()` — line 95, nested/local
- `dynamic_aes()` — line 99, nested/local
- `add_interaction_key()` — line 118, nested/local
- `make_slot_layout()` — line 134, nested/local
- `apply_slot_layout()` — line 169, nested/local
- `decorate_style()` — line 215, nested/local
- `aes_levels()` — line 257, nested/local
- `combo_display_labels()` — line 302, nested/local
- `add_id_line_layers()` — line 431, nested/local
- `add_one()` — line 437, nested/local
- `add_raw_point_layers()` — line 487, nested/local
- `add_one()` — line 490, nested/local
- `add_summary_line_point()` — line 732, nested/local
- `add_summary_errorbar()` — line 757, nested/local
- `add_individual_layers()` — line 789, nested/local
- `legend_title_lab_value()` — line 1414, nested/local
- `set_legend_lab()` — line 1418, nested/local

### `graph_prepared_data_runtime.R`
- `external_error_bounds()` — line 324, nested/local
- `apply_font_family_state_to_editor()` — line 425, nested/local
- `add_stable_spread()` — line 540, nested/local

### `graph_render_error_runtime.R`
- `graph_plot_error_placeholder()` — line 5, top-level
- `graph_render_plot_safely()` — line 25, top-level

### `graph_render_state.R`
- `graph_render_state_apply_semantics()` — line 9, top-level
- `graph_render_state()` — line 54, top-level
- `graph_render_diff_paths()` — line 119, top-level
- `graph_render_state_changed()` — line 123, top-level

### `graph_restore_runtime.R`
- `parse_style_tree()` — line 96, nested/local
- `legacy_mapping_vars()` — line 112, nested/local
- `json_safe_tree()` — line 126, nested/local
- `apply_style_config()` — line 164, nested/local
- `abort_project_restore()` — line 441, nested/local
- `cancel_initial_restore()` — line 470, nested/local
- `restore_wait()` — line 507, nested/local
- `restore_diag_checkpoint()` — line 528, nested/local
- `restore_diag_value()` — line 534, nested/local
- `restore_binding_ack_diag()` — line 542, nested/local
- `restore_ack_field_value()` — line 571, nested/local
- `restore_ack_scalar_matches()` — line 582, nested/local
- `restore_ack_set_matches()` — line 593, nested/local
- `restore_current_reshape_parent_matches()` — line 601, nested/local
- `restore_diag_condition()` — line 612, nested/local
- `restore_diag_snapshot()` — line 644, nested/local
- `reset_mapping_binding_wait()` — line 701, nested/local
- `request_mapping_binding_ack()` — line 710, nested/local
- `json_chr()` — line 796, nested/local
- `json_vec()` — line 803, nested/local
- `normalize_order_tree()` — line 808, nested/local
- `seed_internal_state()` — line 828, nested/local
- `mapping_project_status()` — line 914, nested/local
- `input_value()` — line 931, nested/local
- `raw_label()` — line 935, nested/local
- `resync_mapping_fields()` — line 1016, nested/local

### `graph_shared_style_runtime.R`
- `shared_style_choices()` — line 6, nested/local
- `shared_style_apply_local()` — line 167, nested/local

### `graph_state.R`
- `graph_state_scalar()` — line 6, top-level
- `graph_ui_seed_from_state()` — line 13, top-level
- `put()` — line 17, nested/local

### `graph_state_boundary_runtime.R`
- `is_shiny_control_condition()` — line 9, top-level
- `graph_live_project_state_snapshot()` — line 13, top-level
- `graph_editor_arbitration_state_snapshot()` — line 40, top-level
- `graph_seed_render_target()` — line 59, top-level
- `graph_adopt_equivalent_canonical()` — line 67, top-level
- `graph_accept_attached_canonical()` — line 91, top-level
- `graph_release_render_revision()` — line 104, top-level
- `graph_release_attached_render_target()` — line 154, top-level
- `install_graph_render_revision_runtime()` — line 160, top-level

### `graph_state_runtime.R`
- `direct_sync_path_changed()` — line 115, nested/local
- `direct_sync_any_changed()` — line 125, nested/local
- `reassert_dynamic_style_state()` — line 134, nested/local
- `sync_editor_from_state()` — line 188, nested/local
- `start_state_restore()` — line 411, nested/local
- `finish_restore()` — line 1499, nested/local
- `accept_preseeded_controls_state()` — line 1586, nested/local
- `ack_state()` — line 1599, nested/local
- `scalar_state()` — line 1611, nested/local
- `prepare_restore_from_canonical()` — line 1654, nested/local
- `activate_initial_state()` — line 1687, nested/local
- `prepare_remount_state()` — line 1754, nested/local
- `dbg_tree()` — line 1771, nested/local
- `char1()` — line 1848, nested/local
- `same()` — line 1853, nested/local
- `cancel_remount_ui()` — line 1902, nested/local
- `remount_binding_fields()` — line 1931, nested/local
- `field()` — line 1937, nested/local
- `remount_ui()` — line 1976, nested/local

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
- `get_anovakun_env()` — line 1272, nested/local
- `compute_anovakun_result()` — line 1342, nested/local
- `run_one_anova()` — line 1433, nested/local
- `compute_ttest_result()` — line 1613, nested/local
- `compute_correlation_result()` — line 1687, nested/local
- `format_one_correlation()` — line 1701, nested/local
- `stats_recipes_for_project()` — line 1894, nested/local

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
- `diag_svg_colors()` — line 69, nested/local
- `ui_mounted()` — line 88, nested/local
- `mounted_ids()` — line 89, nested/local
- `mark_ui_mounted()` — line 90, nested/local
- `graph_state_revision_value()` — line 105, nested/local
- `source_module_claim_revision()` — line 109, nested/local
- `source_module_revision_is_current()` — line 127, nested/local
- `invalidate_graph_source_module()` — line 133, nested/local
- `project_graph_label()` — line 255, nested/local
- `send_project_load_overlay()` — line 262, nested/local
- `project_load_action_blocked()` — line 286, nested/local
- `begin_project_load_lock()` — line 296, nested/local
- `update_project_load_lock()` — line 305, nested/local
- `complete_project_load_lock()` — line 332, nested/local
- `fail_project_load_lock()` — line 341, nested/local
- `new_project_uuid()` — line 358, nested/local
- `valid_project_uuid()` — line 372, nested/local
- `release_figure_geometry_bootstrap()` — line 456, nested/local
- `bump_graph_render_state_revision()` — line 534, nested/local
- `mark_graph_preview_dirty()` — line 542, nested/local
- `invalidate_graph_preview_artifacts()` — line 550, nested/local
- `clear_graph_preview_dirty()` — line 576, nested/local
- `graph_preview_is_dirty()` — line 583, nested/local
- `graph_preview_record()` — line 587, nested/local
- `figure_referenced_graph_ids()` — line 600, nested/local
- `figure_source_cache_ids()` — line 626, nested/local
- `figure_evict_source_state()` — line 638, nested/local
- `drop_named()` — line 642, nested/local
- `figure_gc_unreferenced_sources()` — line 681, nested/local
- `figure_mark_new_import()` — line 694, nested/local
- `figure_clear_new_import()` — line 701, nested/local
- `publish_client_preview_catalog()` — line 710, nested/local
- `selected_graph_id()` — line 755, nested/local
- `graph_global_cached_html()` — line 773, nested/local
- `request_global_graph_preview()` — line 815, nested/local
- `fmt()` — line 990, nested/local
- `clear_figure_svg_cache()` — line 1044, nested/local
- `clear_figure_geometry_cache()` — line 1068, nested/local
- `clear_figure_geometry_source_state()` — line 1081, nested/local
- `figure_geometry_override_signature()` — line 1101, nested/local
- `figure_geometry_cache_key()` — line 1121, nested/local
- `num1()` — line 1122, nested/local
- `figure_measure_source_geometry_cached()` — line 1146, nested/local
- `bump_figure_layout_ui()` — line 1207, nested/local
- `bump_figure_panel_display_revision()` — line 1212, nested/local
- `sync_figure_inspector()` — line 1220, nested/local
- `figure_commit_field_values()` — line 1241, nested/local
- `bump_figure_commit_edit_revisions()` — line 1251, nested/local
- `bump_figure_snapshot_revision()` — line 1267, nested/local
- `refresh_figure_geometry_source_revision()` — line 1278, nested/local
- `close_figure_load_progress()` — line 1306, nested/local
- `safe_name()` — line 1317, nested/local
- `next_id()` — line 1323, nested/local
- `module_exists()` — line 1329, nested/local
- `graph_single_mod()` — line 1333, nested/local
- `graph_single_owner()` — line 1335, nested/local
- `graph_single_ready()` — line 1339, nested/local
- `source_graph_module()` — line 1348, nested/local
- `source_graph_ready()` — line 1368, nested/local
- `cache_has()` — line 1373, nested/local
- `cache_get()` — line 1377, nested/local
- `cache_set()` — line 1383, nested/local
- `registry_merge_nonnull()` — line 1407, nested/local
- `registry_commit()` — line 1433, nested/local
- `cache_remove()` — line 1465, nested/local
- `ensure_graph_ui()` — line 1480, nested/local
- `evict_graph_source_ui()` — line 1568, nested/local
- `evict_other_graph_source_uis()` — line 1591, nested/local
- `graph_preview_record_from_plot()` — line 1604, nested/local
- `publish_graph_preview_record()` — line 1654, nested/local
- `refresh_graph_preview_from_figure_snapshot()` — line 1670, nested/local
- `refresh_graph_preview_from_live()` — line 1695, nested/local
- `register_graph_preview_observer()` — line 1897, nested/local
- `figure_editor_module_id()` — line 1942, nested/local
- `figure_editor_wrapper_id()` — line 1945, nested/local
- `figure_editor_module()` — line 1949, nested/local
- `store_figure_edit_state()` — line 1957, nested/local
- `figure_editor_snapshot_available()` — line 1967, nested/local
- `snapshot_ready_figure_editor()` — line 1975, nested/local
- `seed_figure_editor_from_source()` — line 2058, nested/local
- `reload_selected_figure_editor_after_bulk()` — line 2072, nested/local
- `show_figure_editor_wrapper()` — line 2083, nested/local
- `reset_figure_editors()` — line 2090, nested/local
- `request_figure_editor_mount_ack()` — line 2113, nested/local
- `ensure_figure_editor()` — line 2149, nested/local
- `next_graph_default_name()` — line 2387, nested/local
- `show_new_graph_modal()` — line 2399, nested/local
- `create_new_graph_from_modal()` — line 2431, nested/local
- `show_rename_graph_modal()` — line 2536, nested/local
- `apply_graph_rename()` — line 2575, nested/local
- `figure_graph_reference_summary()` — line 2608, nested/local

### `server_export_prepare_runtime.R`
- `export_ids_now()` — line 6, nested/local
- `schedule_export_prep()` — line 26, nested/local

### `server_figure_controls_runtime.R`
- `auto_panel_size_for()` — line 126, nested/local
- `option_tag()` — line 137, nested/local
- `used_elsewhere_for()` — line 145, nested/local
- `selected_row_detail()` — line 153, nested/local
- `label_for()` — line 326, nested/local
- `figure_source_map()` — line 643, nested/local
- `send_figure_browser_selection()` — line 650, nested/local
- `verify_figure_reorder_after_flush()` — line 655, nested/local
- `commit_figure_reorder()` — line 676, nested/local
- `do_figure_adjacent_shift()` — line 725, nested/local
- `figure_restore_failure()` — line 927, nested/local
- `figure_source_load_status()` — line 931, nested/local
- `figure_explicit_load_status()` — line 945, nested/local
- `build_figure_override_ui()` — line 1019, nested/local
- `send_figure_label_overlay_update()` — line 1057, nested/local
- `capture_current_figure_override()` — line 1077, nested/local
- `copy_figure_style_fields()` — line 1460, nested/local
- `refresh_export_choices()` — line 1925, nested/local

### `server_figure_legend_reactivity_runtime.R`
- `figure_legend_materializer_module_id()` — line 30, top-level
- `figure_legend_materializer_wrapper_id()` — line 34, top-level
- `figure_legend_materializer_module()` — line 38, top-level
- `figure_legend_materializer_signature()` — line 43, top-level
- `figure_legend_materializer_legacy_seed()` — line 54, top-level
- `figure_legend_materializer_state()` — line 81, top-level
- `figure_legend_materializer_drop_queue_id()` — line 90, top-level
- `figure_legend_materializer_pending()` — line 97, top-level
- `figure_legend_materializer_publish_latest()` — line 105, top-level
- `figure_legend_materializer_rollback_draft()` — line 131, top-level
- `figure_legend_materializer_on_override_change()` — line 147, top-level
- `figure_legend_materializer_request_mount_ack()` — line 205, top-level
- `figure_legend_materializer_begin()` — line 245, top-level
- `figure_legend_materializer_capture()` — line 382, top-level

### `server_figure_lifecycle_runtime.R`
- `figure_workspace_is_active()` — line 5, nested/local
- `enter_figure_workspace()` — line 9, nested/local
- `leave_figure_workspace()` — line 22, nested/local
- `sync_figure_workspace_lifecycle()` — line 29, nested/local

### `server_figure_workspace_runtime.R`
- `figure_collect_live_layout()` — line 6, nested/local
- `figure_visible_requested_overrides()` — line 65, nested/local
- `snapshot_ready_graph_for_figure()` — line 252, nested/local
- `capture_inset_snapshot_from_ready_graph()` — line 342, nested/local
- `bbox_sig()` — line 851, nested/local
- `figure_live_base_asset()` — line 1137, nested/local
- `write_figure_export()` — line 1718, nested/local

### `server_graph_editor_runtime.R`
- `instantiate_graph()` — line 1, nested/local
- `graph_is_ready()` — line 50, nested/local
- `graph_single_mark_editor_visit()` — line 58, nested/local
- `graph_single_claim_revision()` — line 70, nested/local
- `graph_single_revision_is_current()` — line 88, nested/local
- `graph_single_mark_stale()` — line 96, nested/local
- `graph_single_publish_state()` — line 114, nested/local
- `finalize_graph_single_default_state()` — line 137, nested/local
- `graph_single_accept_loaded_state()` — line 166, nested/local
- `graph_single_abort_activation()` — line 239, nested/local
- `capture_graph_single_default_state()` — line 275, nested/local
- `graph_single_default_state_snapshot()` — line 300, nested/local
- `seed_new_graph_default_state()` — line 316, nested/local
- `ensure_graph_single_editor_module()` — line 338, nested/local
- `graph_single_commit()` — line 422, nested/local
- `request_graph_single_live_preview()` — line 433, nested/local
- `show_graph_single_editor()` — line 440, nested/local
- `graph_single_preview_transaction_id()` — line 449, nested/local
- `graph_single_preview_handshake_advance()` — line 461, nested/local
- `graph_single_sync_compatible()` — line 581, nested/local
- `scalar_chr()` — line 583, nested/local
- `vec_chr()` — line 587, nested/local
- `graph_single_load()` — line 607, nested/local
- `graph_single_request_reconcile_barrier()` — line 832, nested/local

### `server_graph_export_runtime.R`
- `write_one_graph()` — line 3, nested/local
- `write_graph_export()` — line 67, nested/local
- `export_filename_now()` — line 117, nested/local

### `server_graph_fast_switch_runtime.R`
- `graph_single_fast_compare_state()` — line 7, top-level
- `graph_single_fast_equivalent()` — line 25, top-level
- `graph_single_preview_is_fresh_for_state()` — line 32, top-level
- `graph_single_clone_equivalent_preview()` — line 40, top-level
- `graph_single_fast_retarget_client()` — line 56, top-level
- `graph_single_try_equivalent_fast_switch()` — line 78, top-level
- `miss()` — line 81, nested/local

### `server_graph_materialization_runtime.R`
- `browser_ui_ready()` — line 20, nested/local
- `mark_browser_ui_ready()` — line 21, nested/local
- `init_drain_ready()` — line 36, nested/local
- `mark_init_drain_ready()` — line 37, nested/local
- `graph_materialization_signal()` — line 46, nested/local
- `graph_materialization_current_is()` — line 50, nested/local
- `graph_materialization_current_id()` — line 55, nested/local
- `graph_materialization_forget_ui_state()` — line 59, nested/local
- `reset_graph_materialization_service()` — line 67, nested/local
- `remove_graph_materialization_item()` — line 102, nested/local
- `reset_graph_materialization_source()` — line 120, nested/local
- `schedule_graph_materialization()` — line 149, nested/local
- `cancel_graph_materialization_barriers()` — line 176, nested/local
- `cancel_graph_restore_for_canonical_update()` — line 205, nested/local
- `materialization_reason_is_user_priority()` — line 235, nested/local
- `preempt_graph_materialization()` — line 243, nested/local
- `request_graph_materialization()` — line 296, nested/local
- `request_graph_materialization_ui_mount()` — line 338, nested/local
- `refit_graph_cached_preview_after_mount()` — line 379, nested/local
- `handle_graph_materialization_ui_mount_ack()` — line 404, nested/local
- `request_graph_materialization_init_drain()` — line 445, nested/local
- `handle_graph_materialization_init_ack()` — line 479, nested/local
- `request_graph_materialization_browser_drain()` — line 509, nested/local
- `handle_graph_materialization_browser_drain_ack()` — line 538, nested/local
- `materialization_import_pending_figure_assignment()` — line 574, nested/local
- `materialization_should_keep_background_ui()` — line 610, nested/local
- `complete_graph_materialization_item()` — line 624, nested/local
- `prepare_background_source_for_canonical()` — line 675, nested/local
- `accept_background_source_revision()` — line 703, nested/local
- `materialization_select_current_item()` — line 728, nested/local
- `materialization_skip_item()` — line 748, nested/local
- `materialization_ensure_background_runtime()` — line 757, nested/local
- `materialization_restore_background_runtime()` — line 794, nested/local
- `run_graph_materialization_worker()` — line 827, nested/local

### `server_graph_selection_runtime.R`
- `graph_selection_valid_id()` — line 5, nested/local
- `select_graph_preview()` — line 10, nested/local
- `request_graph_editor()` — line 25, nested/local
- `resume_graph_workspace()` — line 97, nested/local

### `server_graph_workspace_runtime.R`
- `show_graph()` — line 1, nested/local
- `create_graph()` — line 121, nested/local

### `server_project_io_runtime.R`
- `flush_active_graph_to_registry()` — line 12, nested/local
- `graph_state_for_save()` — line 49, nested/local
- `figure_state_for_save()` — line 74, nested/local
- `reset_figure_workspace()` — line 124, nested/local
- `figure_layout_diag()` — line 182, nested/local
- `restore_figure_project_state()` — line 190, nested/local
- `build_project()` — line 512, nested/local
- `project_filename()` — line 565, nested/local
- `project_bundle_filename()` — line 583, nested/local
- `collect_project_preview_records()` — line 585, nested/local
- `collect_figure_snapshot_preview_records()` — line 636, nested/local
- `write_project_package()` — line 766, nested/local
- `read_project_file()` — line 1131, nested/local
- `read_preview_entries()` — line 1229, nested/local
- `project_remove_obsolete_panels()` — line 1362, nested/local
- `project_stage_cached_target()` — line 1373, nested/local
- `map_preview_records()` — line 1636, nested/local

### `server_shared_style_runtime.R`
- `shared_style_prune_binding_to_library()` — line 5, nested/local
- `shared_style_prune_graph_state()` — line 31, nested/local
- `shared_style_apply_to_registry()` — line 39, nested/local
- `shared_style_queue_figure_states()` — line 75, nested/local
- `shared_style_commit_library()` — line 163, nested/local

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
- `project_load_overlay_ui()` — line 12, top-level
- `project_manager_ui()` — line 44, top-level
- `graph_workspace_ui()` — line 220, top-level
- `appUI()` — line 330, top-level

