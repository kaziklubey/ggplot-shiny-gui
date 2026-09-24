
// v3.72.6+: report the actually loaded client asset version.  Static browser
// caching previously allowed a new R server to run against an older app_client.js,
// which broke transaction ACKs and left the Editor permanently HYDRATING.
(function() {
  var script = document.currentScript;
  var src = script ? String(script.src || '') : '';
  var version = '';
  try {
    var u = new URL(src, window.location.href);
    version = String(u.searchParams.get('v') || '');
  } catch (e) {}
  window.ggplotGuiClientAssetVersion = version;
  window.ggplotGuiClientAssetSrc = src;
  document.addEventListener('shiny:connected', function() {
    if (window.Shiny) {
      Shiny.setInputValue('graph_client_asset_version', {
        version: version,
        src: src,
        nonce: Date.now()
      }, {priority: 'event'});
    }
  }, {once: true});
})();

// v3.81 structured category ordering. Buttons publish only a role/variable/index
// transition; category labels themselves never travel through delimited text.
document.addEventListener('click', function(ev) {
  var btn = ev.target && ev.target.closest ? ev.target.closest('.category-order-move') : null;
  if (!btn || btn.disabled) return;
  var control = btn.closest('.graph-category-order-control');
  if (!control || !window.Shiny) return;
  var inputId = String(control.getAttribute('data-input-id') || '');
  if (!inputId) return;
  Shiny.setInputValue(inputId, {
    kind: String(control.getAttribute('data-kind') || ''),
    variable: String(control.getAttribute('data-variable') || ''),
    index: Number(btn.getAttribute('data-index') || 0),
    direction: Number(btn.getAttribute('data-direction') || 0),
    nonce: Date.now()
  }, {priority: 'event'});
});

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
    // Preview display is width-first.  A tall Figure scrolls vertically
    // instead of being shrunk again just to satisfy the viewport-height cap.
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

// Open another browser window on the same Shiny origin.  The server process
// remains the same, while Shiny creates an independent session for the new
// window.  Keeping the same origin also preserves the existing IndexedDB /
// FileSystemHandle storage namespace used by Project save destinations.
document.addEventListener('click', function(ev) {
  var btn = ev.target && ev.target.closest ? ev.target.closest('#open_project_window_all') : null;
  if (!btn) return;
  ev.preventDefault();
  var target = window.location.origin + window.location.pathname + window.location.search;
  window.open(target, '_blank', 'noopener');
});

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

// Project restore: acknowledge only when the exact Mapping inputs for
// the requested generation exist in the DOM and are bound by Shiny.
// Server-side generation matching rejects late acks from replaced UI.
// v3.52: keep only the progression-critical binding checker.  Earlier
// diagnostic-only sparse probes repeated the same DOM scan and sent extra
// Shiny inputs while restore was already waiting on the terminal ACK.
// Timing is now measured on the server, so that duplicate traffic is
// intentionally retired without changing the ACK gate itself.
function ggplotGuiReadBoundInputValue(el) {
  if (!el) return {readable:false, value:null};
  try {
    var tag = String(el.tagName || '').toUpperCase();
    var typ = String(el.type || '').toLowerCase();
    if (tag === 'INPUT' && typ === 'checkbox') {
      return {readable:true, value:!!el.checked};
    }
    var isCheckboxGroup = !!(el.classList && el.classList.contains('shiny-input-checkboxgroup'));
    if (isCheckboxGroup) {
      var checked = el.querySelectorAll('input[type=checkbox]:checked');
      var values = [];
      for (var i = 0; i < checked.length; i++) values.push(String(checked[i].value));
      return {readable:true, value:values};
    }
    return {readable:true, value:$(el).val()};
  } catch (e) {
    return {readable:false, value:null};
  }
}

// Statistics recipe replay uses one explicit browser-turn barrier after its
// updateInput() batch. This is not GraphState reconciliation and performs no
// semantic comparison or retry of the persistent Graph Editor.
Shiny.addCustomMessageHandler('stats-restore-browser-barrier', function(msg) {
  if (!msg || !msg.ackId) return;
  var payload = {
    id: String(msg.id || ''),
    generation: Number(msg.generation || 0),
    attempt: Number(msg.attempt || 0),
    token: String(msg.token || ''),
    nonce: Date.now()
  };
  var ack = function() {
    if (!(window.Shiny && msg.ackId)) return;
    Shiny.setInputValue(String(msg.ackId), payload, {priority: 'event'});
  };
  if (typeof window.requestAnimationFrame === 'function') {
    window.requestAnimationFrame(ack);
  } else {
    ack();
  }
});

// Browser-confirm the newly inserted Graph shell before graphServer is
// created.  insertUI() returning on the server does not mean the DOM or
// Shiny input bindings are ready in the client.
var graphUiMountGenerations = {};
var graphUiMountCleanups = {};

// v4 RC7 live-only Graph workspace. The browser keeps Graph id/name metadata
// only. No SVG/PNG Graph preview cache exists; one persistent Shiny plotOutput
// displays the ggplot generated for the current canonical GraphState.
window.ggplotGuiClientGraphCatalog = window.ggplotGuiClientGraphCatalog || {};
window.ggplotGuiClientSelectedGraph = window.ggplotGuiClientSelectedGraph || '';
window.ggplotGuiClientEditingGraph = window.ggplotGuiClientEditingGraph || '';
window.ggplotGuiClientEditingGraphName = window.ggplotGuiClientEditingGraphName || '';
window.ggplotGuiClientEditorReady = window.ggplotGuiClientEditorReady || false;


// v4.0 RC8 persistent level-control slot pools.
// Each pool allocates ordinary browser controls in chunks of 50 and never
// shrinks during the session. These controls are intentionally not Shiny input
// bindings. Programmatic Graph/style hydration therefore cannot feed back as a
// user edit; only delegated user changes publish one namespaced event payload.
function ggplotGuiSlotPoolChunk(container) {
  var n = Number(container && container.getAttribute('data-chunk-size') || 50);
  return isFinite(n) && n > 0 ? Math.max(1, Math.floor(n)) : 50;
}

