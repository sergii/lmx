# frozen_string_literal: true

# Development credentials
# Workspace admin: admin@hire.do / HireDoDemo2026!
# Recruiter:       recruiter@hire.do / HireDoDemo2026!
# Northstar client: client@northstar.example / HireDoDemo2026!

PASSWORD = "HireDoDemo2026!" unless defined?(PASSWORD)

def seed_user(email:, name:)
  User.find_or_initialize_by(email:).tap do |user|
    user.update!(name:, password: PASSWORD, password_confirmation: PASSWORD, verified: true)
  end
end

def seed_membership(user:, organization:, role:, client_company: nil)
  Membership.find_or_initialize_by(user:, organization:).tap do |membership|
    membership.update!(role:, client_company:, active: true)
  end
end

def seed_candidate(attributes, english_level:)
  candidate = Candidate.find_or_initialize_by(email: attributes.fetch(:email))
  candidate.update!(attributes.merge(english_level: Candidate::LEGACY_ENGLISH_LEVEL_TO_CEFR.invert.fetch(english_level)))
  LanguageProficiency.find_or_initialize_by(candidate:, language_code: "en").update!(level: english_level)
  candidate
end

def seed_application(candidate:, job:, recruiter:, stage:, client_visible:)
  application = Application.find_or_initialize_by(candidate:, job:)
  application.update!(sourced_by: recruiter, stage:, client_visible:)
  application
end

def seed_stage_history(application:, recruiter:, stages:, occurred_at_by_stage:)
  stages.each_with_index do |stage, index|
    ApplicationStageEvent.find_or_initialize_by(application:, to_stage: stage).update!(
      from_stage: index.zero? ? nil : stages[index - 1],
      moved_by: recruiter,
      occurred_at: occurred_at_by_stage.fetch(stage)
    )
  end
end

def seed_meeting(candidate:, application:, created_by:, kind:, status:, scheduled_at:, duration_minutes:, notes:, meeting_url: nil)
  meeting = Meeting.find_or_initialize_by(candidate:, application:, kind:, sequence: 1)
  meeting.update!(created_by:, status:, scheduled_at:, duration_minutes:, notes:, meeting_url:)

  task = Task.find_or_initialize_by(
    created_by:,
    assigned_to: application&.sourced_by || created_by,
    title: "#{kind.humanize} with #{candidate.first_name} #{candidate.last_name}"
  )
  task.update!(due_on: scheduled_at.to_date, completed_at: status == "scheduled" ? nil : scheduled_at)
  meeting.update!(reminder_task: task)
  meeting
end

admin = seed_user(email: "admin@hire.do", name: "Hire.do Admin")
recruiter = seed_user(email: "recruiter@hire.do", name: "Maya Chen")
ops_lead = seed_user(email: "ops@hire.do", name: "Alex Morgan")

organization = Organization.find_or_initialize_by(slug: "turnkey-staffing")
organization.update!(name: "TurnKey Staffing")

seed_membership(user: admin, organization:, role: "workspace_admin")
seed_membership(user: recruiter, organization:, role: "recruiter")
seed_membership(user: ops_lead, organization:, role: "recruiting_ops_lead")

