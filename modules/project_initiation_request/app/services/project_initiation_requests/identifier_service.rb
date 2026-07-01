# frozen_string_literal: true

module ProjectInitiationRequests
  class IdentifierService
    def self.call(title, relation:)
      new(title, relation: relation).call
    end

    def initialize(title, relation:)
      @title = title
      @relation = relation
    end

    def call
      candidate = base_identifier
      suffix = 0

      while relation.exists?(identifier: candidate)
        suffix += 1
        candidate = "#{base_identifier}-#{suffix}"
      end

      candidate
    end

    private

    attr_reader :title, :relation

    def base_identifier
      title
        .to_s
        .parameterize
        .presence || "project"
    end
  end
end
