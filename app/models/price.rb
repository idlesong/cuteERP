class Price < ActiveRecord::Base
  attr_accessible :boss_suggestion, :condition, :customer_id, :department_suggestion,
  :finance_suggestion, :item_id, :payment_terms, :price, :sales_suggestion, :status,
  :remark, :created_at, :base_price, :extra_price, :price_number, :part_number, :customer_name,
  :is_prr

  belongs_to :item
  belongs_to :customer
  belongs_to :quotation

  has_many :line_items

  validates :price, :presence => true, :numericality => {:greater_than_or_equal_to => 0}
  validates :condition, :presence => true
  validates :part_number, :presence => true
  validates :customer_name, :presence => true
  validates :item_id, :presence => true
  validates :customer_id, :presence => true

  # before_save  :ensure_price_is_unique?
  # before_destroy :ensure_not_used_by_others  


  def generate_price_number
    # next_id=1
    # next_id=Price.maximum(:id).next if Price.exists?
    next_id = Price.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day ).count + 1
    price_number = 'QO' + DateTime.now.strftime("%Y%m%d") + (next_id%100).to_s.rjust(2,'0')
  end

  def get_set_price(item_id, order_quantity, sell_by)
    last_set_price = SetPrice.order(released_at: :asc).last
    step_quantities = ["1", "1000", "2500", "5000", "10000",  "20000", "50000", "100000"]
    oem_labels = ["step1","step2","step3", "step4","step5", "step6", "step7", "step8"]
    odm_labels = ["step9","step10","step11", "step12","step13", "step14", "step15", "step16"]
    
    step_labels = oem_labels

    if sell_by == "ODM" 
      step_labels = odm_labels
    end

    if step_quantities.index(order_quantity).nil?
      index = 1
      # logger.debug "@@@@@@@@@@@@ step_arry order quantity== #{order_quantity}"      
    else
      index = step_quantities.index(order_quantity)
    end 

    step = step_labels.at(index)
    
    if last_set_price  
      @latest_set_prices = SetPrice.order("item_id ASC").where("released_at" => last_set_price.released_at )
      if @latest_set_prices.where(item_id: item_id).first.nil?
        return 0
      else
        # return @latest_set_prices.where(item_id: item_id, order_quantity: order_quantity, sell_by: sell_by).first.price
        set_price = @latest_set_prices.where(item_id: item_id).first

        price = set_price.attributes[step]
        # logger.debug "=====return set price== #{price}"
        return price
      end
    end  
  end

  def self.export_to_csv(options = {})
    CSV.generate(options) do |csv|
      # re-order columns
      header = ["price_number", "customer_name", "part_number", "price", "condition", 
                "base_price", "extra_price", "remark", "status", "created_at"]
      # logger.debug "=====csv header array== #{header}"
      csv << header

      all.each do |item|
        row = item.attributes.values_at(*header)
        # logger.debug "=====csv row== #{row} index: #{item_index}"
        csv << row
      end
    end
  end

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    import_errors = []
    header = ["price_number", "customer_name", "part_number", "price", "condition", 
    "base_price", "extra_price", "is_prr", "remark", "status", "created_at"]    

    row_header = spreadsheet.row(1)
    if !row_header.include?('price_number') || !row_header.include?('price') || !row_header.include?('is_PRR')
      logger.debug "=====@@@@Error: Invalid price list format== #{row_header[0]}"
      import_errors.push('Error:Not a price list format, header[0] is ' + row_header[0])  

      return import_errors
    end 
    
    (2..spreadsheet.last_row).each do |i|

      row = Hash[[header, spreadsheet.row(i)].transpose]
      # primary key: price_number, update if exsit, or create new one
      price = find_by(price_number: row["price_number"])  || new
      row_attributes = row.to_hash.slice(*header)   
      
      # validations: 
      # New or update, item_id, customer_id, prices, condition
      # - Valid price_number: QO20240101-01
      # Update when customer & item & price & condition exist and valid
      # - item & customer exists? => find the id
      # - Valid item: can find item_id, with fuzzy search part_number
      # - Valid customer: can find customer_id, with fuzzy search customer_name
      # - Valid price and voluem: normal number, volume is intger
      # QO20240101 should be the same as created_at
      
      # validate part_number, customer_name, price, condition presence 
      if (row_attributes["part_number"].blank? || row_attributes["customer_name"].blank? || row_attributes["price"].blank? || row_attributes["condition"].blank?)
        import_errors.push(price.price_number + ":Error:item |customer |price |quantity blank");

        return import_errors
      end

      # validate part_number, customer name are valid, auto link to id when import
      # if item = Item.where('lower(partNo) = ?', row_attributes["part_number"].downcase).first
      if item = Item.find_by(partNo: row_attributes["part_number"]) 
        if customer = Customer.where('lower(name) = ?', row_attributes["customer_name"].downcase).first
        # if customer = Customer.find_by(name: row_attributes["customer_name"])
          row_attributes.store("item_id", item.id)  
          row_attributes.store("customer_id", customer.id)

          if row_attributes["is_prr"] == "PRR" 
            row_attributes.store("is_prr", 1)
          else
            row_attributes.store("is_prr", 0)
          end

          (header + ["item_id", "customer_id"]).each do |attr|
            # logger.debug "=====row attr== #{price.attributes[attr]}, #{row_attributes[attr]}"      
            price.update_attribute(attr, row_attributes[attr])
          end
        else
          # logger.debug "=====@@@@Error: can't find customer== #{price.price_number}:#{row_attributes["customer_name"]}"
          import_errors.push('row' + i.to_s + ":Unknow customer:" + row_attributes["customer_name"])
        end  
      else
        # logger.debug "=====@@@@Error: can't find item== #{row_attributes["part_number"]}"  
        import_errors.push('row' + i.to_s + ":Unknow product:" + row_attributes["part_number"])                
      end  
    end

    return import_errors
  end

  def self.open_spreadsheet(file)
    case File.extname(file.original_filename)              
    when ".csv" then Roo::CSV.new(file.path)
    when ".xls" then Excel.new(file.path, nil, :ignore)
    when ".xlsx" then Excelx.new(file.path, nil, :ignore)
    else raise "Unknown file type: #{file.original_filename}"
    end
  end

  # before_update :price_request_approved?
  before_destroy :price_request_approved?

 private
  def ensure_price_is_unique?
    if (Price.where(customer_name: self.customer_name)
              .where(part_number: self.part_number)
              .where(condition: self.condition)
              .where.not(id: self.id)
              .first)
      return false
    else
      return true
    end
  end

  def price_request_approved?
    if status_was == 'approved'
      errors.add(:base, 'price has been approved, cannot update!')
      return false
    else
      return true
    end
  end

  def ensure_not_used_by_others
    if line_items.empty? then
  		return true
  	else
      errors.add(:base, 'line_items exist')
  		return false
  	end
  end   
end
