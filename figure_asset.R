# figure_asset.R — Figure asset registry helpers
# v3.4.0-alpha1: internal Graphs + external SVG/raster assets.

figure_make_internal_asset <- function(id, comp = NULL, plot = NULL, meta = NULL) {
  comp <- comp %||% list()
  list(
    asset_id = as.character(id),
    source_type = as.character(comp$source_type %||% "internal_graph"),
    source_id = as.character(id),
    name = as.character(comp$name %||% id),
    type = "graph",
    plot = plot,
    meta = meta %||% list(),
    body = comp$body,
    legend = comp$legend,
    geometry = comp$geometry,
    capabilities = comp$capabilities %||% list(
      vector_preview = TRUE,
      style_override = TRUE,
      legend_component = TRUE,
      external_asset = FALSE
    )
  )
}

figure_asset_has_svg <- function(x) {
  is.list(x) && nzchar(as.character(x$svg %||% ""))
}

figure_external_asset_id <- function(name = "asset", existing = character(0)) {
  base <- tools::file_path_sans_ext(basename(as.character(name %||% "asset")[1]))
  base <- gsub("[^A-Za-z0-9_-]+", "_", base)
  if (!nzchar(base)) base <- "asset"
  stem <- paste0("asset_", base)
  id <- stem
  i <- 2L
  while (id %in% existing) {
    id <- paste0(stem, "_", i)
    i <- i + 1L
  }
  id
}

figure_file_to_data_uri <- function(path, mime = NULL) {
  if (!file.exists(path)) return("")
  if (is.null(mime) || !nzchar(mime)) {
    ext <- tolower(tools::file_ext(path))
    mime <- switch(ext, png="image/png", jpg="image/jpeg", jpeg="image/jpeg",
                   webp="image/webp", svg="image/svg+xml", "application/octet-stream")
  }
  raw <- readBin(path, "raw", n = file.info(path)$size)
  if (!length(raw)) return("")
  # jsonlite is already a hard dependency of the app; its base64 helper avoids
  # introducing an additional package only for Figure assets.
  enc <- jsonlite::base64_enc(raw)
  paste0("data:", mime, ";base64,", enc)
}

figure_import_external_asset <- function(upload, existing = list()) {
  if (is.null(upload) || is.null(upload$datapath) || !file.exists(upload$datapath)) {
    stop("Asset uploadが見つかりません。")
  }
  nm <- as.character(upload$name %||% basename(upload$datapath))[1]
  ext <- tolower(tools::file_ext(nm))
  id <- figure_external_asset_id(nm, names(existing %||% list()))
  if (identical(ext, "svg")) {
    lines <- readLines(upload$datapath, warn = FALSE, encoding = "UTF-8")
    svg <- paste(lines, collapse = "\n")
    if (!grepl("<svg\\b", svg, perl = TRUE)) stop("有効なSVGではありません。")
    return(list(
      asset_id = id, source_type = "external_asset", source_id = id,
      name = nm, type = "svg", svg = svg, data_uri = "",
      meta = list(width = 600, height = 600, panel_width = 600, panel_height = 600),
      capabilities = list(vector_preview=TRUE, style_override=FALSE, legend_component=FALSE, external_asset=TRUE)
    ))
  }
  if (!ext %in% c("png", "jpg", "jpeg", "webp")) stop("PNG/JPEG/WebP/SVGのみ対応しています。")
  mime <- switch(ext, png="image/png", jpg="image/jpeg", jpeg="image/jpeg", webp="image/webp")
  list(
    asset_id = id, source_type = "external_asset", source_id = id,
    name = nm, type = "raster", svg = "", data_uri = figure_file_to_data_uri(upload$datapath, mime),
    meta = list(width = 600, height = 600, panel_width = 600, panel_height = 600),
    capabilities = list(vector_preview=FALSE, style_override=FALSE, legend_component=FALSE, external_asset=TRUE)
  )
}

figure_asset_source_choices <- function(meta, external_assets = list()) {
  g <- if (!is.null(meta) && nrow(meta)) {
    stats::setNames(as.character(meta$id), paste0("Graph: ", as.character(meta$name)))
  } else character(0)
  e <- if (length(external_assets)) {
    stats::setNames(names(external_assets), vapply(external_assets, figure_asset_display_name, character(1)))
  } else character(0)
  c(g, e)
}

# v3.4.0-alpha2 metadata for imported external graphs and separately imported legends.
figure_decorate_external_asset <- function(asset, role = c("generic","external_graph","legend"),
                                           legend_mode = c("included","separate","none"),
                                           legend_asset_id = "", parent_asset_id = "") {
  role <- match.arg(role)
  legend_mode <- match.arg(legend_mode)
  asset$asset_role <- role
  asset$legend_mode <- if (identical(role, "external_graph")) legend_mode else "none"
  asset$legend_asset_id <- as.character(legend_asset_id %||% "")[1]
  asset$parent_asset_id <- as.character(parent_asset_id %||% "")[1]
  asset$capabilities <- modifyList(asset$capabilities %||% list(), list(
    external_graph = identical(role, "external_graph"),
    legend_component = identical(role, "legend") || identical(legend_mode, "separate")
  ))
  asset
}

figure_external_legend_asset <- function(asset, assets = list()) {
  if (!is.list(asset) || !identical(as.character(asset$legend_mode %||% "included"), "separate")) return(NULL)
  id <- as.character(asset$legend_asset_id %||% "")[1]
  if (!nzchar(id)) return(NULL)
  assets[[id]] %||% NULL
}

figure_asset_display_name <- function(z) {
  role <- as.character(z$asset_role %||% "generic")
  prefix <- switch(role, external_graph="External graph", legend="Legend", "Asset")
  paste0(prefix, ": ", as.character(z$name %||% z$asset_id %||% "asset"))
}
