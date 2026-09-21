
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

// v3.51 Graph Preview mode switch.  A persisted SVG stays mounted as a
// display cache; it is never the canonical state.  The stage changes
// from cached -> live only when the browser confirms that the Shiny plot
// image itself has loaded.  No MutationObserver, polling, or delay is
// involved in this transition.
function setGraphPreviewStageMode(stage, mode, reason) {
  if (!stage || (mode !== 'cached' && mode !== 'live')) return false;
  var wasCached = stage.classList.contains('graph-preview-mode-cached');
  var wasLive = stage.classList.contains('graph-preview-mode-live');
  if ((mode === 'cached' && wasCached) || (mode === 'live' && wasLive)) return false;

  stage.classList.toggle('graph-preview-mode-cached', mode === 'cached');
  stage.classList.toggle('graph-preview-mode-live', mode === 'live');
  stage.setAttribute('data-preview-mode', mode);

  var cached = stage.querySelector('.graph-preview-cached-layer');
  var live = stage.querySelector('.graph-preview-live-layer');
  if (cached) cached.setAttribute('aria-hidden', mode === 'live' ? 'true' : 'false');
  if (live) live.setAttribute('aria-hidden', mode === 'live' ? 'false' : 'true');

  var ackId = stage.getAttribute('data-preview-ack-id') || '';
  if (window.Shiny && ackId) {
    Shiny.setInputValue(ackId, {
      mode: mode,
      reason: reason || '',
      graphId: stage.getAttribute('data-graph-id') || '',
      cachedExists: !!cached,
      liveExists: !!live,
      nonce: Date.now()
    }, {priority: 'event'});
  }
  return true;
}

// v3.73.1 Editor-first Graph workspace. Cached SVG remains a latency/failure
// layer, while Graph tab clicks immediately retarget the one persistent Editor.
window.ggplotGuiClientPreviewStore = window.ggplotGuiClientPreviewStore || {};
window.ggplotGuiClientSelectedGraph = window.ggplotGuiClientSelectedGraph || '';
window.ggplotGuiClientEditingGraph = window.ggplotGuiClientEditingGraph || '';
window.ggplotGuiClientEditingGraphName = window.ggplotGuiClientEditingGraphName || '';
window.ggplotGuiClientEditorReady = window.ggplotGuiClientEditorReady || false;

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

// Persist only trusted user panel toggles. Programmatic replay/restoration must
// not echo back into GraphState as a new user edit.
document.addEventListener('toggle', function(ev) {
  var el = ev && ev.target;
  if (!el || el.tagName !== 'DETAILS' || !ev.isTrusted) return;
  if (!el.matches('details.control-section, details.control-subsection')) return;
  var root = ggplotGuiEditorModuleRoot();
  if (!root || !root.contains(el)) return;
  ggplotGuiPublishEditorUiState(window.ggplotGuiClientEditingGraph || '', 'user-toggle');
}, true);

function ggplotGuiCloseEditorSections() {
  var root = ggplotGuiEditorModuleRoot();
  if (!root) return false;
  root.querySelectorAll('details.control-section').forEach(function(el) { el.open = false; });
  return true;
}

function ggplotGuiUpdateDormantEditorClass(selectedId) {
  var panels = document.getElementById('graph_panels');
  if (!panels) return;
  selectedId = String(selectedId || window.ggplotGuiClientSelectedGraph || '');
  var rec = window.ggplotGuiClientPreviewStore[selectedId] || null;
  var noPreview = !rec || !String(rec.svg || '').trim();
  var noReadyOwner = !window.ggplotGuiClientEditorReady && !String(window.ggplotGuiClientEditingGraph || '');
  panels.classList.toggle('client-pristine-no-preview', !!(noReadyOwner && noPreview));
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
  // Record it immediately so an overlapping Graph Preview target switch cannot
  // resurrect a cached Plot from that Graph's historical tab state.
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
  var selectedRec = window.ggplotGuiClientPreviewStore[selectedId] || null;
  var selectedName = selectedRec ? String(selectedRec.name || selectedId) : selectedId;
  var editingId = String(window.ggplotGuiClientEditingGraph || '');
  var editingName = String(window.ggplotGuiClientEditingGraphName || editingId || '');
  var nm = document.getElementById('graph_editor_shell_name');
  var st = document.getElementById('graph_editor_shell_state');
  var btn = document.getElementById('graph_editor_shell_edit');
  if (nm) nm.textContent = (selectedId && selectedId !== editingId) ? selectedName : (editingId ? editingName : (selectedName || 'Graph未選択'));
  if (st) {
    if (stateOverride) st.textContent = String(stateOverride);
    else if (editingId && selectedId && editingId !== selectedId) st.textContent = '選択: ' + selectedName;
    else if (editingId) st.textContent = '編集中: ' + editingName;
    else st.textContent = selectedId ? '選択: ' + selectedName : 'Graph未選択';
  }
  if (btn) btn.textContent = '編集中';
}

function ggplotGuiSetBrowseWorkspaceLayout(active) {
  var body = document.getElementById('graph_workspace_body');
  if (!body) return;
  body.classList.toggle('client-browse-layout', !!active);
}

// v3.73.2.19: the singleton Editor DOM is created once at bootstrap. Normal
// Graph selection, New/Duplicate, and Project load only overwrite saved values.
// Keep controls visible and mask only the stale live plot until the new image is
// published. There is no Graph-side hydration overlay after bootstrap.
function ggplotGuiSetLivePlotSwitchPending(active) {
  var anchor = document.getElementById('graph_editor_single-preview_anchor');
  if (anchor) anchor.classList.toggle('graph-live-replay-pending', !!active);
}

function ggplotGuiPrepareReplayWorkspace(id) {
  id = String(id || window.ggplotGuiClientSelectedGraph || '');
  ggplotGuiRevealEditorWorkspace(id);
  ggplotGuiSetLivePlotSwitchPending(true);
  return true;
}


function ggplotGuiRevealEditorWorkspace(id) {
  id = String(id || window.ggplotGuiClientSelectedGraph || '');
  var browser = document.getElementById('graph_client_browser');
  var panels = document.getElementById('graph_panels');
  var editingPanel = document.getElementById('panel_graph_editor_single');
  if (browser) browser.classList.remove('client-browse-active');
  if (panels) {
    panels.classList.remove('client-browse-hidden');
    panels.classList.remove('client-pristine-no-preview');
  }
  ggplotGuiSetBrowseWorkspaceLayout(false);
  if (editingPanel) editingPanel.style.display = '';
  if (id) window.ggplotGuiClientSelectedGraph = id;
  return true;
}


function ggplotGuiClientPreviewScale() {
  var browser = document.getElementById('graph_client_browser');
  var viewport = document.getElementById('graph_client_preview_viewport');
  var canvas = document.getElementById('graph_client_preview_canvas');
  if (!browser || !viewport || !canvas || !browser.classList.contains('client-browse-active')) return;
  var id = String(window.ggplotGuiClientSelectedGraph || '');
  var rec = window.ggplotGuiClientPreviewStore[id];
  if (!rec) return;
  var w = Number(rec.width) || 600, h = Number(rec.height) || 600;
  var aw = Math.max(1, Math.min(760, viewport.clientWidth || 760));
  var ah = Math.max(1, Math.min(620, (window.innerHeight || 800) * 0.68));
  var scale = Math.min(1, aw / w, ah / h);
  if (!isFinite(scale) || scale <= 0) scale = 1;
  canvas.style.width = w + 'px';
  canvas.style.height = h + 'px';
  canvas.style.transform = 'scale(' + scale + ')';
  canvas.style.transformOrigin = 'top center';
  viewport.style.height = Math.max(320, Math.ceil(h * scale) + 8) + 'px';
}

