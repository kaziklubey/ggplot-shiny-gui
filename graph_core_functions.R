# ============================================================
# Canonical reusable Graph functions
# ============================================================
# These functions are intentionally non-reactive.  They accept explicit input
# and return explicit output so future changes can be made/tested independently
# from Shiny observers and Graph lifecycle transactions.

graph_has_selection <- function(x) {
  !is.null(x) && length(x) == 1 && nzchar(x)
}

graph_safe_num1 <- function(x, default = NA_real_) {
  z <- suppressWarnings(as.numeric(x))
  if (!length(z)) return(as.numeric(default)[1])
  z <- z[1]
  if (!is.finite(z)) return(as.numeric(default)[1])
  z
}

graph_restore_size_value <- function(x, default) {
  if (is.null(x)) return(as.numeric(default)[1])
  z <- suppressWarnings(as.numeric(unlist(x, use.names = FALSE)))
  if (!length(z) || !is.finite(z[1])) return(as.numeric(default)[1])
  z[1]
}

graph_saved_plot_size_from_state <- function(cfg) {
  a <- NULL
  if (!is.null(cfg) && !is.null(cfg$style)) a <- cfg$style$appearance

  w <- if (!is.null(a)) graph_restore_size_value(a$plot_width_px, 600) else 600
  h <- if (!is.null(a)) graph_restore_size_value(a$plot_height_px, 600) else 600

  list(
    width = max(250, min(2000, w)),
    height = max(180, min(1400, h))
  )
}

graph_complete_order <- function(existing, observed) {
  observed <- as.character(observed)
  existing <- as.character(existing)
  c(existing[existing %in% observed], setdiff(observed, existing)) |> unique()
}

graph_lighten_colour <- function(colour, amount = 0.45) {
  amount <- max(0, min(1, as.numeric(amount)))
  rgb <- grDevices::col2rgb(colour)
  mixed <- round(rgb + (255 - rgb) * amount)
  grDevices::rgb(mixed[1, ], mixed[2, ], mixed[3, ], maxColorValue = 255)
}

graph_normalise_colour <- function(colour, fallback = "#000000") {
  z <- as.character(colour %||% fallback)[1]
  if (is.na(z) || !nzchar(z)) z <- fallback
  tryCatch({
    rgb <- grDevices::col2rgb(z)
    grDevices::rgb(rgb[1, 1], rgb[2, 1], rgb[3, 1], maxColorValue = 255)
  }, error = function(e) fallback)
}

graph_default_palette <- function(n, preset = "okabe_ito") {
  n <- suppressWarnings(as.integer(n)[1])
  if (!is.finite(n) || n <= 0L) return(character(0))

  if (identical(preset, "hue")) return(scales::hue_pal()(n))

  base <- switch(
    preset,
    okabe_ito = c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                  "#0072B2", "#D55E00", "#CC79A7", "#000000"),
    set2 = c("#66C2A5", "#FC8D62", "#8DA0CB", "#E78AC3",
             "#A6D854", "#FFD92F", "#E5C494", "#B3B3B3"),
    dark2 = c("#1B9E77", "#D95F02", "#7570B3", "#E7298A",
              "#66A61E", "#E6AB02", "#A6761D", "#666666"),
    c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
      "#0072B2", "#D55E00", "#CC79A7", "#000000")
  )
  if (n <= length(base)) return(base[seq_len(n)])

  # Fixed publication palettes contain eight canonical colours.  Repeating the
  # first colours for level 9+ makes categories genuinely indistinguishable, so
  # v3.80 keeps the canonical eight and extends with non-identical hue colours.
  pool <- scales::hue_pal()(max(24L, n * 3L))
  pool <- pool[!toupper(pool) %in% toupper(base)]
  out <- c(base, pool)
  if (length(out) < n) out <- c(out, scales::hue_pal()(n + length(base)))
  out[seq_len(n)]
}

graph_default_linetypes <- function() {
  c("solid", "dashed", "dotted", "dotdash", "longdash", "twodash")
}

graph_default_shapes <- function() {
  c(16, 17, 15, 18, 3, 4, 1, 2, 0, 5)
}

graph_style_input_id <- function(prefix, variable_name, level_name = NULL) {
  key <- if (is.null(level_name)) {
    as.character(variable_name)
  } else {
    paste(as.character(variable_name), as.character(level_name), sep = "::")
  }
  raw <- charToRaw(enc2utf8(key))
  paste0(prefix, "_", paste(sprintf("%02x", as.integer(raw)), collapse = ""))
}

graph_series_combo_key <- function(style_level, series_level) {
  paste(style_level, series_level, sep = " × ")
}

graph_parse_pasted_data <- function(text) {
  # Excel/tab-separated input is preferred.
  x <- tryCatch(
    read.delim(
      text = text,
      header = TRUE,
      check.names = FALSE,
      stringsAsFactors = FALSE,
      na.strings = c("", "NA", "NaN")
    ),
    error = function(e) NULL
  )

  # Chat/plain-text copies may replace tabs with arbitrary whitespace.
  if (is.null(x) || ncol(x) < 2L) {
    x_ws <- tryCatch(
      read.table(
        text = text,
        header = TRUE,
        sep = "",
        check.names = FALSE,
        stringsAsFactors = FALSE,
        na.strings = c("", "NA", "NaN"),
        fill = TRUE,
        comment.char = "",
        quote = "\""
      ),
      error = function(e) NULL
    )
    if (!is.null(x_ws) && ncol(x_ws) >= 2L) x <- x_ws
  }
  x
}
