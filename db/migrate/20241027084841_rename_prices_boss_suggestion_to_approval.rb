class RenamePricesBossSuggestionToApproval < ActiveRecord::Migration
  def change
    rename_column :prices, :boss_suggestion, :approval    
  end
end
