# frozen_string_literal: true

require "fileutils"
require "open3"
require "tmpdir"
require "zip"

class BackupRestoreJob < ApplicationJob
  include OpenProject::PostgresEnvironment

  queue_with_priority :above_normal

  def perform(restore_id:) # rubocop:disable Metrics/AbcSize
    @restore_id = restore_id
    @archive_path = Backups::RestoreProgress.upload_path(restore_id)

    progress("in_process", "validate", 15, "Validating backup archive")
    validate_archive!

    Dir.mktmpdir("openproject-restore-") do |directory|
      sql_path = File.join(directory, "openproject.sql")
      extract_database_dump!(sql_path)

      progress("in_process", "database", 35, "Restoring database")
      restore_database!(sql_path)

      progress("in_process", "database", 60, "Applying database migrations")
      migrate_database!

      progress("in_process", "attachments", 75, "Synchronizing attachments")
      restore_attachments!
    end

    progress("success", "finalize", 100, "Backup restored successfully")
  rescue StandardError => e
    progress("failure", current_step, current_percent, "Restore failed: #{e.message}")
    Rails.logger.error("Backup restore #{@restore_id} failed: #{e.full_message}")
    raise
  ensure
    FileUtils.rm_f(@archive_path) if @archive_path
  end

  private

  def validate_archive! # rubocop:disable Metrics/AbcSize
    raise "Backup upload was not found" unless File.file?(@archive_path)
    raise "Invalid ZIP signature" unless File.binread(@archive_path, 4).start_with?("PK")

    Zip::File.open(@archive_path) do |archive|
      raise "The archive does not contain openproject.sql" unless archive.find_entry("openproject.sql")

      archive.each do |entry|
        next if entry.name == "openproject.sql" || valid_attachment_entry?(entry.name)

        raise "Unexpected file in backup: #{entry.name}"
      end
    end
  rescue Zip::Error => e
    raise "Invalid backup archive: #{e.message}"
  end

  def extract_database_dump!(destination)
    Zip::File.open(@archive_path) do |archive|
      entry = archive.find_entry("openproject.sql")
      entry.get_input_stream { |input| IO.copy_stream(input, destination) }
    end
  end

  def restore_database!(sql_path)
    command = [
      "psql",
      "--no-psqlrc",
      "--set", "ON_ERROR_STOP=1",
      "--single-transaction",
      "--command", "DROP SCHEMA public CASCADE; CREATE SCHEMA public;",
      "--file", sql_path
    ]
    _output, error, status = Open3.capture3(pg_env, *command)
    raise "PostgreSQL rejected the backup: #{error.lines.last(5).join.strip}" unless status.success?
  ensure
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
  end

  def migrate_database!
    command = ["bundle", "exec", "rails", "db:migrate"]
    _output, error, status = Open3.capture3({ "RAILS_ENV" => Rails.env }, *command, chdir: Rails.root.to_s)
    raise "Database migrations failed: #{error.lines.last(10).join.strip}" unless status.success?
  ensure
    ActiveRecord::Base.connection_handler.clear_all_connections!(:all)
  end

  def restore_attachments! # rubocop:disable Metrics/AbcSize
    Zip::File.open(@archive_path) do |archive|
      attachment_entries = archive.select { |entry| valid_attachment_entry?(entry.name) }
      next if attachment_entries.empty?

      raise "Attachment restore requires local attachment storage" if OpenProject::Configuration.remote_storage?

      root = OpenProject::Configuration.attachments_storage_path
      attachment_entries.each do |entry|
        destination = root.join(entry.name).cleanpath
        raise "Unsafe attachment path" unless destination.to_s.start_with?("#{root.cleanpath}/")

        FileUtils.mkdir_p(destination.dirname)
        entry.get_input_stream { |input| IO.copy_stream(input, destination) }
      end
    end
  end

  def valid_attachment_entry?(name)
    %r{\Aattachment/file/\d+/[^/]+\z}.match?(name)
  end

  def progress(status, step, percent, message)
    @current_step = step
    @current_percent = percent
    Backups::RestoreProgress.update(
      @restore_id,
      status:,
      current_step: step,
      percent:,
      message:
    )
  end

  attr_reader :current_step, :current_percent
end
