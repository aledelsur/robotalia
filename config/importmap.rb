# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# The self-contained UMD build (it sets window.Chart). The ESM build imports chunks that
# bin/importmap does not vendor.
pin "chart.js", to: "chart.umd.js", preload: false # @4.6.2
