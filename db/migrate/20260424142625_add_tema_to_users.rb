class AddTemaToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :tema, :string
  end
end
