# frozen_string_literal: true

namespace :lmx do
  namespace :config do
    desc "Validate LMX source and profile configuration"
    task validate: :environment do
      Lmx::Configuration.load!

      puts "LMX config valid: #{Acquisition::SourceRegistry.source_ids.length} sources, root=#{Lmx::Configuration.root}"
    end
  end
end
