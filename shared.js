/* ============================================================
   TG Farmhub — Shared JavaScript
   Used by all modules (index, inventory, workers, spraytracker)
   Requires: Supabase CDN loaded before this script
   ============================================================ */

// Supabase Init
var SUPABASE_URL = "https://qwlagcriiyoflseduvvc.supabase.co";
var SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3bGFnY3JpaXlvZmxzZWR1dnZjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIzNDgxNDYsImV4cCI6MjA4NzkyNDE0Nn0.OJvzNykb_JjejFlWlEy7QUKJjL7bfiaQI0pPx62P5YA";
var sb = supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

// ============================================================
// Session Security
// ============================================================
var INACTIVITY_TIMEOUT = 30 * 60 * 1000; // 30 minutes
var inactivityTimer = null;

function startInactivityTimer() {
  clearInactivityTimer();
  var reset = function() {
    clearTimeout(inactivityTimer);
    inactivityTimer = setTimeout(function() {
      notify("Session expired due to inactivity", "warning");
      setTimeout(function() { doLogout(); }, 1500);
    }, INACTIVITY_TIMEOUT);
  };
  ["mousemove","keydown","click","scroll","touchstart"].forEach(function(e) {
    document.addEventListener(e, reset, {passive:true});
  });
  reset();
}

function clearInactivityTimer() {
  if (inactivityTimer) clearTimeout(inactivityTimer);
}

// Default logout — modules can override
function doLogout() {
  clearInactivityTimer();
  sessionStorage.removeItem("tgfarmhub_user");
  window.location.href = "index.html";
}

// ============================================================
// Utilities
// ============================================================

// HTML escape
function esc(s) {
  if (!s) return "";
  var d = document.createElement("div");
  d.textContent = s;
  return d.innerHTML;
}

// Notification system
function notify(msg, type, duration) {
  type = type || "success";
  duration = duration || 3000;
  var container = document.getElementById("notify-container");
  if (!container) {
    container = document.createElement("div");
    container.id = "notify-container";
    container.className = "notification-container";
    document.body.appendChild(container);
  }
  var el = document.createElement("div");
  el.className = "notification " + type;
  el.textContent = msg;
  container.appendChild(el);
  setTimeout(function() {
    el.style.transition = "opacity 0.3s";
    el.style.opacity = "0";
    setTimeout(function() { el.remove(); }, 300);
  }, duration);
}

// ============================================================
// Offline Detection
// ============================================================
var _offlineBanner = null;

function _showOfflineBanner() {
  if (_offlineBanner) return;
  _offlineBanner = document.createElement("div");
  _offlineBanner.className = "offline-banner";
  _offlineBanner.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="1" y1="1" x2="23" y2="23"/><path d="M16.72 11.06A10.94 10.94 0 0 1 19 12.55"/><path d="M5 12.55a10.94 10.94 0 0 1 5.17-2.39"/><path d="M10.71 5.05A16 16 0 0 1 22.56 9"/><path d="M1.42 9a15.91 15.91 0 0 1 4.7-2.88"/><path d="M8.53 16.11a6 6 0 0 1 6.95 0"/><line x1="12" y1="20" x2="12.01" y2="20"/></svg> You are offline — changes will not be saved';
  document.body.appendChild(_offlineBanner);
}

function _hideOfflineBanner() {
  if (_offlineBanner) {
    _offlineBanner.remove();
    _offlineBanner = null;
    notify("Back online", "success", 2000);
  }
}

window.addEventListener("online", _hideOfflineBanner);
window.addEventListener("offline", _showOfflineBanner);
if (!navigator.onLine) document.addEventListener("DOMContentLoaded", _showOfflineBanner);

// ============================================================
// Supabase Error Handler Wrapper (with retry & backoff)
// ============================================================

// Wraps a Supabase query with try-catch, error notification, retry with exponential backoff.
// Usage: var data = await sbQuery(sb.from('table').select('*'), 'Loading items...');
// Returns: data on success, null on error (error already shown to user).
var SBQUERY_MAX_RETRIES = 2; // 2 retries = 3 total attempts
var SBQUERY_BASE_DELAY = 1000; // 1 second

