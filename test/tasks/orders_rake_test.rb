require "test_helper"
require "rake"

class OrdersRakeTest < ActiveSupport::TestCase
  # The reconciliation task is the manual recovery path for orders Stripe charged
  # but our webhook never marked paid, so its failure handling is the part that
  # matters: one bad order must not strand every order queued behind it.
  # Memoized so the rakefiles load at most once per process. The load re-executes
  # every task definition in lib/tasks, which re-assigns top-level constants that
  # other rakefiles set (photos.rake's IMAGE_EXTENSIONS) — silenced so the suite
  # output stays clean.
  def self.reconcile_task
    @reconcile_task ||= begin
      Kernel.silence_warnings { Rails.application.load_tasks }
      Rake::Task["orders:reconcile_pending"]
    end
  end

  setup { @task = self.class.reconcile_task }

  teardown do
    %w[DRY_RUN MARK_EXPIRED SEND_RECEIPTS ORDER_IDS].each { |key| ENV.delete(key) }
  end

  def run_task
    @task.reenable
    capture_io { @task.invoke }.first
  end

  def pending_orders
    [ orders(:one), orders(:two) ].each do |order|
      order.update!(status: "pending", stripe_payment_intent_id: nil)
    end
  end

  def paid_session(order)
    Stripe::Checkout::Session.construct_from({
      "id" => order.stripe_checkout_session_id,
      "object" => "checkout.session",
      "status" => "complete",
      "payment_status" => "paid",
      "payment_intent" => "pi_test_reconciled",
      "amount_total" => 3300,
      "total_details" => { "amount_shipping" => 800 },
      "customer_details" => { "email" => "fan@example.com", "name" => "Test Fan" },
      "collected_information" => { "shipping_details" => {
        "name" => "Test Fan",
        "address" => { "line1" => "123 Main St", "city" => "Nashville",
                       "state" => "TN", "postal_code" => "37201", "country" => "US" }
      } }
    })
  end

  # Stub Session.retrieve for the duration of the block, resolving each id back
  # to the order that owns it.
  def stubbing_stripe(&)
    sessions = ->(id) { paid_session(Order.find_by!(stripe_checkout_session_id: id)) }
    Stripe::Checkout::Session.stub(:retrieve, sessions, &)
  end

  test "a failing order does not abort the orders queued behind it" do
    pending_orders
    first, second = Order.pending.order(:id).to_a
    boom = ->(order, _session, **) {
      raise "synthetic failure" if order.id == first.id
      order.update!(status: "paid")
    }

    output = OrderPaymentSync.stub(:apply_paid_session!, boom) do
      stubbing_stripe { run_task }
    end

    assert_match(/order ##{first.id}.*FAILED to apply.*synthetic failure/, output)
    assert_equal "pending", first.reload.status, "failed order should be left pending for a re-run"
    assert_equal "paid", second.reload.status, "order behind the failure should still be processed"
    assert_match(/failed: 1/, output)
    assert_match(/paid: 1/, output)
    assert_match(/1 order\(s\) were left pending by errors above/, output)
  end

  test "SEND_RECEIPTS is falsey case-insensitively and defaults to sending" do
    pending_orders
    received = []
    recorder = ->(order, _session, send_receipt: true) {
      received << send_receipt
      order.update!(status: "paid")
    }

    { "FALSE" => false, "0" => false, "no" => false, "off" => false,
      "true" => true, nil => true }.each do |value, expected|
      Order.update_all(status: "pending")
      received.clear
      value.nil? ? ENV.delete("SEND_RECEIPTS") : ENV["SEND_RECEIPTS"] = value

      OrderPaymentSync.stub(:apply_paid_session!, recorder) { stubbing_stripe { run_task } }

      assert_equal [ expected ] * received.size, received,
        "SEND_RECEIPTS=#{value.inspect} should pass send_receipt: #{expected}"
    end
  end

  test "a Stripe retrieval error is reported and the run continues" do
    pending_orders
    first, second = Order.pending.order(:id).to_a
    retrieve = ->(id) {
      raise Stripe::InvalidRequestError.new("No such session", "id") if id == first.stripe_checkout_session_id
      paid_session(second)
    }

    output = Stripe::Checkout::Session.stub(:retrieve, retrieve) do
      OrderPaymentSync.stub(:apply_paid_session!, ->(order, _s, **) { order.update!(status: "paid") }) { run_task }
    end

    assert_match(/order ##{first.id}.*ERROR retrieving session/, output)
    assert_equal "pending", first.reload.status
    assert_equal "paid", second.reload.status
    assert_match(/error: 1/, output)
  end
end
