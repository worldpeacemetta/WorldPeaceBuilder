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

function authHeader(useSessionToken = false) {
  const token = useSessionToken ? (currentSession?.access_token || supabaseAnonKey) : supabaseAnonKey;
  return {
    apikey: supabaseAnonKey,
    Authorization: `Bearer ${token}`,
  };
}

async function restUpsert(table, row, options = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  const onConflict = options.onConflict ? `?on_conflict=${encodeURIComponent(options.onConflict)}` : "";

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/${table}${onConflict}`, {
      method: "POST",
      headers: {
        ...authHeader(true),
        "Content-Type": "application/json",
        Prefer: "resolution=merge-duplicates,return=minimal",
      },
      body: JSON.stringify(row),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "Upsert request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

async function restUpdate(table, row, filters = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  const params = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    params.set(key, `eq.${value}`);
  });

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/${table}?${params.toString()}`, {
      method: "PATCH",
      headers: {
        ...authHeader(true),
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(row),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "Update request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}



async function restInsert(table, row) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/${table}`, {
      method: "POST",
      headers: {
        ...authHeader(true),
        "Content-Type": "application/json",
        Prefer: "return=representation",
      },
      body: JSON.stringify(row),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "Insert request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

async function restSelectSingle(table, columns, filters = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  const params = new URLSearchParams();
  params.set("select", columns || "*");
  Object.entries(filters).forEach(([key, value]) => {
    params.set(key, `eq.${value}`);
  });

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/${table}?${params.toString()}`, {
      method: "GET",
      headers: {
        ...authHeader(true),
        Accept: "application/vnd.pgrst.object+json",
      },
    });

    if (response.status === 406) {
      return { data: null, error: null };
    }

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "Select request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

async function restRpc(functionName, body) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${functionName}`, {
      method: "POST",
      headers: {
        ...authHeader(true),
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body ?? {}),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "RPC request failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

async function storageUpload(bucket, path, file, options = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  try {
    const response = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}/${path}`, {
      method: "POST",
      headers: {
        ...authHeader(true),
        "x-upsert": options.upsert ? "true" : "false",
        "Content-Type": file?.type || "application/octet-stream",
      },
      body: file,
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: { message: payload?.message || payload?.msg || "Upload failed." } };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}



async function storageRemove(bucket, paths) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  const list = Array.isArray(paths) ? paths : [paths];

  try {
    for (const rawPath of list) {
      const path = encodeURIComponent(rawPath);
      const response = await fetch(`${supabaseUrl}/storage/v1/object/${bucket}/${path}`, {
        method: "DELETE",
        headers: {
          ...authHeader(true),
        },
      });

      if (!response.ok && response.status !== 404) {
        const payload = await response.json().catch(() => null);
        return { data: null, error: { message: payload?.message || payload?.msg || "Remove failed." } };
      }
    }

    return { data: { paths: list }, error: null };
  } catch {
    return { data: null, error: { message: "Unable to connect to Supabase." } };
  }
}

async function authRequest(path, options = {}) {
  if (!supabaseUrl || !supabaseAnonKey) {
    return { data: null, error: { message: "Supabase env vars are missing." } };
  }

  const { useSessionToken = false, ...fetchOptions } = options;

  try {
    const response = await fetch(`${supabaseUrl}/auth/v1${path}`, {
      ...fetchOptions,
      headers: {
        ...authHeader(useSessionToken),
        "Content-Type": "application/json",
        ...(fetchOptions.headers || {}),
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
  async rpc(functionName, params) {
    return restRpc(functionName, params);
  },

  from(table) {
    const query = {
      table,
      columns: "*",
      filters: {},
      pendingUpdate: null,
      select(columns) {
        this.columns = columns || "*";
        return this;
      },
      update(row) {
        this.pendingUpdate = row;
        return this;
      },
      eq(column, value) {
        this.filters[column] = value;
        if (this.pendingUpdate) {
          const payload = this.pendingUpdate;
          this.pendingUpdate = null;
          return restUpdate(this.table, payload, this.filters);
        }
        return this;
      },
      async single() {
        return restSelectSingle(this.table, this.columns, this.filters);
      },
      async upsert(row, options) {
        return restUpsert(table, row, options);
      },
      async insert(row) {
        return restInsert(this.table, row);
      },
    };

    return query;
  },

  storage: {
    from(bucket) {
      return {
        upload(path, file, options) {
          return storageUpload(bucket, path, file, options);
        },
        remove(paths) {
          return storageRemove(bucket, paths);
        },
        getPublicUrl(path) {
          return {
            data: {
              publicUrl: `${supabaseUrl}/storage/v1/object/public/${bucket}/${path}`,
            },
          };
        },
      };
    },
  },

  auth: {
    async signUp({ email, password, options }) {
      const payload = { email, password };
      if (options?.data) payload.data = options.data;

      const { data, error } = await authRequest("/signup", {
        method: "POST",
        body: JSON.stringify(payload),
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

    async resetPasswordForEmail(email) {
      const { error } = await authRequest("/recover", {
        method: "POST",
        body: JSON.stringify({ email }),
      });
      return { data: null, error };
    },

    async resend({ type, email }) {
      return authRequest("/resend", {
        method: "POST",
        body: JSON.stringify({ type, email }),
      });
    },

    async updateUser(attributes) {
      const { data, error } = await authRequest("/user", {
        method: "PUT",
        useSessionToken: true,
        body: JSON.stringify(attributes),
      });

      if (error) return { data: null, error };

      if (currentSession && data?.user) {
        setSession({ ...currentSession, user: data.user }, "USER_UPDATED");
      }

      return { data, error: null };
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