async function sbQuery(queryPromise, loadingMsg) {
  var spinner = null;
  if (loadingMsg) spinner = showLoading(loadingMsg);

  // Check offline first
  if (!navigator.onLine) {
    if (spinner) hideLoading(spinner);
    notify("You are offline — please check your connection", "error", 5000);
    return null;
  }

  try {
    var result = await queryPromise;
    if (spinner) hideLoading(spinner);
    if (result.error) {
      console.error("Supabase error:", result.error);
      notify(result.error.message || "Database error", "error", 5000);
      return null;
    }
    return result.data;
  } catch(e) {
    if (spinner) hideLoading(spinner);
    console.error("Network error:", e);
    notify("Connection error — please check your internet", "error", 5000);
    return null;
  }
}

// Retry wrapper for critical mutations (insert/update/delete).
// Pass a function that returns the Supabase query promise (so it can be re-executed).
// Usage: var data = await sbMutate(() => sb.from('t').update(d).eq('id',id).select(), 'Saving...');
async function sbMutate(queryFn, loadingMsg) {
  var spinner = null;
  if (loadingMsg) spinner = showLoading(loadingMsg);

  if (!navigator.onLine) {
    if (spinner) hideLoading(spinner);
    notify("You are offline — cannot save changes", "error", 5000);
    return null;
  }

  var lastError = null;
  for (var attempt = 0; attempt <= SBQUERY_MAX_RETRIES; attempt++) {
    try {
      var result = await queryFn();
      if (result.error) {
        // DB errors (constraint violations, RLS) — don't retry
        if (spinner) hideLoading(spinner);
        console.error("Supabase error:", result.error);
        notify(result.error.message || "Database error", "error", 5000);
        return null;
      }
      if (spinner) hideLoading(spinner);
      return result.data;
    } catch(e) {
      lastError = e;
      console.warn("Network error (attempt " + (attempt + 1) + "/" + (SBQUERY_MAX_RETRIES + 1) + "):", e.message);
      if (attempt < SBQUERY_MAX_RETRIES) {
        var delay = SBQUERY_BASE_DELAY * Math.pow(2, attempt); // 1s, 2s
        await new Promise(function(resolve) { setTimeout(resolve, delay); });
      }
    }
  }

  if (spinner) hideLoading(spinner);
  console.error("All retry attempts failed:", lastError);
  notify("Connection failed after " + (SBQUERY_MAX_RETRIES + 1) + " attempts — please try again", "error", 6000);
  return null;
}

// ============================================================
// Optimistic Locking — prevent concurrent edit overwrites
// ============================================================

// Updates a record only if its updated_at matches the expected value.
// If another user modified the record since it was loaded, shows a conflict warning.
// Usage:
//   var data = await sbUpdateWithLock('block_crops', id, updates, originalUpdatedAt);
//   if (data) { /* success */ } else { /* conflict or error — already handled */ }
async function sbUpdateWithLock(table, id, updates, expectedUpdatedAt) {
  if (!expectedUpdatedAt) {
    // No lock check — fall back to normal update
    return await sbQuery(sb.from(table).update(updates).eq("id", id).select());
  }

  var result = await sb.from(table).update(updates).eq("id", id).eq("updated_at", expectedUpdatedAt).select();

  if (result.error) {
    console.error("Update error:", result.error);
    notify(result.error.message || "Database error", "error", 5000);
    return null;
  }

  if (!result.data || result.data.length === 0) {
    // No rows matched — likely a concurrent edit changed updated_at
    notify("This record was modified by another user. Please reload and try again.", "warning", 6000);
    return null;
  }

  return result.data;
}

// ============================================================
// Loading Indicator
// ============================================================

// Shows a loading overlay. Returns the element so it can be removed later.
function showLoading(msg) {
  var el = document.createElement("div");
  el.className = "loading-overlay";
  el.innerHTML = '<div class="loading-spinner"></div><div class="loading-text">' + esc(msg || "Loading...") + '</div>';
  document.body.appendChild(el);
  return el;
}

function hideLoading(el) {
  if (el && el.parentNode) {
    el.style.opacity = "0";
    setTimeout(function() { el.remove(); }, 200);
  }
}

// Button loading state — disables button and shows spinner text
function btnLoading(btn, loading, originalText) {
  if (!btn) return;
  if (loading) {
    btn.dataset.origText = btn.textContent;
    btn.disabled = true;
    btn.textContent = "Saving...";
  } else {
    btn.disabled = false;
    btn.textContent = originalText || btn.dataset.origText || "Save";
    delete btn.dataset.origText;
  }
}

// ============================================================
// Styled Confirm Modal (replaces browser confirm())
// ============================================================

