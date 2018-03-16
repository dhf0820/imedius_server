
class DocumentVersion < ActiveRecord::Base
  belongs_to :clinical_document
  belongs_to :document_type
  has_one :archived_image


  # has_one :description_id
  # has_one :image_id
  has_many :current_documents

  attr_accessor :document_source_id
  attr_accessor :document_source_name

  def self.for_version(doc_id, version)
    self.where('clinical_document_id = ? and version_number = ?', doc_id, version).first
  end

  # TODO need to verify that the latest document received wil always be the actual latest valid document

  def self.current_version(doc_id)
    x = self.where('clinical_document_id = ? ', doc_id).last
  end


  def self.latest(doc_id)
    self.where('clinical_document_id = ? ', doc_id).order("version_number DESC").first
  end


  def demo_document

  end

  def patient
    clinical_document.patient
  end

  def visit
    clinical_document.visit
  end

  def image
    
    #puts "Repository = #{repository}  ID = #{archived_image.image} DemoMode = #{ENV['CA_DEMO']}"

    if(repository != 'DB' and doc_setting == 'DEMO')
      puts "Generate Demo document for version #{id}"
      pdf = DemoPdf.new(self).render
      iid = replace_image(pdf)
      puts "Generated image id = #{iid}"
      return pdf
      #return DemoPdf.new(self).render
    else
      if(archived_image.nil?) # Image has not been retrieved yet. pull it now.
          puts "Return the image from repository image nil"
          puts "Document id to request is #{self.clinical_document_id}"
          subdomain = Apartment::Tenant.current
          ImageWorker.set(:queue => :adhoc_image_job).perform_async(subdomain, self.clinical_document_id)
          img = File.read('public/ChartArchiveRequest.pdf')
      else
        img =  archived_image.image
      end

      return img
    end
  end


  def self.create_batch_pdf(doc_versions)
    # pdf = CombinePDF.new
    # doc_versions.each do |d|
    #   pdf << CombinePDF.load(d.image)
    # end
    # #pdf.add_javascript "this.print(true);"
    # pdf

    # doc_versions.each do |d|
    #   pdf_temp_nb_pages = Prawn::Document.new(:template => d.image).page_count
    # end

    my_prawn_pdf = CombinePDF.new

    doc_versions.each do |d|
      my_prawn_pdf << CombinePDF.new(d.image)
    end

    my_prawn_pdf

    # pdf = Prawn::Document.new
    #   doc_versions.each do |pdf_file|
    #     pdf_temp_nb_pages = Prawn::Document.new(:template => pdf_file).page_count
    #     (1..pdf_temp_nb_pages).each do |i|
    #       pdf.start_new_page(:template => pdf_file, :template_page => i)
    #     end
    #   end
    # #binding.pry
    # pdf
    # Prawn::Document.generate("result.pdf", {:page_size => 'A4', :skip_page_creation => true}) do |pdf|
    #   doc_versions.each do |pdf_file|
    #     # if File.exists?(pdf_file)
    #       pdf_temp_nb_pages = Prawn::Document.new(:template => pdf_file).page_count

    #       (1..pdf_temp_nb_pages).each do |i|
    #         pdf.start_new_page(:template => pdf_file, :template_page => i)
    #       end
    #     # end
    #   end
    #   return pdf
    # end

  end

  def doc_setting
    Setting.display_document
  end
  
  def new_image(mrn, hdr, image_value)
    if(repository == 'DB')
      if(!image_id.ni?)
        raise ArgumentError.new "Image is already set. Use replace_image to replace existing image"
      end

    end
    # unless (repository == 'DB')
    #   binding.pry
    #   raise ArgumentError.new "Image is already set. Use replace_image to replace existing image"
    #
    # end
    #binding.pry
    #raise ArgumentError.new "Image is already set. Use replace_image to replace existing image" unless(repository == 'DB')
    # raise ArgumentError.new "Image is already set. Use replace_image to replace existing image" unless(image_id.nil?)    # do not override current image

    puts "@@ Create new image for dv.id #{id} of size #{image_value.length}"
    ai = ArchivedImage.new

    ai.image = image_value
    ai.rep_header = hdr
    ai.document_version_id = id
    ai.med_rec_num = mrn
    DocumentVersion.transaction do
      if new_record?
        self.save!
      end
      ai.document_version_id = id
      ai.save!

      self.repository = 'DB'
      self.image_id = ai.id
      self.save!
    end
    puts "New Image id = #{ai.id}, size = #{ai.image.length}"
    ai.id
  end

  def replace_image(image_value)

    begin
      ai = ArchivedImage.find image_id
    rescue ActiveRecord::RecordNotFound
      ai = nil
    end

    DocumentVersion.transaction do
      ai.delete unless ai.nil?
      self.image_id = nil
      ai = ArchivedImage.new

      ai.image = image_value
      ai.document_version_id = id
      if new_record?
        self.save!
      end
      ai.document_version_id = id
      ai.save!
      self.repository = 'DB'
      self.image_id = ai.id
      self.save!
    end
    ai.id

  end

  def to_file(filename = nil)
    filename = "./documents/doc#{id}-#{version_number}.pdf"  if filename.nil?
    f = File.open(filename, 'wb')
    f.write image
    f.close
    filename
  end

  def log_document_access(user,visit_id, access_reason = 'ACCESSED')
    since = Time.now - self.class.log_timeframe

    access = AccessLog.user_accessed_since('DOCUMENT_VERSION', self.id, user, since, access_reason )

    unless(access)
      access = AccessLog.new
      access.access_reason= access_reason
      access.access_time=Time.now
      access.table_name='DOCUMENT_VERSION'
      access.row_id= id
      access.row_description= description
      access.user_id = user.id
      access.user_identifier = patient.name #user.user_name
      access.patient_id = patient.id 
      access.visit_id = visit_id
      access.save
    end
    return true
  end

  def self.log_batch_print(user, doc_versions, visit_id)
    doc_versions.each do |d|
      d.log_document_access(user,visit_id,'BATCH PRINT')
    end
  end

  def self.log_timeframe
    timeframe = ENV["LOG_TIMEFRAME"]
    unless timeframe.blank?
      timeframe.to_i.hours
    else
      24.hours
    end
  end

  def logs
    AccessLog.where(row_id: id, table_name: 'DOCUMENT_VERSION').order('access_time DESC')
  end

end