function ggplotGuiSlotPoolColor(value, fallback) {
  var v = String(value || '').trim();
  var m = v.match(/^#([0-9a-fA-F]{3})$/);
  if (m) return '#' + m[1].split('').map(function(x) { return x + x; }).join('').toUpperCase();
  if (/^#[0-9a-fA-F]{6}$/.test(v)) return v.toUpperCase();
  try {
    var ctx = document.createElement('canvas').getContext('2d');
    ctx.fillStyle = String(fallback || '#333333');
    ctx.fillStyle = v;
    var out = String(ctx.fillStyle || '');
    if (/^#[0-9a-fA-F]{6}$/.test(out)) return out.toUpperCase();
  } catch (e) {}
  return String(fallback || '#333333');
}

function ggplotGuiSlotPoolSelect(options, field) {
  var select = document.createElement('select');
  select.className = 'form-control graph-slot-pool-control';
  select.setAttribute('data-field', field || 'value');
  options.forEach(function(rec) {
    var opt = document.createElement('option');
    opt.value = String(rec[1]);
    opt.textContent = String(rec[0]);
    select.appendChild(opt);
  });
  return select;
}

function ggplotGuiSlotPoolLabeledControl(labelText, control) {
  var wrap = document.createElement('div');
  wrap.className = 'form-group graph-slot-pool-control-wrap';
  var label = document.createElement('label');
  label.className = 'control-label';
  label.textContent = String(labelText || '');
  wrap.appendChild(label);
  wrap.appendChild(control);
  return wrap;
}

function ggplotGuiSlotPoolCreateSlot(container, index) {
  var kind = String(container.getAttribute('data-pool-kind') || 'color');
  var slot = document.createElement('div');
  slot.className = 'group-style-box graph-slot-pool-slot';
  slot.setAttribute('data-slot-index', String(index));
  slot.style.display = 'none';

  var title = document.createElement('b');
  title.className = 'graph-slot-pool-label';
  slot.appendChild(title);

  if (kind === 'color' || kind === 'color_fill') {
    var color = document.createElement('input');
    color.type = 'color';
    color.className = 'form-control graph-slot-pool-control graph-slot-pool-color';
    color.setAttribute('data-field', 'value');
    color.value = '#333333';
    slot.appendChild(ggplotGuiSlotPoolLabeledControl(kind === 'color_fill' ? '色' : '色', color));

    if (kind === 'color_fill') {
      var fillWrap = document.createElement('label');
      fillWrap.className = 'checkbox graph-slot-pool-fill-wrap';
      var check = document.createElement('input');
      check.type = 'checkbox';
      check.className = 'graph-slot-pool-control graph-slot-pool-fill-none';
      check.setAttribute('data-field', 'fillNone');
      fillWrap.appendChild(check);
      fillWrap.appendChild(document.createTextNode(' Bar / Box：塗りなし'));
      slot.appendChild(fillWrap);
    }
  } else if (kind === 'linetype') {
    slot.appendChild(ggplotGuiSlotPoolLabeledControl('線タイプ', ggplotGuiSlotPoolSelect([
      ['実線','solid'], ['破線','dashed'], ['点線','dotted'], ['一点鎖線','dotdash'], ['長い破線','longdash'], ['二重点線','twodash']
    ], 'value')));
  } else if (kind === 'shape') {
    slot.appendChild(ggplotGuiSlotPoolLabeledControl('点の形', ggplotGuiSlotPoolSelect([
      ['● 丸','16'], ['▲ 三角','17'], ['■ 四角','15'], ['◆ ひし形','18'], ['+ プラス','3'], ['× クロス','4'], ['○ 白丸','1'], ['△ 白三角','2'], ['□ 白四角','0'], ['◇ 白ひし形','5']
    ], 'value')));
  }
  return slot;
}

function ggplotGuiSlotPoolEnsure(container, need) {
  if (!container) return 0;
  var host = container.querySelector('.graph-slot-pool-slots');
  if (!host) return 0;
  var chunk = ggplotGuiSlotPoolChunk(container);
  var current = Number(container.getAttribute('data-capacity') || 0);
  var target = Math.max(chunk, Math.ceil(Math.max(0, Number(need || 0)) / chunk) * chunk);
  if (!isFinite(target) || target < chunk) target = chunk;
  if (current >= target) return current;
  for (var i = current + 1; i <= target; i++) host.appendChild(ggplotGuiSlotPoolCreateSlot(container, i));
  container.setAttribute('data-capacity', String(target));
  return target;
}

function ggplotGuiSlotPoolInit(root) {
  var scope = root && root.querySelectorAll ? root : document;
  var pools = scope.querySelectorAll('.graph-slot-pool');
  pools.forEach(function(container) { ggplotGuiSlotPoolEnsure(container, ggplotGuiSlotPoolChunk(container)); });
}

document.addEventListener('DOMContentLoaded', function() { ggplotGuiSlotPoolInit(document); });
document.addEventListener('shiny:connected', function() { ggplotGuiSlotPoolInit(document); });

Shiny.addCustomMessageHandler('graph-slot-pool-config', function(msg) {
  msg = msg || {};
  var container = document.getElementById(String(msg.id || ''));
  if (!container) return;
  var entries = Array.isArray(msg.entries) ? msg.entries : [];
  var options = msg.options && typeof msg.options === 'object' ? msg.options : {};
  var empty = container.querySelector('.graph-slot-pool-empty');
  if (empty) {
    empty.textContent = String(msg.emptyText || container.getAttribute('data-empty-text') || '');
    empty.style.display = entries.length ? 'none' : '';
  }
  container.setAttribute('data-context-token', String(msg.contextToken || ''));
  container.setAttribute('data-generation', String(Number(msg.generation || 0)));
  ggplotGuiSlotPoolEnsure(container, entries.length);
  var slots = container.querySelectorAll('.graph-slot-pool-slot');
  slots.forEach(function(slot, idx) {
    var rec = idx < entries.length && entries[idx] ? entries[idx] : null;
    if (!rec) {
      slot.style.display = 'none';
      slot.removeAttribute('data-key');
      return;
    }
    slot.style.display = '';
    slot.setAttribute('data-key', String(rec.key || ''));
    var title = slot.querySelector('.graph-slot-pool-label');
    if (title) title.textContent = String(rec.label == null ? rec.key || '' : rec.label);
    var kind = String(container.getAttribute('data-pool-kind') || '');
    var primary = slot.querySelector('.graph-slot-pool-control[data-field="value"]');
    if (primary) {
      if (primary.type === 'color') primary.value = ggplotGuiSlotPoolColor(rec.value, '#333333');
      else primary.value = String(rec.value == null ? '' : rec.value);
    }
    var fillWrap = slot.querySelector('.graph-slot-pool-fill-wrap');
    var fill = slot.querySelector('.graph-slot-pool-fill-none');
    if (fillWrap) fillWrap.style.display = options.showFillNone ? '' : 'none';
    if (fill) fill.checked = !!rec.fillNone;
  });
});

document.addEventListener('change', function(ev) {
  var control = ev.target && ev.target.closest ? ev.target.closest('.graph-slot-pool-control') : null;
  if (!control || !window.Shiny) return;
  var slot = control.closest('.graph-slot-pool-slot');
  var container = control.closest('.graph-slot-pool');
  if (!slot || !container || slot.style.display === 'none') return;
  var eventInput = String(container.getAttribute('data-event-input') || '');
  var key = String(slot.getAttribute('data-key') || '');
  if (!eventInput || !key) return;
  var field = String(control.getAttribute('data-field') || 'value');
  var value = control.type === 'checkbox' ? !!control.checked : String(control.value == null ? '' : control.value);
  Shiny.setInputValue(eventInput, {
    pool: String(container.getAttribute('data-pool-id') || ''),
    key: key,
    index: Number(slot.getAttribute('data-slot-index') || 0),
    field: field,
    value: value,
    generation: Number(container.getAttribute('data-generation') || 0),
    contextToken: String(container.getAttribute('data-context-token') || ''),
    nonce: Date.now()
  }, {priority:'event'});
});

// v4.0 RC11 browser working state. Full-Editor fixed controls are browser-owned
// while the Editor is READY. Their ordinary Shiny input messages are cancelled
// and replaced by one revisioned patch channel. R remains the canonical
// GraphState owner.
window.ggplotGuiBrowserPatchPoc = window.ggplotGuiBrowserPatchPoc || {
  ready: false,
  graphId: '',
  revision: 0,
  nextSeq: 0,
  inflight: null,
  queue: [],
  working: {},
  paths: {},
  suppressOnce: {},
  hydrating: false,
  hydrationGeneration: 0,
  hydrationExpected: {},
  hydrationGuardUntil: 0,
  hydrationClearTimer: null,
  userIntentUntil: {}
};

function ggplotGuiBrowserPatchReset(id, seed, preserveHydration) {
  var st = window.ggplotGuiBrowserPatchPoc;
  var hydrationExpected = preserveHydration ? (st.hydrationExpected || {}) : {};
  var hydrationGeneration = preserveHydration ? Number(st.hydrationGeneration || 0) : 0;
  var hydrationGuardUntil = preserveHydration ? Number(st.hydrationGuardUntil || 0) : 0;
  st.ready = false;
  st.graphId = String(id || '');
  st.revision = Number(seed && seed.revision || 0);
  st.inflight = null;
  st.queue = [];
  st.working = Object.assign({}, (seed && seed.values) || {});
  st.paths = Object.assign({}, (seed && seed.paths) || {});
  st.suppressOnce = {};
  st.userIntentUntil = {};
  st.hydrationExpected = hydrationExpected;
  st.hydrationGeneration = hydrationGeneration;
  st.hydrationGuardUntil = hydrationGuardUntil;
  if (!preserveHydration && st.hydrationClearTimer !== null) {
    window.clearTimeout(st.hydrationClearTimer);
    st.hydrationClearTimer = null;
  }
}

function ggplotGuiBrowserPatchComparable(value) {
  if (Array.isArray(value)) return 'array:' + JSON.stringify(value.map(function(x) { return String(x); }));
  if (value === null || typeof value === 'undefined') return 'scalar:';
  return 'scalar:' + String(value);
}

function ggplotGuiBrowserPatchMatches(expected, actual) {
  return ggplotGuiBrowserPatchComparable(expected) === ggplotGuiBrowserPatchComparable(actual);
}

function ggplotGuiBrowserDirectControlValue(inputId) {
  var el = document.getElementById(String(inputId || ''));
  if (!el) return undefined;
  var select = String(el.tagName || '').toLowerCase() === 'select' ? el :
    (el.querySelector ? el.querySelector('select') : null);
  if (select) {
    if (select.selectize) return select.selectize.getValue();
    if (select.multiple) return Array.prototype.filter.call(select.options || [], function(opt) {
      return !!opt.selected;
    }).map(function(opt) { return opt.value; });
    return select.value;
  }
  if (el.classList && el.classList.contains('shiny-input-checkboxgroup')) {
    return Array.prototype.filter.call(el.querySelectorAll('input[type="checkbox"]'), function(box) {
      return !!box.checked;
    }).map(function(box) { return box.value; });
  }
  if (String(el.type || '').toLowerCase() === 'checkbox') return !!el.checked;
  return el.value;
}

function ggplotGuiBrowserDirectSyncClientInput(inputName, value, updateConditionals) {
  var name = String(inputName || '').split(':')[0];
  if (!name) return false;
  var app = window.Shiny && window.Shiny.shinyapp;
  if (!app || !app.$inputValues) return false;
  app.$inputValues[name] = value;
  if (updateConditionals !== false) {
    if (typeof app.$updateConditionals === 'function') app.$updateConditionals();
    else if (window.jQuery) window.jQuery(document).trigger('shiny:conditional');
  }
  return true;
}

function ggplotGuiBrowserDirectRefreshConditionals() {
  var app = window.Shiny && window.Shiny.shinyapp;
  if (app && typeof app.$updateConditionals === 'function') app.$updateConditionals();
  else if (window.jQuery) window.jQuery(document).trigger('shiny:conditional');
}

function ggplotGuiBrowserPatchKeyFromTarget(target) {
  if (!target) return '';
  var prefix = 'graph_editor_single-';
  var node = target.nodeType === 1 ? target : target.parentElement;
  var direct = node && String(node.id || '');
  if (direct.indexOf(prefix) === 0) return direct.slice(prefix.length).split(':')[0];
  var holder = node && node.closest ? node.closest('.form-group, .shiny-input-container, .graph-module') : null;
  var bound = holder && holder.querySelector ? holder.querySelector('[id^="' + prefix + '"]') : null;
  var id = String(bound && bound.id || '');
  return id.indexOf(prefix) === 0 ? id.slice(prefix.length).split(':')[0] : '';
}

function ggplotGuiPatchStateMarkUserIntent(st, key) {
  if (!st || !key) return;
  st.userIntentUntil = st.userIntentUntil || {};
  st.userIntentUntil[key] = Date.now() + 2500;
}

function ggplotGuiPatchStateHasUserIntent(st, key) {
  st = st || {};
  var until = Number((st.userIntentUntil || {})[key] || 0);
  if (until >= Date.now()) return true;
  if (st.userIntentUntil) delete st.userIntentUntil[key];
  return false;
}

function ggplotGuiBrowserPatchKeyForPrefix(target, prefix) {
  prefix = String(prefix || '');
  if (!target || !prefix) return '';
  var node = target.nodeType === 1 ? target : target.parentElement;
  var cur = node;
  while (cur && cur !== document.body) {
    var cid = String(cur.id || '');
    if (cid.indexOf(prefix) === 0) return cid.slice(prefix.length).split(':')[0];
    cur = cur.parentElement;
  }
  var holder = node && node.closest ? node.closest('.form-group, .shiny-input-container, .graph-module') : null;
  if (holder && holder.querySelectorAll) {
    var candidates = holder.querySelectorAll('[id]');
    for (var i = 0; i < candidates.length; i++) {
      var id = String(candidates[i].id || '');
      if (id.indexOf(prefix) === 0) return id.slice(prefix.length).split(':')[0];
    }
  }
  return '';
}

function ggplotGuiBrowserPatchMarkUserIntent(ev) {
  if (!ev || ev.isTrusted !== true) return;
  var graphKey = ggplotGuiBrowserPatchKeyFromTarget(ev.target);
  if (graphKey) ggplotGuiPatchStateMarkUserIntent(window.ggplotGuiBrowserPatchPoc, graphKey);

  var states = window.ggplotGuiFigureBrowserStates || {};
  Object.keys(states).some(function(prefix) {
    var key = ggplotGuiBrowserPatchKeyForPrefix(ev.target, prefix);
    if (!key) return false;
    ggplotGuiPatchStateMarkUserIntent(states[prefix], key);
    return true;
  });
}

document.addEventListener('pointerdown', ggplotGuiBrowserPatchMarkUserIntent, true);
document.addEventListener('keydown', ggplotGuiBrowserPatchMarkUserIntent, true);
document.addEventListener('input', ggplotGuiBrowserPatchMarkUserIntent, true);

function ggplotGuiBrowserPatchHasUserIntent(key) {
  return ggplotGuiPatchStateHasUserIntent(window.ggplotGuiBrowserPatchPoc || {}, key);
}

function ggplotGuiBrowserPatchSetControl(key, value) {
  var el = document.getElementById('graph_editor_single-' + String(key || ''));
  if (!el) return false;
  var st = window.ggplotGuiBrowserPatchPoc;
  st.suppressOnce[key] = value;
  return ggplotGuiBrowserDirectSet('graph_editor_single-', key, value, null);
}

function ggplotGuiBrowserPatchQueue(key, value) {
  var st = window.ggplotGuiBrowserPatchPoc;
  var path = st.paths[key];
  if (!st.ready || !path || !st.graphId || !window.Shiny) return false;
  st.working[key] = value;
  var replaced = false;
  for (var i = 0; i < st.queue.length; i++) {
    if (st.queue[i].key === key) {
      st.queue[i].value = value;
      replaced = true;
      break;
    }
  }
  if (!replaced) st.queue.push({key:key, path:path, value:value, retryCount:0});
  ggplotGuiBrowserPatchDrain();
  return true;
}

function ggplotGuiBrowserPatchDrain() {
  var st = window.ggplotGuiBrowserPatchPoc;
  if (!st.ready || st.inflight || !st.queue.length || !window.Shiny) return false;
  var patch = st.queue.shift();
  patch.seq = ++st.nextSeq;
  patch.graphId = st.graphId;
  patch.baseRevision = Number(st.revision || 0);
  st.inflight = patch;
  Shiny.setInputValue('graph_browser_patch', {
    graphId: patch.graphId,
    seq: patch.seq,
    baseRevision: patch.baseRevision,
    key: patch.key,
    path: patch.path,
    value: patch.value,
    nonce: Date.now()
  }, {priority:'event'});
  return true;
}


$(document).on('shiny:inputchanged.browserPatchPoc', function(ev) {
  var st = window.ggplotGuiBrowserPatchPoc;
  if (!st || !st.ready || !window.ggplotGuiClientEditorReady) return;
  var name = String((ev && ev.name) || '');
  var m = name.match(/^graph_editor_single-([^:]+)(?::.*)?$/);
  if (!m) return;
  var key = m[1];
  if (!Object.prototype.hasOwnProperty.call(st.paths || {}, key)) return;
  if (String(window.ggplotGuiClientEditingGraph || '') !== String(st.graphId || '')) return;

  var value = ev.value;
  // Keep Shiny's browser-local input mirror current even though this ordinary
  // event is prevented from reaching R. conditionalPanel visibility depends on
  // that client mirror (e.g. Bar must hide Line-only controls immediately).
  ggplotGuiBrowserDirectSyncClientInput(name, value, true);
  if (Object.prototype.hasOwnProperty.call(st.suppressOnce, key)) {
    var expected = st.suppressOnce[key];
    delete st.suppressOnce[key];
    if (String(expected) === String(value)) {
      ev.preventDefault();
      return;
    }
  }
  // Browser-direct hydration can cause a binding to publish after the hydrate
  // handler has returned and after READY has been announced. Keep the target
  // value as a short-lived source marker so those delayed events never become
  // revisioned user patches. A genuinely different user value clears the
  // marker immediately and follows the normal patch path.
  if (st.hydrating) {
    ev.preventDefault();
    return;
  }
  // RC13: selectize/colour/numeric bindings may publish one or more delayed
  // values after READY. During a short post-hydration guard window, only a
  // trusted user interaction may become a revisioned patch. This is short
  // enough to avoid the old five-second Scatter suppression, while pointer/
  // keyboard intent still allows an immediate real edit.
  if (Date.now() < Number(st.hydrationGuardUntil || 0) &&
      !ggplotGuiBrowserPatchHasUserIntent(key)) {
    ev.preventDefault();
    return;
  }
  if (Object.prototype.hasOwnProperty.call(st.hydrationExpected || {}, key)) {
    if (ggplotGuiBrowserPatchMatches(st.hydrationExpected[key], value)) {
      // Consume the marker. Keeping it until the five-second safety timeout
      // can misclassify a later genuine re-selection of the same option.
      delete st.hydrationExpected[key];
      ev.preventDefault();
      return;
    }
    // Choice/selectize hydration can publish transient values (for example an
    // empty selection while options are rebuilt) after READY.  Treat a
    // differing event as user input only when it is preceded by a trusted
    // browser interaction with this control; otherwise it is still hydration.
    var liveValue = ggplotGuiBrowserDirectControlValue('graph_editor_single-' + key);
    if (!ggplotGuiBrowserPatchMatches(liveValue, value) && !ggplotGuiBrowserPatchHasUserIntent(key)) {
      ev.preventDefault();
      return;
    }
    delete st.hydrationExpected[key];
  }
  ev.preventDefault();
  ggplotGuiBrowserPatchQueue(key, value);
});

Shiny.addCustomMessageHandler('graph-browser-patch-result', function(msg) {
  msg = msg || {};
  var st = window.ggplotGuiBrowserPatchPoc;
  var graphId = String(msg.graphId || '');
  var seq = Number(msg.seq || 0);
  if (!st || graphId !== String(st.graphId || '')) return;
  var inflight = st.inflight;
  if (!inflight || Number(inflight.seq || 0) !== seq) return;

  st.revision = Number(msg.revision || st.revision || 0);
  if (msg.accepted) {
    if (msg.key) {
      st.working[String(msg.key)] = msg.value;
      ggplotGuiBrowserPatchSetControl(String(msg.key), msg.value);
    }
  } else {
    var canonical = msg.canonicalValues || {};
    Object.keys(canonical).forEach(function(key) {
      st.working[key] = canonical[key];
      ggplotGuiBrowserPatchSetControl(key, canonical[key]);
    });
    if (String(msg.reason || '') === 'revision-mismatch' && Number(inflight.retryCount || 0) < 1) {
      inflight.retryCount = Number(inflight.retryCount || 0) + 1;
      st.queue.unshift({
        key: inflight.key, path: inflight.path, value: inflight.value, retryCount: inflight.retryCount
      });
    }
  }
  st.inflight = null;
  ggplotGuiBrowserPatchDrain();
});

// v3.64.0-lazyui1: presentation-only Editor memory.  This deliberately
// lives outside GraphState/Project serialization and disappears with the
// browser/Shiny session.  The fixed Editor DOM itself is still reused.
window.ggplotGuiGraphEditorUiState = window.ggplotGuiGraphEditorUiState || {};
window.ggplotGuiPendingEditorActivation = window.ggplotGuiPendingEditorActivation || null;

function ggplotGuiEditorModuleRoot() {
  var panel = document.getElementById('panel_graph_editor_single');
  return panel ? panel.querySelector('.graph-module') : null;
}

function ggplotGuiRememberableEditorDetails() {
  var root = ggplotGuiEditorModuleRoot();
  if (!root) return [];
  return Array.prototype.slice.call(
    root.querySelectorAll('details.control-section, details.control-subsection')
  );
}

function ggplotGuiEditorDetailKey(el, index) {
  if (!el) return 'detail:' + index;
  if (el.classList.contains('control-section')) {
    return 'top:' + String(el.getAttribute('data-ui-section') || index);
  }
  var top = el.closest ? el.closest('details.control-section') : null;
  var topKey = top ? String(top.getAttribute('data-ui-section') || 'top') : 'top';
  var siblings = top ? Array.prototype.slice.call(top.querySelectorAll('details.control-subsection')) : [];
  var subIndex = siblings.indexOf(el);
  return 'sub:' + topKey + ':' + (subIndex >= 0 ? subIndex : index);
}

function ggplotGuiCaptureEditorUiState(graphId) {
  graphId = String(graphId || '');
  if (!graphId) return false;
  var details = ggplotGuiRememberableEditorDetails();
  if (!details.length) return false;
  var open = {};
  details.forEach(function(el, i) {
    open[ggplotGuiEditorDetailKey(el, i)] = !!el.open;
  });
  window.ggplotGuiGraphEditorUiState[graphId] = {open: open};
  return true;
}

function ggplotGuiPublishEditorUiState(graphId, source) {
  graphId = String(graphId || '');
  if (!graphId || !window.Shiny) return false;
  ggplotGuiCaptureEditorUiState(graphId);
  var rec = window.ggplotGuiGraphEditorUiState[graphId] || {open:{}};
  Shiny.setInputValue('graph_editor_ui_state', {
    id: graphId,
    panels: rec.open || {},
    source: String(source || 'browser'),
    nonce: Date.now()
  }, {priority:'event'});
  return true;
}

// <details> can emit a burst of toggle events while one visual panel action is
// settling. Keep browser-local panel ownership current immediately, but publish
// only the final snapshot of that burst to Shiny. Transaction boundaries such
// as Graph switch flush synchronously below.
window.ggplotGuiEditorUiPublishTimer = window.ggplotGuiEditorUiPublishTimer || null;
window.ggplotGuiEditorUiPublishPending = window.ggplotGuiEditorUiPublishPending || null;

function ggplotGuiScheduleEditorUiState(graphId, source) {
  graphId = String(graphId || '');
  if (!graphId) return false;
  ggplotGuiCaptureEditorUiState(graphId);
  window.ggplotGuiEditorUiPublishPending = {
    id: graphId,
    source: String(source || 'user-toggle')
  };
  if (window.ggplotGuiEditorUiPublishTimer !== null) {
    window.clearTimeout(window.ggplotGuiEditorUiPublishTimer);
  }
  window.ggplotGuiEditorUiPublishTimer = window.setTimeout(function() {
    var pending = window.ggplotGuiEditorUiPublishPending;
    window.ggplotGuiEditorUiPublishPending = null;
    window.ggplotGuiEditorUiPublishTimer = null;
    if (pending && pending.id) {
      ggplotGuiPublishEditorUiState(pending.id, pending.source);
    }
  }, 50);
  return true;
}

function ggplotGuiFlushEditorUiState(graphId, source) {
  graphId = String(graphId || '');
  if (window.ggplotGuiEditorUiPublishTimer !== null) {
    window.clearTimeout(window.ggplotGuiEditorUiPublishTimer);
    window.ggplotGuiEditorUiPublishTimer = null;
  }
  window.ggplotGuiEditorUiPublishPending = null;
  return ggplotGuiPublishEditorUiState(graphId, source);
}

// Persist only trusted user panel toggles. Programmatic replay/restoration must
// not echo back into GraphState as a new user edit. One user action is one
// browser->Registry panel-state transaction even if the browser emits multiple
// toggle notifications for nested <details>.
document.addEventListener('toggle', function(ev) {
  var el = ev && ev.target;
  if (!el || el.tagName !== 'DETAILS' || !ev.isTrusted) return;
  if (!el.matches('details.control-section, details.control-subsection')) return;
  var root = ggplotGuiEditorModuleRoot();
  if (!root || !root.contains(el)) return;
  ggplotGuiScheduleEditorUiState(window.ggplotGuiClientEditingGraph || '', 'user-toggle');
}, true);

function ggplotGuiCloseEditorSections() {
  var root = ggplotGuiEditorModuleRoot();
  if (!root) return false;
  root.querySelectorAll('details.control-section').forEach(function(el) { el.open = false; });
  return true;
}


function ggplotGuiRestoreEditorUiState(graphId, forceTopKey) {
  graphId = String(graphId || '');
  var details = ggplotGuiRememberableEditorDetails();
  if (!details.length) return false;
  var rec = graphId ? window.ggplotGuiGraphEditorUiState[graphId] : null;
  var remembered = rec && rec.open ? rec.open : {};
  details.forEach(function(el, i) {
    var key = ggplotGuiEditorDetailKey(el, i);
    var hasRemembered = Object.prototype.hasOwnProperty.call(remembered, key);
    var defaultOpen = String(el.getAttribute('data-default-open') || '').toLowerCase() === 'true';
    el.open = hasRemembered ? remembered[key] === true : defaultOpen;
  });
  forceTopKey = String(forceTopKey || '');
  if (forceTopKey) {
    var root = ggplotGuiEditorModuleRoot();
    var forced = root ? root.querySelector('details.control-section[data-ui-section=' + forceTopKey + ']') : null;
    if (forced) forced.open = true;
  }
  return true;
}


function ggplotGuiSyncWorkspaceSectionBar(tabValue) {
  tabValue = String(tabValue || 'Plot');
  // v3.73.1.1: Graph section ownership is workspace-global, not per Graph.
  // Record it immediately; Graph section ownership is workspace-global.
  window.ggplotGuiWorkspaceMainTab = tabValue;
  document.querySelectorAll('#graph_workspace_section_bar [data-graph-main-tab]').forEach(function(btn) {
    btn.classList.toggle('active', String(btn.getAttribute('data-graph-main-tab') || '') === tabValue);
  });
  var root = ggplotGuiEditorModuleRoot();
  if (root) {
    root.classList.toggle('graph-main-information', tabValue === 'Data View' || tabValue === '製作者コメント');
    root.classList.toggle('graph-main-statistics', tabValue === 'Statistics');
  }
}

window.ggplotGuiSelectGraphMainTab = function(tabValue) {
  tabValue = String(tabValue || 'Plot');
  window.ggplotGuiWorkspaceMainTab = tabValue;
  var root = ggplotGuiEditorModuleRoot();
  if (!root) return false;
  var links = root.querySelectorAll('.graph-internal-main-tabs a[data-toggle="tab"], .graph-internal-main-tabs a[data-value]');
  var target = null;
  for (var i = 0; i < links.length; i++) {
    if (String(links[i].getAttribute('data-value') || '').trim() === tabValue) {
      target = links[i];
      break;
    }
  }
  if (target) {
    try { $(target).tab('show'); } catch (e) { try { target.click(); } catch (e2) {} }
  } else if (window.Shiny) {
    // Binding fallback for an unexpectedly different Bootstrap structure.
    Shiny.setInputValue('graph_editor_single-graph_main_tab', tabValue, {priority:'event'});
  }
  ggplotGuiSyncWorkspaceSectionBar(tabValue);
  return false;
};

function ggplotGuiUpdateEditorShell(selectedId, stateOverride) {
  selectedId = String(selectedId || window.ggplotGuiClientSelectedGraph || '');
  var selectedRec = window.ggplotGuiClientGraphCatalog[selectedId] || null;
  var selectedName = selectedRec ? String(selectedRec.name || selectedId) : selectedId;
  var editingId = String(window.ggplotGuiClientEditingGraph || '');
  var editingName = String(window.ggplotGuiClientEditingGraphName || editingId || '');
  var nm = document.getElementById('graph_editor_shell_name');
  var st = document.getElementById('graph_editor_shell_state');
  var btn = document.getElementById('graph_editor_shell_edit');
  if (nm) nm.textContent = selectedName || editingName || 'Graph未選択';
  if (st) {
    if (stateOverride) st.textContent = String(stateOverride);
    else if (selectedId && editingId && selectedId !== editingId) st.textContent = '切替中: ' + selectedName;
    else if (editingId) st.textContent = '編集中: ' + editingName;
    else st.textContent = selectedId ? '選択: ' + selectedName : 'Graph未選択';
  }
  if (btn) {
    btn.style.display = 'none';
    btn.onclick = null;
    btn.textContent = '編集中';
  }
}

// RC7: the Editor and live plot DOM are always the workspace surface. Graph
// switches never substitute a cached preview or a second layout.
function ggplotGuiPrepareReplayWorkspace(id) {
  id = String(id || window.ggplotGuiClientSelectedGraph || '');
  return ggplotGuiRevealEditorWorkspace(id);
}

function ggplotGuiRevealEditorWorkspace(id) {
  id = String(id || window.ggplotGuiClientSelectedGraph || '');
  var panels = document.getElementById('graph_panels');
  var editingPanel = document.getElementById('panel_graph_editor_single');
  if (panels) panels.style.display = '';
  if (editingPanel) editingPanel.style.display = '';
  if (id) window.ggplotGuiClientSelectedGraph = id;
  return true;
}

window.ggplotGuiSelectGraphLive = function(id) {
  id = String(id || '');
  if (!id || !window.ggplotGuiClientGraphCatalog[id]) return false;

  var previousEditing = String(window.ggplotGuiClientEditingGraph || '');
  if (previousEditing && window.ggplotGuiClientEditorReady && previousEditing !== id) {
    ggplotGuiFlushEditorUiState(previousEditing, 'switch-select');
  }

  window.ggplotGuiClientSelectedGraph = id;
  document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
    var selected = String(btn.getAttribute('data-graph-id') || '') === id;
    btn.classList.toggle('client-selected', selected);
    btn.classList.toggle('active', selected);
  });
  ggplotGuiRevealEditorWorkspace(id);
  ggplotGuiUpdateEditorShell(id, previousEditing && previousEditing !== id ? '切替中…' : '');

  if (window.Shiny) {
    Shiny.setInputValue('graph_client_selected', id, {priority:'event'});
  }
  return false;
};

// Compatibility alias for old inline handlers in restored/browser-cached HTML.
window.ggplotGuiBrowseGraph = window.ggplotGuiSelectGraphLive;

function ggplotGuiRequestEditorActivation(id, sectionKey, source, targetInputId) {
  id = String(id || window.ggplotGuiClientSelectedGraph || '');
  sectionKey = String(sectionKey || '');
  source = String(source || 'graph-select');
  targetInputId = String(targetInputId || '');
  if (!id || !window.Shiny) return false;

  // Keep the requested section entirely client-side.  GraphState remains the
  // canonical data/style owner; this is presentation-only activation memory.
  window.ggplotGuiPendingEditorActivation = {
    id: id,
    sectionKey: sectionKey,
    source: source,
    targetInputId: targetInputId
  };

  ggplotGuiUpdateEditorShell(id);

  // If this target is already in-flight, a later section click only changes
  // the pending section to reopen.  Do not start a second replay transaction.
  var editingId = String(window.ggplotGuiClientEditingGraph || '');
  if (editingId === id && !window.ggplotGuiClientEditorReady) return false;

  Shiny.setInputValue('graph_edit_select', {
    id: id,
    source: source,
    sectionKey: sectionKey,
    nonce: Date.now()
  }, {priority:'event'});
  return false;
}

function ggplotGuiRevealGraphSettingInput(inputId) {
  inputId = String(inputId || '');
  if (!inputId) return;
  window.setTimeout(function() {
    var target = document.getElementById('graph_editor_single-' + inputId) || document.getElementById(inputId);
    if (!target) {
      var candidates = document.querySelectorAll('#graph_panels [id]');
      for (var i = 0; i < candidates.length; i++) {
        var cid = String(candidates[i].id || '');
        if (cid === inputId || cid.endsWith('-' + inputId)) { target = candidates[i]; break; }
      }
    }
    if (!target) return;
    var node = target.parentElement;
    while (node && node !== document.body) {
      if (node.tagName && node.tagName.toLowerCase() === 'details') node.open = true;
      node = node.parentElement;
    }
    var box = target.closest ? (target.closest('.form-group') || target.closest('.shiny-input-container') || target) : target;
    try { box.scrollIntoView({behavior:'smooth', block:'center'}); } catch(e) {}
    if (box && box.classList) {
      box.classList.add('graph-setting-jump-highlight');
      window.setTimeout(function() { try { box.classList.remove('graph-setting-jump-highlight'); } catch(e) {} }, 1800);
    }
    try {
      if (target.focus) target.focus({preventScroll:true});
    } catch(e) {}
  }, 140);
}

function ggplotGuiOpenGraphWorkspaceForSettingsJump(id) {
  id = String(id || '');
  if (!id) return false;

  // Make the requested Graph the browser-side selection before the workspace
  // tab change.  The Graph workspace resume observer therefore sees the same
  // target even if Bootstrap publishes the tab change before graph_edit_select.
  window.ggplotGuiClientSelectedGraph = id;
  document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
    var selected = String(btn.getAttribute('data-graph-id') || '') === id;
    btn.classList.toggle('client-selected', selected);
    btn.classList.toggle('active', selected);
  });
  if (window.Shiny) {
    Shiny.setInputValue('graph_client_selected', id, {priority:'event'});
  }

  var graphTab = document.querySelector('#workspace_main_tab a[data-value="graph_workspace"], a[data-value="graph_workspace"]');
  if (graphTab && typeof graphTab.click === 'function') {
    try { graphTab.click(); } catch(e) {}
  }
  return true;
}