window.ggplotGuiBrowseGraph = function(id) {
  id = String(id || '');
  var rec = window.ggplotGuiClientPreviewStore[id];
  if (!id || !rec) return false;
  var previousSelected = String(window.ggplotGuiClientSelectedGraph || '');
  var editingId = String(window.ggplotGuiClientEditingGraph || '');
  var editingPanel = document.getElementById('panel_graph_editor_single');

  window.ggplotGuiClientSelectedGraph = id;
  document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
    btn.classList.toggle('client-selected', String(btn.getAttribute('data-graph-id') || '') === id);
  });

  // Editor-first workspace: selecting a Graph is itself the edit-target change.
  // Preserve the outgoing Graph's fold memory, keep the singleton Editor DOM
  // measurable, and start synchronization immediately. There is no browse-only
  // mode and no second explicit Edit action.
  if (editingId && window.ggplotGuiClientEditorReady && previousSelected === editingId && id !== editingId) {
    ggplotGuiCaptureEditorUiState(editingId);
  }

  // Same READY owner: ordinary selection acknowledgement only.
  if (editingId && editingId === id && editingPanel && window.ggplotGuiClientEditorReady) {
    ggplotGuiRevealEditorWorkspace(id);
    ggplotGuiUpdateEditorShell(id);
    if (window.Shiny) {
      Shiny.setInputValue('graph_client_selected', id, {priority:'event'});
      Shiny.setInputValue('graph_client_mode', 'edit', {priority:'event'});
    }
    return false;
  }

  window.ggplotGuiClientEditorReady = false;
  ggplotGuiPrepareReplayWorkspace(id);
  ggplotGuiUpdateEditorShell(id);
  if (window.Shiny) {
    Shiny.setInputValue('graph_client_selected', id, {priority:'event'});
    Shiny.setInputValue('graph_client_mode', 'edit-pending', {priority:'event'});
  }
  return ggplotGuiRequestEditorActivation(id, '', 'graph-select');
};

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

  var status = document.getElementById('graph_client_browser_status');
  if (status) status.textContent = '';
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
    btn.classList.toggle('client-selected', String(btn.getAttribute('data-graph-id') || '') === id);
  });
  if (window.Shiny) {
    Shiny.setInputValue('graph_client_selected', id, {priority:'event'});
    Shiny.setInputValue('graph_client_mode', 'edit-pending', {priority:'event'});
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

Shiny.addCustomMessageHandler('graph-client-preview-catalog', function(msg) {
  msg = msg || {};
  var entries = Array.isArray(msg.entries) ? msg.entries : [];
  var freshStore = {};
  if (['project-cache-first','project-editor-first','project-state-first'].indexOf(String(msg.reason || '')) >= 0) {
    window.ggplotGuiGraphEditorUiState = {};
    window.ggplotGuiPendingEditorActivation = null;
  }
  entries.forEach(function(rec) {
    if (!rec || !rec.id) return;
    freshStore[String(rec.id)] = rec;
  });
  window.ggplotGuiClientPreviewStore = freshStore;
  Object.keys(window.ggplotGuiGraphEditorUiState || {}).forEach(function(id) {
    if (!freshStore[id]) delete window.ggplotGuiGraphEditorUiState[id];
  });
  var pendingActivation = window.ggplotGuiPendingEditorActivation;
  if (pendingActivation && !freshStore[String(pendingActivation.id || '')]) {
    window.ggplotGuiPendingEditorActivation = null;
  }
  window.ggplotGuiClientEditingGraph = String(msg.editing || '');
  window.ggplotGuiClientEditingGraphName = String(msg.editingName || msg.editing || '');
  var selected = String(msg.selected || window.ggplotGuiClientSelectedGraph || '');
  if (selected) {
    window.ggplotGuiClientSelectedGraph = selected;
    document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
      btn.classList.toggle('client-selected', String(btn.getAttribute('data-graph-id') || '') === selected);
    });
    ggplotGuiUpdateEditorShell(selected);
  } else {
    ggplotGuiUpdateEditorShell(window.ggplotGuiClientSelectedGraph || '');
  }
  if (!!msg.enterBrowse && selected && typeof window.ggplotGuiBrowseGraph === 'function') {
    window.ggplotGuiBrowseGraph(selected);
  }
});

Shiny.addCustomMessageHandler('graph-client-edit-begin', function(msg) {
  var id = String((msg || {}).id || '');
  if (id) {
    var previousEditorId = String(window.ggplotGuiClientEditingGraph || '');
    if (previousEditorId && previousEditorId !== id) {
      ggplotGuiPublishEditorUiState(previousEditorId, 'switch-begin');
    }
    ggplotGuiPrepareReplayWorkspace(id);
    window.ggplotGuiClientEditorReady = false;
    window.ggplotGuiClientSelectedGraph = id;
    window.ggplotGuiClientEditingGraph = id;
    var rec = window.ggplotGuiClientPreviewStore[id];
    window.ggplotGuiClientEditingGraphName = rec ? String(rec.name || id) : id;
    document.querySelectorAll('.graph-tab-btn').forEach(function(btn) {
      btn.classList.toggle('client-selected', String(btn.getAttribute('data-graph-id') || '') === id);
    });
    ggplotGuiUpdateEditorShell(id);
  }
});

window.ggplotGuiLiveReplay = window.ggplotGuiLiveReplay || null;

Shiny.addCustomMessageHandler('graph-live-preview-target', function(msg) {
  msg = msg || {};
  var graphId = String(msg.graphId || '');
  var generation = Number(msg.generation || 0);
  var anchor = document.getElementById(String(msg.anchorId || 'graph_editor_single-preview_anchor'));
  var plot = document.getElementById(String(msg.plotId || 'graph_editor_single-plot'));
  var oldImg = plot ? plot.querySelector('img') : null;
  var oldSrc = oldImg ? String(oldImg.currentSrc || oldImg.src || '') : '';
  window.ggplotGuiLiveReplay = {
    graphId: graphId,
    generation: generation,
    anchorId: anchor ? anchor.id : '',
    plotId: plot ? plot.id : String(msg.plotId || ''),
    blockedSrc: oldSrc,
    valueSeen: false,
    acked: false
  };
  ggplotGuiSetLivePlotSwitchPending(true);
});

function ggplotGuiFinishLiveReplay(status) {
  var pending = window.ggplotGuiLiveReplay;
  if (!pending || pending.acked) return false;
  pending.acked = true;
  var anchor = pending.anchorId ? document.getElementById(pending.anchorId) : null;
  ggplotGuiSetLivePlotSwitchPending(false);
  if (window.Shiny) {
    Shiny.setInputValue('graph_live_preview_ready', {
      graphId: String(pending.graphId || ''),
      generation: Number(pending.generation || 0),
      status: String(status || 'browser-output-ready'),
      nonce: Date.now()
    }, {priority:'event'});
  }
  window.ggplotGuiLiveReplay = null;
  return true;
}

