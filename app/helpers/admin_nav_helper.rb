# The admin sections, shared by the desktop top nav and the phone tab bar. A section with
# a :tab label gets a slot in the tab bar; the rest sit behind its More button.
module AdminNavHelper
  ADMIN_SECTIONS = [
    { label: "Dashboard", tab: "Home", icon: :home, path: :admin_root_path, controllers: %w[dashboard] },
    { label: "Products", tab: "Products", icon: :tag, path: :admin_products_path, controllers: %w[products variants] },
    { label: "Shows", tab: "Shows", icon: :calendar, path: :admin_shows_path, controllers: %w[shows] },
    { label: "Photos", tab: "Photos", icon: :photo, path: :admin_photos_path, controllers: %w[photos] },
    { label: "Orders", path: :admin_orders_path, controllers: %w[orders] },
    { label: "Videos", path: :admin_videos_path, controllers: %w[videos] },
    { label: "Newsletter", path: :admin_newsletters_path, controllers: %w[newsletters] },
    { label: "Email list", path: :admin_subscribers_path, controllers: %w[subscribers] },
    { label: "Notifications", path: :new_admin_push_notification_path, controllers: %w[push_notifications] },
    { label: "Users", path: :admin_users_path, controllers: %w[users invitations] }
  ].freeze

  # Heroicons outline paths.
  ADMIN_NAV_ICONS = {
    home: "m2.25 12 8.954-8.955c.44-.439 1.152-.439 1.591 0L21.75 12M4.5 9.75v10.125c0 .621.504 1.125 1.125 1.125H9.75v-4.875c0-.621.504-1.125 1.125-1.125h2.25c.621 0 1.125.504 1.125 1.125V21h4.125c.621 0 1.125-.504 1.125-1.125V9.75M8.25 21h8.25",
    tag: "M9.568 3H5.25A2.25 2.25 0 0 0 3 5.25v4.318c0 .597.237 1.17.659 1.591l9.581 9.581c.699.699 1.78.872 2.607.33a18.095 18.095 0 0 0 5.223-5.223c.542-.827.369-1.908-.33-2.607L11.16 3.66A2.25 2.25 0 0 0 9.568 3ZM6 6h.008v.008H6V6Z",
    calendar: "M6.75 3v2.25M17.25 3v2.25M3 18.75V7.5a2.25 2.25 0 0 1 2.25-2.25h13.5A2.25 2.25 0 0 1 21 7.5v11.25m-18 0A2.25 2.25 0 0 0 5.25 21h13.5A2.25 2.25 0 0 0 21 18.75m-18 0v-7.5A2.25 2.25 0 0 1 5.25 9h13.5A2.25 2.25 0 0 1 21 11.25v7.5",
    photo: "m2.25 15.75 5.159-5.159a2.25 2.25 0 0 1 3.182 0l5.159 5.159m-1.5-1.5 1.409-1.409a2.25 2.25 0 0 1 3.182 0l2.909 2.909m-18 3.75h16.5a1.5 1.5 0 0 0 1.5-1.5V6a1.5 1.5 0 0 0-1.5-1.5H3.75A1.5 1.5 0 0 0 2.25 6v12a1.5 1.5 0 0 0 1.5 1.5Zm10.5-11.25h.008v.008h-.008V8.25Zm.375 0a.375.375 0 1 1-.75 0 .375.375 0 0 1 .75 0Z",
    more: "M6.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM12.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0ZM18.75 12a.75.75 0 1 1-1.5 0 .75.75 0 0 1 1.5 0Z"
  }.freeze

  def admin_tab_sections
    ADMIN_SECTIONS.select { |section| section[:tab] }
  end

  def admin_more_sections
    ADMIN_SECTIONS.reject { |section| section[:tab] }
  end

  def admin_section_path(section)
    public_send(section[:path])
  end

  def admin_section_current?(section)
    section[:controllers].include?(controller_name)
  end

  def admin_nav_icon(name)
    tag.svg(tag.path(d: ADMIN_NAV_ICONS.fetch(name), "stroke-linecap": "round", "stroke-linejoin": "round"),
      class: "size-6", fill: "none", viewBox: "0 0 24 24", "stroke-width": "1.5", stroke: "currentColor", "aria-hidden": "true")
  end
end
