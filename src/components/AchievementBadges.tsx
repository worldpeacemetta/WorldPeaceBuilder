import { useState } from "react";

export interface BadgeDef {
  id: number;
  stringId: string;
  name: string;
  desc: string;
  category: string;
  shape: string;
  colors: [string, string];
  icon: string;
  accent: string;
}

export const BADGES: BadgeDef[] = [
  { id: 1, stringId: "log_streak_7", name: "Week Logger", desc: "Log food 7 days in a row", category: "Logging Streaks", shape: "rounded", colors: ["#FF6B35", "#FF9F1C"], icon: "calendar7", accent: "#FFF3E0" },
  { id: 2, stringId: "log_streak_14", name: "Fortnight Logger", desc: "Log food 14 days in a row", category: "Logging Streaks", shape: "rounded", colors: ["#E8553D", "#FF6B35"], icon: "calendar14", accent: "#FFE0D0" },
  { id: 3, stringId: "log_streak_30", name: "Monthly Logger", desc: "Log food 30 days in a row", category: "Logging Streaks", shape: "rounded", colors: ["#C62828", "#E53935"], icon: "calendar30", accent: "#FFCDD2" },
  { id: 4, stringId: "log_streak_90", name: "Quarterly Logger", desc: "Log food 90 days in a row", category: "Logging Streaks", shape: "rounded", colors: ["#880E4F", "#C2185B"], icon: "calendar90", accent: "#F8BBD0" },
  { id: 5, stringId: "protein_streak_7", name: "Protein Week", desc: "Hit protein goal 7 days in a row", category: "Protein Streaks", shape: "hexagon", colors: ["#7B1FA2", "#AB47BC"], icon: "muscle7", accent: "#E1BEE7" },
  { id: 6, stringId: "protein_streak_14", name: "Protein Fortnight", desc: "Hit protein goal 14 days in a row", category: "Protein Streaks", shape: "hexagon", colors: ["#6A1B9A", "#8E24AA"], icon: "muscle14", accent: "#CE93D8" },
  { id: 7, stringId: "protein_streak_30", name: "Protein Month", desc: "Hit protein goal 30 days in a row", category: "Protein Streaks", shape: "hexagon", colors: ["#4A148C", "#7B1FA2"], icon: "muscle30", accent: "#BA68C8" },
  { id: 8, stringId: "protein_streak_90", name: "Protein Quarter", desc: "Hit protein goal 90 days in a row", category: "Protein Streaks", shape: "hexagon", colors: ["#311B92", "#5E35B1"], icon: "muscle90", accent: "#9575CD" },
  { id: 10, stringId: "veggie_streak_7", name: "Green Week", desc: "Log a veggie & fruit daily, 7 days", category: "Special", shape: "shield", colors: ["#2E7D32", "#43A047"], icon: "greenweek", accent: "#C8E6C9" },
  { id: 11, stringId: "log_first", name: "First Step", desc: "Log your first food", category: "Logging Milestones", shape: "circle", colors: ["#00897B", "#26A69A"], icon: "footprint", accent: "#B2DFDB" },
  { id: 12, stringId: "log_days_10", name: "10 Days Logged", desc: "Log food on 10 different days", category: "Logging Milestones", shape: "circle", colors: ["#00796B", "#00897B"], icon: "num10", accent: "#B2DFDB" },
  { id: 13, stringId: "log_days_30", name: "30 Days Logged", desc: "Log food on 30 different days", category: "Logging Milestones", shape: "circle", colors: ["#00695C", "#00796B"], icon: "num30", accent: "#80CBC4" },
  { id: 14, stringId: "log_days_100", name: "100 Days Logged", desc: "Log food on 100 different days", category: "Logging Milestones", shape: "circle", colors: ["#004D40", "#00695C"], icon: "num100", accent: "#4DB6AC" },
  { id: 15, stringId: "protein_first", name: "Protein Hit", desc: "Reach protein goal for the first time", category: "Protein Milestones", shape: "octagon", colors: ["#1565C0", "#1E88E5"], icon: "proteinFirst", accent: "#BBDEFB" },
  { id: 16, stringId: "protein_hits_10", name: "10 Protein Days", desc: "Hit protein goal on 10 days", category: "Protein Milestones", shape: "octagon", colors: ["#0D47A1", "#1565C0"], icon: "protein10", accent: "#90CAF9" },
  { id: 17, stringId: "protein_hits_20", name: "20 Protein Days", desc: "Hit protein goal on 20 days", category: "Protein Milestones", shape: "octagon", colors: ["#0D47A1", "#1565C0"], icon: "protein20", accent: "#90CAF9" },
  { id: 18, stringId: "protein_hits_50", name: "50 Protein Days", desc: "Hit protein goal on 50 days", category: "Protein Milestones", shape: "octagon", colors: ["#1A237E", "#283593"], icon: "protein50", accent: "#7986CB" },
  { id: 19, stringId: "protein_hits_100", name: "100 Protein Days", desc: "Hit protein goal on 100 days", category: "Protein Milestones", shape: "octagon", colors: ["#0D1B5E", "#1A237E"], icon: "protein100", accent: "#5C6BC0" },
  { id: 20, stringId: "perfect_day_1", name: "Perfect Day", desc: "All macros in range on the same day", category: "Perfect Days", shape: "star", colors: ["#F9A825", "#FDD835"], icon: "perfectStar", accent: "#FFF9C4" },
  { id: 21, stringId: "perfect_day_3", name: "Hat Trick", desc: "3 perfect days", category: "Perfect Days", shape: "star", colors: ["#F57F17", "#F9A825"], icon: "hatTrick", accent: "#FFF176" },
  { id: 22, stringId: "perfect_day_7", name: "Perfect Week", desc: "7 perfect days", category: "Perfect Days", shape: "star", colors: ["#E65100", "#EF6C00"], icon: "perfectWeek", accent: "#FFE0B2" },
  { id: 23, stringId: "perfect_day_30", name: "Perfect Month", desc: "30 perfect days", category: "Perfect Days", shape: "star", colors: ["#BF360C", "#D84315"], icon: "perfectMonth", accent: "#FFCCBC" },
  { id: 24, stringId: "veggie_day_1", name: "Eat the Rainbow", desc: "Log a vegetable or fruit", category: "Special", shape: "rounded", colors: ["#E91E63", "#FF5252"], icon: "rainbow", accent: "#FCE4EC" },
  { id: 25, stringId: "foods_added_10", name: "Food Collector", desc: "Add 10 foods to your database", category: "Food Database", shape: "rounded", colors: ["#0288D1", "#03A9F4"], icon: "book10", accent: "#B3E5FC" },
  { id: 26, stringId: "foods_added_25", name: "Food Enthusiast", desc: "Add 25 foods to your database", category: "Food Database", shape: "rounded", colors: ["#0277BD", "#0288D1"], icon: "book25", accent: "#81D4FA" },
  { id: 27, stringId: "foods_added_50", name: "Food Expert", desc: "Add 50 foods to your database", category: "Food Database", shape: "rounded", colors: ["#01579B", "#0277BD"], icon: "book50", accent: "#4FC3F7" },
  { id: 28, stringId: "foods_added_100", name: "Food Nerd", desc: "Add 100 foods to your database", category: "Food Database", shape: "rounded", colors: ["#004C8C", "#01579B"], icon: "book100", accent: "#29B6F6" },
  { id: 29, stringId: "foods_added_200", name: "Food Encyclopaedia", desc: "Add 200 foods to your database", category: "Food Database", shape: "rounded", colors: ["#002F6C", "#004C8C"], icon: "book200", accent: "#0288D1" },
  { id: 30, stringId: "recipe_first", name: "Home Chef", desc: "Create your first home recipe", category: "Special", shape: "shield", colors: ["#D84315", "#FF5722"], icon: "chef", accent: "#FFCCBC" },
];

