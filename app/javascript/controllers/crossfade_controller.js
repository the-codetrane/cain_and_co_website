import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "dot"]
  static values = { interval: { type: Number, default: 5000 } }

  connect() {
    this.index = 0
    this.update()
    this.startTimer()
  }

  disconnect() {
    clearInterval(this.timer)
  }

  next() {
    this.advance()
    this.resetTimer()
  }

  prev() {
    this.index = (this.index - 1 + this.cardTargets.length) % this.cardTargets.length
    this.update()
    this.resetTimer()
  }

  goTo(event) {
    this.index = parseInt(event.currentTarget.dataset.index)
    this.update()
    this.resetTimer()
  }

  advance() {
    this.index = (this.index + 1) % this.cardTargets.length
    this.update()
  }

  update() {
    this.cardTargets.forEach((card, i) => {
      const active = i === this.index
      card.classList.toggle("opacity-100", active)
      card.classList.toggle("opacity-0", !active)
      card.classList.toggle("pointer-events-none", !active)
      card.setAttribute("aria-hidden", String(!active))
    })
    this.dotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-white", i === this.index)
      dot.classList.toggle("bg-neutral-600", i !== this.index)
    })
  }

  startTimer() {
    this.timer = setInterval(() => this.advance(), this.intervalValue)
  }

  resetTimer() {
    clearInterval(this.timer)
    this.startTimer()
  }
}
