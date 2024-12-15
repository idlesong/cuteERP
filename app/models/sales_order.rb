class SalesOrder < ActiveRecord::Base
  attr_accessible :bill_address, :bill_contact, :bill_telephone, :customer_id,
  :payment_term, :serial_number, :ship_address, :ship_contact, :ship_telephone,
  :delivery_date, :delivery_status, :delivery_plan, :exchange_rate, :remark,
  :created_at

  has_many :line_items, :as => :line,  :dependent => :destroy
  belongs_to :customer

  validates :serial_number, :presence => true
  # validates :bill_address, :bill_contact, :bill_telephone, :ship_contact, :ship_address,
    # :ship_telephone, :presence => true
  validates :customer_id,  :presence => true
  validates :line_items, :presence => true
  # validates :exchange_rate, :presence => true #:if => usd_currency_customer?

  def generate_order_number
    next_id = SalesOrder.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day ).count + 1
    order_number = 'SO' + DateTime.now.strftime("%Y%m%d") + '-' + (next_id%100).to_s.rjust(2,'0')
  end  

  def generate_uniform_number
    next_id = LineItem.where(line_type: "SalesOrder").maximum(:uniform_number).at(7..9).to_i + 1
    uniform_number = 'XS' + DateTime.now.strftime("%Y") + '-' + next_id.to_s.rjust(3,'0')
  end  

  def initialize_order_header(new_customer)
    self.customer = new_customer
    self.payment_term = new_customer.payment
    self.bill_contact   = new_customer.contact
    self.bill_address   = new_customer.address
    self.bill_telephone = new_customer.telephone
    self.ship_contact   = new_customer.ship_contact
    self.ship_address   = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone

    # self.exchange_rate  = 1
    self.serial_number = self.generate_order_number
  end

  def add_line_items_from_issue_cart(cart)
    logger.debug "==@@@@==SalesOrder: add line_items_from_cart.id==== #{cart.id}"
    cart.line_items.each_with_index do |line, index|
      # logger.debug "==@@@@==SalesOrder: add line_items.id==== #{line.id}"
      line.cart_id = nil
      line.line_number = self.serial_number + '-' + (index + 1).to_s.rjust(2,'0')
      self.line_items << line
    end
  end

  # so.line_items vs cart.line_items issue_unissue so: order.line_items.quantity_issued
  def issue_unissue_po_line_items_when_so_and_cart_diffs(issue_cart)
      logger.debug "==@@@@==SalesOrder: issue unissue(), issuce_cart.id==== #{issue_cart.id}"
      # so line_items not in cart(will be removed), issueback po
      self.line_items.each do |so_line|
        if not issue_cart.line_items.where(line_number: so_line.line_number).exists?
            logger.debug "==@@@@==line_items to be removed from so==== #{so_line.id}"
            self.issue_back_refer_line_item(so_line, so_line.quantity)
        end
      end

      # cart line_items not in so(will be added), issue po
      issue_cart.line_items.each do |line_item|
        # cart line_items not in so: to be added to so
        if not self.line_items.where(line_number: line_item.line_number).exists?
          logger.debug "==@@@@==new line, to be added to so==== #{line_item.id}"    
          self.issue_refer_line_item(line_item, line_item.quantity)         
        else # exist, but quantity different
          line = self.line_items.where(line_number: line_item.line_number).take
          logger.debug "==@@@@==exsit line, update po==== #{line_item.id}"
          if line.quantity < line_item.quantity
            self.issue_refer_line_item(line_item, line_item.quantity - line.quantity)
          elsif line.quantity > line_item.quantity
            self.issue_back_refer_line_item(line_item, line.quantity - line_item.quantity)          
          end
        end
      end
  end

  # issue refer po's line items, after save; and then clear cart
  def issue_refer_line_items
    line_items.each do |line|
      logger.debug "==@@@@==SalesOrder refer_line_id== #{line.refer_line_id}"
      po_line = LineItem.find(line.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + line.quantity)

      line.update_attribute(:cart_id, nil)
    end
  end

  def issue_refer_line_item(line_item, quantity)
      logger.debug "====@@@@==SalesOrder :issue_refer=refer_line_id== #{line_item.refer_line_id}"
      po_line = LineItem.find(line_item.refer_line_id)
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued + quantity)
      # line_item.update_attribute(:cart_id, nil)
  end

  def issue_back_refer_line_item(line_item, quantity)
    logger.debug "==@@@@==SalesOrder: issue_back()refer_line_id== #{line_item.refer_line_id}"
    po_line = LineItem.find(line_item.refer_line_id)
    if quantity <= po_line.quantity_issued
      po_line.update_attribute(:quantity_issued, po_line.quantity_issued - quantity)
    else
      logger.debug "==@@@@==SalesOrder: issue_back() Error}"
    end
  end

  def self.export_to_csv(options = {})
    order_header = ['customer_id', 'end_customer_id', 'created_at', 'delivery_plan', 'delivery_date']
    line_item_header = ['line_number', 'uniform_number', 'full_part_number', 'fixed_price', 'quantity', 'remark','refer_line_id','po_number']

    CSV.generate(options) do |csv|
        csv << line_item_header[0..1]+ order_header[0..1] + line_item_header[2..7] + order_header[2..4]

        all.each do |order|
          row_order_info = order.attributes.values_at(*order_header)
          
          # get Customer and end_customer name from id
          row_order_info[0] = Customer.find(row_order_info[0]).name if Customer.find(row_order_info[0])
          if (row_order_info[1] and Customer.find(row_order_info[1]))
            row_order_info[1] = Customer.find(row_order_info[1]).name 
          end
          
          order.line_items.each do |line_item|
            row_line_item = line_item.attributes.values_at(*line_item_header)
            row_line_item[7] = LineItem.find(row_line_item[6]).line.order_number
            row_line_item[6] = LineItem.find(row_line_item[6]).line_number 
            
            csv << (row_line_item[0..1] + row_order_info[0..1] + row_line_item[2..7] + row_order_info[2..4])
          end
        end            
    end       
  end

  # import (sales orders line by line)
  # validations each lines before imported: 
  # New or update, item_id, customer_id, prices must exist
  # - Valid price_number: QO20240101-01
  # Update when customer & item & price & condition exist and valid
  # - item & customer exists? => find the id
  # - Valid item: can find item_id, with fuzzy search part_number
  # - Valid customer: can find customer_id, with fuzzy search customer_name
  # - Valid price and volue: normal number, volume is intger
  # SO20240101 should be the same as created_at

  def self.import(file)    
    spreadsheet = open_spreadsheet(file)

    order_header = [ 'customer', ]
    header = ['so_line_number', 'refer_po_number', 'uniform_number', 'customer', 'full_part_number', 
             'price', 'quantity', 'remark', 'ship_plan', 'ship_date', 'base_price']
    import_errors = []

    row_header = spreadsheet.row(1)
    if !row_header.include?('uniform_number') || !row_header.include?('ship_date')
      logger.debug "=====@@@@Error: Invalid Sales Order list format== #{row_header[0]}"
      import_errors.push('Error:Not a Sales Order list format, header[0] is ' + row_header[0])  

      return import_errors
    end

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      row_attributes = row.to_hash.slice(*header)

      so_line_number = row_attributes["so_line_number"] || ""      
      # validate part_number, customer_name, price, condition presence 
      if (row_attributes["uniform_number"].blank? \
          or row_attributes["customer"].blank? \
          or row_attributes["full_part_number"].blank? \
          or row_attributes["price"].blank? \
          or row_attributes["quantity"].blank? )

        import_errors.push(so_line_number + "#:Error:with blank");
      end

      # filter last leter C in SCTxxxxABC 
      part_number = row_attributes["full_part_number"]
      # logger.debug "=====Part number== #{part_number}"  

      if row_attributes["full_part_number"] =~ /SCT\d{4}\w{3}/
        part_number = part_number.at(0..8)
        # logger.debug "=====new part number== #{part_number}"  
      end

      @item = Item.find_by(partNo: part_number)
      @customer = Customer.find_by(name: row_attributes["customer"])

      price_range = row_attributes["price"].to_f - 0.5 .. row_attributes["price"].to_f  + 0.5

      quantity = row_attributes["quantity"].to_i

      if @customer.nil? || @item.nil? || quantity <= 0 
        import_errors.push(po_number + "#:Error: Not valid customer or item or qty")
      else
        if row_attributes["price"] == row_attributes["base_price"]
          @price = Price.where(customer_id: @customer.id, item_id: @item.id, base_price: price_range).take
          # logger.debug "=====$$$$$ base price== #{row_attributes["fixed_price"]}"  
        else
          @price = Price.where(customer_id: @customer.id, item_id: @item.id, price: price_range).take
        end

        if @price.nil?
          import_errors.push(so_line_number + "#:Error: Can't find valid price")
          logger.debug "=====$$$$$ No price== #{@customer.name} #{@item.partNo} #{row_attributes["fixed_price"]}" 
        else
          # primary key: order_number, update exsit, or create new order-> line_item
          if @line_item = LineItem.find_by(line_number: row["line_number"])  
            # # update order_header attributes
            # if @line_item.line_type.nil?
            #   #  @line_item.order.new
            # elsif @line_item.line_type == 'Order'
            #   order_header.each do |attr|
            #     @line_item_order = Order.find(@line_item.line_id)

            #     if @customer = Customer.find_by(name: row_attributes["customer"]) 
            #       row_attributes.store("customer_id", @customer.id)  
            #     end
            #     # if @end_customer = Customer.find_by(name: row_attributes["end_customer_id"]) 
            #     #   row_attributes.store("end_customer_id", @end_customer.id)  
            #     # end
            #     @line_item_order.update_attribute(attr, row_attributes[attr])
            #     # @line_item_order.update_attribute(:po_number, row_attributes[po_number])
            #   end
            # end

            # # update line_item_header attributes
            # line_item_header.each do |attr|
            #   @line_item.update_attribute(attr, row_attributes[attr])
            # end
            # # logger.debug "=====row attr== #{price.attributes[attr]}, #{row_attributes[attr]}"              
          else # create new order.line_item       
            # @order = Order.where(order_number: row_order_number).take || Order.new    

            # find Order line_items[] where the price is the same as current SalesOrder 
            # @po_line_items = @customer.sales_orders.line_items.where(price_id: @price.id)
            @po_line_items = LineItem.joins("INNER JOIN orders ON line_items.line_id = orders.id ")
            .where(sales_orders: {customer_id: @customer.id})
            .where(line_items: {line_type: 'Order'})
            .where(line_items: {price_id: @price.id}) 
            
            
            # if @po_line_items.sum("quantity") > quantity
            #   # @order.line_items.where(price_id: @price.id)
            #   # logger.debug "====issue PO quantity== #{@po_line_item, quantity}"

            #   # recurse issue POs, when the quantity > found PO
            #   @po_line_item.update_attribute(quantity_issued: po_line.quantity_issued - quantity)
            #   line.quantity_issued = line.quantity              
            # else
            #   import_errors.push(po_number + "#:Error: Not enough PO qty to be issue")
            # end
            

            @sales_order = @customer.sales_orders.new
            @sales_order.initialize_order_header(@customer)                                                      

            count = 1
            # auto correct po_number to generate a unique po line_number
            # (1)blank -> customer_name + date; 
            # (2)duplicated: different customer -> customer_name+date
            # (3)duplicated -> qty <0, reverse. + ^
            # (4)duplicated: same customer, different item -> line_number+1
              
            so_line_number = @sales_order.serial_number + '-' + count.to_s.rjust(2,'0')

            reverse_po_line_id = nil;

            current_line = @sales_order.line_items.build(
                            :price_id => @price.id,
                            :line_number => so_line_number, 
                            :item_id => @price.item_id, 
                            :full_name => @item.name,
                            :full_part_number => row_attributes["full_part_number"],
                            :quantity => quantity, 
                            :fixed_price => @price.price, 
                            :refer_line_id => reverse_po_line_id)
    
            current_line.save     
            # logger.debug "====Error: import order line items== #{line_number}" 
            
            # @order.created_at = row_attributes["received_at"].to_datetime
            @sales_order.line_items << current_line 
            @sales_order.save
          end
        end
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

  before_destroy :ensure_not_invoiced_or_delivered

  private
   def ensure_not_invoiced_or_delivered
   	if delivery_date.nil?
   		return true
   	else
   		errors.add(:base, 'Line Items present')
   		return false
   	end
  end

  # completed: can't update after both invoiced and shipped
end