export const BadgeShape = ({ shape, colors, children, locked, size = 120 }: any) => {
  const grayColors = ["#5A5A6A", "#6E6E7E"];
  const c = locked ? grayColors : colors;
  const id = `grad-${Math.random().toString(36).substr(2, 9)}`;
  const svgHeight = Math.round(size * 115 / 120);

  const shapes: any = {
    rounded: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <rect x="8" y="8" width="104" height="104" rx="22" fill="white" />
        <rect x="12" y="12" width="96" height="96" rx="18" fill={`url(#${id})`} />
      </>
    ),
    hexagon: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <polygon points="60,4 112,30 112,82 60,108 8,82 8,30" fill="white" />
        <polygon points="60,10 106,33 106,79 60,102 14,79 14,33" fill={`url(#${id})`} />
      </>
    ),
    circle: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <circle cx="60" cy="56" r="52" fill="white" />
        <circle cx="60" cy="56" r="46" fill={`url(#${id})`} />
      </>
    ),
    octagon: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <polygon points="38,4 82,4 108,30 108,78 82,104 38,104 12,78 12,30" fill="white" />
        <polygon points="40,10 80,10 102,32 102,76 80,98 40,98 18,76 18,32" fill={`url(#${id})`} />
      </>
    ),
    shield: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <path d="M60,4 L108,20 L108,68 Q108,92 60,110 Q12,92 12,68 L12,20 Z" fill="white" />
        <path d="M60,10 L102,24 L102,66 Q102,87 60,104 Q18,87 18,66 L18,24 Z" fill={`url(#${id})`} />
      </>
    ),
    star: (
      <>
        <defs>
          <linearGradient id={id} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={c[0]} />
            <stop offset="100%" stopColor={c[1]} />
          </linearGradient>
        </defs>
        <rect x="8" y="8" width="104" height="104" rx="22" fill="white" />
        <rect x="12" y="12" width="96" height="96" rx="18" fill={`url(#${id})`} />
      </>
    ),
  };

  return (
    <svg viewBox="0 0 120 115" width={size} height={svgHeight} style={{ overflow: "visible" }}>
      {shapes[shape]}
      {children}
      {locked && (
        <g opacity="0.85">
          <circle cx="60" cy="60" r="16" fill="rgba(30,30,40,0.7)" />
          <rect x="52" y="58" width="16" height="13" rx="2" fill="#9E9E9E" />
          <path d="M56,58 V53 Q56,48 60,48 Q64,48 64,53 V58" fill="none" stroke="#9E9E9E" strokeWidth="2.5" strokeLinecap="round" />
          <circle cx="60" cy="64" r="1.5" fill="#616161" />
        </g>
      )}
    </svg>
  );
};

