class SalesOrdersController < ApplicationController
  # GET /sales_orders
  # GET /sales_orders.json
  def index
    @sales_orders = SalesOrder.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sales_orders }
    end
  end

  # GET /sales_orders/1
  # GET /sales_orders/1.json
  def show
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/new
  # GET /sales_orders/new.json
  def new
    @sales_order = SalesOrder.new

    # @orders = Order.all
    @customer = Customer.find( params[:customer_id])
    @orders = Order.where(customer_id: params[:customer_id])

    @sales_order.initialize_order_header(@customer)

    @cart = current_issue_cart
    session[:cart_order_type] = "SalesOrder"
    # session[:cart_order_id] = @sales_order.id
    session[:cart_currency] = @sales_order.customer.currency
    session[:exchange_rate] = @sales_order.exchange_rate


    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_order }
    end
  end

  # GET /sales_orders/1/edit
  def edit
    @sales_order = SalesOrder.find(params[:id])

    session[:cart_order_type] = "SalesOrder"
    # session[:cart_order_id] = @sales_order.id
    session[:cart_currency] = @sales_order.customer.currency
    session[:exchange_rate] = @sales_order.exchange_rate
  end

  # GET /sales_orders/1/confirm
  def confirm
    @sales_order = SalesOrder.find(params[:id])
  end

  # POST /sales_orders
  # POST /sales_orders.json
  def create
    @sales_order = SalesOrder.new(params[:sales_order])
    @sales_order.add_line_items_from_issue_cart(current_issue_cart)

    # @sales_order.customer_id = session[:customer_id]
    respond_to do |format|
      if @sales_order.save

        current_issue_cart.issue_refer_line_items

        Cart.destroy(session[:issue_cart_id])
        session[:issue_cart_id] = nil
        format.html { redirect_to @sales_order, notice: 'Sales order was successfully created.' }
        format.json { render json: @sales_order, status: :created, location: @sales_order }
      else
        @orders = Order.where(customer_id: @sales_order.customer.id)
        @cart = current_issue_cart

        session[:cart_order_type] = "SalesOrder"
        session[:cart_order_id] = @sales_order.id

        format.html { render action: "new" }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sales_orders/1
  # PUT /sales_orders/1.json
  def update
    @sales_order = SalesOrder.find(params[:id])

    respond_to do |format|
      if @sales_order.update_attributes(params[:sales_order])
        format.html { redirect_to @sales_order, notice: 'Sales order was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @sales_order.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sales_orders/1
  # DELETE /sales_orders/1.json
  def destroy
    @sales_order = SalesOrder.find(params[:id])
    @sales_order.destroy

    respond_to do |format|
      format.html { redirect_to sales_orders_url }
      format.json { head :no_content }
    end
  end
end