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

  # Wide->Long configuration changes the plot only while reshape is enabled.
  # The browser keeps hidden checkbox/select/text values alive when the mode is
  # OFF, so comparing those dormant values creates false render revisions.
  if (!isTRUE(rs$enabled)) {
    out$reshape <- list(enabled = FALSE)
  }

  plot_type <- as.character(pl$type %||% "line")[[1]]
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


  # Line-series identity is Mapping semantics only for line plots.  The
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
    color_var <- as.character(mp0$color %||% "")[[1]]
    has_color_mapping <- nzchar(color_var) && !identical(color_var, "__fixed__")

    # Scatter draws its points directly from color_styles/shape_styles. The
    # individual-data raw colour tree is a dormant editor preference there and
    # must not block Graph activation. Likewise a fixed mean colour cannot
    # affect scatter while a colour Mapping is active.
    if (identical(plot_type0, "scatter")) {
      st$raw_group_colors <- NULL
      ap$x_tick_labels_show <- NULL
      if (isTRUE(has_color_mapping)) ap$mean_color_mode <- NULL
    } else {
      ap$scatter_point_alpha <- NULL
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

graph_render_state_changed <- function(old, new) {
  !identical(graph_render_state(old), graph_render_state(new))
}
