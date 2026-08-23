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
    const node = cards.get(info.name);
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
        cards.set(card.name, node);
        grid.appendChild(node);
        patch(card);
      });

      ctx.root.appendChild(grid);
    });
  }

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
        ${card.toggle ? `<input type="checkbox" class="toggle" />` : ""}
        ${card.buttons.map((button) => `<button>${button.label}</button>`).join("")}
        ${card.slider ? `<input type="range" class="slider" min="0" max="100" step="1" />` : ""}
      </div>`;

    const send = (cmd) => ctx.pushEvent("command", { name: card.name, cmd });

    node.querySelectorAll(".controls button").forEach((element, index) => {
      element.onclick = () => send(card.buttons[index].cmd);
    });

    const toggle = node.querySelector(".toggle");
    if (toggle) toggle.onchange = () => send({ [card.toggle.field]: toggle.checked });

    const slider = node.querySelector(".slider");
    if (slider) {
      // hold on to the slider and patches leave it alone until you let go
      slider.onpointerdown = () => (dragging = slider);
      slider.onpointerup = slider.onpointercancel = () => (dragging = null);
      slider.oninput = () => (node.querySelector(".fill").style.width = `${slider.value}%`);
      slider.onchange = () => send({ [card.slider.field]: +slider.value });
    }

    return node;
  }

  function patch(card) {
    const node = cards.get(card.name);
    if (!node) return;

    const value = node.querySelector(".value");
    value.innerHTML = card.unit
      ? html`${card.value}<span class="unit"> ${card.unit}</span>`
      : card.value;
    value.classList.toggle("on", card.on);
    node.querySelector(".sub").textContent = card.sub ?? "";

    // an event has nothing to stay on the card, so it fades back out
    if (card.flash) {
      clearTimeout(flashes.get(card.name));
      flashes.set(
        card.name,
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
    // changed it — Home Assistant, another browser, the entity itself
    const toggle = node.querySelector(".toggle");
    if (toggle) toggle.checked = card.on;

    const slider = node.querySelector(".slider");
    if (slider && card.brightness !== null && dragging !== slider) {
      slider.value = card.brightness;
    }
  }
}
