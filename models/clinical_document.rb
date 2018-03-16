class ClinicalDocument < ActiveRecord::Base
  belongs_to :patient
  belongs_to :visit
  has_many :document_versions
  has_many :current_documents
  has_many :documents

  def current_version
    return document_versions.last
  end

  def archived_image
    current_version.archived_image
  end


  def latest
    document_documents.order("dv.version_number DESC").first
  end


end
