// A client display boundary only: no ACK, timer, or server gate ownership.
window.ggplotGuiCreateProjectDisplayLifecycle = function(close, fail) {
  var plotId = 'graph_editor_single-plot';
  var pending = null;
  function current(token) {
    return pending === token &&
      Number(window.ggplotGuiEditorActivationGeneration || 0) === token.generation;
  }
  function inspect(img, token) {
    if (!token || !current(token) || !token.src || !img ||
        img.getAttribute('src') !== token.src || !img.complete || img.naturalWidth <= 0) return;
    requestAnimationFrame(function() {
      requestAnimationFrame(function() {
        if (!current(token) || img.getAttribute('src') !== token.src) return;
        pending = null;
        console.info('PROJECT-DISPLAY READY generation=' + token.generation);
        close();
      });
    });
  }
  document.addEventListener('load', function(event) {
    var img = event.target;
    if (img && img.tagName === 'IMG' && img.closest('#' + plotId)) inspect(img, pending);
  }, true);
  document.addEventListener('error', function(event) {
    var img = event.target, token = pending;
    if (token && current(token) && img && img.tagName === 'IMG' &&
        img.closest('#' + plotId) && img.getAttribute('src') === token.src) {
      pending = null;
      fail('選択したGraphの画像を読み込めませんでした。アプリを再読み込みしてください。');
    }
  }, true);
  $(document).on('shiny:value.projectDisplay', function(event) {
    var token = pending;
    if (!token || !current(token) || event.name !== plotId ||
        !event.value || !event.value.src) return;
    token.src = String(event.value.src);
    requestAnimationFrame(function() {
      var output = document.getElementById(plotId);
      inspect(output && output.querySelector('img'), token);
    });
  });
  $(document).on('shiny:error.projectDisplay', function(event) {
    var token = pending;
    if (token && current(token) && event.name === plotId) {
      pending = null;
      fail('選択したGraphの描画に失敗しました。アプリを再読み込みしてください。');
    }
  });
  $(document).on('shiny:disconnected.projectDisplay', function() {
    if (!pending) return;
    pending = null;
    fail('Project表示中に接続が切れました。アプリを再読み込みしてください。');
  });
  return {
    begin: function(message) {
      pending = {generation:Number(message.generation), src:null};
    },
    cancel: function() { pending = null; }
  };
};
