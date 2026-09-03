require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"

Bundler.require(*Rails.groups)

module Lmx
  class Application < Rails::Application
    config.load_defaults 8.1
    config.autoload_lib(ignore: %w[assets tasks])

    # Treat the conventional directories inside every pack as Rails autoload
    # roots, matching the constants used before the strangler migration.
    config.paths.add "packs", glob: "*/app/{*,*/concerns}", eager_load: true

    # PostgreSQL RLS policies, functions, and other database-enforced security
    # objects are not represented by schema.rb.
    config.active_record.schema_format = :sql

    config.generators.system_tests = nil
  end
end
