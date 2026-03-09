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
