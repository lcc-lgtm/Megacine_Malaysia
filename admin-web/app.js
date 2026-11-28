const CFG = window.MEGACINE_CONFIG;
const state = {
  token: sessionStorage.getItem("mc_jwt") || "",
  user: null,
  movies: [],
  cinemas: [],
  showtimes: [],
};

const $ = (id) => document.getElementById(id);

function getApiBase() {
  return $("apiBaseInput").value.trim().replace(/\/+$/, "");
}

function escapeHtml(str) {
  return String(str ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function formatMYT(isoStr) {
  if (!isoStr) return "-";
  return new Date(isoStr).toLocaleString("en-MY", {
    timeZone: "Asia/Kuala_Lumpur",
    year: "numeric", month: "short", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hour12: true,
  });
}

let toastTimer;
function showToast(msg, type = "success") {
  const el = $("toast");
  el.textContent = msg;
  el.className = `toast ${type}`;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.add("hidden"), 4000);
}

async function apiFetch(path, options = {}) {
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (state.token) headers["Authorization"] = `Bearer ${state.token}`;
  const res = await fetch(`${getApiBase()}${path}`, { ...options, headers });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(data.detail || `HTTP ${res.status}`);
  }
  return data;
}

async function supabaseAuth(endpoint, email, password) {
  const res = await fetch(`${CFG.SUPABASE_URL}/auth/v1/${endpoint}`, {
    method: "POST",
    headers: {
      apikey: CFG.SUPABASE_KEY,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ email, password }),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(data.error_description || data.msg || data.message || "Auth failed");
  return data;
}

async function verifySessionAndLoad() {
  if (!state.token) return;
  try {
    const me = await apiFetch("/api/v1/auth/me");
    const roleCodes = me.roles.map((r) => r.code);
    const isAdmin = roleCodes.includes("PLATFORM_ADMIN") || roleCodes.includes("CINEMA_ADMIN");
    if (!isAdmin) {
      $("authHint").textContent =
        `Signed in as ${me.email} (CUSTOMER). Run: python -m scripts.promote_admin ${me.email}`;
      state.token = "";
      sessionStorage.removeItem("mc_jwt");
      return;
    }
    state.user = me;
    $("authSection").classList.add("hidden");
    $("appSection").classList.remove("hidden");
    $("userBadge").textContent = `${me.email} (${roleCodes.join(", ")})`;
    $("userBadge").classList.remove("hidden");
    $("logoutBtn").classList.remove("hidden");
    await refreshAll();
  } catch (err) {
    state.token = "";
    sessionStorage.removeItem("mc_jwt");
    showToast(`Session error: ${err.message}`, "error");
  }
}

async function refreshAll() {
  await Promise.all([loadMovies(), loadCinemas(), loadShowtimes(), loadOrders()]);
}

async function loadMovies() {
  const [showing, coming, archived] = await Promise.all([
    apiFetch("/api/v1/movies?status=NOW_SHOWING"),
    apiFetch("/api/v1/movies?status=COMING_SOON"),
    apiFetch("/api/v1/movies?status=ARCHIVED"),
  ]);
  state.movies = [...showing, ...coming, ...archived];

  $("moviesTableBody").innerHTML = state.movies.map((m) => {
    const badge = m.status === "NOW_SHOWING" ? "badge-green" : m.status === "COMING_SOON" ? "badge-blue" : "badge-gray";
    const nextStatus = m.status === "NOW_SHOWING" ? "ARCHIVED" : "NOW_SHOWING";
    return `<tr>
      <td><strong>${escapeHtml(m.title)}</strong></td>
      <td>${m.duration_minutes} mins</td>
      <td>${escapeHtml(m.language)}</td>
      <td>${escapeHtml(m.rating || "-")}</td>
      <td><span class="badge ${badge}">${escapeHtml(m.status)}</span></td>
      <td><button class="btn btn-secondary btn-sm" onclick="toggleMovieStatus('${m.id}','${nextStatus}')">Set ${nextStatus}</button></td>
    </tr>`;
  }).join("") || `<tr><td colspan="6">No movies found.</td></tr>`;

  $("stMovieSelect").innerHTML = state.movies
    .filter((m) => m.status !== "ARCHIVED")
    .map((m) => `<option value="${m.id}">${escapeHtml(m.title)} (${m.duration_minutes}m)</option>`)
    .join("");
}

window.toggleMovieStatus = async (movieId, newStatus) => {
  try {
    await apiFetch(`/api/v1/admin/movies/${movieId}`, {
      method: "PATCH",
      body: JSON.stringify({ status: newStatus }),
    });
    showToast(`Movie status updated to ${newStatus}`);
    await loadMovies();
  } catch (err) { showToast(err.message, "error"); }
};

async function loadCinemas() {
  state.cinemas = await apiFetch("/api/v1/cinemas");
  $("cinemasTableBody").innerHTML = state.cinemas.map((c) => {
    const halls = c.auditoriums.map((a) => `${escapeHtml(a.name)} (${a.total_rows}×${a.total_cols})`).join(", ") || "None";
    return `<tr>
      <td><strong>${escapeHtml(c.name)}</strong></td>
      <td>${escapeHtml(c.city)}, ${escapeHtml(c.state)}</td>
      <td>${halls}</td>
    </tr>`;
  }).join("") || `<tr><td colspan="3">No cinemas found.</td></tr>`;

  $("audCinemaSelect").innerHTML = state.cinemas
    .map((c) => `<option value="${c.id}">${escapeHtml(c.name)}</option>`).join("");

  const audOpts = [];
  state.cinemas.forEach((c) => {
    c.auditoriums.forEach((a) => {
      audOpts.push(`<option value="${a.id}">${escapeHtml(c.name)} — ${escapeHtml(a.name)}</option>`);
    });
  });
  $("stAudSelect").innerHTML = audOpts.join("");
}

async function loadShowtimes() {
  state.showtimes = await apiFetch("/api/v1/showtimes");
  $("showtimesTableBody").innerHTML = state.showtimes.map((st) => `<tr>
    <td><strong>${escapeHtml(st.movie_title)}</strong></td>
    <td>${escapeHtml(st.cinema_name)} / ${escapeHtml(st.auditorium_name)}</td>
    <td>${formatMYT(st.start_time)}</td>
    <td>RM ${Number(st.base_price).toFixed(2)}</td>
    <td><span class="badge badge-green">${escapeHtml(st.status)}</span></td>
    <td style="display:flex;gap:6px;">
      <button class="btn btn-secondary btn-sm" onclick="openSeatMap('${st.id}','${escapeHtml(st.movie_title)}')">Seat Map</button>
      <button class="btn btn-danger btn-sm" onclick="cancelShowtime('${st.id}')">Cancel</button>
    </td>
  </tr>`).join("") || `<tr><td colspan="6">No scheduled showtimes.</td></tr>`;
}

window.openSeatMap = async (showtimeId, title) => {
  try {
    const data = await apiFetch(`/api/v1/showtimes/${showtimeId}/seats`);
    $("seatModalTitle").textContent = `${title} — ${data.auditorium_name}`;
    const byRow = {};
    data.seats.forEach((s) => {
      if (!byRow[s.row_label]) byRow[s.row_label] = [];
      byRow[s.row_label].push(s);
    });
    $("seatGrid").innerHTML = Object.entries(byRow).map(([row, seats]) => {
      const cells = seats.map((s) => {
        const vipCls = s.seat_zone === "VIP" ? "seat-vip" : "";
        return `<div class="seat-cell seat-${s.status} ${vipCls}" title="${row}${s.seat_number} (${s.seat_zone}) RM${s.price} - ${s.status}">${row}${s.seat_number}</div>`;
      }).join("");
      return `<div class="seat-row"><span class="row-tag">${escapeHtml(row)}</span>${cells}</div>`;
    }).join("");
    $("seatModal").classList.remove("hidden");
  } catch (err) { showToast(err.message, "error"); }
};

window.cancelShowtime = async (showtimeId) => {
  if (!confirm("Cancel this showtime? All confirmed orders will be refunded and logged.")) return;
  try {
    const res = await apiFetch(`/api/v1/admin/showtimes/${showtimeId}/cancel`, { method: "POST" });
    showToast(`Showtime cancelled. Refunded orders: ${res.refunded_orders_count}`);
    await Promise.all([loadShowtimes(), loadOrders()]);
  } catch (err) { showToast(err.message, "error"); }
};

async function loadOrders() {
  const statusVal = $("orderStatusFilter").value;
  const qs = statusVal ? `?status=${encodeURIComponent(statusVal)}` : "";
  const orders = await apiFetch(`/api/v1/admin/orders${qs}`);
  $("ordersTableBody").innerHTML = orders.map((o) => {
    const cls = o.status === "CONFIRMED" ? "badge-green"
      : o.status === "PENDING_PAYMENT" ? "badge-amber"
      : o.status === "REFUNDED" ? "badge-blue" : "badge-red";
    return `<tr>
      <td><strong>${escapeHtml(o.order_no)}</strong></td>
      <td><span class="badge ${cls}">${escapeHtml(o.status)}</span></td>
      <td>RM ${Number(o.total_amount).toFixed(2)}</td>
      <td>${formatMYT(o.hold_expires_at)}</td>
      <td>${formatMYT(o.created_at)}</td>
    </tr>`;
  }).join("") || `<tr><td colspan="5">No orders found.</td></tr>`;
}

// ---------- Event Listeners ----------
document.addEventListener("DOMContentLoaded", () => {
  const savedApi = localStorage.getItem("mc_api_base");
  $("apiBaseInput").value = (savedApi && !savedApi.includes("127.0.0.1")) ? savedApi : CFG.CLOUD_API_URL;
  $("apiBaseInput").addEventListener("change", () => localStorage.setItem("mc_api_base", getApiBase()));

  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".tab-btn").forEach((b) => b.classList.remove("active"));
      document.querySelectorAll(".tab-panel").forEach((p) => p.classList.add("hidden"));
      btn.classList.add("active");
      $(btn.dataset.tab).classList.remove("hidden");
    });
  });

  $("loginForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    $("authHint").textContent = "";
    try {
      const auth = await supabaseAuth("token?grant_type=password", $("loginEmail").value.trim(), $("loginPassword").value);
      state.token = auth.access_token;
      sessionStorage.setItem("mc_jwt", state.token);
      await verifySessionAndLoad();
    } catch (err) { showToast(err.message, "error"); }
  });

  $("signupBtn").addEventListener("click", async () => {
    const email = $("loginEmail").value.trim();
    const pwd = $("loginPassword").value;
    if (!email || pwd.length < 6) return showToast("Enter valid email and 6+ char password first", "error");
    try {
      const auth = await supabaseAuth("signup", email, pwd);
      if (auth.access_token) {
        state.token = auth.access_token;
        sessionStorage.setItem("mc_jwt", state.token);
        await verifySessionAndLoad();
      } else {
        showToast("Registered! Now click Sign In.");
      }
    } catch (err) { showToast(err.message, "error"); }
  });

  $("logoutBtn").addEventListener("click", () => {
    state.token = "";
    sessionStorage.removeItem("mc_jwt");
    location.reload();
  });

  $("createMovieForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const body = Object.fromEntries(fd.entries());
    body.duration_minutes = Number(body.duration_minutes);
    if (!body.release_date) delete body.release_date;
    if (!body.rating) delete body.rating;
    if (!body.synopsis) delete body.synopsis;
    try {
      await apiFetch("/api/v1/admin/movies", { method: "POST", body: JSON.stringify(body) });
      e.target.reset();
      showToast("Movie created!");
      await loadMovies();
    } catch (err) { showToast(err.message, "error"); }
  });

  $("createAuditoriumForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const cinemaId = fd.get("cinema_id");
    const vipRows = String(fd.get("vip_rows") || "").split(",").map((s) => s.trim()).filter(Boolean);
    const body = {
      name: fd.get("name"),
      total_rows: Number(fd.get("total_rows")),
      total_cols: Number(fd.get("total_cols")),
      vip_rows: vipRows,
    };
    try {
      const res = await apiFetch(`/api/v1/admin/cinemas/${cinemaId}/auditoriums`, { method: "POST", body: JSON.stringify(body) });
      e.target.reset();
      showToast(`Created ${res.name} with ${res.seats_created} seats!`);
      await loadCinemas();
    } catch (err) { showToast(err.message, "error"); }
  });

  $("createShowtimeForm").addEventListener("submit", async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const localDt = fd.get("start_time");
    const body = {
      movie_id: fd.get("movie_id"),
      auditorium_id: fd.get("auditorium_id"),
      start_time: new Date(localDt).toISOString(),
      base_price: Number(fd.get("base_price")),
      vip_surcharge: Number(fd.get("vip_surcharge")),
    };
    try {
      await apiFetch("/api/v1/admin/showtimes", { method: "POST", body: JSON.stringify(body) });
      showToast("Showtime published & seats generated!");
      await loadShowtimes();
    } catch (err) { showToast(err.message, "error"); }
  });

  $("orderStatusFilter").addEventListener("change", loadOrders);
  $("refreshOrdersBtn").addEventListener("click", loadOrders);
  $("closeSeatModal").addEventListener("click", () => $("seatModal").classList.add("hidden"));

  verifySessionAndLoad();
});

