# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_23_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "application_stage_events", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "application_id", null: false
    t.datetime "created_at", null: false
    t.string "from_stage"
    t.uuid "moved_by_id"
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.string "to_stage", null: false
    t.datetime "updated_at", null: false
    t.index ["application_id", "occurred_at"], name: "idx_on_application_id_occurred_at_720a253ef6"
    t.index ["application_id"], name: "index_application_stage_events_on_application_id"
    t.index ["moved_by_id"], name: "index_application_stage_events_on_moved_by_id"
    t.index ["organization_id"], name: "index_application_stage_events_on_organization_id"
  end

  create_table "applications", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "candidate_id", null: false
    t.string "client_portal_id", null: false
    t.boolean "client_visible", default: false, null: false
    t.datetime "created_at", null: false
    t.uuid "job_id", null: false
    t.uuid "organization_id", null: false
    t.uuid "sourced_by_id"
    t.string "stage", default: "sourced", null: false
    t.datetime "updated_at", null: false
    t.index ["candidate_id", "job_id"], name: "index_applications_on_candidate_id_and_job_id", unique: true
    t.index ["candidate_id"], name: "index_applications_on_candidate_id"
    t.index ["client_portal_id"], name: "index_applications_on_client_portal_id", unique: true
    t.index ["job_id"], name: "index_applications_on_job_id"
    t.index ["organization_id", "client_visible", "stage"], name: "idx_on_organization_id_client_visible_stage_1788dde7af"
    t.index ["organization_id", "job_id", "stage"], name: "index_applications_on_organization_id_and_job_id_and_stage"
    t.index ["organization_id"], name: "index_applications_on_organization_id"
    t.index ["sourced_by_id"], name: "index_applications_on_sourced_by_id"
  end

  create_table "audit_events", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "action", null: false
    t.datetime "created_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "subject_id", null: false
    t.string "subject_type", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "subject_type", "subject_id", "occurred_at"], name: "index_audit_events_on_subject"
    t.index ["organization_id"], name: "index_audit_events_on_organization_id"
  end

  create_table "candidates", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.string "availability"
    t.string "consent_status", default: "unknown", null: false
    t.datetime "created_at", null: false
    t.string "email"
    t.string "english_level"
    t.datetime "erased_at"
    t.string "first_name", null: false
    t.string "github_url"
    t.string "last_name", null: false
    t.string "linkedin_url"
    t.string "location"
    t.text "notes"
    t.string "notice_period"
    t.uuid "organization_id", null: false
    t.string "salary_expectation"
    t.string "skills", default: [], null: false, array: true
    t.string "source"
    t.string "tags", default: [], null: false, array: true
    t.string "time_zone"
    t.datetime "updated_at", null: false
    t.string "work_authorization"
    t.index ["erased_at"], name: "index_candidates_on_erased_at"
    t.index ["organization_id", "email"], name: "index_candidates_on_organization_id_and_email", unique: true, where: "(email IS NOT NULL)"
    t.index ["organization_id", "last_name", "first_name"], name: "idx_on_organization_id_last_name_first_name_9f1d37241f"
    t.index ["organization_id"], name: "index_candidates_on_organization_id"
  end

  create_table "client_companies", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "name"], name: "index_client_companies_on_organization_id_and_name", unique: true
    t.index ["organization_id"], name: "index_client_companies_on_organization_id"
  end

  create_table "jobs", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.uuid "project_id", null: false
    t.string "seniority"
    t.string "status", default: "draft", null: false
    t.string "technology_stack"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id", "project_id", "status"], name: "index_jobs_on_organization_id_and_project_id_and_status"
    t.index ["organization_id"], name: "index_jobs_on_organization_id"
    t.index ["project_id"], name: "index_jobs_on_project_id"
  end

  create_table "memberships", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.uuid "client_company_id"
    t.datetime "created_at", null: false
    t.uuid "organization_id", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["client_company_id"], name: "index_memberships_on_client_company_id"
    t.index ["organization_id", "role"], name: "index_memberships_on_organization_id_and_role"
    t.index ["organization_id"], name: "index_memberships_on_organization_id"
    t.index ["user_id", "organization_id"], name: "index_memberships_on_user_id_and_organization_id", unique: true
  end

  create_table "organizations", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_organizations_on_slug", unique: true
  end

  create_table "projects", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.uuid "client_company_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["client_company_id"], name: "index_projects_on_client_company_id"
    t.index ["organization_id", "client_company_id", "name"], name: "index_projects_on_org_client_and_name", unique: true
    t.index ["organization_id"], name: "index_projects_on_organization_id"
  end

  create_table "sessions", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.boolean "verified", default: false, null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["id"], name: "index_users_on_id", unique: true
  end

  add_foreign_key "application_stage_events", "applications"
  add_foreign_key "application_stage_events", "organizations"
  add_foreign_key "application_stage_events", "users", column: "moved_by_id"
  add_foreign_key "applications", "candidates"
  add_foreign_key "applications", "jobs"
  add_foreign_key "applications", "organizations"
  add_foreign_key "applications", "users", column: "sourced_by_id"
  add_foreign_key "audit_events", "organizations"
  add_foreign_key "candidates", "organizations"
  add_foreign_key "client_companies", "organizations"
  add_foreign_key "jobs", "organizations"
  add_foreign_key "jobs", "projects"
  add_foreign_key "memberships", "client_companies"
  add_foreign_key "memberships", "organizations"
  add_foreign_key "memberships", "users"
  add_foreign_key "projects", "client_companies"
  add_foreign_key "projects", "organizations"
  add_foreign_key "sessions", "users"
end
