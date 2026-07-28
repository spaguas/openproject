# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "openproject-contract_management"
  spec.version = "1.0.0"
  spec.authors = ["SP-AGUAS"]
  spec.email = ["tecnologia@spaguas.sp.gov.br"]
  spec.summary = "Public contract management for OpenProject"
  spec.description = "Tracks public contracts, measurements, invoices, amendments, responsibilities and bank orders."
  spec.license = "GPLv3"
  spec.files = Dir["{app,config,db,lib}/**/*"]
  spec.metadata["rubygems_mfa_required"] = "true"
end
