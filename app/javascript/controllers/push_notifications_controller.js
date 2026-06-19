import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["prompt", "iosHint"]
  static values = { vapidPublicKey: String }

  connect() {
    if (!this.isPushSupported()) {
      this.element.hidden = true
      return
    }
    if (Notification.permission !== "default") {
      this.element.hidden = true
      return
    }
    if (this.isIOS()) {
      if (!this.isStandalone()) {
        this.promptTarget.hidden = true
        if (this.hasIosHintTarget) this.iosHintTarget.hidden = false
      } else {
        this.promptTarget.hidden = false
      }
      return
    }
    this.promptTarget.hidden = false
  }

  async subscribe() {
    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      this.element.hidden = true
      return
    }

    try {
      const registration = await navigator.serviceWorker.ready
      const sub = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: this.urlBase64ToUint8Array(this.vapidPublicKeyValue)
      })

      await fetch("/push_subscriptions", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          push_subscription: {
            endpoint: sub.endpoint,
            p256dh_key: this.arrayBufferToBase64Url(sub.getKey("p256dh")),
            auth_key: this.arrayBufferToBase64Url(sub.getKey("auth")),
            user_agent: navigator.userAgent.slice(0, 500)
          }
        })
      })

      this.element.hidden = true
    } catch (error) {
      console.error("Push subscription failed:", error)
      this.element.hidden = true
    }
  }

  dismiss() {
    this.element.hidden = true
  }

  isPushSupported() {
    return "serviceWorker" in navigator && "PushManager" in window && "Notification" in window
  }

  isIOS() {
    return /iphone|ipad|ipod/i.test(navigator.userAgent)
  }

  isStandalone() {
    return window.matchMedia("(display-mode: standalone)").matches || navigator.standalone === true
  }

  // Web Push requires URL-safe base64 (no +, /, or = padding).
  arrayBufferToBase64Url(buffer) {
    const bytes = new Uint8Array(buffer)
    let binary = ""
    for (const byte of bytes) binary += String.fromCharCode(byte)
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    return Uint8Array.from(atob(base64), (c) => c.charCodeAt(0))
  }
}
