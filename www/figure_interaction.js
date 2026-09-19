// figure_interaction.js — Figure browser interaction controller
// v3.3.56: extracted from ui.R. pointermove remains browser-only; Shiny receives commits.

function figureViewZoomFactor() {
  var el = document.getElementById('figure_view_zoom');
  var z = el ? parseFloat(el.value) : 1;
  return (isFinite(z) && z > 0) ? z : 1;
}

function fitFigurePreviewCanvas() {
  var zoom = figureViewZoomFactor();
  var viewports = document.querySelectorAll('.figure-preview-viewport');
  viewports.forEach(function(vp) {
    var canvas = vp.querySelector('.figure-preview-canvas');
    if (!canvas) return;
    var cw = parseFloat(canvas.getAttribute('data-canvas-width')) || canvas.offsetWidth || 1;
    var ch = parseFloat(canvas.getAttribute('data-canvas-height')) || canvas.offsetHeight || 1;
    var availableWidth = Math.max(1, vp.clientWidth - 2);
    var availableHeight = Math.max(220, window.innerHeight * 0.68);
    // Preview display is width-first. A tall Figure scrolls vertically instead
    // of shrinking the whole canvas again to satisfy the viewport-height cap.
    var fitScale = Math.min(1, availableWidth / cw);
    if (!isFinite(fitScale) || fitScale <= 0) fitScale = 1;
    var scale = fitScale * zoom;
    var visualW = Math.max(1, cw * scale);
    var visualH = Math.max(1, ch * scale);
    var stage = canvas.parentElement && canvas.parentElement.classList.contains('figure-preview-stage') ? canvas.parentElement : null;
    canvas.setAttribute('data-view-scale', String(scale));
    canvas.setAttribute('data-fit-scale', String(fitScale));
    canvas.style.transform = 'scale(' + scale + ')';
    canvas.style.visibility = 'visible';
    if (stage) {
      stage.style.width = Math.ceil(visualW) + 'px';
      stage.style.height = Math.ceil(visualH) + 'px';
    }
    vp.style.height = Math.ceil(Math.min(visualH + 2, availableHeight + 2)) + 'px';
    vp.style.overflowX = visualW > availableWidth + 1 ? 'auto' : 'hidden';
    vp.style.overflowY = visualH > availableHeight ? 'auto' : 'hidden';
  });
}

window.addEventListener('resize', function() {
  window.requestAnimationFrame(fitFigurePreviewCanvas);
});
$(document).on('change', '#figure_view_zoom', function() {
  window.requestAnimationFrame(fitFigurePreviewCanvas);
});
$(document).on('shown.bs.tab', function() {
  setTimeout(fitFigurePreviewCanvas, 30);
});
$(document).on('shiny:value shiny:visualchange', function() {
  setTimeout(fitFigurePreviewCanvas, 30);
});
Shiny.addCustomMessageHandler('fit-figure-preview', function(msg) {
  setTimeout(fitFigurePreviewCanvas, 20);
});

Shiny.addCustomMessageHandler('figure-inspector-legend-position', function(msg) {
  if (!msg) return;
  var xEl = document.getElementById('figure_legend_x');
  var yEl = document.getElementById('figure_legend_y');
  var xv = parseFloat(msg.x);
  var yv = parseFloat(msg.y);
  if (xEl && isFinite(xv)) xEl.value = String(Math.round(xv * 10000) / 10000);
  if (yEl && isFinite(yv)) yEl.value = String(Math.round(yv * 10000) / 10000);
});

Shiny.addCustomMessageHandler('figure-inspector-inset-geometry', function(msg) {
  if (!msg) return;
  var fields = {x:'figure_inset_x', y:'figure_inset_y', width:'figure_inset_width', height:'figure_inset_height'};
  Object.keys(fields).forEach(function(k) {
    var el = document.getElementById(fields[k]);
    var v = parseFloat(msg[k]);
    if (el && isFinite(v)) el.value = String(Math.round(v * 10000) / 10000);
  });
});

// v3.73.1.6: server-owned selection follows a reordered Graph/Asset to its
// destination slot. This is presentation-only; no input echo is emitted.
Shiny.addCustomMessageHandler('figure-select-panel', function(msg) {
  var key = msg ? String(msg.key || '') : '';
  document.querySelectorAll('.figure-grid-cell').forEach(function(cell) {
    cell.classList.remove('selected');
  });
  if (!key) return;
  var target = null;
  document.querySelectorAll('.figure-grid-cell[data-figure-key]').forEach(function(cell) {
    if (!target && String(cell.getAttribute('data-figure-key') || '') === key) target = cell;
  });
  if (target) target.classList.add('selected');
});

