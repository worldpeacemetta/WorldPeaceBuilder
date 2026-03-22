// @ts-nocheck
import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
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

function toFriendlyAuthError(error, fallback, t) {
  const message = getErrorMessage(error, fallback).toLowerCase();
  if (message.includes("email not confirmed") || message.includes("email_not_confirmed")) {
    return t("auth.emailNotConfirmed");
  }
  if (message.includes("rate limit") || message.includes("too many") || message.includes("email rate limit exceeded")) {
    return t("auth.tooManyEmails");
  }
  return getErrorMessage(error, fallback);
}

export default function Auth() {
  const { t } = useTranslation();
  const [tab, setTab] = useState("signin");

  const [identifier, setIdentifier] = useState("");
  const [signInPassword, setSignInPassword] = useState("");
  const [isResetMode, setIsResetMode] = useState(false);
  const [resetEmail, setResetEmail] = useState("");
  const [signInError, setSignInError] = useState("");
  const [signInSuccess, setSignInSuccess] = useState("");
  const [signInLoading, setSignInLoading] = useState(false);

  const [registerEmail, setRegisterEmail] = useState("");
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
    !!registerEmail.trim() && !!registerPassword && !!confirmPassword && !passwordsDoNotMatch && !registerLoading;

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
      setSignInError(t("auth.emailOrUsername") + " " + t("error.usernameRequired").toLowerCase());
      return;
    }

    if (!signInPassword) {
      setSignInError(t("auth.password") + " is required");
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
          setSignInError(getErrorMessage(lookupError, t("auth.unableToFindUsername")));
          return;
        }

        if (!resolvedEmail) {
          setSignInError(t("auth.usernameNotFound"));
          return;
        }

        email = resolvedEmail;
      }

      const { error: signInErrorResult } = await supabase.auth.signInWithPassword({
        email,
        password: signInPassword,
      });

      if (signInErrorResult) {
        setSignInError(toFriendlyAuthError(signInErrorResult, t("auth.unableToSignIn"), t));
      }
    } finally {
      setSignInLoading(false);
    }
  };

  const handlePasswordReset = async () => {
    resetSignInMessages();
    const email = resetEmail.trim();

    if (!email || !email.includes("@")) {
      setSignInError(t("auth.resetEmailRequired"));
      return;
    }

    setSignInLoading(true);

    try {
      const { error } = await supabase.auth.resetPasswordForEmail(email);
      if (error) {
        setSignInError(toFriendlyAuthError(error, t("auth.unableToSendReset"), t));
        return;
      }

      setSignInSuccess(t("auth.checkEmailReset"));
    } finally {
      setSignInLoading(false);
    }
  };

  const handleResendConfirmation = async () => {
    const email = registerEmail.trim().toLowerCase();
    if (!email.includes("@")) {
      setRegisterError(t("auth.validEmailRequired"));
      return;
    }

    setResendLoading(true);
    setResendMessage("");
    setRegisterError("");

    try {
      const { error } = await supabase.auth.resend({ type: "signup", email });
      if (error) {
        setRegisterError(toFriendlyAuthError(error, t("auth.unableResendConfirmation"), t));
        return;
      }
      setResendMessage(t("auth.confirmationEmailSent"));
    } finally {
      setResendLoading(false);
    }
  };

  const handleRegister = async () => {
    resetRegisterMessages();

    const email = registerEmail.trim().toLowerCase();

    if (!email.includes("@")) {
      setRegisterError(t("auth.validEmailRegister"));
      return;
    }

    if (passwordsDoNotMatch) {
      setRegisterError(t("auth.passwordsDoNotMatch"));
      return;
    }

    setRegisterLoading(true);

    try {
      const emailPrefix = email.split("@")[0].replace(/[^a-z0-9_]/gi, "").toLowerCase() || "user";
      const tempUsername = `_new_${emailPrefix}_${Math.random().toString(36).slice(2, 7)}`;

      const { error: registerErrorResult } = await supabase.auth.signUp({
        email,
        password: registerPassword,
        options: { data: { username: tempUsername } },
      });

      if (registerErrorResult) {
        setRegisterError(toFriendlyAuthError(registerErrorResult, t("auth.unableToRegister"), t));
        return;
      }

      setRegisterSuccess(t("auth.accountCreated"));
    } finally {
      setRegisterLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 dark:bg-slate-950 flex items-center justify-center px-4">
      <Card className="w-full max-w-md border-slate-200 dark:border-slate-800">
        <CardHeader className="pb-0">
          <div className="flex justify-center mb-4">
            <img
              src="/brand/onebodyonelife-logo-light.png"
              alt="OneBodyOneLife"
              className="block dark:hidden h-28 sm:h-32 md:h-36 w-auto object-contain mx-auto"
            />
            <img
              src="/brand/onebodyonelife-logo-dark.png"
              alt="OneBodyOneLife"
              className="hidden dark:block h-28 sm:h-32 md:h-36 w-auto object-contain mx-auto"
            />
          </div>
        </CardHeader>
        <CardContent>
          <Tabs value={tab} onValueChange={setTab} className="space-y-4">
            <TabsList className="grid w-full grid-cols-2">
              <TabsTrigger value="signin">{t("auth.signInTab")}</TabsTrigger>
              <TabsTrigger value="register">{t("auth.registerTab")}</TabsTrigger>
            </TabsList>

            <TabsContent value="signin" className="space-y-4">
              {!isResetMode ? (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="signin-identifier">{t("auth.emailOrUsername")}</Label>
                    <Input
                      id="signin-identifier"
                      type="text"
                      value={identifier}
                      onChange={(event) => setIdentifier(event.target.value)}
                      placeholder={t("auth.emailOrUsernamePlaceholder")}
                    />
                  </div>

                  <div className="space-y-2">
                    <Label htmlFor="signin-password">{t("auth.password")}</Label>
                    <Input
                      id="signin-password"
                      type="password"
                      value={signInPassword}
                      onChange={(event) => setSignInPassword(event.target.value)}
                      placeholder="••••••••"
                    />
                  </div>

                  <Button className="w-full" onClick={handleSignIn} disabled={signInLoading}>
                    {signInLoading ? t("auth.signingIn") : t("auth.signIn")}
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
                    {t("auth.forgotPassword")}
                  </button>
                </>
              ) : (
                <>
                  <div className="space-y-2">
                    <Label htmlFor="reset-email">{t("auth.email")}</Label>
                    <Input
                      id="reset-email"
                      type="email"
                      value={resetEmail}
                      onChange={(event) => setResetEmail(event.target.value)}
                      placeholder={t("auth.emailPlaceholder")}
                    />
                  </div>

                  <div className="flex gap-2">
                    <Button className="flex-1" onClick={handlePasswordReset} disabled={signInLoading}>
                      {signInLoading ? t("auth.sending") : t("auth.sendResetLink")}
                    </Button>
                    <Button
                      variant="outline"
                      className="flex-1"
                      onClick={() => {
                        setIsResetMode(false);
                        resetSignInMessages();
                      }}
                    >
                      {t("auth.back")}
                    </Button>
                  </div>
                </>
              )}

              {signInError ? <p className="text-sm text-red-600 dark:text-red-400">{signInError}</p> : null}
              {signInSuccess ? <p className="text-sm text-emerald-600 dark:text-emerald-400">{signInSuccess}</p> : null}
            </TabsContent>

            <TabsContent value="register" className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="register-email">{t("auth.email")}</Label>
                <Input
                  id="register-email"
                  type="email"
                  value={registerEmail}
                  onChange={(event) => setRegisterEmail(event.target.value)}
                  placeholder={t("auth.emailPlaceholder")}
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="register-password">{t("auth.password")}</Label>
                <Input
                  id="register-password"
                  type="password"
                  value={registerPassword}
                  onChange={(event) => setRegisterPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              <div className="space-y-2">
                <Label htmlFor="register-confirm-password">{t("auth.confirmPassword")}</Label>
                <Input
                  id="register-confirm-password"
                  type="password"
                  value={confirmPassword}
                  onChange={(event) => setConfirmPassword(event.target.value)}
                  placeholder="••••••••"
                />
              </div>

              {passwordsDoNotMatch ? (
                <p className="text-sm text-amber-600 dark:text-amber-400">{t("auth.passwordsDoNotMatch")}</p>
              ) : null}

              <Button className="w-full" onClick={handleRegister} disabled={!canSubmitRegister}>
                {registerLoading ? t("auth.creatingAccount") : t("auth.register")}
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
                    {resendLoading ? t("auth.resending") : t("auth.resendConfirmation")}
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
