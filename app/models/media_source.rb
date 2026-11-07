# Resolves an attachment or variant to what `image_tag` should receive.
#
# On a public service (DigitalOcean Spaces in production) a stored file has a
# permanent URL, so browsers fetch it from the CDN directly instead of bouncing
# through Active Storage's redirect route, which costs a trip through Puma per image.
#
# Everything else keeps the object itself, so Rails builds its usual route: the Disk
# service used in development and test, and a variant that hasn't been generated yet.
# That route creates the variant on first request, so a missing one heals itself.
module MediaSource
  def self.for(media)
    return media unless media.service.public? && media.key.present?

    cdn_host = Rails.configuration.x.media_cdn_host.presence
    cdn_host ? media.url.sub(%r{\Ahttps://[^/]+}, "https://#{cdn_host}") : media.url
  end
end
