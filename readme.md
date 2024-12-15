# Cute ERP
A cute online ERP, with order system, simple CRM, documents system; 
Cute: easy to use, hide complex for user; robust, modulate; Easy to cooperate with excel workflow by export/import.
use ruby on rails inspired by webERP.

CuteERP: Focus on my needs first， new market development & lean startup in mind sales.

## Quick start
### Build
1. install ruby on rails(rvm)
1. update & install gems
   - bundle update
   - bundle install
1. install nodejs(or rubyracer)   
1. install postgreSQL(and create user rorcuteerp, rorcuteerp)
1. initialize database: rake db:setup
1. rails server -e development
1. login cuteerp with user name and password in : db/seeds.rb
1. import customers, products, set_prices, prices(quotations), customer_orders, sales_orders

### deploy
1. heroku

## Features
### product management
1. products: part_number, type, family, name, description, package, MPQ
1. support assembled products: 
   - assembled item is basic item, but with base, extra, assembled information
1. product status(index: -1, 0, 1, 2)
   - 0: unqualified, 1: inactive, 2: active, -1: EOLed      
1. wiki,related marketing report

### customer management
1. customer
   - overview 
     - basic info: contacts & orders & opportunities & wiki
   - credit:(-1, 0, 1, >1)
     - 0: unqualified, 1: inactive, >1: credit, -1: closed  
   - sales_type: OEM, ODM, internal, re_sell  
1. multiple currencies(now RMB and USD) support   
1. different ship_to and bill_to address support(clone by default)
1. support English and Chinese languages.
1. support different sales types: ODM/OEM/internal
   - SalesOrders need to mark end customers(can modify easily) 

1. export / import customers list
1. contacts:
   - status:(-1, 0, 1)
     - 0: unqulified; 1: inactive; 2: active; -1: archieved/invalid 
   - link contact as bill_to and ship_to easily 


### order system
set_price(PriceList)->price(Quotation), order(PO), sales_order(production_order, invoice, packing_list)

#### prices
- set_price: (part_number /quantity /price / dist_customer / released_at(key))
   - latest price list view(like price list excel, with extra price)
      - step values/names set in current_user.settings
      - setting: name: order_quantity_OEM1, value: 1000, note: released_date
   - support assembled set_price: final price and extra price  
- prices(customer prices)
   - price is the key block for orders, linked to item and customer.
   - support assembled price
     - final price=base + extra through item(part_number=base_item+extra_item) 
   - protections: 
     - avoid to create similar price(same customer, item, volume(condition))   
     - can't edit approved price
     - warning price > set_price 
   - price request & approval(active) & archive
     - auto fillin related set_price according to sales_channel(ODM/OEM) & order_quantity
     - Price reduce request need approval
     - when approved, price status set approved, and inactive old price
     - status(approved/outdated -1: 0, 1, 2, 3, 4)
     - 0: unqulified; 1: requested; 2: approved; ->3: active(inactive to approved)  -1: outdated/archieved 
   - price import/export    
- quotation(united)
   - each price can print a quotation
   - united quotation has many customer prices (with order_quantity(codition) & remarks)
   - quotation remarks(can modify freely)
   - quotation number  

#### Orders(customer order, sales order)
- customer order ==issue to==> sales orders(scheduled) 分解订单 ==> shipped
1. customer order(single driving force)
   - types/catalogs: order, preorder(?), reversed_order
   - reverse_order: issue order like issue to sales_order  
   - orders status(line_items): issued, shipped(?) 
   - issue to sales order(means: sales_orders are issued PO)
   - original order upload(pdf format)     
1. sales order(issued from customer order, related to shipment)
   - customer order ==issue to==> sales orders(scheduled) 分解订单
   - sales orders =>start production(uniform_number) =>confirm/ship to=> shipped
   - edit sales orders(shipped: confirmed=shipped=invoiced)
     - how to edit-issued: edit quantity, zero delete lineitems? issue more? 
     - split sales orders: new sales order
   - Sales orders shipped
   - invoice, packing_list   
   - overview report
   - ship confirmation
   - ship status input
   - invoiced/shipped(issued) orders can't edit, use reverse order to handle    
