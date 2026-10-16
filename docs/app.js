(() => {
  "use strict";
  const byId = (id) => document.getElementById(id);
  function setup() {
    const mode = byId("mode-button");
    const label = byId("mode-label");
    const platform = byId("platform-selector");
    const command = byId("command");
    const runUrl = "https://github.com/2rwa/tmp-wpe-kms/actions";
    let lowMemory = false;
    function redraw() {
      label.textContent = lowMemory ? "2GB / 低負荷" : "通常表示";
      mode.setAttribute("aria-pressed", String(lowMemory));
      command.textContent = "WPE_PLATFORM=" + platform.value +
        " ./dist/wpe-kms-launcher http://127.0.0.1:8080/";
      document.documentElement.dataset.memoryMode = lowMemory ? "low" : "normal";
    }
    mode.addEventListener("click", () => {
      lowMemory = !lowMemory;
      redraw();
    });
    platform.addEventListener("change", redraw);
    redraw();
    fetch("results.json", {cache: "no-store"})
      .then((response) => {
        if (!response.ok) throw new Error("HTTP " + response.status);
        return response.json();
      })
      .then((report) => {
        byId("ci-status").textContent = "UI: " + report.browser +
          " / WPE: " + report.wpe;
        byId("ci-commit").textContent = report.sha.substring(0, 12);
        byId("ci-link").href = report.run_url || runUrl;
        byId("ci-link").textContent = "Actionsの実行ログを見る ↗";
        byId("ci-version").textContent = report.wpe_version || "CIログを参照";
      })
      .catch(() => {
        byId("ci-status").textContent = "結果未公開（Actions実行前）";
      });
  }
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setup);
  } else {
    setup();
  }
})();
