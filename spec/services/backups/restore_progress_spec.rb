# frozen_string_literal: true

require "spec_helper"

RSpec.describe Backups::RestoreProgress do
  let(:restore_id) { SecureRandom.uuid }

  after do
    FileUtils.rm_f(described_class.path(restore_id))
    FileUtils.rm_f(described_class.upload_path(restore_id))
  end

  it "persists progress independently from the database" do
    described_class.start(id: restore_id, filename: "backup.zip")
    described_class.update(restore_id, status: "in_process", current_step: "database", percent: 35)

    expect(described_class.read(restore_id)).to include(
      "status" => "in_process",
      "current_step" => "database",
      "percent" => 35,
      "filename" => "backup.zip"
    )
  end

  it "rejects unsafe restore identifiers" do
    expect { described_class.path("../../etc/passwd") }.to raise_error(ArgumentError)
  end
end
