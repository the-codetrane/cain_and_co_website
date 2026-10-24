require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1280, 900 ]

  private

  # Importmap modules execute after the DOM is ready, so a page can look loaded before
  # Turbo and Stimulus have started. Retry the JS expression until it is truthy.
  def assert_js(expression, message)
    page.document.synchronize do
      raise Capybara::ElementNotFound, message unless page.evaluate_script(expression)
    end
  end

  def wait_for_stimulus_controller(identifier)
    assert_js "!!(window.Stimulus && window.Stimulus.router.modulesByIdentifier.has('#{identifier}')) && " \
              "document.querySelector('[data-controller~=\"#{identifier}\"]') !== null && " \
              "window.Stimulus.controllers.some(c => c.identifier === '#{identifier}')",
              "Stimulus controller #{identifier} never connected"
  end
end
