module Admin
  class PhotosController < BaseController
    before_action :set_photo, only: %i[edit update destroy]

    def index
      @photos = Photo.with_attached_image.order(:position)
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

    private

    def set_photo
      @photo = Photo.find(params[:id])
    end

    def photo_params
      params.require(:photo).permit(:image, :caption, :position, :published)
    end
  end
end
