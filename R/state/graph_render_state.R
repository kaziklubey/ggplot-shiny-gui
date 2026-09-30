# ============================================================
# Canonical render-state contract
# ============================================================
# GraphState is the persistence/editing contract. RenderState contains only
# values that can change the current plot. Hidden/inactive control values are
# deliberately collapsed so UI representation differences cannot block an
# otherwise-equivalent Graph from becoming READY.

graph_render_state_apply_semantics <- function(state) {
  if (is.null(state) || !is.list(state)) return(state)

  out <- graph_normalize_legend_state(state)
  pl <- out$plot %||% list()
  mp <- out$mapping %||% list()
  rs <- out$reshape %||% list()
  filter <- graph_plot_filter_normalize(out$plot_filter)
  out$plot_filter <- if (filter$enabled) filter else graph_plot_filter_default()

  # Wide->Long configuration changes the plot only while reshape is enabled.
  # The browser keeps hidden checkbox/select/text values alive when the mode is
  # OFF, so comparing those dormant values creates false render revisions.
  if (!isTRUE(rs$enabled)) {
    out$reshape <- list(enabled = FALSE)
  }

  plot_type <- as.character(pl$type %||% "line")[[1]]
  bar_layout <- if (identical(plot_type, "bar")) {
    graph_plot_bar_layout_normalize(pl$bar_layout %||% "side_by_side")
  } else {
    "side_by_side"
  }
  if (identical(plot_type, "bar")) {
    pl$bar_layout <- bar_layout
    pl$bar_value_source <- graph_plot_bar_value_source_normalize(
      pl$bar_value_source %||% "numeric_y"
    )
    pl$bar_proportion_display <- graph_plot_bar_proportion_display_normalize(
      pl$bar_proportion_display %||% "percent"
    )
  } else {
    pl$bar_layout <- NULL
    pl$bar_value_source <- NULL
    pl$bar_proportion_display <- NULL
  }
  bar_count_mode <- identical(plot_type, "bar") &&
    graph_plot_bar_value_source_is_count(pl$bar_value_source %||% "numeric_y")
  bar_layout_stacked <- identical(plot_type, "bar") && graph_plot_bar_layout_is_stacked(bar_layout)
  bar_layout_percent <- identical(plot_type, "bar") && graph_plot_bar_layout_is_percent(bar_layout)
  if (!bar_layout_percent) pl$bar_proportion_display <- NULL
  summary_type <- as.character(pl$summary %||% "mean")[[1]]
  external_mode <- as.character(pl$external_error_mode %||% "none")[[1]]

  # Line-break selections are render-active only for line plots. Normalize old
  # Projects without the field to the same empty representation as new ones.
  if (identical(plot_type, "line")) {
    pl$line_breaks <- unique(as.character(unlist(pl$line_breaks %||% character(0), use.names = FALSE)))
    pl$line_breaks <- pl$line_breaks[!is.na(pl$line_breaks) & nzchar(pl$line_breaks)]
  } else {
    pl$line_breaks <- NULL
  }


  # Line-series identity is Mapping semantics only for line plots. The
  # explicit column is dormant unless column mode is selected.
  if (!identical(plot_type, "line")) {
    mp$line_series_mode <- NULL
    mp$line_series_var <- NULL
  } else {
    mode <- as.character(mp$line_series_mode %||% "auto")[[1]]
    if (!mode %in% c("auto", "mapped", "single", "column")) mode <- "auto"
    mp$line_series_mode <- mode
    if (!identical(mode, "column")) mp$line_series_var <- NULL
  }

  # External error-column selectors affect rendering only for direct-value
  # Line/Bar plots. Their selectInputs remain populated while hidden, so the
  # browser may hold a column name even when GraphState stores an empty value.
  # Treat those representations as the same RenderState whenever the controls
  # are inactive.
  external_enabled <- plot_type %in% c("line", "bar") &&
    !bar_count_mode &&
    !bar_layout_stacked &&
    identical(summary_type, "value") &&
    external_mode %in% c("symmetric", "bounds")

  if (!isTRUE(external_enabled)) {
    pl$external_error_mode <- "none"
    mp$external_error <- NULL
    mp$external_ymin <- NULL
    mp$external_ymax <- NULL
  } else if (identical(external_mode, "symmetric")) {
    mp$external_ymin <- NULL
    mp$external_ymax <- NULL
  } else if (identical(external_mode, "bounds")) {
    mp$external_error <- NULL
  }

  if (bar_layout_stacked) {
    # Raw points, individual connections and Shape are side-by-side overlay
    # semantics. Keep their saved values in GraphState but collapse them in the
    # render contract while a stacked layout is active.
    pl$show_raw <- FALSE
    pl$connect_id <- FALSE
    pl$individual_connect_direction <- NULL
    mp$shape <- NULL
  }

  if (bar_count_mode) {
    # Numeric Y and observation-summary controls remain persisted in GraphState,
    # but category counts depend only on X / Position / Color / Facet.
    mp$y <- NULL
    mp$id <- NULL
    mp$shape <- NULL
    pl$summary <- NULL
    pl$summary_unit <- NULL
    pl$show_raw <- FALSE
    pl$connect_id <- FALSE
    pl$individual_connect_direction <- NULL
  }

  if (bar_layout_percent && is.list(out$labels)) {
    # Percentage bars own a fixed 0-100% axis. Manual numeric Y limits are
    # preserved in GraphState and become active again outside this layout.
    out$labels$ymin <- NULL
    out$labels$ymax <- NULL
    out$labels$y_top_to_tick <- NULL
  }

  out$plot <- pl
  out$mapping <- mp
  out
}

