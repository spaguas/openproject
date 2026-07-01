# frozen_string_literal: true

module Projects
  module Settings
    class GeoreferenceForm < ApplicationForm
      form do |f|
        f.text_field(
          name: :latitude,
          label: attribute_name(:latitude),
          caption: I18n.t("projects.settings.georeference.latitude_caption")
        )

        f.text_field(
          name: :longitude,
          label: attribute_name(:longitude),
          caption: I18n.t("projects.settings.georeference.longitude_caption")
        )
      end
    end
  end
end
