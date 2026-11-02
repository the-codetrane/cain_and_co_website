module ApplicationHelper
  # Returns the url only when it is a plain http(s) link, else nil. Use for hrefs built
  # from third-party or admin-entered data so a `javascript:` URL can't reach a link.
  def safe_external_url(url)
    uri = URI.parse(url.to_s.strip)
    url.to_s.strip if uri.is_a?(URI::HTTP) && uri.host.present?
  rescue URI::InvalidURIError
    nil
  end

  # A content_for value trimmed for use inside a meta tag attribute. content_for
  # stores an already-escaped SafeBuffer, but String#strip returns a plain String,
  # which ERB would escape again ("Cain &amp;amp; Co."). to_str + strip keeps the
  # escaped text; re-marking it safe is correct because content_for escaped it.
  def meta_content(name)
    content_for(name).to_str.strip.html_safe # rubocop:disable Rails/OutputSafety
  end
end
