const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
const STORAGE_KEY = "macrotracker.supabase.session";

const listeners = new Set();

function readSession() {
  if (typeof window === "undefined") return null;
  const raw = window.localStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

function writeSession(session) {
  if (typeof window === "undefined") return;
  if (session) {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(session));
  } else {
    window.localStorage.removeItem(STORAGE_KEY);
  }
}

function emitAuthChange(event, session) {
  listeners.forEach((callback) => callback(event, session));
}

let currentSession = readSession();

function setSession(session, event) {
  currentSession = session;
  writeSession(session);
  emitAuthChange(event, session);
}

async function authRequest(path, options = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  try {
    const response = await fetch(`${supabaseUrl}/auth/v1${path}`, {
      ...options,
      headers: {
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
        "Content-Type": "application/json",
        ...(options.headers || {}),
      },
    });

    const payload = await response.json().catch(() => ({}));

    if (!response.ok) {
      return { data: null, error: { message: payload?.msg || payload?.message || "Authentication request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

export const supabase = {
  auth: {
    async signUp({ email, password }) {
      const { data, error } = await authRequest("/signup", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });

      if (error) return { data: null, error };

      const session = data?.access_token
        ? {
            access_token: data.access_token,
            refresh_token: data.refresh_token,
            user: data.user,
          }
        : null;

      if (session) {
        setSession(session, "SIGNED_IN");
      }

      return { data: { user: data?.user ?? null, session }, error: null };
    },

    async signInWithPassword({ email, password }) {
      const { data, error } = await authRequest("/token?grant_type=password", {
        method: "POST",
        body: JSON.stringify({ email, password }),
      });

      if (error) return { data: null, error };

      const session = {
        access_token: data.access_token,
        refresh_token: data.refresh_token,
        user: data.user,
      };

      setSession(session, "SIGNED_IN");

      return { data: { user: data.user, session }, error: null };
    },

    async signOut() {
      setSession(null, "SIGNED_OUT");
      return { error: null };
    },

    async getSession() {
      return { data: { session: currentSession }, error: null };
    },

    onAuthStateChange(callback) {
      listeners.add(callback);
      return {
        data: {
          subscription: {
            unsubscribe: () => listeners.delete(callback),
          },
        },
      };
    },
  },
};