window.ggplotGuiJumpToGraphSetting = function(id, sectionKey, inputId) {
  id = String(id || '');
  sectionKey = String(sectionKey || '');
  inputId = String(inputId || '');
  if (!id) return false;

  if (window.Shiny) {
    Shiny.setInputValue('graph_settings_manager_jump_trace', {
      id: id,
      sectionKey: sectionKey,
      inputId: inputId,
      stage: 'main-received',
      nonce: Date.now()
    }, {priority:'event'});
  }

  ggplotGuiOpenGraphWorkspaceForSettingsJump(id);

  var editingId = String(window.ggplotGuiClientEditingGraph || '');
  if (editingId === id && window.ggplotGuiClientEditorReady) {
    window.ggplotGuiClientSelectedGraph = id;
    ggplotGuiRevealEditorWorkspace(id);
    ggplotGuiRestoreEditorUiState(id, sectionKey);
    ggplotGuiUpdateEditorShell(id);
    ggplotGuiRevealGraphSettingInput(inputId);
    return false;
  }

  // Preserve the requested section/input across the normal persistent-editor
  // activation transaction.  graph-client-edit-ready consumes this record.
  return ggplotGuiRequestEditorActivation(id, sectionKey, 'settings-manager', inputId);
};


// Graph/Figure Settings Manager popout moved to graph_settings_popout.js in v3.73.2.29.

window.ggplotGuiEditBrowsedGraph = function() {
  return ggplotGuiRequestEditorActivation(
    String(window.ggplotGuiClientSelectedGraph || ''),
    '',
    'compat-edit'
  );
};

window.ggplotGuiGraphAction = function(action) {
  var id = String(window.ggplotGuiClientSelectedGraph || '');
  if (!id || !window.Shiny) return false;
  Shiny.setInputValue(String(action), {id:id, nonce:Date.now()}, {priority:'event'});
  return false;
};

Shiny.addCustomMessageHandler('graph-client-catalog', function(msg) {
  msg = msg || {};
  var entries = Array.isArray(msg.entries) ? msg.entries : [];
  var catalog = {};
  entries.forEach(function(rec) {
    if (!rec || !rec.id) return;
    var id = String(rec.id);
    catalog[id] = {id:id, name:String(rec.name || id)};
  });
  window.ggplotGuiClientGraphCatalog = catalog;

  Object.keys(window.ggplotGuiGraphEditorUiState || {}).forEach(function(id) {
    if (!catalog[id]) delete window.ggplotGuiGraphEditorUiState[id];
  });
  var pendingActivation = window.ggplotGuiPendingEditorActivation;
  if (pendingActivation && !catalog[String(pendingActivation.id || '')]) {
    window.ggplotGuiPendingEditorActivation = null;
  }

  window.ggplotGuiClientEditingGraph = String(msg.editing || '');
  window.ggplotGuiClientEditingGraphName = String(msg.editingName || msg.editing || '');
  var selected = String(msg.selected || window.ggplotGuiClientSelectedGraph || '');
  if (selected && catalog[selected]) {
    window.ggplotGuiClientSelectedGraph = selected;
    document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
      var isSelected = String(btn.getAttribute('data-graph-id') || '') === selected;
      btn.classList.toggle('client-selected', isSelected);
      btn.classList.toggle('active', isSelected);
    });
  }
  ggplotGuiUpdateEditorShell(selected);
});

Shiny.addCustomMessageHandler('graph-client-edit-begin', function(msg) {
  var id = String((msg || {}).id || '');
  if (id) {
    var previousEditorId = String(window.ggplotGuiClientEditingGraph || '');
    if (previousEditorId && previousEditorId !== id) {
      ggplotGuiFlushEditorUiState(previousEditorId, 'switch-begin');
    }
    ggplotGuiPrepareReplayWorkspace(id);
    window.ggplotGuiClientEditorReady = false;
    ggplotGuiBrowserPatchReset(id, null);
    window.ggplotGuiClientSelectedGraph = id;
    window.ggplotGuiClientEditingGraph = id;
    var rec = window.ggplotGuiClientGraphCatalog[id];
    window.ggplotGuiClientEditingGraphName = rec ? String(rec.name || id) : id;
    document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
      var selected = String(btn.getAttribute('data-graph-id') || '') === id;
    btn.classList.toggle('client-selected', selected);
    btn.classList.toggle('active', selected);
    });
    ggplotGuiUpdateEditorShell(id);
  }
});

