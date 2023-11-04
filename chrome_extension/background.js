function injectAndToggleIframe() {

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
  // Check the current display state of the iframe and toggle it
  if (iframe.style.display === 'none') {
    iframe.style.display = 'block';
    toggleButton.innerText = 'Hide YouBuddies';
  } else {
    iframe.style.display = 'none';
    toggleButton.innerText = 'Show YouBuddies';
  }
  };
  // Insert the button just above the iframe
  wrapperDiv.insertBefore(toggleButton, iframe);

  targetDiv.insertAdjacentElement('afterend', wrapperDiv);
}

function collectData() {
  const recommendations = [];
  const addedTitles = new Set();
  const recommendationElements = document.querySelectorAll('.ytd-rich-grid-media');

  if (recommendationElements.length > 0) {
    recommendationElements.forEach((element) => {
      const titleElement = element.querySelector('.style-scope ytd-rich-grid-media a#video-title-link');
      const channelElement = element.querySelector('.style-scope ytd-rich-grid-media ytd-channel-name #text');

      const title = titleElement ? titleElement.innerText : 'N/A';
      const link = titleElement ? titleElement.href.split('&')[0] : 'N/A';
      const channel = channelElement ? channelElement.innerText : 'N/A';

      if (title !== 'N/A' && !addedTitles.has(title)) {
        addedTitles.add(title);
        recommendations.push({
          title,
          link,
          channel
        });
      }
    });
  }

  const tabTexts = [];
  const tabElements = document.querySelectorAll('yt-chip-cloud-chip-renderer yt-formatted-string');

  tabElements.forEach((element) => {
    const topic = element.innerText || 'N/A';
    bad = ['N/A', 'All', 'Recently uploaded', 'Watched', 'New to you']
    if (!bad.includes(topic)) {
      tabTexts.push(topic);
    }
  });

  return { recommendations, tabTexts };
}

let data = { recommendations: [], tabTexts: [] };
const dataSet = new Set();

chrome.webNavigation.onDOMContentLoaded.addListener(async ({ tabId, url }) => {
  if (url === "https://www.youtube.com/") {
    chrome.scripting.executeScript({
      target: { tabId },
      func: collectData
    }).then(injectionResults => {
      const newData = injectionResults[0].result;
      const newRecs = newData.recommendations;
      const newTabTexts = newData.tabTexts;

      for (const newRec of newRecs) {
        const recString = JSON.stringify(newRec);
        if (!dataSet.has(recString)) {
          dataSet.add(recString);
          data.recommendations.push(newRec);
        }
      }

      data.tabTexts = newTabTexts;
    });

    chrome.scripting.executeScript({
      target: { tabId },
      function: injectAndToggleIframe
    });
  }
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "collectData") {
    sendResponse(data);
  }
  return true; // Required for asynchronous response
});
