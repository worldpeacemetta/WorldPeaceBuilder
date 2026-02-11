import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "../lib/supabase";

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

export default function Auth() {
  const [tab, setTab] = useState("signin");

  const [identifier, setIdentifier] = useState("");
  const [signInPassword, setSignInPassword] = useState("");
  const [isResetMode, setIsResetMode] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [signInError, setSignInError] = useState("");
  const [signInSuccess, setSignInSuccess] = useState("");
  const [signInLoading, setSignInLoading] = useState(false);

  const [registerEmail, setRegisterEmail] = useState("");
  const [registerUsername, setRegisterUsername] = useState("");
  const [registerPassword, setRegisterPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [registerError, setRegisterError] = useState("");
  const [registerSuccess, setRegisterSuccess] = useState("");
  const [registerLoading, setRegisterLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [resendMessage, setResendMessage] = useState("");

  const passwordsDoNotMatch = useMemo(
    () => confirmPassword.length > 0 && registerPassword !== confirmPassword,
    [registerPassword, confirmPassword]
  );

  const canSubmitRegister =
    !!registerEmail.trim() && !!registerUsername.trim() && !!registerPassword && !!confirmPassword && !passwordsDoNotMatch && !registerLoading;

  const resetSignInMessages = () => {
    setSignInError("");
    setSignInSuccess("");
  };

  const resetRegisterMessages = () => {
    setRegisterError("");
    setRegisterSuccess("");
    setResendMessage("");
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
    const email = registerEmail.trim().toLowerCase();
    if (!email.includes("@")) {
      setRegisterError("Please enter a valid email to resend confirmation.");
      return;
    }

    setResendLoading(true);
    setResendMessage("");
    setRegisterError("");

    try {
      const { error } = await supabase.auth.resend({ type: "signup", email });
      if (error) {
        setRegisterError(toFriendlyAuthError(error, "Unable to resend confirmation email"));
        return;
      }
      setResendMessage("Confirmation email sent. Please check your inbox.");
    } finally {
      setResendLoading(false);
    }
  };

  const handleRegister = async () => {
    resetRegisterMessages();

    const email = registerEmail.trim().toLowerCase();
    const displayUsername = registerUsername.trim();
    const username = displayUsername.toLowerCase();

    if (!email.includes("@")) {
      setRegisterError("Please enter a valid email");
      return;
    }

    if (!displayUsername) {
      setRegisterError("Username is required");
      return;
    }

    if (passwordsDoNotMatch) {
      setRegisterError("Passwords do not match");
      return;
    }

    setRegisterLoading(true);

    try {
      const { data: existingEmail, error: usernameLookupError } = await supabase.rpc("get_email_by_username", {
        p_username: username,
      });
      if (usernameLookupError) {
        setRegisterError(getErrorMessage(usernameLookupError, "Unable to validate username"));
        return;
      }
      if (existingEmail) {
        setRegisterError("Username already taken");
        return;
      }

      const { error: registerErrorResult } = await supabase.auth.signUp({
        email,
        password: registerPassword,
        options: { data: { username, display_username: displayUsername } },
      });

      if (registerErrorResult) {
        setRegisterError(toFriendlyAuthError(registerErrorResult, "Unable to register"));
        return;
      }

      setRegisterSuccess("Account created. Check your inbox (and spam) to confirm your email, then return to sign in.");
    } finally {
      setRegisterLoading(false);
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
              <TabsTrigger value="register">Register</TabsTrigger>
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

            <TabsContent value="register" className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="register-email">Email</Label>
                <Input
                  id="register-email"
                  type="email"
                  value={registerEmail}
                  onChange={(event) => setRegisterEmail(event.target.value)}
                  placeholder="you@example.com"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="register-username">Username</Label>
                <Input
                  id="register-username"
                  type="text"
                  value={registerUsername}
                  onChange={(event) => setRegisterUsername(event.target.value)}
                  placeholder="yourusername"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="register-password">Password</Label>
                <Input
                  id="register-password"
                  type="password"
                  value={registerPassword}
                  onChange={(event) => setRegisterPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="register-confirm-password">Confirm Password</Label>
                <Input
                  id="register-confirm-password"
                  type="password"
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              {passwordsDoNotMatch ? (
                <p className="text-sm text-amber-600 dark:text-amber-400">Passwords do not match</p>
              ) : null}

              <Button className="w-full" onClick={handleRegister} disabled={!canSubmitRegister}>
                {registerLoading ? "Creating account..." : "Register"}
              </Button>

              {registerError ? <p className="text-sm text-red-600 dark:text-red-400">{registerError}</p> : null}
              {registerSuccess ? (
                <div className="space-y-2">
                  <p className="text-sm text-emerald-600 dark:text-emerald-400">{registerSuccess}</p>
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