function ggplotGuiBrowserDirectChoiceRecord(rec) {
  if (rec == null) return {label:'', value:''};
  if (Array.isArray(rec)) {
    if (rec.length >= 2) return {label:String(rec[0] == null ? '' : rec[0]), value:String(rec[1] == null ? '' : rec[1])};
    if (rec.length === 1) return {label:String(rec[0] == null ? '' : rec[0]), value:String(rec[0] == null ? '' : rec[0])};
    return {label:'', value:''};
  }
  if (typeof rec === 'object') {
    var rawValue = rec.value;
    if (rawValue == null && rec.val != null) rawValue = rec.val;
    if (rawValue == null && rec.id != null) rawValue = rec.id;
    var rawLabel = rec.label;
    if (rawLabel == null && rec.text != null) rawLabel = rec.text;
    if (rawLabel == null && rec.name != null) rawLabel = rec.name;
    if (rawLabel == null) rawLabel = rawValue;
    if (rawValue == null) rawValue = rawLabel;
    return {label:String(rawLabel == null ? '' : rawLabel), value:String(rawValue == null ? '' : rawValue)};
  }
  return {label:String(rec), value:String(rec)};
}

function ggplotGuiBrowserDirectNormalizeChoices(choices) {
  if (Array.isArray(choices)) return choices.map(ggplotGuiBrowserDirectChoiceRecord);
  if (!choices || typeof choices !== 'object') return [];
  // Defensive compatibility with a named-object encoding.  Canonical RC11
  // payloads are arrays of {label,value}, but accepting an object prevents a
  // serializer/version difference from creating literal "undefined" options.
  return Object.keys(choices).map(function(key) {
    var rec = choices[key];
    if (rec && typeof rec === 'object' && !Array.isArray(rec)) {
      if (rec.label == null && rec.text == null && rec.name == null) rec = Object.assign({label:key}, rec);
      if (rec.value == null && rec.val == null && rec.id == null) rec = Object.assign({value:key}, rec);
      return ggplotGuiBrowserDirectChoiceRecord(rec);
    }
    return {label:String(key), value:String(rec == null ? '' : rec)};
  });
}

function ggplotGuiBrowserDirectSelectElement(el) {
  if (!el) return null;
  if (String(el.tagName || '').toUpperCase() === 'SELECT') return el;
  return el.querySelector ? el.querySelector('select') : null;
}

function ggplotGuiBrowserDirectReplaceChoices(el, choices) {
  if (!el) return false;
  var records = ggplotGuiBrowserDirectNormalizeChoices(choices);
  if (el.classList && el.classList.contains('shiny-input-checkboxgroup')) {
    var host = el.querySelector('.shiny-options-group') || el;
    while (host.firstChild) host.removeChild(host.firstChild);
    records.forEach(function(rec) {
      var wrap = document.createElement('div');
      wrap.className = 'checkbox';
      var label = document.createElement('label');
      var input = document.createElement('input');
      input.type = 'checkbox';
      input.name = el.id;
      input.value = rec.value;
      label.appendChild(input);
      label.appendChild(document.createTextNode(' ' + rec.label));
      wrap.appendChild(label);
      host.appendChild(wrap);
    });
    return true;
  }
  var select = ggplotGuiBrowserDirectSelectElement(el);
  if (!select) return false;
  if (select.selectize) {
    var sz = select.selectize;
    sz.clear(true);
    sz.clearOptions();
    records.forEach(function(rec) {
      // Shiny/selectize configurations have used both text and label as the
      // presentation field over the app's lifetime.  Populate both so the
      // dropdown can never render "undefined" solely from field-name drift.
      sz.addOption({text:rec.label, label:rec.label, value:rec.value});
    });
    sz.refreshOptions(false);
    return true;
  }
  while (select.options.length) select.remove(0);
  records.forEach(function(rec) {
    var opt = document.createElement('option');
    opt.text = rec.label;
    opt.textContent = rec.label;
    opt.value = rec.value;
    select.add(opt);
  });
  return true;
}

function ggplotGuiBrowserDirectSetValue(el, value) {
  if (!el) return false;
  var select = ggplotGuiBrowserDirectSelectElement(el);
  if (select) {
    if (select.selectize) {
      var sz = select.selectize;
      var v = Array.isArray(value) ? value.map(String) : (value == null ? '' : String(value));
      sz.setValue(v, true);
      return true;
    }
    var vals = Array.isArray(value) ? value.map(String) : [value == null ? '' : String(value)];
    Array.prototype.forEach.call(select.options || [], function(opt) {
      opt.selected = vals.indexOf(String(opt.value)) >= 0;
    });
    if (!select.multiple) select.value = vals.length ? vals[0] : '';
    return true;
  }
  if (el.classList && el.classList.contains('shiny-input-checkboxgroup')) {
    var wanted = Array.isArray(value) ? value.map(String) : [value == null ? '' : String(value)];
    Array.prototype.forEach.call(el.querySelectorAll('input[type="checkbox"]'), function(box) {
      box.checked = wanted.indexOf(String(box.value)) >= 0;
    });
    return true;
  }
  try {
    var slider = window.jQuery ? window.jQuery(el).data('ionRangeSlider') : null;
    if (slider && slider.update) {
      slider.update({from:Number(value)});
      return true;
    }
    if (String(el.type || '').toLowerCase() === 'checkbox') {
      el.checked = !!value;
      return true;
    }
    var binding = window.jQuery ? window.jQuery(el).data('shiny-input-binding') : null;
    if (binding && typeof binding.receiveMessage === 'function') {
      binding.receiveMessage(el, {value:value});
      return true;
    }
    el.value = value == null ? '' : value;
    return true;
  } catch (err) {
    try { el.value = value == null ? '' : value; } catch (ignored) {}
    return false;
  }
}

function ggplotGuiBrowserDirectSet(prefix, key, value, choices) {
  var el = document.getElementById(String(prefix || '') + String(key || ''));
  if (!el) return false;
  if (choices != null) ggplotGuiBrowserDirectReplaceChoices(el, choices);
  return ggplotGuiBrowserDirectSetValue(el, value);
}

// Full Editor Graph switching: canonical GraphState values are written into
// the already-mounted browser controls in one local pass. Programmatic input
// events are cancelled here; actual READY user edits use the revisioned patch
// channel below. No per-input Shiny replay or browser completion ACK exists.
Shiny.addCustomMessageHandler('graph-state-browser-hydrate', function(msg) {
  msg = msg || {};
  var mode = String(msg.mode || 'full');
  var figureMode = mode === 'figure_controls';
  window.ggplotGuiFigureBrowserStates = window.ggplotGuiFigureBrowserStates || {};
  var prefix = String(msg.inputPrefix || '');
  var st = figureMode ? (window.ggplotGuiFigureBrowserStates[prefix] || {}) :
    (window.ggplotGuiBrowserPatchPoc || {});
  var graphId = String(msg.graphId || '');
  var generation = Number(msg.generation || 0);
  if (!figureMode && graphId && String(window.ggplotGuiClientEditingGraph || '') !== graphId) return;
  st.hydrating = true;
  st.hydrationGeneration = generation;
  st.hydrationExpected = {};
  st.hydrationGuardUntil = Date.now() + 1000;
  st.userIntentUntil = st.userIntentUntil || {};
  st.values = {};
  st.patchInput = String(msg.patchInput || '');
  if (st.hydrationClearTimer !== null) {
    window.clearTimeout(st.hydrationClearTimer);
    st.hydrationClearTimer = null;
  }
  var values = msg.values && typeof msg.values === 'object' ? msg.values : {};
  var choices = msg.choices && typeof msg.choices === 'object' ? msg.choices : {};

  // Phase 1: replace every choice topology first.  Phase 2 then applies all
  // selected values.  This prevents select/selectize from temporarily trying
  // to select a value against the previous Graph's option set.
  Object.keys(choices).forEach(function(key) {
    var el = document.getElementById(prefix + String(key || ''));
    if (el) ggplotGuiBrowserDirectReplaceChoices(el, choices[key]);
  });
  Object.keys(values).forEach(function(key) {
    st.hydrationExpected[key] = values[key];
    st.values[key] = values[key];
    var el = document.getElementById(prefix + String(key || ''));
    if (!el || !ggplotGuiBrowserDirectSetValue(el, values[key])) {
      delete st.hydrationExpected[key];
    } else {
      ggplotGuiBrowserDirectSyncClientInput(prefix + key, values[key], false);
    }
  });
  ggplotGuiBrowserDirectRefreshConditionals();
  if (figureMode) window.ggplotGuiFigureBrowserStates[prefix] = st;
  if (!figureMode && graphId) {
    window.ggplotGuiGraphEditorUiState[graphId] = {open:(msg.panels && typeof msg.panels === 'object') ? msg.panels : {}};
    ggplotGuiRestoreEditorUiState(graphId, '');
  }
  window.setTimeout(function() {
    if (Number(st.hydrationGeneration || 0) === generation) st.hydrating = false;
  }, 0);
  st.hydrationClearTimer = window.setTimeout(function() {
    if (Number(st.hydrationGeneration || 0) !== generation) return;
    st.hydrationExpected = {};
    st.hydrationClearTimer = null;
  }, 5000);
});

// Figure Controls keep one persistent DOM and one Figure-owned working state.
// Hydration is local; subsequent user edits travel as one namespaced patch
// input and are overlaid onto the frozen Figure snapshot on the server.
$(document).on('shiny:inputchanged.figureBrowserPatch', function(ev) {
  var states = window.ggplotGuiFigureBrowserStates || {};
  var name = String((ev && ev.name) || '').split(':')[0];
  var prefixes = Object.keys(states);
  for (var i = 0; i < prefixes.length; i++) {
    var prefix = prefixes[i];
    if (name.indexOf(prefix) !== 0) continue;
    var st = states[prefix] || {};
    var key = name.slice(prefix.length);
    if (!key || !Object.prototype.hasOwnProperty.call(st.values || {}, key)) return;
    var value = ev.value;
    ggplotGuiBrowserDirectSyncClientInput(name, value, true);
    if (st.hydrating) {
      ev.preventDefault();
      return;
    }
    if (Date.now() < Number(st.hydrationGuardUntil || 0) &&
        !ggplotGuiPatchStateHasUserIntent(st, key)) {
      ev.preventDefault();
      return;
    }
    if (Object.prototype.hasOwnProperty.call(st.hydrationExpected || {}, key)) {
      if (ggplotGuiBrowserPatchMatches(st.hydrationExpected[key], value)) {
        delete st.hydrationExpected[key];
        ev.preventDefault();
        return;
      }
      var liveValue = ggplotGuiBrowserDirectControlValue(prefix + key);
      if (!ggplotGuiBrowserPatchMatches(liveValue, value) &&
          !ggplotGuiPatchStateHasUserIntent(st, key)) {
        ev.preventDefault();
        return;
      }
      delete st.hydrationExpected[key];
    }
    ev.preventDefault();
    st.values[key] = value;
    if (window.Shiny && st.patchInput) {
      Shiny.setInputValue(st.patchInput, {
        key:key, value:value, generation:Number(st.hydrationGeneration || 0), nonce:Date.now()
      }, {priority:'event'});
    }
    return;
  }
});

$(document).on('shiny:inputchanged.browserDirectHydration', function(ev) {
  var st = window.ggplotGuiBrowserPatchPoc;
  if (!st || !st.hydrating) return;
  var name = String((ev && ev.name) || '');
  if (name.indexOf('graph_editor_single-') === 0) ev.preventDefault();
});

// Focused browser-direct topology refresh for data/order-dependent controls
// that can legitimately change while the same Graph remains attached.
Shiny.addCustomMessageHandler('graph-browser-control-hydrate', function(msg) {
  msg = msg || {};
  var st = window.ggplotGuiBrowserPatchPoc || {};
  var key = String(msg.key || '');
  if (!key) return;
  var prefix = String(msg.inputPrefix || '');
  var el = document.getElementById(prefix + key);
  if (!el) return;
  var generation = Number(msg.generation || st.hydrationGeneration || 0);
  st.hydrating = true;
  st.hydrationGeneration = generation;
  st.hydrationGuardUntil = Date.now() + 1000;
  st.hydrationExpected = st.hydrationExpected || {};
  st.hydrationExpected[key] = msg.value;
  ggplotGuiBrowserDirectReplaceChoices(el, msg.choices || []);
  ggplotGuiBrowserDirectSetValue(el, msg.value);
  ggplotGuiBrowserDirectSyncClientInput(prefix + key, msg.value, true);
  window.setTimeout(function() {
    if (Number(st.hydrationGeneration || 0) === generation) st.hydrating = false;
  }, 0);
  if (st.hydrationClearTimer !== null) window.clearTimeout(st.hydrationClearTimer);
  st.hydrationClearTimer = window.setTimeout(function() {
    if (Number(st.hydrationGeneration || 0) !== generation) return;
    st.hydrationExpected = {};
    st.hydrationClearTimer = null;
  }, 5000);
});


Shiny.addCustomMessageHandler('graph-state-replay-complete-request', function(msg) {
  msg = msg || {};
  var graphId = String(msg.graphId || '');
  var panels = msg.panels && typeof msg.panels === 'object' ? msg.panels : {};
  if (graphId) {
    window.ggplotGuiGraphEditorUiState[graphId] = {open: panels};
    ggplotGuiRestoreEditorUiState(graphId, '');
  }
  var ackId = String(msg.ackId || '');
  if (window.Shiny && ackId) {
    var transportError = null;
    try {
      var prefix = String(msg.inputPrefix || '');
      // Shiny/jsonlite can encode an empty R vector differently from a JS
      // Array. Empty required-input sets are semantically [] and must never
      // make an otherwise valid replay transaction fail.
      var requiredInputs = Array.isArray(msg.requiredInputs) ? msg.requiredInputs : [];
      var bound = {};
      $('.shiny-bound-input').each(function() {
        var binding = $(this).data('shiny-input-binding');
        if (!binding) return;
        var id = binding.getId(this);
        if (!id || !prefix || id.indexOf(prefix) !== 0 ||
            requiredInputs.indexOf(id) < 0) return;
        bound[id] = true;
        // Replay changes values, never clicks actions or uploads files.
        if ($(this).hasClass('action-button') || this.type === 'file') return;
        var type = binding.getType ? binding.getType(this) : null;
        // event priority drains/cancels Shiny's rate-policy timer, notably Ace.
        // Read current binding values only; no canonical/browser comparison.
        Shiny.setInputValue(id + (type ? ':' + type : ''), binding.getValue(this),
          {priority: 'event'});
      });
      requiredInputs.forEach(function(id) {
        if (!bound[id]) throw new Error('Replay input binding unavailable: ' + id);
      });
    } catch (err) { transportError = String(err.message || err); }
    Shiny.setInputValue(ackId, {
      graphId: graphId,
      generation: Number(msg.generation || 0),
      token: String(msg.token || ''),
      error: transportError,
      nonce: Date.now()
    }, {priority:'event'});
  }
});

