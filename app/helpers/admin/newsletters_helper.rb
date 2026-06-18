module Admin::NewslettersHelper
  def newsletter_status_class(status)
    case status
    when "draft"     then "bg-neutral-200 text-neutral-600"
    when "scheduled" then "bg-indigo-100 text-indigo-700"
    when "sending"   then "bg-amber-100 text-amber-700"
    when "sent"      then "bg-emerald-100 text-emerald-700"
    else                  "bg-neutral-200 text-neutral-600"
    end
  end
end
