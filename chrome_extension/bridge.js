// Listen for a message from popup.html
window.addEventListener("message", function (event) {
    if (event.data.action === "collectRecommendations") {
        const username = event.data.username;
        chrome.runtime.sendMessage({ action: "collectRecommendations", username: username }, function (response) {
            // Send the response back to popup.html
            console.log(username);
            console.log(response);
            window.parent.postMessage({ action: "collectedRecommendations", data: response }, "*");
        });
    }
});