Shiny.addCustomMessageHandler('graph-client-edit-ready', function(msg) {
  var id = String((msg || {}).id || '');
  if (id) {
    var selectedBeforeReady = String(window.ggplotGuiClientSelectedGraph || '');
    var stillSelected = !selectedBeforeReady || selectedBeforeReady === id;
    window.ggplotGuiClientEditorReady = true;
    window.ggplotGuiClientEditingGraph = id;
    var patchSeed = (msg || {}).browserPatch || null;
    // Preserve delayed-event source markers installed by the immediately
    // preceding browser-direct hydration. Resetting them at READY was the RC9
    // path that turned hydration events into BROWSER-PATCH traffic.
    ggplotGuiBrowserPatchReset(id, patchSeed, true);
    window.ggplotGuiBrowserPatchPoc.ready = !!(patchSeed && patchSeed.enabled);
    var rec = window.ggplotGuiClientGraphCatalog[id];
    window.ggplotGuiClientEditingGraphName = rec ? String(rec.name || id) : id;

    var canonicalPanels = (msg || {}).uiPanels;
    if (canonicalPanels && typeof canonicalPanels === 'object') {
      window.ggplotGuiGraphEditorUiState[id] = {open: canonicalPanels};
    }

    var pending = window.ggplotGuiPendingEditorActivation;
    var forceSection = '';
    var targetInputId = '';
    if (pending && String(pending.id || '') === id) {
      forceSection = String(pending.sectionKey || '');
      targetInputId = String(pending.targetInputId || '');
      window.ggplotGuiPendingEditorActivation = null;
    }

    // RC7: canonical controls and the live plot share one persistent workspace.
    // No preview layer is swapped in or out while the Shiny plot updates.
    if (stillSelected) {
      ggplotGuiRevealEditorWorkspace(id);
      window.ggplotGuiClientSelectedGraph = id;
      ggplotGuiRestoreEditorUiState(id, forceSection);
      ggplotGuiUpdateEditorShell(id);
      if (targetInputId) ggplotGuiRevealGraphSettingInput(targetInputId);
    } else {
      // The user selected a newer Graph while this transaction was in flight.
      // The server drains the queued latest target immediately after this
      // READY transaction releases; do not reveal the older queued owner.
      ggplotGuiUpdateEditorShell(selectedBeforeReady);
    }
  }
});

Shiny.addCustomMessageHandler('graph-editor-shell-clear', function(msg) {
  msg = msg || {};
  window.ggplotGuiClientEditorReady = false;
  if (window.ggplotGuiBrowserPatchPoc) window.ggplotGuiBrowserPatchPoc.ready = false;
  window.ggplotGuiClientEditingGraph = '';
  window.ggplotGuiClientEditingGraphName = '';
  var selected = String(msg.selected || window.ggplotGuiClientSelectedGraph || '');
  ggplotGuiRevealEditorWorkspace(selected);
  ggplotGuiUpdateEditorShell(selected, selected ? 'Editor反映エラー' : 'Graph未選択');
});

Shiny.addCustomMessageHandler('project-close-reload', function(msg) {
  // Project close is a hard ownership boundary. Reload the Shiny session so no
  // Graph/Figure/Library/editor lease from the closed Project can survive into
  // the new pristine Graph 1 workspace.
  window.location.reload();
});

// RC7: retired fixed Global Preview subsystem removed. The persistent
// graph_editor_single plotOutput is the sole Graph display surface.

Shiny.addCustomMessageHandler('figure-editor-select', function(msg) {
  var host = document.getElementById('figure_graph_editor_host');
  if (!host) return;
  var nodes = host.querySelectorAll('.figure-graph-editor-instance');
  for (var i = 0; i < nodes.length; i++) nodes[i].style.display = 'none';
  var wrapperId = msg && msg.wrapperId ? String(msg.wrapperId) : '';
  if (!wrapperId) return;
  var target = document.getElementById(wrapperId);
  if (target) target.style.display = 'block';
});

Shiny.addCustomMessageHandler('graph-ui-mount-check', function(msg) {
  if (!msg || !msg.ackId) return;
  var generation = Number(msg.generation || 0);
  var graphId = String(msg.graphId || '');
  var panelId = String(msg.panelId || '');
  var fields = Array.isArray(msg.fields) ? msg.fields : [];
  var started = Date.now();
  var key = String(msg.ackId || '') + ':' + graphId;
  if (typeof graphUiMountCleanups[key] === 'function') graphUiMountCleanups[key]();
  graphUiMountGenerations[key] = generation;

  function snapshot() {
    var panel = panelId ? document.getElementById(panelId) : null;
    var states = [];
    var missing = [];
    for (var i = 0; i < fields.length; i++) {
      var item = fields[i] || {};
      var field = String(item.field || '');
      var id = String(item.id || '');
      var el = id ? document.getElementById(id) : null;
      var bound = !!(el && el.classList && el.classList.contains('shiny-bound-input'));
      var read = ggplotGuiReadBoundInputValue(el);
      states.push({field: field, id: id, exists: !!el, bound: bound, valueReadable: !!read.readable, value: read.value});
      if (!bound) missing.push(field || id);
    }
    if (!panel) missing.unshift('panel');
    return {
      panelExists: !!panel,
      states: states,
      missing: missing,
      domInputCount: document.querySelectorAll('input,select,textarea').length,
      boundInputCount: document.querySelectorAll('.shiny-bound-input').length
    };
  }

  var boundHandler = null;
  function cleanup() {
    if (boundHandler && window.jQuery) {
      window.jQuery(document).off('shiny:bound shiny:unbound', boundHandler);
    }
    boundHandler = null;
    if (graphUiMountCleanups[key] === cleanup) delete graphUiMountCleanups[key];
  }
  graphUiMountCleanups[key] = cleanup;

  function inspect() {
    if (graphUiMountGenerations[key] !== generation) {
      cleanup();
      return;
    }
    var snap = snapshot();
    var ready = snap.panelExists && snap.missing.length === 0;
    if (!ready) return;

    cleanup();
    Shiny.setInputValue(msg.ackId, {
      generation: generation,
      graphId: graphId,
      status: 'ready',
      panelExists: snap.panelExists,
      missing: snap.missing,
      states: snap.states,
      elapsedMs: Date.now() - started,
      domInputCount: snap.domInputCount,
      boundInputCount: snap.boundInputCount,
      nonce: Date.now()
    }, {priority: 'event'});
    graphUiMountGenerations[key] = null;
  }

  // No polling/timer fallback.  Inspect once at the next frame and thereafter
  // only when Shiny reports that an input binding has completed.
  if (window.jQuery) {
    boundHandler = function(evt) {
      if (graphUiMountGenerations[key] !== generation) {
        cleanup();
        return;
      }
      if (evt && evt.type === 'shiny:unbound' && panelId && !document.getElementById(panelId)) {
        graphUiMountGenerations[key] = null;
        cleanup();
        return;
      }
      if (typeof window.requestAnimationFrame === 'function') {
        window.requestAnimationFrame(inspect);
      } else {
        inspect();
      }
    };
    window.jQuery(document).on('shiny:bound shiny:unbound', boundHandler);
  }
  if (typeof window.requestAnimationFrame === 'function') {
    window.requestAnimationFrame(inspect);
  } else {
    inspect();
  }
});

Shiny.addCustomMessageHandler('graph-ui-mount-cancel', function(msg) {
  if (!msg) return;
  var graphId = String(msg.graphId || '');
  var ackId = String(msg.ackId || 'graph_ui_mount_ack');
  var key = ackId + ':' + graphId;
  graphUiMountGenerations[key] = null;
  if (typeof graphUiMountCleanups[key] === 'function') graphUiMountCleanups[key]();
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
  var label = cell.querySelector('.figure-panel-label');
  if (!label) return;

  var text = (msg.text == null) ? '' : String(msg.text);
  var size = parseFloat(msg.size);
  if (!isFinite(size)) size = 18;
  var mode = String(msg.mode || 'align');
  var anchor = String(msg.anchor || 'panel');
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
      y = Math.max(2, (gutter - size) / 2);
    } else {
      // Panel labels are Figure-owned: X follows the aligned data-panel edge,
      // while Y stays in the dedicated label band and does not follow
      // facet/title/axis geometry.
      x = zoneLeft;
      y = Math.max(2, (gutter - size) / 2);
    }
    x += xo;
    y += yo;
  }
  label.style.left = x + 'px';
  label.style.top = y + 'px';
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

// RC13: Figure layout numeric controls are a browser-side working copy while
// the user is spinning/typing.  Only the latest value for each field is sent
// after a short quiet period, so native spinner-arrow holds do not enqueue a
// full geometry/autofit pass for every intermediate value. Structural edits
// flush this queue before they mutate the Figure topology.
window.ggplotGuiFigureRapidLayoutEdits = window.ggplotGuiFigureRapidLayoutEdits || {};
var ggplotGuiFigureRapidLayoutDelay = 180;

function ggplotGuiFigureLayoutEditSend(msg) {
  if (!window.Shiny || !msg) return false;
  msg.nonce = Date.now();
  Shiny.setInputValue('figure_layout_edit', msg, {priority: 'event'});
  return true;
}

function ggplotGuiFigureLayoutEditQueue(key, msg, delay) {
  key = String(key || '');
  if (!key || !msg) return false;
  var store = window.ggplotGuiFigureRapidLayoutEdits;
  var old = store[key];
  if (old && old.timer) window.clearTimeout(old.timer);
  var item = {msg:Object.assign({}, msg), timer:null};
  item.timer = window.setTimeout(function() {
    var current = store[key];
    if (!current) return;
    delete store[key];
    ggplotGuiFigureLayoutEditSend(current.msg);
  }, Math.max(50, Number(delay || ggplotGuiFigureRapidLayoutDelay)));
  store[key] = item;
  return true;
}

function ggplotGuiFigureLayoutEditTakePending(key) {
  var store = window.ggplotGuiFigureRapidLayoutEdits || {};
  var keys = key ? [String(key)] : Object.keys(store);
  var edits = [];
  keys.forEach(function(k) {
    var item = store[k];
    if (!item) return;
    if (item.timer) window.clearTimeout(item.timer);
    delete store[k];
    edits.push(Object.assign({}, item.msg));
  });
  return edits;
}

function ggplotGuiFigureLayoutEditFlush(key) {
  var edits = ggplotGuiFigureLayoutEditTakePending(key);
  if (!edits.length) return false;
  return ggplotGuiFigureLayoutEditSend({type:'rapid_batch', edits:edits});
}

function ggplotGuiFigureLayoutEditSendWithPending(msg) {
  var pending = ggplotGuiFigureLayoutEditTakePending();
  var payload = Object.assign({}, msg || {});
  if (pending.length) payload.pendingEdits = pending;
  return ggplotGuiFigureLayoutEditSend(payload);
}

function sendFigureNumberEdit(el, type, fallback, commit) {
  var row = parseInt($(el).attr('data-row'), 10);
  var value = commit ? clampFigureNumberInput(el, fallback) : parseFloat(el.value);
  if (!isFinite(row) || !isFinite(value)) return;
  var min = parseFloat(el.getAttribute('min'));
  var max = parseFloat(el.getAttribute('max'));
  if (isFinite(min)) value = Math.max(min, value);
  if (isFinite(max)) value = Math.min(max, value);
  ggplotGuiFigureLayoutEditQueue(type + ':' + row, {
    type: type, row: row, value: value
  });
}

function sendFigureColumnRatioEdit(el, commit) {
  var col = parseInt($(el).attr('data-col'), 10);
  var value = commit ? clampFigureNumberInput(el, 1) : parseFloat(el.value);
  if (!isFinite(col) || !isFinite(value)) return;
  var min = parseFloat(el.getAttribute('min'));
  var max = parseFloat(el.getAttribute('max'));
  if (isFinite(min)) value = Math.max(min, value);
  if (isFinite(max)) value = Math.min(max, value);
  ggplotGuiFigureLayoutEditQueue('column_ratio:' + col, {
    type: 'column_ratio', col: col, value: value
  });
}

function sendFigureGraphSizeEdit(el, type) {
  var row = parseInt($(el).attr('data-row'), 10);
  var col = parseInt($(el).attr('data-col'), 10);
  if (!isFinite(row) || !isFinite(col)) return;
  var raw = String(el.value || '').trim();
  if (raw !== '') {
    var value = parseFloat(raw);
    if (!isFinite(value)) return;
    var min = parseFloat(el.getAttribute('min'));
    var max = parseFloat(el.getAttribute('max'));
    if (isFinite(min)) value = Math.max(min, value);
    if (isFinite(max)) value = Math.min(max, value);
    raw = String(value);
    el.value = raw;
  }
  ggplotGuiFigureLayoutEditQueue(type + ':' + row + ':' + col, {
    type: type, row: row, col: col, value: raw
  });
}

// Row height, column ratio and Graph size all share the same quiet-period
// queue. The browser control itself changes immediately; R receives only the
// final value after rapid spinner/typing input settles.
$(document).on('input change', '.figure-row-height-edit', function() {
  sendFigureNumberEdit(this, 'row_height', 1, true);
});

$(document).on('input change', '.figure-column-ratio-edit', function() {
  sendFigureColumnRatioEdit(this, true);
});

// v3.3.69: native number-input spinners use min=80 when the value is
// empty.  For an Auto field, prime the control from the Graph-side panel
// size (normally 600x600) before the browser applies the first step.
$(document).on('mousedown', '.figure-graph-width-edit,.figure-graph-height-edit', function(e) {
  if (String(this.value || '').trim() !== '') return;
  var rightEdge = this.getBoundingClientRect().right;
  if ((rightEdge - e.clientX) > 26) return; // ordinary text-field click
  var base = parseFloat(this.getAttribute('data-auto-value'));
  if (!isFinite(base) || base <= 0) base = 600;
  this.value = String(Math.round(base * 10) / 10);
});

$(document).on('keydown', '.figure-graph-width-edit,.figure-graph-height-edit', function(e) {
  if ((e.key !== 'ArrowUp' && e.key !== 'ArrowDown') || String(this.value || '').trim() !== '') return;
  var base = parseFloat(this.getAttribute('data-auto-value'));
  if (!isFinite(base) || base <= 0) base = 600;
  var step = parseFloat(this.getAttribute('step'));
  if (!isFinite(step) || step <= 0) step = 10;
  var next = base + (e.key === 'ArrowUp' ? step : -step);
  var min = parseFloat(this.getAttribute('min'));
  var max = parseFloat(this.getAttribute('max'));
  if (isFinite(min)) next = Math.max(min, next);
  if (isFinite(max)) next = Math.min(max, next);
  this.value = String(Math.round(next * 10) / 10);
  e.preventDefault();
  sendFigureGraphSizeEdit(this, this.classList.contains('figure-graph-width-edit') ? 'graph_width' : 'graph_height');
});

$(document).on('input change', '.figure-graph-width-edit,.figure-graph-height-edit', function() {
  var typ = this.classList.contains('figure-graph-width-edit') ? 'graph_width' : 'graph_height';
  sendFigureGraphSizeEdit(this, typ);
});

$(document).on('change', '.figure-row-basis-edit', function() {
  var row = parseInt($(this).attr('data-row'), 10);
  if (!isFinite(row)) return;
  ggplotGuiFigureLayoutEditSendWithPending({
    type: 'row_basis', row: row, value: String(this.value || 'inherit')
  });
});

