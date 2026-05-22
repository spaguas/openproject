# frozen_string_literal: true

module ::Okr
  class BaseController < ::ApplicationController
    menu_item :okr

    before_action :find_project_by_project_id
    before_action :authorize
  end
end
