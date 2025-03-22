class AddHouseAccountBalanceToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :house_account_balance, :decimal, precision: 10, scale: 2, default: 0.0
  end
end
