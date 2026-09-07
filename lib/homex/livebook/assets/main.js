const html = String.raw
export function init(ctx, layout) {
  ctx.importCSS("main.css");

  const cards = new Map();
  const flashes = new Map();
  let dragging = null;

  render(layout);

  ctx.handleEvent("layout", render);
  ctx.handleEvent("card", patch);
  ctx.handleEvent("image", ([info, buffer]) => {
    const node = cards.get(info.id);
    if (!node) return;

    const img = node.querySelector(".snap");
    if (img.dataset.url) URL.revokeObjectURL(img.dataset.url);
    img.dataset.url = URL.createObjectURL(new Blob([buffer], { type: "image/jpeg" }));
    img.src = img.dataset.url;
    img.hidden = false;
  });

  function render({ devices }) {
    ctx.root.innerHTML = "";
    cards.clear();
    flashes.forEach(clearTimeout);
    flashes.clear();

    devices.forEach((device) => {
      const heading = document.createElement("div");
      heading.className = "device";
      heading.textContent = device.name;
      ctx.root.appendChild(heading);

      const grid = document.createElement("div");
      grid.className = "grid";

      device.cards.forEach((card) => {
        const node = build(card);
        cards.set(card.id, node);
        grid.appendChild(node);
        patch(card);
      });

      ctx.root.appendChild(grid);
    });
  }

  // one element per control type, in the same order build() renders them in
  const controlHtml = {
    toggle: () => `<input type="checkbox" class="toggle" />`,
    button: (control) => `<button>${control.label}</button>`,
    slider: (control) =>
      `<input type="range" class="slider" min="${control.min}" max="${control.max}" step="${control.step}" />`,
    input: (control) => {
      const type = control.kind === "number" ? "number" : control.kind;
      const attr = (name, v) => (v != null ? `${name}="${v}"` : "");
      return `<input type="${type}" class="input" ${attr("min", control.min)} ${attr("max", control.max)} ${attr("step", control.step)} ${attr("maxlength", control.maxlength)} />`;
    },
    select: (control) =>
      `<select class="select">${control.options.map((option) => `<option value="${option}">${option}</option>`).join("")}</select>`
  };

  function build(card) {
    const node = document.createElement("div");
    node.className = "card";
    node.innerHTML = html`
      <div class="tile">
        <div class="icon">${card.icon}</div>
        <div class="text">
          <div class="name">${card.name}</div>
          <div class="value"></div>
          <div class="sub"></div>
          <div class="bar" hidden><div class="fill"></div></div>
        </div>
        <img class="snap" hidden />
      </div>
      <div class="controls">
        ${card.controls.map((control) => controlHtml[control.type](control)).join("")}
      </div>`;

    const send = (cmd) => ctx.pushEvent("command", { id: card.id, cmd });

    node.querySelectorAll(".controls > *").forEach((element, index) => {
      const control = card.controls[index];
      switch (control.type) {
        case "toggle":
          element.onchange = () => send({ [control.field]: element.checked });
          break;
        case "button":
          element.onclick = () => send(control.cmd);
          break;
        case "slider":
          // hold on to the slider and patches leave it alone until you let go
          element.onpointerdown = () => (dragging = element);
          element.onpointerup = element.onpointercancel = () => (dragging = null);
          element.oninput = () => {
            const fill = node.querySelector(".fill");
            if (fill) fill.style.width = `${element.value}%`;
          };
          element.onchange = () => send({ [control.field]: +element.value });
          break;
        case "input":
          element.onchange = () =>
            send({ [control.field]: control.kind === "number" ? +element.value : element.value });
          break;
        case "select":
          element.onchange = () => send({ [control.field]: element.value });
          break;
      }
    });

    return node;
  }

  function patch(card) {
    const node = cards.get(card.id);
    if (!node) return;

    const value = node.querySelector(".value");
    value.innerHTML = card.unit
      ? html`${card.value}<span class="unit"> ${card.unit}</span>`
      : card.value;
    value.classList.toggle("on", card.on);
    node.querySelector(".sub").textContent = card.sub ?? "";

    // an event has nothing to stay on the card, so it fades back out
    if (card.flash) {
      clearTimeout(flashes.get(card.id));
      flashes.set(
        card.id,
        setTimeout(() => {
          value.textContent = "—";
          value.classList.remove("on");
        }, 1500)
      );
    }

    const bar = node.querySelector(".bar");
    bar.hidden = !(card.on && card.brightness !== null);
    if (!bar.hidden) node.querySelector(".fill").style.width = `${card.brightness}%`;

    // what a Kino.Frame cannot do: the controls follow the entity, whoever
    // changed it — Home Assistant, another browser, the entity itself. typing
    // and dragging both get the same protection: a patch leaves the widget
    // alone until you're done with it
    node.querySelectorAll(".controls > *").forEach((element, index) => {
      const control = card.controls[index];
      switch (control.type) {
        case "toggle":
          element.checked = card.on;
          break;
        case "slider":
          if (control.value !== null && dragging !== element) element.value = control.value;
          break;
        case "input":
        case "select":
          if (document.activeElement !== element) element.value = control.value ?? "";
          break;
      }
    });
  }
}
