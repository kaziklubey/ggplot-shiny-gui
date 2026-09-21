# pptx_editable_export.R — shared editable PowerPoint helpers
#
# rvg emits editable DrawingML as a grouped shape (<p:grpSp>). PowerPoint can
# normally ungroup that object, but the GUI's PowerPoint export is intended to
# make low-level plot elements directly selectable where possible. After the
# PPTX is written we therefore flatten only our own rvg wrapper groups whose
# group transform is an identity transform (off == chOff and ext == chExt).
# Child geometry already uses slide coordinates in that case, so flattening does
# not alter the rendered Figure/Graph.

pptx_editable_require <- function() {
  missing <- c(
    if (!requireNamespace("officer", quietly = TRUE)) "officer" else character(0),
    if (!requireNamespace("rvg", quietly = TRUE)) "rvg" else character(0),
    if (!requireNamespace("xml2", quietly = TRUE)) "xml2" else character(0),
    if (!requireNamespace("zip", quietly = TRUE)) "zip" else character(0)
  )
  if (length(missing)) {
    stop("編集可能PowerPointの出力には ", paste(missing, collapse = " / "), " パッケージが必要です。")
  }
  invisible(TRUE)
}

pptx_blank_layout <- function(doc) {
  layouts <- tryCatch(officer::layout_summary(doc), error = function(e) NULL)
  if (!is.data.frame(layouts) || !nrow(layouts) ||
      !all(c("layout", "master") %in% names(layouts))) {
    stop("PowerPointのBlankレイアウトを取得できませんでした。")
  }

  nm <- trimws(as.character(layouts$layout))
  idx <- which(tolower(nm) == "blank")
  if (!length(idx)) idx <- grep("blank|空白", nm, ignore.case = TRUE)
  if (!length(idx)) idx <- nrow(layouts)
  idx <- idx[[1]]

  list(
    layout = as.character(layouts$layout[[idx]]),
    master = as.character(layouts$master[[idx]])
  )
}

pptx_set_slide_size <- function(doc, width_in, height_in) {
  width_in <- suppressWarnings(as.numeric(width_in)[1])
  height_in <- suppressWarnings(as.numeric(height_in)[1])
  if (!all(is.finite(c(width_in, height_in))) || width_in <= 0 || height_in <= 0) {
    stop("PowerPointのスライドサイズが不正です。")
  }
  if (width_in > 56 || height_in > 56) {
    stop(sprintf(
      "PowerPointの最大スライドサイズ（56 inch）を超えています: %.2f x %.2f inch",
      width_in, height_in
    ))
  }

  presentation_xml <- tryCatch(doc$presentation$get(), error = function(e) NULL)
  if (is.null(presentation_xml)) {
    stop("PowerPoint presentation.xmlへアクセスできませんでした。")
  }
  node <- tryCatch(xml2::xml_find_first(presentation_xml, "//p:sldSz"), error = function(e) NULL)
  if (is.null(node) || inherits(node, "xml_missing")) {
    stop("PowerPointのsldSz要素を取得できませんでした。")
  }

  emu <- 914400
  xml2::xml_set_attr(node, "cx", sprintf("%.0f", width_in * emu))
  xml2::xml_set_attr(node, "cy", sprintf("%.0f", height_in * emu))
  xml2::xml_set_attr(node, "type", "custom")

  got <- tryCatch(officer::slide_size(doc), error = function(e) NULL)
  if (is.null(got) || !all(c("width", "height") %in% names(got)) ||
      any(!is.finite(c(got$width, got$height))) ||
      abs(got$width - width_in) > 0.002 || abs(got$height - height_in) > 0.002) {
    stop("PowerPointのカスタムスライドサイズを確定できませんでした。")
  }
  doc
}

