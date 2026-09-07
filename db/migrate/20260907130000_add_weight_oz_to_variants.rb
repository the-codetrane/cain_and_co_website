class AddWeightOzToVariants < ActiveRecord::Migration[8.1]
  # 0 means "not weighed yet" rather than "weightless" — Variant#shipping_weight_oz
  # substitutes Variant::DEFAULT_WEIGHT_OZ so an un-weighed variant prices as a
  # typical shirt instead of shipping for free. Existing rows keep the default.
  def change
    add_column :variants, :weight_oz, :integer, default: 0, null: false
  end
end
