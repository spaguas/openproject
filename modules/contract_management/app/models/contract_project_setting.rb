# frozen_string_literal: true

class ContractProjectSetting < ApplicationRecord
  belongs_to :project

  validates :commitment_consumption_alert_percentage,
            numericality: { greater_than: 0, less_than_or_equal_to: 100 }

  def self.for(project)
    find_or_initialize_by(project:) do |setting|
      setting.commitment_consumption_alert_percentage = 80
    end
  end
end
