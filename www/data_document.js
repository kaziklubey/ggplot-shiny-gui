(function() {
  'use strict';

  // One persistent Ace editor, one explicit Graph-owned document lease.
  // Native shinyAce input$text may still exist as a browser binding, but it is
  // not a canonical write path. Every real Data edit is transported here with
  // graphId + generation + seq so delayed events cannot change ownership.
  var st = {
    graphId: '',
    generation: 0,
    seq: 0,
    inputId: '',
    patchInputId: '',
    text: '',
    dirty: false,
    suppress: 0,
    timer: null,
    editor: null,
    boundEditor: null,
    boundHandler: null
  };

  function asString(x) {
    return x == null ? '' : String(x);
  }

  function getEditor(inputId) {
    inputId = asString(inputId || st.inputId);
    if (!inputId || !window.ace || typeof window.ace.edit !== 'function') return null;
    var el = document.getElementById(inputId);
    if (!el) return null;
    try { return window.ace.edit(el); } catch (e) { return null; }
  }

  function clearTimer() {
    if (st.timer !== null) {
      window.clearTimeout(st.timer);
      st.timer = null;
    }
  }

  function currentText() {
    var ed = st.editor || getEditor(st.inputId);
    if (ed && typeof ed.getValue === 'function') {
      try { return asString(ed.getValue()); } catch (e) {}
    }
    return asString(st.text);
  }

  function sendPatch(text, reason) {
    if (!window.Shiny || !st.graphId || !st.patchInputId || !st.generation) return false;
    st.seq += 1;
    window.Shiny.setInputValue(st.patchInputId, {
      graphId: st.graphId,
      generation: Number(st.generation || 0),
      seq: Number(st.seq || 0),
      text: asString(text),
      reason: asString(reason || 'edit'),
      nonce: Date.now()
    }, {priority: 'event'});
    return true;
  }

  function flush(reason) {
    clearTimer();
    if (!st.dirty || !st.graphId) return false;
    var text = currentText();
    var ok = sendPatch(text, reason || 'flush');
    if (ok) {
      st.text = text;
      st.dirty = false;
    }
    return ok;
  }

  function schedulePatch() {
    clearTimer();
    st.timer = window.setTimeout(function() {
      st.timer = null;
      flush('edit-settled');
    }, 220);
  }

  function bindEditor(editor) {
    if (!editor || st.boundEditor === editor) return;
    if (st.boundEditor && st.boundHandler && st.boundEditor.getSession) {
      try { st.boundEditor.getSession().off('change', st.boundHandler); } catch (e) {}
    }
    var handler = function() {
      if (st.suppress > 0) return;
      st.editor = editor;
      st.text = currentText();
      st.dirty = true;
      schedulePatch();
    };
    try {
      editor.getSession().on('change', handler);
      st.boundEditor = editor;
      st.boundHandler = handler;
    } catch (e) {
      st.boundEditor = null;
      st.boundHandler = null;
    }
  }

  function hydrate(msg) {
    msg = msg || {};
    var nextGraph = asString(msg.graphId);
    var nextGeneration = Number(msg.generation || 0);
    if (Number(msg.activationGeneration || 0) !==
        Number(window.ggplotGuiEditorActivationGeneration || 0)) return;
    var inputId = asString(msg.inputId);
    var patchInputId = asString(msg.patchInputId);
    var text = asString(msg.text);
    if (!nextGraph || !nextGeneration || !inputId || !patchInputId) return;

    // If an edit exists for the previous lease, transport it with that old
    // graphId/generation before retargeting this one persistent Ace DOM.
    flush('hydrate-before-retarget');

    clearTimer();
    st.graphId = nextGraph;
    st.generation = nextGeneration;
    st.seq = 0;
    st.inputId = inputId;
    st.patchInputId = patchInputId;
    st.dirty = false;

    var editor = getEditor(inputId);
    st.editor = editor;
    if (!editor) return;
    bindEditor(editor);

    st.suppress += 1;
    try {
      if (asString(editor.getValue()) !== text) editor.setValue(text, -1);
      st.text = text;
      st.dirty = false;
    } finally {
      st.suppress = Math.max(0, st.suppress - 1);
    }
  }

  window.ggplotGuiDataDocumentFlush = flush;
  window.ggplotGuiDataDocumentLease = function() {
    return {
      graphId: st.graphId,
      generation: st.generation,
      seq: st.seq,
      dirty: st.dirty
    };
  };

  // Save actions serialize the canonical registry. Flush the current Data draft
  // in the capture phase so its explicit-owner patch reaches Shiny before the
  // actionButton event that starts project serialization.
  document.addEventListener('click', function(ev) {
    var t = ev && ev.target;
    if (!t) return;
    var btn = t.closest ? t.closest('#save_project_as_all, #overwrite_project_all, #graph_add') : null;
    if (!btn) return;
    flush(btn.id === 'graph_add' ? 'graph-add' : 'project-save');
  }, true);

  if (window.Shiny && typeof window.Shiny.addCustomMessageHandler === 'function') {
    window.Shiny.addCustomMessageHandler('graph-data-document-hydrate', hydrate);
  }
})();
