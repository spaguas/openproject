# frozen_string_literal: true

require "json"
require "fileutils"

module Backups
  class RestoreProgress
    STEPS = %w[upload validate database attachments finalize].freeze

    class << self
      def start(id:, filename:)
        write(id, status: "queued", current_step: "upload", percent: 5, filename:, message: "Upload received")
      end

      def update(id, **attributes)
        write(id, read(id).merge(attributes.stringify_keys))
      end

      def read(id)
        JSON.parse(File.read(path(id)))
      rescue Errno::ENOENT, JSON::ParserError
        {}
      end

      def path(id)
        root.join("#{safe_id(id)}.json")
      end

      def upload_path(id)
        root.join("#{safe_id(id)}.zip")
      end

      def root
        Rails.root.join("tmp/backup-restores").tap { FileUtils.mkdir_p(it, mode: 0o700) }
      end

      private

      def write(id, attributes)
        payload = attributes.stringify_keys.merge(
          "id" => safe_id(id),
          "steps" => STEPS,
          "updated_at" => Time.current.iso8601
        )
        temporary = "#{path(id)}.tmp"
        File.open(temporary, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
          file.write(JSON.generate(payload))
        end
        File.rename(temporary, path(id))
        payload
      end

      def safe_id(id)
        value = id.to_s
        raise ArgumentError, "Invalid restore identifier" unless /\A[0-9a-f-]{36}\z/.match?(value)

        value
      end
    end
  end
end
