# frozen_string_literal: true

module Homescreen
  class ProjectOverviewComponent < ApplicationComponent
    include IconsHelper
    include Redmine::I18n

    attr_reader :overview

    def initialize(overview:)
      super

      @overview = overview
    end

    def summary
      overview.summary
    end

    def render?
      overview.visible?
    end
  end
end
