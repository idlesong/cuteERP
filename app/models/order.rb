class Order < ActiveRecord::Base
  attr_accessible :customer_id, :amount, :order_number, :name, :address,
    :telephone, :ship_contact, :ship_address, :ship_telephone, :pay_type,
    :exchange_rate, :remark, :document, :created_at, :end_customer_id,
    :po_number

  has_many :line_items, as: :line,  :dependent => :destroy
  belongs_to :customer

  PAYMENT_TYPES = ["款到发货","T.T in advance", "COD", "T.T 30days"]

  has_attached_file :document

  validates_attachment :document, :content_type => {:content_type =>
    %w(image/jpeg image/jpg image/png application/pdf application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document)}

  validates :order_number, :presence => true
  validates :pay_type, :presence => true
  # validates :pay_type, :inclusion => PAYMENT_TYPES
  validates :line_items, :presence => true
  validates :customer_id, :presence => true
  validates :exchange_rate, :presence => true
  # validates :name, :address, :presence => true # can fill when ship

  # before_update :not_issued?
  before_destroy :not_issued?

  def initialize_order_header(new_customer)
    self.customer = new_customer
    # set bill_to and ship_to contact by default, then confirm it in sales order
    self.name      = new_customer.contact
    self.address   = new_customer.address
    self.telephone = new_customer.telephone
    self.ship_contact = new_customer.ship_contact
    self.ship_address = new_customer.ship_address
    self.ship_telephone = new_customer.ship_telephone

    self.exchange_rate = 1 #default for rmb
    self.pay_type  = new_customer.payment
    self.order_number = self.generate_order_number
  end

  def add_line_items_from_cart(cart, reverse_order)
  	cart.line_items.each_with_index do |line, index|
  		line.cart_id = nil
      line.line_number = self.order_number + '-' + (index + 1).to_s.rjust(2,'0')

      if line.quantity < 0 
        if reverse_order
          # issue po order before create reverse po
          logger.debug "====cart-cart=refer_line_id== #{line.refer_line_id}"
          po_line = LineItem.find(line.refer_line_id)
          po_line.update_attribute(:quantity_issued, po_line.quantity_issued - line.quantity)
          line.quantity_issued = line.quantity         
        else
          logger.debug "====po.po.po.po#### line_quantity error"        
          return
        end
      end

  		line_items << line
  	end
  end

  def generate_order_number
    # next_id=1
    # next_id=Order.maximum(:id).next if Order.exists?
    next_id = Order.where(created_at: DateTime.now.at_beginning_of_day..DateTime.now.at_end_of_day ).count + 1
    order_number = 'PO' + DateTime.now.strftime("%Y%m%d") + '-' + (next_id%100).to_s.rjust(2,'0')
  end

  # def auto_generate_order_number(customer_po_number)
  #   if customer_po_number.nil
  #     order_number = 'PO:'+ customer_name + DateTime.now.strftime("%Y%m%d")
  #   else
  #     # customer_po_number must unique
  #   end
  # end


  # Cancel issued order left quantity
  def cancel
  end

  def self.export_to_csv(options = {})
    annual_orders = SalesOrder.all.order(order_number: :asc)
    order_header = ['order_number', 'customer_id', 'end_customer_id', 'po_number', 'created_at']
    line_item_header = ['line_number', 'full_part_number', 'fixed_price', 'quantity', 'quantity_issued', 'remark']

    CSV.generate(options) do |csv|
        csv << order_header + line_item_header

        all.each do |order|
          row_order_info = order.attributes.values_at(*order_header)
          row_order_info[1] = Customer.find(row_order_info[1]).name if Customer.find(row_order_info[1])
          if (row_order_info[2] and Customer.find(row_order_info[2]))
            row_order_info[2] = Customer.find(row_order_info[2]).name 
          end

          order.line_items.each do |line_item|
            row_line_item = line_item.attributes.values_at(*line_item_header)

            csv << (row_order_info + row_line_item)
          end
        end            
    end       
  end

  # import (customer orders line by line)
  # validations each lines before imported: 
  # New or update, item_id, customer_id, prices, condition
  # - Valid price_number: QO20240101-01
  # Update when customer & item & price & condition exist and valid
  # - item & customer exists? => find the id
  # - Valid item: can find item_id, with fuzzy search part_number
  # - Valid customer: can find customer_id, with fuzzy search customer_name
  # - Valid price and voluem: normal number, volume is intger
  # QO20240101 should be the same as created_at

  def self.import(file)
    spreadsheet = open_spreadsheet(file)

    order_header = ['po_line_number', 'customer', 'po_number', 'received_at', 'price_number']
    line_item_header = ['full_part_number', 'fixed_price', 'quantity', 'value', 'quantity_issued', 'remark']
    header =  order_header + line_item_header                      

    import_errors = []
    row_header = spreadsheet.row(1)
    if !row_header.include?('customer') || !row_header.include?('po_number')
      logger.debug "=====@@@@Error: Invalid purchase Order list format== #{row_header[0]}"
      import_errors.push('Error:Not a Purchase Order list format, header[0] is ' + row_header[0])  

      return import_errors
    end

    (2..spreadsheet.last_row).each do |i|
      row = Hash[[header, spreadsheet.row(i)].transpose]
      row_attributes = row.to_hash.slice(*header)

      po_number = row_attributes["po_number"] || ""      
      # po_number = row_attributes["po_number"]    
      # validate part_number, customer_name, price, condition presence 
      if (row_attributes["customer"].blank? \
          or row_attributes["full_part_number"].blank? \
          or row_attributes["fixed_price"].blank? \
          or row_attributes["quantity"].blank? \
          or row_attributes["value"].blank? \
          or row_attributes["received_at"].blank?)

        import_errors.push(po_number + "#:Error:with blank");
      end

      # filter last leter C in SCTxxxxABC 
      part_number = row_attributes["full_part_number"]
      # logger.debug "=====Part number== #{part_number}"  
      if row_attributes["full_part_number"] =~ /SCT\d{4}\w{3}/
        part_number = part_number.at(0..8)
        # logger.debug "=====new part number== #{part_number}"  
      end

      @item = Item.find_by(partNo: part_number)
      # @customer = Customer.find_by(name: row_attributes["customer"])
      @customer = Customer.where('lower(name) = ?', row_attributes["customer"].downcase).first

      price_range = row_attributes["fixed_price"].to_f - 0.5 .. row_attributes["fixed_price"].to_f  + 0.5
      quantity = row_attributes["quantity"].to_i

      if @customer.nil? || @item.nil?
        import_errors.push(po_number + "#:Error: Not valid customer or item")
      else
        if row_attributes["remark"] == "base"
          @price = Price.where(customer_id: @customer.id, item_id: @item.id, base_price: price_range).take
          # logger.debug "=====$$$$$ base price== #{row_attributes["fixed_price"]}"  
        else
          @price = Price.where(customer_id: @customer.id, item_id: @item.id, price: price_range).take
        end

        if @price.nil?
          import_errors.push(po_number + "#:Error: Can't find valid price")
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
            @order = @customer.orders.new
            @order.initialize_order_header(@customer)                                                      
            
            ## auto turn po_number to a regulative unique po line_number
            # (1)blank -> customer_name + date; 
            # (2)duplicated: only_date -> customer_name+date
            # (3)duplicated: -> qty <0, reverse. + ^
            # (4)duplicated: -> line_number+1
            count = 1
            logger.debug "====&&&&&: row_line_number==  #{row_attributes["po_number"]}" 

            if row_attributes["po_number"].blank?
              line_number = 'PO:' + @customer.name + DateTime.now.strftime("%Y%m%d")
            else
              line_number = 'PO:'+ row_attributes["po_number"]              
            end
            
            # if row_attributes["po_number"] = ~/^[\d]+$/
            #   line_number = 'PO:' + @customer.name + row_attributes["po_number"]
            # end

            if quantity < 0
              line_number = 'PO:@' + row_attributes["po_number"].to_s
            end

            @customer_line_items = LineItem.joins("INNER JOIN orders ON line_items.line_id = orders.id ")
            .where(line_items: {line_type: 'Order'})
            .where(orders: {customer_id: @customer.id})            

            if @customer_line_items.where(line_number: line_number).exists?
              line_number = line_number + '-' + count.to_s.rjust(2,'0')
            end

            reverse_po_line_id = nil;
            current_line = @order.line_items.build(
                            :price_id => @price.id,
                            :line_number => line_number, 
                            :item_id => @price.item_id, 
                            :full_name => @item.name,
                            :full_part_number => row_attributes["full_part_number"],
                            :quantity => quantity, 
                            :fixed_price => @price.price, 
                            :refer_line_id => reverse_po_line_id)
    
            if !current_line.save    
              import_errors.push(po_number + "#:Error: Can't save current_line")
            end 
            # logger.debug "====Error: import order line items== #{line_number}" 
            
            # @order.created_at = row_attributes["received_at"].to_datetime
            @order.po_number = row_attributes["po_number"]
            @order.line_items << current_line 

            if !@order.save
              import_errors.push(po_number + "#:Error: Can't save PO")
            end

            if false # quantity < 0
              # reverse orders in open orders: find refer line(same price_id)
              quantity_left = quantity

              @matched_open_order_line_items = LineItem.joins("INNER JOIN orders ON line_items.line_id = orders.id ")
              .where(line_items: {line_type: 'Order'})
              .where(orders: {customer_id: @customer.id})
              .where(price_id: @price.id) 
              # .where(line_items: {quantity -quantity_issued > 0})

              # @matched_po_line_items = @customer.orders.line_items.where(price_id: @price.id)
              @matched_open_order_line_items.each do |po_line|
                # @customer.order.line_items.where(price_id: @price.id)
                # logger.debug "====cart-cart=refer_line_id== #{line.refer_line_id}"
                # po_line = LineItem.find(line.refer_line_id)
                po_line_left = po_line.quantity - po_line.quantity_issued
                if quantity_left < po_line_left
                  po_line.update_attribute(quantity_issued: po_line.quantity_issued + quantity_left)
                  quantity_left = 0
                  break;
                else
                  po_line.update_attribute(quantity_issued: po_line.quantity_issued - po_line_left)
                  quantity_left = quantity_left - po_line_left         
                  # logger.debug "====po.po.po.po#### reverse order"
                end
                
              end        
            end

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

  # ensure this order is not issued by any of the sales order
  def not_issued?
    if line_items.where("quantity_issued > 0").exists?
      errors.add(:base, 'Order has been used by sales orders')
      return false
    end

    return true
  end

private
  # ensure not completed: canceled or all items issued
  def besure_not_completed?
  end

end
