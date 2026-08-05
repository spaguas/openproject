# frozen_string_literal: true

module ContractManagement
  class SyncAdjustmentIndicesJob < ApplicationJob
    queue_as :default

    def perform(project_id = nil)
      SyncAdjustmentIndicesService.new(project_id:).call
    end
  end
end
