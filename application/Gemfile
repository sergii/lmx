source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.6"
gem "typeid", "~> 0.2"
gem "action_policy", "~> 0.7"
gem "alba", "~> 3.10"
gem "alba-inertia", "~> 0.1.4"
gem "puma", ">= 5.0"
gem "jbuilder"
gem "bcrypt", "~> 3.1.7"
gem "json_schemer"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"
gem "bootsnap", require: false
gem "kamal", require: false, group: [ :development, :deploy ]
gem "thruster", require: false
gem "rails_vite"
gem "inertia_rails", "~> 3.21"
gem "authentication-zero"
gem "typelizer"
gem "opentelemetry-api", "~> 1.11"
gem "opentelemetry-sdk", "~> 1.13", require: false
gem "opentelemetry-exporter-otlp", "~> 0.34.1", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rspec-rails", "~> 8.0"
  gem "packwerk", "~> 3.3", require: false
  gem "packwerk-extensions", "~> 0.3", require: false
end

group :development do
  gem "web-console"
  gem "letter_opener"
end

group :test do
  gem "capybara"
  gem "capybara-lockstep"
  gem "selenium-webdriver"
  gem "enforceable",
    github: "sergii/enforceable",
    ref: "fb068be2f17facedee92a1dc94c65199d1eadd93",
    require: false
end
