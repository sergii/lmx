# frozen_string_literal: true

# Rails 8 discovers application tasks before environment-specific configuration
# requires test gems. Load Enforceable's task explicitly so
# `RAILS_ENV=test bin/rails enforceable:verify` works in local development and
# CI, while production never exposes the verification task.
if Rails.env.test? || ENV["RAILS_ENV"] == "test"
  require "enforceable"
  load File.join(Gem::Specification.find_by_name("enforceable").gem_dir, "lib/tasks/enforceable.rake")
end
