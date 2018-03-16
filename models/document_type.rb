class DocumentType < ActiveRecord::Base
  belongs_to :document_class
  validates_uniqueness_of :code

	def self.by_code(type_code)
    DocumentType.where(:code => type_code).first
  end
end