# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "openproject-project_initiation_request"
  s.version     = "1.0.0"
  s.authors     = "SP-AGUAS"
  s.email       = "tecnologia@spaguas.sp.gov.br"
  s.summary     = "OpenProject Project Initiation Request"
  s.description = "Adds a Project Initiation Request workflow backed by native project copy services."
  s.license     = "GPLv3"

  s.files = Dir["{app,config,db,lib}/**/*"]
  s.metadata["rubygems_mfa_required"] = "true"
end