// A Shiny plot value belongs to the only in-flight Graph transaction because
// the server keeps graph_single_editor_loading=TRUE until this completion ACK.
$(document).on('shiny:value', function(ev) {
  var pending = window.ggplotGuiLiveReplay;
  if (!pending || pending.acked) return;
  var target = ev && ev.target;
  var targetId = target ? String(target.id || '') : '';
  var eventName = ev ? String(ev.name || '') : '';
  if (targetId !== String(pending.plotId || '') && eventName !== String(pending.plotId || '')) return;
  pending.valueSeen = true;
  var raf = window.requestAnimationFrame || function(cb) { cb(); };
  raf(function() {
    var p = window.ggplotGuiLiveReplay;
    if (!p || p.acked || !p.valueSeen) return;
    var plot = document.getElementById(String(p.plotId || ''));
    var img = plot ? plot.querySelector('img') : null;
    // Errors/non-image output are also a completed browser publication and
    // must not leave the Graph switch permanently locked.
    if (!img) ggplotGuiFinishLiveReplay('browser-value-no-image');
    else if (img.complete && Number(img.naturalWidth || 0) > 0) {
      ggplotGuiFinishLiveReplay('browser-image-complete');
    }
  });
});

$(document).on('shiny:error', function(ev) {
  var pending = window.ggplotGuiLiveReplay;
  if (!pending || pending.acked) return;
  var target = ev && ev.target;
  var targetId = target ? String(target.id || '') : '';
  var eventName = ev ? String(ev.name || '') : '';
  if (targetId !== String(pending.plotId || '') && eventName !== String(pending.plotId || '')) return;
  ggplotGuiFinishLiveReplay('browser-output-error');
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
      var bound = {};
      $('.shiny-bound-input').each(function() {
        var binding = $(this).data('shiny-input-binding');
        if (!binding) return;
        var id = binding.getId(this);
        if (!id || !prefix || id.indexOf(prefix) !== 0 ||
            (msg.requiredInputs || []).indexOf(id) < 0) return;
        bound[id] = true;
        // Replay changes values, never clicks actions or uploads files.
        if ($(this).hasClass('action-button') || this.type === 'file') return;
        var type = binding.getType ? binding.getType(this) : null;
        // event priority drains/cancels Shiny's rate-policy timer, notably Ace.
        // Read current binding values only; no canonical/browser comparison.
        Shiny.setInputValue(id + (type ? ':' + type : ''), binding.getValue(this),
          {priority: 'event'});
      });
      (msg.requiredInputs || []).forEach(function(id) {
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
    var rec = window.ggplotGuiClientPreviewStore[id];
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

    ggplotGuiSetLivePlotSwitchPending(false);
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
  if (window.Shiny) Shiny.setInputValue('graph_client_mode', 'edit', {priority:'event'});
});

Shiny.addCustomMessageHandler('graph-editor-shell-clear', function(msg) {
  ggplotGuiSetLivePlotSwitchPending(false);
  window.ggplotGuiClientEditorReady = false;
  window.ggplotGuiClientEditingGraph = '';
  window.ggplotGuiClientEditingGraphName = '';
  var selected = String((msg || {}).selected || window.ggplotGuiClientSelectedGraph || '');
  ggplotGuiUpdateEditorShell(selected, selected ? 'Graphを選択し直してください' : 'Graph未選択');
});

Shiny.addCustomMessageHandler('project-close-reload', function(msg) {
  // Project close is a hard ownership boundary. Reload the Shiny session so no
  // Graph/Figure/Library/editor lease from the closed Project can survive into
  // the new pristine Graph 1 workspace.
  window.location.reload();
});

window.addEventListener('resize', function() { ggplotGuiClientPreviewScale(); });

// v3.54 fixed singleton Graph Preview. The outer stage is created once
// under graph_panels and never reparented. Per-Graph UI contributes only
// a visual anchor. On target changes only the cached HTML and live output
// binding are replaced; Shiny unbind/bind is scoped to the live layer.
var graphGlobalPreviewStageRef = null;
var graphGlobalPreviewAnchorId = '';
window.ggplotGuiWorkspaceMainTab = window.ggplotGuiWorkspaceMainTab || 'Plot';

function ggplotGuiSemanticGraphId(moduleId) {
  moduleId = String(moduleId || '');
  if (moduleId === 'graph_editor_single') {
    return String(window.ggplotGuiClientEditingGraph || window.ggplotGuiClientSelectedGraph || '');
  }
  return moduleId;
}

function ggplotGuiCurrentEditorMainTab() {
  var root = document.querySelector('.graph-module[data-graph-module="graph_editor_single"]');
  if (!root) return '';
  var active = root.querySelector('.nav-tabs li.active a[data-value]');
  return active ? String(active.getAttribute('data-value') || '') : '';
}

function ggplotGuiApplyGraphPreviewTabState(moduleId, tabValue, source) {
  var stage = getGraphGlobalPreviewStage();
  if (!stage) return false;

  var graphId = ggplotGuiSemanticGraphId(moduleId);
  tabValue = String(tabValue || 'Plot');
  var visible = tabValue === 'Plot';
  // Section selection belongs to the workspace singleton. Never persist Preview
  // visibility per semantic Graph: switching Graphs must preserve the current
  // Statistics/Data/Comment section instead of restoring an old Plot state.
  window.ggplotGuiWorkspaceMainTab = tabValue;

  var currentId = String(stage.getAttribute('data-graph-id') || '');
  // A non-Plot tab never owns the singleton Preview. Hide immediately even if
  // a target switch is still catching up. Plot may reveal only its own Graph.
  if (!visible) {
    stage.classList.add('graph-preview-tab-hidden');
    stage.classList.remove('graph-preview-positioned');
    if (typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
      window.ggplotGuiUpdateGlobalPreviewFollow();
    }
    return true;
  }
  if (graphId && currentId && graphId !== currentId) return false;

  stage.classList.remove('graph-preview-tab-hidden');
  var raf = window.requestAnimationFrame || function(cb) { cb(); };
  raf(function() {
    var positioned = positionGraphGlobalPreview();
    if (positioned) window.ggplotGuiApplyGraphPreviewScale(stage, 'plot-tab-visible');
    if (typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
      window.ggplotGuiUpdateGlobalPreviewFollow();
    }
  });
  return true;
}

function getGraphGlobalPreviewStage() {
  if (graphGlobalPreviewStageRef) return graphGlobalPreviewStageRef;
  graphGlobalPreviewStageRef = document.getElementById('graph_global_preview_stage');
  return graphGlobalPreviewStageRef;
}

function positionGraphGlobalPreview() {
  var stage = getGraphGlobalPreviewStage();
  var root = document.getElementById('graph_panels');
  var anchor = graphGlobalPreviewAnchorId ? document.getElementById(graphGlobalPreviewAnchorId) : null;
  var tabHidden = !!stage && stage.classList.contains('graph-preview-tab-hidden');
  if (!stage || !root || !anchor || anchor.offsetParent === null || tabHidden) {
    if (stage) stage.classList.remove('graph-preview-positioned');
    return false;
  }
  var rootRect = root.getBoundingClientRect();
  var anchorRect = anchor.getBoundingClientRect();
  stage.style.left = Math.max(0, anchorRect.left - rootRect.left) + 'px';
  stage.style.top = Math.max(0, anchorRect.top - rootRect.top) + 'px';
  stage.style.width = Math.max(1, anchorRect.width) + 'px';
  stage.classList.add('graph-preview-positioned');
  var measuredH = stage.classList.contains('graph-preview-manual-scale')
    ? (stage.clientHeight || stage.getBoundingClientRect().height || 0)
    : (stage.scrollHeight || 0);
  var h = Math.max(700, measuredH);
  anchor.style.minHeight = h + 'px';
  return true;
}

function graphPreviewBox(el) {
  if (!el || !el.getBoundingClientRect) return null;
  var r = el.getBoundingClientRect();
  return {
    w: Math.round(r.width * 10) / 10,
    h: Math.round(r.height * 10) / 10,
    clientW: el.clientWidth || 0,
    clientH: el.clientHeight || 0,
    scrollW: el.scrollWidth || 0,
    scrollH: el.scrollHeight || 0
  };
}

function graphPreviewNativeSize(stage) {
  var w = Number(stage && stage.getAttribute('data-preview-native-width'));
  var h = Number(stage && stage.getAttribute('data-preview-native-height'));
  if (!isFinite(w) || w <= 0) w = 600;
  if (!isFinite(h) || h <= 0) h = 600;
  return {w:w, h:h};
}

function graphPreviewAvailableSize(stage) {
  var rawW = stage && stage.clientWidth ? stage.clientWidth : 0;
  if (!isFinite(rawW) || rawW <= 0) rawW = window.innerWidth || 660;
  // Preserve the established Preview reading width while remaining
  // responsive on smaller windows.  Height follows the historical 55vh.
  var w = Math.max(1, Math.min(660, rawW - 24));
  var h = Math.max(1, Math.min(560, (window.innerHeight || 800) * 0.55));
  return {w:w, h:h};
}

window.ggplotGuiApplyGraphPreviewScale = function(stage, reason) {
  if (!stage || !stage.classList.contains('graph-preview-positioned')) return false;
  var nativeSize = graphPreviewNativeSize(stage);
  var available = graphPreviewAvailableSize(stage);
  var autoEl = document.getElementById('graph_preview_scale_auto');
  var slider = document.getElementById('graph_preview_scale_slider');
  var valueEl = document.getElementById('graph_preview_scale_value');
  var isAuto = !autoEl || !!autoEl.checked;
  var manualPct = slider ? Number(slider.value) : 100;
  if (!isFinite(manualPct)) manualPct = 100;
  manualPct = Math.max(25, Math.min(150, manualPct));

  var nativeBoxW = nativeSize.w + 26;
  var nativeBoxH = nativeSize.h + 26;
  var scale = isAuto
    ? Math.min(1, available.w / nativeBoxW, available.h / nativeBoxH)
    : manualPct / 100;
  if (!isFinite(scale) || scale <= 0) scale = 1;

  var displayW = Math.max(1, nativeSize.w * scale);
  var displayH = Math.max(1, nativeSize.h * scale);
  var displayBoxW = Math.max(1, nativeBoxW * scale);
  var displayBoxH = Math.max(1, nativeBoxH * scale);
  stage.setAttribute('data-preview-scale-mode', isAuto ? 'auto' : 'manual');
  stage.setAttribute('data-preview-scale', String(scale));
  stage.setAttribute('data-preview-display-width', String(displayW));
  stage.setAttribute('data-preview-display-height', String(displayH));
  stage.classList.toggle('graph-preview-manual-scale', !isAuto);
  stage.style.maxHeight = '';
  stage.style.overflow = 'visible';

  if (slider) slider.disabled = isAuto;
  if (valueEl) valueEl.textContent = isAuto ? 'Auto' : Math.round(manualPct) + '%';

  var live = stage.querySelector('#graph_global_preview_live_layer');
  var holder = live ? live.querySelector('.shiny-html-output') : null;
  var viewport = live ? live.querySelector('[id$=-plot_viewport]') : null;
  var spacer = live ? live.querySelector('[id$=-plot_scale_spacer]') : null;
  var canvas = live ? live.querySelector('[id$=-plot_scale_canvas]') : null;
  var panel = live ? live.querySelector('[id$=-plot_panel]') : null;
  var plot = live ? live.querySelector('[id$=-plot]') : null;

  if (holder) {
    holder.style.width = '100%';
    holder.style.maxWidth = 'none';
    holder.style.overflow = 'visible';
  }
  if (viewport) {
    var viewportW = isAuto ? displayBoxW : Math.min(available.w, displayBoxW);
    var viewportH = isAuto ? displayBoxH : Math.min(available.h, displayBoxH);
    viewport.style.width = Math.max(1, viewportW) + 'px';
    viewport.style.maxWidth = '100%';
    viewport.style.height = Math.max(1, viewportH) + 'px';
    viewport.style.maxHeight = Math.max(1, viewportH) + 'px';
    viewport.style.overflowX = (!isAuto && displayBoxW > viewportW + 0.5) ? 'auto' : 'hidden';
    viewport.style.overflowY = (!isAuto && displayBoxH > viewportH + 0.5) ? 'auto' : 'hidden';
    viewport.style.marginLeft = 'auto';
    viewport.style.marginRight = 'auto';
    viewport.setAttribute('data-preview-scroll-owner', 'graph-only');
  }
  if (spacer) {
    spacer.style.width = displayBoxW + 'px';
    spacer.style.height = displayBoxH + 'px';
    spacer.style.maxWidth = 'none';
  }
  if (canvas) {
    canvas.style.width = nativeBoxW + 'px';
    canvas.style.height = nativeBoxH + 'px';
    canvas.style.transform = 'scale(' + scale + ')';
    canvas.style.transformOrigin = 'top left';
  }
  if (panel) {
    panel.style.width = nativeBoxW + 'px';
    panel.style.maxWidth = 'none';
    panel.style.height = nativeBoxH + 'px';
    panel.style.marginLeft = '0';
    panel.style.marginRight = '0';
    panel.setAttribute('data-display-scale', String(scale));
  }
  if (plot) {
    plot.style.width = nativeSize.w + 'px';
    plot.style.height = nativeSize.h + 'px';
    plot.style.transform = 'none';
    plot.setAttribute('data-plot-width', String(nativeSize.w));
    plot.setAttribute('data-plot-height', String(nativeSize.h));
  }

  var cached = stage.querySelector('#graph_global_preview_cached_layer');
  var cachedSpacer = cached ? cached.querySelector('.graph-cached-preview-scale-spacer') : null;
  var cachedCanvas = cached ? cached.querySelector('.graph-cached-preview-scale-canvas') : null;
  var cachedViewport = cached ? cached.querySelector('.graph-cached-preview-svg') : null;
  if (cachedSpacer) {
    cachedSpacer.style.width = displayW + 'px';
    cachedSpacer.style.height = displayH + 'px';
    cachedSpacer.style.maxWidth = 'none';
  }
  if (cachedCanvas) {
    cachedCanvas.style.width = nativeSize.w + 'px';
    cachedCanvas.style.height = nativeSize.h + 'px';
    cachedCanvas.style.transform = 'scale(' + scale + ')';
    cachedCanvas.style.transformOrigin = 'top left';
  }
  if (cachedViewport) {
    cachedViewport.style.width = nativeSize.w + 'px';
    cachedViewport.style.height = nativeSize.h + 'px';
    cachedViewport.style.maxWidth = 'none';
    cachedViewport.style.maxHeight = 'none';
    cachedViewport.style.aspectRatio = nativeSize.w + ' / ' + nativeSize.h;
    var svg = cachedViewport.querySelector('svg');
    if (svg) {
      svg.style.width = '100%';
      svg.style.height = '100%';
      svg.style.maxWidth = 'none';
      svg.style.maxHeight = 'none';
    }
  }

  if (window.Shiny) {
    Shiny.setInputValue('graph_preview_scale_ack', {
      graphId: String(stage.getAttribute('data-graph-id') || ''),
      mode: isAuto ? 'auto' : 'manual',
      nativeW: nativeSize.w, nativeH: nativeSize.h,
      availableW: available.w, availableH: available.h,
      scale: scale, displayW: displayW, displayH: displayH,
      reason: String(reason || ''), nonce: Date.now()
    }, {priority:'event'});
  }
  return true;
};

function reportGraphPreviewDims(stage, reason) {
  if (!stage || !window.Shiny) return;
  var live = stage.querySelector('#graph_global_preview_live_layer');
  var holder = live ? live.querySelector('.shiny-html-output') : null;
  var anchor = live ? live.querySelector('[id$=-plot_anchor]') : null;
  var follow = live ? live.querySelector('[id$=-plot_follow]') : null;
  var viewport = live ? live.querySelector('[id$=-plot_viewport]') : null;
  var spacer = live ? live.querySelector('[id$=-plot_scale_spacer]') : null;
  var canvas = live ? live.querySelector('[id$=-plot_scale_canvas]') : null;
  var panel = live ? live.querySelector('[id$=-plot_panel]') : null;
  var plot = live ? live.querySelector('[id$=-plot]') : null;
  var img = plot ? plot.querySelector('img') : null;
  Shiny.setInputValue('graph_global_preview_dims_ack', {
    graphId: String(stage.getAttribute('data-graph-id') || ''),
    reason: String(reason || ''),
    mode: String(stage.getAttribute('data-preview-mode') || ''),
    stage: graphPreviewBox(stage),
    live: graphPreviewBox(live),
    holder: graphPreviewBox(holder),
    anchor: graphPreviewBox(anchor),
    follow: graphPreviewBox(follow),
    viewport: graphPreviewBox(viewport),
    spacer: graphPreviewBox(spacer),
    canvas: graphPreviewBox(canvas),
    panel: graphPreviewBox(panel),
    plot: graphPreviewBox(plot),
    image: graphPreviewBox(img),
    imageNaturalW: img && img.naturalWidth ? img.naturalWidth : 0,
    imageNaturalH: img && img.naturalHeight ? img.naturalHeight : 0,
    nonce: Date.now()
  }, {priority:'event'});
}


function reportGraphPreviewReveal(stage, state, reason) {
  if (!stage || !window.Shiny) return;
  Shiny.setInputValue('graph_global_preview_reveal_ack', {
    graphId: String(stage.getAttribute('data-graph-id') || ''),
    state: String(state || ''),
    reason: String(reason || ''),
    pending: stage.classList.contains('graph-preview-live-pending'),
    nonce: Date.now()
  }, {priority:'event'});
}

function revealPendingGraphPreview(stage, reason) {
  if (!stage || !stage.classList.contains('graph-preview-live-pending')) return false;
  stage.classList.remove('graph-preview-live-pending');
  stage.removeAttribute('data-preview-pending-graph');
  reportGraphPreviewReveal(stage, 'visible', reason || '');
  return true;
}

Shiny.addCustomMessageHandler('graph-global-preview-fast-retarget', function(msg) {
  msg = msg || {};
  var stage = getGraphGlobalPreviewStage();
  if (!stage) return;
  var id = String(msg.graphId || '');
  if (!id) return;

  // Equivalent-state identity switch: preserve the existing singleton live
  // output holder and IMG. Only Graph identity/viewport ownership changes.
  // No Shiny unbind/bind, cached->live promotion, or render authorization is
  // needed because the server verified that the target GraphState is exactly
  // the RenderState already displayed by this holder.
  stage.setAttribute('data-graph-id', id);
  stage.setAttribute('data-preview-transaction-id', '');
  stage.setAttribute('data-preview-live-authorized', '1');
  stage.classList.remove('graph-preview-live-pending');
  stage.removeAttribute('data-preview-pending-graph');

  var nativeW = Number(msg.viewportWidth);
  var nativeH = Number(msg.viewportHeight);
  if (!isFinite(nativeW) || nativeW <= 0) nativeW = 600;
  if (!isFinite(nativeH) || nativeH <= 0) nativeH = 600;
  stage.setAttribute('data-preview-native-width', String(nativeW));
  stage.setAttribute('data-preview-native-height', String(nativeH));

  setGraphPreviewStageMode(stage, 'live', 'equivalent-fast-retarget');
  var live = stage.querySelector('#graph_global_preview_live_layer');
  if (live) live.setAttribute('aria-hidden', 'false');
  window.ggplotGuiApplyGraphPreviewScale(stage, 'equivalent-fast-retarget');
});

Shiny.addCustomMessageHandler('graph-global-preview-target', function(msg) {
  msg = msg || {};
  var stage = getGraphGlobalPreviewStage();
  if (!stage) return;
  var anchor = msg.anchorId ? document.getElementById(msg.anchorId) : null;
  var cached = stage.querySelector('#graph_global_preview_cached_layer');
  var live = stage.querySelector('#graph_global_preview_live_layer');
  if (!anchor || !cached || !live) return;

  var msgReason = String(msg.reason || '');
  if (msgReason.indexOf('project-') === 0) {
    var resetAuto = document.getElementById('graph_preview_scale_auto');
    var resetSlider = document.getElementById('graph_preview_scale_slider');
    if (resetAuto) resetAuto.checked = true;
    if (resetSlider) resetSlider.value = '100';
  }
  var nextGraph = String(msg.graphId || '');
  var prevGraph = String(stage.getAttribute('data-graph-id') || '');
  var targetChanged = prevGraph !== nextGraph;
  var forceReset = !!msg.forceReset;
  graphGlobalPreviewAnchorId = String(msg.anchorId || '');

  // v3.72.5: a single-editor Preview transaction owns promotion explicitly.
  // Transactional READY may create/bind the live holder, but it is NOT allowed
  // to reveal any IMG until the server receives the bind ACK and sends the
  // separate live-authorize message. This prevents an already-computed/replayed
  // output from appearing before the target cached SVG has been acknowledged.
  var previewTxn = String(msg.transactionId || '');
  var transactionalPreview = previewTxn.length > 0;
  stage.setAttribute('data-preview-transaction-id', previewTxn);
  stage.setAttribute('data-preview-live-authorized', (!transactionalPreview && !!msg.preferLive) ? '1' : '0');
  stage.setAttribute('data-preview-live-output-id', String(msg.liveOutputId || ''));

  // One shared live layer only. Browse-first selection uses cached SVGs; the
  // persistent single Editor owns the sole live output when editing begins.
  live.id = 'graph_global_preview_live_layer';
  live.className = 'graph-preview-live-layer';
  live.style.display = '';

  if (targetChanged || forceReset) {
    try {
      if (window.Shiny && Shiny.unbindAll) Shiny.unbindAll(live);
    } catch (e) {}
    cached.innerHTML = String(msg.cachedHtml || '');
    live.innerHTML = '';

    // v3.72.4: while the target Graph is HYDRATING (preferLive=FALSE),
    // intentionally leave the shared live layer unbound and without the
    // singleton output holder.  The cached SVG is the only visible preview
    // during the transaction.  READY sends preferLive=TRUE for the same
    // target; only then do we recreate/bind the live holder below.
    if (!!msg.preferLive && msg.liveOutputId) {
      var holder = document.createElement('div');
      holder.id = String(msg.liveOutputId);
      holder.className = 'shiny-html-output';

      // v3.58: holder stays responsive; Graph display scaling is done
      // centrally by ggplotGuiApplyGraphPreviewScale().
      holder.style.width = '100%';
      holder.style.maxWidth = 'none';
      holder.style.marginLeft = 'auto';
      holder.style.marginRight = 'auto';
      live.appendChild(holder);
    }
    stage.setAttribute('data-graph-id', nextGraph);
    // v3.73.1.1: Preview visibility follows the workspace section, never the
    // target Graph's historical section. The persistent internal tab is kept as
    // a fallback only for startup before the outer workspace bar has emitted.
    var workspaceTab = String(
      window.ggplotGuiWorkspaceMainTab || ggplotGuiCurrentEditorMainTab() || 'Plot'
    );
    var workspaceVisible = workspaceTab === 'Plot';
    stage.classList.toggle('graph-preview-tab-hidden', !workspaceVisible);
    if (!workspaceVisible) stage.classList.remove('graph-preview-positioned');
    var nativeW = Number(msg.viewportWidth);
    var nativeH = Number(msg.viewportHeight);
    if (!isFinite(nativeW) || nativeW <= 0) nativeW = 600;
    if (!isFinite(nativeH) || nativeH <= 0) nativeH = 600;
    stage.setAttribute('data-preview-native-width', String(nativeW));
    stage.setAttribute('data-preview-native-height', String(nativeH));
    stage.setAttribute('data-preview-ack-id', 'graph_global_preview_mode_ack');
    if (!!msg.preferLive) {
      stage.classList.add('graph-preview-live-pending');
      stage.setAttribute('data-preview-pending-graph', nextGraph);
      reportGraphPreviewReveal(stage, 'hidden', 'live-target-pending');
    } else {
      stage.classList.remove('graph-preview-live-pending');
      stage.removeAttribute('data-preview-pending-graph');
    }
    // v3.65.1: READY means the Editor state is ready, not that a new
    // browser plot image has arrived.  When a cached SVG exists, keep
    // it visible while the fresh live output is pending.  Previously we
    // entered mode=live and live-pending at the same time; CSS then hid
    // both cached and live layers until IMG load, producing a blank plot.
    var waitForLiveImage = !!msg.preferLive && !!msg.hasCached;
    var targetMode = waitForLiveImage ? 'cached'
      : (msg.preferLive ? 'live' : (msg.hasCached ? 'cached' : 'live'));
    setGraphPreviewStageMode(stage, targetMode, 'target-change');
    live.setAttribute('aria-hidden', targetMode === 'live' ? 'false' : 'true');
    try {
      // v3.72.4: do not bind the singleton live output during HYDRATING.
      // Binding here with preferLive=FALSE was enough for Shiny to replay the
      // previous plot into the freshly retargeted stage, producing a visible
      // cached -> previous-live -> current-live round trip.
      if (!!msg.preferLive && window.Shiny && Shiny.bindAll) Shiny.bindAll(live);
    } catch (e) {}
    window.ggplotGuiApplyGraphPreviewScale(stage, 'target-change');
  }

  // v3.72.4: READY is the only point where the persistent single-editor live
  // output is allowed to exist in the shared Preview stage.  A pending
  // HYDRATING target has no holder at all, so stale plot-image-load events
  // from the previous Graph cannot be mistaken for the new target.
  if (!!msg.preferLive) {
    var readyOutputId = String(msg.liveOutputId || '');
    var readyHolder = readyOutputId ? document.getElementById(readyOutputId) : null;
    var readyHolderCreated = false;

    if (readyOutputId && (!readyHolder || readyHolder.parentNode !== live)) {
      // Defensive cleanup: if the same singleton id somehow exists outside
      // the current live layer, unbind/remove it before creating the READY
      // holder.  In the normal path HYDRATING already removed it.
      if (readyHolder) {
        try { if (window.Shiny && Shiny.unbindAll) Shiny.unbindAll(readyHolder); } catch (e) {}
        try { if (readyHolder.parentNode) readyHolder.parentNode.removeChild(readyHolder); } catch (e) {}
      }
      readyHolder = document.createElement('div');
      readyHolder.id = readyOutputId;
      readyHolder.className = 'shiny-html-output';
      readyHolder.style.width = '100%';
      readyHolder.style.maxWidth = 'none';
      readyHolder.style.marginLeft = 'auto';
      readyHolder.style.marginRight = 'auto';
      live.appendChild(readyHolder);
      readyHolderCreated = true;
    }

    var cachedStillVisible = cached && String(cached.innerHTML || '').trim().length > 0;
    if (cachedStillVisible) {
      stage.classList.add('graph-preview-live-pending');
      stage.setAttribute('data-preview-pending-graph', nextGraph);
      if (!stage.classList.contains('graph-preview-mode-cached')) {
        setGraphPreviewStageMode(stage, 'cached', 'ready-wait-live-bind');
      }
      live.setAttribute('aria-hidden', 'true');
    }

    if (readyHolderCreated) {
      try { if (window.Shiny && Shiny.bindAll) Shiny.bindAll(live); } catch (e) {}
    }

    if (window.Shiny) {
      Shiny.setInputValue('graph_global_preview_live_bind_ack', {
        graphId: nextGraph,
        outputId: readyOutputId,
        holderCreated: readyHolderCreated,
        cachedVisible: cachedStillVisible,
        nonce: Date.now()
      }, {priority: 'event'});
    }

    // If Shiny synchronously restored a completed image during bindAll, use
    // it immediately.  Otherwise the capture-phase IMG load handler performs
    // the one cached -> live promotion when the fresh image arrives.
    var readyImg = readyHolder ? readyHolder.querySelector('.shiny-plot-output img') : null;
    if (stage.getAttribute('data-preview-live-authorized') === '1' &&
        readyImg && readyImg.complete && Number(readyImg.naturalWidth || 0) > 0) {
      window.ggplotGuiApplyGraphPreviewScale(stage, 'ready-existing-image');
      if (stage.classList.contains('graph-preview-live-pending')) {
        revealPendingGraphPreview(stage, 'ready-existing-image');
      }
      if (stage.classList.contains('graph-preview-mode-cached')) {
        setGraphPreviewStageMode(stage, 'live', 'ready-existing-image');
      }
    }
  }

  var positioned = positionGraphGlobalPreview();
  window.ggplotGuiApplyGraphPreviewScale(stage, 'target-positioned');
  var raf = window.requestAnimationFrame || function(cb) { cb(); };
  raf(function() {
    positionGraphGlobalPreview();
    window.ggplotGuiApplyGraphPreviewScale(stage, 'target-positioned-raf');
    reportGraphPreviewDims(stage, 'target-positioned');
  });

  // Diagnostic only: restore/materialization never waits for this ACK.
  if (window.Shiny) {
    Shiny.setInputValue('graph_global_preview_target_ack', {
      graphId: nextGraph,
      previousGraphId: prevGraph,
      targetChanged: targetChanged,
      forceReset: forceReset,
      preferLive: !!msg.preferLive,
      transactionId: previewTxn,
      liveHolderPresent: !!(msg.liveOutputId && document.getElementById(String(msg.liveOutputId))),
      attached: stage.parentNode && stage.parentNode.id === 'graph_global_preview_home',
      positioned: positioned,
      stageCount: document.querySelectorAll('#graph_global_preview_stage').length,
      nonce: Date.now()
    }, {priority: 'event'});
  }
});

Shiny.addCustomMessageHandler('graph-global-preview-live-authorize', function(msg) {
  msg = msg || {};
  var stage = getGraphGlobalPreviewStage();
  if (!stage) return;
  var graphId = String(msg.graphId || '');
  var txn = String(msg.transactionId || '');
  var currentGraph = String(stage.getAttribute('data-graph-id') || '');
  var currentTxn = String(stage.getAttribute('data-preview-transaction-id') || '');
  var holderId = String(stage.getAttribute('data-preview-live-output-id') || '');
  var holder = holderId ? document.getElementById(holderId) : null;
  var matches = !!graphId && graphId === currentGraph && !!txn && txn === currentTxn;
  if (matches) stage.setAttribute('data-preview-live-authorized', '1');
  if (window.Shiny) {
    Shiny.setInputValue('graph_global_preview_live_authorize_ack', {
      graphId: graphId,
      transactionId: txn,
      matched: matches,
      holderPresent: !!holder,
      nonce: Date.now()
    }, {priority: 'event'});
  }
});

Shiny.addCustomMessageHandler('graph-global-preview-tab-state', function(msg) {
  msg = msg || {};
  ggplotGuiApplyGraphPreviewTabState(
    String(msg.graphId || ''),
    String(msg.tab || 'Plot'),
    'server-message'
  );
});

window.addEventListener('resize', function() {
  var stage = getGraphGlobalPreviewStage();
  if (stage) window.ggplotGuiApplyGraphPreviewScale(stage, 'window-resize');
  positionGraphGlobalPreview();
});

// v3.58.3.5: the Shiny input-change event is the authoritative browser
// signal for the namespaced Graph main tab.  Unlike DOM ancestry from
// Bootstrap's shown.bs.tab target, this carries both the exact input id
// (e.g. g002-graph_main_tab) and its value, so singleton Preview
// visibility cannot lose track of the active Graph.
$(document).on('shiny:inputchanged', function(ev) {
  var inputName = ev && ev.name ? String(ev.name) : '';
  var suffix = '-graph_main_tab';
  if (!inputName || inputName.slice(-suffix.length) !== suffix) return;

  var moduleId = inputName.slice(0, -suffix.length);
  var tabValue = ev && ev.value != null ? String(ev.value) : '';
  var graphId = ggplotGuiSemanticGraphId(moduleId);
  if (moduleId === 'graph_editor_single') ggplotGuiSyncWorkspaceSectionBar(tabValue);
  var applied = ggplotGuiApplyGraphPreviewTabState(moduleId, tabValue, 'shiny-inputchanged');
  if (applied && window.Shiny) {
    Shiny.setInputValue('graph_global_preview_tab_ack', {
      graphId: graphId, tab: tabValue, visible: tabValue === 'Plot',
      source: 'shiny-inputchanged', nonce: Date.now()
    }, {priority: 'event'});
  }
});

$(document).on('shown.bs.tab', function(ev) {
  var tabTarget = ev && ev.target ? ev.target : null;
  var tabValue = tabTarget && tabTarget.getAttribute
    ? String(tabTarget.getAttribute('data-value') || '')
    : '';
  var graphModule = tabTarget && tabTarget.closest
    ? tabTarget.closest('.graph-module[data-graph-module]')
    : null;
  var moduleId = graphModule
    ? String(graphModule.getAttribute('data-graph-module') || '')
    : '';
  var isGraphMainTab = !!graphModule &&
    ['Plot', 'Statistics', 'Data View', '製作者コメント'].indexOf(tabValue) >= 0;

  if (isGraphMainTab) {
    if (moduleId === 'graph_editor_single') ggplotGuiSyncWorkspaceSectionBar(tabValue);
    ggplotGuiApplyGraphPreviewTabState(moduleId, tabValue, 'bootstrap-tab');
    return;
  }

  var raf = window.requestAnimationFrame || function(cb) { cb(); };
  raf(function() {
    positionGraphGlobalPreview();
    if (typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
      window.ggplotGuiUpdateGlobalPreviewFollow();
    }
  });
});

document.addEventListener('load', function(ev) {
  var target = ev && ev.target;
  if (!target || target.tagName !== 'IMG') return;
  var plot = target.closest ? target.closest('.shiny-plot-output') : null;
  if (!plot) return;
  var pendingLive = window.ggplotGuiLiveReplay;
  if (pendingLive && !pendingLive.acked &&
      String(plot.id || '') === String(pendingLive.plotId || '')) {
    // Ignore an old already-visible image if its delayed load event arrives
    // after the next Graph replay began. A new Shiny value event or changed
    // image URL authorizes this completion.
    var srcNow = String(target.currentSrc || target.src || '');
    if (pendingLive.valueSeen || !pendingLive.blockedSrc || srcNow !== pendingLive.blockedSrc) {
      ggplotGuiFinishLiveReplay('browser-image-load');
    }
    return;
  }

  var stage = plot.closest ? plot.closest('.graph-preview-stage') : null;
  if (!stage) return;

  // v3.72.3 transaction guard.  During single-editor HYDRATING the server has
  // already retargeted the shared stage to the new Graph's cached SVG, while a
  // queued load event from the previous Graph can still arrive.  Only READY's
  // preferLive=TRUE message authorizes promotion, and the IMG must belong to
  // the currently expected live holder.
  var liveAuthorized = stage.getAttribute('data-preview-live-authorized') === '1';
  var expectedOutputId = String(stage.getAttribute('data-preview-live-output-id') || '');
  var expectedHolder = expectedOutputId ? document.getElementById(expectedOutputId) : null;
  var holderMatches = !expectedOutputId ? true : (!!expectedHolder && expectedHolder.contains(target));
  if (!liveAuthorized || !holderMatches) {
    if (window.Shiny) {
      Shiny.setInputValue('graph_global_preview_live_guard_ack', {
        graphId: String(stage.getAttribute('data-graph-id') || ''),
        authorized: liveAuthorized,
        holderMatches: holderMatches,
        expectedOutputId: expectedOutputId,
        nonce: Date.now()
      }, {priority: 'event'});
    }
    return;
  }

  window.ggplotGuiApplyGraphPreviewScale(stage, 'plot-image-load');
  if (stage.classList.contains('graph-preview-live-pending')) {
    revealPendingGraphPreview(stage, 'plot-image-load-fallback');
  }
  if (stage.classList.contains('graph-preview-mode-cached')) {
    setGraphPreviewStageMode(stage, 'live', 'plot-image-load');
  }
}, true);

Shiny.addCustomMessageHandler('graph-cached-preview-refit', function(msg) {
  if (!msg || !msg.previewId) return;
  var ratio = Number(msg.aspectRatio || 1);
  if (!isFinite(ratio) || ratio <= 0) ratio = 1;

  function fitOnce() {
    var layer = document.getElementById(msg.previewId);
    if (!layer) return;
    var previewStage = layer.closest ? layer.closest('#graph_global_preview_stage') : null;
    if (previewStage) {
      window.ggplotGuiApplyGraphPreviewScale(previewStage, 'cached-refit');
      return;
    }
    var viewport = layer.querySelector('.graph-cached-preview-svg');
    if (!viewport) return;
    var parent = viewport.parentElement || layer.parentElement;
    var available = parent ? parent.clientWidth : 0;
    if (!isFinite(available) || available <= 0) return;

    var vhCap = Math.max(1, window.innerHeight * 0.55);
    var width = Math.min(available, 660, vhCap * ratio);
    var height = width / ratio;

    viewport.style.width = Math.max(1, width) + 'px';
    viewport.style.height = Math.max(1, height) + 'px';
    viewport.style.maxWidth = '100%';
    viewport.style.maxHeight = Math.min(560, vhCap) + 'px';
    viewport.style.aspectRatio = ratio + ' / 1';

    var svg = viewport.querySelector('svg');
    if (svg) {
      svg.style.width = '100%';
      svg.style.height = '100%';
      svg.style.maxWidth = '100%';
      svg.style.maxHeight = '100%';
    }
  }

  fitOnce();
  window.requestAnimationFrame(function() {
    window.requestAnimationFrame(fitOnce);
  });
});

// v3.43: Figure-owned panel subsections fold vertically by heading.
// Event delegation keeps dynamically-rendered inspector groups foldable
// v3.49: save only presentation state; no DOM observer/presence probe.
document.addEventListener('click', function(ev) {
  var heading = ev.target && ev.target.closest ? ev.target.closest('.figure-inspector-group > h5') : null;
  if (!heading) return;
  var group = heading.parentElement;
  if (!group) return;
  group.classList.toggle('is-collapsed');
  // Optional persistence runs only on a click, after handler registration.
  // A failure here must not stop the existing synchronization bridge.
  try {
    var key = group.getAttribute('data-figure-fold-key');
    if (key && window.Shiny && typeof Shiny.setInputValue === 'function') {
      Shiny.setInputValue('figure_inspector_fold', {
        key: key, collapsed: group.classList.contains('is-collapsed')
      }, {priority: 'event'});
    }
  } catch (err) {
    console.warn('Figure Inspector fold state was not saved', err);
  }
});

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
  Shiny.setInputValue('figure_layout_edit', {
    type: type, row: row, col: col, value: raw, nonce: Date.now()
  }, {priority: 'event'});
}

// Phase 8: Row height and Panel ratio are Fixed-layout controls.  Do not
// stream every native number-input `input` event to Shiny: spinner holds
// and rapid typing can otherwise enqueue repeated full Figure geometry
// recalculations and make the R session appear hung.  Commit once on
// `change` instead.  Graph width/height keeps its short debounce because
// those fields are live in Auto fit as well.
$(document).on('change', '.figure-row-height-edit', function() {
  sendFigureNumberEdit(this, 'row_height', 1, true);
});

$(document).on('change', '.figure-panel-width-edit', function() {
  sendFigureNumberEdit(this, 'panel_width', 1, true);
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

$(document).on('input', '.figure-graph-width-edit,.figure-graph-height-edit', function() {
  var el = this;
  if (el._figureEditTimer) clearTimeout(el._figureEditTimer);
  el._figureEditTimer = setTimeout(function() {
    var typ = el.classList.contains('figure-graph-width-edit') ? 'graph_width' : 'graph_height';
    sendFigureGraphSizeEdit(el, typ);
  }, 250);
});

$(document).on('change', '.figure-graph-width-edit,.figure-graph-height-edit', function() {
  if (this._figureEditTimer) clearTimeout(this._figureEditTimer);
  var typ = this.classList.contains('figure-graph-width-edit') ? 'graph_width' : 'graph_height';
  sendFigureGraphSizeEdit(this, typ);
});

$(document).on('change', '.figure-row-basis-edit', function() {
  var row = parseInt($(this).attr('data-row'), 10);
  if (!isFinite(row)) return;
  Shiny.setInputValue('figure_layout_edit', {
    type: 'row_basis', row: row, value: String(this.value || 'inherit'), nonce: Date.now()
  }, {priority: 'event'});
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
  var msg = {type: typ, nonce: Date.now()};
  if (isFinite(row)) msg.row = row;
  Shiny.setInputValue('figure_layout_edit', msg, {priority: 'event'});
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

  var stage = panel.closest ? panel.closest('#graph_global_preview_stage') : null;
  if (stage) {
    stage.setAttribute('data-preview-native-width', String(w));
    stage.setAttribute('data-preview-native-height', String(h));
    return window.ggplotGuiApplyGraphPreviewScale(stage, 'live-dimensions');
  }

  // Non-Preview graph modules keep the historical fit behavior.
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

  var stage = panel && panel.closest ? panel.closest('#graph_global_preview_stage') : null;
  if (!stage && panel && isFinite(panelW)) {
    panel.style.width = 'min(100%, ' + panelW + 'px)';
    panel.style.maxWidth = panelW + 'px';
  }

  window.ggplotGuiApplyPlotScale(panel, plot, w, h);
  if (stage) {
    var msgReason = msg.reason ? String(msg.reason) : '';
    var reportReason = 'set-plot-dimensions' + (msgReason ? ':' + msgReason : '');
    requestAnimationFrame(function() { reportGraphPreviewDims(stage, reportReason); });
  }

  // Do not recreate/move DOM. Refresh sticky geometry only after the
  // existing elements have adopted their new dimensions.
  requestAnimationFrame(function() {
    requestAnimationFrame(function() {
      var module = follow && follow.closest ? follow.closest('.graph-module') : null;
      if (module && typeof window.ggplotGuiUpdatePlotFollow === 'function') {
        window.ggplotGuiUpdatePlotFollow(module);
      } else if (stage && typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
        window.ggplotGuiUpdateGlobalPreviewFollow();
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

$(document).on('change', '#graph_preview_scale_auto', function() {
  var stage = getGraphGlobalPreviewStage();
  if (!stage) return;
  window.ggplotGuiApplyGraphPreviewScale(stage, 'control-auto');
  positionGraphGlobalPreview();
});
$(document).on('input change', '#graph_preview_scale_slider', function() {
  var stage = getGraphGlobalPreviewStage();
  var autoEl = document.getElementById('graph_preview_scale_auto');
  if (!stage || (autoEl && autoEl.checked)) return;
  window.ggplotGuiApplyGraphPreviewScale(stage, 'control-manual');
  positionGraphGlobalPreview();
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
    } else if (typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
      requestAnimationFrame(function() { window.ggplotGuiUpdateGlobalPreviewFollow(); });
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
      if (typeof window.ggplotGuiUpdateGlobalPreviewFollow === 'function') {
        window.ggplotGuiUpdateGlobalPreviewFollow();
      }
    });
  });
});

(function() {
  function clearGlobalPreviewFollow(anchor, box) {
    if (!box) return;
    box.classList.remove('plot-fixed');
    box.style.width = '';
    box.style.left = '';
    box.style.top = '';
    box.style.maxHeight = '';
    box.style.overflowY = '';
    if (anchor) anchor.style.minHeight = '';
  }

  function updateGlobalPreviewFollow() {
    var stage = getGraphGlobalPreviewStage();
    if (!stage) return;
    var live = stage.querySelector('#graph_global_preview_live_layer');
    var anchor = live ? live.querySelector('[id$=-plot_anchor]') : null;
    var box = live ? live.querySelector('[id$=-plot_follow]') : null;
    if (!anchor || !box) return;

    var enabled = box.getAttribute('data-follow') === 'true';
    var mobile = window.innerWidth <= 991;
    var hidden = stage.classList.contains('graph-preview-tab-hidden') ||
      !stage.classList.contains('graph-preview-positioned');
    var fullHeight = Math.max(box.scrollHeight || 0, box.getBoundingClientRect().height || 0);
    var availableHeight = Math.max(240, window.innerHeight - 30);
    var oversize = fullHeight > availableHeight;
    if (!enabled || mobile || hidden || oversize) {
      clearGlobalPreviewFollow(anchor, box);
      return;
    }

    var rect = anchor.getBoundingClientRect();
    if (rect.top <= 10) {
      box.classList.add('plot-fixed');
      box.style.top = '10px';
      box.style.width = rect.width + 'px';
      box.style.left = rect.left + 'px';
      var h = Math.ceil(box.getBoundingClientRect().height || box.offsetHeight || 0);
      if (h > 0) anchor.style.minHeight = h + 'px';
    } else {
      clearGlobalPreviewFollow(anchor, box);
    }
  }

  window.ggplotGuiUpdateGlobalPreviewFollow = updateGlobalPreviewFollow;

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
    updateGlobalPreviewFollow();
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
    });

    // Re-apply current Plot geometry using the same proportional
    // scaling path after viewport/column width changes.
    if (typeof window.ggplotGuiApplyVisiblePlotScale === 'function') {
      window.ggplotGuiApplyVisiblePlotScale(module);
    }
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
    
