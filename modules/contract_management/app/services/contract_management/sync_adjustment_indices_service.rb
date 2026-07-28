# frozen_string_literal: true

module ContractManagement
  class SyncAdjustmentIndicesService
    HISTORY_YEARS = 3
    SOURCE = "Banco Central do Brasil — SGS"

    def initialize(client: BcbSgsClient.new, today: Date.current, project_id: nil)
      @client = client
      @today = today
      @project_id = project_id
    end

    def call
      synchronized = 0
      failed = []

      index_types.find_each do |index_type|
        synchronize_type(index_type)
        index_type.update!(last_synced_at: Time.current, last_sync_error: nil)
        synchronized += 1
      rescue StandardError => e
        index_type&.update_columns(last_sync_error: e.message)
        failed << { index: index_type&.name, project_id: index_type&.project_id, error: e.message }
        Rails.logger.error("[ContractManagement] Failed to synchronize adjustment index: #{failed.last.inspect}")
      end

      { synchronized:, failed: }
    end

    private

    attr_reader :client, :today, :project_id

    def index_types
      relation = ContractAdjustmentIndexType.active
      project_id ? relation.where(project_id:) : relation
    end

    def synchronize_type(index_type)
      from = Date.new(today.year - HISTORY_YEARS, 1, 1)
      values = client.values(series_code: index_type.external_series_code, from:, to: today)

      values.each { |entry| synchronize_month(index_type, entry) }
    end

    def synchronize_month(index_type, entry)
      date = entry.fetch(:date)
      record = index_type.adjustment_indices.find_or_initialize_by(year: date.year, month: date.month)
      record.assign_attributes(
        project_id: index_type.project_id,
        name: index_type.name,
        percentage: entry.fetch(:value),
        periodicity: "monthly",
        external_series_code: index_type.external_series_code,
        source: SOURCE,
        last_synced_at: Time.current
      )
      record.save!
    end
  end
end
