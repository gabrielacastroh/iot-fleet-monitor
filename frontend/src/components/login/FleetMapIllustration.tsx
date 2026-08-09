import { motion } from "framer-motion";
import { cn } from "@/lib/utils";

/**
 * Route the vehicle marker travels along. Kept as explicit points so the
 * marker keyframes and the drawn path stay in sync.
 */
const ROUTE = [
  { x: 52, y: 250 },
  { x: 118, y: 214 },
  { x: 150, y: 150 },
  { x: 236, y: 132 },
  { x: 292, y: 78 },
] as const;

const ROUTE_PATH = ROUTE.map(
  ({ x, y }, index) => `${index === 0 ? "M" : "L"}${x} ${y}`,
).join(" ");

const SENSOR_NODES = [
  { x: 118, y: 214, delay: 0.6 },
  { x: 150, y: 150, delay: 1.2 },
  { x: 236, y: 132, delay: 1.8 },
];

interface FleetMapIllustrationProps {
  className?: string;
}

export function FleetMapIllustration({ className }: FleetMapIllustrationProps) {
  const last = ROUTE.at(-1)!;

  return (
    <svg
      viewBox="0 0 360 300"
      fill="none"
      role="img"
      aria-label="Mapa de rutas con vehículos conectados y sensores IoT"
      className={cn("h-auto w-full", className)}
    >
      <defs>
        <linearGradient id="route-glow" x1="0" y1="1" x2="1" y2="0">
          <stop offset="0%" stopColor="#1d4ed8" />
          <stop offset="55%" stopColor="#3b82f6" />
          <stop offset="100%" stopColor="#60a5fa" />
        </linearGradient>
        <radialGradient id="map-fade" cx="50%" cy="60%" r="60%">
          <stop offset="0%" stopColor="#60a5fa" stopOpacity="0.35" />
          <stop offset="100%" stopColor="#60a5fa" stopOpacity="0" />
        </radialGradient>
        <filter id="route-blur" x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="6" />
        </filter>
      </defs>

      {/* Ambient glow behind the map */}
      <ellipse cx="180" cy="180" rx="170" ry="120" fill="url(#map-fade)" />

      {/* Street grid, skewed for a subtle perspective */}
      <g
        transform="matrix(1 0.24 -0.62 0.86 150 -20)"
        stroke="#60a5fa"
        strokeWidth="1"
        opacity="0.22"
      >
        {Array.from({ length: 9 }, (_, index) => (
          <line
            key={`v-${index}`}
            x1={index * 40}
            y1={0}
            x2={index * 40}
            y2={320}
          />
        ))}
        {Array.from({ length: 9 }, (_, index) => (
          <line
            key={`h-${index}`}
            x1={0}
            y1={index * 40}
            x2={320}
            y2={index * 40}
          />
        ))}
      </g>

      {/* Route: blurred copy underneath for the neon bleed */}
      <motion.path
        d={ROUTE_PATH}
        stroke="url(#route-glow)"
        strokeWidth="7"
        strokeLinecap="round"
        strokeLinejoin="round"
        filter="url(#route-blur)"
        opacity="0.7"
        initial={{ pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 1.8, ease: "easeInOut" }}
      />
      <motion.path
        d={ROUTE_PATH}
        stroke="url(#route-glow)"
        strokeWidth="2.5"
        strokeLinecap="round"
        strokeLinejoin="round"
        initial={{ pathLength: 0 }}
        animate={{ pathLength: 1 }}
        transition={{ duration: 1.8, ease: "easeInOut" }}
      />

      {/* Mesh links between sensor nodes — reads as an IoT network, not just a route */}
      <motion.g
        stroke="#93c5fd"
        strokeWidth="1"
        strokeDasharray="3 4"
        opacity="0.5"
        initial={{ opacity: 0 }}
        animate={{ opacity: 0.5 }}
        transition={{ delay: 1.6, duration: 0.6 }}
      >
        <line x1={118} y1={214} x2={236} y2={132} />
        <line x1={150} y1={150} x2={52} y2={250} />
      </motion.g>

      {/* Sensor nodes pulsing along the route */}
      {SENSOR_NODES.map(({ x, y, delay }) => (
        <g key={`${x}-${y}`}>
          <motion.circle
            cx={x}
            cy={y}
            r="4"
            fill="#93c5fd"
            initial={{ scale: 0, opacity: 0 }}
            animate={{ scale: 1, opacity: 1 }}
            transition={{ delay, duration: 0.4 }}
            style={{ originX: `${x}px`, originY: `${y}px` }}
          />
          <motion.circle
            cx={x}
            cy={y}
            r="4"
            stroke="#60a5fa"
            strokeWidth="1.5"
            fill="none"
            initial={{ scale: 1, opacity: 0.8 }}
            animate={{ scale: [1, 3.2], opacity: [0.8, 0] }}
            transition={{
              delay,
              duration: 2.4,
              repeat: Infinity,
              ease: "easeOut",
            }}
            style={{ originX: `${x}px`, originY: `${y}px` }}
          />
        </g>
      ))}

      {/* Origin marker */}
      <circle cx={ROUTE[0].x} cy={ROUTE[0].y} r="9" fill="#1e3a8a" />
      <circle cx={ROUTE[0].x} cy={ROUTE[0].y} r="4" fill="#bfdbfe" />

      {/* Vehicle marker travelling the route */}
      <motion.g
        initial={{ opacity: 0 }}
        animate={{
          opacity: 1,
          x: ROUTE.map((point) => point.x - last.x),
          y: ROUTE.map((point) => point.y - last.y),
        }}
        transition={{
          opacity: { delay: 0.3, duration: 0.4 },
          x: { delay: 0.3, duration: 6, repeat: Infinity, ease: "easeInOut" },
          y: { delay: 0.3, duration: 6, repeat: Infinity, ease: "easeInOut" },
        }}
      >
        <path
          d={`M${last.x} ${last.y + 12}
              c-8 -10 -13 -15 -13 -22 a13 13 0 1 1 26 0 c0 7 -5 12 -13 22z`}
          fill="#2563eb"
        />
        <g
          transform={`translate(${last.x - 7} ${last.y - 15})`}
          stroke="#ffffff"
          strokeWidth="1.3"
          strokeLinecap="round"
          strokeLinejoin="round"
          fill="none"
        >
          <path d="M0.5 7.5V2.6a.8.8 0 0 1 .8-.8h6.4a.8.8 0 0 1 .8.8v4.9" />
          <path d="M8.5 4.2h2.4l2.1 2.6v.7" />
          <circle cx="3.4" cy="8.6" r="1.1" />
          <circle cx="10.2" cy="8.6" r="1.1" />
        </g>

        {/* Live signal ring broadcasting from the moving vehicle */}
        <motion.circle
          cx={last.x}
          cy={last.y - 8}
          r="3"
          stroke="#60a5fa"
          strokeWidth="1.5"
          fill="none"
          initial={{ scale: 1, opacity: 0.9 }}
          animate={{ scale: [1, 4], opacity: [0.9, 0] }}
          transition={{ duration: 2, repeat: Infinity, ease: "easeOut" }}
          style={{
            originX: `${last.x}px`,
            originY: `${last.y - 8}px`,
          }}
        />
      </motion.g>
    </svg>
  );
}
