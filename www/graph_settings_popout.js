// v3.73.2.30 — external Graph/Figure Settings Manager companion window.
// The child window has no Shiny bindings and owns no Graph/Figure state. It
// mirrors server-owned values, keeps only local selection/draft UI state, and
// sends explicit Graph / Figure / Graph+Figure writes back to the main session.
window.ggplotGuiGraphSettingsPopout = null;
window.ggplotGuiGraphSettingsManagerData = null;
window.ggplotGuiGraphSettingsSelection = {};
window.ggplotGuiGraphSettingsSelectionInitialized = false;
window.ggplotGuiGraphSettingsSource = null;
window.ggplotGuiGraphSettingsDraftValue = null;
window.ggplotGuiGraphSettingsDraftDirty = false;
window.ggplotGuiGraphSettingsFeedback = {ok:true, message:''};

function ggplotGuiSetGraphSettingsFeedback(ok, message) {
  window.ggplotGuiGraphSettingsFeedback = {ok:!!ok, message:String(message || '')};
  var popout = window.ggplotGuiGraphSettingsPopout;
  if (!popout || popout.closed) return;
  var node = popout.document.getElementById('gsm-feedback');
  if (!node) return;
  node.textContent = String(message || '');
  node.className = 'gsm-feedback ' + (ok ? 'gsm-feedback-ok' : 'gsm-feedback-error');
  node.style.display = message ? 'block' : 'none';
}

window.ggplotGuiApplyGraphSettingValue = function(sourceId, path, value, targetIds, scope) {
  sourceId = String(sourceId || '');
  path = String(path || '');
  scope = String(scope || 'graph');
  targetIds = Array.isArray(targetIds) ? targetIds.map(function(x){ return String(x || ''); }).filter(Boolean) : [];
  if (!path || !targetIds.length || ['graph','figure','both'].indexOf(scope) < 0 || !window.Shiny) return false;
  Shiny.setInputValue('graph_settings_manager_value_apply', {
    sourceId: sourceId,
    path: path,
    value: value,
    targetIds: targetIds,
    scope: scope,
    nonce: Date.now()
  }, {priority:'event'});
  return true;
};

// v28 compatibility: old companion windows that are still open can continue
// to request a source-value copy. The current value is resolved from the latest
// manager payload and sent through the typed v29 path.
window.ggplotGuiApplyGraphSettingBatch = function(sourceId, path, targetIds) {
  var payload = window.ggplotGuiGraphSettingsManagerData || {};
  var graphs = Array.isArray(payload.graphs) ? payload.graphs : [];
  var rows = Array.isArray(payload.rows) ? payload.rows : [];
  var gi = graphs.findIndex(function(g){ return String((g && g.id) || '') === String(sourceId || ''); });
  var row = rows.find(function(r){ return String((r && r.path) || '') === String(path || ''); });
  if (gi < 0 || !row || !Array.isArray(row.rawValues)) return false;
  return window.ggplotGuiApplyGraphSettingValue(sourceId, path, row.rawValues[gi], targetIds, 'graph');
};

window.ggplotGuiRefreshFigureGraphSettings = function(targetIds) {
  targetIds = Array.isArray(targetIds) ? targetIds.map(function(x){ return String(x || ''); }).filter(Boolean) : [];
  if (!targetIds.length || !window.Shiny) return false;
  Shiny.setInputValue('graph_settings_manager_figure_refresh', {
    targetIds: targetIds,
    nonce: Date.now()
  }, {priority:'event'});
  return true;
};

function ggplotGuiGraphSettingsMainWindow(popout) {
  var mainWindow = null;
  try { mainWindow = (popout && (popout.ggplotGuiMainWindow || popout.opener)) || window; } catch(e) {}
  return mainWindow && !mainWindow.closed ? mainWindow : null;
}

function ggplotGuiNormalizeGraphSettingsSelection(graphs) {
  graphs = Array.isArray(graphs) ? graphs : [];
  var known = {};
  graphs.forEach(function(graph) {
    var id = String((graph && graph.id) || '');
    if (id) known[id] = true;
  });

  var current = window.ggplotGuiGraphSettingsSelection || {};
  var next = {};
  Object.keys(known).forEach(function(id) {
    if (!window.ggplotGuiGraphSettingsSelectionInitialized) next[id] = true;
    else next[id] = !!current[id];
  });
  window.ggplotGuiGraphSettingsSelection = next;
  window.ggplotGuiGraphSettingsSelectionInitialized = true;

  var source = window.ggplotGuiGraphSettingsSource;
  if (source && (!known[String(source.graphId || '')] || !String(source.path || ''))) {
    window.ggplotGuiGraphSettingsSource = null;
    window.ggplotGuiGraphSettingsDraftValue = null;
    window.ggplotGuiGraphSettingsDraftDirty = false;
  }
}

function ggplotGuiGraphSettingsSelectedIds() {
  var selected = window.ggplotGuiGraphSettingsSelection || {};
  return Object.keys(selected).filter(function(id) { return !!selected[id]; });
}

function ggplotGuiGraphSettingsEditorValueFromSource(source) {
  if (!source) return null;
  var raw = source.rawValue;
  if (raw === undefined || raw === null) {
    var kind = String(((source.editor || {}).kind) || '');
    return kind === 'boolean' ? false : '';
  }
  return raw;
}