// Phase 9: structural controls live inside a dynamic renderUI, so do not
// make their lifecycle depend on Shiny actionButton bindings. Route all
// Row/Panel add/remove clicks through the stable delegated edit channel.
$(document).on('click', '.figure-layout-structure-action', function(e) {
  e.preventDefault();
  e.stopPropagation();
  var typ = String(this.getAttribute('data-figure-layout-action') || '');
  if (!typ) return;
  var row = parseInt(this.getAttribute('data-row'), 10);
  var msg = {type: typ};
  if (isFinite(row)) msg.row = row;
  ggplotGuiFigureLayoutEditSendWithPending(msg);
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
  ggplotGuiFigureLayoutEditSendWithPending({
    type: 'panel_graph', row: row, col: col, value: String(this.value || '')
  });
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
  // v3.49.1: snapshot the current Inspector fold presentation state
  // into the same panel-selection event.  This removes the race between
  // the separate figure_inspector_fold round-trip and renderUI replacement.
  // No observer/presence probe is needed: read only the DOM that exists at
  // the explicit panel click boundary.
  var folds = {};
  document.querySelectorAll('.figure-inspector-group[data-figure-fold-key]').forEach(function(group) {
    var foldKey = String(group.getAttribute('data-figure-fold-key') || '');
    if (foldKey) folds[foldKey] = group.classList.contains('is-collapsed');
  });
  Shiny.setInputValue('figure_panel_clicked', {
    id: id,
    key: key,
    folds: folds,
    nonce: Date.now()
  }, {priority: 'event'});
});

// F1-4e: mirror canonical legend coordinates in the Inspector without
// dispatching input/change events back to Shiny. This is display-only;
// manual edits still use the normal numericInput bindings.
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
      if (ownerKey) cell = document.querySelector('.figure-grid-cell[data-figure-key=' + ownerKey + ']');
    }
    if (!cell) return;
    e.preventDefault();
    e.stopPropagation();
    $('.figure-grid-cell').removeClass('selected');
    $(cell).addClass('selected');
    // F1-4d: legend drag selects locally only. Do not send a panel-click
    // roundtrip here; the drag commit carries id/key and becomes canonical.

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

// v3.4.0-alpha1: free-canvas Panel move/resize experiment.
// Row layout remains untouched. Geometry is committed to the same cell
// identity so switching modes does not duplicate Figure content.
(function() {
  var panelDrag = null;

  function figureCanvasScale(cell) {
    var canvas = cell.closest('.figure-preview-canvas');
    if (!canvas) return 1;
    var logicalW = parseFloat(canvas.getAttribute('data-canvas-width')) || canvas.offsetWidth || 1;
    var rect = canvas.getBoundingClientRect();
    var sc = rect.width / logicalW;
    return (isFinite(sc) && sc > 0) ? sc : 1;
  }

  document.addEventListener('pointerdown', function(e) {
    var cell = e.target.closest('.figure-grid-cell[data-figure-id]');
    if (!cell) return;
    var canvas = cell.closest('.figure-preview-canvas');
    if (!canvas || String(canvas.getAttribute('data-layout-mode') || 'row') !== 'free') return;
    if (e.target.closest('.figure-draggable,input,select,button')) return;

    var rect = cell.getBoundingClientRect();
    var resizeZone = (rect.right - e.clientX < 18) && (rect.bottom - e.clientY < 18);
    panelDrag = {
      cell: cell,
      scale: figureCanvasScale(cell),
      mode: resizeZone ? 'panel_resize' : 'panel_move',
      startX: e.clientX,
      startY: e.clientY,
      left: parseFloat(cell.style.left) || 0,
      top: parseFloat(cell.style.top) || 0,
      width: parseFloat(cell.style.width) || cell.offsetWidth,
      height: parseFloat(cell.style.height) || cell.offsetHeight,
      pointerId: e.pointerId
    };
    cell.classList.add('dragging');
    if (cell.setPointerCapture) {
      try { cell.setPointerCapture(e.pointerId); } catch (err) {}
    }
    e.preventDefault();
  }, true);

  document.addEventListener('pointermove', function(e) {
    if (!panelDrag) return;
    var dx = (e.clientX - panelDrag.startX) / panelDrag.scale;
    var dy = (e.clientY - panelDrag.startY) / panelDrag.scale;
    if (panelDrag.mode === 'panel_move') {
      panelDrag.cell.style.left = (panelDrag.left + dx) + 'px';
      panelDrag.cell.style.top = (panelDrag.top + dy) + 'px';
    } else {
      panelDrag.cell.style.width = Math.max(20, panelDrag.width + dx) + 'px';
      panelDrag.cell.style.height = Math.max(20, panelDrag.height + dy) + 'px';
    }
  }, true);

  function finishPanelDrag() {
    if (!panelDrag) return;
    var cell = panelDrag.cell;
    cell.classList.remove('dragging');
    var row = parseInt(cell.getAttribute('data-figure-row'), 10);
    var col = parseInt(cell.getAttribute('data-figure-col'), 10);
    if (isFinite(row) && isFinite(col)) {
      Shiny.setInputValue('figure_free_panel_event', {
        type: panelDrag.mode,
        row: row,
        col: col,
        x: parseFloat(cell.style.left) || 0,
        y: parseFloat(cell.style.top) || 0,
        width: parseFloat(cell.style.width) || cell.offsetWidth,
        height: parseFloat(cell.style.height) || cell.offsetHeight,
        nonce: Date.now()
      }, {priority: 'event'});
    }
    panelDrag = null;
  }

  document.addEventListener('pointerup', finishPanelDrag, true);
  document.addEventListener('pointercancel', finishPanelDrag, true);
})();

// v3.3.57 diagnostic: confirm the stable inline Figure interaction bridge is active.
$(function() {
  try {
    Shiny.setInputValue('figure_interaction_ready', {nonce: Date.now()}, {priority: 'event'});
  } catch (e) {}
});

Shiny.addCustomMessageHandler('open-graph-parameter-section', function(msg) {
  setTimeout(function() {
    if (!msg || !msg.panelId) return;
    var panel = document.getElementById(String(msg.panelId));
    if (!panel) return;
    var wanted = String(msg.section || '').trim();
    var summaries = panel.querySelectorAll('details > summary');
    var target = null;
    for (var i = 0; i < summaries.length; i++) {
      var txt = String(summaries[i].textContent || '').trim();
      if (!wanted || txt === wanted || txt.indexOf(wanted) === 0) {
        target = summaries[i];
        break;
      }
    }
    if (target) {
      var details = target.parentElement;
      if (details && details.tagName && details.tagName.toLowerCase() === 'details') {
        details.open = true;
      }
      try { target.scrollIntoView({behavior:'smooth', block:'start'}); } catch(e) {}
    }
  }, 80);
});

// v3.64.0-lazyui1: the single persistent Editor stays mounted while
// browsing.  A top-level section click promotes selected_graph_id to the
// editing target only when needed.  The first click is consumed by the
// sync transaction; graph-client-edit-ready reopens the requested section
// together with that Graph's session-only fold memory.
$(document).on('click', '#graph_panels .graph-module details.control-section > summary', function(e) {
  var root = $(this).closest('.graph-module')[0];
  if (!root) return;
  var moduleId = String(root.getAttribute('data-graph-module') || '');
  if (!moduleId) return;

  if (moduleId === 'graph_editor_single') {
    var selectedId = String(window.ggplotGuiClientSelectedGraph || '');
    var editingId = String(window.ggplotGuiClientEditingGraph || '');
    var ready = !!window.ggplotGuiClientEditorReady;

    // When the selected Graph already owns a READY Editor this is an ordinary
    // <details> toggle.  Do not interfere with native control interaction.
    if (selectedId && selectedId === editingId && ready) return;

    // Browse mode deliberately exposes only section summaries.  The first
    // click is the explicit activation request for the selected Graph; consume
    // the native toggle so stale controls from the previous owner are never
    // exposed while SYNC/HYDRATING is in flight.
    e.preventDefault();
    e.stopPropagation();
    var details = this.parentElement;
    var sectionKey = details ? String(details.getAttribute('data-ui-section') || '') : '';
    ggplotGuiRequestEditorActivation(selectedId, sectionKey, 'section');
    return false;
  }

  // Legacy per-Graph modules are retained only for compatibility/export.
  Shiny.setInputValue('graph_ui_edit_request', {
    id: moduleId,
    section: String(this.textContent || '').trim(),
    nonce: Date.now()
  }, {priority:'event'});
});

Shiny.addCustomMessageHandler('focus-select-input', function(msg) {
  setTimeout(function() {
    var el = document.getElementById(msg.id);
    if (el) {
      el.focus();
      if (typeof el.select === 'function') el.select();
    }
  }, 40);
});

document.addEventListener('keydown', function(e) {
  if (e.key !== 'Enter') return;

  if (e.target && e.target.id === 'new_graph_name') {
    e.preventDefault();
    Shiny.setInputValue('new_graph_enter', true, {priority:'event'});
  }

  if (e.target && e.target.id === 'rename_graph_text') {
    e.preventDefault();
    Shiny.setInputValue('rename_graph_enter', true, {priority:'event'});
  }
});

// Dimension messages can precede renderUI/plot binding. Keep the latest
// dimensions on the module's persistent DOM, then replay on binding.
window.ggplotGuiApplyPlotScale = function(panel, plot, w, h) {
  if (!panel || !plot || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) {
    return false;
  }

  // The persistent live Graph plot uses the normal module fit behavior.
  plot.style.width = w + 'px';
  plot.style.height = h + 'px';
  plot.setAttribute('data-plot-width', String(w));
  plot.setAttribute('data-plot-height', String(h));
  plot.style.transformOrigin = 'top left';

  var panelRect = panel.getBoundingClientRect();
  var host = panel.parentElement;
  var hostRect = host && host.getBoundingClientRect ? host.getBoundingClientRect() : panelRect;
  if (!isFinite(hostRect.width) || hostRect.width <= 0) {
    plot.style.transform = 'scale(1)';
    panel.style.width = 'min(100%, ' + (w + 26) + 'px)';
    panel.style.maxWidth = (w + 26) + 'px';
    panel.style.height = (h + 26) + 'px';
    return false;
  }

  var availableW = Math.max(1, hostRect.width - 26);
  var availableH = Math.max(300, Math.min(620, window.innerHeight * 0.60));
  var scale = Math.min(1, availableW / w, availableH / h);
  if (!isFinite(scale) || scale <= 0) scale = 1;
  plot.style.transform = 'scale(' + scale + ')';
  var visibleW = Math.max(1, w * scale + 26);
  panel.style.width = 'min(100%, ' + visibleW + 'px)';
  panel.style.maxWidth = visibleW + 'px';
  panel.style.height = (h * scale + 26) + 'px';
  panel.setAttribute('data-display-scale', String(scale));
  return true;
};

window.ggplotGuiApplyVisiblePlotScale = function(module) {
  if (!module || module.offsetParent === null) return false;

  var plot = module.querySelector('[id$=-plot]');
  var panel = module.querySelector('[id$=-plot_panel]');
  if (!plot || !panel) return false;

  var w = Number(
    module.getAttribute('data-device-width') || plot.getAttribute('data-plot-width') ||
    String(plot.style.width || '').replace('px', '')
  );
  var h = Number(
    module.getAttribute('data-device-height') || plot.getAttribute('data-plot-height') ||
    String(plot.style.height || '').replace('px', '')
  );

  return window.ggplotGuiApplyPlotScale(panel, plot, w, h);
};

Shiny.addCustomMessageHandler('set-plot-dimensions', function(msg) {
  var panel = document.getElementById(msg.panelId);
  var plot = document.getElementById(msg.plotId);
  var follow = document.getElementById(msg.followId);
  var anchor = document.getElementById(msg.anchorId);

  var w = Number(msg.width);
  var panelW = Number(msg.panelWidth);
  var h = Number(msg.height);

  var module = document.getElementById(msg.plotId.replace(/-plot$/, ''));
  if (!module) {
    module = document.querySelector('.graph-module[data-graph-module="' + msg.plotId.replace(/-plot$/, '') + '"]');
  }
  if (module && isFinite(w) && isFinite(h)) {
    module.setAttribute('data-device-width', String(w));
    module.setAttribute('data-device-height', String(h));
  }

  if (panel && isFinite(panelW)) {
    panel.style.width = 'min(100%, ' + panelW + 'px)';
    panel.style.maxWidth = panelW + 'px';
  }

  window.ggplotGuiApplyPlotScale(panel, plot, w, h);

  // Do not recreate/move DOM. Refresh sticky geometry only after the
  // existing elements have adopted their new dimensions.
  requestAnimationFrame(function() {
    requestAnimationFrame(function() {
      var module = follow && follow.closest ? follow.closest('.graph-module') : null;
      if (module && typeof window.ggplotGuiUpdatePlotFollow === 'function') {
        window.ggplotGuiUpdatePlotFollow(module);
      } else if (anchor && follow && follow.classList.contains('plot-fixed')) {
        var rect = anchor.getBoundingClientRect();
        follow.style.width = rect.width + 'px';
        follow.style.left = rect.left + 'px';
        var boxH = Math.ceil(follow.getBoundingClientRect().height || follow.offsetHeight || 0);
        if (boxH > 0) anchor.style.minHeight = boxH + 'px';
      }
    });
  });
});

// Shiny events are jQuery events. Native addEventListener does not receive
// shiny:value, and a one-shot custom message may arrive before the DOM.
$(document).on('shiny:bound shiny:value shiny:visualchange', function(event) {
  var module = event.target && event.target.closest ? event.target.closest('.graph-module') : null;
  if (!module) return;
  requestAnimationFrame(function() { window.ggplotGuiApplyVisiblePlotScale(module); });
});




Shiny.addCustomMessageHandler('set-follow-state', function(msg) {
  var el = document.getElementById(msg.id);
  if (el) {
    el.setAttribute('data-follow', msg.value);
    // v3.3.76: restored/duplicated modules can receive sticky_plot after
    // their DOM was already mounted. Apply immediately instead of
    // waiting for the next scroll/style redraw.
    var module = el.closest ? el.closest('.graph-module') : null;
    if (module && typeof window.ggplotGuiUpdatePlotFollow === 'function') {
      requestAnimationFrame(function() { window.ggplotGuiUpdatePlotFollow(module); });
    }
  }
});

// v3.3.75: Graph switching can reveal an already-bound module without a
// new shiny:value event. Recompute scale/sticky geometry explicitly so a
// duplicated Graph follows scroll immediately instead of only after the
// next style/font edit forces a redraw.
Shiny.addCustomMessageHandler('refresh-visible-graph-ui', function(msg) {
  requestAnimationFrame(function() {
    requestAnimationFrame(function() {
      var panel = msg && msg.id ? document.getElementById('panel_' + msg.id) : null;
      var module = panel ? panel.querySelector('.graph-module') : null;
      if (!module) {
        module = document.querySelector('.graph-module-panel:not([style*="display: none"]) .graph-module');
      }
      if (module) {
        if (typeof window.ggplotGuiApplyVisiblePlotScale === 'function') {
          window.ggplotGuiApplyVisiblePlotScale(module);
        }
        if (typeof window.ggplotGuiObserveVisiblePlotFollow === 'function') {
          window.ggplotGuiObserveVisiblePlotFollow();
        }
        if (typeof window.ggplotGuiUpdatePlotFollow === 'function') {
          window.ggplotGuiUpdatePlotFollow(module);
        }
      }
    });
  });
});

