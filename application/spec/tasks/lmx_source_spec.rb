# frozen_string_literal: true

require "rails_helper"
require "rake"

RSpec.describe "lmx:source" do
  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("lmx:source")
  end

  let(:task) { Rake::Task["lmx:source"] }
  let(:result_class) { Struct.new(:observed_count, :source_run_id) }
  let(:job) { instance_double(AcquisitionCollectionJob) }

  around do |example|
    previous = ENV.to_h.slice("SOURCE", "SEARCH", "STRICT")
    ENV.delete("SOURCE")
    ENV.delete("STRICT")
    ENV["SEARCH"] = "Ruby"

    example.run
  ensure
    %w[SOURCE SEARCH STRICT].each { ENV.delete(_1) }
    previous.each { |key, value| ENV[key] = value }
  end

  before do
    task.reenable
    allow(AcquisitionCollectionJob).to receive(:new).and_return(job)
    allow(job).to receive(:perform) do |source_key, search:|
      raise "Work.ua HTTP request failed with status 403" if source_key == "work_ua"

      result_class.new(2, "source_run_#{source_key}")
    end
  end

  it "reports one source failure and continues the remaining sources" do
    expect { task.invoke }.to output(/"source": "work_ua".*"status": "failed"/m).to_stdout

    expect(job).to have_received(:perform).with("dou", search: "Ruby")
    expect(job).to have_received(:perform).with("djinni", search: "Ruby")
    expect(job).to have_received(:perform).with("work_ua", search: "Ruby")
    expect(job).to have_received(:perform).with("robota_ua", search: "Ruby")
    expect(job).to have_received(:perform).with("remoteok", search: "Ruby")
  end

  it "can fail the aggregate command when STRICT is enabled" do
    ENV["STRICT"] = "true"

    expect { task.invoke }
      .to output(/"status": "failed"/).to_stdout
      .and raise_error(SystemExit)
  end
end
