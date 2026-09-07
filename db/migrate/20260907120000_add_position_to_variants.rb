class AddPositionToVariants < ActiveRecord::Migration[8.1]
  def up
    add_column :variants, :position, :integer, default: 0, null: false

    # Seed existing rows so their current (insertion) order is preserved.
    execute <<~SQL
      UPDATE variants
         SET position = (
           SELECT COUNT(*)
             FROM variants AS earlier
            WHERE earlier.product_id = variants.product_id
              AND earlier.id < variants.id
         )
    SQL

    add_index :variants, [ :product_id, :position ]
    add_index :variants, [ :product_id, :name ], unique: true
  end

  def down
    remove_index :variants, [ :product_id, :name ]
    remove_index :variants, [ :product_id, :position ]
    remove_column :variants, :position
  end
end
