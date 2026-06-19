namespace :webpush do
  desc "Generate VAPID key pair — add output to credentials via bin/rails credentials:edit"
  task keygen: :environment do
    key = WebPush.generate_key
    puts
    puts "Add the following block to credentials (bin/rails credentials:edit):"
    puts
    puts "vapid:"
    puts "  public_key: #{key.public_key}"
    puts "  private_key: #{key.private_key}"
    puts
  end
end
