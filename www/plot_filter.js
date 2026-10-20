(function () {
  if (window.graphPlotFilterEventsInstalled) return;
  window.graphPlotFilterEventsInstalled = true;

  var pendingValueTimers = new Map();
  var VALUE_DEBOUNCE_MS = 2000;

  function root(el) { return el.closest('.plot-filter-root'); }
  function bodyKey(body) {
    var box = root(body);
    if (!box || !body) return '';
    return String(box.dataset.filterInput || '') + '::' + String(body.dataset.column || '');
  }
  function send(el, event) {
    var box = root(el);
    if (!box || !window.Shiny) return;
    event.generation = Number(box.dataset.filterGeneration);
    window.Shiny.setInputValue(box.dataset.filterInput, event, {priority: 'event'});
  }
  function values(body) {
    var select = body.querySelector('select[data-filter-field="values"]');
    if (select) return Array.from(select.selectedOptions).map(function (o) {return o.value;});
    return Array.from(body.querySelectorAll('input[data-filter-field="values"]:checked'))
      .map(function (x) {return x.value;});
  }
  function updateCategoricalSummary(body) {
    if (!body || body.dataset.filterKind !== 'categorical') return;
    var rule = body.closest('.plot-filter-rule');
    var label = rule && rule.querySelector('.plot-filter-rule-summary-state');
    if (!label) return;
    var options = Array.from(body.querySelectorAll('input[data-filter-field="values"]'));
    var count = options.filter(function (x) { return x.checked; }).length;
    var missing = body.querySelector('input[data-filter-field="include_na"]');
    label.textContent = (count === options.length ? '全' + options.length + '値' :
      count + ' / ' + options.length + ' 値') +
      (missing && missing.checked ? ' + 欠損値' : '');
  }
  function cancelQueuedValues(body) {
    var key = bodyKey(body);
    if (!key || !pendingValueTimers.has(key)) return;
    window.clearTimeout(pendingValueTimers.get(key).timer);
    pendingValueTimers.delete(key);
  }
  function flushPendingValues() {
    // Graph-tab navigation and structural edits must preserve the last local
    // selection instead of leaving a timer attached to an obsolete editor DOM.
    pendingValueTimers.forEach(function (entry) {
      window.clearTimeout(entry.timer);
      if (document.body.contains(entry.body))
        send(entry.el, {action: 'set', column: entry.body.dataset.column,
          field: 'values', value: values(entry.body)});
    });
    pendingValueTimers.clear();
  }
  function queueValues(el, body) {
    var key = bodyKey(body);
    if (!key) return;
    cancelQueuedValues(body);
    var timer = window.setTimeout(function () {
      pendingValueTimers.delete(key);
      // Read the live DOM only when the burst has settled. This keeps rapid
      // checkbox/select edits local and sends one complete value set, avoiding
      // server renderUI responses that can visually rewind a later click.
      if (!document.body.contains(body)) return;
      send(el, {action: 'set', column: body.dataset.column, field: 'values', value: values(body)});
    }, VALUE_DEBOUNCE_MS);
    pendingValueTimers.set(key, {timer: timer, el: el, body: body});
  }

  document.addEventListener('change', function (evt) {
    var el = evt.target, box = root(el);
    if (!box) return;
    var body = el.closest('[data-column]');
    var field = el.dataset.filterField;
    if (el.dataset.filterAction === 'enabled') {
      flushPendingValues();
      send(el, {action: 'enabled', value: el.checked});
    } else if (body && field) {
      if (field === 'values') {
        updateCategoricalSummary(body);
        queueValues(el, body);
      } else {
        flushPendingValues();
        if (field === 'include_na') updateCategoricalSummary(body);
        send(el, {action: 'set', column: body.dataset.column, field: field,
          value: el.type === 'checkbox' ? el.checked : el.value});
      }
    }
  });

  document.addEventListener('click', function (evt) {
    if (evt.target.closest('.graph-tab-btn')) flushPendingValues();
  }, true);

  document.addEventListener('click', function (evt) {
    var el = evt.target.closest('[data-filter-action]');
    if (!el || !root(el) || el.dataset.filterAction === 'enabled') return;
    var action = el.dataset.filterAction, body = el.closest('[data-column]');
    if (action === 'add') {
      var picker = root(el).querySelector('[data-filter-column-picker]');
      if (picker && picker.value) {
        flushPendingValues();
        send(el, {action: 'add', column: picker.value});
      }
    } else if (action === 'remove' && body) {
      cancelQueuedValues(body);
      flushPendingValues();
      send(el, {action: 'remove', column: body.dataset.column});
    } else if ((action === 'all' || action === 'none') && body) {
      cancelQueuedValues(body);
      body.querySelectorAll('[data-filter-field="values"]').forEach(function (x) {
        if (x.tagName === 'SELECT') Array.from(x.options).forEach(function (o) {o.selected = action === 'all';});
        else x.checked = action === 'all';
      });
      updateCategoricalSummary(body);
      send(el, {action: 'set', column: body.dataset.column, field: 'values', value: values(body)});
    }
  });

  document.addEventListener('input', function (evt) {
    var el = evt.target;
    if (!el.classList.contains('plot-filter-search') || !root(el)) return;
    var section = el.closest('.plot-filter-value-section');
    if (!section) return;
    var search = el.value.toLowerCase();
    section.querySelectorAll('.plot-filter-value-option').forEach(function (label) {
      label.hidden = !label.textContent.toLowerCase().includes(search);
    });
    var select = section.querySelector('select[data-filter-field="values"]');
    if (select) Array.from(select.options).forEach(function (o) {
      o.hidden = !o.text.toLowerCase().includes(search);
    });
  });
}());