function ggplotGuiSetGraphSettingsSource(source) {
  window.ggplotGuiGraphSettingsSource = source || null;
  window.ggplotGuiGraphSettingsDraftValue = source ? ggplotGuiGraphSettingsEditorValueFromSource(source) : null;
  window.ggplotGuiGraphSettingsDraftDirty = false;
}

function ggplotGuiReadGraphSettingsEditorValue(doc) {
  var source = window.ggplotGuiGraphSettingsSource;
  if (!source) return null;
  var editor = source.editor || {};
  var kind = String(editor.kind || '');
  var input = doc.getElementById('gsm-value-editor-input');
  if (!input) return window.ggplotGuiGraphSettingsDraftValue;
  if (kind === 'boolean') return String(input.value || '') === 'true';
  if (kind === 'number') {
    if (String(input.value || '').trim() === '') return null;
    var n = Number(input.value);
    return Number.isFinite(n) ? n : input.value;
  }
  return String(input.value == null ? '' : input.value);
}

function ggplotGuiWriteGraphSettingsEditorValue(input, value, kind) {
  if (!input) return;
  if (kind === 'boolean') input.value = value === true ? 'true' : 'false';
  else input.value = value == null ? '' : String(value);
}

function ggplotGuiBuildGraphSettingsEditor(doc, source) {
  var host = doc.createElement('div');
  host.className = 'gsm-editor-host';
  if (!source) {
    var note = doc.createElement('span');
    note.className = 'gsm-editor-placeholder';
    note.textContent = '編集する値をクリック';
    host.appendChild(note);
    return host;
  }

  var editor = source.editor || {};
  var kind = String(editor.kind || '');
  var label = doc.createElement('span');
  label.className = 'gsm-editor-label';
  label.textContent = '編集値';
  host.appendChild(label);

  var input;
  if (kind === 'boolean' || kind === 'select') {
    input = doc.createElement('select');
    if (kind === 'boolean') {
      [['true','ON'],['false','OFF']].forEach(function(pair){
        var op = doc.createElement('option'); op.value = pair[0]; op.textContent = pair[1]; input.appendChild(op);
      });
    } else {
      (Array.isArray(editor.choices) ? editor.choices : []).forEach(function(choice){
        var op = doc.createElement('option');
        op.value = String((choice && choice.value) == null ? '' : choice.value);
        op.textContent = String((choice && (choice.label != null ? choice.label : choice.value)) == null ? '' : (choice.label != null ? choice.label : choice.value));
        input.appendChild(op);
      });
    }
  } else {
    input = doc.createElement('input');
    input.type = kind === 'number' ? 'number' : 'text';
    if (kind === 'number') {
      if (editor.min != null) input.min = String(editor.min);
      if (editor.max != null) input.max = String(editor.max);
      if (editor.step != null) input.step = String(editor.step);
    }
    if (kind === 'axis_number') input.placeholder = '空欄 = 自動';
  }
  input.id = 'gsm-value-editor-input';
  input.className = 'gsm-value-editor-input';
  ggplotGuiWriteGraphSettingsEditorValue(input, window.ggplotGuiGraphSettingsDraftValue, kind);
  host.appendChild(input);
  return host;
}

function ggplotGuiUpdateGraphSettingsPopoutToolbar() {
  var popout = window.ggplotGuiGraphSettingsPopout;
  if (!popout || popout.closed) return;
  var doc = popout.document;
  var graphs = ((window.ggplotGuiGraphSettingsManagerData || {}).graphs || []);
  var selectedIds = ggplotGuiGraphSettingsSelectedIds();
  var source = window.ggplotGuiGraphSettingsSource;

  var count = doc.getElementById('gsm-selected-count');
  if (count) count.textContent = '対象 ' + selectedIds.length + ' / ' + graphs.length;

  var allBox = doc.getElementById('gsm-select-all');
  if (allBox) {
    allBox.checked = graphs.length > 0 && selectedIds.length === graphs.length;
    allBox.indeterminate = selectedIds.length > 0 && selectedIds.length < graphs.length;
  }

  var sourceText = doc.getElementById('gsm-source-summary');
  if (sourceText) {
    sourceText.textContent = source ?
      ('編集中: ' + String(source.graphName || source.graphId || '') + ' / ' + String(source.label || '') +
       ' [' + (source.origin === 'figure' ? 'Figure' : 'Graph') + ']') :
      'Graph値またはFigure値をクリックして編集';
  }

  var selectedFigureIds = selectedIds.filter(function(id){
    var graph = graphs.find(function(g){ return String((g && g.id) || '') === id; });
    return !!(graph && graph.inFigure);
  });
  var buttons = [
    ['gsm-apply-graph', !!source && selectedIds.length > 0],
    ['gsm-apply-figure', !!source && selectedFigureIds.length > 0],
    ['gsm-apply-both', !!source && selectedIds.length > 0],
    ['gsm-refresh-figure', selectedFigureIds.length > 0]
  ];
  buttons.forEach(function(pair){ var b = doc.getElementById(pair[0]); if (b) b.disabled = !pair[1]; });

  var refresh = doc.getElementById('gsm-refresh-figure');
  if (refresh) refresh.textContent = 'FigureをGraphから更新 (' + selectedFigureIds.length + ')';
  var clear = doc.getElementById('gsm-clear-source');
  if (clear) clear.disabled = !source;
}

