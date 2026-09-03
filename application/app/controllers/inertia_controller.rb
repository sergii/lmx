# frozen_string_literal: true

class InertiaController < ApplicationController
  include ActionPolicy::Controller
  include Alba::Inertia::Controller

  authorize :user, through: :current_user
  authorize :membership, through: :current_membership
  inertia_config default_render: true
  inertia_share auth: {
        user: -> { Current.user && Current.user.slice(:name, :email, :verified, :created_at, :updated_at).merge(id: Current.user.typed_id) },
        session: -> { Current.session && { id: Current.session.typed_id } }
      }
  inertia_share organization: -> {
    Current.organization && {
      name: Current.organization.name,
      slug: Current.organization.slug,
      logo_url: (rails_blob_url(Current.organization.logo) if Current.organization.logo.attached?)
    }
  }
  inertia_share portal: -> {
    { client: Current.membership&.client_portal? || false }
  }
  inertia_share permissions: -> {
    { workspace_admin: Current.membership&.workspace_admin? || false }
  }
end
