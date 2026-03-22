// @ts-nocheck
import { useState, useEffect, useCallback } from "react";
import { useTranslation } from "react-i18next";
import { setLanguage } from "../i18n";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

// ─── Formula helpers ────────────────────────────────────────────────────────

const ACTIVITY_MULTIPLIERS = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  athlete: 1.9,
};

function computeBMR(sex, age, heightCm, weightKg, bodyFatPct) {
  if (!age || !heightCm || !weightKg) return null;
  if (bodyFatPct != null && bodyFatPct > 0) {
    // Katch-McArdle (more accurate when body fat is known)
    const lbm = weightKg * (1 - bodyFatPct / 100);
    return 370 + 21.6 * lbm;
  }
  // Mifflin-St Jeor
  const base = 10 * weightKg + 6.25 * heightCm - 5 * age;
  return sex === "female" ? base - 161 : base + 5;
}

function computeMacrosForGoal(sex, age, heightCm, weightKg, bodyFatPct, activity, goalSetup, aggressiveness) {
  const bmr = computeBMR(sex, age, heightCm, weightKg, bodyFatPct);
  if (!bmr) return null;

  const tdee = Math.round(bmr * (ACTIVITY_MULTIPLIERS[activity] ?? 1.55));

  const deltas = {
    maintenance: 0,
    cutting: aggressiveness === "aggressive" ? -600 : -350,
    bulking: aggressiveness === "aggressive" ? 450 : 250,
  };
  const kcal = Math.round(tdee + (deltas[goalSetup] ?? 0));

  const proteinPerKg = goalSetup === "cutting" ? 2.2 : 1.8;
  const protein = Math.round((weightKg ?? 70) * proteinPerKg);
  const fat = Math.max(30, Math.round((kcal * 0.275) / 9));
  const carbs = Math.max(0, Math.round((kcal - protein * 4 - fat * 9) / 4));

  return { kcal, protein, fat, carbs, tdee };
}

// For dual (train/rest) mode: compute a baseline then shift carbs/fat
function computeDualMacros(sex, age, heightCm, weightKg, bodyFatPct, activity, aggressiveness) {
  const base = computeMacrosForGoal(sex, age, heightCm, weightKg, bodyFatPct, activity, "maintenance", aggressiveness);
  if (!base) return null;

  const carbShift = 55; // g carbs moved from rest → training day
  const fatShift = 6;   // g fat moved from training → rest day (balances calories roughly)

  const trainKcal = base.kcal + carbShift * 4 - fatShift * 9;
  const restKcal  = base.kcal - carbShift * 4 + fatShift * 9;

  return {
    train: {
      kcal: Math.round(trainKcal),
      protein: base.protein,
      carbs: base.carbs + carbShift,
      fat: Math.max(20, base.fat - fatShift),
    },
    rest: {
      kcal: Math.round(restKcal),
      protein: base.protein,
      carbs: Math.max(0, base.carbs - carbShift),
      fat: base.fat + fatShift,
    },
    tdee: base.tdee,
  };
}

// ─── Unit conversion helpers ─────────────────────────────────────────────────

function cmToFtIn(cm) {
  const totalInches = cm / 2.54;
  const ft = Math.floor(totalInches / 12);
  const inch = Math.round(totalInches % 12);
  return { ft, inch };
}

function ftInToCm(ft, inch) {
  return Math.round((Number(ft) * 12 + Number(inch)) * 2.54);
}

function kgToLb(kg) {
  return Math.round(kg * 2.20462 * 10) / 10;
}

function lbToKg(lb) {
  return Math.round((lb / 2.20462) * 10) / 10;
}

// ─── Sub-components ──────────────────────────────────────────────────────────

function ProgressBar({ step, total }) {
  return (
    <div className="flex items-center gap-1.5 mb-6">
      {Array.from({ length: total }).map((_, i) => (
        <div
          key={i}
          className={`h-1 flex-1 rounded-full transition-all duration-300 ${
            i < step
              ? "bg-violet-500"
              : i === step
              ? "bg-violet-300 dark:bg-violet-700"
              : "bg-slate-200 dark:bg-slate-700"
          }`}
        />
      ))}
    </div>
  );
}

