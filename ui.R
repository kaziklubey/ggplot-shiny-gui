shinyUI(fluidPage(
  useShinyjs(),

  tags$head(
    tags$style(HTML("
      .plot-error-wrap,
      .plot-error-wrap pre,
      .plot-error-wrap code,
      .plot-note-wrap,
      .plot-note-wrap * {
        white-space: pre-wrap !important;
        overflow-wrap: anywhere !important;
        word-break: break-word !important;
        max-width: 100% !important;
      }

      .project-manager {
        border: 1px solid #d8d8d8;
        border-radius: 9px;
        padding: 10px 12px;
        margin-bottom: 12px;
        background: #fafafa;
      }

      .top-row {
        display: flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 7px;
        min-height: 38px;
      }
      .top-row > .form-group,
      .top-row .form-group {
        margin-bottom: 0;
      }
      .top-row + .top-row {
        border-top: 1px solid #e5e5e5;
        padding-top: 8px;
        margin-top: 8px;
      }
      .top-label {
        font-weight: 700;
        min-width: 68px;
        margin-right: 2px;
      }

      .project-name-compact {
        width: 180px;
      }
      .project-name-compact .form-group {
        margin: 0;
      }

      .project-action-group {
        display: inline-flex;
        align-items: center;
        gap: 6px;
        flex: 0 0 auto;
      }

      .project-open-compact {
        width: 58px;
        min-width: 58px;
        max-width: 58px;
        height: 34px;
        display: flex;
        align-items: center;
        overflow: hidden;
      }
      .project-open-compact .form-group {
        margin: 0;
        height: 34px;
      }
      .project-open-compact .input-group {
        width: 58px !important;
        min-width: 58px !important;
        max-width: 58px !important;
        height: 34px;
      }
      .project-open-compact .form-control {
        display: none;
      }
      .project-open-compact .input-group-btn,
      .project-open-compact .btn-file {
        width: 58px;
        height: 34px;
      }
      .project-open-compact .input-group-btn .btn,
      .project-open-compact .btn-file {
        width: 58px;
        min-width: 58px;
        max-width: 58px;
        border-radius: 4px;
        height: 34px;
        line-height: 20px;
        padding-left: 10px;
        padding-right: 10px;
      }

      /* fileInput標準の Upload complete バーは使わない。
         Project行には専用の読込/Graph復元表示があるため、ここで二重表示しない。 */
      .project-open-compact .progress,
      .project-open-compact .progress-bar,
      .project-open-compact .help-block {
        display: none !important;
      }

      .project-manager .btn,
      .project-manager .form-control {
        min-height: 34px;
      }

      .remember-save-destination {
        display: inline-flex;
        align-items: center;
        margin-left: 2px;
        white-space: nowrap;
      }

      .remember-save-destination .checkbox {
        margin-top: 0;
        margin-bottom: 0;
      }
.project-autosave-interval .selectize-control,
.project-save-note {
        flex: 1 1 100%;
        margin-left: 72px;
        margin-top: -2px;
        line-height: 1.25;
        color: #666;
        max-width: 900px;
      }

      .project-save-note small {
        font-size: 11px;
      }
.project-progress-inline {
        flex: 1 1 260px;
        min-width: 240px;
        max-width: 520px;
        margin-left: 4px;
      }
      .project-progress-line {
        margin-bottom: 4px;
      }
      .project-progress-line:last-child {
        margin-bottom: 0;
      }
      .project-progress-label {
        font-size: 11px;
        margin-bottom: 2px;
      }
      .compact-progress {
        height: 12px;
        margin-bottom: 0;
      }
      .compact-progress .progress-bar {
        line-height: 12px;
        font-size: 9px;
      }
      .restore-done {
        font-size: 12px;
        color: #3c763d;
        font-weight: 600;
      }

      .graph-tabs-wrap {
        display: inline-flex;
        align-items: center;
        flex-wrap: wrap;
        gap: 5px;
        flex: 1 1 auto;
      }
      .graph-tab-btn {
        margin: 0;
        padding: 6px 12px;
        border: 1px solid #ccc;
        border-radius: 17px;
        background: #fff;
        cursor: pointer;
        font-weight: 400;
      }
      .graph-tab-btn.active {
        background: #ececec;
        border-color: #777;
        font-weight: 700;
      }

      .graph-menu .dropdown-menu {
        min-width: 135px;
      }
      .graph-menu .dropdown-menu > li > a {
        cursor: pointer;
      }

      .inline-select {
        display: inline-block;
        vertical-align: middle;
      }
      .inline-select .form-group {
        margin: 0;
      }
      .export-target {
        width: 155px;
      }
      .export-format {
        width: 90px;
      }
      .export-status {
        font-size: 12px;
        color: #666;
        margin-left: 4px;
      }
      .bulk-choice-box {
        margin-left: 76px;
        margin-top: 5px;
        padding: 6px 10px;
        border-left: 3px solid #ccc;
        background: #fff;
      }
      .bulk-choice-box .form-group {
        margin-bottom: 0;
      }

      .graph-module-panel {
        width: 100%;
      }
      .control-label {
        font-weight: 600;
      }
      .plot-panel {
        background: #fff;
        border: 1px solid #ddd;
        border-radius: 8px;
        padding: 12px;
        box-sizing: border-box;
      }
      /* The plot device keeps its true pixel geometry.
         If the available browser width is narrower, JS scales the whole plot
         uniformly with transform:scale(), so text/points/axes never stretch. */
      .plot-panel .shiny-plot-output {
        transform-origin: top left;
        flex: 0 0 auto;
      }

      .plot-follow,
      .plot-anchor {
        box-sizing: border-box;
      }

      .code-box {
        max-height: 340px;
        overflow-y: auto;
        background: #f7f7f7;
        border-radius: 6px;
        padding: 10px;
      }
      .group-style-box {
        border: 1px solid #e5e5e5;
        border-radius: 7px;
        padding: 10px;
        margin-bottom: 10px;
        background: #fafafa;
      }
      .order-box {
        border-left: 4px solid #bdbdbd;
        padding: 8px 10px;
        margin-bottom: 10px;
        background: #fafafa;
      }
      .help-block {
        color: #666;
        font-size: 12px;
        margin: 3px 0 7px 0;
      }
      .control-section {
        border: 1px solid #dedede;
        border-radius: 7px;
        margin-bottom: 9px;
        background: #fff;
        overflow: visible;
      }
      .control-section > summary {
        cursor: pointer;
        list-style: none;
        font-weight: 700;
        font-size: 15px;
        padding: 11px 12px;
        background: #f7f7f7;
        user-select: none;
      }
      .control-section > summary::-webkit-details-marker {
        display: none;
      }
      .control-section > summary::before {
        content: '▶';
        display: inline-block;
        width: 1.25em;
        font-size: 11px;
        transition: transform 0.12s ease;
      }
      .control-section[open] > summary::before {
        transform: rotate(90deg);
      }
      .control-section > .section-body {
        padding: 12px 12px 4px 12px;
      }

      .control-subsection {
        border: 1px solid #e5e5e5;
        border-radius: 6px;
        margin-bottom: 9px;
        background: #fcfcfc;
        overflow: visible;
      }
      .control-subsection > summary {
        cursor: pointer;
        list-style: none;
        font-weight: 600;
        padding: 8px 9px;
        background: #f5f5f5;
        user-select: none;
      }
      .control-subsection > summary::-webkit-details-marker {
        display: none;
      }
      .control-subsection > summary::before {
        content: '▸';
        display: inline-block;
        width: 1.15em;
        transition: transform 0.12s ease;
      }
      .control-subsection[open] > summary::before {
        transform: rotate(90deg);
      }
      .control-subsection > .subsection-body {
        padding: 10px 10px 2px 10px;
      }

      .graph-statistics-header {
        margin-bottom: 14px;
      }
      .statistics-card {
        border: 1px solid #dddddd;
        border-radius: 7px;
        padding: 14px 14px 8px 14px;
        background: #ffffff;
        min-height: 180px;
      }
      .statistics-result-card {
        background: #fafafa;
      }
      .statistics-sidebar-fixed-wrap {
        position: sticky;
        top: 12px;
        z-index: 10;
        background: #ffffff;
        margin-bottom: 10px;
      }
      .statistics-sidebar-reference-wrap {
        position: static;
        margin-bottom: 8px;
        background: #ffffff;
      }
      .statistics-sidebar-reference-box {
        height: clamp(190px, 34vh, 390px);
        min-height: 190px;
        max-height: 390px;
        overflow: hidden;
        position: relative;
      }
      .statistics-sidebar-reference-box .shiny-plot-output {
        width: 100% !important;
        height: 100% !important;
        max-width: 100%;
        display: block;
      }
      @media (max-height: 720px) {
        .statistics-sidebar-reference-box {
          height: 210px;
        }
      }
      @media (min-height: 1000px) {
        .statistics-sidebar-reference-box {
          height: 360px;
        }
      }
      .plot-style-toolbar {
        margin-top: 8px;
        margin-bottom: 10px;
        padding: 8px 10px 4px 10px;
        border: 1px solid #dddddd;
        border-radius: 7px;
        background: #ffffff;
      }
      .plot-style-toolbar-title {
        font-weight: 600;
        margin-bottom: 6px;
      }
      .plot-style-toolbar .form-group {
        margin-bottom: 4px;
      }
      .plot-style-toolbar .btn-block {
        width: 100%;
      }
      .plot-style-toolbar .help-block {
        margin: 2px 0 0 0;
      }

      .statistics-analysis-nav {
        position: sticky;
        top: 0;
        z-index: 20;
        background: #ffffff;
        border: 1px solid #dddddd;
        border-radius: 7px;
        padding: 7px 10px 1px 10px;
        margin-bottom: 10px;
      }
      .statistics-analysis-nav .form-group {
        margin-bottom: 6px;
      }
      .statistics-sidebar-analysis-actions {
        display: flex;
        justify-content: flex-end;
        gap: 5px;
        margin: 4px 0 6px 0;
        flex-wrap: wrap;
      }
      .statistics-sidebar-analysis-actions .btn {
        margin: 0;
      }
      .statistics-result-focus {
        margin-bottom: 12px;
      }
      .statistics-result-scroll {
        height: clamp(360px, 58vh, 720px);
        overflow-y: auto;
        overflow-x: auto;
        border: 1px solid #dddddd;
        border-radius: 4px;
        background: #ffffff;
      }
      .statistics-result-scroll pre {
        margin: 0;
        border: 0;
        border-radius: 0;
        min-height: 100%;
      }
      .statistics-sidebar-analysis-details {
        border: 1px solid #dddddd;
        border-radius: 7px;
        background: #ffffff;
        margin: 10px 0 10px 0;
        overflow: hidden;
        clear: both;
      }
      .statistics-sidebar-analysis-details > summary {
        cursor: pointer;
        list-style: none;
        font-weight: 600;
        padding: 9px 10px;
        background: #f5f5f5;
        user-select: none;
      }
      .statistics-sidebar-analysis-details > summary::-webkit-details-marker {
        display: none;
      }
      .statistics-sidebar-analysis-details > summary::before {
        content: '▸';
        display: inline-block;
        width: 1.15em;
        transition: transform 0.12s ease;
      }
      .statistics-sidebar-analysis-details[open] > summary::before {
        transform: rotate(90deg);
      }
      .statistics-sidebar-analysis-body {
        padding: 10px 10px 2px 10px;
        max-height: clamp(260px, 46vh, 620px);
        overflow-y: auto;
      }
      .statistics-actions {
        padding-top: 1px;
        white-space: nowrap;
      }
      .statistics-actions .btn {
        margin-right: 3px;
      }
      .statistics-link-summary {
        border-left: 3px solid #999999;
        padding: 8px 10px;
        margin-bottom: 12px;
        background: #ffffff;
      }
      .anova-factor-row {
        border-top: 1px solid #eeeeee;
        padding-top: 7px;
        margin-top: 5px;
      }
      .anova-factor-row h5 {
        margin-top: 0;
        margin-bottom: 5px;
      }

      .statistics-empty {
        padding: 14px;
        border: 1px dashed #cccccc;
        border-radius: 6px;
        background: #ffffff;
        color: #666666;
        margin-bottom: 12px;
      }
      .section-toolbar {
        margin-bottom: 10px;
      }
      .section-toolbar .btn {
        margin-right: 5px;
        margin-bottom: 4px;
      }

      .plot-follow.plot-fixed {
        position: fixed;
        top: 10px;
        z-index: 1000;
        background: white;
      }

      @media (max-width: 991px) {
        .plot-follow.plot-fixed {
          position: static;
          max-height: none;
          overflow: visible;
          width: auto !important;
          left: auto !important;
        }
        .project-progress-inline {
          flex-basis: 100%;
          max-width: none;
        }
      }
    ")),

    tags$script(HTML("
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

      window.ggplotGuiApplyPlotScale = function(panel, plot, w, h) {
        if (!panel || !plot || !isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) {
          return false;
        }

        // Keep the Shiny plot at the real device dimensions.
        plot.style.width = w + 'px';
        plot.style.height = h + 'px';
        plot.setAttribute('data-plot-width', String(w));
        plot.setAttribute('data-plot-height', String(h));
        plot.style.transformOrigin = 'top left';

        var panelRect = panel.getBoundingClientRect();

        // Hidden Graphs report width 0. Do not store an artificial 1 px scale.
        // A visible-Graph hook below recalculates the scale after reveal.
        if (!isFinite(panelRect.width) || panelRect.width <= 0) {
          plot.style.transform = 'scale(1)';
          panel.style.height = (h + 26) + 'px';
          return false;
        }

        // plot-panel uses 12 px padding on both sides and a 1 px border
        // on both sides: 24 + 2 = 26 px outside the plot content.
        var availableW = Math.max(1, panelRect.width - 26);
        var scale = Math.min(1, availableW / w);

        plot.style.transform = 'scale(' + scale + ')';

        // transform does not change normal-flow geometry, so explicitly
        // reserve the scaled height and avoid invisible blank space.
        panel.style.height = (h * scale + 26) + 'px';
        return true;
      };

      window.ggplotGuiApplyVisiblePlotScale = function(module) {
        if (!module || module.offsetParent === null) return false;

        var plot = module.querySelector('[id$=\"-plot\"]');
        var panel = module.querySelector('[id$=\"-plot_panel\"]');
        if (!plot || !panel) return false;

        var w = Number(
          plot.getAttribute('data-plot-width') ||
          String(plot.style.width || '').replace('px', '')
        );
        var h = Number(
          plot.getAttribute('data-plot-height') ||
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

      Shiny.addCustomMessageHandler('set-follow-state', function(msg) {
        var el = document.getElementById(msg.id);
        if (el) el.setAttribute('data-follow', msg.value);
      });

      (function() {
        function updatePlotFollow(module) {
          if (!module || module.offsetParent === null) return;

          if (typeof window.ggplotGuiApplyVisiblePlotScale === 'function') {
            window.ggplotGuiApplyVisiblePlotScale(module);
          }

          var anchor = module.querySelector('[id$=\"-plot_anchor\"]');
          var box = module.querySelector('[id$=\"-plot_follow\"]');
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

          var anchor = module.querySelector('[id$=\"-plot_anchor\"]');
          var box = module.querySelector('[id$=\"-plot_follow\"]');
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

        function visibleModule() {
          return document.querySelector(
            '.graph-module-panel:not([style*=\"display: none\"]) .graph-module'
          );
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
            updatePlotFollow(visibleModule());
          }, 0);
        });

        var plotFollowResizeObserver = null;
        if (window.ResizeObserver) {
          plotFollowResizeObserver = new ResizeObserver(function() {
            requestAnimationFrame(function() {
              updatePlotFollow(visibleModule());
            });
          });
        }

        function observeVisiblePlotFollow() {
          if (!plotFollowResizeObserver) return;
          plotFollowResizeObserver.disconnect();
          var module = visibleModule();
          if (!module) return;
          var anchor = module.querySelector('[id$=\"-plot_anchor\"]');
          var box = module.querySelector('[id$=\"-plot_follow\"]');
          var panel = module.querySelector('.plot-panel');
          if (anchor) plotFollowResizeObserver.observe(anchor);
          if (box) plotFollowResizeObserver.observe(box);
          if (panel) plotFollowResizeObserver.observe(panel);
        }

        window.addEventListener('scroll', function() {
          updatePlotFollow(visibleModule());
        }, {passive: true});

        window.addEventListener('resize', function() {
          var module = visibleModule();
          clearStalePlotFollow(module);
          updatePlotFollow(module);

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
          updatePlotFollow(visibleModule());
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

          // saveRDS(..., compress='gzip') produces a gzip stream.
          // Refuse to overwrite an existing Project unless the payload starts
          // with the gzip magic bytes 1F 8B.
          var head = new Uint8Array(await blob.slice(0, 2).arrayBuffer());
          if (head.length < 2 || head[0] !== 0x1f || head[1] !== 0x8b) {
            throw new Error(
              'Project保存データがRDS形式ではないため、上書きを中止しました。'
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
            suggestedName: filename || 'project.ggplotproj',
            types: [{
              description: 'ggplot GUI Project',
              accept: {'application/octet-stream': ['.ggplotproj']}
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
                : (msg.filename || 'MyProject.ggplotproj');

              var selectedProjectName = selectedFileName.replace(/\\.ggplotproj$/i, '');
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
                if (
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

  

          Shiny.addCustomMessageHandler('reset-project-save-handle', function() {
            projectSaveHandle = null;
            projectSaveHandleProject = null;
            reportSaveDestinationAvailable(false, '', '');
            updateSaveDestinationStatus('');
          });
        }
      })();
    "))
  ),

  titlePanel("ggplot GUI"),

  div(
    class = "project-manager",

    # Project
    div(
      class = "top-row",
      tags$span(class = "top-label", "Project"),
      div(
        class = "project-name-compact",
        textInput("project_name", NULL, value = "MyProject", width = "180px")
      ),
      div(
        class = "project-action-group",
        div(
          class = "project-open-compact",
          fileInput(
            "upload_project_all",
            NULL,
            accept = c(".ggplotproj", ".json"),
            buttonLabel = "開く",
            placeholder = ""
          )
        ),
        actionButton(
          "save_project_as_all",
          "名前を付けて保存",
          title = "保存先を選んでProjectファイルを作成します。保存先を記憶するがONなら、その保存先も同時に記憶します。"
        ),
        actionButton(
          "overwrite_project_all",
          "上書き保存",
          class = "btn-primary",
          title = "保存先が未設定・無効な場合は保存先を選び直します。"
        ),
        div(
          class = "remember-save-destination",
          checkboxInput(
            "remember_project_save_destination",
            "保存先を記憶する",
            value = FALSE
          )
        ),
        div(
          style = "display:none;",
          downloadButton("download_project_all", ""),
          downloadButton("download_project_overwrite_payload", "")
        )
      ),
      div(
        class = "project-save-note",
        tags$small(
          "※ 「保存先を記憶する」をONにすると、対応ブラウザではこのProjectの上書き保存先をProject ID単位で記憶します。Project名を変更しても保存先は維持されます。ファイルを移動・削除した場合や権限が失われた場合は、次回の上書き保存時に保存先を再選択します。"
        ),
        tags$br(),
        tags$small(
          id = "project-save-destination-status",
          class = "text-muted",
          ""
        )
      ),
      div(
        class = "project-progress-inline",
        uiOutput("project_load_progress")
      )
    ),

    # Graph
    div(
      class = "top-row",
      tags$span(class = "top-label", "Graph"),
      div(
        class = "graph-tabs-wrap",
        uiOutput("graph_tab_bar")
      ),
      actionButton("graph_add", "＋", class = "btn-default btn-sm", title = "新規Graph"),
      div(
        class = "btn-group graph-menu",
        tags$button(
          type = "button",
          class = "btn btn-default btn-sm dropdown-toggle",
          `data-toggle` = "dropdown",
          `aria-haspopup` = "true",
          `aria-expanded` = "false",
          "⋯ ",
          tags$span(class = "caret")
        ),
        tags$ul(
          class = "dropdown-menu dropdown-menu-right",
          tags$li(
            tags$a(
              href = "#",
              onclick = "Shiny.setInputValue('graph_duplicate', Date.now(), {priority:'event'}); return false;",
              "複製"
            )
          ),
          tags$li(
            tags$a(
              href = "#",
              onclick = "Shiny.setInputValue('graph_rename', Date.now(), {priority:'event'}); return false;",
              "名前変更"
            )
          ),
          tags$li(role = "separator", class = "divider"),
          tags$li(
            tags$a(
              href = "#",
              onclick = "Shiny.setInputValue('graph_delete', Date.now(), {priority:'event'}); return false;",
              "削除"
            )
          )
        )
      )
    ),

    # Export
    div(
      class = "top-row",
      tags$span(class = "top-label", "書き出し"),
      div(
        class = "inline-select export-target",
        selectInput(
          "top_export_target",
          NULL,
          choices = c(
            "現在のGraph" = "current",
            "選択したGraph" = "selected",
            "全Graph" = "all"
          ),
          selected = "current",
          width = "155px"
        )
      ),
      div(
        class = "inline-select export-format",
        selectInput(
          "top_export_format",
          NULL,
          choices = c(
            "SVG" = "svg",
            "PNG" = "png",
            "PDF" = "pdf"
          ),
          selected = "svg",
          width = "90px"
        )
      ),
      downloadButton("download_graphs", "書き出す"),
      tags$span(
        class = "export-status",
        textOutput("bulk_export_status", inline = TRUE)
      ),
      tags$small(
        class = "text-muted",
        "SVG / PDF: ベクター本番用　｜　PNG: 軽量な確認・共有用　｜　サイズ比率は現在のPlotに連動"
      )
    ),

    conditionalPanel(
      condition = "input.top_export_target == 'selected'",
      div(
        class = "bulk-choice-box",
        uiOutput("bulk_export_choices")
      )
    )
  ),

  div(
    id = "graph_panels",
    div(
      id = "panel_g001",
      class = "graph-module-panel",
      graphUI("g001")
    )
  )
))
