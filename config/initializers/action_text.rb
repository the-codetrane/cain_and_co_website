Rails.application.config.to_prepare do
  ActionText::ContentHelper.allowed_tags =
    ActionText::ContentHelper.sanitizer.class.allowed_tags.to_a +
    [ ActionText::Attachment.tag_name, "figure", "figcaption", "h2", "h3" ]
end
