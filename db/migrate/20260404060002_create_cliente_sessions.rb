class CreateClienteSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :cliente_sessions do |t|
      t.references :cliente, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
