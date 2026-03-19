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

export const BadgeShape = ({ shape, colors, children, locked, size = 120, title }: any) => {
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
      {title && <title>{title}</title>}
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

  const icons = {
    // ---- STREAK LOGGERS: Calendar with flame ----
    calendar7: (
      <g opacity={op}>
        <rect x="38" y="32" width="44" height="40" rx="5" fill={white} opacity="0.9" />
        <rect x="38" y="32" width="44" height="12" rx="5" fill={pale} />
        <line x1="48" y1="28" x2="48" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <line x1="72" y1="28" x2="72" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <text x="60" y="64" textAnchor="middle" fontSize="16" fontWeight="900" fill="#E65100" fontFamily="sans-serif">7</text>
        <path d="M78,40 Q82,34 80,28 Q84,32 82,38 Q86,32 84,26 Q90,34 82,44" fill="#FF6B35" opacity="0.8" />
      </g>
    ),
    calendar14: (
      <g opacity={op}>
        <rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" />
        <rect x="36" y="32" width="48" height="12" rx="5" fill={pale} />
        <line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#C62828" fontFamily="sans-serif">14</text>
        <path d="M80,38 Q85,30 82,24 Q88,30 84,38 Q90,28 86,22 Q94,32 84,44" fill="#FF6B35" opacity="0.9" />
      </g>
    ),
    calendar30: (
      <g opacity={op}>
        <rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" />
        <rect x="36" y="32" width="48" height="12" rx="5" fill={pale} />
        <line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#880E4F" fontFamily="sans-serif">30</text>
        <path d="M80,36 Q86,26 82,18 Q90,28 85,38 Q92,24 88,16 Q98,30 86,44" fill="#FF5252" opacity="0.9" />
        <path d="M34,40 Q28,32 32,24 Q26,30 30,38" fill="#FF5252" opacity="0.6" />
      </g>
    ),
    calendar90: (
      <g opacity={op}>
        <rect x="36" y="32" width="48" height="40" rx="5" fill={white} opacity="0.9" />
        <rect x="36" y="32" width="48" height="12" rx="5" fill={pale} />
        <line x1="46" y1="28" x2="46" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <line x1="74" y1="28" x2="74" y2="36" stroke={white} strokeWidth="2.5" strokeLinecap="round" />
        <text x="60" y="64" textAnchor="middle" fontSize="14" fontWeight="900" fill="#4A0020" fontFamily="sans-serif">90</text>
        <path d="M80,34 Q88,22 84,14 Q92,24 86,36 Q94,20 90,12 Q100,28 88,44" fill="#FF1744" opacity="0.9" />
        <path d="M32,38 Q26,28 30,20 Q24,28 28,36 Q22,24 26,16 Q18,30 28,42" fill="#FF1744" opacity="0.7" />
        {[...Array(6)].map((_, i) => <circle key={i} cx={35 + i * 10} cy={76} r="1.5" fill="#C2185B" opacity="0.6" />)}
      </g>
    ),

    // ---- PROTEIN STREAKS: Flexing arm / dumbbell ----
    muscle7: (
      <g opacity={op}>
        <path d="M42,70 Q42,50 50,42 Q56,36 60,40 Q66,36 70,44 Q78,54 70,62" fill={white} opacity="0.9" />
        <path d="M44,68 Q44,52 51,44 Q56,39 60,42 Q65,38 69,46 Q76,54 69,61" fill={pale} />
        <text x="58" y="58" textAnchor="middle" fontSize="14" fontWeight="900" fill="#7B1FA2" fontFamily="sans-serif">7</text>
        <circle cx="48" cy="38" r="3" fill={white} opacity="0.6" />
        <circle cx="72" cy="36" r="2" fill={white} opacity="0.4" />
        <rect x="38" y="70" width="44" height="6" rx="3" fill={white} opacity="0.7" />
        <rect x="34" y="67" width="8" height="12" rx="2" fill={white} opacity="0.8" />
        <rect x="78" y="67" width="8" height="12" rx="2" fill={white} opacity="0.8" />
      </g>
    ),
    muscle14: (
      <g opacity={op}>
        <path d="M42,70 Q42,50 50,42 Q56,36 60,40 Q66,36 70,44 Q78,54 70,62" fill={white} opacity="0.9" />
        <path d="M44,68 Q44,52 51,44 Q56,39 60,42 Q65,38 69,46 Q76,54 69,61" fill={pale} />
        <text x="58" y="58" textAnchor="middle" fontSize="12" fontWeight="900" fill="#6A1B9A" fontFamily="sans-serif">14</text>
        <rect x="38" y="70" width="44" height="6" rx="3" fill={white} opacity="0.7" />
        <rect x="32" y="67" width="10" height="12" rx="2" fill={white} opacity="0.8" />
        <rect x="78" y="67" width="10" height="12" rx="2" fill={white} opacity="0.8" />
        <circle cx="46" cy="36" r="4" fill={white} opacity="0.5" />
        <circle cx="74" cy="34" r="3" fill={white} opacity="0.4" />
      </g>
    ),
    muscle30: (
      <g opacity={op}>
        <path d="M40,70 Q40,48 50,40 Q56,34 60,38 Q66,34 72,42 Q80,52 72,62" fill={white} opacity="0.9" />
        <path d="M42,68 Q42,50 51,42 Q56,37 60,40 Q65,36 71,44 Q78,52 71,61" fill={pale} />
        <text x="58" y="58" textAnchor="middle" fontSize="12" fontWeight="900" fill="#4A148C" fontFamily="sans-serif">30</text>
        <rect x="36" y="70" width="48" height="7" rx="3.5" fill={white} opacity="0.7" />
        <rect x="30" y="66" width="12" height="14" rx="3" fill={white} opacity="0.8" />
        <rect x="78" y="66" width="12" height="14" rx="3" fill={white} opacity="0.8" />
        {[42, 50, 58, 66, 74].map((x, i) => <circle key={i} cx={x} cy={34} r="2" fill={white} opacity="0.5" />)}
      </g>
    ),
    muscle90: (
      <g opacity={op}>
        <path d="M38,70 Q38,46 48,38 Q56,30 60,36 Q66,30 74,40 Q84,52 74,64" fill={white} opacity="0.9" />
        <path d="M40,68 Q40,48 49,40 Q56,33 60,38 Q65,33 73,42 Q82,52 73,63" fill={pale} />
        <text x="58" y="56" textAnchor="middle" fontSize="12" fontWeight="900" fill="#311B92" fontFamily="sans-serif">90</text>
        <rect x="34" y="70" width="52" height="8" rx="4" fill={white} opacity="0.7" />
        <rect x="28" y="65" width="14" height="16" rx="3" fill={white} opacity="0.85" />
        <rect x="78" y="65" width="14" height="16" rx="3" fill={white} opacity="0.85" />
        <path d="M44,32 L48,24 L52,32" fill="none" stroke="#FFD600" strokeWidth="2" strokeLinecap="round" />
        <path d="M68,32 L72,24 L76,32" fill="none" stroke="#FFD600" strokeWidth="2" strokeLinecap="round" />
        <circle cx="60" cy="26" r="3" fill="#FFD600" opacity="0.8" />
      </g>
    ),

    // ---- GREEN WEEK ----
    greenweek: (
      <g opacity={op}>
        <circle cx="50" cy="50" r="14" fill="#81C784" />
        <path d="M50,36 Q58,42 50,50 Q42,42 50,36" fill="#43A047" />
        <line x1="50" y1="50" x2="50" y2="64" stroke="#388E3C" strokeWidth="2" />
        <circle cx="72" cy="54" r="10" fill="#FF7043" />
        <circle cx="72" cy="52" r="3" fill="#D84315" opacity="0.3" />
        <path d="M72,44 Q75,42 74,46" fill="#43A047" strokeWidth="1" stroke="#43A047" />
        <text x="60" y="82" textAnchor="middle" fontSize="8" fontWeight="800" fill={white} fontFamily="sans-serif">×7</text>
        <path d="M30,60 Q34,52 38,58" fill="#A5D6A7" opacity="0.7" />
      </g>
    ),

    // ---- MILESTONE LOGGERS: Plate → Seedling → Tree → Mountain ----
    // First Step: A plate with fork & knife, one piece of food, sparkle
    footprint: (
      <g opacity={op}>
        {/* plate */}
        <ellipse cx="60" cy="58" rx="26" ry="12" fill={white} opacity="0.15" />
        <ellipse cx="60" cy="56" rx="24" ry="18" fill={white} opacity="0.95" />
        <ellipse cx="60" cy="56" rx="18" ry="13" fill={pale} opacity="0.4" />
        {/* single food item on plate — little piece of sushi/food */}
        <ellipse cx="60" cy="54" rx="7" ry="5" fill="#FF8A65" opacity="0.85" />
        <ellipse cx="60" cy="52" rx="5" ry="3" fill="#FFAB91" opacity="0.6" />
        <ellipse cx="60" cy="50" rx="7" ry="2" fill="#66BB6A" opacity="0.7" />
        {/* fork left */}
        <line x1="36" y1="36" x2="42" y2="68" stroke={white} strokeWidth="2.5" strokeLinecap="round" opacity="0.8" />
        <line x1="34" y1="36" x2="35" y2="44" stroke={white} strokeWidth="1.5" strokeLinecap="round" opacity="0.7" />
        <line x1="38" y1="36" x2="39" y2="44" stroke={white} strokeWidth="1.5" strokeLinecap="round" opacity="0.7" />
        {/* knife right */}
        <line x1="84" y1="36" x2="78" y2="68" stroke={white} strokeWidth="2.5" strokeLinecap="round" opacity="0.8" />
        <path d="M84,36 Q88,40 86,48" fill="none" stroke={white} strokeWidth="1.5" strokeLinecap="round" opacity="0.6" />
        {/* sparkle — first time! */}
        <path d="M76,30 L78,24 L80,30 L76,27 L80,27" fill="#FFD600" opacity="0.9" />
        <circle cx="44" cy="30" r="2" fill="#FFD600" opacity="0.6" />
      </g>
    ),
    // 10 Days Logged: Seedling sprouting from soil with "10" marker
    num10: (
      <g opacity={op}>
        {/* soil mound */}
        <ellipse cx="60" cy="74" rx="28" ry="8" fill="#8D6E63" opacity={locked ? 0.3 : 0.5} />
        <ellipse cx="60" cy="72" rx="24" ry="6" fill="#A1887F" opacity={locked ? 0.2 : 0.35} />
        {/* stem */}
        <path d="M60,72 Q58,58 60,46" fill="none" stroke="#66BB6A" strokeWidth="3" strokeLinecap="round" opacity="0.9" />
        {/* two leaves */}
        <path d="M60,56 Q50,48 46,52 Q50,56 60,56" fill="#66BB6A" opacity="0.85" />
        <path d="M60,50 Q70,42 74,46 Q70,50 60,50" fill="#81C784" opacity="0.8" />
        {/* leaf veins */}
        <line x1="60" y1="56" x2="50" y2="52" stroke="#43A047" strokeWidth="0.8" opacity="0.5" />
        <line x1="60" y1="50" x2="70" y2="46" stroke="#43A047" strokeWidth="0.8" opacity="0.5" />
        {/* small bud at top */}
        <circle cx="60" cy="44" r="3" fill="#A5D6A7" opacity="0.8" />
        {/* garden marker sign */}
        <rect x="76" y="48" width="16" height="12" rx="2" fill={white} opacity="0.9" />
        <line x1="84" y1="60" x2="84" y2="74" stroke={white} strokeWidth="2" strokeLinecap="round" opacity="0.7" />
        <text x="84" y="57" textAnchor="middle" fontSize="8" fontWeight="900" fill="#00897B" fontFamily="sans-serif">10</text>
      </g>
    ),
    // 30 Days Logged: Small tree with several branches and leaves
    num30: (
      <g opacity={op}>
        {/* trunk */}
        <rect x="56" y="56" width="8" height="24" rx="2" fill="#8D6E63" opacity={locked ? 0.3 : 0.65} />
        <rect x="58" y="56" width="3" height="24" rx="1" fill="#A1887F" opacity={locked ? 0.15 : 0.3} />
        {/* soil */}
        <ellipse cx="60" cy="80" rx="22" ry="5" fill="#8D6E63" opacity={locked ? 0.2 : 0.35} />
        {/* canopy — cluster of circles */}
        <circle cx="48" cy="46" r="12" fill="#66BB6A" opacity="0.75" />
        <circle cx="72" cy="46" r="12" fill="#81C784" opacity="0.7" />
        <circle cx="60" cy="40" r="14" fill="#4CAF50" opacity="0.8" />
        <circle cx="54" cy="36" r="10" fill="#66BB6A" opacity="0.65" />
        <circle cx="68" cy="38" r="10" fill="#43A047" opacity="0.6" />
        {/* highlights on canopy */}
        <circle cx="56" cy="34" r="4" fill={white} opacity="0.15" />
        <circle cx="66" cy="40" r="3" fill={white} opacity="0.1" />
        {/* small fruit */}
        <circle cx="46" cy="50" r="3" fill="#FF7043" opacity="0.7" />
        <circle cx="70" cy="42" r="2.5" fill="#FFCA28" opacity="0.65" />
        {/* "30" floating */}
        <circle cx="84" cy="28" r="9" fill={white} opacity="0.85" />
        <text x="84" y="32" textAnchor="middle" fontSize="10" fontWeight="900" fill="#00796B" fontFamily="sans-serif">30</text>
      </g>
    ),
    // 100 Days Logged: Mountain with flag planted at summit
    num100: (
      <g opacity={op}>
        {/* back mountain */}
        <polygon points="20,82 50,32 80,82" fill={white} opacity="0.2" />
        {/* main mountain */}
        <polygon points="30,82 64,26 98,82" fill={white} opacity="0.9" />
        <polygon points="38,82 64,32 90,82" fill={pale} opacity="0.4" />
        {/* snow cap */}
        <polygon points="64,26 56,42 72,42" fill={white} opacity="0.95" />
        <path d="M56,42 Q60,46 64,42 Q68,46 72,42" fill={white} opacity="0.8" />
        {/* flag pole */}
        <line x1="64" y1="26" x2="64" y2="14" stroke={white} strokeWidth="2" strokeLinecap="round" />
        {/* flag */}
        <path d="M64,14 L80,18 L64,22" fill="#FF5252" opacity="0.9" />
        {/* "100" on flag */}
        <text x="72" y="20" textAnchor="middle" fontSize="5" fontWeight="900" fill={white} fontFamily="sans-serif">100</text>
        {/* mountain detail lines */}
        <line x1="50" y1="58" x2="58" y2="50" stroke={white} strokeWidth="1" opacity="0.2" />
        <line x1="70" y1="58" x2="66" y2="52" stroke={white} strokeWidth="1" opacity="0.2" />
        {/* sparkles at summit */}
        <circle cx="56" cy="18" r="2" fill="#FFD600" opacity="0.8" />
        <circle cx="78" cy="12" r="1.5" fill="#FFD600" opacity="0.6" />
        <path d="M48,12 L50,8 L52,12 L48,10 L52,10" fill="#FFD600" opacity="0.7" />
      </g>
    ),

    // ---- PROTEIN MILESTONES: Chicken drumstick → Shaker → Egg → Steak → Trophy ----
    // Protein Hit: Chicken drumstick with a checkmark spark
    proteinFirst: (
      <g opacity={op}>
        {/* drumstick bone */}
        <ellipse cx="68" cy="70" rx="5" ry="4" fill={white} opacity="0.9" />
        <ellipse cx="74" cy="74" rx="5" ry="4" fill={white} opacity="0.9" />
        <rect x="62" y="62" width="8" height="14" rx="3" fill={white} opacity="0.9" transform="rotate(20,66,68)" />
        {/* drumstick meat */}
        <ellipse cx="52" cy="50" rx="18" ry="15" fill={white} opacity="0.95" transform="rotate(-15,52,50)" />
        <ellipse cx="52" cy="50" rx="14" ry="12" fill={pale} transform="rotate(-15,52,50)" />
        <ellipse cx="48" cy="46" rx="5" ry="4" fill={white} opacity="0.3" />
        {/* checkmark spark */}
        <circle cx="76" cy="32" r="10" fill="#4CAF50" opacity="0.9" />
        <path d="M71,32 L75,36 L82,28" fill="none" stroke={white} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round" />
      </g>
    ),
    // 10 Protein Days: Protein shaker bottle
    protein10: (
      <g opacity={op}>
        {/* bottle body */}
        <rect x="44" y="42" width="32" height="38" rx="6" fill={white} opacity="0.95" />
        <rect x="47" y="50" width="26" height="26" rx="3" fill={pale} />
        {/* cap */}
        <rect x="46" y="34" width="28" height="10" rx="4" fill={white} />
        <rect x="52" y="28" width="16" height="8" rx="3" fill={pale} opacity="0.8" />
        {/* lid nozzle */}
        <rect x="56" y="24" width="8" height="6" rx="2" fill={white} opacity="0.9" />
        {/* shake lines */}
        <path d="M36,38 Q32,44 36,50" fill="none" stroke={white} strokeWidth="2" strokeLinecap="round" opacity="0.6" />
        <path d="M84,38 Q88,44 84,50" fill="none" stroke={white} strokeWidth="2" strokeLinecap="round" opacity="0.6" />
        {/* liquid inside */}
        <rect x="47" y="62" width="26" height="14" rx="3" fill={white} opacity="0.3" />
        {/* number */}
        <text x="60" y="61" textAnchor="middle" fontSize="14" fontWeight="900" fill="#0D47A1" fontFamily="sans-serif">10</text>
      </g>
    ),
    // 20 Protein Days: Egg with flexing arms
    protein20: (
      <g opacity={op}>
        {/* egg body */}
        <ellipse cx="60" cy="56" rx="18" ry="22" fill={white} opacity="0.95" />
        <ellipse cx="60" cy="54" rx="14" ry="18" fill={pale} opacity="0.4" />
        <ellipse cx="56" cy="48" rx="6" ry="8" fill={white} opacity="0.25" />
        {/* cute face */}
        <circle cx="54" cy="54" r="2" fill="#0D47A1" opacity="0.7" />
        <circle cx="66" cy="54" r="2" fill="#0D47A1" opacity="0.7" />
        <path d="M56,60 Q60,63 64,60" fill="none" stroke="#0D47A1" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
        {/* left flexing arm */}
        <path d="M42,52 Q34,48 32,40 Q30,36 34,36 Q38,36 36,42 Q38,46 42,48" fill={white} opacity="0.9" />
        <circle cx="33" cy="37" r="4" fill={pale} opacity="0.7" />
        {/* right flexing arm */}
        <path d="M78,52 Q86,48 88,40 Q90,36 86,36 Q82,36 84,42 Q82,46 78,48" fill={white} opacity="0.9" />
        <circle cx="87" cy="37" r="4" fill={pale} opacity="0.7" />
        {/* number */}
        <text x="60" y="80" textAnchor="middle" fontSize="11" fontWeight="900" fill={white} fontFamily="sans-serif">×20</text>
      </g>
    ),
    // 50 Protein Days: Steak with medal ribbon
    protein50: (
      <g opacity={op}>
        {/* steak body */}
        <ellipse cx="58" cy="54" rx="24" ry="18" fill={white} opacity="0.95" />
        <ellipse cx="58" cy="54" rx="20" ry="14" fill="#E57373" opacity={locked ? 0.3 : 0.6} />
        {/* fat marbling */}
        <path d="M44,50 Q50,46 56,50 Q62,54 68,50" fill="none" stroke={white} strokeWidth="2" opacity="0.5" />
        <path d="M48,58 Q54,54 60,58" fill="none" stroke={white} strokeWidth="1.5" opacity="0.4" />
        {/* bone */}
        <ellipse cx="78" cy="48" rx="6" ry="4" fill={white} opacity="0.9" />
        <rect x="72" y="46" width="6" height="10" rx="3" fill={white} opacity="0.8" />
        {/* medal ribbon */}
        <path d="M34,28 L40,40 L46,28" fill="#FFD600" opacity="0.8" />
        <circle cx="40" cy="40" r="8" fill="#FFD600" />
        <text x="40" y="44" textAnchor="middle" fontSize="9" fontWeight="900" fill="#1A237E" fontFamily="sans-serif">50</text>
      </g>
    ),
    // 100 Protein Days: Trophy cup overflowing with protein food
    protein100: (
      <g opacity={op}>
        {/* trophy cup */}
        <path d="M44,38 L46,68 Q46,76 60,76 Q74,76 74,68 L76,38 Z" fill={white} opacity="0.95" />
        <path d="M48,42 L50,66 Q50,72 60,72 Q70,72 70,66 L72,42 Z" fill="#FFD600" opacity={locked ? 0.2 : 0.6} />
        {/* handles */}
        <path d="M44,42 Q32,42 32,52 Q32,60 44,58" fill="none" stroke={white} strokeWidth="3" strokeLinecap="round" opacity="0.8" />
        <path d="M76,42 Q88,42 88,52 Q88,60 76,58" fill="none" stroke={white} strokeWidth="3" strokeLinecap="round" opacity="0.8" />
        {/* base */}
        <rect x="54" y="76" width="12" height="4" rx="1" fill={white} opacity="0.8" />
        <rect x="48" y="80" width="24" height="4" rx="2" fill={white} opacity="0.9" />
        {/* food items peeking out of trophy */}
        <circle cx="54" cy="36" r="5" fill="#FF7043" opacity="0.8" /> {/* drumstick top */}
        <ellipse cx="66" cy="34" rx="5" ry="4" fill={white} opacity="0.8" /> {/* egg */}
        <circle cx="60" cy="30" r="4" fill="#EF5350" opacity="0.7" /> {/* meat */}
        {/* 100 label */}
        <text x="60" y="60" textAnchor="middle" fontSize="14" fontWeight="900" fill="#0D1B5E" fontFamily="sans-serif">100</text>
        {/* sparkles */}
        <path d="M34,30 L36,26 L38,30 L34,28 L38,28" fill="#FFD600" opacity="0.7" />
        <path d="M82,30 L84,26 L86,30 L82,28 L86,28" fill="#FFD600" opacity="0.7" />
      </g>
    ),

    // ---- PERFECT DAYS: Stars and crown ----
    perfectStar: (
      <g opacity={op}>
        <polygon points="60,24 66,44 88,44 70,56 78,76 60,64 42,76 50,56 32,44 54,44" fill={white} opacity="0.95" />
        <polygon points="60,30 64,44 80,44 68,53 74,68 60,60 46,68 52,53 40,44 56,44" fill="#FFD600" />
        <circle cx="60" cy="48" r="5" fill="#FF6F00" opacity="0.7" />
        <text x="60" y="51" textAnchor="middle" fontSize="6" fontWeight="900" fill={white} fontFamily="sans-serif">✓</text>
      </g>
    ),
    // Hat Trick: Magician's top hat with 3 stars popping out
    hatTrick: (
      <g opacity={op}>
        {/* hat brim */}
        <ellipse cx="60" cy="64" rx="28" ry="6" fill={white} opacity="0.95" />
        {/* hat body */}
        <rect x="42" y="40" width="36" height="26" rx="4" fill={white} opacity="0.9" />
        <rect x="44" y="42" width="32" height="22" rx="3" fill={pale} opacity="0.3" />
        {/* hat band */}
        <rect x="42" y="58" width="36" height="5" rx="1" fill="#FFD600" opacity={locked ? 0.3 : 0.7} />
        {/* 3 stars popping out */}
        <polygon points="46,34 48,28 50,34 44,30 52,30" fill="#FFD600" opacity="0.9" />
        <polygon points="60,26 63,18 66,26 58,22 68,22" fill="#FFD600" opacity="0.95" />
        <polygon points="74,34 76,28 78,34 72,30 80,30" fill="#FFD600" opacity="0.9" />
        {/* sparkle trails */}
        <circle cx="42" cy="26" r="2" fill="#FFF176" opacity="0.6" />
        <circle cx="60" cy="14" r="2.5" fill="#FFF176" opacity="0.7" />
        <circle cx="80" cy="24" r="1.5" fill="#FFF176" opacity="0.5" />
        {/* "×3" label */}
        <text x="60" y="78" textAnchor="middle" fontSize="9" fontWeight="900" fill={white} fontFamily="sans-serif">×3 PERFECT</text>
      </g>
    ),
    // Perfect Week: Bullseye target with arrow dead center
    perfectWeek: (
      <g opacity={op}>
        {/* outer ring */}
        <circle cx="58" cy="52" r="26" fill={white} opacity="0.9" />
        <circle cx="58" cy="52" r="22" fill="#FF8A65" opacity={locked ? 0.2 : 0.5} />
        <circle cx="58" cy="52" r="16" fill={white} opacity="0.85" />
        <circle cx="58" cy="52" r="12" fill="#FF5252" opacity={locked ? 0.2 : 0.5} />
        <circle cx="58" cy="52" r="6" fill={white} opacity="0.9" />
        <circle cx="58" cy="52" r="3" fill="#FFD600" opacity="0.9" />
        {/* arrow */}
        <line x1="58" y1="52" x2="86" y2="28" stroke={white} strokeWidth="2.5" strokeLinecap="round" opacity="0.9" />
        {/* arrow tip */}
        <polygon points="86,28 80,30 84,34" fill={white} opacity="0.9" />
        {/* arrow fletching */}
        <path d="M58,52 L54,56 L56,52 L52,54" fill="none" stroke="#FFD600" strokeWidth="1.5" opacity="0.7" />
        {/* "7" */}
        <circle cx="86" cy="72" r="9" fill={white} opacity="0.85" />
        <text x="86" y="76" textAnchor="middle" fontSize="12" fontWeight="900" fill="#E65100" fontFamily="sans-serif">7</text>
      </g>
    ),
    // Perfect Month: Radiant gem / diamond
    perfectMonth: (
      <g opacity={op}>
        {/* gem facets — top */}
        <polygon points="60,22 40,42 80,42" fill={white} opacity="0.95" />
        <polygon points="60,22 40,42 50,42" fill="#FFF176" opacity={locked ? 0.15 : 0.4} />
        <polygon points="60,22 70,42 80,42" fill="#FFE082" opacity={locked ? 0.1 : 0.3} />
        {/* gem facets — bottom */}
        <polygon points="40,42 80,42 60,78" fill={white} opacity="0.9" />
        <polygon points="40,42 60,42 50,78" fill="#FFF9C4" opacity={locked ? 0.1 : 0.25} />
        <polygon points="60,42 80,42 70,78" fill="#FFE082" opacity={locked ? 0.08 : 0.2} />
        <polygon points="50,78 70,78 60,78" fill="none" />
        {/* center line */}
        <line x1="60" y1="22" x2="60" y2="42" stroke={white} strokeWidth="1" opacity="0.3" />
        <line x1="60" y1="42" x2="50" y2="78" stroke={white} strokeWidth="1" opacity="0.2" />
        <line x1="60" y1="42" x2="70" y2="78" stroke={white} strokeWidth="1" opacity="0.2" />
        {/* facet edges */}
        <line x1="40" y1="42" x2="80" y2="42" stroke={white} strokeWidth="1.5" opacity="0.4" />
        {/* radiant lines */}
        <line x1="60" y1="14" x2="60" y2="8" stroke="#FFD600" strokeWidth="2" strokeLinecap="round" opacity="0.7" />
        <line x1="36" y1="28" x2="30" y2="24" stroke="#FFD600" strokeWidth="2" strokeLinecap="round" opacity="0.6" />
        <line x1="84" y1="28" x2="90" y2="24" stroke="#FFD600" strokeWidth="2" strokeLinecap="round" opacity="0.6" />
        <line x1="28" y1="48" x2="22" y2="48" stroke="#FFD600" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
        <line x1="92" y1="48" x2="98" y2="48" stroke="#FFD600" strokeWidth="1.5" strokeLinecap="round" opacity="0.5" />
        {/* sparkles */}
        <circle cx="34" cy="18" r="2" fill="#FFD600" opacity="0.5" />
        <circle cx="88" cy="16" r="2.5" fill="#FFD600" opacity="0.6" />
        {/* "30" inside gem */}
        <text x="60" y="56" textAnchor="middle" fontSize="14" fontWeight="900" fill="#BF360C" fontFamily="sans-serif" opacity="0.7">30</text>
      </g>
    ),

    // ---- EAT THE RAINBOW ----
    rainbow: (
      <g opacity={op}>
        <path d="M30,68 Q30,32 60,32 Q90,32 90,68" fill="none" stroke="#FF1744" strokeWidth="5" opacity="0.9" />
        <path d="M34,68 Q34,38 60,38 Q86,38 86,68" fill="none" stroke="#FF9100" strokeWidth="4" opacity="0.85" />
        <path d="M38,68 Q38,42 60,42 Q82,42 82,68" fill="none" stroke="#FFEA00" strokeWidth="4" opacity="0.85" />
        <path d="M42,68 Q42,46 60,46 Q78,46 78,68" fill="none" stroke="#00E676" strokeWidth="4" opacity="0.85" />
        <path d="M46,68 Q46,50 60,50 Q74,50 74,68" fill="none" stroke="#2979FF" strokeWidth="4" opacity="0.85" />
        <path d="M50,68 Q50,54 60,54 Q70,54 70,68" fill="none" stroke="#D500F9" strokeWidth="4" opacity="0.85" />
        <circle cx="42" cy="76" r="5" fill="#FF7043" />
        <circle cx="42" cy="75" r="2" fill="#BF360C" opacity="0.3" />
        <path d="M42,70 Q44,68 43,72" fill="#43A047" />
        <path d="M72,72 Q76,68 72,76 Q68,68 72,72" fill="#66BB6A" />
        <line x1="72" y1="76" x2="72" y2="82" stroke="#388E3C" strokeWidth="1.5" />
      </g>
    ),

    // ---- FOOD DATABASE: Basket → Fridge → Magnifier → Nerd → Encyclopaedia ----
    // Food Collector (10): Shopping basket with food peeking out
    book10: (
      <g opacity={op}>
        {/* basket body */}
        <path d="M34,52 L40,78 Q42,82 60,82 Q78,82 80,78 L86,52 Z" fill={white} opacity="0.95" />
        <path d="M38,56 L42,76 Q44,78 60,78 Q76,78 78,76 L82,56 Z" fill={pale} opacity="0.5" />
        {/* basket handle */}
        <path d="M42,52 Q42,34 60,34 Q78,34 78,52" fill="none" stroke={white} strokeWidth="3.5" strokeLinecap="round" />
        {/* grid pattern */}
        <line x1="50" y1="52" x2="48" y2="78" stroke={white} strokeWidth="1.5" opacity="0.3" />
        <line x1="70" y1="52" x2="72" y2="78" stroke={white} strokeWidth="1.5" opacity="0.3" />
        <line x1="36" y1="64" x2="84" y2="64" stroke={white} strokeWidth="1.5" opacity="0.3" />
        {/* apple peeking out */}
        <circle cx="52" cy="48" r="7" fill="#FF5252" opacity="0.85" />
        <path d="M52,42 Q54,38 56,40" fill="none" stroke="#4CAF50" strokeWidth="1.5" strokeLinecap="round" />
        {/* carrot peeking out */}
        <path d="M68,50 L72,38 L74,50" fill="#FF9800" opacity="0.85" />
        <path d="M72,38 Q74,34 76,36" fill="#4CAF50" opacity="0.7" />
        {/* number badge */}
        <circle cx="82" cy="40" r="8" fill="#FFD600" opacity="0.85" />
        <text x="82" y="44" textAnchor="middle" fontSize="9" fontWeight="900" fill="#0277BD" fontFamily="sans-serif">10</text>
      </g>
    ),
    // Food Enthusiast (25): Open fridge with food visible
    book25: (
      <g opacity={op}>
        {/* fridge body */}
        <rect x="38" y="26" width="44" height="60" rx="5" fill={white} opacity="0.95" />
        <rect x="42" y="30" width="36" height="24" rx="3" fill={pale} opacity="0.5" />
        <rect x="42" y="58" width="36" height="24" rx="3" fill={pale} opacity="0.4" />
        {/* divider */}
        <line x1="42" y1="56" x2="78" y2="56" stroke={white} strokeWidth="2" opacity="0.5" />
        {/* handle */}
        <rect x="74" y="40" width="3" height="10" rx="1.5" fill={white} opacity="0.6" />
        <rect x="74" y="62" width="3" height="10" rx="1.5" fill={white} opacity="0.6" />
        {/* food in top: milk carton */}
        <rect x="46" y="34" width="8" height="14" rx="1" fill={white} opacity="0.8" />
        <rect x="46" y="34" width="8" height="6" rx="1" fill="#42A5F5" opacity="0.5" />
        {/* food in top: bottle */}
        <rect x="58" y="38" width="6" height="12" rx="2" fill="#66BB6A" opacity="0.6" />
        <rect x="59" y="34" width="4" height="5" rx="1" fill="#66BB6A" opacity="0.5" />
        {/* food in top: fruit */}
        <circle cx="70" cy="44" r="5" fill="#FF7043" opacity="0.7" />
        {/* food in bottom */}
        <ellipse cx="54" cy="68" rx="6" ry="4" fill="#FFCA28" opacity="0.5" />
        <circle cx="66" cy="70" r="5" fill="#EF5350" opacity="0.5" />
        {/* sparkle */}
        <text x="86" y="30" textAnchor="middle" fontSize="10" fill="#FFD600" opacity="0.7" fontFamily="sans-serif">✦</text>
      </g>
    ),
    // Food Expert (50): Magnifying glass over food items
    book50: (
      <g opacity={op}>
        {/* food items scattered */}
        <circle cx="52" cy="48" r="6" fill="#FF7043" opacity="0.6" /> {/* tomato */}
        <circle cx="66" cy="44" r="5" fill="#66BB6A" opacity="0.5" /> {/* pea */}
        <ellipse cx="46" cy="58" rx="7" ry="4" fill="#FFCA28" opacity="0.5" /> {/* banana */}
        <circle cx="70" cy="58" r="4" fill="#AB47BC" opacity="0.4" /> {/* berry */}
        {/* magnifying glass */}
        <circle cx="58" cy="50" r="18" fill="none" stroke={white} strokeWidth="4" opacity="0.95" />
        <circle cx="58" cy="50" r="15" fill={white} opacity="0.15" />
        <line x1="72" y1="62" x2="86" y2="78" stroke={white} strokeWidth="5" strokeLinecap="round" opacity="0.9" />
        {/* shine on glass */}
        <path d="M48,40 Q52,36 54,40" fill="none" stroke={white} strokeWidth="2" strokeLinecap="round" opacity="0.4" />
        {/* number */}
        <circle cx="36" cy="74" r="9" fill="#FFD600" opacity="0.85" />
        <text x="36" y="78" textAnchor="middle" fontSize="10" fontWeight="900" fill="#01579B" fontFamily="sans-serif">50</text>
      </g>
    ),
    // Food Nerd (100): Nerdy character with glasses and food notebook
    book100: (
      <g opacity={op}>
        {/* face */}
        <circle cx="56" cy="48" r="16" fill={white} opacity="0.95" />
        {/* glasses */}
        <circle cx="50" cy="46" r="6" fill="none" stroke={pale} strokeWidth="2" opacity="0.9" />
        <circle cx="62" cy="46" r="6" fill="none" stroke={pale} strokeWidth="2" opacity="0.9" />
        <line x1="56" y1="46" x2="56" y2="46" stroke={pale} strokeWidth="2" opacity="0.9" />
        <line x1="44" y1="46" x2="40" y2="44" stroke={pale} strokeWidth="1.5" opacity="0.7" />
        <line x1="68" y1="46" x2="72" y2="44" stroke={pale} strokeWidth="1.5" opacity="0.7" />
        {/* eyes behind glasses */}
        <circle cx="50" cy="46" r="2" fill="#004C8C" opacity={locked ? 0.3 : 0.7} />
        <circle cx="62" cy="46" r="2" fill="#004C8C" opacity={locked ? 0.3 : 0.7} />
        {/* smile */}
        <path d="M50,54 Q56,58 62,54" fill="none" stroke="#004C8C" strokeWidth="1.5" strokeLinecap="round" opacity={locked ? 0.3 : 0.5} />
        {/* hair tuft */}
        <path d="M50,32 Q52,26 56,32 Q58,26 62,32" fill={white} opacity="0.8" />
        {/* notebook */}
        <rect x="72" y="50" width="18" height="24" rx="2" fill={white} opacity="0.9" />
        <rect x="74" y="50" width="3" height="24" fill={pale} opacity="0.5" />
        <line x1="79" y1="56" x2="88" y2="56" stroke={pale} strokeWidth="1" opacity="0.4" />
        <line x1="79" y1="60" x2="86" y2="60" stroke={pale} strokeWidth="1" opacity="0.4" />
        <line x1="79" y1="64" x2="87" y2="64" stroke={pale} strokeWidth="1" opacity="0.4" />
        {/* food doodle on notebook */}
        <circle cx="84" cy="69" r="3" fill="#FF7043" opacity="0.5" />
        {/* number badge */}
        <circle cx="36" cy="70" r="9" fill="#FFD600" opacity="0.85" />
        <text x="36" y="74" textAnchor="middle" fontSize="9" fontWeight="900" fill="#004C8C" fontFamily="sans-serif">100</text>
      </g>
    ),
    // Food Encyclopaedia (200): Open book with food illustrations bursting out
    book200: (
      <g opacity={op}>
        {/* open book pages */}
        <path d="M60,42 Q40,38 28,42 L28,80 Q40,76 60,80 Z" fill={white} opacity="0.95" />
        <path d="M60,42 Q80,38 92,42 L92,80 Q80,76 60,80 Z" fill={white} opacity="0.9" />
        {/* spine */}
        <line x1="60" y1="42" x2="60" y2="80" stroke={pale} strokeWidth="2" opacity="0.6" />
        {/* text lines left page */}
        <line x1="34" y1="52" x2="54" y2="52" stroke={pale} strokeWidth="1" opacity="0.3" />
        <line x1="34" y1="56" x2="52" y2="56" stroke={pale} strokeWidth="1" opacity="0.3" />
        <line x1="34" y1="60" x2="50" y2="60" stroke={pale} strokeWidth="1" opacity="0.3" />
        {/* text lines right page */}
        <line x1="66" y1="52" x2="86" y2="52" stroke={pale} strokeWidth="1" opacity="0.3" />
        <line x1="66" y1="56" x2="84" y2="56" stroke={pale} strokeWidth="1" opacity="0.3" />
        <line x1="66" y1="60" x2="82" y2="60" stroke={pale} strokeWidth="1" opacity="0.3" />
        {/* food bursting out: apple */}
        <circle cx="42" cy="34" r="7" fill="#FF5252" opacity="0.85" />
        <path d="M42,28 Q44,24 46,26" fill="none" stroke="#4CAF50" strokeWidth="1.5" strokeLinecap="round" />
        {/* food bursting out: broccoli */}
        <circle cx="74" cy="30" r="4" fill="#66BB6A" opacity="0.8" />
        <circle cx="70" cy="32" r="3.5" fill="#4CAF50" opacity="0.7" />
        <circle cx="78" cy="32" r="3.5" fill="#4CAF50" opacity="0.7" />
        <rect x="73" y="36" width="3" height="5" rx="1" fill="#8D6E63" opacity="0.5" />
        {/* food bursting out: cheese */}
        <path d="M56,28 L64,28 L60,20 Z" fill="#FFCA28" opacity="0.8" />
        <circle cx="58" cy="26" r="1.5" fill="#FFA000" opacity="0.5" />
        <circle cx="62" cy="27" r="1" fill="#FFA000" opacity="0.5" />
        {/* carrot */}
        <path d="M84,36 L88,26 L90,36" fill="#FF9800" opacity="0.7" />
        <path d="M88,26 Q90,22 92,24" fill="#4CAF50" opacity="0.6" />
        {/* sparkle stars */}
        <path d="M30,28 L32,24 L34,28 L30,26 L34,26" fill="#FFD600" opacity="0.8" />
        <path d="M90,18 L92,14 L94,18 L90,16 L94,16" fill="#FFD600" opacity="0.7" />
        {/* 200 label */}
        <circle cx="60" cy="70" r="9" fill="#FFD600" opacity="0.9" />
        <text x="60" y="74" textAnchor="middle" fontSize="9" fontWeight="900" fill="#002F6C" fontFamily="sans-serif">200</text>
      </g>
    ),

    // ---- HOME CHEF ----
    chef: (
      <g opacity={op}>
        <ellipse cx="60" cy="70" rx="14" ry="10" fill={white} opacity="0.9" />
        <circle cx="60" cy="56" r="12" fill={white} opacity="0.9" />
        <circle cx="54" cy="58" r="2" fill="#333" opacity={locked ? 0.3 : 0.7} />
        <circle cx="66" cy="58" r="2" fill="#333" opacity={locked ? 0.3 : 0.7} />
        <path d="M56,64 Q60,67 64,64" fill="none" stroke="#333" strokeWidth="1.5" opacity={locked ? 0.3 : 0.6} />
        <path d="M48,52 Q48,28 60,28 Q72,28 72,52" fill={white} opacity="0.95" />
        <circle cx="52" cy="34" r="8" fill={white} />
        <circle cx="68" cy="34" r="8" fill={white} />
        <circle cx="60" cy="30" r="9" fill={white} />
        <rect x="48" y="42" width="24" height="10" fill={white} />
        <path d="M54,78 Q56,82 60,82 Q64,82 66,78" fill="none" stroke={white} strokeWidth="2" opacity="0.5" />
      </g>
    ),
  };

  return icons[icon] || null;
};