// Usage: confirmAction("Delete User?", "This will permanently remove the user.", function() { doDelete(); });
// Optional 4th param: true for danger styling (red confirm button).
function confirmAction(title, message, onConfirm, danger) {
  // Remove existing confirm modal if any
  var existing = document.getElementById("tg-confirm-modal");
  if (existing) existing.remove();

  var modal = document.createElement("div");
  modal.id = "tg-confirm-modal";
  modal.className = "modal-overlay";
  modal.style.display = "flex";
  modal.onclick = function(e) { if (e.target === modal) modal.remove(); };

  var btnClass = danger ? "btn-danger" : "btn-primary";
  var confirmLabel = danger ? "Delete" : "Confirm";

  modal.innerHTML =
    '<div class="modal-box" style="max-width:400px;">' +
      '<div class="modal-header">' +
        '<div class="modal-title">' + esc(title) + '</div>' +
        '<button class="modal-close" onclick="document.getElementById(\'tg-confirm-modal\').remove()">' +
          '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/></svg>' +
        '</button>' +
      '</div>' +
      '<div style="font-size:13px;color:var(--text);line-height:1.6;margin-bottom:20px;">' + esc(message) + '</div>' +
      '<div class="modal-actions">' +
        '<button class="btn btn-outline" onclick="document.getElementById(\'tg-confirm-modal\').remove()">Cancel</button>' +
        '<button class="btn ' + btnClass + '" id="tg-confirm-btn">' + confirmLabel + '</button>' +
      '</div>' +
    '</div>';

  document.body.appendChild(modal);

  document.getElementById("tg-confirm-btn").onclick = function() {
    modal.remove();
    if (onConfirm) onConfirm();
  };

  trapFocus(modal.querySelector(".modal-box"));
}

// ============================================================
// Modal Focus Trap (accessibility)
// ============================================================

function trapFocus(modalEl) {
  if (!modalEl) return;
  var focusable = modalEl.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
  if (!focusable.length) return;
  var first = focusable[0];
  var last = focusable[focusable.length - 1];
  first.focus();
  modalEl._trapHandler = function(e) {
    if (e.key === "Escape") {
      modalEl.style.display = "none";
      return;
    }
    if (e.key !== "Tab") return;
    if (e.shiftKey) {
      if (document.activeElement === first) { e.preventDefault(); last.focus(); }
    } else {
      if (document.activeElement === last) { e.preventDefault(); first.focus(); }
    }
  };
  modalEl.addEventListener("keydown", modalEl._trapHandler);
}

function releaseFocus(modalEl) {
  if (modalEl && modalEl._trapHandler) {
    modalEl.removeEventListener("keydown", modalEl._trapHandler);
    delete modalEl._trapHandler;
  }
}

// Generate next ID via DB function
async function dbNextId(prefix) {
  try {
    var result = await sb.rpc("next_id", { p_prefix: prefix });
    if (result.error) throw result.error;
    return result.data;
  } catch(e) {
    console.error("ID gen error:", e);
    return prefix + String(Date.now()).slice(-6);
  }
}

// Close modal by ID
function closeModal(id) {
  var el = document.getElementById(id);
  if (el) el.style.display = "none";
}

// Show save tick animation
function showTick(id) {
  var el = document.getElementById(id);
  if (!el) return;
  el.classList.add("show");
  el.style.opacity = "1";
  setTimeout(function() {
    el.classList.remove("show");
    el.style.opacity = "0";
  }, 1500);
}

// ============================================================
// Date & Number Formatters
// ============================================================

// DD/MM/YYYY
function fmtDate(d) {
  if (!d) return "—";
  var p = String(d).split("-");
  if (p.length !== 3) return d;
  return p[2] + "/" + p[1] + "/" + p[0];
}

// DD/MM/YY (short)
function fmtDateShort(d) {
  if (!d) return "—";
  var p = String(d).split("-");
  if (p.length !== 3) return d;
  return p[2] + "/" + p[1] + "/" + p[0].slice(2);
}

// "9 Mar 2026" style
function fmtDateNice(d) {
  if (!d) return "—";
  try {
    var dt = new Date(d + "T00:00:00");
    return dt.toLocaleDateString("en-GB", { day:"numeric", month:"short", year:"numeric" });
  } catch(e) { return d; }
}

// RM currency
function formatRM(val) {
  return "RM " + (val || 0).toLocaleString("en-MY", { minimumFractionDigits:2, maximumFractionDigits:2 });
}

