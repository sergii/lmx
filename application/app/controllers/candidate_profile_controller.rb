# frozen_string_literal: true

class CandidateProfileController < InertiaController
  before_action :require_current_organization

  def show
    render inertia: "profile/show", props: CandidateProfileQuery.call(
      user_id: Current.user.typed_id
    )
  end

  def update
    candidate = TalentProfile::Api.fetch_candidate_for_user(user_id: Current.user.typed_id)
    TalentProfile::Api.create_profile_version(
      candidate_id: candidate.fetch(:id),
      profile: profile_params,
      origin: "manual"
    )

    redirect_to profile_path, status: :see_other, notice: "Profile version created"
  rescue TalentProfile::Api::NotFound
    head :not_found
  rescue ArgumentError, ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end

  private

  def profile_params
    value = params.require(:profile)
    raise ArgumentError, "profile must be an object" unless value.respond_to?(:to_unsafe_h)

    value.to_unsafe_h
  end
end
