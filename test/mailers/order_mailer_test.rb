require "test_helper"

class OrderMailerTest < ActionMailer::TestCase
  test "receipt contains order details" do
    order = orders(:one)
    mail = OrderMailer.receipt(order)

    assert_equal "Your Cain & Co. order is confirmed (##{order.id})", mail.subject
    assert_equal [ order.buyer_email ], mail.to

    text_part = mail.text_part.decoded
    html_part = mail.html_part.decoded

    assert_match order.buyer_name, text_part
    assert_match "$30.00", text_part
    assert_match order_items(:shirt_in_paid_order).variant_name, text_part
    assert_match order_items(:shirt_in_paid_order).variant_name, html_part
  end
end