function ggplotGuiInitGraphSettingsPopout(popout) {
  if (!popout || popout.closed) return false;
  var doc = popout.document;
  doc.open();
  doc.write([
    '<!doctype html><html><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>Graph / Figure Settings Manager</title>',
    '<style>',
    'html,body{margin:0;padding:0;background:#f6f7f9;color:#222;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI","Yu Gothic UI","Meiryo",sans-serif;font-size:13px;}',
    '.gsm-shell{height:100vh;display:flex;flex-direction:column;overflow:hidden;}',
    '.gsm-head{display:flex;align-items:center;gap:12px;padding:11px 14px;background:#fff;border-bottom:1px solid #d8dde3;box-shadow:0 1px 3px rgba(0,0,0,.04);}',
    '.gsm-title{font-size:16px;font-weight:700;white-space:nowrap;}',
    '.gsm-note{color:#6b7280;font-size:12px;flex:1;}',
    '.gsm-close,.gsm-tool-btn{border:1px solid #cbd2d9;background:#fff;border-radius:5px;padding:5px 10px;cursor:pointer;}',
    '.gsm-tool-btn:disabled{opacity:.45;cursor:not-allowed;}',
    '.gsm-primary{background:#337ab7;border-color:#2e6da4;color:#fff;font-weight:600;}',
    '.gsm-figure-btn{background:#fff8e8;border-color:#d8a442;color:#805c12;font-weight:600;}',
    '.gsm-both-btn{background:#5b4aa3;border-color:#4c3c8c;color:#fff;font-weight:600;}',
    '#gsm-popout-root{flex:1;min-height:0;padding:12px;display:flex;flex-direction:column;gap:8px;}',
    '.gsm-empty{padding:18px;background:#fff;border:1px solid #dfe3e8;border-radius:6px;}',
    '.gsm-tools{display:flex;align-items:center;flex-wrap:wrap;gap:7px 9px;background:#fff;border:1px solid #dfe3e8;border-radius:6px;padding:8px 10px;}',
    '.gsm-source-summary{min-width:300px;color:#4b5563;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;}',
    '.gsm-selected-count{font-weight:600;white-space:nowrap;}',
    '.gsm-editor-host{display:flex;align-items:center;gap:5px;min-width:220px;}',
    '.gsm-editor-label{font-size:11px;color:#667085;font-weight:600;}',
    '.gsm-editor-placeholder{color:#8a929b;font-size:12px;}',
    '.gsm-feedback{display:none;padding:6px 9px;border-radius:5px;font-size:12px;font-weight:600;}',
    '.gsm-feedback-ok{display:block;background:#edf8ef;border:1px solid #a7d8ad;color:#276734;}',
    '.gsm-feedback-error{display:block;background:#fff0f0;border:1px solid #e2aaaa;color:#9b2c2c;}',
    '.gsm-value-editor-input{min-width:120px;max-width:210px;height:29px;border:1px solid #aeb7c2;border-radius:4px;padding:3px 7px;background:#fff;}',
    '.gsm-scroll{flex:1;min-height:0;overflow:auto;background:#fff;border:1px solid #dfe3e8;border-radius:6px;}',
    '.gsm-table{border-collapse:separate;border-spacing:0;min-width:900px;width:max-content;font-size:12px;}',
    '.gsm-table th,.gsm-table td{padding:6px 8px;border-right:1px solid #eceff2;border-bottom:1px solid #eceff2;white-space:nowrap;vertical-align:middle;}',
    '.gsm-table thead th{position:sticky;top:0;z-index:4;background:#f3f5f7;font-weight:700;}',
    '.gsm-setting-head,.gsm-setting{position:sticky;left:0;z-index:3;min-width:210px;background:#fafbfc;font-weight:600;}',
    '.gsm-setting-head{z-index:6!important;}',
    '.gsm-graph-head{min-width:200px;}',
    '.gsm-graph-title{display:flex;align-items:center;gap:6px;}',
    '.gsm-graph-select{margin:0;}',
    '.gsm-figure-head{display:inline-block;margin-left:4px;padding:1px 5px;border-radius:9px;background:#f7e6b6;color:#7a5a12;font-size:10px;font-weight:600;}',
    '.gsm-shared-head,.gsm-shared{display:inline-block;margin-left:5px;padding:1px 5px;border-radius:9px;background:#d9edf7;color:#31708f;font-size:10px;font-weight:600;}',
    '.gsm-group th{position:sticky;left:0;z-index:5;background:#e9edf2;font-weight:700;text-align:left;}',
    '.gsm-diff-row .gsm-setting{box-shadow:inset 3px 0 0 #e6a23c;}',
    '.gsm-diff-badge{display:inline-block;margin-left:6px;padding:1px 5px;border-radius:9px;background:#fff1d6;color:#9a6300;font-size:10px;}',
    '.gsm-cell{min-width:200px;}',
    '.gsm-value-line{display:flex;align-items:center;gap:5px;min-height:23px;border-radius:4px;padding:1px 3px;}',
    '.gsm-sourceable{cursor:pointer;}',
    '.gsm-sourceable:hover{background:#f2f8fd;}',
    '.gsm-source-selected{background:#dff0ff!important;box-shadow:inset 0 0 0 2px #337ab7;}',
    '.gsm-target-diff{background:#fff4e5;}',
    '.gsm-target-match{background:#eef8ee;}',
    '.gsm-origin{display:inline-block;min-width:15px;font-size:10px;font-weight:700;color:#667085;}',
    '.gsm-figure-line{margin-top:2px;color:#71561a;background:#fffdf6;}',
    '.gsm-figure-diff{box-shadow:inset 3px 0 0 #d6a338;background:#fff8e8;}',
    '.gsm-figure-unknown{color:#9c8f6d;font-style:italic;}',
    '.gsm-value{display:inline-block;max-width:128px;overflow:hidden;text-overflow:ellipsis;vertical-align:middle;}',
    '.gsm-jump{margin-left:auto;border:1px solid #cbd2d9;background:#fff;border-radius:4px;padding:0 6px;line-height:20px;cursor:pointer;color:#23527c;}',
    '.gsm-jump:hover{background:#eef5fb;border-color:#9bbbd6;}',
    '.gsm-readonly{color:#9aa1a9;font-size:10px;margin-left:5px;}',
    '</style></head><body>',
    '<div class="gsm-shell"><div class="gsm-head">',
    '<div class="gsm-title">Graph / Figure Settings Manager</div>',
    '<div class="gsm-note">G = GraphState、F = Figure-owned state。値を直接編集して Graph / Figure / 両方へ明示適用できます。</div>',
    '<button type="button" class="gsm-close" id="gsm-popout-close">閉じる</button>',
    '</div><div id="gsm-popout-root"><div class="gsm-empty">設定一覧を読み込み中…</div></div></div>',
    '</body></html>'
  ].join(''));
  doc.close();
  doc.documentElement.setAttribute('data-ggplot-settings-popout', '1');
  try { popout.ggplotGuiMainWindow = window; } catch(e) {}

  function applyEditedValue(scope) {
    var source = window.ggplotGuiGraphSettingsSource;
    if (!source) return;
    var selected = ggplotGuiGraphSettingsSelectedIds();
    if (!selected.length) return;
    var editorInput = doc.getElementById('gsm-value-editor-input');
    if (editorInput && typeof editorInput.checkValidity === 'function' && !editorInput.checkValidity()) {
      try { editorInput.reportValidity(); } catch(e) {}
      var validationMessage = editorInput.validationMessage || '入力値が許容範囲外です。';
      ggplotGuiSetGraphSettingsFeedback(false, validationMessage);
      return;
    }
    var value = ggplotGuiReadGraphSettingsEditorValue(doc);
    window.ggplotGuiGraphSettingsDraftValue = value;
    ggplotGuiSetGraphSettingsFeedback(true, '');
    var payloadNow = window.ggplotGuiGraphSettingsManagerData || {};
    var graphsNow = Array.isArray(payloadNow.graphs) ? payloadNow.graphs : [];
    var figureTargets = selected.filter(function(id){
      var g = graphsNow.find(function(rec){ return String((rec && rec.id) || '') === id; });
      return !!(g && g.inFigure);
    });
    var targetIds = scope === 'figure' ? figureTargets : selected;
    if (!targetIds.length) return;
    var scopeLabel = scope === 'graph' ? 'Graph' : (scope === 'figure' ? 'Figureだけ' : 'Graph + Figure');
    var msg = String(source.label || '設定') + ' = ' + String(value == null ? '' : value) +
      '\nを ' + targetIds.length + ' 件の ' + scopeLabel + ' へ反映しますか？';
    if (scope === 'figure') msg += '\n\nGraphStateは変更しません。';
    if (scope === 'both') msg += '\n\nGraphStateとFigure-owned stateの両方を更新します。';
    var rowNow = (Array.isArray(payloadNow.rows) ? payloadNow.rows : []).find(function(r){ return String((r && r.path) || '') === String(source.path || ''); });
    if (rowNow && Array.isArray(rowNow.shared)) {
      var linkedTargets = targetIds.filter(function(id){
        var idx = graphsNow.findIndex(function(g){ return String((g && g.id) || '') === id; });
        return idx >= 0 && String(rowNow.shared[idx] || '') !== '';
      });
      if (linkedTargets.length) msg += '\n\nShared表示中の ' + linkedTargets.length + ' GraphはLibrary bindingを維持するため、後のLibrary更新でこの値が上書きされることがあります。';
    }
    if (!popout.confirm(msg)) return;
    var mainWindow = ggplotGuiGraphSettingsMainWindow(popout);
    if (!mainWindow) return;
    var delivered = false;
    try {
      if (typeof mainWindow.ggplotGuiApplyGraphSettingValue === 'function') {
        delivered = !!mainWindow.ggplotGuiApplyGraphSettingValue(source.graphId, source.path, value, targetIds, scope);
      }
    } catch(e) {}
    if (!delivered) {
      try { mainWindow.postMessage({type:'ggplot-gui-settings-value-apply',sourceId:source.graphId,path:source.path,value:value,targetIds:targetIds,scope:scope}, '*'); } catch(e) {}
    }
  }

  doc.addEventListener('click', function(event) {
    var closeBtn = event.target && event.target.closest ? event.target.closest('#gsm-popout-close') : null;
    if (closeBtn) { popout.close(); return; }

    var jump = event.target && event.target.closest ? event.target.closest('.gsm-jump') : null;
    if (jump) {
      event.preventDefault(); event.stopPropagation();
      var targetId = String(jump.getAttribute('data-graph-id') || '');
      var sectionKey = String(jump.getAttribute('data-section') || '');
      var inputId = String(jump.getAttribute('data-input') || '');
      var mainWindow = ggplotGuiGraphSettingsMainWindow(popout);
      if (!mainWindow) return;
      var delivered = false;
      try {
        if (typeof mainWindow.ggplotGuiJumpToGraphSetting === 'function') {
          mainWindow.ggplotGuiJumpToGraphSetting(targetId, sectionKey, inputId);
          delivered = true;
        }
      } catch(e) {}
      if (!delivered) {
        try { mainWindow.postMessage({type:'ggplot-gui-settings-jump',id:targetId,sectionKey:sectionKey,inputId:inputId}, '*'); } catch(e) {}
      }
      try { mainWindow.focus(); } catch(e) {}
      return;
    }

    var clearSource = event.target && event.target.closest ? event.target.closest('#gsm-clear-source') : null;
    if (clearSource) {
      ggplotGuiSetGraphSettingsSource(null);
      ggplotGuiRenderGraphSettingsPopout();
      return;
    }

    var sourceValue = event.target && event.target.closest ? event.target.closest('.gsm-sourceable') : null;
    if (sourceValue) {
      event.preventDefault();
      var rawText = sourceValue.getAttribute('data-raw-json');
      var rawValue = null;
      try { rawValue = JSON.parse(rawText || 'null'); } catch(e) { rawValue = sourceValue.getAttribute('data-value') || ''; }
      var editorText = sourceValue.getAttribute('data-editor-json');
      var editor = {};
      try { editor = JSON.parse(editorText || '{}') || {}; } catch(e) {}
      ggplotGuiSetGraphSettingsSource({
        graphId: String(sourceValue.getAttribute('data-graph-id') || ''),
        graphName: String(sourceValue.getAttribute('data-graph-name') || ''),
        path: String(sourceValue.getAttribute('data-path') || ''),
        label: String(sourceValue.getAttribute('data-label') || ''),
        value: String(sourceValue.getAttribute('data-value') || '—'),
        rawValue: rawValue,
        origin: String(sourceValue.getAttribute('data-origin') || 'graph'),
        editor: editor
      });
      ggplotGuiRenderGraphSettingsPopout();
      return;
    }

    if (event.target && event.target.closest && event.target.closest('#gsm-apply-graph')) { applyEditedValue('graph'); return; }
    if (event.target && event.target.closest && event.target.closest('#gsm-apply-figure')) { applyEditedValue('figure'); return; }
    if (event.target && event.target.closest && event.target.closest('#gsm-apply-both')) { applyEditedValue('both'); return; }

    var refreshFigure = event.target && event.target.closest ? event.target.closest('#gsm-refresh-figure') : null;
    if (refreshFigure) {
      var selected = ggplotGuiGraphSettingsSelectedIds();
      var payloadNow = window.ggplotGuiGraphSettingsManagerData || {};
      var graphsNow = Array.isArray(payloadNow.graphs) ? payloadNow.graphs : [];
      var targets = selected.filter(function(id){
        var g = graphsNow.find(function(rec){ return String((rec && rec.id) || '') === id; });
        return !!(g && g.inFigure);
      });
      if (!targets.length) return;
      if (!popout.confirm('選択した ' + targets.length + ' GraphのFigure snapshotを、現在のGraphStateから更新しますか？\n\nFigure側だけ更新し、GraphStateは変更しません。Figure固有のGraph設定は現在のGraphStateへ置き換わります。')) return;
      var mainWindow = ggplotGuiGraphSettingsMainWindow(popout);
      if (!mainWindow) return;
      var deliveredRefresh = false;
      try {
        if (typeof mainWindow.ggplotGuiRefreshFigureGraphSettings === 'function') {
          deliveredRefresh = !!mainWindow.ggplotGuiRefreshFigureGraphSettings(targets);
        }
      } catch(e) {}
      if (!deliveredRefresh) {
        try { mainWindow.postMessage({type:'ggplot-gui-settings-figure-refresh',targetIds:targets}, '*'); } catch(e) {}
      }
      return;
    }
  });

  doc.addEventListener('change', function(event) {
    var target = event.target;
    if (!target) return;
    if (target.id === 'gsm-select-all') {
      var checked = !!target.checked;
      var graphs = ((window.ggplotGuiGraphSettingsManagerData || {}).graphs || []);
      graphs.forEach(function(graph) {
        var id = String((graph && graph.id) || '');
        if (id) window.ggplotGuiGraphSettingsSelection[id] = checked;
      });
      ggplotGuiRenderGraphSettingsPopout();
      return;
    }
    if (target.classList && target.classList.contains('gsm-graph-select')) {
      var id = String(target.getAttribute('data-graph-id') || '');
      if (id) window.ggplotGuiGraphSettingsSelection[id] = !!target.checked;
      ggplotGuiRenderGraphSettingsPopout();
      return;
    }
    if (target.id === 'gsm-value-editor-input') {
      window.ggplotGuiGraphSettingsDraftValue = ggplotGuiReadGraphSettingsEditorValue(doc);
      window.ggplotGuiGraphSettingsDraftDirty = true;
    }
  });
  doc.addEventListener('input', function(event) {
    if (event.target && event.target.id === 'gsm-value-editor-input') {
      window.ggplotGuiGraphSettingsDraftValue = ggplotGuiReadGraphSettingsEditorValue(doc);
      window.ggplotGuiGraphSettingsDraftDirty = true;
    }
  });

  popout.addEventListener('beforeunload', function() {
    if (window.ggplotGuiGraphSettingsPopout === popout) window.ggplotGuiGraphSettingsPopout = null;
  });
  return true;
}

