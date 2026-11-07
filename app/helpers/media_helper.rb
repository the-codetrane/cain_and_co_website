module MediaHelper
  def media_src(media)
    MediaSource.for(media)
  end
end
