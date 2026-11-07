module Admin
  class PhotosController < BaseController
    PER_PAGE = 48

    before_action :set_photo, only: %i[edit update destroy]

    def index
      @filter = params[:filter]
      @photos = paginate(filtered_photos.with_image_variants.order(:position, :id))
      return render :page if turbo_frame_request?

      counts = Photo.group(:published).count
      @counts = { visible: counts[true] || 0, hidden: counts[false] || 0 }
      @counts[:all] = @counts[:visible] + @counts[:hidden]
      @filtered_count = @counts.fetch(@filter&.to_sym, @counts[:all])
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

    # Not paginated: #reorder renumbers from the ids it's sent, so dragging within part
    # of the list would give those photos the positions of the ones left out.
    def visible
      @photos = Photo.with_image_variants.where(published: true).order(:position)
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
      select_all = params[:select_all].present?
      if ids.empty? && !select_all
        redirect_to admin_photos_path(filter: params[:filter].presence), alert: "No photos selected."
        return
      end
      # "Select all" means the whole filter, including pages not scrolled to yet.
      photos = select_all ? filtered_photos : Photo.where(id: ids)
      count = photos.update_all(published: params[:published] == "1")
      redirect_to admin_photos_path(filter: params[:filter].presence),
        notice: "#{count} photo(s) updated."
    end

    private

    def filtered_photos
      case params[:filter]
      when "visible" then Photo.where(published: true)
      when "hidden"  then Photo.where(published: false)
      else Photo.all
      end
    end

    # Fetches one row more than a page to learn whether another follows, without a COUNT.
    def paginate(photos)
      page = [ params[:page].to_i, 1 ].max
      rows = photos.offset((page - 1) * PER_PAGE).limit(PER_PAGE + 1).to_a
      @next_page = page + 1 if rows.size > PER_PAGE
      rows.first(PER_PAGE)
    end

    def set_photo
      @photo = Photo.find(params[:id])
    end

    def photo_params
      params.require(:photo).permit(:image, :caption, :position, :published, :epk)
    end
  end
end
