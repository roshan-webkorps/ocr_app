class CreateExtractedData < ActiveRecord::Migration[7.0]
  def change
    create_table :extracted_data do |t|
      t.references :document, null: false, foreign_key: true
      t.string :key, null: false
      t.text :value
      t.string :data_type, default: 'text'

      t.timestamps
    end

    add_index :extracted_data, [ :document_id, :key ]
  end
end
