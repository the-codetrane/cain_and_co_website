require "test_helper"

class NewsletterDrafterTest < ActiveSupport::TestCase
  # Minimal stand-in for Anthropic::Client — captures the request and returns a
  # message shaped like the SDK's (content = array of typed blocks).
  Block = Struct.new(:type, :text)

  class FakeMessages
    attr_reader :captured

    def initialize(blocks)
      @blocks = blocks
    end

    def create(**kwargs)
      @captured = kwargs
      Struct.new(:content).new(@blocks)
    end
  end

  class FakeClient
    attr_reader :messages

    def initialize(blocks)
      @messages = FakeMessages.new(blocks)
    end
  end

  test "configured? is false without a key" do
    assert_not NewsletterDrafter.new(api_key: nil).configured?
  end

  test "configured? is true with a key" do
    assert NewsletterDrafter.new(api_key: "sk-test").configured?
  end

  test "call raises when not configured" do
    assert_raises(NewsletterDrafter::Error) do
      NewsletterDrafter.new(api_key: nil).call
    end
  end

  test "builds the request with persona, topic, and shows; returns extracted HTML" do
    client = FakeClient.new([ Block.new(:thinking, ""), Block.new(:text, "<p>Hello fans</p>") ])
    drafter = NewsletterDrafter.new(api_key: "sk-test", client: client)

    body = drafter.call(topic: "summer tour", shows: [ shows(:upcoming) ])

    assert_equal "<p>Hello fans</p>", body
    req = client.messages.captured
    assert_equal NewsletterDrafter::MODEL, req[:model]
    assert_match "copywriter for Cain & Co.", req[:system_]
    user_turn = req[:messages].first[:content]
    assert_match "summer tour", user_turn
    assert_match shows(:upcoming).title, user_turn
  end

  test "wraps Anthropic errors in NewsletterDrafter::Error" do
    failing = Class.new do
      def messages = self
      def create(**)
        raise Anthropic::Errors::APIError.new(url: URI("https://api.anthropic.com/v1/messages"), message: "boom")
      end
    end.new

    error = assert_raises(NewsletterDrafter::Error) do
      NewsletterDrafter.new(api_key: "sk-test", client: failing).call
    end
    assert_match "boom", error.message
  end
end