Current.set(organization:) do
  northstar = ClientCompany.find_or_create_by!(name: "Northstar Labs")
  helio = ClientCompany.find_or_create_by!(name: "Helio Health")
  boldin = ClientCompany.find_or_create_by!(name: "Boldin")

  northstar_manager = seed_user(email: "client@northstar.example", name: "Olivia Reed")
  helio_manager = seed_user(email: "hiring@helio.example", name: "Samira Patel")
  seed_membership(user: northstar_manager, organization:, role: "client_hiring_manager", client_company: northstar)
  seed_membership(user: helio_manager, organization:, role: "client_hiring_manager", client_company: helio)

  platform = Project.find_or_create_by!(name: "Platform Modernization", client_company: northstar)
  patient_portal = Project.find_or_create_by!(name: "Patient Portal", client_company: helio)
  boldin_product = Project.find_or_create_by!(name: "Product Engineering", client_company: boldin)

  react_job = Job.find_or_initialize_by(title: "Senior React Engineer", project: platform)
  react_job.update!(seniority: "Senior", technology_stack: "React, TypeScript, Next.js, PostgreSQL", status: "open", description: "Own customer-facing platform capabilities for Northstar's modernization program. Partner with product and design, improve the frontend architecture, and deliver reliable user-facing features.")
  devops_job = Job.find_or_initialize_by(title: "Senior DevOps Engineer", project: platform)
  devops_job.update!(seniority: "Senior", technology_stack: "AWS, Kubernetes, Terraform, GitHub Actions", status: "open", description: "Build and operate the platform foundations that help product teams ship safely and quickly.")
  backend_job = Job.find_or_initialize_by(title: "Backend Engineer", project: patient_portal)
  backend_job.update!(seniority: "Middle+", technology_stack: "Ruby on Rails, PostgreSQL, Sidekiq, React", status: "open", description: "Develop secure, maintainable backend workflows for Helio's patient-facing product.")
  design_job = Job.find_or_initialize_by(title: "Product Designer", project: patient_portal)
  design_job.update!(seniority: "Senior", technology_stack: "Figma, Design Systems, Healthcare UX", status: "open", description: "Lead product-design discovery and evolve the design system for a healthcare experience.")
  boldin_job = Job.find_or_initialize_by(title: "Full-Stack Engineer", project: boldin_product)
  boldin_job.update!(seniority: "Senior", technology_stack: "To be confirmed from the role brief", status: "open", description: "Public role imported from TurnKey Staffing. The recruiter should capture and approve the detailed internal brief before sourcing.")

  SourcingBrief.find_or_initialize_by(job: react_job).update!(
    status: "approved", approved_by: recruiter, approved_at: 1.day.ago,
    summary: "Senior product engineer who can own complex React surfaces while collaborating closely with design and backend teams.",
    must_haves: [ "React", "TypeScript", "Production product experience", "English B2+" ],
    nice_to_haves: [ "Next.js", "PostgreSQL", "Accessibility", "SaaS experience" ],
    exclusions: [ "Unavailable for more than 60 days", "No production TypeScript experience" ],
    search_queries: [ "React AND TypeScript AND accessibility", "Next.js AND TypeScript AND SaaS" ],
    location_preferences: [ "Europe", "Latin America", "UTC−3 to UTC+3" ],
    language_requirement: "English B2+",
    interview_focus: "Ownership, frontend architecture, accessibility judgment, and product collaboration."
  )
  SourcingBrief.find_or_initialize_by(job: boldin_job).update!(
    status: "draft", summary: "Review the external posting with the client, then turn its requirements into an approved sourcing target.",
    must_haves: [], nice_to_haves: [], exclusions: [], search_queries: [], location_preferences: [], language_requirement: nil, interview_focus: nil,
    approved_by: nil, approved_at: nil
  )
  open_jobs = [ react_job, devops_job, backend_job, design_job, boldin_job ]
  open_jobs.each do |job|
    JobPosting.find_or_initialize_by(job:, public_url: "https://turnkeystaffing.com/career/full-stack-engineer-for-boldin/").update!(
      channel: "careers_site", status: "published", title: job.title,
      content_snapshot: "TurnKey Staffing public careers reference linked by the recruiter. Review and approve a role-specific internal sourcing brief before sourcing."
    )
  end

  sofia = seed_candidate({
    first_name: "Sofía", last_name: "Martínez", email: "sofia.martinez@example.com",
    location: "Buenos Aires, Argentina", time_zone: "America/Argentina/Buenos_Aires",
    source: "LinkedIn", consent_status: "granted", skills: [ "React", "TypeScript", "Next.js", "PostgreSQL" ],
    tags: [ "LATAM", "frontend", "high-priority" ], linkedin_url: "https://www.linkedin.com/in/sofia-martinez",
    availability: "2 weeks", notice_period: "2 weeks", salary_expectation: "$6,500/month",
    notes: "Strong product engineering background. Presented after a successful technical interview."
  }, english_level: "c1")
  lucas = seed_candidate({
    first_name: "Lucas", last_name: "Kim", email: "lucas.kim@example.com",
    location: "Lisbon, Portugal", time_zone: "Europe/Lisbon", source: "Referral", consent_status: "granted",
    skills: [ "React", "TypeScript", "GraphQL", "Testing Library" ], tags: [ "EU", "frontend" ],
    github_url: "https://github.com/lucaskim", availability: "3 weeks", notice_period: "1 month",
    salary_expectation: "$7,200/month", notes: "Referral from a former staff engineer; client interview booked."
  }, english_level: "c2")
  diego = seed_candidate({
    first_name: "Diego", last_name: "Silva", email: "diego.silva@example.com",
    location: "Montevideo, Uruguay", time_zone: "America/Montevideo", source: "Referral", consent_status: "granted",
    skills: [ "AWS", "Kubernetes", "Terraform", "Ruby" ], tags: [ "LATAM", "devops" ],
    github_url: "https://github.com/diegosilva", availability: "Immediate", notice_period: "None",
    salary_expectation: "$6,800/month", notes: "Excellent infrastructure depth; scheduled for technical interview."
  }, english_level: "b2")
  priya = seed_candidate({
    first_name: "Priya", last_name: "Nair", email: "priya.nair@example.com",
    location: "Berlin, Germany", time_zone: "Europe/Berlin", source: "Outbound", consent_status: "granted",
    skills: [ "Ruby on Rails", "PostgreSQL", "Sidekiq", "Hotwire" ], tags: [ "EU", "backend" ],
    linkedin_url: "https://www.linkedin.com/in/priya-nair", availability: "1 month", notice_period: "1 month",
    salary_expectation: "$7,800/month", notes: "Initial outbound reply received; recruiter screen scheduled."
  }, english_level: "c1")
  jae = seed_candidate({
    first_name: "Jae", last_name: "Williams", email: "jae.williams@example.com",
    location: "Toronto, Canada", time_zone: "America/Toronto", source: "Inbound", consent_status: "granted",
    skills: [ "React", "TypeScript", "Accessibility", "Design Systems" ], tags: [ "North America", "frontend" ],
    linkedin_url: "https://www.linkedin.com/in/jae-williams", availability: "Immediate", notice_period: "2 weeks",
    salary_expectation: "$8,000/month", notes: "Selected by Northstar after the final client interview."
  }, english_level: "c2")
  elena = seed_candidate({
    first_name: "Elena", last_name: "Petrova", email: "elena.petrova@example.com",
    location: "Warsaw, Poland", time_zone: "Europe/Warsaw", source: "Talent community", consent_status: "granted",
    skills: [ "Figma", "Research", "Design Systems" ], tags: [ "EU", "design" ], availability: "2 weeks",
    notice_period: "2 weeks", salary_expectation: "$6,000/month", notes: "Strong portfolio; held for the product-design requisition."
  }, english_level: "b2")

  sofia_application = seed_application(candidate: sofia, job: react_job, recruiter:, stage: "presented", client_visible: true)
  lucas_application = seed_application(candidate: lucas, job: react_job, recruiter:, stage: "client_interviews", client_visible: true)
  diego_application = seed_application(candidate: diego, job: devops_job, recruiter:, stage: "technical_interview", client_visible: false)
  priya_application = seed_application(candidate: priya, job: backend_job, recruiter:, stage: "recruiter_screen", client_visible: false)
  jae_application = seed_application(candidate: jae, job: react_job, recruiter:, stage: "selected", client_visible: true)
  elena_application = seed_application(candidate: elena, job: design_job, recruiter:, stage: "sourced", client_visible: false)

  seed_stage_history(application: sofia_application, recruiter:, stages: %w[sourced recruiter_screen english_check technical_interview internal_approval presented], occurred_at_by_stage: {
    "sourced" => 15.days.ago, "recruiter_screen" => 12.days.ago + 1.hour, "english_check" => 11.days.ago,
    "technical_interview" => 9.days.ago + 1.hour, "internal_approval" => 8.days.ago, "presented" => 6.days.ago
  })
  seed_stage_history(application: lucas_application, recruiter:, stages: %w[sourced recruiter_screen technical_interview presented client_interviews], occurred_at_by_stage: {
    "sourced" => 16.days.ago, "recruiter_screen" => 14.days.ago + 1.hour, "technical_interview" => 10.days.ago + 1.hour,
    "presented" => 7.days.ago, "client_interviews" => 1.day.ago
  })
  seed_stage_history(application: diego_application, recruiter:, stages: %w[sourced recruiter_screen english_check technical_interview], occurred_at_by_stage: {
    "sourced" => 10.days.ago, "recruiter_screen" => 8.days.ago + 1.hour, "english_check" => 7.days.ago,
    "technical_interview" => 1.day.ago
  })
  seed_stage_history(application: priya_application, recruiter:, stages: %w[sourced recruiter_screen], occurred_at_by_stage: {
    "sourced" => 3.days.ago, "recruiter_screen" => 1.day.ago
  })
  seed_stage_history(application: jae_application, recruiter:, stages: %w[sourced recruiter_screen technical_interview presented client_interviews selected], occurred_at_by_stage: {
    "sourced" => 18.days.ago, "recruiter_screen" => 15.days.ago + 1.hour, "technical_interview" => 10.days.ago + 1.hour,
    "presented" => 7.days.ago, "client_interviews" => 5.days.ago + 1.hour, "selected" => 1.day.ago
  })
  seed_stage_history(application: elena_application, recruiter:, stages: %w[sourced], occurred_at_by_stage: { "sourced" => 4.days.ago })

  ClientDecision.find_or_initialize_by(application: jae_application).update!(
    decided_by: northstar_manager,
    decision: "accepted",
    note: "Approved by the hiring panel. Start-date discussion is underway.",
    decided_at: 1.day.ago
  )

  seed_meeting(candidate: sofia, application: sofia_application, created_by: recruiter, kind: "recruiter_screen", status: "completed", scheduled_at: 12.days.ago, duration_minutes: 30, notes: "Confirmed product depth, English fluency, and a two-week availability window.")
  seed_meeting(candidate: sofia, application: sofia_application, created_by: recruiter, kind: "technical_interview", status: "completed", scheduled_at: 9.days.ago, duration_minutes: 75, notes: "Strong system design and communication. Ready for client presentation.")
  seed_meeting(candidate: lucas, application: lucas_application, created_by: recruiter, kind: "recruiter_screen", status: "completed", scheduled_at: 14.days.ago, duration_minutes: 30, notes: "Validated referral context, compensation range, and availability.")
  seed_meeting(candidate: lucas, application: lucas_application, created_by: recruiter, kind: "technical_interview", status: "completed", scheduled_at: 10.days.ago, duration_minutes: 90, notes: "Strong TypeScript and testing fundamentals; recommended for client interview.")
  seed_meeting(candidate: lucas, application: lucas_application, created_by: recruiter, kind: "client_interview", status: "scheduled", scheduled_at: 2.days.from_now.change(hour: 15, min: 0), duration_minutes: 60, meeting_url: "https://meet.google.com/demo-lucas", notes: "Meet Northstar's engineering manager and staff engineer.")
  seed_meeting(candidate: diego, application: diego_application, created_by: recruiter, kind: "recruiter_screen", status: "completed", scheduled_at: 8.days.ago, duration_minutes: 30, notes: "Confirmed hands-on platform experience and immediate availability.")
  seed_meeting(candidate: diego, application: diego_application, created_by: recruiter, kind: "technical_interview", status: "scheduled", scheduled_at: 1.day.from_now.change(hour: 17, min: 0), duration_minutes: 90, meeting_url: "https://meet.google.com/demo-diego", notes: "Terraform and Kubernetes troubleshooting exercise.")
  seed_meeting(candidate: priya, application: priya_application, created_by: recruiter, kind: "recruiter_screen", status: "scheduled", scheduled_at: 3.days.from_now.change(hour: 11, min: 30), duration_minutes: 30, notes: "Confirm compensation range, availability, and healthcare domain interest.")
  seed_meeting(candidate: jae, application: jae_application, created_by: recruiter, kind: "recruiter_screen", status: "completed", scheduled_at: 15.days.ago, duration_minutes: 30, notes: "Strong communication, relevant staff-level experience, and immediate availability.")
  seed_meeting(candidate: jae, application: jae_application, created_by: recruiter, kind: "technical_interview", status: "completed", scheduled_at: 10.days.ago, duration_minutes: 90, notes: "Excellent accessibility judgment and pragmatic approach to React architecture.")
  seed_meeting(candidate: jae, application: jae_application, created_by: recruiter, kind: "client_interview", status: "completed", scheduled_at: 5.days.ago, duration_minutes: 60, notes: "Northstar panel agreed Jae would be a strong fit for the platform modernization team.")
  seed_meeting(candidate: jae, application: jae_application, created_by: recruiter, kind: "offer_call", status: "completed", scheduled_at: 12.hours.ago, duration_minutes: 30, notes: "Offer discussed after client approval. Candidate is enthusiastic and reviewing terms.")

  Task.find_or_initialize_by(created_by: recruiter, assigned_to: recruiter, title: "Send Sofía's presentation follow-up to Northstar").update!(due_on: Date.current, completed_at: nil)
  Task.find_or_initialize_by(created_by: recruiter, assigned_to: recruiter, title: "Prepare Diego's technical interview brief").update!(due_on: Date.tomorrow, completed_at: nil)
  Task.find_or_initialize_by(created_by: ops_lead, assigned_to: recruiter, title: "Confirm Jae's proposed start date").update!(due_on: 2.days.from_now.to_date, completed_at: nil)
end

puts "Seeded TurnKey Staffing with clients, jobs, sourcing briefs, job postings, pipeline history, meetings, and recruiter reminders."
