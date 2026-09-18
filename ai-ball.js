(() => {
  const phone = document.getElementById("phone");
  const themeToggle = document.getElementById("themeToggle");
  const reduceToggle = document.getElementById("reduceToggle");
  const tabs = Array.from(document.querySelectorAll(".tab"));
  const slidingPill = document.getElementById("slidingPill");
  const aiBall = document.getElementById("aiBall");
  const sheet = document.getElementById("sheet");
  const backdrop = document.getElementById("sheetBackdrop");
  const sheetOk = document.getElementById("sheetOk");
  const sheetMascot = document.getElementById("sheetMascot");

  function applyTheme(dark) {
    document.documentElement.dataset.uiTheme = dark ? "dark" : "light";
    phone.dataset.theme = dark ? "dark" : "light";
    themeToggle.setAttribute("aria-pressed", dark ? "true" : "false");
    themeToggle.textContent = dark ? "浅色模式" : "深色模式";
  }

  function applyReduce(on) {
    document.documentElement.dataset.reduce = on ? "on" : "off";
    reduceToggle.setAttribute("aria-pressed", on ? "true" : "false");
    reduceToggle.textContent = on ? "恢复动态" : "减少动态";
  }

  const tabShell = document.querySelector(".tab-pill-shell");

  function layoutPill(index) {
    const shellWidth = tabShell.clientWidth;
    const contentWidth = shellWidth - 8; // horizontal padding 4*2
    const slot = contentWidth / tabs.length;
    const pillWidth = Math.max(slot - 4, 0);
    slidingPill.style.width = `${pillWidth}px`;
    slidingPill.style.transform = `translateX(${index * slot}px)`;
  }

  function selectTab(index) {
    tabs.forEach((tab, i) => {
      const on = i === index;
      tab.classList.toggle("is-active", on);
      tab.setAttribute("aria-selected", on ? "true" : "false");
    });
    layoutPill(index);
  }

  function openSheet() {
    sheet.hidden = false;
    backdrop.hidden = false;
    sheetMascot.classList.add("is-awake");
  }

  function closeSheet() {
    sheet.hidden = true;
    backdrop.hidden = true;
    sheetMascot.classList.remove("is-awake");
    aiBall.classList.remove("is-awake");
  }

  themeToggle.addEventListener("click", () => {
    applyTheme(document.documentElement.dataset.uiTheme !== "dark");
  });

  reduceToggle.addEventListener("click", () => {
    applyReduce(document.documentElement.dataset.reduce !== "on");
  });

  tabs.forEach((tab) => {
    tab.addEventListener("click", () => {
      selectTab(Number(tab.dataset.index));
    });
  });

  aiBall.addEventListener("pointerdown", () => aiBall.classList.add("is-awake"));
  aiBall.addEventListener("pointerup", () => aiBall.classList.remove("is-awake"));
  aiBall.addEventListener("pointerleave", () => aiBall.classList.remove("is-awake"));
  aiBall.addEventListener("click", openSheet);
  backdrop.addEventListener("click", closeSheet);
  sheetOk.addEventListener("click", closeSheet);
  document.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && !sheet.hidden) closeSheet();
  });

  applyTheme(false);
  applyReduce(false);
  selectTab(0);
  window.addEventListener("resize", () => {
    const active = tabs.findIndex((t) => t.classList.contains("is-active"));
    layoutPill(active < 0 ? 0 : active);
  });
})();
