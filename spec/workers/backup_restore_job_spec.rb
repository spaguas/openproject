# frozen_string_literal: true

require "spec_helper"

RSpec.describe BackupRestoreJob do
  let(:restore_id) { SecureRandom.uuid }
  let(:archive_path) { Backups::RestoreProgress.upload_path(restore_id) }

  after do
    FileUtils.rm_f(archive_path)
    FileUtils.rm_f(Backups::RestoreProgress.path(restore_id))
  end

  it "validates and processes a native OpenProject backup" do
    Zip::File.open(archive_path, Zip::File::CREATE) do |zip|
      zip.get_output_stream("openproject.sql") { |stream| stream.write("-- database dump") }
    end
    Backups::RestoreProgress.start(id: restore_id, filename: "backup.zip")

    job = described_class.new
    allow(job).to receive(:restore_database!)
    allow(job).to receive(:restore_attachments!)

    job.perform(restore_id:)

    expect(Backups::RestoreProgress.read(restore_id)).to include(
      "status" => "success",
      "current_step" => "finalize",
      "percent" => 100
    )
  end

  it "rejects archives without a database dump" do
    Zip::File.open(archive_path, Zip::File::CREATE) do |zip|
      zip.get_output_stream("unexpected.txt") { |stream| stream.write("invalid") }
    end
    Backups::RestoreProgress.start(id: restore_id, filename: "backup.zip")

    expect { described_class.new.perform(restore_id:) }
      .to raise_error(RuntimeError, /does not contain openproject\.sql/)
  end
end
