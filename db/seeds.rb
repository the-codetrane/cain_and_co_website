# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# Seed the single admin user. There is no public signup — this is the only account.
# Set ADMIN_EMAIL / ADMIN_PASSWORD in the environment (defaults are for local dev only).
admin_email = ENV.fetch("ADMIN_EMAIL", "admin@cainandco.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "change-me-in-production")

admin = User.find_or_initialize_by(email_address: admin_email)
admin.password = admin_password
admin.save!
puts "Seeded admin user: #{admin.email_address}"
