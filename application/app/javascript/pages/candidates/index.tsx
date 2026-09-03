import { Head, Link } from "@inertiajs/react"

import Heading from "@/components/heading"
import LanguageProficiencyBadge from "@/components/language-proficiency-badge"
import { Button } from "@/components/ui/button"
import AppLayout from "@/layouts/app-layout"

type Candidate = {
  id: string
  first_name: string
  last_name: string
  email: string | null
  location: string | null
  time_zone: string | null
  source: string | null
  consent_status: string
  english_proficiency: { code: string; label: string } | null
}

export default function Candidates({
  candidates,
}: {
  candidates: Candidate[]
}) {
  return (
    <AppLayout breadcrumbs={[{ title: "Candidates", href: "/candidates" }]}>
      <Head title="Candidates" />
      <div className="p-6">
        <div className="mb-6 flex items-start justify-between gap-4">
          <Heading
            title="Candidates"
            description="People in your workspace’s talent pool."
          />
          <Button asChild>
            <Link href="/candidates/new">Add candidate</Link>
          </Button>
        </div>
        {candidates.length === 0 ? (
          <div className="rounded-xl border border-dashed p-10 text-center">
            <h3 className="font-medium">No candidates yet</h3>
            <p className="text-muted-foreground mt-2 text-sm">
              Add the first candidate to this workspace.
            </p>
          </div>
        ) : (
          <div className="overflow-hidden rounded-xl border">
            {candidates.map((candidate) => (
              <div
                key={candidate.id}
                className="flex items-center justify-between border-b p-4 last:border-b-0"
              >
                <div>
                  <Link
                    href={`/candidates/${candidate.id}`}
                    className="font-medium hover:underline"
                  >
                    {candidate.first_name} {candidate.last_name}
                  </Link>
                  <p className="text-muted-foreground text-sm">
                    {candidate.email ||
                      candidate.location ||
                      "No contact details"}
                  </p>
                </div>
                <div className="flex items-center gap-5">
                  {candidate.english_proficiency && (
                    <LanguageProficiencyBadge
                      code={candidate.english_proficiency.code}
                      label={candidate.english_proficiency.label}
                    />
                  )}
                  <span className="text-muted-foreground text-xs">
                    Consent: {candidate.consent_status}
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