1. preorders(only forecast, not act as real order data?)
   - used for forecast. easy to edit and reschedule, act like sales orders(shipment).
   - be cleaned every month
   - can turn to real customer orders, if match?
   - order_kind: preorders
1. delivery
   - re-schedule: delivery_plan date change freely.
   - auto highlight outdated so when delivery_plan < Time.now.
   - fixed date: when delivery, set delivery_plan = delivery_date, then fixed.    
1. import/export orders/sales orders?    

### Admin: overview of active Orders
1. Sales Rolling Forecast view is *Main View*(admin)
   - All customer orders(with preorders) together in a year forecast overview
     - sort by shipped, open-orders, and preorders. with dispatch schedule
     - Customers orders view, sort by:
       - sales type: ODM, OEM, internal, Re-sell
       - product group: Digital_baseband, RF, PA, Vocoder, 
       - territoreis: KR, ExFJ, FJ
       - customers
       - part_numbers
       - prices
     - Products view, sort by:
       - sales type
       - product group
       - product family(SCT3258, SCT3604, SCT3600)
   - as easy as excel, or better
     - fill the table with forecast-preorders
     - change preorder quantity

1. Product Rolling Forecast view in *Main View*(admin)
   - Catalog the actually selling products
   - Calalog settings

### payment & receivable(under development)
1. payment
1. receivable account
1. balance

### business opportunities management
- BO means customer projects
1. index(show opportunities in catalog)

### activities(tasks) management
1. related to customer.
1. related to opportunities

### user management
1. administrator interface(Overview based on user role)
1. sales overview
   - Sales Rolling Forecast
   - Customer open orders

### documents system(markdown, like wiki)
1. customers wiki
1. products wiki
1. marketing wiki

### settings
1. configuration
   - documents system, 
   - payment term: COD, T.T in advance
   - set_price: order quantities
   - company information: name, address,  
   - opportunities can hide
   gem for setting models
   https://github.com/ledermann/rails-settings

### maintaince(import, export)
- Easily import and export all major data timely
- import (yearly) / export(backup data monthly?) according to unique identifier
   - Customer: customer engilish short name: *Onreal*
   - Item: part_number: *SCT3258TDM*
   - SetPrice: release_date & partNo; *SP2024.05.02-005*
   - Price: price_number *QO2024.10.22-05*
   - Order: order_type & line_number: *PO:PUR-220309005-01(with created_at)*
   - SalesOrder: order_type & line_number:*SO2022.10.22-06-1, XS2024-133*

- skills
  - timely: import yearly, backup data monthly?
  - reuse create_at/released_at/since
  - import: create_at fetch from SP_number; QO_number; PO_number; SO_number;

  - import also verify the data; 

- customers list

 *name#* | "territory"| "full_name"| "sales_type"| "disty_id"|"payment"| "currency"| "since"| "address"| "contact" | "telephone"| "credit"
---|---|---|---|---|---|---|---|---|---|---|---
*Qixiang* |FJ |QZ Qixiang |OEM |no |T.T. |RMB |2010 |QZ city | MissZhang |1005000 |1 |

- items list

*part#*| "group"| "family"| "name"| "description"| "package"| "mop"| "assembled"| "base_item"| "extra_item"| "index"
---|---|---|---|---|---|---|---|---|---|---
*SCT3288TD*|Baseband|SCT3288|d baseband| d baseband | QFN88 | 490|no|SCT3288| | 1

  - users list
  
  - set_prices list

*set_price#* | 'part'| 'extra_price'| '1'| '1k'| '2.5k'| '5k'| '10k'| '20k'| '50k'| '100k'| '1'| '1k'| '2.5k'| '5k'| '10k'| '20k'| '50k' 
---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---
*SP2024.05.02-005* |SCT3288TD | 31 | 85 |82|75|75|65|85 |82|75|75|65||75|75|65|60


  - prices list(quotation)

*price#*| "customer_name"| "part_number"| "price"| "condition"|"base_price"| "extra_price"| "remark"| "status"| "created_at"
---|---|---|---|---|---|---|---|---|---
*QO2021.01.22-01* |Qixiang|SCT3258TD| 80| 50k | 80|30|new | active 

  - customer_orders list(line_items as basic unit)  

