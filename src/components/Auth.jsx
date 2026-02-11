import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "../lib/supabase";

const PENDING_USERNAMES_KEY = "macrotracker.pending-usernames";

function getErrorMessage(error, fallback) {
  if (!error) return fallback;
  if (typeof error === "string") return error;
  return error.message || fallback;
}

function toFriendlyAuthError(error, fallback) {
  const message = getErrorMessage(error, fallback).toLowerCase();
  if (message.includes("email not confirmed") || message.includes("email_not_confirmed")) {
    return "Email not confirmed yet. Check your inbox for the confirmation email.";
  }
  if (message.includes("rate limit") || message.includes("too many") || message.includes("email rate limit exceeded")) {
    return "Too many emails sent. Please try again later.";
  }
  return getErrorMessage(error, fallback);
}

function readPendingUsernames() {
  if (typeof window === "undefined") return {};
  try {
    const raw = window.localStorage.getItem(PENDING_USERNAMES_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch {
    return {};
  }
}

function setPendingUsername(email, username) {
  if (typeof window === "undefined") return;
  const pending = readPendingUsernames();
  pending[email.toLowerCase()] = username;
  window.localStorage.setItem(PENDING_USERNAMES_KEY, JSON.stringify(pending));
}

function takePendingUsername(email) {
  if (typeof window === "undefined") return null;
  const pending = readPendingUsernames();
  const key = email.toLowerCase();
  const username = pending[key] ?? null;
  if (!username) return null;
  delete pending[key];
  window.localStorage.setItem(PENDING_USERNAMES_KEY, JSON.stringify(pending));
  return username;
}

function clearPendingUsername(email) {
  if (typeof window === "undefined") return;
  const pending = readPendingUsernames();
  delete pending[email.toLowerCase()];
  window.localStorage.setItem(PENDING_USERNAMES_KEY, JSON.stringify(pending));
}

export default function Auth() {
  const [tab, setTab] = useState("signin");

  const [identifier, setIdentifier] = useState("");
  const [signInPassword, setSignInPassword] = useState("");
  const [isResetMode, setIsResetMode] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [signInError, setSignInError] = useState("");
  const [signInSuccess, setSignInSuccess] = useState("");
  const [signInLoading, setSignInLoading] = useState(false);

  const [signUpEmail, setSignUpEmail] = useState("");
  const [signUpUsername, setSignUpUsername] = useState("");
  const [signUpPassword, setSignUpPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [signUpError, setSignUpError] = useState("");
  const [signUpSuccess, setSignUpSuccess] = useState("");
  const [signUpLoading, setSignUpLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendMessage, setResendMessage] = useState("");

  const passwordsDoNotMatch = useMemo(
    () => confirmPassword.length > 0 && signUpPassword !== confirmPassword,
    [signUpPassword, confirmPassword]
  );

  const canSubmitSignUp =
    !!signUpEmail.trim() && !!signUpUsername.trim() && !!signUpPassword && !!confirmPassword && !passwordsDoNotMatch && !signUpLoading;

  const resetSignInMessages = () => {
    setSignInError("");
    setSignInSuccess("");
  };

  const resetSignUpMessages = () => {
    setSignUpError("");
    setSignUpSuccess("");
    setResendMessage("");
  };

  const ensureProfileForCurrentUser = async (username, errorSetter) => {
    if (!username) return;
    const { data: sessionData } = await supabase.auth.getSession();
    const user = sessionData?.session?.user;
    if (!user?.id) return;

    const { error } = await supabase
      .from("profiles")
      .upsert({ id: user.id, username }, { onConflict: "id" });

    if (error && errorSetter) {
      const message = getErrorMessage(error, "Unable to save username").toLowerCase();
      if (message.includes("duplicate") || message.includes("unique")) {
        errorSetter("Username already taken");
      } else {
        errorSetter(getErrorMessage(error, "Unable to save username"));
      }
    }
  };

  const handleSignIn = async () => {
    resetSignInMessages();

    const rawIdentifier = identifier.trim();
    if (!rawIdentifier) {
      setSignInError("Email or username is required");
      return;
    }

    if (!signInPassword) {
      setSignInError("Password is required");
      return;
    }

    setSignInLoading(true);

    try {
      let email = rawIdentifier;

      if (!rawIdentifier.includes("@")) {
        const { data: resolvedEmail, error: lookupError } = await supabase.rpc("get_email_by_username", {
          p_username: rawIdentifier,
        });

        if (lookupError) {
          setSignInError(getErrorMessage(lookupError, "Unable to find username"));
          return;
        }

        if (!resolvedEmail) {
          setSignInError("Username not found");
          return;
        }

        email = resolvedEmail;
      }

      const { error: signInErrorResult } = await supabase.auth.signInWithPassword({
        email,
        password: signInPassword,
      });

      if (signInErrorResult) {
        setSignInError(toFriendlyAuthError(signInErrorResult, "Unable to sign in"));
        return;
      }

      const pendingUsername = takePendingUsername(email);
      if (pendingUsername) {
        await ensureProfileForCurrentUser(pendingUsername, setSignInError);
      }
    } finally {
      setSignInLoading(false);
    }
  };

  const handlePasswordReset = async () => {
    resetSignInMessages();
    const email = resetEmail.trim();

    if (!email || !email.includes("@")) {
      setSignInError("Please enter your email to reset password");
      return;
    }

    setSignInLoading(true);

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email);
      if (error) {
        setSignInError(toFriendlyAuthError(error, "Unable to send reset email"));
        return;
      }

      setSignInSuccess("Check your email for reset link");
    } finally {
      setSignInLoading(false);
    }
  };

  const handleResendConfirmation = async () => {
    const email = signUpEmail.trim().toLowerCase();
    if (!email.includes("@")) {
      setSignUpError("Please enter a valid email to resend confirmation.");
      return;
    }

    setResendLoading(true);
    setResendMessage("");
    setSignUpError("");

    try {
      const { error } = await supabase.auth.resend({ type: "signup", email });
      if (error) {
        setSignUpError(toFriendlyAuthError(error, "Unable to resend confirmation email"));
        return;
      }
      setResendMessage("Confirmation email sent. Please check your inbox.");
    } finally {
      setResendLoading(false);
    }
  };

  const handleSignUp = async () => {
    resetSignUpMessages();

    const email = signUpEmail.trim().toLowerCase();
    const username = signUpUsername.trim().toLowerCase();

    if (!email.includes("@")) {
      setSignUpError("Please enter a valid email");
      return;
    }

    if (!username) {
      setSignUpError("Username is required");
      return;
    }

    if (passwordsDoNotMatch) {
      setSignUpError("Passwords do not match");
      return;
    }

    setSignUpLoading(true);

    try {
      const { data: existingEmail, error: usernameLookupError } = await supabase.rpc("get_email_by_username", {
        p_username: username,
      });
      if (usernameLookupError) {
        setSignUpError(getErrorMessage(usernameLookupError, "Unable to validate username"));
        return;
      }
      if (existingEmail) {
        setSignUpError("Username already taken");
        return;
      }

      const { data: signUpData, error: signUpErrorResult } = await supabase.auth.signUp({
        email,
        password: signUpPassword,
      });

      if (signUpErrorResult) {
        setSignUpError(toFriendlyAuthError(signUpErrorResult, "Unable to sign up"));
        return;
      }

      setPendingUsername(email, username);

      if (signUpData?.session) {
        await ensureProfileForCurrentUser(username, setSignUpError);
        clearPendingUsername(email);
      }

      setSignUpSuccess("Account created. Check your inbox (and spam) to confirm your email, then come back and sign in.");
      setTab("signin");
      setIdentifier(email);
      setSignInPassword("");
      setSignUpPassword("");
      setConfirmPassword("");
    } finally {
      setSignUpLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 flex items-center justify-center px-4">
      <Card className="w-full max-w-md border-slate-200 dark:border-slate-800">
        <CardHeader className="pb-2">
          <img
            src="/brand/onebodyonelife-logo.png"
            alt="OneBodyOneLife"
            className="mx-auto mb-4 w-full max-w-xs h-auto"
          />
        </CardHeader>
        <CardContent>
          <Tabs value={tab} onValueChange={setTab} className="space-y-4">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="signin">Sign In</TabsTrigger>
              <TabsTrigger value="signup">Sign Up</TabsTrigger>
            </TabsList>

            <TabsContent value="signin" className="space-y-4">
              {!isResetMode ? (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="signin-identifier">Email or username</Label>
                    <Input
                      id="signin-identifier"
                      type="text"
                      value={identifier}
                      onChange={(event) => setIdentifier(event.target.value)}
                      placeholder="you@example.com or username"
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="signin-password">Password</Label>
                    <Input
                      id="signin-password"
                      type="password"
                      value={signInPassword}
                      onChange={(event) => setSignInPassword(event.target.value)}
                      placeholder="••••••••"
                    />
                  </div>

                  <Button className="w-full" onClick={handleSignIn} disabled={signInLoading}>
                    {signInLoading ? "Signing in..." : "Sign in"}
                  </Button>

                  <button
                    type="button"
                    className="text-sm text-slate-600 hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-100 underline"
                    onClick={() => {
                      setIsResetMode(true);
                      setResetEmail(identifier.includes("@") ? identifier : "");
                      resetSignInMessages();
                    }}
                  >
                    Forgot password?
                  </button>
                </>
              ) : (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="reset-email">Email</Label>
                    <Input
                      id="reset-email"
                      type="email"
                      value={resetEmail}
                      onChange={(event) => setResetEmail(event.target.value)}
                      placeholder="you@example.com"
                    />
                  </div>

                  <div className="flex gap-2">
                    <Button className="flex-1" onClick={handlePasswordReset} disabled={signInLoading}>
                      {signInLoading ? "Sending..." : "Send reset link"}
                    </Button>
                    <Button
                      variant="outline"
                      className="flex-1"
                      onClick={() => {
                        setIsResetMode(false);
                        resetSignInMessages();
                      }}
                    >
                      Back
                    </Button>
                  </div>
                </>
              )}

              {signInError ? <p className="text-sm text-red-600 dark:text-red-400">{signInError}</p> : null}
              {signInSuccess ? <p className="text-sm text-emerald-600 dark:text-emerald-400">{signInSuccess}</p> : null}
            </TabsContent>

            <TabsContent value="signup" className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="signup-email">Email</Label>
                <Input
                  id="signup-email"
                  type="email"
                  value={signUpEmail}
                  onChange={(event) => setSignUpEmail(event.target.value)}
                  placeholder="you@example.com"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="signup-username">Username</Label>
                <Input
                  id="signup-username"
                  type="text"
                  value={signUpUsername}
                  onChange={(event) => setSignUpUsername(event.target.value)}
                  placeholder="yourusername"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="signup-password">Password</Label>
                <Input
                  id="signup-password"
                  type="password"
                  value={signUpPassword}
                  onChange={(event) => setSignUpPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="signup-confirm-password">Confirm Password</Label>
                <Input
                  id="signup-confirm-password"
                  type="password"
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              {passwordsDoNotMatch ? (
                <p className="text-sm text-amber-600 dark:text-amber-400">Passwords do not match</p>
              ) : null}

              <Button className="w-full" onClick={handleSignUp} disabled={!canSubmitSignUp}>
                {signUpLoading ? "Creating account..." : "Sign up"}
              </Button>

              {signUpError ? <p className="text-sm text-red-600 dark:text-red-400">{signUpError}</p> : null}
              {signUpSuccess ? (
                <div className="space-y-2">
                  <p className="text-sm text-emerald-600 dark:text-emerald-400">{signUpSuccess}</p>
                  <button
                    type="button"
                    onClick={handleResendConfirmation}
                    disabled={resendLoading}
                    className="text-sm underline text-slate-600 hover:text-slate-900 dark:text-slate-300 dark:hover:text-slate-100 disabled:opacity-60"
                  >
                    {resendLoading ? "Resending..." : "Resend confirmation email"}
                  </button>
                  {resendMessage ? <p className="text-sm text-emerald-600 dark:text-emerald-400">{resendMessage}</p> : null}
                </div>
              ) : null}
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}
