import { cn } from "@/lib/utils"

const levelStyles: Record<string, string> = {
  a1: "border-amber-300 bg-amber-100 text-amber-950",
  a2: "border-yellow-300 bg-yellow-100 text-yellow-950",
  b1: "border-lime-300 bg-lime-100 text-lime-950",
  b2: "border-emerald-300 bg-emerald-100 text-emerald-950",
  c1: "border-green-400 bg-green-200 text-green-950",
  c2: "border-emerald-700 bg-emerald-700 text-white",
}

export default function LanguageProficiencyBadge({
  code,
  label,
  className,
}: {
  code: string
  label?: string
  className?: string
}) {
  const normalizedCode = code.toLowerCase()

  return (
    <span
      className={cn("inline-flex items-center gap-2", className)}
      title={
        label
          ? `${normalizedCode.toUpperCase()} · ${label}`
          : normalizedCode.toUpperCase()
      }
    >
      <span
        aria-label={`${normalizedCode.toUpperCase()} language proficiency`}
        className={cn(
          "inline-flex size-8 shrink-0 items-center justify-center border text-xs font-bold shadow-sm",
          "[clip-path:polygon(50%_0%,94%_14%,94%_60%,50%_100%,6%_60%,6%_14%)]",
          levelStyles[normalizedCode] ??
            "border-muted-foreground/30 bg-muted text-foreground",
        )}
      >
        <span className="-translate-y-[3px]">
          {normalizedCode.toUpperCase()}
        </span>
      </span>
      {label && (
        <span className="-translate-y-[3px] text-sm font-medium">{label}</span>
      )}
    </span>
  )
}
