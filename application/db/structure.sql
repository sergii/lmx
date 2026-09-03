--
-- PostgreSQL database dump
--

\restrict 09V5mGpKFQWdGgxYen3VnWXYuKRiuUH0ROC0Z2WZPEMbA4qsvKDyb5Jyu9puWfO

-- Dumped from database version 18.4 (Debian 18.4-1.pgdg13+1)
-- Dumped by pg_dump version 18.4 (Debian 18.4-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id uuid NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: application_stage_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.application_stage_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    application_id uuid NOT NULL,
    from_stage character varying,
    to_stage character varying NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    moved_by_id uuid
);

ALTER TABLE ONLY public.application_stage_events FORCE ROW LEVEL SECURITY;


--
-- Name: applications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.applications (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    job_id uuid NOT NULL,
    stage character varying DEFAULT 'sourced'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    sourced_by_id uuid,
    client_visible boolean DEFAULT false NOT NULL,
    client_portal_id character varying NOT NULL
);

ALTER TABLE ONLY public.applications FORCE ROW LEVEL SECURITY;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    action character varying NOT NULL,
    subject_type character varying NOT NULL,
    subject_id uuid NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.audit_events FORCE ROW LEVEL SECURITY;


--
-- Name: candidate_evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.candidate_evidences (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    source_type character varying NOT NULL,
    source_reference text,
    claim text NOT NULL,
    confidence numeric(4,3),
    observed_at timestamp(6) without time zone,
    provenance jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.candidate_evidences FORCE ROW LEVEL SECURITY;


--
-- Name: candidate_profile_version_evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.candidate_profile_version_evidences (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_profile_version_id uuid CONSTRAINT candidate_profile_version_e_candidate_profile_version__not_null NOT NULL,
    candidate_evidence_id uuid CONSTRAINT candidate_profile_version_eviden_candidate_evidence_id_not_null NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.candidate_profile_version_evidences FORCE ROW LEVEL SECURITY;


--
-- Name: candidate_profile_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.candidate_profile_versions (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    version_number integer NOT NULL,
    schema_version integer DEFAULT 1 NOT NULL,
    profile_data jsonb DEFAULT '{}'::jsonb NOT NULL,
    content_digest character varying NOT NULL,
    origin character varying NOT NULL,
    accepted_by_user_id uuid,
    accepted_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.candidate_profile_versions FORCE ROW LEVEL SECURITY;


--
-- Name: candidates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.candidates (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    first_name character varying NOT NULL,
    last_name character varying NOT NULL,
    email character varying,
    location character varying,
    time_zone character varying,
    source character varying,
    consent_status character varying DEFAULT 'unknown'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    linkedin_url character varying,
    github_url character varying,
    english_level character varying,
    salary_expectation character varying,
    availability character varying,
    notice_period character varying,
    work_authorization character varying,
    skills character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    tags character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    notes text,
    erased_at timestamp(6) without time zone,
    linked_user_id uuid
);

ALTER TABLE ONLY public.candidates FORCE ROW LEVEL SECURITY;


--
-- Name: client_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_companies (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.client_companies FORCE ROW LEVEL SECURITY;


--
-- Name: client_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.client_decisions (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    application_id uuid NOT NULL,
    decided_by_id uuid NOT NULL,
    decision character varying NOT NULL,
    note text,
    decided_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.client_decisions FORCE ROW LEVEL SECURITY;


--
-- Name: competencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competencies (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    name character varying NOT NULL,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.competencies FORCE ROW LEVEL SECURITY;


--
-- Name: competency_assessment_evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competency_assessment_evidences (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    competency_assessment_id uuid CONSTRAINT competency_assessment_evidenc_competency_assessment_id_not_null NOT NULL,
    evidence_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.competency_assessment_evidences FORCE ROW LEVEL SECURITY;


--
-- Name: competency_assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.competency_assessments (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    interview_assessment_id uuid NOT NULL,
    competency_id uuid NOT NULL,
    status character varying DEFAULT 'not_assessed'::character varying NOT NULL,
    ai_suggested_level character varying,
    ai_suggested_comment text,
    manual_level character varying,
    manual_comment text,
    final_level character varying,
    final_comment text,
    confidence numeric(4,3),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT competency_assessments_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT competency_assessments_status_check CHECK (((status)::text = ANY ((ARRAY['not_assessed'::character varying, 'insufficient_evidence'::character varying, 'weak'::character varying, 'demonstrated'::character varying])::text[])))
);

ALTER TABLE ONLY public.competency_assessments FORCE ROW LEVEL SECURITY;


--
-- Name: evidences; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.evidences (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    interview_id uuid NOT NULL,
    source_type character varying NOT NULL,
    source_reference character varying,
    claim text NOT NULL,
    confidence numeric(4,3),
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT evidences_confidence_check CHECK (((confidence IS NULL) OR ((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))),
    CONSTRAINT evidences_source_type_check CHECK (((source_type)::text = ANY ((ARRAY['transcript'::character varying, 'interviewer_note'::character varying, 'resume'::character varying, 'live_coding'::character varying, 'take_home_assignment'::character varying])::text[])))
);

ALTER TABLE ONLY public.evidences FORCE ROW LEVEL SECURITY;


--
-- Name: ingestion_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_records (
    id uuid DEFAULT uuidv7() NOT NULL,
    source_run_id uuid NOT NULL,
    raw_payload_id uuid NOT NULL,
    transport character varying NOT NULL,
    ingress_interface character varying,
    ingested_at timestamp(6) without time zone NOT NULL,
    collector_version character varying,
    adapter_version character varying,
    parser_version character varying,
    idempotency_key character varying NOT NULL,
    provenance jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: intelligence_match_assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.intelligence_match_assessments (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id character varying NOT NULL,
    candidate_profile_version_id character varying CONSTRAINT intelligence_match_assessme_candidate_profile_version__not_null NOT NULL,
    candidate_profile_content_digest character varying CONSTRAINT intelligence_match_assessme_candidate_profile_content__not_null NOT NULL,
    job_opening_id character varying NOT NULL,
    opening_evidence_cutoff timestamp(6) without time zone NOT NULL,
    opening_snapshot jsonb DEFAULT '{}'::jsonb NOT NULL,
    version_number integer NOT NULL,
    opportunity_score numeric(12,4),
    action_priority numeric(12,4),
    score_details jsonb DEFAULT '{}'::jsonb NOT NULL,
    strengths jsonb DEFAULT '[]'::jsonb NOT NULL,
    gaps jsonb DEFAULT '[]'::jsonb NOT NULL,
    risks jsonb DEFAULT '[]'::jsonb NOT NULL,
    recommendation text,
    interview_angles jsonb DEFAULT '[]'::jsonb NOT NULL,
    evidence_references jsonb DEFAULT '[]'::jsonb NOT NULL,
    scoring_policy_version character varying NOT NULL,
    processor_kind character varying,
    processor_key character varying,
    processor_version character varying,
    processor_model_name character varying,
    model_version character varying,
    generated_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.intelligence_match_assessments FORCE ROW LEVEL SECURITY;


--
-- Name: interview_assessments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interview_assessments (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    interview_id uuid NOT NULL,
    assessor_id uuid NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    overall_level character varying,
    rating integer,
    recommendation character varying,
    strong_sides text,
    improvement_areas text,
    overall_comments text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT interview_assessments_rating_check CHECK (((rating IS NULL) OR ((rating >= 1) AND (rating <= 5)))),
    CONSTRAINT interview_assessments_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'submitted'::character varying, 'reviewed'::character varying, 'approved'::character varying])::text[])))
);

ALTER TABLE ONLY public.interview_assessments FORCE ROW LEVEL SECURITY;


--
-- Name: interviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.interviews (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    application_id uuid,
    meeting_id uuid,
    created_by_id uuid NOT NULL,
    template_name character varying,
    language character varying,
    status character varying DEFAULT 'completed'::character varying NOT NULL,
    interviewer_notes text,
    transcript text,
    recording_url character varying,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT interviews_status_check CHECK (((status)::text = ANY ((ARRAY['draft'::character varying, 'completed'::character varying, 'cancelled'::character varying])::text[])))
);

ALTER TABLE ONLY public.interviews FORCE ROW LEVEL SECURITY;


--
-- Name: job_postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.job_postings (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    job_id uuid NOT NULL,
    channel character varying NOT NULL,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    title character varying,
    public_url character varying NOT NULL,
    content_snapshot text,
    published_at timestamp(6) without time zone,
    closed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.job_postings FORCE ROW LEVEL SECURITY;


--
-- Name: jobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.jobs (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    project_id uuid NOT NULL,
    title character varying NOT NULL,
    seniority character varying,
    technology_stack character varying,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    description text
);

ALTER TABLE ONLY public.jobs FORCE ROW LEVEL SECURITY;


--
-- Name: language_proficiencies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.language_proficiencies (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    language_code character varying(2) NOT NULL,
    level character varying(2) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.language_proficiencies FORCE ROW LEVEL SECURITY;


--
-- Name: market_catalog_companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_companies (
    id uuid DEFAULT uuidv7() NOT NULL,
    canonical_name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    website_url text,
    primary_domain character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: market_catalog_job_openings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_job_openings (
    id uuid DEFAULT uuidv7() NOT NULL,
    primary_company_id uuid,
    canonical_title character varying NOT NULL,
    normalized_title character varying NOT NULL,
    lifecycle_state character varying DEFAULT 'open'::character varying NOT NULL,
    first_seen_at timestamp(6) without time zone NOT NULL,
    last_seen_at timestamp(6) without time zone NOT NULL,
    closed_at timestamp(6) without time zone,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: market_catalog_job_postings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_job_postings (
    id uuid DEFAULT uuidv7() NOT NULL,
    job_opening_id uuid,
    publisher_company_id uuid,
    source_key character varying NOT NULL,
    external_id character varying,
    canonical_url text,
    canonical_url_digest character varying,
    application_url text,
    application_url_digest character varying,
    title character varying NOT NULL,
    normalized_title character varying NOT NULL,
    source_published_at timestamp(6) without time zone,
    source_updated_at timestamp(6) without time zone,
    first_seen_at timestamp(6) without time zone NOT NULL,
    last_confirmed_present_at timestamp(6) without time zone NOT NULL,
    missing_since timestamp(6) without time zone,
    lifecycle_state character varying DEFAULT 'present'::character varying NOT NULL,
    description_fingerprint character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT market_postings_identity_check CHECK ((((external_id IS NOT NULL) AND (btrim((external_id)::text) <> ''::text)) OR ((canonical_url IS NOT NULL) AND (btrim(canonical_url) <> ''::text)) OR ((application_url IS NOT NULL) AND (btrim(application_url) <> ''::text))))
);


--
-- Name: market_catalog_opening_parties; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_opening_parties (
    id uuid DEFAULT uuidv7() NOT NULL,
    job_opening_id uuid NOT NULL,
    company_id uuid,
    role character varying NOT NULL,
    party_label character varying,
    confidence numeric(4,3) DEFAULT 1.0 NOT NULL,
    evidence jsonb DEFAULT '[]'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT market_parties_confidence_check CHECK (((confidence >= (0)::numeric) AND (confidence <= (1)::numeric))),
    CONSTRAINT market_parties_identity_check CHECK (((company_id IS NOT NULL) OR ((party_label IS NOT NULL) AND (btrim((party_label)::text) <> ''::text))))
);


--
-- Name: market_catalog_posting_snapshots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_posting_snapshots (
    id uuid DEFAULT uuidv7() NOT NULL,
    job_posting_id uuid NOT NULL,
    source_observation_id uuid NOT NULL,
    observed_at timestamp(6) without time zone NOT NULL,
    presence_state character varying DEFAULT 'unknown'::character varying NOT NULL,
    title character varying,
    description_fingerprint character varying,
    source_published_at timestamp(6) without time zone,
    source_updated_at timestamp(6) without time zone,
    facts jsonb DEFAULT '{}'::jsonb NOT NULL,
    content_digest character varying NOT NULL,
    normalizer_key character varying NOT NULL,
    normalizer_version character varying NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT market_snapshots_content_digest_check CHECK (((content_digest)::text ~ '^[0-9a-f]{64}$'::text)),
    CONSTRAINT market_snapshots_presence_state_check CHECK (((presence_state)::text = ANY ((ARRAY['present'::character varying, 'missing'::character varying, 'explicit_closed'::character varying, 'unknown'::character varying])::text[])))
);


--
-- Name: market_catalog_resolution_decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.market_catalog_resolution_decisions (
    id uuid DEFAULT uuidv7() NOT NULL,
    decision_type character varying NOT NULL,
    job_posting_id uuid NOT NULL,
    from_job_opening_id uuid,
    to_job_opening_id uuid,
    confidence numeric(4,3) NOT NULL,
    evidence jsonb DEFAULT '[]'::jsonb NOT NULL,
    resolver_key character varying NOT NULL,
    resolver_version character varying NOT NULL,
    decided_at timestamp(6) without time zone NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT market_resolutions_confidence_check CHECK (((confidence >= (0)::numeric) AND (confidence <= (1)::numeric)))
);


--
-- Name: meetings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.meetings (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    candidate_id uuid NOT NULL,
    application_id uuid,
    created_by_id uuid NOT NULL,
    reminder_task_id uuid,
    kind character varying NOT NULL,
    status character varying DEFAULT 'scheduled'::character varying NOT NULL,
    sequence integer NOT NULL,
    scheduled_at timestamp(6) without time zone NOT NULL,
    duration_minutes integer,
    meeting_url character varying,
    notes text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.meetings FORCE ROW LEVEL SECURITY;


--
-- Name: memberships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.memberships (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    role character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    user_id uuid NOT NULL,
    client_company_id uuid
);


--
-- Name: organizations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.organizations (
    id uuid DEFAULT uuidv7() NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    onboarding_use_cases character varying[] DEFAULT '{}'::character varying[] NOT NULL
);


--
-- Name: platform_domain_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_domain_events (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    event_type character varying NOT NULL,
    event_version integer NOT NULL,
    aggregate_type character varying NOT NULL,
    aggregate_id character varying NOT NULL,
    aggregate_version integer NOT NULL,
    occurred_at timestamp(6) without time zone NOT NULL,
    effective_at timestamp(6) without time zone,
    principal character varying,
    credential character varying,
    actor character varying,
    executor character varying,
    interface character varying,
    client character varying,
    evidence_references jsonb DEFAULT '[]'::jsonb NOT NULL,
    correlation_id character varying,
    causation_id character varying,
    command_id character varying,
    idempotency_key character varying,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.platform_domain_events FORCE ROW LEVEL SECURITY;


--
-- Name: platform_inbox_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_inbox_messages (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    message_id character varying NOT NULL,
    command_id character varying NOT NULL,
    idempotency_key character varying NOT NULL,
    command_name character varying NOT NULL,
    command_version integer DEFAULT 1 NOT NULL,
    interface character varying NOT NULL,
    client character varying NOT NULL,
    principal character varying NOT NULL,
    credential character varying,
    actor character varying,
    executor character varying,
    correlation_id character varying,
    causation_id character varying,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    payload_digest character varying NOT NULL,
    payload_reference character varying,
    status character varying DEFAULT 'received'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    result jsonb,
    processing_error jsonb,
    received_at timestamp(6) without time zone NOT NULL,
    processing_started_at timestamp(6) without time zone,
    processed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.platform_inbox_messages FORCE ROW LEVEL SECURITY;


--
-- Name: platform_outbox_messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.platform_outbox_messages (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    domain_event_id uuid NOT NULL,
    message_type character varying NOT NULL,
    message_version integer DEFAULT 1 NOT NULL,
    destination character varying,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    attempt_count integer DEFAULT 0 NOT NULL,
    available_at timestamp(6) without time zone NOT NULL,
    publishing_started_at timestamp(6) without time zone,
    published_at timestamp(6) without time zone,
    last_error jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.platform_outbox_messages FORCE ROW LEVEL SECURITY;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    client_company_id uuid NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.projects FORCE ROW LEVEL SECURITY;


--
-- Name: raw_payloads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.raw_payloads (
    id uuid DEFAULT uuidv7() NOT NULL,
    source_run_id uuid NOT NULL,
    source_uri text,
    content_digest character varying NOT NULL,
    content_type character varying,
    encoding character varying,
    body bytea NOT NULL,
    byte_size bigint NOT NULL,
    captured_at timestamp(6) without time zone NOT NULL,
    idempotency_key character varying NOT NULL,
    provenance jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    user_agent character varying,
    ip_address character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT uuidv7() CONSTRAINT sessions_uuid_id_not_null NOT NULL,
    user_id uuid NOT NULL
);


--
-- Name: source_observations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_observations (
    id uuid DEFAULT uuidv7() NOT NULL,
    source_key character varying NOT NULL,
    transport character varying NOT NULL,
    external_id character varying,
    canonical_url text,
    observed_at timestamp(6) without time zone NOT NULL,
    content_digest character varying NOT NULL,
    idempotency_key character varying NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    source_run_id uuid NOT NULL,
    ingestion_record_id uuid NOT NULL,
    original_url text,
    source_published_at timestamp(6) without time zone,
    source_updated_at timestamp(6) without time zone,
    ingested_at timestamp(6) without time zone NOT NULL,
    presence_state character varying DEFAULT 'present'::character varying NOT NULL,
    parser_version character varying
);


--
-- Name: source_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.source_runs (
    id uuid DEFAULT uuidv7() NOT NULL,
    source_key character varying NOT NULL,
    transport character varying NOT NULL,
    status character varying DEFAULT 'running'::character varying NOT NULL,
    started_at timestamp(6) without time zone NOT NULL,
    finished_at timestamp(6) without time zone,
    fetched_count bigint,
    discovered_count bigint,
    observed_count bigint,
    run_key character varying,
    collector_version character varying,
    adapter_version character varying,
    parser_version character varying,
    idempotency_key character varying NOT NULL,
    error_class character varying,
    error_message text,
    error_details jsonb DEFAULT '{}'::jsonb NOT NULL,
    provenance jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sourcing_briefs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sourcing_briefs (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    job_id uuid NOT NULL,
    approved_by_id uuid,
    status character varying DEFAULT 'draft'::character varying NOT NULL,
    summary text,
    must_haves character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    nice_to_haves character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    exclusions character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    search_queries character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    location_preferences character varying[] DEFAULT '{}'::character varying[] NOT NULL,
    language_requirement character varying,
    interview_focus text,
    approved_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.sourcing_briefs FORCE ROW LEVEL SECURITY;


--
-- Name: tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tasks (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    created_by_id uuid NOT NULL,
    assigned_to_id uuid NOT NULL,
    title character varying NOT NULL,
    due_on date,
    completed_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.tasks FORCE ROW LEVEL SECURITY;


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    name character varying NOT NULL,
    email character varying NOT NULL,
    password_digest character varying NOT NULL,
    verified boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    id uuid DEFAULT uuidv7() CONSTRAINT users_uuid_id_not_null NOT NULL,
    onboarding_completed_at timestamp(6) without time zone
);


--
-- Name: workspace_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.workspace_invitations (
    id uuid DEFAULT uuidv7() NOT NULL,
    organization_id uuid NOT NULL,
    invited_by_id uuid NOT NULL,
    email character varying NOT NULL,
    role character varying DEFAULT 'recruiter'::character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    accepted_at timestamp(6) without time zone,
    revoked_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);

ALTER TABLE ONLY public.workspace_invitations FORCE ROW LEVEL SECURITY;


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: application_stage_events application_stage_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_stage_events
    ADD CONSTRAINT application_stage_events_pkey PRIMARY KEY (id);


--
-- Name: applications applications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT applications_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: candidate_evidences candidate_evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_evidences
    ADD CONSTRAINT candidate_evidences_pkey PRIMARY KEY (id);


--
-- Name: candidate_profile_version_evidences candidate_profile_version_evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_version_evidences
    ADD CONSTRAINT candidate_profile_version_evidences_pkey PRIMARY KEY (id);


--
-- Name: candidate_profile_versions candidate_profile_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_versions
    ADD CONSTRAINT candidate_profile_versions_pkey PRIMARY KEY (id);


--
-- Name: candidates candidates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidates
    ADD CONSTRAINT candidates_pkey PRIMARY KEY (id);


--
-- Name: client_companies client_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_companies
    ADD CONSTRAINT client_companies_pkey PRIMARY KEY (id);


--
-- Name: client_decisions client_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_decisions
    ADD CONSTRAINT client_decisions_pkey PRIMARY KEY (id);


--
-- Name: competencies competencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competencies
    ADD CONSTRAINT competencies_pkey PRIMARY KEY (id);


--
-- Name: competency_assessment_evidences competency_assessment_evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessment_evidences
    ADD CONSTRAINT competency_assessment_evidences_pkey PRIMARY KEY (id);


--
-- Name: competency_assessments competency_assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessments
    ADD CONSTRAINT competency_assessments_pkey PRIMARY KEY (id);


--
-- Name: evidences evidences_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT evidences_pkey PRIMARY KEY (id);


--
-- Name: ingestion_records ingestion_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_records
    ADD CONSTRAINT ingestion_records_pkey PRIMARY KEY (id);


--
-- Name: intelligence_match_assessments intelligence_match_assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.intelligence_match_assessments
    ADD CONSTRAINT intelligence_match_assessments_pkey PRIMARY KEY (id);


--
-- Name: interview_assessments interview_assessments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_assessments
    ADD CONSTRAINT interview_assessments_pkey PRIMARY KEY (id);


--
-- Name: interviews interviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT interviews_pkey PRIMARY KEY (id);


--
-- Name: job_postings job_postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_postings
    ADD CONSTRAINT job_postings_pkey PRIMARY KEY (id);


--
-- Name: jobs jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT jobs_pkey PRIMARY KEY (id);


--
-- Name: language_proficiencies language_proficiencies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_proficiencies
    ADD CONSTRAINT language_proficiencies_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_companies market_catalog_companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_companies
    ADD CONSTRAINT market_catalog_companies_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_job_openings market_catalog_job_openings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_job_openings
    ADD CONSTRAINT market_catalog_job_openings_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_job_postings market_catalog_job_postings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_job_postings
    ADD CONSTRAINT market_catalog_job_postings_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_opening_parties market_catalog_opening_parties_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_opening_parties
    ADD CONSTRAINT market_catalog_opening_parties_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_posting_snapshots market_catalog_posting_snapshots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_posting_snapshots
    ADD CONSTRAINT market_catalog_posting_snapshots_pkey PRIMARY KEY (id);


--
-- Name: market_catalog_resolution_decisions market_catalog_resolution_decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_resolution_decisions
    ADD CONSTRAINT market_catalog_resolution_decisions_pkey PRIMARY KEY (id);


--
-- Name: meetings meetings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT meetings_pkey PRIMARY KEY (id);


--
-- Name: memberships memberships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT memberships_pkey PRIMARY KEY (id);


--
-- Name: organizations organizations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.organizations
    ADD CONSTRAINT organizations_pkey PRIMARY KEY (id);


--
-- Name: platform_domain_events platform_domain_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_domain_events
    ADD CONSTRAINT platform_domain_events_pkey PRIMARY KEY (id);


--
-- Name: platform_inbox_messages platform_inbox_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_inbox_messages
    ADD CONSTRAINT platform_inbox_messages_pkey PRIMARY KEY (id);


--
-- Name: platform_outbox_messages platform_outbox_messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_outbox_messages
    ADD CONSTRAINT platform_outbox_messages_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: raw_payloads raw_payloads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_payloads
    ADD CONSTRAINT raw_payloads_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: source_observations source_observations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_observations
    ADD CONSTRAINT source_observations_pkey PRIMARY KEY (id);


--
-- Name: source_runs source_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_runs
    ADD CONSTRAINT source_runs_pkey PRIMARY KEY (id);


--
-- Name: sourcing_briefs sourcing_briefs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_briefs
    ADD CONSTRAINT sourcing_briefs_pkey PRIMARY KEY (id);


--
-- Name: tasks tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT tasks_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: workspace_invitations workspace_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT workspace_invitations_pkey PRIMARY KEY (id);


--
-- Name: idx_market_companies_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_companies_normalized_name ON public.market_catalog_companies USING btree (normalized_name);


--
-- Name: idx_market_companies_primary_domain; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_companies_primary_domain ON public.market_catalog_companies USING btree (primary_domain);


--
-- Name: idx_market_openings_company_title; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_openings_company_title ON public.market_catalog_job_openings USING btree (primary_company_id, normalized_title);


--
-- Name: idx_market_openings_lifecycle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_openings_lifecycle ON public.market_catalog_job_openings USING btree (lifecycle_state);


--
-- Name: idx_market_openings_primary_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_openings_primary_company ON public.market_catalog_job_openings USING btree (primary_company_id);


--
-- Name: idx_market_parties_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_parties_company ON public.market_catalog_opening_parties USING btree (company_id);


--
-- Name: idx_market_parties_opening; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_parties_opening ON public.market_catalog_opening_parties USING btree (job_opening_id);


--
-- Name: idx_market_parties_opening_role_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_parties_opening_role_company ON public.market_catalog_opening_parties USING btree (job_opening_id, role, company_id);


--
-- Name: idx_market_postings_lifecycle; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_postings_lifecycle ON public.market_catalog_job_postings USING btree (lifecycle_state);


--
-- Name: idx_market_postings_opening; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_postings_opening ON public.market_catalog_job_postings USING btree (job_opening_id);


--
-- Name: idx_market_postings_publisher; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_postings_publisher ON public.market_catalog_job_postings USING btree (publisher_company_id);


--
-- Name: idx_market_postings_source_apply_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_postings_source_apply_digest ON public.market_catalog_job_postings USING btree (source_key, application_url_digest) WHERE (application_url_digest IS NOT NULL);


--
-- Name: idx_market_postings_source_external; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_market_postings_source_external ON public.market_catalog_job_postings USING btree (source_key, external_id) WHERE (external_id IS NOT NULL);


--
-- Name: idx_market_postings_source_last_present; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_postings_source_last_present ON public.market_catalog_job_postings USING btree (source_key, last_confirmed_present_at);


--
-- Name: idx_market_postings_source_url_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_market_postings_source_url_digest ON public.market_catalog_job_postings USING btree (source_key, canonical_url_digest) WHERE (canonical_url_digest IS NOT NULL);


--
-- Name: idx_market_resolutions_from_opening; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_resolutions_from_opening ON public.market_catalog_resolution_decisions USING btree (from_job_opening_id);


--
-- Name: idx_market_resolutions_posting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_resolutions_posting ON public.market_catalog_resolution_decisions USING btree (job_posting_id);


--
-- Name: idx_market_resolutions_posting_decided; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_resolutions_posting_decided ON public.market_catalog_resolution_decisions USING btree (job_posting_id, decided_at);


--
-- Name: idx_market_resolutions_to_opening; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_resolutions_to_opening ON public.market_catalog_resolution_decisions USING btree (to_job_opening_id);


--
-- Name: idx_market_snapshots_posting; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_snapshots_posting ON public.market_catalog_posting_snapshots USING btree (job_posting_id);


--
-- Name: idx_market_snapshots_posting_observed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_market_snapshots_posting_observed ON public.market_catalog_posting_snapshots USING btree (job_posting_id, observed_at);


--
-- Name: idx_market_snapshots_source_observation; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_market_snapshots_source_observation ON public.market_catalog_posting_snapshots USING btree (source_observation_id);


--
-- Name: idx_on_application_id_occurred_at_720a253ef6; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_application_id_occurred_at_720a253ef6 ON public.application_stage_events USING btree (application_id, occurred_at);


--
-- Name: idx_on_competency_assessment_id_572fc25a91; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_competency_assessment_id_572fc25a91 ON public.competency_assessment_evidences USING btree (competency_assessment_id);


--
-- Name: idx_on_organization_id_candidate_id_status_496da638b8; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_candidate_id_status_496da638b8 ON public.interviews USING btree (organization_id, candidate_id, status);


--
-- Name: idx_on_organization_id_client_visible_stage_1788dde7af; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_client_visible_stage_1788dde7af ON public.applications USING btree (organization_id, client_visible, stage);


--
-- Name: idx_on_organization_id_job_id_public_url_875028656a; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_organization_id_job_id_public_url_875028656a ON public.job_postings USING btree (organization_id, job_id, public_url);


--
-- Name: idx_on_organization_id_language_code_level_82385f312f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_language_code_level_82385f312f ON public.language_proficiencies USING btree (organization_id, language_code, level);


--
-- Name: idx_on_organization_id_last_name_first_name_9f1d37241f; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_on_organization_id_last_name_first_name_9f1d37241f ON public.candidates USING btree (organization_id, last_name, first_name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_application_stage_events_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_application_stage_events_on_application_id ON public.application_stage_events USING btree (application_id);


--
-- Name: index_application_stage_events_on_moved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_application_stage_events_on_moved_by_id ON public.application_stage_events USING btree (moved_by_id);


--
-- Name: index_application_stage_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_application_stage_events_on_organization_id ON public.application_stage_events USING btree (organization_id);


--
-- Name: index_applications_on_candidate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_candidate_id ON public.applications USING btree (candidate_id);


--
-- Name: index_applications_on_candidate_id_and_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_applications_on_candidate_id_and_job_id ON public.applications USING btree (candidate_id, job_id);


--
-- Name: index_applications_on_client_portal_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_applications_on_client_portal_id ON public.applications USING btree (client_portal_id);


--
-- Name: index_applications_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_job_id ON public.applications USING btree (job_id);


--
-- Name: index_applications_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_organization_id ON public.applications USING btree (organization_id);


--
-- Name: index_applications_on_organization_id_and_job_id_and_stage; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_organization_id_and_job_id_and_stage ON public.applications USING btree (organization_id, job_id, stage);


--
-- Name: index_applications_on_sourced_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_applications_on_sourced_by_id ON public.applications USING btree (sourced_by_id);


--
-- Name: index_audit_events_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_organization_id ON public.audit_events USING btree (organization_id);


--
-- Name: index_audit_events_on_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_audit_events_on_subject ON public.audit_events USING btree (organization_id, subject_type, subject_id, occurred_at);


--
-- Name: index_candidate_evidences_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidate_evidences_on_organization_id ON public.candidate_evidences USING btree (organization_id);


--
-- Name: index_candidate_evidences_on_workspace_candidate_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidate_evidences_on_workspace_candidate_created ON public.candidate_evidences USING btree (organization_id, candidate_id, created_at);


--
-- Name: index_candidate_evidences_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidate_evidences_on_workspace_id ON public.candidate_evidences USING btree (organization_id, id);


--
-- Name: index_candidate_profile_version_evidences_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidate_profile_version_evidences_on_organization_id ON public.candidate_profile_version_evidences USING btree (organization_id);


--
-- Name: index_candidate_profile_versions_on_candidate_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidate_profile_versions_on_candidate_version ON public.candidate_profile_versions USING btree (candidate_id, version_number);


--
-- Name: index_candidate_profile_versions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidate_profile_versions_on_organization_id ON public.candidate_profile_versions USING btree (organization_id);


--
-- Name: index_candidate_profile_versions_on_workspace_candidate_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidate_profile_versions_on_workspace_candidate_version ON public.candidate_profile_versions USING btree (organization_id, candidate_id, version_number);


--
-- Name: index_candidate_profile_versions_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidate_profile_versions_on_workspace_id ON public.candidate_profile_versions USING btree (organization_id, id);


--
-- Name: index_candidates_on_erased_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidates_on_erased_at ON public.candidates USING btree (erased_at);


--
-- Name: index_candidates_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_candidates_on_organization_id ON public.candidates USING btree (organization_id);


--
-- Name: index_candidates_on_organization_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidates_on_organization_id_and_email ON public.candidates USING btree (organization_id, email) WHERE (email IS NOT NULL);


--
-- Name: index_candidates_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidates_on_workspace_id ON public.candidates USING btree (organization_id, id);


--
-- Name: index_candidates_on_workspace_linked_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_candidates_on_workspace_linked_user ON public.candidates USING btree (organization_id, linked_user_id) WHERE (linked_user_id IS NOT NULL);


--
-- Name: index_client_companies_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_companies_on_organization_id ON public.client_companies USING btree (organization_id);


--
-- Name: index_client_companies_on_organization_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_companies_on_organization_id_and_name ON public.client_companies USING btree (organization_id, name);


--
-- Name: index_client_decisions_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_client_decisions_on_application_id ON public.client_decisions USING btree (application_id);


--
-- Name: index_client_decisions_on_decided_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_decisions_on_decided_by_id ON public.client_decisions USING btree (decided_by_id);


--
-- Name: index_client_decisions_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_decisions_on_organization_id ON public.client_decisions USING btree (organization_id);


--
-- Name: index_client_decisions_on_organization_id_and_decided_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_client_decisions_on_organization_id_and_decided_at ON public.client_decisions USING btree (organization_id, decided_at);


--
-- Name: index_competencies_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competencies_on_organization_id ON public.competencies USING btree (organization_id);


--
-- Name: index_competencies_on_organization_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_competencies_on_organization_id_and_name ON public.competencies USING btree (organization_id, name);


--
-- Name: index_competency_assessment_evidence_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_competency_assessment_evidence_uniqueness ON public.competency_assessment_evidences USING btree (competency_assessment_id, evidence_id);


--
-- Name: index_competency_assessment_evidences_on_evidence_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competency_assessment_evidences_on_evidence_id ON public.competency_assessment_evidences USING btree (evidence_id);


--
-- Name: index_competency_assessment_evidences_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competency_assessment_evidences_on_organization_id ON public.competency_assessment_evidences USING btree (organization_id);


--
-- Name: index_competency_assessments_on_assessment_and_competency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_competency_assessments_on_assessment_and_competency ON public.competency_assessments USING btree (interview_assessment_id, competency_id);


--
-- Name: index_competency_assessments_on_competency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competency_assessments_on_competency_id ON public.competency_assessments USING btree (competency_id);


--
-- Name: index_competency_assessments_on_interview_assessment_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competency_assessments_on_interview_assessment_id ON public.competency_assessments USING btree (interview_assessment_id);


--
-- Name: index_competency_assessments_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_competency_assessments_on_organization_id ON public.competency_assessments USING btree (organization_id);


--
-- Name: index_evidences_on_interview_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evidences_on_interview_id ON public.evidences USING btree (interview_id);


--
-- Name: index_evidences_on_interview_id_and_source_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evidences_on_interview_id_and_source_type ON public.evidences USING btree (interview_id, source_type);


--
-- Name: index_evidences_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_evidences_on_organization_id ON public.evidences USING btree (organization_id);


--
-- Name: index_ingestion_records_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_ingestion_records_on_idempotency_key ON public.ingestion_records USING btree (idempotency_key);


--
-- Name: index_ingestion_records_on_raw_payload_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ingestion_records_on_raw_payload_id ON public.ingestion_records USING btree (raw_payload_id);


--
-- Name: index_ingestion_records_on_source_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ingestion_records_on_source_run_id ON public.ingestion_records USING btree (source_run_id);


--
-- Name: index_ingestion_records_on_source_run_id_and_ingested_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_ingestion_records_on_source_run_id_and_ingested_at ON public.ingestion_records USING btree (source_run_id, ingested_at);


--
-- Name: index_interview_assessments_on_assessor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_assessments_on_assessor_id ON public.interview_assessments USING btree (assessor_id);


--
-- Name: index_interview_assessments_on_interview_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_assessments_on_interview_id ON public.interview_assessments USING btree (interview_id);


--
-- Name: index_interview_assessments_on_interview_id_and_assessor_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_interview_assessments_on_interview_id_and_assessor_id ON public.interview_assessments USING btree (interview_id, assessor_id);


--
-- Name: index_interview_assessments_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_assessments_on_organization_id ON public.interview_assessments USING btree (organization_id);


--
-- Name: index_interview_assessments_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interview_assessments_on_organization_id_and_status ON public.interview_assessments USING btree (organization_id, status);


--
-- Name: index_interviews_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interviews_on_application_id ON public.interviews USING btree (application_id);


--
-- Name: index_interviews_on_application_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interviews_on_application_id_and_status ON public.interviews USING btree (application_id, status);


--
-- Name: index_interviews_on_candidate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interviews_on_candidate_id ON public.interviews USING btree (candidate_id);


--
-- Name: index_interviews_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interviews_on_created_by_id ON public.interviews USING btree (created_by_id);


--
-- Name: index_interviews_on_meeting_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_interviews_on_meeting_id ON public.interviews USING btree (meeting_id) WHERE (meeting_id IS NOT NULL);


--
-- Name: index_interviews_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_interviews_on_organization_id ON public.interviews USING btree (organization_id);


--
-- Name: index_job_postings_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_postings_on_job_id ON public.job_postings USING btree (job_id);


--
-- Name: index_job_postings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_postings_on_organization_id ON public.job_postings USING btree (organization_id);


--
-- Name: index_job_postings_on_organization_id_and_job_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_job_postings_on_organization_id_and_job_id_and_status ON public.job_postings USING btree (organization_id, job_id, status);


--
-- Name: index_jobs_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jobs_on_organization_id ON public.jobs USING btree (organization_id);


--
-- Name: index_jobs_on_organization_id_and_project_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jobs_on_organization_id_and_project_id_and_status ON public.jobs USING btree (organization_id, project_id, status);


--
-- Name: index_jobs_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_jobs_on_project_id ON public.jobs USING btree (project_id);


--
-- Name: index_language_proficiencies_on_candidate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_language_proficiencies_on_candidate_id ON public.language_proficiencies USING btree (candidate_id);


--
-- Name: index_language_proficiencies_on_candidate_id_and_language_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_language_proficiencies_on_candidate_id_and_language_code ON public.language_proficiencies USING btree (candidate_id, language_code);


--
-- Name: index_language_proficiencies_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_language_proficiencies_on_organization_id ON public.language_proficiencies USING btree (organization_id);


--
-- Name: index_match_assessments_on_workspace_candidate_opening_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_match_assessments_on_workspace_candidate_opening_created ON public.intelligence_match_assessments USING btree (organization_id, candidate_id, job_opening_id, created_at);


--
-- Name: index_match_assessments_on_workspace_candidate_opening_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_match_assessments_on_workspace_candidate_opening_version ON public.intelligence_match_assessments USING btree (organization_id, candidate_id, job_opening_id, version_number);


--
-- Name: index_match_assessments_on_workspace_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_match_assessments_on_workspace_id ON public.intelligence_match_assessments USING btree (organization_id, id);


--
-- Name: index_meetings_on_application_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_application_id ON public.meetings USING btree (application_id);


--
-- Name: index_meetings_on_application_kind_sequence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_meetings_on_application_kind_sequence ON public.meetings USING btree (application_id, kind, sequence) WHERE (application_id IS NOT NULL);


--
-- Name: index_meetings_on_candidate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_candidate_id ON public.meetings USING btree (candidate_id);


--
-- Name: index_meetings_on_candidate_id_and_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_candidate_id_and_scheduled_at ON public.meetings USING btree (candidate_id, scheduled_at);


--
-- Name: index_meetings_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_created_by_id ON public.meetings USING btree (created_by_id);


--
-- Name: index_meetings_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_organization_id ON public.meetings USING btree (organization_id);


--
-- Name: index_meetings_on_organization_id_and_scheduled_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_organization_id_and_scheduled_at ON public.meetings USING btree (organization_id, scheduled_at);


--
-- Name: index_meetings_on_reminder_task_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_meetings_on_reminder_task_id ON public.meetings USING btree (reminder_task_id);


--
-- Name: index_memberships_on_client_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_client_company_id ON public.memberships USING btree (client_company_id);


--
-- Name: index_memberships_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id ON public.memberships USING btree (organization_id);


--
-- Name: index_memberships_on_organization_id_and_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_memberships_on_organization_id_and_role ON public.memberships USING btree (organization_id, role);


--
-- Name: index_memberships_on_user_id_and_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_memberships_on_user_id_and_organization_id ON public.memberships USING btree (user_id, organization_id);


--
-- Name: index_organizations_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_organizations_on_slug ON public.organizations USING btree (slug);


--
-- Name: index_platform_events_on_aggregate_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_platform_events_on_aggregate_version ON public.platform_domain_events USING btree (organization_id, aggregate_type, aggregate_id, aggregate_version);


--
-- Name: index_platform_events_on_workspace_command; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_events_on_workspace_command ON public.platform_domain_events USING btree (organization_id, command_id);


--
-- Name: index_platform_events_on_workspace_type_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_events_on_workspace_type_time ON public.platform_domain_events USING btree (organization_id, event_type, occurred_at);


--
-- Name: index_platform_inbox_on_workspace_command; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_platform_inbox_on_workspace_command ON public.platform_inbox_messages USING btree (organization_id, command_id);


--
-- Name: index_platform_inbox_on_workspace_idempotency; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_platform_inbox_on_workspace_idempotency ON public.platform_inbox_messages USING btree (organization_id, idempotency_key);


--
-- Name: index_platform_inbox_on_workspace_message; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_platform_inbox_on_workspace_message ON public.platform_inbox_messages USING btree (organization_id, message_id);


--
-- Name: index_platform_inbox_on_workspace_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_inbox_on_workspace_status ON public.platform_inbox_messages USING btree (organization_id, status, received_at);


--
-- Name: index_platform_outbox_on_workspace_claim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_outbox_on_workspace_claim ON public.platform_outbox_messages USING btree (organization_id, status, publishing_started_at);


--
-- Name: index_platform_outbox_on_workspace_delivery; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_outbox_on_workspace_delivery ON public.platform_outbox_messages USING btree (organization_id, status, available_at);


--
-- Name: index_platform_outbox_on_workspace_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_platform_outbox_on_workspace_event ON public.platform_outbox_messages USING btree (organization_id, domain_event_id);


--
-- Name: index_profile_version_evidences_on_version_evidence; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_profile_version_evidences_on_version_evidence ON public.candidate_profile_version_evidences USING btree (candidate_profile_version_id, candidate_evidence_id);


--
-- Name: index_profile_version_evidences_on_workspace_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_profile_version_evidences_on_workspace_version ON public.candidate_profile_version_evidences USING btree (organization_id, candidate_profile_version_id);


--
-- Name: index_projects_on_client_company_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_client_company_id ON public.projects USING btree (client_company_id);


--
-- Name: index_projects_on_org_client_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_org_client_and_name ON public.projects USING btree (organization_id, client_company_id, name);


--
-- Name: index_projects_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_projects_on_organization_id ON public.projects USING btree (organization_id);


--
-- Name: index_raw_payloads_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_raw_payloads_on_idempotency_key ON public.raw_payloads USING btree (idempotency_key);


--
-- Name: index_raw_payloads_on_source_run_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_raw_payloads_on_source_run_id ON public.raw_payloads USING btree (source_run_id);


--
-- Name: index_raw_payloads_on_source_run_id_and_captured_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_raw_payloads_on_source_run_id_and_captured_at ON public.raw_payloads USING btree (source_run_id, captured_at);


--
-- Name: index_raw_payloads_on_source_run_id_and_content_digest; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_raw_payloads_on_source_run_id_and_content_digest ON public.raw_payloads USING btree (source_run_id, content_digest);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_source_observations_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_source_observations_on_idempotency_key ON public.source_observations USING btree (idempotency_key);


--
-- Name: index_source_observations_on_ingestion_record_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_observations_on_ingestion_record_id ON public.source_observations USING btree (ingestion_record_id);


--
-- Name: index_source_observations_on_source_external_observed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_observations_on_source_external_observed ON public.source_observations USING btree (source_key, external_id, observed_at);


--
-- Name: index_source_observations_on_source_key_and_observed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_observations_on_source_key_and_observed_at ON public.source_observations USING btree (source_key, observed_at);


--
-- Name: index_source_observations_on_source_run_id_and_observed_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_observations_on_source_run_id_and_observed_at ON public.source_observations USING btree (source_run_id, observed_at);


--
-- Name: index_source_runs_on_idempotency_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_source_runs_on_idempotency_key ON public.source_runs USING btree (idempotency_key);


--
-- Name: index_source_runs_on_source_key_and_started_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_runs_on_source_key_and_started_at ON public.source_runs USING btree (source_key, started_at);


--
-- Name: index_source_runs_on_source_status_finished; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_source_runs_on_source_status_finished ON public.source_runs USING btree (source_key, status, finished_at);


--
-- Name: index_sourcing_briefs_on_approved_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sourcing_briefs_on_approved_by_id ON public.sourcing_briefs USING btree (approved_by_id);


--
-- Name: index_sourcing_briefs_on_job_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_sourcing_briefs_on_job_id ON public.sourcing_briefs USING btree (job_id);


--
-- Name: index_sourcing_briefs_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sourcing_briefs_on_organization_id ON public.sourcing_briefs USING btree (organization_id);


--
-- Name: index_sourcing_briefs_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sourcing_briefs_on_organization_id_and_status ON public.sourcing_briefs USING btree (organization_id, status);


--
-- Name: index_tasks_on_assigned_to_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_assigned_to_id ON public.tasks USING btree (assigned_to_id);


--
-- Name: index_tasks_on_created_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_created_by_id ON public.tasks USING btree (created_by_id);


--
-- Name: index_tasks_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_organization_id ON public.tasks USING btree (organization_id);


--
-- Name: index_tasks_on_organization_id_and_completed_at_and_due_on; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_tasks_on_organization_id_and_completed_at_and_due_on ON public.tasks USING btree (organization_id, completed_at, due_on);


--
-- Name: index_users_on_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email ON public.users USING btree (email);


--
-- Name: index_users_on_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_id ON public.users USING btree (id);


--
-- Name: index_workspace_invitations_on_invited_by_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_invited_by_id ON public.workspace_invitations USING btree (invited_by_id);


--
-- Name: index_workspace_invitations_on_organization_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_organization_id ON public.workspace_invitations USING btree (organization_id);


--
-- Name: index_workspace_invitations_on_organization_id_and_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_workspace_invitations_on_organization_id_and_email ON public.workspace_invitations USING btree (organization_id, email);


--
-- Name: index_workspace_invitations_on_organization_id_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_workspace_invitations_on_organization_id_and_status ON public.workspace_invitations USING btree (organization_id, status);


--
-- Name: candidate_evidences fk_candidate_evidences_workspace_candidate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_evidences
    ADD CONSTRAINT fk_candidate_evidences_workspace_candidate FOREIGN KEY (organization_id, candidate_id) REFERENCES public.candidates(organization_id, id);


--
-- Name: candidates fk_candidates_linked_workspace_member; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidates
    ADD CONSTRAINT fk_candidates_linked_workspace_member FOREIGN KEY (linked_user_id, organization_id) REFERENCES public.memberships(user_id, organization_id);


--
-- Name: candidate_profile_version_evidences fk_profile_version_evidences_workspace_evidence; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_version_evidences
    ADD CONSTRAINT fk_profile_version_evidences_workspace_evidence FOREIGN KEY (organization_id, candidate_evidence_id) REFERENCES public.candidate_evidences(organization_id, id);


--
-- Name: candidate_profile_version_evidences fk_profile_version_evidences_workspace_version; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_version_evidences
    ADD CONSTRAINT fk_profile_version_evidences_workspace_version FOREIGN KEY (organization_id, candidate_profile_version_id) REFERENCES public.candidate_profile_versions(organization_id, id);


--
-- Name: candidate_profile_versions fk_profile_versions_accepting_workspace_member; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_versions
    ADD CONSTRAINT fk_profile_versions_accepting_workspace_member FOREIGN KEY (accepted_by_user_id, organization_id) REFERENCES public.memberships(user_id, organization_id);


--
-- Name: candidate_profile_versions fk_profile_versions_workspace_candidate; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_versions
    ADD CONSTRAINT fk_profile_versions_workspace_candidate FOREIGN KEY (organization_id, candidate_id) REFERENCES public.candidates(organization_id, id);


--
-- Name: language_proficiencies fk_rails_04c159e5d0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_proficiencies
    ADD CONSTRAINT fk_rails_04c159e5d0 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: meetings fk_rails_0842ae6524; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_0842ae6524 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: market_catalog_opening_parties fk_rails_0970411655; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_opening_parties
    ADD CONSTRAINT fk_rails_0970411655 FOREIGN KEY (job_opening_id) REFERENCES public.market_catalog_job_openings(id);


--
-- Name: competency_assessment_evidences fk_rails_0ccb9d4f75; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessment_evidences
    ADD CONSTRAINT fk_rails_0ccb9d4f75 FOREIGN KEY (competency_assessment_id) REFERENCES public.competency_assessments(id);


--
-- Name: client_decisions fk_rails_144478fa83; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_decisions
    ADD CONSTRAINT fk_rails_144478fa83 FOREIGN KEY (decided_by_id) REFERENCES public.users(id);


--
-- Name: market_catalog_job_postings fk_rails_1818d214a1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_job_postings
    ADD CONSTRAINT fk_rails_1818d214a1 FOREIGN KEY (publisher_company_id) REFERENCES public.market_catalog_companies(id);


--
-- Name: jobs fk_rails_1977e8b5a6; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT fk_rails_1977e8b5a6 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: interviews fk_rails_1f80a78ff5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_rails_1f80a78ff5 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: ingestion_records fk_rails_20fd14e314; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_records
    ADD CONSTRAINT fk_rails_20fd14e314 FOREIGN KEY (raw_payload_id) REFERENCES public.raw_payloads(id);


--
-- Name: interviews fk_rails_22b104629d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_rails_22b104629d FOREIGN KEY (candidate_id) REFERENCES public.candidates(id);


--
-- Name: competency_assessments fk_rails_238b3231b3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessments
    ADD CONSTRAINT fk_rails_238b3231b3 FOREIGN KEY (competency_id) REFERENCES public.competencies(id);


--
-- Name: job_postings fk_rails_286d997ec0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_postings
    ADD CONSTRAINT fk_rails_286d997ec0 FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- Name: evidences fk_rails_2d38c9a9dd; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT fk_rails_2d38c9a9dd FOREIGN KEY (interview_id) REFERENCES public.interviews(id);


--
-- Name: competency_assessment_evidences fk_rails_3357e6a30b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessment_evidences
    ADD CONSTRAINT fk_rails_3357e6a30b FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: platform_outbox_messages fk_rails_33dc25f12e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.platform_outbox_messages
    ADD CONSTRAINT fk_rails_33dc25f12e FOREIGN KEY (domain_event_id) REFERENCES public.platform_domain_events(id);


--
-- Name: candidate_profile_versions fk_rails_3a58eafdce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_versions
    ADD CONSTRAINT fk_rails_3a58eafdce FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: candidate_evidences fk_rails_3cc6d0dd56; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_evidences
    ADD CONSTRAINT fk_rails_3cc6d0dd56 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applications fk_rails_3df42c917d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_3df42c917d FOREIGN KEY (candidate_id) REFERENCES public.candidates(id);


--
-- Name: ingestion_records fk_rails_42f822a406; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_records
    ADD CONSTRAINT fk_rails_42f822a406 FOREIGN KEY (source_run_id) REFERENCES public.source_runs(id);


--
-- Name: language_proficiencies fk_rails_50b6a0fed1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.language_proficiencies
    ADD CONSTRAINT fk_rails_50b6a0fed1 FOREIGN KEY (candidate_id) REFERENCES public.candidates(id);


--
-- Name: interviews fk_rails_5307bca83b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_rails_5307bca83b FOREIGN KEY (meeting_id) REFERENCES public.meetings(id);


--
-- Name: tasks fk_rails_54673877db; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_54673877db FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: interview_assessments fk_rails_57c0b9e60d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_assessments
    ADD CONSTRAINT fk_rails_57c0b9e60d FOREIGN KEY (interview_id) REFERENCES public.interviews(id);


--
-- Name: market_catalog_posting_snapshots fk_rails_58192e4af2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_posting_snapshots
    ADD CONSTRAINT fk_rails_58192e4af2 FOREIGN KEY (job_posting_id) REFERENCES public.market_catalog_job_postings(id);


--
-- Name: applications fk_rails_618951e727; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_618951e727 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: memberships fk_rails_64267aab58; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_64267aab58 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: jobs fk_rails_6861f589d1; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.jobs
    ADD CONSTRAINT fk_rails_6861f589d1 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: evidences fk_rails_71d1de62d7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.evidences
    ADD CONSTRAINT fk_rails_71d1de62d7 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: applications fk_rails_72983108c3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_72983108c3 FOREIGN KEY (sourced_by_id) REFERENCES public.users(id);


--
-- Name: market_catalog_resolution_decisions fk_rails_72d0eac1e5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_resolution_decisions
    ADD CONSTRAINT fk_rails_72d0eac1e5 FOREIGN KEY (from_job_opening_id) REFERENCES public.market_catalog_job_openings(id);


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: workspace_invitations fk_rails_759aefbfd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_759aefbfd2 FOREIGN KEY (invited_by_id) REFERENCES public.users(id);


--
-- Name: candidate_profile_version_evidences fk_rails_75cd26c308; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidate_profile_version_evidences
    ADD CONSTRAINT fk_rails_75cd26c308 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: sourcing_briefs fk_rails_76a9476b2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_briefs
    ADD CONSTRAINT fk_rails_76a9476b2e FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- Name: tasks fk_rails_781b907909; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_781b907909 FOREIGN KEY (assigned_to_id) REFERENCES public.users(id);


--
-- Name: market_catalog_job_postings fk_rails_78ac82fbc3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_job_postings
    ADD CONSTRAINT fk_rails_78ac82fbc3 FOREIGN KEY (job_opening_id) REFERENCES public.market_catalog_job_openings(id);


--
-- Name: applications fk_rails_7a1f279622; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.applications
    ADD CONSTRAINT fk_rails_7a1f279622 FOREIGN KEY (job_id) REFERENCES public.jobs(id);


--
-- Name: meetings fk_rails_7af58b740b; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_7af58b740b FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: application_stage_events fk_rails_7ba7495aa5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_stage_events
    ADD CONSTRAINT fk_rails_7ba7495aa5 FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: market_catalog_resolution_decisions fk_rails_9597b5f4af; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_resolution_decisions
    ADD CONSTRAINT fk_rails_9597b5f4af FOREIGN KEY (to_job_opening_id) REFERENCES public.market_catalog_job_openings(id);


--
-- Name: memberships fk_rails_96efd5e8dc; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_96efd5e8dc FOREIGN KEY (client_company_id) REFERENCES public.client_companies(id);


--
-- Name: memberships fk_rails_99326fb65d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.memberships
    ADD CONSTRAINT fk_rails_99326fb65d FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: projects fk_rails_9aee26923d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_9aee26923d FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: competency_assessments fk_rails_9e5fccafce; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessments
    ADD CONSTRAINT fk_rails_9e5fccafce FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: interview_assessments fk_rails_a33f3bc160; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_assessments
    ADD CONSTRAINT fk_rails_a33f3bc160 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: tasks fk_rails_a362a150d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tasks
    ADD CONSTRAINT fk_rails_a362a150d3 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: competency_assessments fk_rails_af907e78d2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessments
    ADD CONSTRAINT fk_rails_af907e78d2 FOREIGN KEY (interview_assessment_id) REFERENCES public.interview_assessments(id);


--
-- Name: candidates fk_rails_b2429415c2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.candidates
    ADD CONSTRAINT fk_rails_b2429415c2 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: client_companies fk_rails_b3051fd0ed; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_companies
    ADD CONSTRAINT fk_rails_b3051fd0ed FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: job_postings fk_rails_b69136d982; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.job_postings
    ADD CONSTRAINT fk_rails_b69136d982 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: client_decisions fk_rails_bbd9679bd2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_decisions
    ADD CONSTRAINT fk_rails_bbd9679bd2 FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: competency_assessment_evidences fk_rails_bc70834e88; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competency_assessment_evidences
    ADD CONSTRAINT fk_rails_bc70834e88 FOREIGN KEY (evidence_id) REFERENCES public.evidences(id);


--
-- Name: audit_events fk_rails_be0ed9e37f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT fk_rails_be0ed9e37f FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: competencies fk_rails_c06603ffe4; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.competencies
    ADD CONSTRAINT fk_rails_c06603ffe4 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: raw_payloads fk_rails_c219d9df74; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.raw_payloads
    ADD CONSTRAINT fk_rails_c219d9df74 FOREIGN KEY (source_run_id) REFERENCES public.source_runs(id);


--
-- Name: meetings fk_rails_c26ce8563d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_c26ce8563d FOREIGN KEY (reminder_task_id) REFERENCES public.tasks(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: source_observations fk_rails_c629b57347; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_observations
    ADD CONSTRAINT fk_rails_c629b57347 FOREIGN KEY (source_run_id) REFERENCES public.source_runs(id);


--
-- Name: meetings fk_rails_c85bbe772c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_c85bbe772c FOREIGN KEY (candidate_id) REFERENCES public.candidates(id);


--
-- Name: application_stage_events fk_rails_c92285f3a5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_stage_events
    ADD CONSTRAINT fk_rails_c92285f3a5 FOREIGN KEY (moved_by_id) REFERENCES public.users(id);


--
-- Name: client_decisions fk_rails_ca21f8ad81; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.client_decisions
    ADD CONSTRAINT fk_rails_ca21f8ad81 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: meetings fk_rails_ca30ca7a34; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.meetings
    ADD CONSTRAINT fk_rails_ca30ca7a34 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: interviews fk_rails_d0ee6a8458; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_rails_d0ee6a8458 FOREIGN KEY (created_by_id) REFERENCES public.users(id);


--
-- Name: projects fk_rails_d5b3d7a917; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT fk_rails_d5b3d7a917 FOREIGN KEY (client_company_id) REFERENCES public.client_companies(id);


--
-- Name: market_catalog_job_openings fk_rails_d8e76a4cc2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_job_openings
    ADD CONSTRAINT fk_rails_d8e76a4cc2 FOREIGN KEY (primary_company_id) REFERENCES public.market_catalog_companies(id);


--
-- Name: sourcing_briefs fk_rails_e2172b36d3; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_briefs
    ADD CONSTRAINT fk_rails_e2172b36d3 FOREIGN KEY (approved_by_id) REFERENCES public.users(id);


--
-- Name: source_observations fk_rails_e35751ae57; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.source_observations
    ADD CONSTRAINT fk_rails_e35751ae57 FOREIGN KEY (ingestion_record_id) REFERENCES public.ingestion_records(id);


--
-- Name: application_stage_events fk_rails_e428f967f8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.application_stage_events
    ADD CONSTRAINT fk_rails_e428f967f8 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: market_catalog_opening_parties fk_rails_e8d2d60ff9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_opening_parties
    ADD CONSTRAINT fk_rails_e8d2d60ff9 FOREIGN KEY (company_id) REFERENCES public.market_catalog_companies(id);


--
-- Name: market_catalog_resolution_decisions fk_rails_edffbe4590; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.market_catalog_resolution_decisions
    ADD CONSTRAINT fk_rails_edffbe4590 FOREIGN KEY (job_posting_id) REFERENCES public.market_catalog_job_postings(id);


--
-- Name: sourcing_briefs fk_rails_f0535b0229; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sourcing_briefs
    ADD CONSTRAINT fk_rails_f0535b0229 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: interviews fk_rails_f2f89b52c5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interviews
    ADD CONSTRAINT fk_rails_f2f89b52c5 FOREIGN KEY (application_id) REFERENCES public.applications(id);


--
-- Name: workspace_invitations fk_rails_f93dc8da51; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.workspace_invitations
    ADD CONSTRAINT fk_rails_f93dc8da51 FOREIGN KEY (organization_id) REFERENCES public.organizations(id);


--
-- Name: interview_assessments fk_rails_fabd27b94a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.interview_assessments
    ADD CONSTRAINT fk_rails_fabd27b94a FOREIGN KEY (assessor_id) REFERENCES public.users(id);


--
-- Name: application_stage_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.application_stage_events ENABLE ROW LEVEL SECURITY;

--
-- Name: applications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: candidate_evidences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.candidate_evidences ENABLE ROW LEVEL SECURITY;

--
-- Name: candidate_profile_version_evidences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.candidate_profile_version_evidences ENABLE ROW LEVEL SECURITY;

--
-- Name: candidate_profile_versions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.candidate_profile_versions ENABLE ROW LEVEL SECURITY;

--
-- Name: candidates; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.candidates ENABLE ROW LEVEL SECURITY;

--
-- Name: client_companies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_companies ENABLE ROW LEVEL SECURITY;

--
-- Name: client_decisions; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.client_decisions ENABLE ROW LEVEL SECURITY;

--
-- Name: competencies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.competencies ENABLE ROW LEVEL SECURITY;

--
-- Name: competency_assessment_evidences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.competency_assessment_evidences ENABLE ROW LEVEL SECURITY;

--
-- Name: competency_assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.competency_assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: evidences; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.evidences ENABLE ROW LEVEL SECURITY;

--
-- Name: intelligence_match_assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.intelligence_match_assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: interview_assessments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.interview_assessments ENABLE ROW LEVEL SECURITY;

--
-- Name: interviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.interviews ENABLE ROW LEVEL SECURITY;

--
-- Name: job_postings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.job_postings ENABLE ROW LEVEL SECURITY;

--
-- Name: jobs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

--
-- Name: language_proficiencies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.language_proficiencies ENABLE ROW LEVEL SECURITY;

--
-- Name: meetings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.meetings ENABLE ROW LEVEL SECURITY;

--
-- Name: application_stage_events organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.application_stage_events USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: applications organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.applications USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: audit_events organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.audit_events USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: candidate_evidences organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.candidate_evidences USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: candidate_profile_version_evidences organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.candidate_profile_version_evidences USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: candidate_profile_versions organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.candidate_profile_versions USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: candidates organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.candidates USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: client_companies organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.client_companies USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: client_decisions organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.client_decisions USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: competencies organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.competencies USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: competency_assessment_evidences organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.competency_assessment_evidences USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: competency_assessments organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.competency_assessments USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: evidences organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.evidences USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: intelligence_match_assessments organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.intelligence_match_assessments USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: interview_assessments organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.interview_assessments USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: interviews organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.interviews USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: job_postings organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.job_postings USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: jobs organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.jobs USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: language_proficiencies organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.language_proficiencies USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: meetings organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.meetings USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: platform_domain_events organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.platform_domain_events USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: platform_inbox_messages organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.platform_inbox_messages USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: platform_outbox_messages organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.platform_outbox_messages USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: projects organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.projects USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: sourcing_briefs organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.sourcing_briefs USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: tasks organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.tasks USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: workspace_invitations organization_isolation; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY organization_isolation ON public.workspace_invitations USING ((organization_id = (current_setting('app.current_organization'::text, true))::uuid)) WITH CHECK ((organization_id = (current_setting('app.current_organization'::text, true))::uuid));


--
-- Name: platform_domain_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_domain_events ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_inbox_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_inbox_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: platform_outbox_messages; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.platform_outbox_messages ENABLE ROW LEVEL SECURITY;

--
-- Name: projects; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.projects ENABLE ROW LEVEL SECURITY;

--
-- Name: sourcing_briefs; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.sourcing_briefs ENABLE ROW LEVEL SECURITY;

--
-- Name: tasks; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

--
-- Name: workspace_invitations; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.workspace_invitations ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict 09V5mGpKFQWdGgxYen3VnWXYuKRiuUH0ROC0Z2WZPEMbA4qsvKDyb5Jyu9puWfO


SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260902200000'),
('20260902185000'),
('20260902100000'),
('20260902013000'),
('20260902011700'),
('20260902002000'),
('20260901194000'),
('20260729000000'),
('20260723211000'),
('20260723210000'),
('20260723200000'),
('20260723190000'),
('20260723180000'),
('20260723170000'),
('20260723160000'),
('20260723150000'),
('20260723140000'),
('20260723130000'),
('20260723120000'),
('20260723110000'),
('20260723100000'),
('20260723090000'),
('20260723080000'),
('20260723070000'),
('20260723060000'),
('20260723050000'),
('20260723040000'),
('20250801153828'),
('20250801153827');
