import { useState } from "react";
import { supabase } from "../lib/supabase";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

async function callSupabaseRpc(functionName, body) {
  try {
    const response = await fetch(`${supabaseUrl}/rest/v1/rpc/${functionName}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
      },
      body: JSON.stringify(body),
    });

    const payload = await response.json().catch(() => null);
    if (!response.ok) {
      return { data: null, error: payload?.message ?? payload?.msg ?? "Request failed." };
    }

    return { data: payload, error: null };
  } catch {
    return { data: null, error: "Unable to reach Supabase." };
  }
}

async function resolveEmailFromUsername(username) {
  const { data, error } = await callSupabaseRpc("get_email_by_username", {
    p_username: username,
  });

  if (error) return { email: null, error };
  if (!data) return { email: null, error: "Username does not exist." };

  return { email: data, error: null };
}

async function sendPasswordReset(email) {
  try {
    const response = await fetch(`${supabaseUrl}/auth/v1/recover`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: supabaseAnonKey,
        Authorization: `Bearer ${supabaseAnonKey}`,
      },
      body: JSON.stringify({ email }),
    });

    const payload = await response.json().catch(() => null);

    if (!response.ok) {
      return { error: payload?.message ?? payload?.msg ?? "Unable to send reset email." };
    }

    return { error: null };
  } catch {
    return { error: "Unable to connect to Supabase." };
  }
}

export default function Auth() {
  const [identifier, setIdentifier] = useState("");
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [resetEmail, setResetEmail] = useState("");
  const [showForgotPassword, setShowForgotPassword] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [loading, setLoading] = useState(false);

  const handleSignUp = async () => {
    setError("");
    setSuccess("");

    if (!identifier.includes("@")) {
      setError("Please enter a valid email for sign up.");
      return;
    }

    const normalizedUsername = username.trim().toLowerCase();
    if (!normalizedUsername) {
      setError("Username is required.");
      return;
    }

    setLoading(true);

    const usernameLookup = await resolveEmailFromUsername(normalizedUsername);
    if (usernameLookup.email) {
      setLoading(false);
      setError("That username is already taken.");
      return;
    }

    const { data: signUpData, error: signUpError } = await supabase.auth.signUp({
      email: identifier.trim(),
      password,
    });

    if (signUpError) {
      setLoading(false);
      setError(signUpError.message);
      return;
    }

    const newUserId = signUpData?.user?.id;
    if (newUserId) {
      const { error: profileError } = await callSupabaseRpc("create_profile", {
        p_user_id: newUserId,
        p_username: normalizedUsername,
      });

      if (profileError) {
        setLoading(false);
        setError(profileError.includes("duplicate") ? "That username is already taken." : profileError);
        return;
      }
    }

    setSuccess("Account created. You can sign in now.");
    setLoading(false);
  };

  const handleSignIn = async () => {
    setError("");
    setSuccess("");
    setLoading(true);

    let emailToUse = identifier.trim();

    if (!emailToUse.includes("@")) {
      const { email, error: resolveError } = await resolveEmailFromUsername(emailToUse.toLowerCase());
      if (resolveError) {
        setLoading(false);
        setError(resolveError || "Username does not exist.");
        return;
      }
      emailToUse = email;
    }

    const { error: signInError } = await supabase.auth.signInWithPassword({
      email: emailToUse,
      password,
    });

    if (signInError) {
      setError(signInError.message);
    }

    setLoading(false);
  };

  const handleForgotPassword = async () => {
    setError("");
    setSuccess("");

    if (!resetEmail.trim()) {
      setError("Email is required.");
      return;
    }

    setLoading(true);
    const { error: resetError } = await sendPasswordReset(resetEmail.trim());

    if (resetError) {
      setError(resetError);
    } else {
      setSuccess("Check your email for reset link.");
    }

    setLoading(false);
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 flex items-center justify-center px-4">
      <div className="w-full max-w-sm rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 p-6 shadow-sm space-y-4">
        <h1 className="text-lg font-semibold text-slate-900 dark:text-slate-100">Sign in to MacroTracker</h1>

        {!showForgotPassword ? (
          <>
            <div className="space-y-2">
              <label className="text-sm text-slate-700 dark:text-slate-300" htmlFor="identifier">
                Email or username
              </label>
              <input
                id="identifier"
                type="text"
                value={identifier}
                onChange={(event) => setIdentifier(event.target.value)}
                className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-950 px-3 py-2 text-sm"
                placeholder="you@example.com or username"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm text-slate-700 dark:text-slate-300" htmlFor="username">
                Username (required for sign up)
              </label>
              <input
                id="username"
                type="text"
                value={username}
                onChange={(event) => setUsername(event.target.value)}
                className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-950 px-3 py-2 text-sm"
                placeholder="yourusername"
              />
            </div>

            <div className="space-y-2">
              <label className="text-sm text-slate-700 dark:text-slate-300" htmlFor="password">
                Password
              </label>
              <input
                id="password"
                type="password"
                value={password}
                onChange={(event) => setPassword(event.target.value)}
                className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-950 px-3 py-2 text-sm"
                placeholder="••••••••"
              />
            </div>

            <div className="flex gap-2 pt-2">
              <button
                type="button"
                onClick={handleSignUp}
                disabled={loading}
                className="flex-1 rounded-md bg-slate-200 dark:bg-slate-700 px-3 py-2 text-sm font-medium hover:bg-slate-300 dark:hover:bg-slate-600 disabled:opacity-60"
              >
                Sign up
              </button>
              <button
                type="button"
                onClick={handleSignIn}
                disabled={loading}
                className="flex-1 rounded-md bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 px-3 py-2 text-sm font-medium hover:opacity-90 disabled:opacity-60"
              >
                Sign in
              </button>
            </div>

            <button
              type="button"
              onClick={() => {
                setShowForgotPassword(true);
                setError("");
                setSuccess("");
              }}
              className="text-sm text-slate-600 hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-100 underline"
            >
              Forgot password?
            </button>
          </>
        ) : (
          <>
            <div className="space-y-2">
              <label className="text-sm text-slate-700 dark:text-slate-300" htmlFor="resetEmail">
                Email
              </label>
              <input
                id="resetEmail"
                type="email"
                value={resetEmail}
                onChange={(event) => setResetEmail(event.target.value)}
                className="w-full rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-950 px-3 py-2 text-sm"
                placeholder="you@example.com"
              />
            </div>

            <div className="flex gap-2 pt-2">
              <button
                type="button"
                onClick={handleForgotPassword}
                disabled={loading}
                className="flex-1 rounded-md bg-slate-900 dark:bg-slate-100 text-white dark:text-slate-900 px-3 py-2 text-sm font-medium hover:opacity-90 disabled:opacity-60"
              >
                Send reset link
              </button>
              <button
                type="button"
                onClick={() => {
                  setShowForgotPassword(false);
                  setError("");
                  setSuccess("");
                }}
                className="flex-1 rounded-md bg-slate-200 dark:bg-slate-700 px-3 py-2 text-sm font-medium hover:bg-slate-300 dark:hover:bg-slate-600"
              >
                Back
              </button>
            </div>
          </>
        )}

        {error ? <p className="text-sm text-red-600 dark:text-red-400">{error}</p> : null}
        {success ? <p className="text-sm text-emerald-600 dark:text-emerald-400">{success}</p> : null}
      </div>
    </div>
  );
}
