(function () {
  if (window.graphPlotFilterEventsInstalled) return;
  window.graphPlotFilterEventsInstalled = true;

  var pendingValueTimers = new Map();

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
  function cancelQueuedValues(body) {
    var key = bodyKey(body);
    if (!key || !pendingValueTimers.has(key)) return;
    window.clearTimeout(pendingValueTimers.get(key));
    pendingValueTimers.delete(key);
  }
  function queueValues(el, body) {
    var key = bodyKey(body);
    if (!key) return;
    cancelQueuedValues(body);
    pendingValueTimers.set(key, window.setTimeout(function () {
      pendingValueTimers.delete(key);
      // Read the live DOM only when the burst has settled. This keeps rapid
      // checkbox/select edits local and sends one complete value set, avoiding
      // server renderUI responses that can visually rewind a later click.
      if (!document.body.contains(body)) return;
      send(el, {action: 'set', column: body.dataset.column, field: 'values', value: values(body)});
    }, 220));
  }

  document.addEventListener('change', function (evt) {
    var el = evt.target, box = root(el);
    if (!box) return;
    var body = el.closest('[data-column]');
    var field = el.dataset.filterField;
    if (el.dataset.filterAction === 'enabled') {
      send(el, {action: 'enabled', value: el.checked});
    } else if (body && field) {
      if (field === 'values') {
        queueValues(el, body);
      } else {
        send(el, {action: 'set', column: body.dataset.column, field: field,
          value: el.type === 'checkbox' ? el.checked : el.value});
      }
    }
  });

  document.addEventListener('click', function (evt) {
    var el = evt.target.closest('[data-filter-action]');
    if (!el || !root(el) || el.dataset.filterAction === 'enabled') return;
    var action = el.dataset.filterAction, body = el.closest('[data-column]');
    if (action === 'add') {
      var picker = root(el).querySelector('[data-filter-column-picker]');
      if (picker && picker.value) send(el, {action: 'add', column: picker.value});
    } else if (action === 'remove' && body) {
      cancelQueuedValues(body);
      send(el, {action: 'remove', column: body.dataset.column});
    } else if ((action === 'all' || action === 'none') && body) {
      cancelQueuedValues(body);
      body.querySelectorAll('[data-filter-field="values"]').forEach(function (x) {
        if (x.tagName === 'SELECT') Array.from(x.options).forEach(function (o) {o.selected = action === 'all';});
        else x.checked = action === 'all';
      });
      send(el, {action: 'set', column: body.dataset.column, field: 'values', value: values(body)});
    }
  });

  document.addEventListener('input', function (evt) {
    var el = evt.target;
    if (!el.classList.contains('plot-filter-search') || !root(el)) return;
    var select = el.parentElement.querySelector('select[data-filter-field="values"]');
    if (!select) return;
    Array.from(select.options).forEach(function (o) {
      o.hidden = !o.text.toLowerCase().includes(el.value.toLowerCase());
    });
  });
}());
