# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-okr"
  s.version     = "1.0.0"
  s.authors     = "OpenProject GmbH"
  s.email       = "info@openproject.com"
  s.summary     = "OpenProject OKR"
  s.description = "Provides OKR and KPI progress tracking."
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
