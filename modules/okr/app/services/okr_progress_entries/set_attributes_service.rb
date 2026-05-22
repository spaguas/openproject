# frozen_string_literal: true

module OkrProgressEntries
  class SetAttributesService < ::BaseServices::SetAttributes
    private

    def set_default_attributes(_params)
      model.change_by_system do
        model.author = user
        model.recorded_on ||= Date.current
      end
    end
  end
end