// Generic number with 2 decimals
function fmtNum2(n) {
  return (n || 0).toLocaleString("en-MY", { minimumFractionDigits:2, maximumFractionDigits:2 });
}

// Generic number with up to 1 decimal
function fmtNum(n) {
  if (n == null) return "—";
  return Number(n).toLocaleString("en", { maximumFractionDigits:1 });
}

// ============================================================
// Form Validation Helpers
// ============================================================
var VALID_ERR_STYLE = "border:1.5px solid var(--red);background:rgba(232,96,96,0.08);";

function clearFieldError(el) {
  if (el) { el.style.cssText = el.dataset.origStyle || ""; delete el.dataset.origStyle; }
}

function markFieldError(el) {
  if (!el) return;
  if (!el.dataset.origStyle) el.dataset.origStyle = el.style.cssText || "";
  el.style.cssText += VALID_ERR_STYLE;
}

function attachClearOnInput(el) {
  if (!el || el.dataset.hasValListener) return;
  el.dataset.hasValListener = "1";
  var ev = el.tagName === "SELECT" ? "change" : "input";
  el.addEventListener(ev, function() { clearFieldError(el); });
}

function validateRequired(ids) {
  var ok = true;
  ids.forEach(function(id) {
    var el = document.getElementById(id);
    if (!el) return;
    attachClearOnInput(el);
    var val = el.value;
    if (val === "" || val === null || val === undefined) {
      markFieldError(el);
      ok = false;
    } else {
      clearFieldError(el);
    }
  });
  if (!ok) notify("Please fill all required fields", "warning");
  return ok;
}

// ============================================================
// User Badge (sidebar)
// ============================================================
function injectUserBadge(currentUser) {
  var container = document.getElementById("sidebar-user-info");
  if (!container) return;
  if (!currentUser) { container.innerHTML = ""; return; }
  var initials = currentUser.displayName.split(" ").map(function(w) { return w[0]; }).join("").substring(0,2).toUpperCase();
  var roleColor = currentUser.role === "admin" ? "var(--gold)" : "var(--good)";
  var roleBg = currentUser.role === "admin" ? "var(--gold-pale)" : "rgba(46,160,67,0.15)";
  var roleLabel = currentUser.role === "admin" ? "Admin" : currentUser.role === "supervisor" ? "Supervisor" : "Staff";
  container.innerHTML =
    '<div style="width:30px;height:30px;border-radius:50%;background:var(--gold-pale);display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:var(--gold);flex-shrink:0;">' + initials + '</div>' +
    '<div class="nav-label">' +
      '<div style="font-size:12px;font-weight:700;color:var(--white);line-height:1.2;">' + esc(currentUser.displayName) + '</div>' +
      '<div style="font-size:9px;font-weight:600;color:' + roleColor + ';background:' + roleBg + ';display:inline-block;padding:1px 6px;border-radius:8px;margin-top:2px;">' + roleLabel + '</div>' +
    '</div>';
}

// ============================================================
// Login Rate Limiting
// ============================================================
var LOGIN_MAX_ATTEMPTS = 5;
var LOGIN_LOCKOUT_MS = 5 * 60 * 1000; // 5 minutes

function checkLoginRateLimit() {
  try {
    var data = JSON.parse(sessionStorage.getItem("tgfarmhub_login_attempts") || "{}");
    if (data.lockedUntil && Date.now() < data.lockedUntil) {
      var mins = Math.ceil((data.lockedUntil - Date.now()) / 60000);
      notify("Too many failed attempts. Try again in " + mins + " minute(s).", "error", 5000);
      return false;
    }
    if (data.lockedUntil && Date.now() >= data.lockedUntil) {
      sessionStorage.removeItem("tgfarmhub_login_attempts");
    }
    return true;
  } catch(e) { return true; }
}

function recordFailedLogin() {
  try {
    var data = JSON.parse(sessionStorage.getItem("tgfarmhub_login_attempts") || "{}");
    data.count = (data.count || 0) + 1;
    if (data.count >= LOGIN_MAX_ATTEMPTS) {
      data.lockedUntil = Date.now() + LOGIN_LOCKOUT_MS;
      data.count = 0;
    }
    sessionStorage.setItem("tgfarmhub_login_attempts", JSON.stringify(data));
  } catch(e) {}
}

function clearLoginAttempts() {
  sessionStorage.removeItem("tgfarmhub_login_attempts");
}