Shiny.addCustomMessageHandler('figure-label-overlay-update', function(msg) {
  if (!msg || !msg.id) return;
  var cells = document.querySelectorAll('.figure-grid-cell[data-figure-id]');
  var cell = null;
  for (var i = 0; i < cells.length; i++) {
    if (String(cells[i].getAttribute('data-figure-id') || '') === String(msg.id)) {
      cell = cells[i];
      break;
    }
  }
  if (!cell) return;
  var key = String(cell.getAttribute('data-figure-key') || '');
  var label = document.querySelector('.figure-canvas-label-layer .figure-panel-label[data-figure-key="' + key + '"]');
  if (!label) label = cell.querySelector('.figure-panel-label');
  if (!label) return;

  var text = (msg.text == null) ? '' : String(msg.text);
  var size = parseFloat(msg.size);
  if (!isFinite(size)) size = 18;
  var mode = String(msg.mode || 'align');
  var anchor = String(msg.anchor || 'plot_axis');
  var xo = parseFloat(msg.xOffset); if (!isFinite(xo)) xo = 0;
  var yo = parseFloat(msg.yOffset); if (!isFinite(yo)) yo = 0;
  var gx = parseFloat(msg.x); if (!isFinite(gx)) gx = 0.06;
  var gy = parseFloat(msg.y); if (!isFinite(gy)) gy = 0.02;
  var gutter = parseFloat(msg.topGutter); if (!isFinite(gutter)) gutter = 48;

  label.textContent = text;
  label.style.fontSize = size + 'px';
  label.style.display = text ? '' : 'none';
  label.classList.toggle('free', mode === 'free');
  label.classList.toggle('figure-draggable', mode === 'free');
  label.classList.toggle('aligned', mode !== 'free');

  var cw = parseFloat(cell.getAttribute('data-cell-width')) || cell.offsetWidth || 1;
  var ch = parseFloat(cell.getAttribute('data-cell-height')) || cell.offsetHeight || 1;
  var x = 0, y = 0;
  if (mode === 'free') {
    x = cw * gx;
    y = ch * gy;
  } else {
    var shell = cell.querySelector('.figure-cell-plot-shell');
    var zone = cell.querySelector('.figure-plot-panel-zone');
    var shellLeftRaw = shell ? parseFloat(shell.style.left) : NaN;
    var shellTopRaw = shell ? parseFloat(shell.style.top) : NaN;
    var zoneLeftRaw = zone ? parseFloat(zone.style.left) : NaN;
    var shellLeft = isFinite(shellLeftRaw) ? shellLeftRaw : 0;
    var shellTop = isFinite(shellTopRaw) ? shellTopRaw : gutter;
    var zoneLeft = isFinite(zoneLeftRaw) ? zoneLeftRaw : shellLeft;
    if (anchor === 'cell_left') {
      x = 8;
      y = Math.max(2, (gutter - size) / 2);
    } else if (anchor === 'plot_left') {
      x = shellLeft + 4;
      y = Math.max(2, shellTop - size - 6);
    } else {
      x = zoneLeft;
      y = Math.max(2, shellTop - size - 6);
    }
    x += xo;
    y += yo;
  }
  var canvasOwned = String(label.getAttribute('data-coordinate-space') || '') === 'canvas';
  var cellLeft = parseFloat(cell.style.left) || 0;
  var cellTop = parseFloat(cell.style.top) || 0;
  label.style.left = (x + (canvasOwned ? cellLeft : 0)) + 'px';
  label.style.top = (y + (canvasOwned ? cellTop : 0)) + 'px';
});

// v3.3.48: Layout editor uses plain HTML controls. Commit only
// explicit user changes to the R-side Figure state. This avoids Shiny
// dynamic-input initialization feeding old values back into state.
function clampFigureNumberInput(el, fallback) {
  var value = parseFloat(el.value);
  if (!isFinite(value)) {
    value = fallback;
  }
  var min = parseFloat(el.getAttribute('min'));
  var max = parseFloat(el.getAttribute('max'));
  if (isFinite(min)) value = Math.max(min, value);
  if (isFinite(max)) value = Math.min(max, value);
  el.value = String(value);
  return value;
}

