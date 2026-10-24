module ApplicationHelper
  # Returns the url only when it is a plain http(s) link, else nil. Use for hrefs built
  # from third-party or admin-entered data so a `javascript:` URL can't reach a link.
  def safe_external_url(url)
    uri = URI.parse(url.to_s.strip)
    url.to_s.strip if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end
end
