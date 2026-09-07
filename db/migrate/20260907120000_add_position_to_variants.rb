class AddPositionToVariants < ActiveRecord::Migration[8.1]
  # Matches Variant::SIZE_POSITION_STEP — positions are spaced so a variant inserted
  # later has room to land between two existing ones.
  STEP = 10

  # Variant#assign_position treats position 0 as "please assign one for me", so the
  # backfill must start at STEP rather than 0. Otherwise the earliest variant of each
  # product would be re-positioned (and a non-size one sent to the end) the next time
  # it happened to be saved.
  def up
    add_column :variants, :position, :integer, default: 0, null: false

    execute <<~SQL
      UPDATE variants
         SET position = #{STEP} * (1 + (
           SELECT COUNT(*)
             FROM variants AS earlier
            WHERE earlier.product_id = variants.product_id
              AND earlier.id < variants.id
         ))
    SQL

    add_index :variants, [ :product_id, :position ]

    # Variant validates name uniqueness per product case-insensitively; a plain
    # unique index on (product_id, name) is case-sensitive in SQLite and would still
    # let "S" and "s" both land under a race. Index the lowercased name to match.
    add_index :variants, "product_id, lower(name)",
              unique: true, name: "index_variants_on_product_id_and_lower_name"
  end

  def down
    remove_index :variants, name: "index_variants_on_product_id_and_lower_name"
    remove_index :variants, [ :product_id, :position ]
    remove_column :variants, :position
  end
end