function sendFigureNumberEdit(el, type, fallback, commit) {
  var row = parseInt($(el).attr('data-row'), 10);
  var col = parseInt($(el).attr('data-col'), 10);
  var value = commit ? clampFigureNumberInput(el, fallback) : parseFloat(el.value);
  if (!isFinite(row) || !isFinite(value)) return;
  var min = parseFloat(el.getAttribute('min'));
  var max = parseFloat(el.getAttribute('max'));
  if (isFinite(min)) value = Math.max(min, value);
  if (isFinite(max)) value = Math.min(max, value);
  var msg = {type: type, row: row, value: value, nonce: Date.now()};
  if (type === 'panel_width') {
    if (!isFinite(col)) return;
    msg.col = col;
  }
  Shiny.setInputValue('figure_layout_edit', msg, {priority: 'event'});
}

// Send a stable value after a short typing pause so Figure state/autosave
// does not wait for the input to lose focus. The control itself is never
// rebuilt by this numeric edit, so this cannot create the old value loop.
$(document).on('input', '.figure-row-height-edit,.figure-panel-width-edit', function() {
  var el = this;
  if (el._figureEditTimer) clearTimeout(el._figureEditTimer);
  el._figureEditTimer = setTimeout(function() {
    var typ = el.classList.contains('figure-panel-width-edit') ? 'panel_width' : 'row_height';
    sendFigureNumberEdit(el, typ, 1, false);
  }, 250);
});

$(document).on('change', '.figure-row-height-edit', function() {
  if (this._figureEditTimer) clearTimeout(this._figureEditTimer);
  sendFigureNumberEdit(this, 'row_height', 1, true);
});

$(document).on('change', '.figure-panel-width-edit', function() {
  if (this._figureEditTimer) clearTimeout(this._figureEditTimer);
  sendFigureNumberEdit(this, 'panel_width', 1, true);
});

$(document).on('change', '.figure-panel-graph-edit', function() {
  var row = parseInt($(this).attr('data-row'), 10);
  var col = parseInt($(this).attr('data-col'), 10);
  if (!isFinite(row) || !isFinite(col)) return;
  var selectedText = this.options && this.selectedIndex >= 0
    ? this.options[this.selectedIndex].text : '';
  this.title = selectedText;
  var card = this.closest('.figure-row-panel-card-compact');
  if (card) card.title = selectedText;
  Shiny.setInputValue('figure_layout_edit', {
    type: 'panel_graph', row: row, col: col,
    value: String(this.value || ''), nonce: Date.now()
  }, {priority: 'event'});
});

// v3.3.47: compact accordion-style Row selection.
$(document).on('click', '.figure-row-summary[data-figure-row]', function(e) {
  if ($(e.target).closest('input,select,button,.selectize-control').length) return;
  var row = parseInt($(this).attr('data-figure-row'), 10);
  if (!isFinite(row)) return;
  Shiny.setInputValue('figure_row_clicked', {row: row, nonce: Date.now()}, {priority: 'event'});
});

// v3.3.47 Figure Editor: click-to-select and drag trial with stable commit.
// Drag positions use each object's owning coordinate contract; free legends
// are persisted relative to their owner Graph display frame.
$(document).on('click', '.figure-grid-cell[data-figure-id]', function(e) {
  if ($(e.target).closest('.figure-draggable').length) return;
  var id = String($(this).attr('data-figure-id') || '');
  var key = String($(this).attr('data-figure-key') || '');
  if (!id) return;
  $('.figure-grid-cell').removeClass('selected');
  $(this).addClass('selected');
  Shiny.setInputValue('figure_panel_clicked', {
    id: id,
    key: key,
    nonce: Date.now()
  }, {priority: 'event'});
});

