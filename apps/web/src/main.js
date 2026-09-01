import {
  addTask,
  ensureInbox,
  fetchTasks,
  loadSession,
  redeemSyncKey,
  setCompleted,
  signOut,
} from "./sync.js";

const PANES = {
  today: { title: "Today", lede: "Your Inbox tasks from Supabase (same backend as Apple)." },
  calendar: { title: "Calendar", lede: "Day / week / month will land here later." },
  focus: { title: "Focus", lede: "Pomodoro lives on Apple first; this pane is a stub." },
  settings: { title: "Settings", lede: "Paste the sync key from the Apple app." },
};

let pane = "today";
let session = loadSession();
let tasks = [];
let inbox = null;
let status = "";
let error = "";
let busy = false;

function setBusy(next) {
  busy = next;
  render();
}

async function refreshTasks() {
  if (!session) {
    tasks = [];
    inbox = null;
    return;
  }
  inbox = await ensureInbox(session);
  tasks = await fetchTasks(session);
}

function stubMarkup(key) {
  const copy = {
    calendar: "Calendar views are not built on web yet.",
    focus: "Focus timer is not on web yet. Use the Apple app for Pomodoro.",
  };
  return `<div class="placeholder">${copy[key]}</div>`;
}

function todayMarkup() {
  if (!session) {
    return `<div class="placeholder">Sign in under Settings to load tasks from Supabase.</div>`;
  }
  const rows = tasks.length
    ? tasks
        .map(
          (task) => `
      <button type="button" class="row as-button" data-toggle="${task.id}">
        <span class="check ${task.is_completed ? "done" : ""}" aria-hidden="true"></span>
        <div>
          <div>${escapeHtml(task.title)}</div>
          <div class="meta">${task.due_date || "No date"} · ${task.priority || "none"}</div>
        </div>
      </button>`
        )
        .join("")
    : `<div class="placeholder">No tasks yet. Add one below.</div>`;
  return `
    <form class="add-row" id="add-form">
      <input name="title" maxlength="280" placeholder="New task" required />
      <button type="submit" ${busy ? "disabled" : ""}>Add</button>
    </form>
    <p class="section-label">Inbox</p>
    ${rows}
  `;
}

function settingsMarkup() {
  if (session) {
    return `
      <p class="lede">Linked with the Apple-device sync key.</p>
      <button type="button" class="primary" id="sign-out">Sign out</button>
    `;
  }
  return `
    <form class="auth-form" id="auth-form">
      <label>Sync key <input name="key" autocomplete="off" spellcheck="false" required placeholder="TTK-XXXX-XXXX-XXXX-XXXX" /></label>
      <div class="auth-actions">
        <button type="submit" ${busy ? "disabled" : ""}>Connect</button>
      </div>
    </form>
    <p class="meta">Create the key in Tickytacky on iPhone or Mac (Settings → Create sync key).</p>
  `;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function bodyFor(key) {
  if (key === "today") return todayMarkup();
  if (key === "settings") return settingsMarkup();
  return stubMarkup(key);
}

function render() {
  const spec = PANES[pane];
  document.querySelector("#app").innerHTML = `
    <div class="platform-stripe" title="Web client"></div>
    <header class="platform-banner">
      <div>
        <div class="wordmark">Tickytacky Web</div>
        <p class="banner-note">Browser prototype · syncs via Supabase · not apps/ios</p>
      </div>
      <span class="platform-tag">Web</span>
    </header>
    <nav class="tabs" aria-label="Primary">
      ${Object.keys(PANES)
        .map(
          (key) => `
        <button type="button" data-pane="${key}" ${key === pane ? 'aria-current="page"' : ""}>
          ${PANES[key].title}
        </button>`
        )
        .join("")}
    </nav>
    <main>
      <h1>${spec.title}</h1>
      <p class="lede">${spec.lede}</p>
      ${error ? `<p class="error">${escapeHtml(error)}</p>` : ""}
      ${status ? `<p class="meta">${escapeHtml(status)}</p>` : ""}
      ${bodyFor(pane)}
    </main>
  `;

  document.querySelectorAll("[data-pane]").forEach((button) => {
    button.addEventListener("click", () => {
      pane = button.dataset.pane;
      render();
    });
  });

  document.querySelectorAll("[data-toggle]").forEach((button) => {
    button.addEventListener("click", async () => {
      const task = tasks.find((item) => item.id === button.dataset.toggle);
      if (!task || !session) return;
      try {
        error = "";
        const updated = await setCompleted(session, task);
        tasks = tasks.map((item) => (item.id === updated.id ? { ...item, ...updated } : item));
        render();
      } catch (err) {
        error = err.message;
        render();
      }
    });
  });

  const addForm = document.querySelector("#add-form");
  if (addForm) {
    addForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const title = new FormData(addForm).get("title");
      if (!title || !session || !inbox) return;
      setBusy(true);
      try {
        error = "";
        await addTask(session, inbox.id, String(title));
        await refreshTasks();
        status = "Saved to Supabase";
      } catch (err) {
        error = err.message;
      } finally {
        setBusy(false);
      }
    });
  }

  const authForm = document.querySelector("#auth-form");
  if (authForm) {
    authForm.addEventListener("submit", async (event) => {
      event.preventDefault();
      const key = String(new FormData(authForm).get("key") || "");
      setBusy(true);
      try {
        error = "";
        session = await redeemSyncKey(key);
        await refreshTasks();
        status = `Connected · ${tasks.length} tasks`;
        pane = "today";
      } catch (err) {
        error = err.message;
      } finally {
        setBusy(false);
      }
    });
  }

  const signOutBtn = document.querySelector("#sign-out");
  if (signOutBtn) {
    signOutBtn.addEventListener("click", () => {
      signOut();
      session = null;
      tasks = [];
      inbox = null;
      status = "Signed out";
      render();
    });
  }
}

if (session) {
  refreshTasks()
    .then(() => {
      status = `Loaded ${tasks.length} tasks`;
      render();
    })
    .catch((err) => {
      error = err.message;
      render();
    });
} else {
  render();
}
