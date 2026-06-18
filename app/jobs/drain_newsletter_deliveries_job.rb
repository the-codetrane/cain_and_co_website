# Resumes in-flight newsletter sends. Runs on a schedule (see config/recurring.yml)
# so that recipients deferred by the daily cap are picked up after the count rolls
# over, and any newsletter whose recipients are all terminal gets finalized.
class DrainNewsletterDeliveriesJob < ApplicationJob
  queue_as :default

  def perform
    Newsletter.sending.find_each { |newsletter| NewsletterDispatch.dispatch(newsletter) }
  end
end
