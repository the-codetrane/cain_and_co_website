# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "trix", to: "trix-esm.js" # @2.1.19; not trix.js, which the action_text-trix gem also ships (UMD, no default export)
pin "trix_config", to: "trix_config.js"
pin "@rails/actiontext", to: "@rails--actiontext.js" # @8.1.300
pin "sortablejs" # @1.15.7