export const BadgeIcon = ({ icon, locked, accent }: any) => {
  const op = locked ? 0.3 : 1;
  const white = "#FFFFFF";
  const pale = locked ? "#AAAAAA" : accent;

  const icons: any = {
    calendar7: <g opacity={op}><rect x="38" y="32" width="44" height="40" rx="5" fill={white} opacity="0.9" /><rect x="38" y="32" width="44" height="12" rx="5" fill={pale} /><line x1="48" y1="28" x2="48" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><line x1="72" y1="28" x2="72" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><text x="60" y="64" textAnchor="middle" fontSize="16" fontWeight="900" fill="#E65100" fontFamily="sans-serif">7</text><path d="M78,40 Q82,34 80,28 Q84,32 82,38 Q86,32 84,26 Q90,34 82,44" fill="#FF6B35" opacity="0.8" /></g>,
    calendar14: <g opacity={op}><rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" /><rect x="36" y="32" width="48" height="12" rx="5" fill={pale} /><line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#C62828" fontFamily="sans-serif">14</text><path d="M80,38 Q85,30 82,24 Q88,30 84,38 Q90,28 86,22 Q94,32 84,44" fill="#FF6B35" opacity="0.9" /></g>,
    calendar30: <g opacity={op}><rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" /><rect x="36" y="32" width="48" height="12" rx="5" fill={pale} /><line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#880E4F" fontFamily="sans-serif">30</text><path d="M80,36 Q86,26 82,18 Q90,28 85,38 Q92,24 88,16 Q98,30 86,44" fill="#FF5252" opacity="0.9" /><path d="M34,40 Q28,32 32,24 Q26,30 30,38" fill="#FF5252" opacity="0.6" /></g>,
    calendar90: <g opacity={op}><rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" /><rect x="36" y="32" width="48" height="12" rx="5" fill={pale} /><line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" /><text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#4A0020" fontFamily="sans-serif">90</text><path d="M80,34 Q88,22 84,14 Q92,24 86,36 Q94,20 90,12 Q100,28 88,44" fill="#FF1744" opacity="0.9" /><path d="M32,38 Q26,28 30,20 Q24,28 28,36 Q22,24 26,16 Q18,30 28,42" fill="#FF1744" opacity="0.7" /></g>,
    muscle7: <g opacity={op}><path d="M42,70 Q42,50 50,42 Q56,36 60,40 Q66,36 70,44 Q78,54 70,62" fill={white} opacity="0.9" /><path d="M44,68 Q44,52 51,44 Q56,39 60,42 Q65,38 69,46 Q76,54 69,61" fill={pale} /><text x="58" y="58" textAnchor="middle" fontSize="14" fontWeight="900" fill="#7B1FA2" fontFamily="sans-serif">7</text><circle cx="48" cy="38" r="3" fill={white} opacity="0.6" /><circle cx="72" cy="36" r="2" fill={white} opacity="0.4" /><rect x="38" y="70" width="44" height="6" rx="3" fill={white} opacity="0.7" /><rect x="34" y="67" width="8" height="12" rx="2" fill={white} opacity="0.8" /><rect x="78" y="67" width="8" height="12" rx="2" fill={white} opacity="0.8" /></g>,
    muscle14: <g opacity={op}><path d="M42,70 Q42,50 50,42 Q56,36 60,40 Q66,36 70,44 Q78,54 70,62" fill={white} opacity="0.9" /><path d="M44,68 Q44,52 51,44 Q56,39 60,42 Q65,38 69,46 Q76,54 69,61" fill={pale} /><text x="58" y="58" textAnchor="middle" fontSize="12" fontWeight="900" fill="#6A1B9A" fontFamily="sans-serif">14</text><rect x="38" y="70" width="44" height="6" rx="3" fill={white} opacity="0.7" /><rect x="32" y="67" width="10" height="12" rx="2" fill={white} opacity="0.8" /><rect x="78" y="67" width="10" height="12" rx="2" fill={white} opacity="0.8" /><circle cx="46" cy="36" r="4" fill={white} opacity="0.5" /><circle cx="74" cy="34" r="3" fill={white} opacity="0.4" /></g>,
    muscle30: <g opacity={op}><path d="M40,70 Q40,48 50,40 Q56,34 60,38 Q66,34 72,42 Q80,52 72,62" fill={white} opacity="0.9" /><path d="M42,68 Q42,50 51,42 Q56,37 60,40 Q65,36 71,44 Q78,52 71,61" fill={pale} /><text x="58" y="58" textAnchor="middle" fontSize="12" fontWeight="900" fill="#4A148C" fontFamily="sans-serif">30</text><rect x="36" y="70" width="48" height="7" rx="3.5" fill={white} opacity="0.7" /><rect x="30" y="66" width="12" height="14" rx="3" fill={white} opacity="0.8" /><rect x="78" y="66" width="12" height="14" rx="3" fill={white} opacity="0.8" /></g>,
    muscle90: <g opacity={op}><path d="M38,70 Q38,46 48,38 Q56,30 60,36 Q66,30 74,40 Q84,52 74,64" fill={white} opacity="0.9" /><path d="M40,68 Q40,48 49,40 Q56,33 60,38 Q65,33 73,42 Q82,52 73,63" fill={pale} /><text x="58" y="56" textAnchor="middle" fontSize="12" fontWeight="900" fill="#311B92" fontFamily="sans-serif">90</text><rect x="34" y="70" width="52" height="8" rx="4" fill={white} opacity="0.7" /><rect x="28" y="65" width="14" height="16" rx="3" fill={white} opacity="0.85" /><rect x="78" y="65" width="14" height="16" rx="3" fill={white} opacity="0.85" /></g>,
    greenweek: <g opacity={op}><circle cx="50" cy="50" r="14" fill="#81C784" /><path d="M50,36 Q58,42 50,50 Q42,42 50,36" fill="#43A047" /><line x1="50" y1="50" x2="50" y2="64" stroke="#388E3C" strokeWidth="2" /><circle cx="72" cy="54" r="10" fill="#FF7043" /><circle cx="72" cy="52" r="3" fill="#D84315" opacity="0.3" /><path d="M72,44 Q75,42 74,46" fill="#43A047" strokeWidth="1" stroke="#43A047" /><text x="60" y="82" textAnchor="middle" fontSize="8" fontWeight="800" fill={white} fontFamily="sans-serif">×7</text><path d="M30,60 Q34,52 38,58" fill="#A5D6A7" opacity="0.7" /></g>,
    footprint: <g opacity={op}><path d="M52,38 Q48,30 52,26 Q56,22 60,26 Q64,30 60,38 Z" fill={white} opacity="0.9" /><ellipse cx="56" cy="44" rx="12" ry="16" fill={white} opacity="0.85" /><text x="56" y="50" textAnchor="middle" fontSize="11" fontWeight="900" fill="#00897B" fontFamily="sans-serif">1st</text><circle cx="44" cy="34" r="3.5" fill={white} opacity="0.7" /><circle cx="66" cy="32" r="3" fill={white} opacity="0.7" /></g>,
    num10: <g opacity={op}><circle cx="60" cy="54" r="22" fill={white} opacity="0.2" /><text x="60" y="62" textAnchor="middle" fontSize="28" fontWeight="900" fill={white} fontFamily="sans-serif">10</text><path d="M40,38 L44,32 L48,38" fill="none" stroke={pale} strokeWidth="2" strokeLinecap="round" /><path d="M72,38 L76,32 L80,38" fill="none" stroke={pale} strokeWidth="2" strokeLinecap="round" /></g>,
    num30: <g opacity={op}><circle cx="60" cy="54" r="22" fill={white} opacity="0.2" /><text x="60" y="62" textAnchor="middle" fontSize="28" fontWeight="900" fill={white} fontFamily="sans-serif">30</text></g>,
    num100: <g opacity={op}><circle cx="60" cy="54" r="24" fill={white} opacity="0.2" /><text x="60" y="63" textAnchor="middle" fontSize="24" fontWeight="900" fill={white} fontFamily="sans-serif">100</text></g>,
    proteinFirst: <g opacity={op}><ellipse cx="60" cy="54" rx="22" ry="18" fill={white} opacity="0.9" /><ellipse cx="60" cy="54" rx="18" ry="14" fill={pale} /><text x="60" y="58" textAnchor="middle" fontSize="10" fontWeight="900" fill="#1565C0" fontFamily="sans-serif">P</text></g>,
    protein10: <g opacity={op}><ellipse cx="60" cy="52" rx="24" ry="18" fill={white} opacity="0.9" /><ellipse cx="60" cy="52" rx="20" ry="14" fill={pale} /><text x="60" y="57" textAnchor="middle" fontSize="16" fontWeight="900" fill="#0D47A1" fontFamily="sans-serif">10</text></g>,
    protein20: <g opacity={op}><ellipse cx="60" cy="52" rx="24" ry="18" fill={white} opacity="0.9" /><ellipse cx="60" cy="52" rx="20" ry="14" fill={pale} /><text x="60" y="57" textAnchor="middle" fontSize="16" fontWeight="900" fill="#0D47A1" fontFamily="sans-serif">20</text></g>,
    protein50: <g opacity={op}><ellipse cx="60" cy="52" rx="26" ry="20" fill={white} opacity="0.9" /><ellipse cx="60" cy="52" rx="22" ry="16" fill={pale} /><text x="60" y="57" textAnchor="middle" fontSize="18" fontWeight="900" fill="#1A237E" fontFamily="sans-serif">50</text></g>,
    protein100: <g opacity={op}><ellipse cx="60" cy="52" rx="28" ry="22" fill={white} opacity="0.9" /><ellipse cx="60" cy="52" rx="24" ry="18" fill={pale} /><text x="60" y="58" textAnchor="middle" fontSize="18" fontWeight="900" fill="#0D1B5E" fontFamily="sans-serif">100</text></g>,
    perfectStar: <g opacity={op}><polygon points="60,24 66,44 88,44 70,56 78,76 60,64 42,76 50,56 32,44 54,44" fill={white} opacity="0.95" /><polygon points="60,30 64,44 80,44 68,53 74,68 60,60 46,68 52,53 40,44 56,44" fill="#FFD600" /><circle cx="60" cy="48" r="5" fill="#FF6F00" opacity="0.7" /></g>,
    hatTrick: <g opacity={op}><polygon points="46,28 50,42 36,42" fill={white} opacity="0.8" /><polygon points="60,20 66,38 54,38" fill={white} opacity="0.95" /><polygon points="74,28 78,42 70,42" fill={white} opacity="0.8" /><polygon points="60,22 64,36 56,36" fill="#FFD600" /><polygon points="48,30 51,40 45,40" fill="#FFC107" /><polygon points="72,30 75,40 69,40" fill="#FFC107" /><text x="60" y="64" textAnchor="middle" fontSize="20" fontWeight="900" fill={white} fontFamily="sans-serif">3</text></g>,
    perfectWeek: <g opacity={op}><path d="M40,46 L48,32 L60,28 L72,32 L80,46 L76,48 L44,48 Z" fill={white} opacity="0.95" /><path d="M43,46 L50,34 L60,30 L70,34 L77,46 Z" fill="#FFD600" /><text x="60" y="68" textAnchor="middle" fontSize="20" fontWeight="900" fill={white} fontFamily="sans-serif">7</text></g>,
    perfectMonth: <g opacity={op}><path d="M36,46 L46,28 L60,22 L74,28 L84,46 L80,48 L40,48 Z" fill={white} opacity="0.95" /><path d="M39,46 L48,30 L60,24 L72,30 L81,46 Z" fill="#FFD600" /><text x="60" y="70" textAnchor="middle" fontSize="18" fontWeight="900" fill={white} fontFamily="sans-serif">30</text></g>,
    rainbow: <g opacity={op}><path d="M30,68 Q30,32 60,32 Q90,32 90,68" fill="none" stroke="#FF1744" strokeWidth="5" opacity="0.9" /><path d="M34,68 Q34,38 60,38 Q86,38 86,68" fill="none" stroke="#FF9100" strokeWidth="4" opacity="0.85" /><path d="M38,68 Q38,42 60,42 Q82,42 82,68" fill="none" stroke="#FFEA00" strokeWidth="4" opacity="0.85" /><path d="M42,68 Q42,46 60,46 Q78,46 78,68" fill="none" stroke="#00E676" strokeWidth="4" opacity="0.85" /><path d="M46,68 Q46,50 60,50 Q74,50 74,68" fill="none" stroke="#2979FF" strokeWidth="4" opacity="0.85" /><path d="M50,68 Q50,54 60,54 Q70,54 70,68" fill="none" stroke="#D500F9" strokeWidth="4" opacity="0.85" /></g>,
    book10: <g opacity={op}><rect x="40" y="34" width="36" height="44" rx="3" fill={white} opacity="0.9" /><rect x="42" y="34" width="4" height="44" fill={pale} opacity="0.6" /><text x="58" y="66" textAnchor="middle" fontSize="16" fontWeight="900" fill="#0288D1" fontFamily="sans-serif">10</text></g>,
    book25: <g opacity={op}><rect x="38" y="36" width="36" height="40" rx="3" fill={white} opacity="0.7" /><rect x="42" y="32" width="36" height="44" rx="3" fill={white} opacity="0.9" /><rect x="44" y="32" width="4" height="44" fill={pale} opacity="0.6" /><text x="62" y="62" textAnchor="middle" fontSize="16" fontWeight="900" fill="#0277BD" fontFamily="sans-serif">25</text></g>,
    book50: <g opacity={op}><rect x="34" y="38" width="36" height="40" rx="3" fill={white} opacity="0.5" /><rect x="38" y="34" width="36" height="42" rx="3" fill={white} opacity="0.7" /><rect x="42" y="30" width="36" height="44" rx="3" fill={white} opacity="0.9" /><rect x="44" y="30" width="4" height="44" fill={pale} opacity="0.6" /><text x="62" y="60" textAnchor="middle" fontSize="16" fontWeight="900" fill="#01579B" fontFamily="sans-serif">50</text></g>,
    book100: <g opacity={op}><rect x="30" y="40" width="36" height="40" rx="3" fill={white} opacity="0.4" /><rect x="34" y="36" width="36" height="42" rx="3" fill={white} opacity="0.55" /><rect x="38" y="32" width="36" height="44" rx="3" fill={white} opacity="0.7" /><rect x="42" y="28" width="36" height="46" rx="3" fill={white} opacity="0.9" /><rect x="44" y="28" width="4" height="46" fill={pale} opacity="0.6" /><text x="62" y="58" textAnchor="middle" fontSize="14" fontWeight="900" fill="#004C8C" fontFamily="sans-serif">100</text></g>,
    book200: <g opacity={op}><rect x="26" y="42" width="34" height="38" rx="3" fill={white} opacity="0.3" /><rect x="30" y="38" width="34" height="40" rx="3" fill={white} opacity="0.45" /><rect x="34" y="34" width="36" height="42" rx="3" fill={white} opacity="0.6" /><rect x="38" y="30" width="36" height="44" rx="3" fill={white} opacity="0.75" /><rect x="42" y="26" width="36" height="48" rx="3" fill={white} opacity="0.9" /><rect x="44" y="26" width="4" height="48" fill={pale} opacity="0.6" /><text x="62" y="58" textAnchor="middle" fontSize="13" fontWeight="900" fill="#002F6C" fontFamily="sans-serif">200</text></g>,
    chef: <g opacity={op}><ellipse cx="60" cy="70" rx="14" ry="10" fill={white} opacity="0.9" /><circle cx="60" cy="56" r="12" fill={white} opacity="0.9" /><circle cx="54" cy="58" r="2" fill="#333" opacity={locked ? 0.3 : 0.7} /><circle cx="66" cy="58" r="2" fill="#333" opacity={locked ? 0.3 : 0.7} /><path d="M56,64 Q60,67 64,64" fill="none" stroke="#333" strokeWidth="1.5" opacity={locked ? 0.3 : 0.6} /><path d="M48,52 Q48,28 60,28 Q72,28 72,52" fill={white} opacity="0.95" /><circle cx="52" cy="34" r="8" fill={white} /><circle cx="68" cy="34" r="8" fill={white} /><circle cx="60" cy="30" r="9" fill={white} /></g>,
  };

  return icons[icon] || null;
};