export default function AchievementBadges({ earnedBadgeIds }: { earnedBadgeIds: Set<string> }) {
  const [showEarnedOnly, setShowEarnedOnly] = useState(false);
  const earnedCount = BADGES.filter(b => earnedBadgeIds.has(b.stringId)).length;
  const categories = [...new Set(BADGES.map(b => b.category))];

  return (
    <div style={{
      background: "linear-gradient(135deg, #0F0C29 0%, #1A1640 40%, #24243E 100%)",
      padding: "28px 20px",
      fontFamily: "'Nunito', 'Segoe UI', sans-serif",
    }}>
      <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@600;700;800;900&display=swap" rel="stylesheet" />

      <div style={{ maxWidth: 960, margin: "0 auto" }}>
        <p style={{ color: "#9E9EBE", fontSize: 13, textAlign: "center", marginBottom: 20 }}>
          {earnedCount} of {BADGES.length} earned
        </p>

        <div style={{ display: "flex", justifyContent: "center", marginBottom: 32, gap: 0 }}>
          <button
            onClick={() => setShowEarnedOnly(false)}
            style={{
              padding: "10px 28px",
              borderRadius: "24px 0 0 24px",
              border: "2px solid #6C63FF",
              background: !showEarnedOnly ? "linear-gradient(135deg, #6C63FF, #8B5CF6)" : "transparent",
              color: !showEarnedOnly ? "#FFF" : "#9E9EBE",
              fontWeight: 800,
              fontSize: 14,
              cursor: "pointer",
              fontFamily: "inherit",
              transition: "all 0.2s",
            }}
          >
            🏅 All Badges
          </button>
          <button
            onClick={() => setShowEarnedOnly(true)}
            style={{
              padding: "10px 28px",
              borderRadius: "0 24px 24px 0",
              border: "2px solid #6C63FF",
              borderLeft: "none",
              background: showEarnedOnly ? "linear-gradient(135deg, #6C63FF, #8B5CF6)" : "transparent",
              color: showEarnedOnly ? "#FFF" : "#9E9EBE",
              fontWeight: 800,
              fontSize: 14,
              cursor: "pointer",
              fontFamily: "inherit",
              transition: "all 0.2s",
            }}
          >
            ✨ Earned
          </button>
        </div>

        {categories.map(cat => {
          const catBadges = BADGES.filter(b => b.category === cat).filter(b => !showEarnedOnly || earnedBadgeIds.has(b.stringId));
          if (catBadges.length === 0) return null;
          return (
            <div key={cat} style={{ marginBottom: 36 }}>
              <h2 style={{
                color: "#C5C3E8",
                fontSize: 16,
                fontWeight: 800,
                marginBottom: 16,
                paddingLeft: 8,
                textTransform: "uppercase",
                letterSpacing: "1.5px",
              }}>
                {cat}
              </h2>
              <div style={{
                display: "grid",
                gridTemplateColumns: "repeat(auto-fill, minmax(140px, 1fr))",
                gap: 16,
              }}>
                {catBadges.map(badge => {
                  const earned = earnedBadgeIds.has(badge.stringId);
                  return (
                    <div
                      key={badge.id}
                      style={{
                        display: "flex",
                        flexDirection: "column",
                        alignItems: "center",
                        padding: "16px 8px 12px",
                        borderRadius: 16,
                        background: "rgba(255,255,255,0.04)",
                        border: "1px solid rgba(255,255,255,0.06)",
                        transition: "all 0.3s",
                        cursor: "default",
                      }}
                      onMouseEnter={e => {
                        (e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.08)";
                        (e.currentTarget as HTMLDivElement).style.transform = "translateY(-4px)";
                      }}
                      onMouseLeave={e => {
                        (e.currentTarget as HTMLDivElement).style.background = "rgba(255,255,255,0.04)";
                        (e.currentTarget as HTMLDivElement).style.transform = "translateY(0)";
                      }}
                    >
                      <div style={{ filter: !earned ? "saturate(0) brightness(0.6)" : "none", transition: "filter 0.3s" }}>
                        <BadgeShape shape={badge.shape} colors={badge.colors} locked={!earned}>
                          <BadgeIcon icon={badge.icon} locked={!earned} accent={badge.accent} />
                        </BadgeShape>
                      </div>
                      <span style={{
                        color: earned ? "#EEEEFF" : "#7A7A8E",
                        fontSize: 11,
                        fontWeight: 800,
                        marginTop: 8,
                        textAlign: "center",
                        lineHeight: 1.3,
                      }}>
                        {badge.name}
                      </span>
                      <span style={{
                        color: earned ? "#9E9EBE" : "#55556A",
                        fontSize: 9,
                        fontWeight: 600,
                        marginTop: 2,
                        textAlign: "center",
                        lineHeight: 1.3,
                      }}>
                        {badge.desc}
                      </span>
                    </div>
                  );
                })}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
