# This migration comes from pack (originally 20180817104303)
class AddOptionsCategoryIdToPackVersionOptions < ActiveRecord::Migration
  def change
    add_column :pack_version_options, :options_category_id, :integer
  end
end
