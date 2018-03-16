class Patient < ActiveRecord::Base

  has_many :clinical_documents
  has_many :current_documents
  # has_many :documents
  # has_many :accounts ,  through: :visits
  # has_many :visits
  # has_many :diagnoses
  # has_many :batteries
  #has_many :observation_results, :through => :batteries

  #validates_uniqueness_of :pat_id

  def Patient.by_firstname(name)
    parts = name.split(',')
    case parts.size
      when 0
        # Invalid wildcard search. Can not search entire DB
        return nil
      #TODO raise invalid argument
      when 1 # Assume last name only
        w = where('lower(first_name) LIKE ?', "%#{parts[0].strip.downcase}%")
      #w = /^#{parts[0].strip}[\w\s\.]*/i
      when 2 # comma separating last and first name
        # w = where(patname: /^#{parts[0].strip}[\w\s\.]*, #{parts[1].strip}[\w\s\.]*/i)
        w = where('lower(first_name) LIKE (?) OR lower(first_name) LIKE (?)',
                  "%#{parts[0].strip.downcase}%" , "%#{parts[1].strip.downcase}%")
      #w = /^#{parts[0].strip}[\w\s\.]*, #{parts[1].strip}[\w\s\.]*/i
      else
        #invalid wildcard search
        return nil
    end
    w
  end

  def Patient.by_name(fname, lname)
    fname = fname.strip.downcase+'%' unless fname.nil?
    # if fname.nil?
    #   fname = '%'
    # else
    #   fname = '%'+fname.strip.downcase+'%'
    # end


    lname = lname.strip.downcase+'%' unless lname.nil?
    #
    # if lname.nil?
    #   lname = '%'
    # else
    #   lname = '%'+lname.strip.downcase+'%'
    # end


    if( fname.nil? && lname.nil?)
      return all
    end

    if(lname.nil?)
      w = where('lower(first_name) LIKE ?',fname)
    elsif(fname.nil?)
      w = where('lower(last_name) LIKE ?', lname)
    else
      w = where('lower(last_name) LIKE ? and lower(first_name) LIKE ?', lname, fname)
    end

    #
    # findname = "#{lname}, #{fname}"
    # puts "findname = #{findname}"
    # where('lower(name) LIKE ?', findname)
  end


  def Patient.by_lastname(name)
    parts = name.split(',')
    case parts.size
      when 0
        # Invalid wildcard search. Can not search entire DB
        return nil
      #TODO raise invalid argument
      when 1 # Assume last name only
        w = where('lower(last_name) LIKE ?', "%#{parts[0].strip.downcase}%")
      #w = /^#{parts[0].strip}[\w\s\.]*/i
      when 2 # comma separating last and first name
        # w = where(patname: /^#{parts[0].strip}[\w\s\.]*, #{parts[1].strip}[\w\s\.]*/i)
        w = where('lower(last_name) LIKE (?) OR lower(last_name) LIKE (?)', "%#{parts[0].strip.downcase}%",
                  "%#{parts[1].strip.downcase}%")
      #w = /^#{parts[0].strip}[\w\s\.]*, #{parts[1].strip}[\w\s\.]*/i
      else
        #invalid wildcard search
        return nil
    end
    w
  end


  def Patient.by_mrn(medrec)
    where(mrn: medrec)
  end

  def log_access(user, role)
    since = Time.now - log_timeframe
    access = AccessLog.user_accessed_since('PATIENT', self.id, user, since )

    unless(access)
      access = AccessLog.new
      access.access_reason='PATIENT RECORD MANAGEMENT'
      access.access_time=Time.now
      access.table_name='PATIENT'
      access.row_id= id
      access.patient_id = id
      access.row_description= name
      access.user_id = user.id
      access.user_type = role
      access.save
    end
    return true
  end

  def log_timeframe
    timeframe = ENV["LOG_TIMEFRAME"]
    unless timeframe.blank?
      timeframe.to_i.hours
    else
      24.hours
    end
  end

  def self.recent_for_user(user)
    #logs = AccessLog.select(:row_id,:access_time).where("table_name = 'PATIENT'  and user_id = ?", user.id).order("access_time DESC").distinct(:row_id)
    logs = AccessLog.select(:row_id,:access_time).where("table_name = 'PATIENT'  and user_id = ?", user.id).order("access_time DESC").distinct(:row_id)
    
    pat_ids = []
    logs.each do |l|
      pat_ids << l.row_id
    end
    pats = []

    #Patient.where("id in (?)", pat_ids).limit(10).each do |p|
    # Patient.where(id: pat_ids).limit(10).index_by(&:id).slice(*pat_ids).values.each do |p|
    #   pats << RecentPatient.new(id: p.id, mrn: p.mrn, sex: p.sex, name: p.name, full_name: p.full_name, 
    #           access_time: logs.find{|l| l.row_id == p.id }.access_time )
    # end
    #pats.sort_by {|p| p.access_time}.reverse

    Patient.where(id: pat_ids.uniq).limit(10).order("name ASC").each do |p|
      pats << RecentPatient.new(id: p.id, mrn: p.mrn, sex: p.sex, name: p.name, full_name: p.full_name, 
              access_time: logs.find{|l| l.row_id == p.id }.access_time )
    end
    pats
  end

  def clinical_documents_by_type(doc_type)
    clinical_documents.where("type_id = ?", doc_type).order('reptdate')
  end

  def document_versions_by_type(doc_type)
    list = clinical_documents.where("type_id = ?", doc_type)
  end

  def documents_for_tab(tab_id, page, per_page, column_name, sort_order='DESC')
    doc_ids = []
    docs = []

    ds = DocumentSource.find(tab_id)
    
    if ds.name == 'Chronological'
      DocumentSourceDocType.all.each do |dst|
        doc_ids << dst.document_type_id
      end
    else
      DocumentSourceDocType.where("data_source_id = ?", tab_id).each do |dst|
         doc_ids << dst.document_type_id
      end
    end

    cdocs = if column_name == 'description'
      if doc_setting == 'YES' || doc_setting == 'DEMO'
        current_documents.where( "type_id in (?)", doc_ids).order("#{column_name} #{sort_order}, rept_datetime DESC").page(page).per(per_page)
        # QC1 did not support cancelling documents so ignoring
        #current_documents.where( "type_id in (?) and status != 'CA'", doc_ids).order("#{column_name} #{sort_order}, rept_datetime DESC").page(page).per(per_page)
      elsif doc_setting == 'NO'
        #current_documents.where( "type_id in (?) and status != 'CA' and repository = 'DB' ", doc_ids).order("#{column_name} #{sort_order}, rept_datetime DESC").page(page).per(per_page)
        # Qc1 does not support Cancelled documebnts or versions. remove check for CA as it is null and query does not work
        current_documents.where( "type_id in (?) and repository = 'DB' ", doc_ids).order("#{column_name} #{sort_order}, rept_datetime DESC").page(page).per(per_page)
      end
    else
      if doc_setting == 'YES' || doc_setting == 'DEMO'
        #current_documents.where( "type_id in (?) and status != 'CA'", doc_ids).order("#{column_name} #{sort_order}").page(page).per(per_page)
        # Qc1 does not support Cancelled documebnts or versions. remove check for CA as it is null and query does not work
        current_documents.where( "type_id in (?)", doc_ids).order("#{column_name} #{sort_order}").page(page).per(per_page)
      elsif doc_setting == 'NO'
        #current_documents.where( "type_id in (?) and status != 'CA' and repository = 'DB'", doc_ids).order("#{column_name} #{sort_order}").page(page).per(per_page)

        # Qc1 does not support Cancelled documebnts or versions. remove check for CA as it is null and query does not work
        current_documents.where( "type_id in (?) and repository = 'DB'", doc_ids).order("#{column_name} #{sort_order}").page(page).per(per_page)
      end
    end

    [cdocs, cdocs.total_count, cdocs.total_pages]
  end

  def documents_count
    doc_hash = {}

    DocumentSource.all.each do |ds|
      doc_ids = []

      if ds.name == 'Chronological'
        DocumentSourceDocType.all.each do |dst|
          doc_ids << dst.document_type_id
        end
      else
        DocumentSourceDocType.where("data_source_id = ?", ds.id).each do |dst|
           doc_ids << dst.document_type_id
        end
      end
      
      #binding.pry
      doc_hash[ds.id] = if doc_setting == 'YES' || doc_setting == 'DEMO'
        #binding.pry
        #current_documents.where( "type_id in (?) and status != 'CA'", doc_ids).count
        # Qc1 does not support Cancelled documebnts or versions. remove check for CA as it is null and query does not work
        current_documents.where( "type_id in (?)", doc_ids).count
      elsif doc_setting == 'NO'
        #current_documents.where( "type_id in (?) and status != 'CA' and repository = 'DB' ", doc_ids).count
        # Qc1 does not support Cancelled documebnts or versions. remove check for CA as it is null and query does not work
        current_documents.where( "type_id in (?) and repository = 'DB' ", doc_ids).count

                        end
    end
    
    doc_hash
  end

  def display_email?
    Setting.display_email?
  end

  def doc_setting
    Setting.display_document
  end

  def selected_docs(doc_hash)
    h = {}
    docs = []
    doc_hash.each do |tab_id, doc_ids|
      ds = DocumentSource.find(tab_id)
      DocumentVersion.find(doc_ids).each do |d|
        docs << SelectedDocument.new(version_id: d.id , document_source_id: ds.id, document_source_name: ds.name,
                                     description: d.description, rept_datetime: d.rept_datetime )
      end 
    end
    docs
  end

  def age
    (Date.today - birth_date).to_i / 365 unless birth_date.blank?
    #Date.today.year - birth_date.year
  end

 # 1926-10-15
 # Fri, 15 Oct 1926

  def full_name
    "#{last_name}, #{first_name} #{middle_name}"
  end

	def default_visit
    v = Visit.where(visit_num: "default-#{id}").first
    if v.blank?
      v = create_default_visit("default-#{id}")
    end
    v
  end

	private

  def create_default_visit(visit_num)
    v = Visit.new
    v.visit_num =  visit_num
    v.visit_id = id * -1
    v.patient_id = id
    v.account_id = account_id
    v.comment = "Catchall visit"
    v.status = "Catchall Visit"
    v.facility = facility
    begin
      v.save!
    rescue Exception => e
      puts "Catchall visit for #{id} failed: #{e}"
      return nil
    end
    v
  end

	def visit(visit_num)
    Visit.where(:patient_id=> id, :visit_num => visit_num)
  end
end