*PO-line_no#*| 'customer_id'| 'end_cus_id'| *po_no*| 'created_at'|price_id| 'full_partNo'|'fixed_price'| 'qty'| 'qty_issued'| 'remark'
---|---|---|---|---|---|---|---|---|---|---
*PO:PUR-220309005-01*| qixiang | no | *PUR-220309005* | 241003 | QO21122-01 | SCT3288TD |80|5000|*4000*|no 

  - sales_orders list(line_items as basic unit)

*SO-line_no#*|'uni_no'| 'cus_id'| 'end_cus_id'| 'refer_po_no'| 'full_p_no'| 'f_price'| 'qty'| 'FW'|'plan_date'|'ship_date'|remark 
---|---|---|---|---|---|---|---|---|---|---|---
*SO:241004-01-01*|XS22-131|Qixiang|no|*PO:PUR-220309005-01*|SCT3288TD|92|2500|V3.01.01P3|221131|221131|*
*SO:241004-02-01*|??22-132|Qixiang|no|*PO:PUR-220309005-01*|SCT3288TD|92|2500|-|221131|221131|*


## development
### upgrade rails from 3.2 to 4.2 tips
1. [upgrade guide](https://edgeguides.rubyonrails.org/upgrading_ruby_on_rails.html)
1. [upgrade tips](https://ruby-china.org/topics/22280?locale=en)
1. Change logs:
   - Gemfile update to 4.xx
   - whitelist_attribute
   - mass_assignment_san...
   - group assets


### code reading & date structures & function logicals
![block_diagram](./doc/block_digrams.png)


#### Feature requests - major
1. common
   - attachments for PRR, customer PO

1 maintaince: import/export
  - common 
    - 导入前先单独做validates？ 
      - 主要属性比如封装，ODM/OEM只能在可选中选择？

  - item import validates
    - base + extra 为拆分声码器用；extra只能为几种声码器（D，C，V，U，T，M，G）；extra为空，base则和型号一致。
    - group不能为空
    - group且只能在常见类别（baseband/RF）中选择。
  - customer import validates
    - 不新建重复的客户： 避免相似用户名：大小写，名称不允许空格，横线；
    - 中文名称一致，用户名不一致也不新建客户
    - validate新客户提示？
  - price import validates
   - 新建或更新Price时，必须是
     - 合法客户：支持模糊名称（不区分大小写）
     - 合法型号：支持模糊名称（不区分大小写)
     - 合适的价格和数量：是数字，数量且为整数
     - approved条目，Approval不能为空：链接到SetPrice SP20220121-001；或PRR
   - 更新Price时，必须确保
     - Price_number是真实的（不会误更新原有的）?且未批准的。已批准的只能更新状态。
  - order import validates
    - 导入订单不能Update，只能新增，否则issues，数量计算。
    - 按时间段导入，按时间段核算(quantity,value)。grand_total; group total;monthly_total;
    - New(received_date;customer;part_number; price; quantity;qty_issued? customer po_number) 
      => PO_line_number:PO20240401-01-01  => order_number
      => check price_number ?(select)

1. Order
- *如何导入导出 orders, sales_orders/uniform_orders?*
- *Line_items 如何保证没有空的，非order和sales order*

- *PO:YS2020.02.02" - 使用客户订单编号，如果没有客户名缩写-日期“*

- product group/sell_by
  - Own(baseband/RF/PA), Internal(baseband/RF/PA), resell
  - ODM_baseband; ODM_RF; resell

- 生成生产订单unique_order_number
sales_orders: start_production, uniform_number(use lineitem.full_name first )
生成六联单（sales_order:start_production，production_number，line_items:product_property)

1. customer orders(single driving force)
   - types: shipped orders(confirmed), open orders, preorders 
   - customer-orders: issued: scheduled;  confirm sales orders also make orders shipped?   
   - preorders: easy to edit, reschedule; based on shipment used for forecast 
1. sales orders(based on shipment) 
   - types: shipped orders(invoice, confirmed), scheduled shipments, forecast shipments
   - issue from sales orders, open orders and pre-orders.   
