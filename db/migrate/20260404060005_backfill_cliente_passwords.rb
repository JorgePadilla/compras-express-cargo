class BackfillClientePasswords < ActiveRecord::Migration[8.0]
  def up
    return unless ENV["SEED_SAMPLE_DATA"] || Rails.env.development?

    Cliente.where(password_digest: nil).find_each do |cliente|
      cliente.update_columns(password_digest: BCrypt::Password.create("Cliente123!"))
    end
  end

  def down
    # no-op: cannot reverse password hashing
  end
end
