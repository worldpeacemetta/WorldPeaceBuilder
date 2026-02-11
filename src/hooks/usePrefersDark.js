import { useEffect, useState } from "react";

function isDarkMode() {
  if (typeof document === "undefined") return false;
  return document.documentElement.classList.contains("dark");
}

export default function usePrefersDark() {
  const [isDark, setIsDark] = useState(() => isDarkMode());

  useEffect(() => {
    if (typeof document === "undefined") return undefined;

    const observer = new MutationObserver(() => {
      setIsDark(isDarkMode());
    });

    observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    });

    setIsDark(isDarkMode());

    return () => observer.disconnect();
  }, []);

  return isDark;
}