pptx_commit_temp_export <- function(source, target, attempts = 8L) {
  source <- as.character(source %||% "")[1]
  target <- as.character(target %||% "")[1]
  if (!nzchar(source) || !file.exists(source) || !nzchar(target)) {
    stop("PowerPoint export一時ファイルを確定できませんでした。")
  }
  attempts <- max(1L, suppressWarnings(as.integer(attempts %||% 8L)))
  for (i in seq_len(attempts)) {
    if (file.exists(target)) try(unlink(target), silent = TRUE)
    ok <- suppressWarnings(tryCatch(
      isTRUE(file.copy(source, target, overwrite = TRUE)),
      error = function(e) FALSE
    ))
    if (isTRUE(ok) && file.exists(target)) {
      sz <- suppressWarnings(file.info(target)$size)
      if (length(sz) && is.finite(sz) && sz > 0) return(invisible(TRUE))
    }
    Sys.sleep(min(0.4, 0.04 * i))
  }
  stop("PowerPoint exportファイルの確定に失敗しました。Windowsのファイルロックを確認してください。")
}


pptx_validate_package_structure <- function(path) {
  path <- as.character(path %||% "")[1]
  if (!nzchar(path) || !file.exists(path)) {
    stop("PowerPoint package validation対象ファイルがありません。")
  }

  listing <- tryCatch(utils::unzip(path, list = TRUE), error = function(e) NULL)
  if (is.null(listing) || !is.data.frame(listing) || !"Name" %in% names(listing)) {
    stop("PowerPoint packageのZIP構造を読み取れませんでした。")
  }

  entries <- gsub("\\\\", "/", as.character(listing$Name), fixed = FALSE)
  required <- c(
    "[Content_Types].xml",
    "_rels/.rels",
    "ppt/presentation.xml",
    "ppt/_rels/presentation.xml.rels",
    "ppt/slides/slide1.xml"
  )
  missing <- setdiff(required, entries)
  if (length(missing)) {
    stop(
      "PowerPoint packageの内部パスが壊れています。missing: ",
      paste(missing, collapse = ", ")
    )
  }

  invisible(TRUE)
}

pptx_add_editable_ggplot <- function(doc, plot, left, top, width, height, label) {
  if (!inherits(plot, "ggplot")) stop("PowerPointへ追加するggplotが不正です。")
  vals <- suppressWarnings(as.numeric(c(left, top, width, height)))
  if (length(vals) != 4L || any(!is.finite(vals)) || vals[3] <= 0 || vals[4] <= 0) {
    stop("PowerPointのGraph配置サイズが不正です。")
  }
  vg <- rvg::dml(ggobj = plot, bg = "transparent", editable = TRUE)
  officer::ph_with(
    doc,
    value = vg,
    location = officer::ph_location(
      left = vals[1], top = vals[2], width = vals[3], height = vals[4],
      newlabel = as.character(label %||% "ggplot-editable-graph")[1]
    )
  )
}

pptx_group_identity_transform <- function(group, ns, tolerance = 1) {
  read_pair <- function(xpath, attrs) {
    node <- xml2::xml_find_first(group, xpath, ns)
    if (inherits(node, "xml_missing")) return(rep(NA_real_, length(attrs)))
    suppressWarnings(as.numeric(vapply(attrs, function(a) xml2::xml_attr(node, a), character(1))))
  }
  xfrm <- xml2::xml_find_first(group, "./p:grpSpPr/a:xfrm", ns)
  if (inherits(xfrm, "xml_missing")) return(FALSE)

  # officer::xml_to_slide() sets the rvg wrapper to an identity transform by
  # making off/chOff and ext/chExt identical. Only that exact no-rotation case
  # is safe to flatten without rewriting every descendant coordinate.
  rot <- suppressWarnings(as.numeric(xml2::xml_attr(xfrm, "rot")))
  if (is.finite(rot) && abs(rot) > tolerance) return(FALSE)
  flip_h <- tolower(as.character(xml2::xml_attr(xfrm, "flipH")) %||% "")
  flip_v <- tolower(as.character(xml2::xml_attr(xfrm, "flipV")) %||% "")
  if (flip_h %in% c("1", "true") || flip_v %in% c("1", "true")) return(FALSE)

  off <- read_pair("./p:grpSpPr/a:xfrm/a:off", c("x", "y"))
  ext <- read_pair("./p:grpSpPr/a:xfrm/a:ext", c("cx", "cy"))
  choff <- read_pair("./p:grpSpPr/a:xfrm/a:chOff", c("x", "y"))
  chext <- read_pair("./p:grpSpPr/a:xfrm/a:chExt", c("cx", "cy"))
  if (any(!is.finite(c(off, ext, choff, chext)))) return(FALSE)
  all(abs(off - choff) <= tolerance) && all(abs(ext - chext) <= tolerance)
}

