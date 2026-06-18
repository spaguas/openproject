# frozen_string_literal: true

module API
  module V3
    module Grids
      module Widgets
        class KpiChartOptionsRepresenter < DefaultOptionsRepresenter
          property :kpiIds,
                   getter: ->(represented:, **) {
                     Array(represented["kpiIds"]).map(&:to_i)
                   }

          property :metric,
                   getter: ->(represented:, **) {
                     represented["metric"].presence || "progress"
                   }

          property :chartType,
                   getter: ->(represented:, **) {
                     represented["chartType"].presence || "horizontal_bar"
                   }
        end
      end
    end
  end
end
