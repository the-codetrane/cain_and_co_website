import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "meta-pixel-consent"

// Gates the Meta Pixel behind an opt-in banner. Attached to <body>, which Turbo
// replaces on every visit, so connect() also fires the per-page PageView.
export default class extends Controller {
  static targets = ["banner"]
  static values = { pixelId: String }

  connect() {
    const choice = this.#read()
    if (choice === "granted") this.#track()
    else if (choice === null) this.bannerTarget.hidden = false
  }

  accept() {
    this.#write("granted")
    this.bannerTarget.hidden = true
    this.#track()
  }

  decline() {
    this.#write("denied")
    this.bannerTarget.hidden = true
    this.#revoke()
  }

  reopen() {
    this.bannerTarget.hidden = false
  }

  #track() {
    if (!this.pixelIdValue || document.documentElement.hasAttribute("data-turbo-preview")) return
    this.#load()
    window.fbq("track", "PageView")
  }

  #load() {
    if (window.fbq) return
    const fbq = window.fbq = function () {
      fbq.callMethod ? fbq.callMethod.apply(fbq, arguments) : fbq.queue.push(arguments)
    }
    window._fbq = fbq
    fbq.push = fbq
    fbq.loaded = true
    fbq.version = "2.0"
    fbq.queue = []
    const script = document.createElement("script")
    script.async = true
    script.src = "https://connect.facebook.net/en_US/fbevents.js"
    document.head.appendChild(script)
    fbq("init", this.pixelIdValue)
  }

  #revoke() {
    if (window.fbq) window.fbq("consent", "revoke")
    document.cookie = "_fbp=; Max-Age=0; path=/"
  }

  #read() {
    try { return localStorage.getItem(STORAGE_KEY) } catch { return null }
  }

  #write(value) {
    try { localStorage.setItem(STORAGE_KEY, value) } catch { /* private mode: choice lasts one page */ }
  }
}