- more
   1. rolloing forecast: includes 3 shipped orders, open orders, preorders with dispatch schedule  
   - (list view) re-schedule easily: 
   - add new line(in current view), delete line, change quantity 
   - auto clear forecast orders, when issue sales orders (first in, first out)?
   - manually adjustment forecast quantity & auto re-schedule outdated forecast schedule(in forecast view) 

   - filter by: product number/ product family / product type/ Territory / customer/
   - default:  product type/ territory /       
   - Year view of booking 
   - remain booking, allocate orders 


line_type: Order, -> issued SalesOrder(scheduled -> shipped); 
quantity_issued:


### bugs and refact & clean & small features
1. users
   - 不同权限：比如生产发货首页

1. items

1. customers
  - show/ add new contact can't save

  - 客户名，使用中文还是英文名？
  - 客户名，大小写

  disty/customer
   - customer 为交易客户；备注最终客户即可？
   - Alliedchips/xradio
   - Alliedchips/AMIS
   - CML/Entel
   - no/Qixiang
  - end_customer_id to disty

1. Orders(customer order)
   - forbidden edit issued orders failed when the line not be issued
   - sales order should merge same items line like order does
   - order can't edit; shows private not_issued?  
   - should restore line_items' cart_id or clear cart_id after save(or will leave failed line_items)
   - validate line_items: presence not work
   - add report of orders and sales_orders for (1month, 3month,6month,1year)
   - show warning when create order without monthly exchange rate(stamp:EX201606)
   - Can't mass-assign protected attributes for SalesOrder: {:delivery_status=>"reschedule"}

   - delete reverse order also should issue_back

   - PO:直接根据客户订单号生成系统订单号(加PO前缀)：PO-PUR-220309005;可省去客户订单号   
   - PO: created_at, 其实就是订单收到日期 received_at
   - ordering: 
     - item.group: own_products, resell
     - sales_type(1) ODM/OEM; Internal; 
     - item.group: baseband, RF, PA
     - area: Korea, ChinaFJ, ChinaExFJ
     - customer_name, accend

orders/show: Can not edit this order, order been issued!
- 应该醒目提示已分解订单（右上角显示订单状态？），隐藏编辑按钮
- 取消人民币和美元兑换，number_to_currency
- 全部使用中文，根据客户语言选择订单
- 发货前，需先下六联单

如何拆分生产订单？直接修改SO？

预计交期: 2024-09-02 ↻ 现在发货

样品单/退换货单 如何处理？

CML订单，如何与ODM分类

PO header title

SCT3258PV for Korea, not assemble?

sales_type: set_price/ ODM/OEM, internal, resell? 如何拆分

1. set_price
   - sp_number: SP20240502-001; remove released at? and line_no? created_at=released_at? 
   - import when no file selected, not allowed 
   - verification: 同一发布时间，型号不能重复。

1. price 
   - price as quotation or a flexible quotations
   - quotation has many prices; prices has many quotations.
   - g scaffold quotation quotation_number:string remark:string price_id:integer
   - [ ] show by catalogs: active(current stared price, requested price), all(approved, requested) 
   - finance confirmed price: mark 1640  
   - [ ] bug: choose set_price will reset customer name
   - [ ] bug: use simple quotation view as price request view.(include price request?)    
   - [ ] bug: customer full name: blank but not nil?

   - price 报价单需要有依据 
     - new/show/edit: SP20240502-032; PRR approval:department_suggestion
     - PRR 上传附件, 
     - List price 链接 set_price_number
   - 直接打印pdf报价单，不需要预览
   - department_suggestion: PRR approval.

   - 导入时，客户名称产品名称不区分大小写；如果有错误，网页提示


1. documents(posts)
   - assign correct subject in customer wiki, product wiki creation
   - default wiki templates for customer wiki, products wiki, markets wiki
   - product wiki: auto create short url according to products name policy.
   - Add website for customers in templates
   - Docs, fetch 1st line as post title
   - Docs, add edit preview in the same page.
   - markets model? name, catalog(based on solution), market catalog label

1. users
   - only admin can add new user, and update the profile
   - user can reset the password  
   - admin can active , inactive user
   - user rights policy

1. admin
   - sales orders overview, sort with item index
   - overview filter for choosen customer  

