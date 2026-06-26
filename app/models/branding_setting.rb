# frozen_string_literal: true

class BrandingSetting < ApplicationRecord
  mount_uploader :light_logo, OpenProject::Configuration.file_uploader
  mount_uploader :dark_logo, OpenProject::Configuration.file_uploader

  class << self
    def current
      RequestStore.fetch(:current_branding_setting) do
        order(Arel.sql("created_at DESC")).first
      end
    end

    def current_or_initialize
      current || new
    end
  end

  def digest
    updated_at.to_i
  end

  def logo_present?
    light_logo.present? || dark_logo.present?
  end

  %i[light_logo dark_logo].each do |name|
    define_method :"#{name}_path" do
      attachment = public_send(name)

      attachment.local_file.path if attachment.readable?
    end

    define_method :"remove_#{name}!" do
      super()
      save!
    end
  end
end
