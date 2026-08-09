import { motion } from "framer-motion";
import { ChartSpline, Fuel, MapPin } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { FleetMapIllustration } from "./FleetMapIllustration";

interface HighlightCard {
  icon: LucideIcon;
  title: string;
  description: string;
}

const HIGHLIGHTS: HighlightCard[] = [
  {
    icon: MapPin,
    title: "Ubicación en tiempo real",
    description: "Sigue cada vehículo de la flota en el mapa, al instante.",
  },
  {
    icon: Fuel,
    title: "Alertas predictivas",
    description: "Consumo, temperatura y fallas detectadas antes de escalar.",
  },
  {
    icon: ChartSpline,
    title: "Analítica inteligente",
    description: "Métricas de operación y rutas para decidir con datos.",
  },
];

const containerVariants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.12, delayChildren: 0.2 } },
};

const itemVariants = {
  hidden: { opacity: 0, y: 16 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.5, ease: "easeOut" } },
} as const;

export function LoginHero() {
  return (
    <section className="relative hidden overflow-hidden bg-slate-950 lg:flex lg:w-[45%] lg:flex-col lg:justify-center">
      {/* Layered gradients: deep blue base + a lit corner behind the map */}
      <div className="absolute inset-0 bg-gradient-to-br from-slate-950 via-blue-950 to-slate-900" />
      <div className="absolute -top-24 -right-16 size-[28rem] rounded-full bg-blue-600/25 blur-3xl" />
      <div className="absolute -bottom-32 -left-20 size-[24rem] rounded-full bg-sky-500/15 blur-3xl" />

      <motion.div
        variants={containerVariants}
        initial="hidden"
        animate="visible"
        className="relative flex flex-col gap-9 px-12 py-12 xl:px-16 2xl:gap-11"
      >
        <motion.div variants={itemVariants} className="flex justify-center">
          <FleetMapIllustration className="max-w-[13rem] 2xl:max-w-[15rem]" />
        </motion.div>

        <motion.div variants={itemVariants} className="space-y-4">
          <h1 className="leading-tight font-bold tracking-tight text-white">
            <span className="block text-3xl xl:text-4xl 2xl:text-5xl">
              Monitoreo inteligente
            </span>
            <span className="block text-3xl text-blue-400 xl:text-4xl 2xl:text-5xl">
              para flotas conectadas
            </span>
          </h1>

          <p className="max-w-lg text-sm leading-relaxed text-slate-400 2xl:text-base">
            Visualiza en tiempo real la información de todos tus vehículos y
            recibe alertas predictivas para tomar decisiones oportunas.
          </p>
        </motion.div>

        <motion.ul variants={containerVariants} className="space-y-3.5">
          {HIGHLIGHTS.map(({ icon: Icon, title, description }) => (
            <motion.li
              key={title}
              variants={itemVariants}
              whileHover={{ y: -3 }}
              transition={{ type: "spring", stiffness: 300, damping: 20 }}
              className="group flex items-start gap-3.5 rounded-2xl border border-white/10 bg-white/[0.06] p-4 shadow-[0_8px_30px_rgb(0,0,0,0.24)] backdrop-blur-xl transition-colors duration-300 hover:border-blue-400/30 hover:bg-white/[0.09] hover:shadow-[0_8px_30px_rgb(37,99,235,0.18)]"
            >
              <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-blue-500/20 text-blue-300 transition-colors duration-300 group-hover:bg-blue-500/30 group-hover:text-blue-200">
                <Icon className="size-4.5" aria-hidden />
              </span>
              <div className="space-y-0.5">
                <p className="text-sm font-semibold text-white">{title}</p>
                <p className="text-xs leading-relaxed text-slate-400 2xl:text-sm">
                  {description}
                </p>
              </div>
            </motion.li>
          ))}
        </motion.ul>
      </motion.div>
    </section>
  );
}
