# frozen_string_literal: true

require "fileutils"
require "rails_helper"
require "tmpdir"

RSpec.describe Lmx::Configuration, type: :model do
  let(:fixture_root) { Rails.root.join("spec/fixtures/lmx_root").expand_path }

  after do
    described_class.load!(root: fixture_root)
  end

  it "loads and freezes source and profile configuration from a validated root" do
    configuration = described_class.load!(root: fixture_root)

    expect(configuration.root).to eq(fixture_root)
    expect(configuration.sources.fetch("sources").first.fetch("id")).to eq("dou")
    expect(configuration.default_profile.dig("source_priorities", "dou", "weight")).to eq(100)
    expect(configuration.sources).to be_frozen
    expect(configuration.sources.fetch("sources")).to be_frozen
    expect(configuration.default_profile).to be_frozen
  end

  it "rejects a source registry that violates its JSON Schema" do
    with_config_copy do |root|
      root.join("config/sources.yml").write(<<~YAML)
        version: 1
        sources:
          - id: dou
            name: DOU Jobs
            enabled: true
            kind: job_board
      YAML

      expect { described_class.load!(root:) }
        .to raise_error(described_class::InvalidDocument, /sources\.yml/)
    end
  end

  it "rejects a ranking profile that violates its JSON Schema" do
    with_config_copy do |root|
      root.join("config/profiles/default.yml").write(<<~YAML)
        version: 1
        source_priorities:
          dou: { lane: local_fast, weight: 101 }
        ranking: {}
        policies: {}
      YAML

      expect { described_class.load!(root:) }
        .to raise_error(described_class::InvalidDocument, /default\.yml/)
    end
  end

  it "fails fast when an explicit configuration root is incomplete" do
    Dir.mktmpdir("lmx-config-missing") do |directory|
      expect { described_class.load!(root: directory) }
        .to raise_error(described_class::RootNotFound, /missing/)
    end
  end

  def with_config_copy
    Dir.mktmpdir("lmx-config") do |directory|
      root = Pathname.new(directory)
      FileUtils.cp_r(fixture_root.join("config"), root)
      yield root
    end
  end
end
