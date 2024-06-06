// Listen for a message from popup.html
window.addEventListener("message", function (event) {
    if (event.data.action === "collectData") {
        const username = event.data.username;
        chrome.runtime.sendMessage({ action: "collectData", username: username }, function (response) {
            // Send the response back to popup.html
            window.parent.postMessage({ action: "collectData", data: response }, "*");
        });
    }
});