graph_render_state <- function(state) {
  if (is.null(state) || !is.list(state)) return(state)
  out <- graph_render_state_apply_semantics(state)
  for (nm in c("version", "schema_version", "app", "project_name", "export", "statistics_recipes", "statistics_selected_id", "ui_snapshot")) {
    out[[nm]] <- NULL
  }

  st <- out$style
  if (is.list(st)) {
    # Style format metadata is persistence-only. It must never trigger a plot
    # rebuild when a Project is migrated to the current style schema.
    st$version <- NULL
    st$schema_version <- NULL

    pl0 <- out$plot %||% list()
    mp0 <- out$mapping %||% list()
    plot_type0 <- as.character(pl0$type %||% "line")[[1]]
    ap <- st$appearance
    if (!is.list(ap)) ap <- list()
    # Summary method/unit are already represented by out$plot. Ignore any
    # legacy Style mirrors so they cannot create false render revisions.
    ap$summary_type <- NULL
    ap$summary_unit <- NULL
    color_var <- as.character(mp0$color %||% "")[[1]]
    has_color_mapping <- nzchar(color_var) && !identical(color_var, "__fixed__")
    bar_layout0 <- if (identical(plot_type0, "bar")) {
      graph_plot_bar_layout_normalize(pl0$bar_layout %||% "side_by_side")
    } else {
      "side_by_side"
    }
    bar_percent0 <- identical(plot_type0, "bar") && graph_plot_bar_layout_is_percent(bar_layout0)
    bar_count0 <- identical(plot_type0, "bar") &&
      graph_plot_bar_value_source_is_count(pl0$bar_value_source %||% "numeric_y")

    if (graph_plot_uses_fill(plot_type0)) {
      if (isTRUE(has_color_mapping)) {
        ap$bar_fill_none_fixed <- NULL
      } else {
        st$fill_none_styles <- NULL
      }
      border_mode <- as.character(ap$bar_border_mode %||% "fixed")[[1]]
      if (!identical(border_mode, "fixed")) ap$bar_border_color <- NULL
      border_linetype <- as.character(ap$bar_border_linetype %||% "solid")[[1]]
      if (!identical(border_linetype, "custom")) {
        ap$bar_border_dash <- NULL
        ap$bar_border_gap <- NULL
      }
    } else {
      st$fill_none_styles <- NULL
      for (nm in c("bar_fill_none_fixed", "bar_border_mode", "bar_border_color",
                   "bar_border_width", "bar_border_linetype", "bar_border_dash",
                   "bar_border_gap")) ap[[nm]] <- NULL
    }

    # Scatter draws its points directly from color_styles/shape_styles. The
    # individual-data raw colour tree is a dormant editor preference there and
    # must not block Graph activation. Likewise a fixed mean colour cannot
    # affect scatter while a colour Mapping is active.
    if (identical(plot_type0, "bar") &&
        (graph_plot_bar_layout_is_stacked(bar_layout0) || bar_count0)) {
      st$raw_group_colors <- NULL
      st$shape_styles <- NULL
      for (nm in c(
        "raw_color_mode", "raw_fixed_custom", "raw_lighten", "raw_alpha",
        "raw_shape_mode", "raw_shape", "raw_point_size", "jitter_width",
        "id_line_color_mode", "id_line_custom_color", "id_line_lighten",
        "id_linetype", "id_line_width", "id_line_alpha", "summary_on_top",
        "error_color_mode", "error_color", "error_width", "error_line_width"
      )) ap[[nm]] <- NULL
    }

    if (bar_percent0) {
      for (nm in c(
        "bar_zero_touch", "y_break_enabled", "y_breaks_auto", "y_breaks_step",
        "y_break_from", "y_break_to", "y_break_space", "y_break_symbol"
      )) ap[[nm]] <- NULL
    }

    if (identical(plot_type0, "scatter")) {
      st$raw_group_colors <- NULL
      ap$x_tick_labels_show <- NULL
      if (isTRUE(has_color_mapping)) ap$mean_color_mode <- NULL
      if (!isTRUE(ap$scatter_jitter_enabled)) {
        ap$scatter_jitter_x <- NULL
        ap$scatter_jitter_y <- NULL
      }
    } else {
      ap$scatter_point_alpha <- NULL
      ap$scatter_jitter_enabled <- NULL
      ap$scatter_jitter_x <- NULL
      ap$scatter_jitter_y <- NULL
    }
    st$appearance <- ap

    # style$axes mirrors the rendered axis-range values already stored under
    # GraphState$labels. It exists for style-copy semantics, not as a second
    # render authority.
    st$axes <- NULL

    # Shared Library binding metadata controls where future semantic style
    # updates are sourced from. Concrete display/style values are already
    # materialized into ordinary GraphState fields.
    st$shared_library <- NULL

    ap <- st$appearance
    if (is.list(ap)) {
      # Saved legend-title text is dormant while title display is OFF. Keep it
      # in GraphState for later re-enable, but exclude it from RenderState so
      # editing hidden text does not redraw the plot.
      st$legend_titles <- NULL # legacy title tree is migration-only
      if (!isTRUE(ap$legend_title_show)) ap$legend_group_title <- NULL
      if (!isTRUE(ap$legend_individual_title_show)) ap$legend_individual_title <- NULL
      for (aes in graph_legend_aesthetics()) {
        if (!isTRUE(ap[[paste0("legend_", aes, "_title_show")]])) {
          ap[[paste0("legend_", aes, "_title")]] <- NULL
        }
      }

      wrap_mode <- as.character(ap$legend_wrap_mode %||% "auto")[[1]]
      if (!wrap_mode %in% c("ncol", "nrow")) {
        ap$legend_wrap_mode <- "auto"
        ap$legend_wrap_count <- NULL
      }
      spacing <- suppressWarnings(as.numeric(ap$legend_item_spacing %||% -1))
      if (!is.finite(spacing) || spacing < 0) ap$legend_item_spacing <- NULL
      text_size <- suppressWarnings(as.numeric(ap$legend_text_size %||% 0))
      if (!is.finite(text_size) || text_size <= 0) ap$legend_text_size <- NULL

      # Sticky preview is editor UI state, not plot appearance.
      ap$sticky_plot <- NULL
      # Render comparison uses the actual family passed to ggplot, not the
      # selector representation.
      ff_effective <- app_effective_font_family(
        ap$font_family_mode %||% "sans",
        ap$font_family_custom %||% ""
      )
      ap$font_family_mode <- NULL
      ap$font_family_custom <- NULL
      ap$font_family_effective <- ff_effective
      st$appearance <- ap
    }

    # Dynamic display-label controls visually inherit their source names when
    # no override exists. Older projects may have materialized those defaults;
    # collapse them so they do not create false render revisions.
    lt <- st$legend_titles
    if (is.list(lt) && length(lt)) {
      for (nm in names(lt)) {
        z <- lt[[nm]]
        if (!is.null(z) && length(z) && identical(as.character(z)[1], as.character(nm)[1])) lt[[nm]] <- NULL
      }
      st$legend_titles <- if (length(lt)) lt else NULL
    }
    ll <- st$level_labels
    if (is.list(ll) && length(ll)) {
      for (vn in names(ll)) {
        br <- ll[[vn]]
        if (!is.list(br)) next
        for (lv in names(br)) {
          z <- br[[lv]]
          if (!is.null(z) && length(z) && identical(as.character(z)[1], as.character(lv)[1])) br[[lv]] <- NULL
        }
        ll[[vn]] <- br
      }
      ll <- ll[vapply(ll, function(x) is.list(x) && length(x) > 0L, logical(1))]
      st$level_labels <- if (length(ll)) ll else NULL
    }
    out$style <- st
  }
  out
}

graph_render_diff_paths <- function(old, new) {
  app_state_diff_paths(graph_render_state(old), graph_render_state(new))
}

# RenderState is a named semantic contract. Field ordering/attributes are not
# rendering meaning, so use the canonical named-record equality contract.
# Atomic values, unnamed collections, classes and non-name attributes remain strict.
graph_render_payload_equal <- function(old_render_state, new_render_state) {
  app_state_semantically_equal(old_render_state, new_render_state)
}

graph_render_state_equal <- function(old, new) {
  graph_render_payload_equal(graph_render_state(old), graph_render_state(new))
}

graph_render_state_changed <- function(old, new) {
  !graph_render_state_equal(old, new)
}
