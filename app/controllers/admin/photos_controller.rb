module Admin
  class PhotosController < BaseController
    before_action :set_photo, only: %i[edit update destroy]

    def index
      @filter = params[:filter]
      @photos = Photo.with_attached_image.order(:position)
      case @filter
      when "visible" then @photos = @photos.where(published: true)
      when "hidden"  then @photos = @photos.where(published: false)
      end
      counts = Photo.group(:published).count
      @counts = { visible: counts[true] || 0, hidden: counts[false] || 0 }
      @counts[:all] = @counts[:visible] + @counts[:hidden]
    end

    def new
      @photo = Photo.new
    end

    def create
      @photo = Photo.new(photo_params)
      if @photo.save
        redirect_to admin_photos_path, notice: "Photo added."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @photo.update(photo_params)
        redirect_to admin_photos_path, notice: "Photo updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @photo.destroy
      redirect_to admin_photos_path, notice: "Photo removed."
    end

    def visible
      @photos = Photo.with_attached_image.where(published: true).order(:position)
    end

    def reorder
      ids = Array(params[:ids]).map(&:to_i).reject(&:zero?)
      Photo.transaction do
        ids.each_with_index { |id, i| Photo.where(id: id, published: true).update_all(position: i + 1) }
      end
      head :ok
    end

    def bulk_update
      ids = Array(params[:photo_ids]).reject(&:blank?)
      if ids.empty?
        redirect_to admin_photos_path(filter: params[:filter].presence), alert: "No photos selected."
        return
      end
      count = Photo.where(id: ids).update_all(published: params[:published] == "1")
      redirect_to admin_photos_path(filter: params[:filter].presence),
        notice: "#{count} photo(s) updated."
    end

    private

    def set_photo
      @photo = Photo.find(params[:id])
    end

    def photo_params
      params.require(:photo).permit(:image, :caption, :position, :published)
    end
  end
end
