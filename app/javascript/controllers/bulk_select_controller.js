import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "bar", "count", "published", "form"]

  connect() {
    this.updateBar()
  }

  toggle() {
    this.updateBar()
  }

  selectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateBar()
  }

  deselectAll() {
    this.checkboxTargets.forEach(cb => cb.checked = false)
    this.updateBar()
  }

  publish() {
    this.publishedTarget.value = "1"
    this.formTarget.requestSubmit()
  }

  hide() {
    this.publishedTarget.value = "0"
    this.formTarget.requestSubmit()
  }

  updateBar() {
    const count = this.selectedCount
    this.countTarget.textContent = count === 1 ? "1 selected" : `${count} selected`
    this.barTarget.classList.toggle("hidden", count === 0)
  }

  get selectedCount() {
    return this.checkboxTargets.filter(cb => cb.checked).length
  }
}
