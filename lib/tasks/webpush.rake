namespace :webpush do
  desc "Generate VAPID key pair — add output to credentials via bin/rails credentials:edit"
  task keygen: :environment do
    pair = WebPush.generate_key_pair
    puts
    puts "Add the following block to credentials (bin/rails credentials:edit):"
    puts
    puts "vapid:"
    puts "  public_key: #{pair[:public_key]}"
    puts "  private_key: #{pair[:private_key]}"
    puts
  end
end