(function() {
  var drag = null;

  function canvasScale(el) {
    var canvas = el.closest('.figure-preview-canvas');
    if (!canvas) return 1;
    var logicalW = parseFloat(canvas.getAttribute('data-canvas-width')) || canvas.offsetWidth || 1;
    var rect = canvas.getBoundingClientRect();
    var scale = rect.width / logicalW;
    return (isFinite(scale) && scale > 0) ? scale : 1;
  }

  document.addEventListener('pointerdown', function(e) {
    var hit = e.target.closest('.figure-legend-drag-hitbox');
    var resizeHit = e.target.closest('.figure-inset-resize-handle');
    var target = hit ? hit.closest('.figure-draggable.free') : (resizeHit ? resizeHit.closest('.figure-draggable.free') : e.target.closest('.figure-draggable.free'));
    if (!target) return;
    var cell = target.closest('.figure-grid-cell');
    if (!cell) {
      var ownerKey = String(target.getAttribute('data-figure-key') || '');
      if (ownerKey) cell = document.querySelector('.figure-grid-cell[data-figure-key="' + ownerKey + '"]');
    }
    if (!cell) return;
    e.preventDefault();
    e.stopPropagation();
    $('.figure-grid-cell').removeClass('selected');
    $(cell).addClass('selected');
    // F1-4d: select locally while dragging.  The pointer-up commit carries
    // the owner id/key, so a panel-click roundtrip would only cause a redraw.

    var scale = canvasScale(target);
    drag = {
      el: target,
      cell: cell,
      scale: scale,
      startX: e.clientX,
      startY: e.clientY,
      startLeft: parseFloat(target.style.left) || 0,
      startTop: parseFloat(target.style.top) || 0,
      startWidth: parseFloat(target.style.width) || target.offsetWidth || 1,
      startHeight: parseFloat(target.style.height) || target.offsetHeight || 1,
      mode: resizeHit ? 'resize' : 'move',
      pointerId: e.pointerId,
      moved: false
    };
    if (target.setPointerCapture) {
      try { target.setPointerCapture(e.pointerId); } catch (err) {}
    }
    target.classList.add('dragging');
  }, true);

  document.addEventListener('pointermove', function(e) {
    if (!drag) return;
    var dx = (e.clientX - drag.startX) / drag.scale;
    var dy = (e.clientY - drag.startY) / drag.scale;
    if (Math.abs(dx) + Math.abs(dy) > 0.75) drag.moved = true;
    if (drag.mode === 'resize' && String(drag.el.getAttribute('data-drag-type') || '') === 'inset') {
      drag.el.style.width = Math.max(12, drag.startWidth + dx) + 'px';
      drag.el.style.height = Math.max(12, drag.startHeight + dy) + 'px';
    } else {
      drag.el.style.left = (drag.startLeft + dx) + 'px';
      drag.el.style.top = (drag.startTop + dy) + 'px';
    }
  }, true);

  function finishDrag(e) {
    if (!drag) return;
    var el = drag.el;
    var cell = drag.cell;
    el.classList.remove('dragging');
    if (!drag.moved) { drag = null; return; }

    var cw = parseFloat(cell.getAttribute('data-cell-width')) || cell.offsetWidth || 1;
    var ch = parseFloat(cell.getAttribute('data-cell-height')) || cell.offsetHeight || 1;
    var left = parseFloat(el.style.left) || 0;
    var top = parseFloat(el.style.top) || 0;
    var typ = String(el.getAttribute('data-drag-type') || '');
    var coordSpace = String(el.getAttribute('data-coordinate-space') || 'panel');
    var cellLeft = parseFloat(cell.style.left) || 0;
    var cellTop = parseFloat(cell.style.top) || 0;
    var localLeft = coordSpace === 'canvas' ? left - cellLeft : left;
    var localTop = coordSpace === 'canvas' ? top - cellTop : top;
    var xp, yp;

    var graphZone = null, gx = 0, gy = 0, gw = cw, gh = ch;
    if (typ === 'legend' || typ === 'inset') {
      // Figure-owned overlays persist against the owner Graph display frame,
      // not the Row/Panel. Crop therefore never changes their anchor.
      graphZone = cell.querySelector('.figure-graph-anchor-zone');
      gx = graphZone ? (parseFloat(graphZone.style.left) || 0) : 0;
      gy = graphZone ? (parseFloat(graphZone.style.top) || 0) : 0;
      gw = graphZone ? (parseFloat(graphZone.style.width) || cw) : cw;
      gh = graphZone ? (parseFloat(graphZone.style.height) || ch) : ch;
      xp = (localLeft - gx) / Math.max(1, gw);
      yp = (localTop - gy) / Math.max(1, gh);
      xp = Math.max(-2, Math.min(3, xp));
      yp = Math.max(-2, Math.min(3, yp));
    } else {
      xp = localLeft / cw;
      yp = localTop / ch;
    }
    if (!isFinite(xp)) xp = 0;
    if (!isFinite(yp)) yp = 0;

    Shiny.setInputValue('figure_drag_event', {
      id: String(el.getAttribute('data-figure-id') || ''),
      key: String(el.getAttribute('data-figure-key') || ''),
      type: typ,
      scope: typ === 'legend' ? String(el.getAttribute('data-legend-scope') || '') : '',
      x: xp,
      y: yp,
      width: typ === 'inset' ? (el.offsetWidth / Math.max(1, gw)) : null,
      height: typ === 'inset' ? (el.offsetHeight / Math.max(1, gh)) : null,
      nonce: Date.now()
    }, {priority: 'event'});
    drag = null;
  }

  document.addEventListener('pointerup', finishDrag, true);
  document.addEventListener('pointercancel', finishDrag, true);
})();
