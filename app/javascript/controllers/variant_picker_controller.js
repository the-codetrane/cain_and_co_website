import { Controller } from "@hotwired/stimulus"

// Keeps the displayed price and the add-to-cart button in step with the selected
// size. The form still posts a plain variant_id, so this is purely progressive
// enhancement — with JS off, the radios and submit button work unchanged.
export default class extends Controller {
  static targets = ["price", "submit", "option"]

  connect() {
    this.update()
  }

  update() {
    const selected = this.optionTargets.find((option) => option.checked)

    if (this.hasPriceTarget) {
      this.priceTarget.textContent = selected ? selected.dataset.price : "—"
    }

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !selected
    }
  }
}
