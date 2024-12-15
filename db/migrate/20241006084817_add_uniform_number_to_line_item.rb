class AddUniformNumberToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :uniform_number, :string
  end
end
