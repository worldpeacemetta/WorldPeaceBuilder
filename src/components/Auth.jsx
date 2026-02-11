import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { supabase } from "../lib/supabase";

function getErrorMessage(error, fallback) {
  if (!error) return fallback;
  if (typeof error === "string") return error;
  return error.message || fallback;
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
        setSignInError(getErrorMessage(signInErrorResult, "Unable to sign in"));
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
        setSignInError(getErrorMessage(error, "Unable to send reset email"));
        return;
      }

      setSignInSuccess("Check your email for reset link");
    } finally {
      setSignInLoading(false);
    }
  };

  const handleSignUp = async () => {
    resetSignUpMessages();

    const email = signUpEmail.trim();
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
      const { data: signUpData, error: signUpErrorResult } = await supabase.auth.signUp({
        email,
        password: signUpPassword,
      });

      if (signUpErrorResult) {
        setSignUpError(getErrorMessage(signUpErrorResult, "Unable to sign up"));
        return;
      }

      const userId = signUpData?.user?.id;
      if (!userId) {
        setSignUpSuccess("Sign up successful. Check your email to confirm your account.");
        return;
      }

      const { error: profileError } = await supabase.rpc("create_profile", {
        p_user_id: userId,
        p_username: username,
      });

      if (profileError) {
        const message = getErrorMessage(profileError, "Unable to create profile").toLowerCase();
        if (message.includes("duplicate") || message.includes("unique")) {
          setSignUpError("Username already taken");
        } else {
          setSignUpError(getErrorMessage(profileError, "Unable to create profile"));
        }
        await supabase.auth.signOut();
        return;
      }

      setSignUpSuccess("Account created. You can now sign in.");
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
          <CardTitle>Welcome to MacroTracker</CardTitle>
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
              {signUpSuccess ? <p className="text-sm text-emerald-600 dark:text-emerald-400">{signUpSuccess}</p> : null}
            </TabsContent>
          </Tabs>
        </CardContent>
      </Card>
    </div>
  );
}
