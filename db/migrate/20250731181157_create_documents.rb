class CreateDocuments < ActiveRecord::Migration[7.0]
  def change
    create_table :documents do |t|
      t.string :name, null: false
      t.string :original_filename, null: false
      t.string :file_path
      t.string :content_type
      t.integer :file_size
      t.string :status, default: 'pending'
      t.text :error_message
      t.datetime :processed_at

      t.timestamps
    end

    add_index :documents, :status
    add_index :documents, :created_at
  end
end
