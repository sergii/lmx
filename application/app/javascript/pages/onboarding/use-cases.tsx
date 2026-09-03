import { Form, Head } from "@inertiajs/react"
import { Check } from "lucide-react"
import { useState } from "react"

import { Button } from "@/components/ui/button"
import { cn } from "@/lib/utils"
import OnboardingLayout from "@/layouts/onboarding-layout"

type UseCases = Record<string, string>

export default function UseCases({
  selected_use_cases,
  use_cases,
}: {
  selected_use_cases: string[]
  use_cases: UseCases
}) {
  const [selected, setSelected] = useState(selected_use_cases)

  const toggle = (value: string) => {
    setSelected((current) =>
      current.includes(value)
        ? current.filter((item) => item !== value)
        : [...current, value],
    )
  }

  return (
    <OnboardingLayout
      step={3}
      title="Tailor your workspace"
      description="Choose what you want to start with. This only helps us shape your initial experience; it does not limit the workspace."
    >
      <Head title="Recruiting setup" />
      <Form action="/onboarding/use-cases" method="patch" className="space-y-6">
        {({ processing }) => (
          <>
            <div className="grid gap-3">
              {Object.entries(use_cases).map(([value, label]) => {
                const active = selected.includes(value)

                return (
                  <button
                    key={value}
                    type="button"
                    onClick={() => toggle(value)}
                    className={cn(
                      "flex items-center justify-between rounded-xl border px-4 py-3 text-left text-sm font-medium transition-colors",
                      active
                        ? "border-primary bg-primary/5"
                        : "hover:bg-muted/70",
                    )}
                  >
                    {label}
                    <span
                      className={cn(
                        "flex size-5 items-center justify-center rounded-full border",
                        active &&
                          "border-primary bg-primary text-primary-foreground",
                      )}
                    >
                      {active && <Check className="size-3" />}
                    </span>
                  </button>
                )
              })}
            </div>
            {selected.map((value) => (
              <input
                key={value}
                type="hidden"
                name="use_cases[]"
                value={value}
              />
            ))}
            <Button type="submit" className="w-full" disabled={processing}>
              Continue
            </Button>
          </>
        )}
      </Form>
    </OnboardingLayout>
  )
}
