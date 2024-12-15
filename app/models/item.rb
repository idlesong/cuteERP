class Item < ActiveRecord::Base
  attr_accessible :imageURL, :name, :package, :partNo, :description,
    :volume, :weight, :moq, :mop ,
    :assembled, :index, :base_item, :extra_item, :group, :family

  # default_scope :order => 'name'
  # default_scope { where order: 'name'}

  FW_MARK_TYPES = ["","S","M","D","C"]

  has_many :line_items
  has_many :orders, :through => :line_items
  has_many :prices
  has_many :set_prices

  validates :name, :partNo, :presence => true
  validates :partNo, :uniqueness => true

  has_settings do |s|
    s.key :extra, :defaults => { :extra => ["D","C","V","U", "T", "M", "G", ""] }
    s.key :group, :defaults => { :group => ["Digital BB", "RF", "PA", "Wireless", "resell"] }
    s.key :package, :defaults => { :package => ["QFN*", "BGA*", "PCBA*", "LQFP*", "SW", "EVB"] }
  end  

  before_destroy :ensure_not_referenced_by_any_line_item
  before_destroy :ensure_not_used_by_others

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|

      header = ["partNo", "group", "family", "name", "description", 
      "package", "mop", "assembled", "base_item", "extra_item", "index"]

      csv << header
      all.each do |item|
        csv << item.attributes.values_at(*header)
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    # header = ["partNo", "group", "family", "name", "description", 
    # "package", "mop", "assembled", "base_item", "extra_item", "index"]

    header = ["partNo", "name", "package", "description", "mop", "group", "family", 
             "assembled", "base_item", "extra_item", "index"]

    import_errors = []
    row_header = spreadsheet.row(1)
    if !row_header.include?('partNo') || !row_header.include?('package')
      logger.debug "=====@@@@Error: Invalid product list format== #{row_header[0]}"
      import_errors.push('Error:Not a product list format, header[0] is ' + row_header[0])  

      return import_errors
    end    

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]

      # validations: 
      # 1. extra only could be ["D","C","V","U", "T", "M", "G"]; 
      # 2. if extra = "", then base==part_number
      # 3. group only could be ["Digital BB", "RF", "PA", "Wireless", "resell"] & not blank
      # 4. package only could be ["QFN*", "BGA*", "PCBA*", "LQFP*", "SW", "EVB"]

      # item_extras = self.settings(:extra).extra
      # item_groups = self.settings(:group).group
      # item_packages = self.settings(:package).package

      if row["partNo"].include?(' ')
        logger.debug "=====@@@@Error: invalid part_number== #{row["partNo"]}"
        
        import_errors.push(row["partNo"])        
        next
      end

      # Update exsits, find by uniq partNo, or new a item
      item = find_by(partNo: row["partNo"])  || new

      row_attributes = row.to_hash.slice(*header)

      header.each do |attr|
        item.update_attribute(attr, row_attributes[attr])
      end      

      # import_errors.push("debug:row(" + i.to_s)
      # import_errors.push(")debug:partNo:" + item.partNo)
    end

    return import_errors
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)
    when ".csv" then Roo::CSV.new(file.path, csv_options: {encoding: "iso-8859-1:utf-8"})
    when ".xls" then Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

 private
  #ensure that there are no line items referencing this item
  def ensure_not_referenced_by_any_line_item
  	if line_items.count.zero?
  		return true
  	else
  		errors.add(:base, 'Line Items present')
  		return false
  	end
  end

  def ensure_not_used_by_others
    if prices.empty? and set_prices.empty? then
  		return true
  	else
      errors.add(:base, 'prices or set_prices exist')
  		return false
  	end
  end  
end
