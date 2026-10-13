// Startup is one display lifecycle, not an interruptible Project transaction.
(function() {
  var plotId = 'graph_editor_single-plot';
  var state = 'loading';
  function overlay() { return document.getElementById('startup_load_overlay'); }
  function finish() {
    if (state !== 'loading') return;
    state = 'ready';
    var panel = overlay();
    if (panel) panel.remove();
    var content = document.getElementById('app_startup_content');
    if (content) content.removeAttribute('inert');
    console.info('STARTUP-DISPLAY READY first plot image loaded');
  }
  function fail(message) {
    var panel = overlay();
    if (state !== 'loading' || !panel) return;
    state = 'failed';
    panel.classList.add('failed');
    panel.querySelector('.project-load-title').textContent = '起動を完了できませんでした';
    panel.querySelector('.project-load-message').textContent = message || 'アプリを再読み込みしてください。';
    console.error('STARTUP-DISPLAY FAILED ' + String(message || ''));
  }
  function imageReady(img) {
    if (state !== 'loading' || !img || !img.complete || img.naturalWidth <= 0) return;
    // Allow the image/layout to reach a browser paint boundary before unlock.
    requestAnimationFrame(function() { requestAnimationFrame(finish); });
  }
  document.addEventListener('load', function(event) {
    var img = event.target;
    if (img && img.tagName === 'IMG' && img.closest('#' + plotId)) imageReady(img);
  }, true);
  document.addEventListener('error', function(event) {
    var img = event.target;
    if (img && img.tagName === 'IMG' && img.closest('#' + plotId)) fail('初期グラフの画像を読み込めませんでした。');
  }, true);
  $(document).on('shiny:value.startupDisplay', function(event) {
    if (state !== 'loading' || event.name !== plotId) return;
    // shiny:value precedes output rendering; inspect the newly applied image
    // on the next frame. The capture load listener handles later image loads.
    requestAnimationFrame(function() {
      var output = document.getElementById(plotId);
      imageReady(output && output.querySelector('img'));
    });
  });
  $(document).on('shiny:error.startupDisplay', function(event) {
    if (event.name === plotId) fail('初期グラフの描画に失敗しました。');
  });
  $(document).on('shiny:disconnected.startupDisplay', function() {
    fail('起動中にサーバーとの接続が切れました。');
  });
  Shiny.addCustomMessageHandler('startup-load-failed', function(message) {
    fail(String((message || {}).message || '初期化に失敗しました。'));
  });
})();