(function() {
  function updatePlotFollow(module) {
    if (!module || module.offsetParent === null) return;

    if (typeof window.ggplotGuiApplyVisiblePlotScale === 'function') {
      window.ggplotGuiApplyVisiblePlotScale(module);
    }

    var anchor = module.querySelector('[id$=-plot_anchor]');
    var box = module.querySelector('[id$=-plot_follow]');
    if (!anchor || !box) return;

    var enabled = box.getAttribute('data-follow') === 'true';
    var mobile = window.innerWidth <= 991;

    // Measure full content height without letting the fixed max-height
    // hide the fact that the Graph is larger than the viewport.
    var fullHeight = Math.max(
      box.scrollHeight || 0,
      box.getBoundingClientRect().height || 0
    );
    var availableHeight = Math.max(240, window.innerHeight - 30);
    var oversize = fullHeight > availableHeight;

    // A Graph that cannot fit in the viewport must remain in normal flow.
    // Otherwise the fixed box can cover the header and capture page scroll.
    if (!enabled || mobile || oversize) {
      box.classList.remove('plot-fixed');
      box.style.width = '';
      box.style.left = '';
      box.style.top = '';
      box.style.maxHeight = '';
      box.style.overflowY = '';
      anchor.style.minHeight = '';
      return;
    }

    var rect = anchor.getBoundingClientRect();

    // Sticky only after the natural anchor reaches the viewport top.
    if (rect.top <= 10) {
      box.classList.add('plot-fixed');
      box.style.top = '10px';
      box.style.width = rect.width + 'px';
      box.style.left = rect.left + 'px';

      var h = Math.ceil(
        box.getBoundingClientRect().height ||
        box.offsetHeight ||
        0
      );
      if (h > 0) anchor.style.minHeight = h + 'px';
    } else {
      box.classList.remove('plot-fixed');
      box.style.width = '';
      box.style.left = '';
      box.style.top = '';
      anchor.style.minHeight = '';
    }
  }

  window.ggplotGuiUpdatePlotFollow = updatePlotFollow;

  function clearStalePlotFollow(module) {
    if (!module) return;

    var anchor = module.querySelector('[id$=-plot_anchor]');
    var box = module.querySelector('[id$=-plot_follow]');
    if (!anchor || !box) return;

    var fullHeight = Math.max(
      box.scrollHeight || 0,
      box.getBoundingClientRect().height || 0
    );
    var availableHeight = Math.max(240, window.innerHeight - 30);
    var rect = anchor.getBoundingClientRect();

    if (rect.top > 10 || fullHeight > availableHeight) {
      box.classList.remove('plot-fixed');
      box.style.width = '';
      box.style.left = '';
      box.style.top = '';
      box.style.maxHeight = '';
      box.style.overflowY = '';
      anchor.style.minHeight = '';
    }
  }

  function visibleModules() {
    // Dynamic duplicate panels are mounted after startup. Never assume the
    // first module in DOM is the active one; collect every actually visible
    // module and update each. This also survives brief shinyjs show/hide
    // overlap during Graph switching.
    var out = [];
    var modules = document.querySelectorAll('.graph-module-panel .graph-module');
    for (var i = 0; i < modules.length; i++) {
      var m = modules[i];
      var panel = m.closest ? m.closest('.graph-module-panel') : null;
      if (!panel) continue;
      var cs = window.getComputedStyle ? window.getComputedStyle(panel) : null;
      if (panel.offsetParent !== null && (!cs || (cs.display !== 'none' && cs.visibility !== 'hidden'))) out.push(m);
    }
    return out;
  }

  function visibleModule() {
    var xs = visibleModules();
    return xs.length ? xs[xs.length - 1] : null;
  }

  function updateVisiblePlotFollow() {
    visibleModules().forEach(function(m) { updatePlotFollow(m); });
  }

  document.addEventListener('click', function(e) {
    var module = e.target.closest ? e.target.closest('.graph-module') : null;

    if (module && e.target.id && e.target.id.endsWith('-open_all_sections')) {
      module.querySelectorAll('details.control-section').forEach(function(el) {
        el.open = true;
      });
    }

    if (module && e.target.id && e.target.id.endsWith('-close_all_sections')) {
      module.querySelectorAll('details.control-section').forEach(function(el) {
        el.open = false;
      });
    }

    setTimeout(function() {
      updateVisiblePlotFollow();
    }, 0);
  });

  var plotFollowResizeObserver = null;
  if (window.ResizeObserver) {
    plotFollowResizeObserver = new ResizeObserver(function() {
      requestAnimationFrame(function() {
        updateVisiblePlotFollow();
      });
    });
  }

  function observeVisiblePlotFollow() {
    if (!plotFollowResizeObserver) return;
    plotFollowResizeObserver.disconnect();
    var modules = visibleModules();
    if (!modules.length) return;
    modules.forEach(function(module) {
      var anchor = module.querySelector('[id$=-plot_anchor]');
      var box = module.querySelector('[id$=-plot_follow]');
      var panel = module.querySelector('.plot-panel');
      if (anchor) plotFollowResizeObserver.observe(anchor);
      if (box) plotFollowResizeObserver.observe(box);
      if (panel) plotFollowResizeObserver.observe(panel);
    });
  }
  window.ggplotGuiObserveVisiblePlotFollow = observeVisiblePlotFollow;

  window.addEventListener('scroll', function() {
    updateVisiblePlotFollow();
  }, {passive: true});

  window.addEventListener('resize', function() {
    visibleModules().forEach(function(module) {
      clearStalePlotFollow(module);
      updatePlotFollow(module);

      // Re-apply current Plot geometry using the same proportional scaling
      // path for each visible module. Keep the module reference inside this
      // callback so resize never depends on an implicit/global last module.
      if (typeof window.ggplotGuiApplyVisiblePlotScale === 'function') {
        window.ggplotGuiApplyVisiblePlotScale(module);
      }
    });
  });

  document.addEventListener('shiny:value', function() {
    setTimeout(function() {
      var module = visibleModule();
      clearStalePlotFollow(module);
      observeVisiblePlotFollow();
      updatePlotFollow(module);
    }, 0);
    setTimeout(function() {
      var module = visibleModule();
      clearStalePlotFollow(module);
      updatePlotFollow(module);
    }, 80);
  });

  setTimeout(function() {
    observeVisiblePlotFollow();
    updateVisiblePlotFollow();
  }, 0);

  // ------------------------------------------------------
  // Project overwrite save
  // ------------------------------------------------------
  var projectSaveHandle = null;
  var projectSaveHandleProject = null;


  var saveHandleDbName = 'ggplot_gui_project_handles';
  var saveHandleStoreName = 'handles';
  var saveHandleDbPromise = null;

  function openSaveHandleDb() {
    if (saveHandleDbPromise) return saveHandleDbPromise;

    saveHandleDbPromise = new Promise(function(resolve, reject) {
      if (!window.indexedDB) {
        reject(new Error('IndexedDB unavailable'));
        return;
      }

      var req = indexedDB.open(saveHandleDbName, 2);

      req.onupgradeneeded = function(ev) {
        var db = ev.target.result;
        if (!db.objectStoreNames.contains(saveHandleStoreName)) {
          db.createObjectStore(saveHandleStoreName, {keyPath: 'project'});
        }
      };

      req.onsuccess = function(ev) {
        resolve(ev.target.result);
      };

      req.onerror = function() {
        reject(req.error || new Error('IndexedDB open failed'));
      };
    });

    return saveHandleDbPromise;
  }

  async function savePersistentHandle(project, handle) {
    var db = await openSaveHandleDb();
    return await new Promise(function(resolve, reject) {
      var tx = db.transaction(saveHandleStoreName, 'readwrite');
      tx.objectStore(saveHandleStoreName).put({
        project: project,
        handle: handle,
        fileName: handle && handle.name ? handle.name : ''
      });
      tx.oncomplete = function() { resolve(); };
      tx.onerror = function() { reject(tx.error || new Error('保存先の記憶に失敗しました。')); };
    });
  }

  async function loadPersistentHandle(project) {
    var db = await openSaveHandleDb();
    return await new Promise(function(resolve, reject) {
      var tx = db.transaction(saveHandleStoreName, 'readonly');
      var req = tx.objectStore(saveHandleStoreName).get(project);
      req.onsuccess = function() {
        resolve(req.result || null);
      };
      req.onerror = function() {
        reject(req.error || new Error('保存先の読込に失敗しました。'));
      };
    });
  }

  async function deletePersistentHandle(project) {
    try {
      var db = await openSaveHandleDb();
      await new Promise(function(resolve, reject) {
        var tx = db.transaction(saveHandleStoreName, 'readwrite');
        tx.objectStore(saveHandleStoreName).delete(project);
        tx.oncomplete = function() { resolve(); };
        tx.onerror = function() { reject(tx.error); };
      });
    } catch (e) {
      // Best effort only.
    }
  }

  function setProjectNameInputValue(name) {
    if (!name) return;

    var el = document.getElementById('project_name');
    if (!el) return;

    if (el.value !== name) {
      el.value = name;

      try {
        el.dispatchEvent(new Event('input', {bubbles: true}));
        el.dispatchEvent(new Event('change', {bubbles: true}));
      } catch (e) {}
    }

    // Explicitly synchronize the Shiny input as well.
    if (window.Shiny) {
      Shiny.setInputValue(
        'project_name',
        name,
        {priority: 'event'}
      );
    }
  }

  function updateSaveDestinationStatus(text) {
    var el = document.getElementById('project-save-destination-status');
    if (el) el.textContent = text || '';
  }




  // 「保存先を記憶する」は通常のShiny bindingに加え、明示的にも通知する。
  document.addEventListener('change', function(ev) {
    var target = ev.target;
    if (!target || !window.Shiny) return;
    if (target.id === 'remember_project_save_destination') {
      Shiny.setInputValue(
        'project_remember_manual_state',
        {value: !!target.checked, nonce: Date.now()},
        {priority: 'event'}
      );
    }
  }, true);

  function reportSaveDestinationAvailable(available, projectKey, fileName) {
    if (!window.Shiny) return;

    Shiny.setInputValue(
      'project_save_destination_available',
      {
        available: !!available,
        projectKey: projectKey || '',
        fileName: fileName || '',
        nonce: Date.now()
      },
      {priority: 'event'}
    );
  }


  async function ensureHandlePermission(handle) {
    if (!handle) return false;

    try {
      var q = await handle.queryPermission({mode: 'readwrite'});
      if (q === 'granted') return true;

      var r = await handle.requestPermission({mode: 'readwrite'});
      return r === 'granted';
    } catch (e) {
      return false;
    }
  }

  async function projectFileHandleStillExists(handle) {
    if (!handle) return false;
    try {
      // getFile() must succeed for an existing file handle.
      // If the file was moved/deleted/renamed outside the app,
      // Chromium typically throws NotFoundError here.
      var f = await handle.getFile();
      return !!f;
    } catch (e) {
      return false;
    }
  }

  async function validateProjectBlob(blob) {
    if (!blob || blob.size < 8) {
      throw new Error('Project保存データが空、または短すぎます。');
    }

    // v3.3.69: new Project saves are .ggplotpack ZIP containers.
    // Accept the standard PK signatures used by ZIP archives and reject
    // accidental HTML/error payloads before overwriting an existing file.
    var head = new Uint8Array(await blob.slice(0, 4).arrayBuffer());
    var isZip = head.length >= 4 && head[0] === 0x50 && head[1] === 0x4b &&
      ((head[2] === 0x03 && head[3] === 0x04) ||
       (head[2] === 0x05 && head[3] === 0x06) ||
       (head[2] === 0x07 && head[3] === 0x08));
    if (!isZip) {
      throw new Error(
        'Project保存データがggplotpack(ZIP)形式ではないため、上書きを中止しました。'
      );
    }

    return blob;
  }

  async function waitForProjectDownloadHref(linkId) {
    for (var i = 0; i < 20; i++) {
      var link = document.getElementById(linkId);
      if (link && link.href) return link.href;
      await new Promise(function(resolve) { setTimeout(resolve, 100); });
    }
    throw new Error('Project保存データを準備できませんでした。');
  }

  async function fetchProjectBlob(linkId) {
    var baseHref = await waitForProjectDownloadHref(linkId);

    // Cache-bust every save. Hidden Shiny download URLs can otherwise
    // be reused by the browser even though the Project state changed.
    var sep = baseHref.indexOf('?') >= 0 ? '&' : '?';
    var url = baseHref + sep + '_ggplotproj_ts=' + Date.now();

    var response = await fetch(url, {
      method: 'GET',
      credentials: 'same-origin',
      cache: 'no-store',
      headers: {'Accept': 'application/octet-stream'}
    });

    if (!response.ok) {
      throw new Error(
        'Project保存データの取得に失敗しました（HTTP ' +
        response.status + '）。'
      );
    }

    var blob = await response.blob();
    return await validateProjectBlob(blob);
  }

  async function chooseProjectSaveHandle(filename) {
    return await window.showSaveFilePicker({
      suggestedName: filename || 'project.ggplotpack',
      types: [{
        description: 'ggplot GUI Project package',
        accept: {'application/zip': ['.ggplotpack']}
      }]
    });
  }


  if (window.Shiny) {
    var pendingProjectSaveAsHandle = null;
    var pendingProjectSaveAsMeta = null;

    Shiny.addCustomMessageHandler('prepare-project-save-as', async function(msg) {
      var oldProjectKey = msg.oldProjectKey || '';
      var remember = !!msg.remember;

      try {
        if (!window.showSaveFilePicker) {
          var fallbackLink = document.getElementById(msg.fallbackLinkId);
          if (fallbackLink) fallbackLink.click();

          Shiny.setInputValue(
            'project_save_as_status',
            {
              ok: false,
              fallback: true,
              projectKey: (msg.projectKey || 'project'),
              message: 'このブラウザでは保存先を直接保持できないため、通常のダウンロード保存を開始しました。',
              nonce: Date.now()
            },
            {priority: 'event'}
          );
          return;
        }

        var handle = await chooseProjectSaveHandle(msg.filename);
        var selectedFileName = (handle && handle.name)
          ? handle.name
          : (msg.filename || 'MyProject.ggplotpack');

        var selectedProjectName = selectedFileName.replace(/\.(?:ggplotpack|ggplotproj)$/i, '');
        if (!selectedProjectName) {
          selectedProjectName = msg.projectName || 'MyProject';
        }

        var selectedProjectKey = msg.projectKey || 'project';

        // Reflect the actual chosen filename immediately.
        setProjectNameInputValue(selectedProjectName);

        pendingProjectSaveAsHandle = handle;
        pendingProjectSaveAsMeta = {
          projectName: selectedProjectName,
          projectKey: selectedProjectKey,
          oldProjectKey: oldProjectKey,
          remember: remember
        };

        // Tell R the final name first. R then regenerates the payload
        // with this Project name and asks us to commit it.
        Shiny.setInputValue(
          'project_save_as_target',
          {
            projectName: selectedProjectName,
            projectKey: selectedProjectKey,
            oldProjectKey: oldProjectKey,
            remember: remember,
            nonce: Date.now()
          },
          {priority: 'event'}
        );

      } catch (err) {
        if (err && err.name === 'AbortError') {
          Shiny.setInputValue(
            'project_save_as_status',
            {ok: false, fallback: false, cancelled: true, nonce: Date.now()},
            {priority: 'event'}
          );
          return;
        }

        Shiny.setInputValue(
          'project_save_as_status',
          {
            ok: false,
            fallback: false,
            message: (err && err.message) ? err.message : String(err),
            nonce: Date.now()
          },
          {priority: 'event'}
        );
      }
    });

    Shiny.addCustomMessageHandler('commit-project-save-as', async function(msg) {
      var handle = pendingProjectSaveAsHandle;
      var meta = pendingProjectSaveAsMeta || {};
      var projectKey = msg.projectKey || meta.projectKey || msg.projectName || 'project';
      var oldProjectKey = msg.oldProjectKey || meta.oldProjectKey || '';
      var remember = !!msg.remember;

      try {
        if (!handle) {
          throw new Error('保存先情報が失われたため、もう一度「名前を付けて保存」を実行してください。');
        }

        var blob = await fetchProjectBlob(msg.linkId);
        var writable = await handle.createWritable();
        await writable.write(blob);
        await writable.close();

        projectSaveHandle = handle;
        projectSaveHandleProject = projectKey;

        if (remember) {
          try {
            // Save As is a new Project UUID. Keep the original Project's
            // remembered handle intact and store this copy separately.
            await savePersistentHandle(projectKey, handle);

            updateSaveDestinationStatus(
              '保存先を記憶中: ' + (handle.name || msg.filename)
            );
            reportSaveDestinationAvailable(
              true,
              projectKey,
              handle.name || msg.filename
            );
          } catch (e) {
            updateSaveDestinationStatus(
              'Projectは保存しましたが、ブラウザに保存先を記憶できませんでした。'
            );
            reportSaveDestinationAvailable(false, projectKey, '');
          }
        } else {
          // Remember is OFF for the new copy: do not disturb the original
          // Project UUID's persisted destination.
          await deletePersistentHandle(projectKey);

          updateSaveDestinationStatus(
            'このセッションの保存先: ' + (handle.name || msg.filename)
          );
          reportSaveDestinationAvailable(false, projectKey, '');
        }
        setProjectNameInputValue(
          msg.projectName || meta.projectName || ''
        );

        Shiny.setInputValue(
          'project_save_as_status',
          {
            ok: true,
            fallback: false,
            name: handle.name || msg.filename,
            projectName: msg.projectName || meta.projectName || '',
            projectKey: projectKey,
            remembered: remember,
            nonce: Date.now()
          },
          {priority: 'event'}
        );

      } catch (err) {
        Shiny.setInputValue(
          'project_save_as_status',
          {
            ok: false,
            fallback: false,
            message: (err && err.message) ? err.message : String(err),
            nonce: Date.now()
          },
          {priority: 'event'}
        );
      } finally {
        pendingProjectSaveAsHandle = null;
        pendingProjectSaveAsMeta = null;
      }
    });

    Shiny.addCustomMessageHandler('overwrite-project-file', async function(msg) {
      var projectKey = msg.projectKey || msg.filename || 'project';
      var remember = !!msg.remember;

      try {
        // Chromium系以外では通常ダウンロードへフォールバック。
        if (!window.showSaveFilePicker) {
          var fallbackLink = document.getElementById(msg.linkId);
          if (fallbackLink) fallbackLink.click();

          Shiny.setInputValue(
            'project_overwrite_status',
            {
              ok: false,
              fallback: true,
              message: 'このブラウザでは直接上書きできないため、通常の保存を開始しました。',
              nonce: Date.now()
            },
            {priority: 'event'}
          );
          return;
        }

        var handle = null;

        // Current page/session handle can only be reused for the same Project.
        if (projectSaveHandle && projectSaveHandleProject === projectKey) {
          var sessionHandleIsPack = /\.ggplotpack$/i.test(projectSaveHandle.name || '');
          if (
            sessionHandleIsPack &&
            await ensureHandlePermission(projectSaveHandle) &&
            await projectFileHandleStillExists(projectSaveHandle)
          ) {
            handle = projectSaveHandle;
          } else {
            projectSaveHandle = null;
            projectSaveHandleProject = null;
          }
        }

        // If requested, try persistent browser storage next.
        if (!handle && remember) {
          try {
            var saved = await loadPersistentHandle(projectKey);

            if (
              saved &&
              saved.handle &&
              /\.ggplotpack$/i.test(saved.handle.name || saved.fileName || '') &&
              await ensureHandlePermission(saved.handle) &&
              await projectFileHandleStillExists(saved.handle)
            ) {
              handle = saved.handle;
              projectSaveHandle = handle;
              projectSaveHandleProject = projectKey;
              updateSaveDestinationStatus(
                '保存先を記憶中: ' + (saved.fileName || handle.name || msg.filename)
              );
            } else if (saved) {
              await deletePersistentHandle(projectKey);
              updateSaveDestinationStatus(
                'Projectファイルが移動・削除・名前変更された可能性があるため、保存先を再選択します。'
              );
            }
          } catch (e) {
            // IndexedDB failure should not block saving.
          }
        }

        // No usable target: ask user again.
        if (!handle) {
          handle = await chooseProjectSaveHandle(msg.filename);
          projectSaveHandle = handle;
          projectSaveHandleProject = projectKey;

          if (remember) {
            try {
              await savePersistentHandle(projectKey, handle);
              updateSaveDestinationStatus(
                '保存先を記憶中: ' + (handle.name || msg.filename)
              );
            } catch (e) {
              updateSaveDestinationStatus(
                '保存はできますが、ブラウザに保存先を記憶できませんでした。'
              );
            }
          } else {
            updateSaveDestinationStatus(
              'このセッションの保存先: ' + (handle.name || msg.filename)
            );
          }
        }

        var blob = await fetchProjectBlob(msg.linkId);

        // The file may have been moved/deleted after permission checking.
        // Never recreate an old-path file from a stale remembered handle.
        try {
          if (!await projectFileHandleStillExists(handle)) {
            var staleErr = new Error(
              'Projectファイルが見つからないため、保存先を再選択します。'
            );
            staleErr.name = 'StaleProjectHandleError';
            throw staleErr;
          }

          var writable = await handle.createWritable();
          await writable.write(blob);
          await writable.close();
        } catch (writeErr) {
          // Forget stale handle and ask once more.
          projectSaveHandle = null;
          projectSaveHandleProject = null;
          if (remember) {
            await deletePersistentHandle(projectKey);
          }

          updateSaveDestinationStatus(
            'Projectファイルが移動・削除・名前変更された可能性があるため、保存先を再選択します。'
          );

          handle = await chooseProjectSaveHandle(msg.filename);
          projectSaveHandle = handle;
          projectSaveHandleProject = projectKey;

          if (remember) {
            try {
              await savePersistentHandle(projectKey, handle);
              updateSaveDestinationStatus(
                '保存先を記憶中: ' + (handle.name || msg.filename)
              );
            } catch (e) {}
          } else {
            updateSaveDestinationStatus(
              'このセッションの保存先: ' + (handle.name || msg.filename)
            );
          }

          var writable2 = await handle.createWritable();
          await writable2.write(blob);
          await writable2.close();
        }
        reportSaveDestinationAvailable(
          remember,
          projectKey,
          handle.name || msg.filename
        );

        Shiny.setInputValue(
          'project_overwrite_status',
          {
            ok: true,
            fallback: false,
            name: handle.name || msg.filename,
            remembered: remember,
            nonce: Date.now()
          },
          {priority: 'event'}
        );

      } catch (err) {
        if (err && err.name === 'AbortError') return;

        Shiny.setInputValue(
          'project_overwrite_status',
          {
            ok: false,
            fallback: false,
            message: (err && err.message) ? err.message : String(err),
            nonce: Date.now()
          },
          {priority: 'event'}
        );
      }
    });

    // Checkbox OFF: keep session handle, but remove persistent copy
    // for this Project so future app sessions do not reuse it.
    Shiny.addCustomMessageHandler('forget-project-save-destination', async function(msg) {
      var projectKey = msg.projectKey || 'project';
      await deletePersistentHandle(projectKey);
      reportSaveDestinationAvailable(false, projectKey, '');

      if (projectSaveHandleProject === projectKey) {
        updateSaveDestinationStatus(
          projectSaveHandle
            ? '保存先の記憶を解除しました（このセッション中は現在の保存先を使用します）。'
            : ''
        );
      }
    });

    Shiny.addCustomMessageHandler('migrate-project-save-destination', async function(msg) {
      var oldKey = msg.oldKey || '';
      var newKey = msg.newKey || '';
      if (!oldKey || !newKey || oldKey === newKey) return;

      try {
        var oldSaved = await loadPersistentHandle(oldKey);
        if (oldSaved && oldSaved.handle) {
          await savePersistentHandle(newKey, oldSaved.handle);
          await deletePersistentHandle(oldKey);
          projectSaveHandle = oldSaved.handle;
          projectSaveHandleProject = newKey;
          updateSaveDestinationStatus(
            '旧Projectの保存先をProject ID方式へ移行しました: ' +
            (oldSaved.fileName || oldSaved.handle.name || '')
          );
          var permission = 'prompt';
          try {
            permission = await oldSaved.handle.queryPermission({mode: 'readwrite'});
          } catch (e) { permission = 'denied'; }
          reportSaveDestinationAvailable(
            permission === 'granted', newKey,
            oldSaved.fileName || oldSaved.handle.name || ''
          );
          return;
        }
      } catch (e) {}

      // No old remembered handle: continue with normal UUID lookup.
      try {
        var saved = await loadPersistentHandle(newKey);
        reportSaveDestinationAvailable(!!(saved && saved.handle), newKey,
          saved ? (saved.fileName || '') : '');
      } catch (e) {
        reportSaveDestinationAvailable(false, newKey, '');
      }
    });

    Shiny.addCustomMessageHandler('check-project-save-destination', async function(msg) {
      var projectKey = msg.projectKey || 'project';
      if (!msg.remember) {
        updateSaveDestinationStatus('');
        return;
      }

      try {
        var saved = await loadPersistentHandle(projectKey);
        if (saved && saved.handle) {
          var savedName = saved.fileName || saved.handle.name || '';
          updateSaveDestinationStatus(
            '保存先を記憶中: ' + savedName
          );

          var permission = 'prompt';
          try {
            permission = await saved.handle.queryPermission({mode: 'readwrite'});
          } catch (e) {
            permission = 'denied';
          }

          if (permission === 'granted') {
            projectSaveHandle = saved.handle;
            projectSaveHandleProject = projectKey;
            reportSaveDestinationAvailable(true, projectKey, savedName);
          } else {
            // Keep the remembered handle. A manual overwrite provides
            // the user gesture required to re-confirm write permission.
            reportSaveDestinationAvailable(false, projectKey, savedName);
            updateSaveDestinationStatus(
              '保存先は記憶済み: ' + savedName +
              '（上書き保存時に権限を再確認します）'
            );
          }
        } else {
          updateSaveDestinationStatus(
            '保存先はまだ未設定です。最初の上書き保存時に選択します。'
          );
          reportSaveDestinationAvailable(false, projectKey, '');
        }
      } catch (e) {
        updateSaveDestinationStatus(
          '保存先はまだ未設定です。最初の上書き保存時に選択します。'
        );
        reportSaveDestinationAvailable(false, projectKey, '');
      }
    });


    Shiny.addCustomMessageHandler('set-project-name-input', function(msg) {
      if (!msg) return;
      setProjectNameInputValue(msg.name || '');
    });

  

    function setProjectUiInert(locked) {
      var root = document.querySelector('body > .container-fluid');
      if (!root) return;
      Array.prototype.forEach.call(root.children, function(el) {
        if (el && el.id === 'project_load_overlay') return;
        if (locked) {
          el.setAttribute('inert', '');
        } else {
          el.removeAttribute('inert');
        }
      });
    }

    Shiny.addCustomMessageHandler('project-load-overlay', function(msg) {
      var overlay = document.getElementById('project_load_overlay');
      if (!overlay) return;
      var mode = String((msg && msg.mode) || 'loading');
      var message = String((msg && msg.message) || '');
      var title = overlay.querySelector('.project-load-title');
      var body = overlay.querySelector('.project-load-message');
      var progressWrap = overlay.querySelector('.project-load-progress-wrap');
      var progressBar = overlay.querySelector('.project-load-progress-bar');
      var progressText = overlay.querySelector('.project-load-progress-text');

      if (mode === 'hidden') {
        overlay.classList.remove('visible', 'failed');
        overlay.setAttribute('aria-hidden', 'true');
        setProjectUiInert(false);
        return;
      }

      if (document.activeElement && typeof document.activeElement.blur === 'function') {
        try { document.activeElement.blur(); } catch (e) {}
      }
      overlay.classList.add('visible');
      overlay.classList.toggle('failed', mode === 'failed');
      overlay.setAttribute('aria-hidden', 'false');
      if (title) title.textContent = mode === 'failed' ? 'Projectの読み込みに失敗しました' : 'Projectを準備しています';
      if (body) body.textContent = message;

      if (mode !== 'failed' && progressWrap && progressBar && progressText) {
        var total = Number(msg && msg.total);
        var ready = Number(msg && msg.ready);
        var current = Number(msg && msg.current);
        var pct = Number(msg && msg.percent);
        var determinate = Number.isFinite(total) && total > 0 && Number.isFinite(pct);
        progressWrap.classList.toggle('indeterminate', !determinate);
        if (determinate) {
          pct = Math.max(0, Math.min(100, pct));
          progressBar.style.width = pct + '%';
          progressBar.style.transform = 'none';
          progressBar.setAttribute('aria-valuenow', String(pct));
          progressText.textContent = Number.isFinite(current) && current > 0
            ? ('Graph ' + current + ' / ' + total + '　' + pct + '%')
            : (ready + ' / ' + total + ' READY　' + pct + '%');
        } else {
          progressBar.style.width = '';
          progressBar.style.transform = '';
          progressBar.removeAttribute('aria-valuenow');
          progressText.textContent = 'Projectファイルを確認しています…';
        }
      }
      setProjectUiInert(true);
    });

    // Lock immediately when the user chooses a Project file, before the
    // upload reaches the server. This closes the short window in which
    // another UI action could otherwise be issued during file transfer.
    $(document).on('change', '#upload_project_all', function() {
      if (!this.files || !this.files.length) return;
      var overlay = document.getElementById('project_load_overlay');
      if (!overlay) return;
      var title = overlay.querySelector('.project-load-title');
      var body = overlay.querySelector('.project-load-message');
      var progressWrap = overlay.querySelector('.project-load-progress-wrap');
      var progressBar = overlay.querySelector('.project-load-progress-bar');
      var progressText = overlay.querySelector('.project-load-progress-text');
      if (document.activeElement && typeof document.activeElement.blur === 'function') {
        try { document.activeElement.blur(); } catch (e) {}
      }
      overlay.classList.add('visible');
      overlay.classList.remove('failed');
      overlay.setAttribute('aria-hidden', 'false');
      if (title) title.textContent = 'Projectを準備しています';
      if (body) body.textContent = 'Projectファイルを読み込んでいます…';
      if (progressWrap) progressWrap.classList.add('indeterminate');
      if (progressBar) {
        progressBar.style.width = '';
        progressBar.style.transform = '';
        progressBar.removeAttribute('aria-valuenow');
      }
      if (progressText) progressText.textContent = 'Projectファイルを確認しています…';
      // Do not make the app inert from the raw file-input change event.
      // Shiny still has to consume/upload the selected file at this point;
      // disabling the surrounding UI here can race the fileInput binding
      // and leave the client overlay visible without ever delivering
      // upload_project_all to the server.  The server calls
      // begin_project_load_lock() as soon as the upload arrives, and its
      // project-load-overlay message applies inert at that safe point.
    });

    Shiny.addCustomMessageHandler('reset-project-save-handle', function(msg) {
      projectSaveHandle = null;
      projectSaveHandleProject = null;
      reportSaveDestinationAvailable(false, '', '');
      updateSaveDestinationStatus('');
    });
  }
})();
    
