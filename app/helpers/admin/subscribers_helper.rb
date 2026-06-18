module Admin::SubscribersHelper
  def status_badge_class(status)
    case status
    when "confirmed"    then "bg-emerald-100 text-emerald-700"
    when "unconfirmed"  then "bg-amber-100 text-amber-700"
    else                     "bg-neutral-200 text-neutral-600"
    end
  end
end
