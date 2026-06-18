# frozen_string_literal: true

require "spec_helper"
require "support/permission_specs"

RSpec.describe Grids::Widgets::KpiChartsController, "permissions", type: :controller do # rubocop:disable RSpec/EmptyExampleGroup,RSpec/SpecFilePathFormat
  include PermissionSpecs

  check_permission_required_for("grids/widgets/kpi_charts#show", :view_kpis)
end