function ggplotGuiRenderGraphSettingsPopout() {
  var popout = window.ggplotGuiGraphSettingsPopout;
  if (!popout || popout.closed) return;
  var doc = popout.document;
  var root = doc.getElementById('gsm-popout-root');
  if (!root) return;

  var previousScroll = root.querySelector('.gsm-scroll');
  var scrollTop = previousScroll ? previousScroll.scrollTop : 0;
  var scrollLeft = previousScroll ? previousScroll.scrollLeft : 0;
  while (root.firstChild) root.removeChild(root.firstChild);

  var payload = window.ggplotGuiGraphSettingsManagerData || {};
  var graphs = Array.isArray(payload.graphs) ? payload.graphs : [];
  var rows = Array.isArray(payload.rows) ? payload.rows : [];
  if (!graphs.length) {
    var empty = doc.createElement('div');
    empty.className = 'gsm-empty';
    empty.textContent = 'Graphがありません。';
    root.appendChild(empty);
    return;
  }
  ggplotGuiNormalizeGraphSettingsSelection(graphs);

  var liveSource = window.ggplotGuiGraphSettingsSource;
  if (liveSource) {
    var liveGraphIndex = graphs.findIndex(function(g){ return String((g && g.id) || '') === String(liveSource.graphId || ''); });
    var liveRow = rows.find(function(r){ return String((r && r.path) || '') === String(liveSource.path || ''); });
    if (liveGraphIndex >= 0 && liveRow) {
      liveSource.graphName = String((graphs[liveGraphIndex] && (graphs[liveGraphIndex].name || graphs[liveGraphIndex].id)) || liveSource.graphId || '');
      liveSource.label = String(liveRow.label || liveSource.label || '');
      liveSource.editor = liveRow.editor || liveSource.editor || {};
      var figureOrigin = liveSource.origin === 'figure';
      var rawList = figureOrigin ? liveRow.figureRawValues : liveRow.rawValues;
      var valueList = figureOrigin ? liveRow.figureValues : liveRow.values;
      if (!window.ggplotGuiGraphSettingsDraftDirty && Array.isArray(rawList)) {
        liveSource.rawValue = rawList[liveGraphIndex];
        window.ggplotGuiGraphSettingsDraftValue = ggplotGuiGraphSettingsEditorValueFromSource(liveSource);
      }
      if (Array.isArray(valueList) && valueList[liveGraphIndex] != null) liveSource.value = String(valueList[liveGraphIndex]);
      window.ggplotGuiGraphSettingsSource = liveSource;
    }
  }

  var tools = doc.createElement('div');
  tools.className = 'gsm-tools';
  var selectAll = doc.createElement('input');
  selectAll.type = 'checkbox'; selectAll.id = 'gsm-select-all'; tools.appendChild(selectAll);
  var selectAllLabel = doc.createElement('label');
  selectAllLabel.htmlFor = 'gsm-select-all'; selectAllLabel.textContent = '全Graph'; tools.appendChild(selectAllLabel);
  var selectedCount = doc.createElement('span');
  selectedCount.id = 'gsm-selected-count'; selectedCount.className = 'gsm-selected-count'; tools.appendChild(selectedCount);
  var sourceSummary = doc.createElement('span');
  sourceSummary.id = 'gsm-source-summary'; sourceSummary.className = 'gsm-source-summary'; tools.appendChild(sourceSummary);
  tools.appendChild(ggplotGuiBuildGraphSettingsEditor(doc, window.ggplotGuiGraphSettingsSource));
  var clearSource = doc.createElement('button');
  clearSource.type = 'button'; clearSource.id = 'gsm-clear-source'; clearSource.className = 'gsm-tool-btn'; clearSource.textContent = '編集解除'; tools.appendChild(clearSource);
  var applyGraph = doc.createElement('button');
  applyGraph.type = 'button'; applyGraph.id = 'gsm-apply-graph'; applyGraph.className = 'gsm-tool-btn gsm-primary'; applyGraph.textContent = 'Graphへ適用'; tools.appendChild(applyGraph);
  var applyFigure = doc.createElement('button');
  applyFigure.type = 'button'; applyFigure.id = 'gsm-apply-figure'; applyFigure.className = 'gsm-tool-btn gsm-figure-btn'; applyFigure.textContent = 'Figureだけへ適用'; tools.appendChild(applyFigure);
  var applyBoth = doc.createElement('button');
  applyBoth.type = 'button'; applyBoth.id = 'gsm-apply-both'; applyBoth.className = 'gsm-tool-btn gsm-both-btn'; applyBoth.textContent = 'Graph + Figure'; tools.appendChild(applyBoth);
  var refreshFigure = doc.createElement('button');
  refreshFigure.type = 'button'; refreshFigure.id = 'gsm-refresh-figure'; refreshFigure.className = 'gsm-tool-btn gsm-figure-btn'; refreshFigure.textContent = 'FigureをGraphから更新'; tools.appendChild(refreshFigure);
  root.appendChild(tools);
  var feedback = doc.createElement('div');
  feedback.id = 'gsm-feedback';
  var fb = window.ggplotGuiGraphSettingsFeedback || {ok:true, message:''};
  feedback.textContent = String(fb.message || '');
  feedback.className = 'gsm-feedback ' + (fb.ok ? 'gsm-feedback-ok' : 'gsm-feedback-error');
  feedback.style.display = fb.message ? 'block' : 'none';
  root.appendChild(feedback);

  var scroll = doc.createElement('div');
  scroll.className = 'gsm-scroll';
  var table = doc.createElement('table'); table.className = 'gsm-table';
  var thead = doc.createElement('thead'); var headRow = doc.createElement('tr');
  var settingHead = doc.createElement('th'); settingHead.className = 'gsm-setting-head'; settingHead.textContent = '設定'; headRow.appendChild(settingHead);
  graphs.forEach(function(graph) {
    var th = doc.createElement('th'); th.className = 'gsm-graph-head';
    var head = doc.createElement('div'); head.className = 'gsm-graph-title';
    var checkbox = doc.createElement('input'); checkbox.type = 'checkbox'; checkbox.className = 'gsm-graph-select';
    checkbox.setAttribute('data-graph-id', String((graph && graph.id) || ''));
    checkbox.checked = !!window.ggplotGuiGraphSettingsSelection[String((graph && graph.id) || '')]; head.appendChild(checkbox);
    var name = doc.createElement('span'); name.textContent = String((graph && (graph.name || graph.id)) || 'Graph'); head.appendChild(name);
    if (graph && graph.inFigure) {
      var figHead = doc.createElement('span'); figHead.className = 'gsm-figure-head'; figHead.textContent = graph.figureEditable ? 'Figure' : 'Figure snapshot';
      figHead.title = graph.figureEditable ? 'Figure-owned GraphStateあり' : 'Figureには配置済みですがeditable stateがありません'; head.appendChild(figHead);
    }
    if (graph && graph.sharedEnabled) {
      var sharedHead = doc.createElement('span'); sharedHead.className = 'gsm-shared-head'; sharedHead.textContent = 'Shared ' + Number(graph.sharedLinks || 0); sharedHead.title = 'Shared Library binding数'; head.appendChild(sharedHead);
    }
    th.appendChild(head); headRow.appendChild(th);
  });
  thead.appendChild(headRow); table.appendChild(thead);

  var source = window.ggplotGuiGraphSettingsSource;
  var sourceGraphIndex = source ? graphs.findIndex(function(g){ return String((g && g.id) || '') === String(source.graphId || ''); }) : -1;
  var tbody = doc.createElement('tbody'); var previousGroup = '';
  rows.forEach(function(row) {
    row = row || {};
    var group = String(row.group || '');
    if (group !== previousGroup) {
      var groupRow = doc.createElement('tr'); groupRow.className = 'gsm-group';
      var groupCell = doc.createElement('th'); groupCell.colSpan = graphs.length + 1; groupCell.textContent = group; groupRow.appendChild(groupCell); tbody.appendChild(groupRow); previousGroup = group;
    }
    var tr = doc.createElement('tr'); if (!row.allEqual) tr.className = 'gsm-diff-row';
    var label = doc.createElement('th'); label.className = 'gsm-setting'; label.appendChild(doc.createTextNode(String(row.label || '')));
    if (!row.allEqual) { var diffBadge = doc.createElement('span'); diffBadge.className = 'gsm-diff-badge'; diffBadge.textContent = '差あり'; label.appendChild(diffBadge); }
    if (!row.canApply) { var readonly = doc.createElement('span'); readonly.className = 'gsm-readonly'; readonly.textContent = '比較のみ'; label.appendChild(readonly); }
    tr.appendChild(label);

    var values = Array.isArray(row.values) ? row.values : [];
    var rawValues = Array.isArray(row.rawValues) ? row.rawValues : [];
    var keys = Array.isArray(row.keys) ? row.keys : [];
    var figureValues = Array.isArray(row.figureValues) ? row.figureValues : [];
    var figureRawValues = Array.isArray(row.figureRawValues) ? row.figureRawValues : [];
    var figureKeys = Array.isArray(row.figureKeys) ? row.figureKeys : [];
    var figureDiffers = Array.isArray(row.figureDiffers) ? row.figureDiffers : [];
    var shared = Array.isArray(row.shared) ? row.shared : [];
    var editorJson = '{}'; try { editorJson = JSON.stringify(row.editor || {}); } catch(e) {}
    var sourceKey = null;
    if (source && String(source.path || '') === String(row.path || '') && sourceGraphIndex >= 0) {
      sourceKey = source.origin === 'figure' ? String(figureKeys[sourceGraphIndex] || '') : String(keys[sourceGraphIndex] || '');
    }

    graphs.forEach(function(graph, index) {
      var graphId = String((graph && graph.id) || '');
      var td = doc.createElement('td'); td.className = 'gsm-cell';
      if (sourceKey !== null && !!window.ggplotGuiGraphSettingsSelection[graphId] && graphId !== String(source.graphId || '')) {
        var targetKey = source.origin === 'figure' ? String(figureKeys[index] || '') : String(keys[index] || '');
        td.classList.add(targetKey === sourceKey ? 'gsm-target-match' : 'gsm-target-diff');
      }

      function addValueLine(origin, displayValue, rawValue, available, differs) {
        var line = doc.createElement('div');
        line.className = 'gsm-value-line ' + (origin === 'figure' ? 'gsm-figure-line' : 'gsm-graph-line');
        if (origin === 'figure' && differs) line.classList.add('gsm-figure-diff');
        var isSelected = !!source && graphId === String(source.graphId || '') && String(row.path || '') === String(source.path || '') && String(source.origin || 'graph') === origin;
        if (row.canApply && available) line.classList.add('gsm-sourceable');
        if (isSelected) line.classList.add('gsm-source-selected');
        line.setAttribute('data-graph-id', graphId);
        line.setAttribute('data-graph-name', String((graph && (graph.name || graph.id)) || graphId));
        line.setAttribute('data-path', String(row.path || ''));
        line.setAttribute('data-label', String(row.label || ''));
        line.setAttribute('data-value', String(displayValue == null ? '—' : displayValue));
        line.setAttribute('data-origin', origin);
        line.setAttribute('data-editor-json', editorJson);
        var rawJson = 'null'; try { rawJson = JSON.stringify(rawValue === undefined ? null : rawValue); } catch(e) {}
        line.setAttribute('data-raw-json', rawJson);
        var badge = doc.createElement('span'); badge.className = 'gsm-origin'; badge.textContent = origin === 'figure' ? 'F' : 'G'; line.appendChild(badge);
        var value = doc.createElement('span'); value.className = 'gsm-value';
        value.textContent = available ? String(displayValue == null ? '—' : displayValue) : 'snapshot / 値未取得';
        if (!available) value.classList.add('gsm-figure-unknown');
        value.title = row.canApply && available ? 'クリックして外部ウィンドウで編集' : value.textContent; line.appendChild(value);
        if (origin === 'graph' && String(shared[index] || '')) {
          var sharedBadge = doc.createElement('span'); sharedBadge.className = 'gsm-shared'; sharedBadge.textContent = 'Shared'; sharedBadge.title = 'Shared Library: ' + String(shared[index]); line.appendChild(sharedBadge);
        }
        if (origin === 'graph') {
          var jump = doc.createElement('button'); jump.type = 'button'; jump.className = 'gsm-jump'; jump.textContent = '↗'; jump.title = 'このGraphの設定欄をメイン画面で開く';
          jump.setAttribute('data-graph-id', graphId); jump.setAttribute('data-section', String(row.section || '')); jump.setAttribute('data-input', String(row.input || '')); line.appendChild(jump);
        }
        td.appendChild(line);
      }

      addValueLine('graph', values[index], rawValues[index], true, false);
      if (graph && graph.inFigure) addValueLine('figure', figureValues[index], figureRawValues[index], !!graph.figureEditable, !!figureDiffers[index]);
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
  table.appendChild(tbody); scroll.appendChild(table); root.appendChild(scroll);
  scroll.scrollTop = scrollTop; scroll.scrollLeft = scrollLeft;
  ggplotGuiUpdateGraphSettingsPopoutToolbar();
}

window.ggplotGuiOpenGraphSettingsPopout = function() {
  var popout = window.ggplotGuiGraphSettingsPopout;
  var acquiredWindow = false;
  if (!popout || popout.closed) {
    popout = window.open('', 'ggplotGuiGraphSettingsManager', 'popup=yes,width=1460,height=900,resizable=yes,scrollbars=yes');
    if (!popout) {
      window.alert('別ウィンドウを開けませんでした。ブラウザのポップアップ許可を確認してください。');
      return false;
    }
    window.ggplotGuiGraphSettingsPopout = popout;
    acquiredWindow = true;
  }
  var marker = null;
  try { marker = popout.document && popout.document.documentElement && popout.document.documentElement.getAttribute('data-ggplot-settings-popout'); } catch(e) {}
  if (acquiredWindow || marker !== '1') ggplotGuiInitGraphSettingsPopout(popout);
  ggplotGuiRenderGraphSettingsPopout();
  try { popout.focus(); } catch(e) {}
  return false;
};

window.addEventListener('message', function(event) {
  var msg = event && event.data ? event.data : {};
  var type = String(msg.type || '');
  var popout = window.ggplotGuiGraphSettingsPopout;
  if (popout && !popout.closed && event.source !== popout) return;
  if (type === 'ggplot-gui-settings-jump') {
    try { window.focus(); } catch(e) {}
    window.ggplotGuiJumpToGraphSetting(String(msg.id || ''), String(msg.sectionKey || ''), String(msg.inputId || ''));
    return;
  }
  if (type === 'ggplot-gui-settings-apply') {
    window.ggplotGuiApplyGraphSettingBatch(String(msg.sourceId || ''), String(msg.path || ''), Array.isArray(msg.targetIds) ? msg.targetIds : []);
    return;
  }
  if (type === 'ggplot-gui-settings-value-apply') {
    window.ggplotGuiApplyGraphSettingValue(String(msg.sourceId || ''), String(msg.path || ''), msg.value,
      Array.isArray(msg.targetIds) ? msg.targetIds : [], String(msg.scope || 'graph'));
    return;
  }
  if (type === 'ggplot-gui-settings-figure-refresh') {
    window.ggplotGuiRefreshFigureGraphSettings(Array.isArray(msg.targetIds) ? msg.targetIds : []);
  }
});

Shiny.addCustomMessageHandler('graph-settings-manager-feedback', function(msg) {
  msg = msg || {};
  ggplotGuiSetGraphSettingsFeedback(!!msg.ok, String(msg.message || ''));
});

Shiny.addCustomMessageHandler('graph-settings-manager-data', function(msg) {
  window.ggplotGuiGraphSettingsManagerData = msg || {graphs: [], rows: []};
  ggplotGuiRenderGraphSettingsPopout();
});
