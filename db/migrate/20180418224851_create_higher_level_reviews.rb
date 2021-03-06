class CreateHigherLevelReviews < ActiveRecord::Migration[5.1]
  safety_assured

  def change
    create_table :higher_level_reviews do |t|
      t.string     :veteran_file_number, null: false
      t.date       :receipt_date
      t.boolean    :informal_conference
      t.boolean    :same_office
      t.datetime   :established_at
      t.string     :end_product_reference_id
      t.string     :end_product_status
      t.datetime   :end_product_status_last_synced_at
    end

    add_index(:higher_level_reviews, :veteran_file_number)
  end
end
