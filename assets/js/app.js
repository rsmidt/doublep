// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import topbar from "../vendor/topbar"

const Hooks = {}
Hooks.CopyToClipboard = {
    mounted() {
        this.el.addEventListener("click", e => {

            // @link https://css-tricks.com/copy-paste-the-web/
            // Select the email link anchor text
            const html = document.querySelector(this.el.dataset.copyTarget);

            const range = document.createRange();
            range.selectNode(html);
            window.getSelection().addRange(range);

            try {
                // Now that we've selected the anchor text, execute the copy command
                let successful = document.execCommand('copy');
                let msg = successful ? 'successful' : 'unsuccessful';
            } catch (err) {
                console.error('failed to copy', err)
            }

            // Remove the selections - NOTE: Should use
            // removeRange(range) when it is supported
            window.getSelection().removeRange(range);
        })
    }
}

let intervalRef;
let current;

Hooks.AutoRevealTimer = {
    mounted() {
        this.handleEvent("auto-reveal-timer-started", data => {
            clearInterval(intervalRef)
            current = data.duration;
            this.el.innerHTML = `${current / 1000} second(s) to auto-reveal`

            intervalRef = setInterval(() => {
                current -= 1000
                if (current <= 0) {
                    clearInterval(intervalRef)
                    this.el.innerHTML = ''
                } else {
                    this.el.innerHTML = `${current / 1000} second(s) to auto-reveal`
                }
            }, 1000)
        })
    }
}


let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken }, hooks: Hooks })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", info => topbar.delayedShow(200))
window.addEventListener("phx:page-loading-stop", info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