export default function AchievementBadges({ earnedBadgeIds }: { earnedBadgeIds: Set<string> }) {
  const earnedCount = BADGES.filter(b => earnedBadgeIds.has(b.stringId)).length;
  const categories = [...new Set(BADGES.map(b => b.category))];

  return (
    <div style={{ padding: "20px" }}>
      {categories.map(cat => {
        const catBadges = BADGES.filter(b => b.category === cat);
        return (
          <div key={cat} style={{ marginBottom: 24 }}>
            <h3 style={{ fontSize: 12, fontWeight: 600, color: "#666", textTransform: "uppercase", marginBottom: 12, letterSpacing: 1 }}>{cat}</h3>
            <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(110px, 1fr))", gap: 12 }}>
              {catBadges.map(badge => {
                const earned = earnedBadgeIds.has(badge.stringId);
                return (
                  <div key={badge.id} style={{ display: "flex", flexDirection: "column", alignItems: "center", padding: "12px 8px", borderRadius: 12, background: earned ? "rgba(255,255,255,0.05)" : "rgba(255,255,255,0.02)", border: `1px solid ${earned ? "rgba(255,255,255,0.1)" : "rgba(255,255,255,0.05)"}` }}>
                    <div style={{ filter: !earned ? "saturate(0) brightness(0.6)" : "none", transition: "filter 0.3s" }}>
                      <BadgeShape shape={badge.shape} colors={badge.colors} locked={!earned} size={80}>
                        <BadgeIcon icon={badge.icon} locked={!earned} accent={badge.accent} />
                      </BadgeShape>
                    </div>
                    <span style={{ color: earned ? "#eee" : "#888", fontSize: 10, fontWeight: 700, marginTop: 8, textAlign: "center", lineHeight: 1.2 }}>{badge.name}</span>
                    <span style={{ color: earned ? "#aaa" : "#666", fontSize: 8, fontWeight: 500, marginTop: 2, textAlign: "center", lineHeight: 1.2 }}>{badge.desc}</span>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>
  );
}
