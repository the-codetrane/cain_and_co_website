import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "slide", "dot"]

  connect() {
    this.index = 0
    this.update()
  }

  next() {
    this.index = (this.index + 1) % this.slideTargets.length
    this.update()
  }

  prev() {
    this.index = (this.index - 1 + this.slideTargets.length) % this.slideTargets.length
    this.update()
  }

  goTo(event) {
    this.index = parseInt(event.currentTarget.dataset.index)
    this.update()
  }

  update() {
    this.trackTarget.style.transform = `translateX(-${this.index * 100}%)`
    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-white", i === this.index)
      dot.classList.toggle("bg-neutral-600", i !== this.index)
    })
  }
}
