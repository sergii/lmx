# frozen_string_literal: true

Rails.application.routes.draw do
  get  "sign_in", to: "sessions#new", as: :sign_in
  post "sign_in", to: "sessions#create"
  get  "sign_up", to: "users#new", as: :sign_up
  post "sign_up", to: "users#create"

  get "onboarding/profile", to: "onboarding#profile", as: :onboarding_profile
  patch "onboarding/profile", to: "onboarding#update_profile"
  get "onboarding/workspace", to: "onboarding#workspace", as: :onboarding_workspace
  post "onboarding/workspace", to: "onboarding#create_workspace"
  get "onboarding/use-cases", to: "onboarding#use_cases", as: :onboarding_use_cases
  patch "onboarding/use-cases", to: "onboarding#update_use_cases"
  get "onboarding/team", to: "onboarding#team", as: :onboarding_team
  post "onboarding/complete", to: "onboarding#complete", as: :complete_onboarding

  resources :sessions, only: [ :destroy ]
  resource :users, only: [ :destroy ]
  resources :organizations, only: %i[index new create]
  resource :organization_selection, only: :create
  resources :client_companies, only: %i[index create]
  resources :projects, only: %i[index create]
  resources :jobs, only: %i[index create show update] do
    resource :sourcing_brief, only: %i[create update]
  end
  resources :job_postings, only: %i[create update]
  resources :applications, only: :update
  get :pipeline, to: "pipeline#index"
  resources :candidates, only: %i[index new create show edit update]
  resources :interviews, only: %i[create show] do
    resources :assessments, only: :create, controller: "interview_assessments"
  end

  namespace :client do
    resources :applications, only: %i[index show] do
      resource :decision, only: :create, controller: "application_decisions"
    end
  end

  namespace :identity do
    resource :email_verification, only: [ :show, :create ]
    resource :password_reset,     only: [ :new, :edit, :create, :update ]
  end

  get :home, to: "dashboard#index"
  resources :tasks, only: %i[index create update]
  resources :meetings, only: %i[index create update]

  namespace :settings do
    resource :workspace, only: %i[show update]
    resource :team, only: %i[show create]
    resource :profile, only: [ :show, :update ]
    resource :password, only: [ :show, :update ]
    resource :email, only: [ :show, :update ]
    resources :sessions, only: [ :index ]
    inertia :appearance
  end

  root "dashboard#index"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
