function insertIframe() {
    const targetDiv = document.getElementById('masthead-ad');
    if (!targetDiv) {
        console.error('Target element not found.');
        return;
    }

    const iframe = document.createElement('iframe');
    iframe.id = 'dynamic-iframe';
    iframe.style.width = '100%';
    iframe.style.height = '500px'
    iframe.style.border = '0';
    iframe.style.borderRadius = '20px';
    iframe.style.display = 'block';
    iframe.src = "https://youbuddy-96438.web.app/"
    iframe.onload = () => {
        iframe.style.height = iframe.contentWindow.document.documentElement.scrollHeight + 'px';
    };

    const wrapperDiv = document.createElement('div');
    wrapperDiv.id = 'iframe-wrapper';
    wrapperDiv.style.width = '100%';
    wrapperDiv.appendChild(iframe);

    // Create the toggle button
    const toggleButton = document.createElement('button');
    toggleButton.innerText = 'Hide YouBuddies';
    toggleButton.style.background = 'linear-gradient(to right, #FF0047, #00BFFF)';
    toggleButton.style.color = 'white';
    toggleButton.style.border = 'none';
    toggleButton.style.padding = '10px 20px';
    toggleButton.style.borderRadius = '2px';
    toggleButton.style.fontWeight = 'bold';
    toggleButton.style.fontSize = '15px';
    toggleButton.style.cursor = 'pointer';
    toggleButton.style.marginBottom = '10px';
    // Ensuring the gradient text works across different browsers
    toggleButton.style.backgroundClip = 'text';
    toggleButton.style.webkitBackgroundClip = 'text';
    toggleButton.style.webkitTextFillColor = 'transparent';
    toggleButton.style.display = 'block';
    toggleButton.style.margin = 'auto';

    toggleButton.onclick = function () {
        // Set the initial height for the animation
        const initialHeight = '500px';
        // Check the current display state of the iframe and toggle it
        if (iframe.style.height === '0px' || iframe.style.height === '') {
            iframe.style.height = initialHeight; // Animate to the initial height
            toggleButton.innerText = 'Hide YouBuddies';
        } else {
            iframe.style.height = '0px'; // Animate to height 0
            // Using a timeout to wait for the transition to finish before hiding the element
            setTimeout(() => {
                toggleButton.innerText = 'Show YouBuddies';
            }, 350); // The timeout duration should match the transition duration
        }
    };
    // Apply a transition to the height property
    iframe.style.transition = 'height 0.35s ease-in-out';

    // Insert the button just above the iframe
    wrapperDiv.insertBefore(toggleButton, iframe);

    targetDiv.insertAdjacentElement('afterend', wrapperDiv);
}

// Using MutationObserver to watch for changes in the DOM
const observer = new MutationObserver(function (mutations, me) {
    const targetDiv = document.getElementById('masthead-ad');
    if (targetDiv) {
        insertIframe();
        me.disconnect();
        return;
    }
});

// Start observing
observer.observe(document, {
    childList: true,
    subtree: true
});