pptx_group_reassign_shape_ids <- function(group, ns, next_id) {
  # Select cNvPr nodes only below actual child shapes, never by relying on the
  # wrapper cNvPr being first in document order. Flattening moves these child
  # elements to the slide root, so each one receives a slide-unique shape id.
  child_ids <- xml2::xml_find_all(
    group,
    paste0(
      "./p:sp//p:cNvPr | ./p:pic//p:cNvPr | ",
      "./p:graphicFrame//p:cNvPr | ./p:cxnSp//p:cNvPr | ./p:grpSp//p:cNvPr"
    ),
    ns
  )
  id_map <- list()
  if (length(child_ids)) {
    for (node in child_ids) {
      old <- as.character(xml2::xml_attr(node, "id"))[1]
      if (is.na(old)) old <- ""
      new <- as.character(next_id)
      next_id <- next_id + 1L
      if (nzchar(old) && is.null(id_map[[old]])) id_map[[old]] <- new
      xml2::xml_set_attr(node, "id", new)
    }
  }

  refs <- xml2::xml_find_all(group, ".//a:stCxn | .//a:endCxn", ns)
  if (length(refs) && length(id_map)) {
    for (node in refs) {
      old <- as.character(xml2::xml_attr(node, "id"))[1]
      if (is.na(old)) old <- ""
      if (nzchar(old) && !is.null(id_map[[old]])) {
        xml2::xml_set_attr(node, "id", id_map[[old]])
      }
    }
  }
  next_id
}

pptx_flatten_editable_groups <- function(path, label_prefix = "ggplot-editable-") {
  pptx_editable_require()
  path <- as.character(path %||% "")[1]
  if (!nzchar(path) || !file.exists(path)) {
    stop("PowerPointのDrawingML groupを展開する対象ファイルがありません。")
  }

  td <- tempfile("pptx_flatten_")
  dir.create(td, recursive = TRUE, showWarnings = FALSE)
  on.exit(try(unlink(td, recursive = TRUE, force = TRUE), silent = TRUE), add = TRUE)
  # Validate the officer-generated package before unpacking.  The postprocessor
  # must never turn a valid PPTX into a merely ZIP-readable but Office-invalid
  # archive.
  pptx_validate_package_structure(path)
  utils::unzip(path, exdir = td)

  slide_dir <- file.path(td, "ppt", "slides")
  slide_files <- if (dir.exists(slide_dir)) {
    list.files(slide_dir, pattern = "^slide[0-9]+\\.xml$", full.names = TRUE)
  } else character(0)

  flattened <- 0L
  skipped_nonidentity <- 0L
  exposed_elements <- 0L
  for (slide_path in slide_files) {
    doc <- xml2::read_xml(slide_path)
    ns <- xml2::xml_ns(doc)
    prefix_safe <- gsub("'", "", as.character(label_prefix %||% "ggplot-editable-")[1], fixed = TRUE)
    groups <- xml2::xml_find_all(
      doc,
      paste0("//p:grpSp[starts-with(p:nvGrpSpPr/p:cNvPr/@name, '", prefix_safe, "')]"),
      ns
    )
    if (!length(groups)) next

    all_ids <- suppressWarnings(as.integer(xml2::xml_attr(xml2::xml_find_all(doc, "//p:cNvPr", ns), "id")))
    all_ids <- all_ids[is.finite(all_ids)]
    next_id <- if (length(all_ids)) max(all_ids) + 1L else 2L

    for (group in groups) {
      if (!pptx_group_identity_transform(group, ns)) {
        skipped_nonidentity <- skipped_nonidentity + 1L
        next
      }
      next_id <- pptx_group_reassign_shape_ids(group, ns, next_id)
      children <- xml2::xml_children(group)
      keep <- !xml2::xml_name(children) %in% c("nvGrpSpPr", "grpSpPr")
      content <- children[keep]
      if (length(content)) {
        exposed_elements <- exposed_elements + length(content)
        for (child in content) {
          xml2::xml_add_sibling(group, child, .where = "before", .copy = TRUE)
        }
      }
      xml2::xml_remove(group)
      flattened <- flattened + 1L
    }
    xml2::write_xml(doc, slide_path, options = "format")
  }

  rebuilt <- tempfile("pptx_flattened_", fileext = ".pptx")
  on.exit(try(unlink(rebuilt), silent = TRUE), add = TRUE)
  rel_files <- list.files(td, recursive = TRUE, all.files = TRUE, no.. = TRUE)
  rel_files <- rel_files[file.info(file.path(td, rel_files))$isdir %in% FALSE]
  # IMPORTANT: PPTX is an OPC ZIP package and its directory paths are semantic.
  # zip::zipr() defaults to cherry-pick mode, which strips the parent paths of
  # individually listed files (e.g. ppt/presentation.xml -> presentation.xml).
  # That archive still passes a raw ZIP CRC check but PowerPoint cannot open it.
  # Mirror mode preserves the package paths exactly.
  zip::zip(
    zipfile = rebuilt,
    files = rel_files,
    root = td,
    include_directories = FALSE,
    mode = "mirror"
  )
  if (!file.exists(rebuilt) || !is.finite(file.info(rebuilt)$size) || file.info(rebuilt)$size <= 0) {
    stop("PowerPointのDrawingML group展開後ファイルを生成できませんでした。")
  }
  pptx_validate_package_structure(rebuilt)
  pptx_commit_temp_export(rebuilt, path)

  list(
    flattened = flattened,
    skipped_nonidentity = skipped_nonidentity,
    exposed_elements = exposed_elements
  )
}

