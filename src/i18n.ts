import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import en from "./locales/en.json";
import fr from "./locales/fr.json";

const K_LANG = "mt_lang";

i18n
  .use(initReactI18next)
  .init({
    resources: { en: { translation: en }, fr: { translation: fr } },
    lng: localStorage.getItem(K_LANG) ?? "en",
    fallbackLng: "en",
    interpolation: { escapeValue: false },
    // Resources are bundled inline — initialize synchronously so useTranslation()
    // never throws a Suspense promise before the first render.
    initImmediate: false,
    // Belt-and-suspenders: also disable Suspense integration so the hook never
    // throws a Promise even if init timing is unexpected.
    react: { useSuspense: false },
  });

export function setLanguage(lang: string) {
  i18n.changeLanguage(lang);
  localStorage.setItem(K_LANG, lang);
}

export default i18n;
