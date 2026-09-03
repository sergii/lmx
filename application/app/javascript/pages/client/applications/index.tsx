import { Head, Link } from "@inertiajs/react"

import Heading from "@/components/heading"
import AppLayout from "@/layouts/app-layout"

interface ClientApplication {
  id: string
  stage: string
  role: string
  project: string
  candidate: { name: string; skills: string[] }
}

export default function ClientApplications({
  applications,
}: {
  applications: ClientApplication[]
}) {
  return (
    <AppLayout
      breadcrumbs={[
        { title: "Presented candidates", href: "/client/applications" },
      ]}
    >
      <Head title="Presented candidates" />
      <div className="max-w-5xl p-6">
        <Heading
          title="Presented candidates"
          description="Candidates shared with your team."
        />
        {applications.length === 0 ? (
          <p className="text-muted-foreground">
            No candidates have been presented yet.
          </p>
        ) : (
          <div className="space-y-3">
            {applications.map((application) => (
              <Link
                key={application.id}
                href={`/client/applications/${application.id}`}
                className="hover:bg-muted/50 block rounded-xl border p-4"
              >
                <div className="flex items-start justify-between gap-4">
                  <div>
                    <p className="font-medium">{application.candidate.name}</p>
                    <p className="text-muted-foreground text-sm">
                      {application.role} · {application.project}
                    </p>
                    {application.candidate.skills.length > 0 && (
                      <p className="text-muted-foreground mt-2 text-xs">
                        {application.candidate.skills.join(" · ")}
                      </p>
                    )}
                  </div>
                  <span className="bg-muted rounded-full px-2 py-1 text-xs capitalize">
                    {application.stage.replaceAll("_", " ")}
                  </span>
                </div>
              </Link>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
