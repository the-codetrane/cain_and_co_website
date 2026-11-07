import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "bar", "count", "published", "form", "allField"]
  static values = { total: Number }

  connect() {
    this.updateBar()
  }

  // Rows arriving from endless scroll join a "select all" that's already on.
  checkboxTargetConnected(checkbox) {
    if (this.allSelected) checkbox.checked = true
  }

  toggle(event) {
    if (!event.target.checked) this.allSelected = false
    this.updateBar()
  }

  selectAll() {
    this.allSelected = true
    this.checkboxTargets.forEach(cb => cb.checked = true)
    this.updateBar()
  }

  deselectAll() {
    this.allSelected = false
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
    const count = this.allSelected ? this.totalValue : this.selectedCount
    this.countTarget.textContent = count === 1 ? "1 selected" : `${count} selected`
    this.barTarget.classList.toggle("hidden", count === 0)
  }

  // Tells the server to apply to the whole filter, not just the rows loaded so far.
  get allSelected() {
    return this.allFieldTarget.value === "1"
  }

  set allSelected(selected) {
    this.allFieldTarget.value = selected ? "1" : ""
  }

  get selectedCount() {
    return this.checkboxTargets.filter(cb => cb.checked).length
  }
}
