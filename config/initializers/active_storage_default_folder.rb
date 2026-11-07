# Files in the shared Spaces bucket are organised by key prefix, so anything that
# doesn't set its own key, including generated variants, goes in this folder rather
# than the bucket root. A key stays with its blob, so existing files are unaffected.
module ActiveStorageDefaultFolder
  FOLDER = "PublicMisc"

  def generate_unique_secure_token(...)
    "#{FOLDER}/#{super}"
  end
end

ActiveSupport.on_load(:active_storage_blob) { singleton_class.prepend ActiveStorageDefaultFolder }