function StepWrapper({ title, subtitle, children, onNext, onSkip, nextLabel, nextDisabled = false, isLast = false }) {
  const { t } = useTranslation();
  const label = nextLabel ?? t("onboarding.continueButton");
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-900 dark:text-slate-50 leading-tight">{title}</h2>
        {subtitle && <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">{subtitle}</p>}
      </div>

      <div className="space-y-4">{children}</div>

      <div className="flex gap-3 pt-2">
        <Button
          className="flex-1 bg-violet-600 hover:bg-violet-700 text-white"
          onClick={onNext}
          disabled={nextDisabled}
        >
          {label}
        </Button>
        {onSkip && !isLast && (
          <Button variant="ghost" className="text-slate-400 hover:text-slate-600 dark:hover:text-slate-300" onClick={onSkip}>
            {t("onboarding.skipButton")}
          </Button>
        )}
      </div>
    </div>
  );
}

function GoalCard({ icon, label, description, selected, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full text-left p-4 rounded-xl border-2 transition-all ${
        selected
          ? "border-violet-500 bg-violet-50 dark:bg-violet-950/40"
          : "border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600"
      }`}
    >
      <div className="flex items-start gap-3">
        <span className="text-xl mt-0.5">{icon}</span>
        <div>
          <p className="font-semibold text-sm text-slate-900 dark:text-slate-100">{label}</p>
          <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">{description}</p>
        </div>
        <div className="ml-auto mt-0.5">
          <div
            className={`w-4 h-4 rounded-full border-2 transition-all ${
              selected ? "border-violet-500 bg-violet-500" : "border-slate-300 dark:border-slate-600"
            }`}
          />
        </div>
      </div>
    </button>
  );
}

function ActivityCard({ value, label, description, selected, onClick }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={`w-full text-left px-4 py-3 rounded-xl border-2 transition-all ${
        selected
          ? "border-violet-500 bg-violet-50 dark:bg-violet-950/40"
          : "border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600"
      }`}
    >
      <div className="flex items-center justify-between">
        <div>
          <p className="font-semibold text-sm text-slate-900 dark:text-slate-100">{label}</p>
          <p className="text-xs text-slate-500 dark:text-slate-400">{description}</p>
        </div>
        <div
          className={`w-4 h-4 rounded-full border-2 flex-shrink-0 transition-all ${
            selected ? "border-violet-500 bg-violet-500" : "border-slate-300 dark:border-slate-600"
          }`}
        />
      </div>
    </button>
  );
}

function MacroBox({ label, value, onChange, color }) {
  const { t } = useTranslation();
  return (
    <div className={`rounded-xl p-3 ${color} space-y-1`}>
      <p className="text-xs font-semibold uppercase tracking-wide opacity-70">{label}</p>
      <input
        type="number"
        min={0}
        value={value}
        onChange={(e) => onChange(Math.max(0, Number(e.target.value)))}
        className="w-full bg-transparent text-2xl font-bold outline-none [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none"
      />
      <p className="text-xs opacity-60">{label === t("macro.kcal") ? "kcal" : "g"}</p>
    </div>
  );
}

// ─── Main component ──────────────────────────────────────────────────────────

const TOTAL_STEPS = 7;

export default function OnboardingQuestionnaire({ userEmail, onComplete }) {
  const { t, i18n } = useTranslation();
  const [step, setStep] = useState(0);
  const [saving, setSaving] = useState(false);

  // Step 0 — Language
  const [selectedLang, setSelectedLang] = useState(i18n.language?.startsWith("fr") ? "fr" : "en");

  // Step 1 — Name
  const emailPrefix = userEmail?.split("@")[0] ?? "";
  const [displayName, setDisplayName] = useState(emailPrefix);

  // Step 2 — Age & Sex
  const [age, setAge] = useState("");
  const [sex, setSex] = useState(""); // "male" | "female" | "other"

  // Step 3 — Height & Weight
  const [unit, setUnit] = useState("metric"); // "metric" | "imperial"
  const [heightCm, setHeightCm] = useState("");
  const [heightFt, setHeightFt] = useState("");
  const [heightIn, setHeightIn] = useState("");
  const [weightKg, setWeightKg] = useState("");
  const [weightLb, setWeightLb] = useState("");
  const [bodyFatPct, setBodyFatPct] = useState("");

  // Step 4 — Activity
  const [activity, setActivity] = useState("moderate");

  // Step 5 — Goal
  const [goalMode, setGoalMode] = useState("maintenance"); // "maintenance" | "cutting" | "bulking" | "dual"
  const [aggressiveness, setAggressiveness] = useState("moderate"); // "moderate" | "aggressive"

  // Step 6 — Review macros (editable)
  const [macros, setMacros] = useState(null); // { kcal, protein, fat, carbs } or dual {train, rest}

  // Sync unit changes for height/weight fields
  const switchUnit = useCallback((newUnit) => {
    if (newUnit === unit) return;
    if (newUnit === "imperial") {
      if (heightCm) {
        const { ft, inch } = cmToFtIn(Number(heightCm));
        setHeightFt(String(ft));
        setHeightIn(String(inch));
      }
      if (weightKg) setWeightLb(String(kgToLb(Number(weightKg))));
    } else {
      if (heightFt || heightIn) setHeightCm(String(ftInToCm(heightFt || 0, heightIn || 0)));
      if (weightLb) setWeightKg(String(lbToKg(Number(weightLb))));
    }
    setUnit(newUnit);
  }, [unit, heightCm, heightFt, heightIn, weightKg, weightLb]);

  // Compute macros when reaching step 6
  useEffect(() => {
    if (step !== 6) return;

    const resolvedHeightCm = unit === "metric" ? Number(heightCm) : ftInToCm(heightFt || 0, heightIn || 0);
    const resolvedWeightKg = unit === "metric" ? Number(weightKg) : lbToKg(Number(weightLb));
    const resolvedAge = age ? Number(age) : null;
    const resolvedSex = sex || "male";
    const resolvedBf = bodyFatPct ? Number(bodyFatPct) : null;

    if (goalMode === "dual") {
      const dual = computeDualMacros(resolvedSex, resolvedAge, resolvedHeightCm, resolvedWeightKg, resolvedBf, activity, aggressiveness);
      setMacros(dual ? { mode: "dual", ...dual } : { mode: "dual", train: { kcal: 2200, protein: 160, carbs: 250, fat: 60 }, rest: { kcal: 1800, protein: 160, carbs: 140, fat: 67 }, tdee: null });
    } else {
      const single = computeMacrosForGoal(resolvedSex, resolvedAge, resolvedHeightCm, resolvedWeightKg, resolvedBf, activity, goalMode, aggressiveness);
      setMacros(single ? { mode: "single", ...single } : { mode: "single", kcal: 2000, protein: 150, carbs: 200, fat: 65, tdee: null });
    }
  }, [step]); // eslint-disable-line react-hooks/exhaustive-deps

  const next = () => setStep((s) => Math.min(s + 1, TOTAL_STEPS - 1));
  const skip = () => setStep((s) => Math.min(s + 1, TOTAL_STEPS - 1));

  const handleComplete = async () => {
    setSaving(true);
    try {
      const resolvedHeightCm = unit === "metric" ? Number(heightCm) || 0 : ftInToCm(heightFt || 0, heightIn || 0);
      const resolvedWeightKg = unit === "metric" ? Number(weightKg) || 0 : lbToKg(Number(weightLb) || 0);

      const profile = {
        age: age ? Number(age) : undefined,
        sex: sex || undefined,
        heightCm: resolvedHeightCm || undefined,
        weightKg: resolvedWeightKg || undefined,
        bodyFatPct: bodyFatPct ? Number(bodyFatPct) : undefined,
        activity,
      };

      let dailyGoals;
      if (macros?.mode === "dual") {
        dailyGoals = {
          setup: "dual",
          dual: {
            train: { kcal: macros.train.kcal, protein: macros.train.protein, carbs: macros.train.carbs, fat: macros.train.fat },
            rest: { kcal: macros.rest.kcal, protein: macros.rest.protein, carbs: macros.rest.carbs, fat: macros.rest.fat },
            active: "train",
          },
        };
      } else {
        const g = { kcal: macros?.kcal ?? 2000, protein: macros?.protein ?? 150, carbs: macros?.carbs ?? 200, fat: macros?.fat ?? 65 };
        dailyGoals = { setup: goalMode === "maintenance" ? "maintenance" : goalMode, [goalMode === "maintenance" ? "maintenance" : goalMode]: g };
      }

      await onComplete({ displayName: displayName.trim() || emailPrefix, profile, dailyGoals });
    } finally {
      setSaving(false);
    }
  };

  // ── Render steps ──────────────────────────────────────────────────────────

  const renderStep = () => {
    switch (step) {
      // ── Step 0: Language ──────────────────────────────────────────────────
      case 0:
        return (
          <StepWrapper
            title={t("onboarding.langStepTitle")}
            subtitle={t("onboarding.langStepSubtitle")}
            onNext={next}
          >
            <div className="grid grid-cols-2 gap-3">
              {([
                { code: "en", flag: "🇬🇧", label: "English" },
                { code: "fr", flag: "🇫🇷", label: "Français" },
              ] as const).map(({ code, flag, label }) => (
                <button
                  key={code}
                  type="button"
                  onClick={() => {
                    setSelectedLang(code);
                    setLanguage(code);
                  }}
                  className={`flex flex-col items-center gap-2 py-6 rounded-2xl border-2 font-semibold text-sm transition-all ${
                    selectedLang === code
                      ? "border-violet-500 bg-violet-50 dark:bg-violet-950/40 text-violet-700 dark:text-violet-300"
                      : "border-slate-200 dark:border-slate-700 hover:border-slate-300 dark:hover:border-slate-600 text-slate-700 dark:text-slate-300"
                  }`}
                >
                  <span className="text-4xl">{flag}</span>
                  <span>{label}</span>
                  {selectedLang === code && (
                    <div className="w-4 h-4 rounded-full bg-violet-500 flex items-center justify-center">
                      <svg className="w-2.5 h-2.5 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={3} d="M5 13l4 4L19 7" />
                      </svg>
                    </div>
                  )}
                </button>
              ))}
            </div>
          </StepWrapper>
        );

      // ── Step 1: Name ──────────────────────────────────────────────────────
      case 1:
        return (
          <StepWrapper
            title={t("onboarding.step0Title")}
            subtitle={t("onboarding.step0Subtitle")}
            onNext={next}
            nextDisabled={!displayName.trim()}
          >
            <div className="space-y-2">
              <Label htmlFor="onb-name">{t("onboarding.step0NameLabel")}</Label>
              <Input
                id="onb-name"
                type="text"
                value={displayName}
                onChange={(e) => setDisplayName(e.target.value)}
                placeholder={t("onboarding.step0NamePlaceholder")}
                className="text-lg"
                autoFocus
                onKeyDown={(e) => e.key === "Enter" && displayName.trim() && next()}
              />
            </div>
          </StepWrapper>
        );

      // ── Step 2: Age & Sex ─────────────────────────────────────────────────
      case 2:
        return (
          <StepWrapper
            title={t("onboarding.step1Title")}
            subtitle={t("onboarding.step1Subtitle")}
            onNext={next}
            onSkip={skip}
          >
            <div className="space-y-4">
              <div className="space-y-2">
                <Label htmlFor="onb-age">{t("onboarding.step1AgeLabel")}</Label>
                <Input
                  id="onb-age"
                  type="number"
                  min={10}
                  max={120}
                  value={age}
                  onChange={(e) => setAge(e.target.value)}
                  placeholder={t("onboarding.step1AgePlaceholder")}
                />
              </div>

              <div className="space-y-2">
                <Label>{t("onboarding.step1SexLabel")} <span className="text-slate-400 font-normal">{t("onboarding.step1SexHint")}</span></Label>
                <div className="grid grid-cols-3 gap-2">
                  {[
                    { value: "male", label: t("onboarding.step1Male") },
                    { value: "female", label: t("onboarding.step1Female") },
                    { value: "other", label: t("onboarding.step1Other") },
                  ].map((opt) => (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setSex(opt.value)}
                      className={`py-2.5 rounded-xl border-2 text-sm font-medium transition-all ${
                        sex === opt.value
                          ? "border-violet-500 bg-violet-50 dark:bg-violet-950/40 text-violet-700 dark:text-violet-300"
                          : "border-slate-200 dark:border-slate-700 hover:border-slate-300"
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </StepWrapper>
        );

      // ── Step 3: Height & Weight ───────────────────────────────────────────
      case 3:
        return (
          <StepWrapper
            title={t("onboarding.step2Title")}
            subtitle={t("onboarding.step2Subtitle")}
            onNext={next}
            onSkip={skip}
          >
            {/* Unit toggle */}
            <div className="inline-flex rounded-lg border border-slate-200 dark:border-slate-700 p-0.5 gap-0.5">
              {["metric", "imperial"].map((u) => (
                <button
                  key={u}
                  type="button"
                  onClick={() => switchUnit(u)}
                  className={`px-4 py-1.5 rounded-md text-sm font-medium transition-all ${
                    unit === u ? "bg-violet-600 text-white" : "text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800"
                  }`}
                >
                  {u === "metric" ? "kg / cm" : "lb / ft"}
                </button>
              ))}
            </div>

            {unit === "metric" ? (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label htmlFor="onb-height-cm">{t("onboarding.step2HeightCm")}</Label>
                  <Input id="onb-height-cm" type="number" min={100} max={250} value={heightCm} onChange={(e) => setHeightCm(e.target.value)} placeholder={t("onboarding.step2HeightCmPlaceholder")} />
                </div>
                <div className="space-y-2">
                  <Label htmlFor="onb-weight-kg">{t("onboarding.step2WeightKg")}</Label>
                  <Input id="onb-weight-kg" type="number" min={30} max={300} value={weightKg} onChange={(e) => setWeightKg(e.target.value)} placeholder={t("onboarding.step2WeightKgPlaceholder")} />
                </div>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-3">
                <div className="space-y-2">
                  <Label>{t("onboarding.step2Height")}</Label>
                  <div className="flex gap-2">
                    <div className="relative flex-1">
                      <Input type="number" min={3} max={8} value={heightFt} onChange={(e) => setHeightFt(e.target.value)} placeholder="5" />
                      <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-slate-400">ft</span>
                    </div>
                    <div className="relative flex-1">
                      <Input type="number" min={0} max={11} value={heightIn} onChange={(e) => setHeightIn(e.target.value)} placeholder="9" />
                      <span className="absolute right-2 top-1/2 -translate-y-1/2 text-xs text-slate-400">in</span>
                    </div>
                  </div>
                </div>
                <div className="space-y-2">
                  <Label htmlFor="onb-weight-lb">{t("onboarding.step2WeightLb")}</Label>
                  <Input id="onb-weight-lb" type="number" min={66} max={660} value={weightLb} onChange={(e) => setWeightLb(e.target.value)} placeholder={t("onboarding.step2WeightLbPlaceholder")} />
                </div>
              </div>
            )}

            <div className="space-y-2">
              <Label htmlFor="onb-bf">{t("onboarding.step2BodyFat")} <span className="text-slate-400 font-normal">{t("onboarding.step2BodyFatHint")}</span></Label>
              <Input id="onb-bf" type="number" min={3} max={60} value={bodyFatPct} onChange={(e) => setBodyFatPct(e.target.value)} placeholder={t("onboarding.step2BodyFatPlaceholder")} />
            </div>
          </StepWrapper>
        );

      // ── Step 4: Activity level ────────────────────────────────────────────
      case 4:
        return (
          <StepWrapper
            title={t("onboarding.step3Title")}
            subtitle={t("onboarding.step3Subtitle")}
            onNext={next}
            onSkip={skip}
          >
            <div className="space-y-2">
              {[
                { value: "sedentary", label: t("onboarding.step3Sedentary"), description: t("onboarding.step3SedentaryDesc") },
                { value: "light", label: t("onboarding.step3Light"), description: t("onboarding.step3LightDesc") },
                { value: "moderate", label: t("onboarding.step3Moderate"), description: t("onboarding.step3ModerateDesc") },
                { value: "active", label: t("onboarding.step3Active"), description: t("onboarding.step3ActiveDesc") },
                { value: "athlete", label: t("onboarding.step3Athlete"), description: t("onboarding.step3AthleteDesc") },
              ].map((opt) => (
                <ActivityCard key={opt.value} {...opt} selected={activity === opt.value} onClick={() => setActivity(opt.value)} />
              ))}
            </div>
          </StepWrapper>
        );

      // ── Step 5: Goal ──────────────────────────────────────────────────────
      case 5:
        return (
          <StepWrapper
            title={t("onboarding.step4Title")}
            subtitle={t("onboarding.step4Subtitle")}
            onNext={next}
            onSkip={skip}
          >
            <div className="space-y-2">
              <GoalCard icon="⚖️" label={t("onboarding.step4Maintain")} description={t("onboarding.step4MaintainDesc")} selected={goalMode === "maintenance"} onClick={() => setGoalMode("maintenance")} />
              <GoalCard icon="🔥" label={t("onboarding.step4Cutting")} description={t("onboarding.step4CuttingDesc")} selected={goalMode === "cutting"} onClick={() => setGoalMode("cutting")} />
              <GoalCard icon="💪" label={t("onboarding.step4Bulking")} description={t("onboarding.step4BulkingDesc")} selected={goalMode === "bulking"} onClick={() => setGoalMode("bulking")} />
              <GoalCard icon="📆" label={t("onboarding.step4Dual")} description={t("onboarding.step4DualDesc")} selected={goalMode === "dual"} onClick={() => setGoalMode("dual")} />
            </div>

            {(goalMode === "cutting" || goalMode === "bulking") && (
              <div className="pt-2 space-y-2">
                <p className="text-sm font-medium text-slate-700 dark:text-slate-300">{t("onboarding.step4HowAggressive")}</p>
                <div className="grid grid-cols-2 gap-2">
                  {[
                    { value: "moderate", label: goalMode === "cutting" ? t("onboarding.step4ModCutting") : t("onboarding.step4ModBulking") },
                    { value: "aggressive", label: goalMode === "cutting" ? t("onboarding.step4AggCutting") : t("onboarding.step4AggBulking") },
                  ].map((opt) => (
                    <button
                      key={opt.value}
                      type="button"
                      onClick={() => setAggressiveness(opt.value)}
                      className={`py-2.5 px-3 rounded-xl border-2 text-xs font-medium transition-all text-left ${
                        aggressiveness === opt.value
                          ? "border-violet-500 bg-violet-50 dark:bg-violet-950/40 text-violet-700 dark:text-violet-300"
                          : "border-slate-200 dark:border-slate-700 hover:border-slate-300"
                      }`}
                    >
                      {opt.label}
                    </button>
                  ))}
                </div>
              </div>
            )}
          </StepWrapper>
        );

      // ── Step 6: Macro review ──────────────────────────────────────────────
      case 6:
        if (!macros) return <div className="text-center py-12 text-slate-500">{t("onboarding.step5Computing")}</div>;

        return (
          <StepWrapper
            title={t("onboarding.step5Title")}
            subtitle={macros.tdee ? t("onboarding.step5SubtitleTDEE", { tdee: macros.tdee }) : t("onboarding.step5Subtitle")}
            onNext={handleComplete}
            nextLabel={saving ? t("onboarding.saving") : t("onboarding.getStarted")}
            nextDisabled={saving}
            isLast
          >
            {macros.mode === "dual" ? (
              <div className="space-y-4">
                <p className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400">{t("onboarding.step5TrainingDays")}</p>
                <div className="grid grid-cols-2 gap-2">
                  <MacroBox label={t("macro.kcal")} value={macros.train.kcal} onChange={(v) => setMacros((m) => ({ ...m, train: { ...m.train, kcal: v } }))} color="bg-violet-50 dark:bg-violet-950/30 text-violet-900 dark:text-violet-100" />
                  <MacroBox label={t("macro.protein")} value={macros.train.protein} onChange={(v) => setMacros((m) => ({ ...m, train: { ...m.train, protein: v } }))} color="bg-blue-50 dark:bg-blue-950/30 text-blue-900 dark:text-blue-100" />
                  <MacroBox label={t("macro.carbs")} value={macros.train.carbs} onChange={(v) => setMacros((m) => ({ ...m, train: { ...m.train, carbs: v } }))} color="bg-amber-50 dark:bg-amber-950/30 text-amber-900 dark:text-amber-100" />
                  <MacroBox label={t("macro.fat")} value={macros.train.fat} onChange={(v) => setMacros((m) => ({ ...m, train: { ...m.train, fat: v } }))} color="bg-rose-50 dark:bg-rose-950/30 text-rose-900 dark:text-rose-100" />
                </div>

                <p className="text-xs font-semibold uppercase tracking-widest text-slate-500 dark:text-slate-400 pt-2">{t("onboarding.step5RestDays")}</p>
                <div className="grid grid-cols-2 gap-2">
                  <MacroBox label={t("macro.kcal")} value={macros.rest.kcal} onChange={(v) => setMacros((m) => ({ ...m, rest: { ...m.rest, kcal: v } }))} color="bg-violet-50 dark:bg-violet-950/30 text-violet-900 dark:text-violet-100" />
                  <MacroBox label={t("macro.protein")} value={macros.rest.protein} onChange={(v) => setMacros((m) => ({ ...m, rest: { ...m.rest, protein: v } }))} color="bg-blue-50 dark:bg-blue-950/30 text-blue-900 dark:text-blue-100" />
                  <MacroBox label={t("macro.carbs")} value={macros.rest.carbs} onChange={(v) => setMacros((m) => ({ ...m, rest: { ...m.rest, carbs: v } }))} color="bg-amber-50 dark:bg-amber-950/30 text-amber-900 dark:text-amber-100" />
                  <MacroBox label={t("macro.fat")} value={macros.rest.fat} onChange={(v) => setMacros((m) => ({ ...m, rest: { ...m.rest, fat: v } }))} color="bg-rose-50 dark:bg-rose-950/30 text-rose-900 dark:text-rose-100" />
                </div>
              </div>
            ) : (
              <div className="grid grid-cols-2 gap-2">
                <MacroBox label={t("macro.kcal")} value={macros.kcal} onChange={(v) => setMacros((m) => ({ ...m, kcal: v }))} color="bg-violet-50 dark:bg-violet-950/30 text-violet-900 dark:text-violet-100" />
                <MacroBox label={t("macro.protein")} value={macros.protein} onChange={(v) => setMacros((m) => ({ ...m, protein: v }))} color="bg-blue-50 dark:bg-blue-950/30 text-blue-900 dark:text-blue-100" />
                <MacroBox label={t("macro.carbs")} value={macros.carbs} onChange={(v) => setMacros((m) => ({ ...m, carbs: v }))} color="bg-amber-50 dark:bg-amber-950/30 text-amber-900 dark:text-amber-100" />
                <MacroBox label={t("macro.fat")} value={macros.fat} onChange={(v) => setMacros((m) => ({ ...m, fat: v }))} color="bg-rose-50 dark:bg-rose-950/30 text-rose-900 dark:text-rose-100" />
              </div>
            )}

            <p className="text-xs text-slate-400 dark:text-slate-500 text-center">{t("onboarding.step5SettingsHint")}</p>
          </StepWrapper>
        );

      default:
        return null;
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-950/60 backdrop-blur-sm px-4">
      <div className="w-full max-w-md bg-white dark:bg-slate-900 rounded-2xl shadow-2xl p-7 max-h-[90vh] overflow-y-auto">
        <ProgressBar step={step} total={TOTAL_STEPS} />
        {renderStep()}
      </div>
    </div>
  );
}
