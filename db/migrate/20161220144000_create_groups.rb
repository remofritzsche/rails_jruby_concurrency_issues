class CreateGroups < ActiveRecord::Migration[5.0]
  def change
    create_table :groups do |t|
      t.string :name
      t.integer :manager_id
    end

    add_column :users, :group_id, :integer
  end
end
