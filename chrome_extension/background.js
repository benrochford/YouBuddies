function collectRecommendations() {
  const recommendations = [];
  const addedTitles = new Set();
  const recommendationElements = document.querySelectorAll('.ytd-rich-grid-media');

  if (recommendationElements.length > 0) {
    recommendationElements.forEach((element) => {
      const titleElement = element.querySelector('.style-scope ytd-rich-grid-media a#video-title-link');
      const channelElement = element.querySelector('.style-scope ytd-rich-grid-media ytd-channel-name #text');
      const thumbnailElement = element.querySelector('.style-scope ytd-rich-grid-media ytd-thumbnail img');
      
      const title = titleElement ? titleElement.innerText : 'N/A';
      const link = titleElement ? titleElement.href : 'N/A';
      const channel = channelElement ? channelElement.innerText : 'N/A';
      const thumbnail = thumbnailElement ? thumbnailElement.src : 'N/A';

      if (title !== 'N/A' && !addedTitles.has(title)) {
        addedTitles.add(title);
        recommendations.push({
          title,
          link,
          channel,
          thumbnail
        });
      }
    });
  }
  return recommendations;
}

let recs = [];
const recsSet = new Set();
chrome.webNavigation.onDOMContentLoaded.addListener(async ({ tabId, url }) => {
  if (url === "https://www.youtube.com/") {
    chrome.scripting.executeScript({
      target: { tabId },
      func: collectRecommendations
    }).then(injectionResults => {
      const newRecs = injectionResults[0].result;
      for (const newRec of newRecs) {
        const recString = JSON.stringify(newRec);  // Convert object/array to string for comparison
        if (!recsSet.has(recString)) {
          recsSet.add(recString);
          recs.push(newRec);
        }
      }
    });
  }
});

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (request.action === "collectRecommendations") {
    sendResponse(recs);
  }
  return true; // Required for asynchronous response
});