pptx_write_ggplot_editable <- function(path, plot, width_px, height_px, reference_res = 120,
                                        label = "ggplot-editable-graph") {
  pptx_editable_require()
  rr <- suppressWarnings(as.numeric(reference_res %||% 120)[1])
  if (!is.finite(rr) || rr <= 0) rr <- 120
  pw <- suppressWarnings(as.numeric(width_px)[1])
  ph <- suppressWarnings(as.numeric(height_px)[1])
  if (!all(is.finite(c(pw, ph))) || pw <= 0 || ph <= 0) {
    stop("PowerPoint出力用のGraphサイズが不正です。")
  }

  graph_w_in <- pw / rr
  graph_h_in <- ph / rr
  slide_w_in <- max(1, graph_w_in)
  slide_h_in <- max(1, graph_h_in)
  if (slide_w_in > 56 || slide_h_in > 56) {
    stop(sprintf(
      "GraphがPowerPointの最大スライドサイズ（56 inch）を超えています: %.2f x %.2f inch",
      graph_w_in, graph_h_in
    ))
  }
  left_in <- (slide_w_in - graph_w_in) / 2
  top_in <- (slide_h_in - graph_h_in) / 2

  doc <- officer::read_pptx()
  doc <- pptx_set_slide_size(doc, slide_w_in, slide_h_in)
  blank <- pptx_blank_layout(doc)
  doc <- officer::add_slide(doc, layout = blank$layout, master = blank$master)
  doc <- pptx_add_editable_ggplot(
    doc, plot,
    left = left_in, top = top_in, width = graph_w_in, height = graph_h_in,
    label = label
  )

  tmp <- tempfile("graph_editable_", fileext = ".pptx")
  on.exit(try(unlink(tmp), silent = TRUE), add = TRUE)
  tryCatch(
    print(doc, target = tmp),
    error = function(e) stop("編集可能PowerPointの生成に失敗しました: ", conditionMessage(e))
  )
  if (!file.exists(tmp) || !is.finite(file.info(tmp)$size) || file.info(tmp)$size <= 0) {
    stop("編集可能PowerPointの一時ファイルが生成されませんでした。")
  }

  flatten <- pptx_flatten_editable_groups(tmp, label_prefix = "ggplot-editable-")
  pptx_commit_temp_export(tmp, path)
  list(
    pptx_editable = TRUE,
    flattened_groups = as.integer(flatten$flattened %||% 0L),
    skipped_groups = as.integer(flatten$skipped_nonidentity %||% 0L),
    exposed_shapes = as.integer(flatten$exposed_elements %||% 0L),
    slide_width_in = slide_w_in,
    slide_height_in = slide_h_in,
    graph_width_in = graph_w_in,
    graph_height_in = graph_h_in
  )
}
