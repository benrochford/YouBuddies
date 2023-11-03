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
  }
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "collectData") {
    sendResponse(data);
  }
  return true; // Required for asynchronous response
});
