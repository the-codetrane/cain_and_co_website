namespace :orders do
  # Truthy-ENV helper: a lambda rather than a `def`, which inside a rake block
  # would leak a method onto Object. Unset or blank falls back to `default`, so
  # opt-in flags default off while SEND_RECEIPTS defaults on; anything else is
  # true unless it is a recognized falsey word, compared case-insensitively.
  flag = ->(name, default: false) {
    value = ENV[name]
    return default if value.blank?

    !%w[0 false no off].include?(value.strip.downcase)
  }

  # Orders only leave "pending" when Stripe's checkout.session.completed webhook
  # arrives. If that delivery fails, the payment still succeeded and the order is
  # stranded — unpaid on our side, charged on Stripe's. This re-fetches each
  # pending order's Checkout Session and applies it exactly as the webhook would.
  #
  #   bin/rails orders:reconcile_pending DRY_RUN=1          # report only, change nothing
  #   bin/rails orders:reconcile_pending                    # apply, emailing receipts
  #   bin/rails orders:reconcile_pending SEND_RECEIPTS=false
  #   bin/rails orders:reconcile_pending ORDER_IDS=12,15    # limit to specific orders
  #   bin/rails orders:reconcile_pending MARK_EXPIRED=1     # also cancel expired sessions
  desc "Reconcile pending orders against their Stripe Checkout Session"
  task reconcile_pending: :environment do
    dry_run       = flag.call("DRY_RUN")
    mark_expired  = flag.call("MARK_EXPIRED")
    send_receipts = flag.call("SEND_RECEIPTS", default: true)

    scope = Order.pending.where.not(stripe_checkout_session_id: nil).order(:id)
    scope = scope.where(id: ENV["ORDER_IDS"].split(",").map(&:strip)) if ENV["ORDER_IDS"].present?

    puts "#{dry_run ? "[dry run] " : ""}Checking #{scope.count} pending order(s) against Stripe..."
    counts = Hash.new(0)

    scope.find_each do |order|
      session_id = order.stripe_checkout_session_id

      begin
        stripe_session = Stripe::Checkout::Session.retrieve(session_id)
      rescue Stripe::StripeError => e
        counts[:error] += 1
        puts "  order ##{order.id} #{session_id}: ERROR retrieving session — #{e.message}"
        next
      end

      state = "payment_status=#{stripe_session.payment_status} status=#{stripe_session.status}"

      # One bad order must not strand the rest of the run. The transaction rolls
      # back, so a failed order stays pending and is safely retried next time.
      begin
        if stripe_session.payment_status == "paid"
          if dry_run
            counts[:would_pay] += 1
            puts "  order ##{order.id} #{session_id}: #{state} — would mark paid " \
                 "(#{stripe_session.customer_details&.email}, $#{stripe_session.amount_total.to_i / 100.0})"
          else
            ActiveRecord::Base.transaction do
              OrderPaymentSync.apply_paid_session!(order, stripe_session, send_receipt: send_receipts)
            end
            counts[:paid] += 1
            puts "  order ##{order.id} #{session_id}: marked PAID (#{order.buyer_email}, $#{order.total_dollars})"
          end
        elsif stripe_session.status == "expired"
          if mark_expired && !dry_run
            order.update!(status: "canceled")
            counts[:canceled] += 1
            puts "  order ##{order.id} #{session_id}: #{state} — marked canceled"
          else
            counts[:expired] += 1
            puts "  order ##{order.id} #{session_id}: #{state} — expired, left pending" \
                 "#{" (pass MARK_EXPIRED=1 to cancel)" unless mark_expired}"
          end
        else
          counts[:open] += 1
          puts "  order ##{order.id} #{session_id}: #{state} — not paid yet, left pending"
        end
      rescue StandardError => e
        counts[:failed] += 1
        puts "  order ##{order.id} #{session_id}: FAILED to apply — #{e.class}: #{e.message}"
        next
      end
    end

    puts "Done. #{counts.map { |k, v| "#{k}: #{v}" }.join(", ").presence || "nothing to do"}"

    failures = counts[:error] + counts[:failed]
    puts "#{failures} order(s) were left pending by errors above — safe to re-run." if failures.positive?
  end
end
