import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// One-time session migration from the old hand-rolled REST client.
// The custom client stored sessions under a different localStorage key;
// this reads that key and hands the tokens to the new SDK so users don't
// need to sign in again after the upgrade.
const OLD_SESSION_KEY = 'macrotracker.supabase.session';
const _oldRaw = typeof window !== 'undefined' ? window.localStorage.getItem(OLD_SESSION_KEY) : null;
if (_oldRaw) {
  try {
    const _old = JSON.parse(_oldRaw) as { access_token?: string; refresh_token?: string };
    if (_old.access_token && _old.refresh_token) {
      supabase.auth
        .setSession({ access_token: _old.access_token, refresh_token: _old.refresh_token })
        .finally(() => window.localStorage.removeItem(OLD_SESSION_KEY));
    } else {
      window.localStorage.removeItem(OLD_SESSION_KEY);
    }
  } catch {
    window.localStorage.removeItem(OLD_SESSION_KEY);
  }
}
