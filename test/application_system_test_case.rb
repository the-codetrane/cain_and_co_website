require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  SCREEN_SIZE = [ 1280, 900 ]

  # The fixtures sign in with "password", which Chrome's leak check knows is breached. Its
  # warning is native browser UI that takes all input, so later clicks and keystrokes in
  # the same browser never reach the page and tests fail far from the sign-in that caused it.
  driven_by :selenium, using: :headless_chrome, screen_size: SCREEN_SIZE do |options|
    options.add_preference("profile.password_manager_leak_detection", false)
  end

  # Blob fixtures have no stored file, so a browser asking for a variant of one would
  # raise on the server rather than just show a broken image.
  setup do
    ActiveStorage::Blob.find_each do |blob|
      blob.service.upload(blob.key, file_fixture("test_photo.gif").open) unless blob.service.exist?(blob.key)
    end
  end

  private

  # Importmap modules execute after the DOM is ready, so a page can look loaded before
  # Turbo and Stimulus have started. Retry the JS expression until it is truthy.
  def assert_js(expression, message)
    page.document.synchronize do
      raise Capybara::ElementNotFound, message unless page.evaluate_script(expression)
    end
  rescue Capybara::ElementNotFound => e
    raise e.class, "#{e.message}\nBrowser console:\n#{browser_console}"
  end

  def browser_console
    page.driver.browser.logs.get(:browser).map { |entry| "  #{entry.level}: #{entry.message}" }.join("\n").presence || "  (empty)"
  rescue StandardError => e
    "  (unavailable: #{e.class}: #{e.message})"
  end

  def wait_for_stimulus_controller(identifier)
    assert_js "!!(window.Stimulus && window.Stimulus.router.modulesByIdentifier.has('#{identifier}')) && " \
              "document.querySelector('[data-controller~=\"#{identifier}\"]') !== null && " \
              "window.Stimulus.controllers.some(c => c.identifier === '#{identifier}')",
              "Stimulus controller #{identifier} never connected"
  end
end
