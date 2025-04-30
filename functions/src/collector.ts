/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// The Firebase Admin SDK to access Firestore.
import serviceAccount from "../firebase-adminsdk-key.json";
import googleOAuthConfigFile from "../google_oauth_keys.json";
import {credential} from "firebase-admin";
import {AppOptions, initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

import { Innertube, BrowseRequest, Parser, YTNodes, Continuation } from 'youtubei.js';

const cert = {
  projectId: serviceAccount.project_id,
  clientEmail: serviceAccount.client_email,
  privateKey: serviceAccount.private_key
};

// Initialize Firebase
const firebaseConfig: AppOptions = {
  projectId: "youbuddy-96438",
  databaseURL: "https://youbuddy-96438-default-rtdb.firebaseio.com",
  credential: credential.cert(cert)
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Config from Google Cloud Project
const googleOAuthConfig: Record<string, any> = googleOAuthConfigFile;

const youtubeUrl = "https://www.youtube.com";
const browseEndpoint = "/youtubei/v1/browse";
const browseUrl = new URL(browseEndpoint, youtubeUrl);
const browseRequest = {
  "context": {
      "client": {
          "clientName": "TVHTML5",
          "clientVersion": "7.20241016.15.00"
      }
  },
  "browseId": "FEwhat_to_watch",
};
const youtubeWatchUrl = "https://www.youtube.com/watch?v=";
const NUM_VIDEOS = 21;

/** Retrieve access tokens by exchanging refresh tokens in firebase
 * Google OAuth implementation can be seen at https://developers.google.com/identity/protocols/oauth2
 */
async function getAllAccessTokens() {
  const snapshot = await db.collection("tokens").get();
  const docs: any[] = [];
  snapshot.forEach((doc) => docs.push(doc));
  const accessTokens: Record<string, any> = {};

  for (const doc of docs) {
    const userId = doc.id;
    const data = doc.data();
    const refreshToken = data.refreshToken;
    const platform = data.platform;
    
    accessTokens[userId] = await getAccessToken(userId, platform, refreshToken) || "";
  }

  return accessTokens;
}

async function getAccessToken(userId: string, platform?: string, refreshToken?: string): Promise<Record<string, string> | null> {
  const googleOAuthEndpoint = new URL("/token", "https://oauth2.googleapis.com");
  googleOAuthEndpoint.searchParams.set("grant_type", "refresh_token");

  if (!refreshToken || !platform) {
    const snapshot = await db.collection("tokens").doc(userId).get();
    const doc = snapshot.data();
    if (doc === undefined) {
      console.error(`Error retrieving token from db for ${userId}`);
      return null;
    }

    refreshToken = doc.refreshToken;
    platform = doc.platform;
  }
  
  // if clientSecret is undefined (intended for android and ios) put empty string to pass auth
  googleOAuthEndpoint.searchParams.set("client_secret", googleOAuthConfig[platform!].clientSecret || "");
  googleOAuthEndpoint.searchParams.set("client_id", googleOAuthConfig[platform!].clientId);
  googleOAuthEndpoint.searchParams.set("refresh_token", <string>refreshToken);
  
  const response = await fetch(googleOAuthEndpoint, {
    method: "POST",
  });

  const data = await response.json();
  if (response.ok) {
    console.log(`Access token retrieved for ${userId}`);
    return {accessToken: <string>data.access_token, refreshToken: refreshToken!};
  } else {
    console.error(`Error retrieving access token for ${userId}: ${JSON.stringify(data)}`);
    return null;
  }
}

function storeData(userId: string, recommendations: any[], filterChipTexts: string[]) {
  // yyyy_MM_dd_HH_mm_ss for document name
  const date = new Date();
  const datetimeString = date.toISOString().replace(/-|:/g, "_").replace(/\.\d{3}Z/g, "");

  return (
    db.collection("users")
      .doc(userId)
      .collection("youtubeRecommendations")
      .doc(datetimeString) // Using datetime with underscores as document ID
      .set({ // Send recommendations to database
        clientName: browseRequest.context.client.clientName,
        recommendations: recommendations,
        topics: filterChipTexts,
        timestamp: FieldValue.serverTimestamp(),
      })
  );
}

const excluded_chips = ["N/A", "All", "Recently uploaded", "Watched", "New to you"];

async function collectRecsAllUsers(tokens: Record<string, any>) {
  const data: Record<string, any> = {};
  for (const [userId, token] of Object.entries(tokens)) {
    data[userId] = await collectRecs(userId, token.accessToken);
  }

  return data;
}

async function collectRecs(userId: string, accessToken: string): Promise<{recommendations: any[], filterChipTexts: string[]}> {
  const recommendations: any[] = [];
  const addedRecs = new Set();
  const filterChipTexts: string[] = [];

  const response = await fetch(browseUrl, {
    method: "POST",
    headers: {
      "Authorization": "Bearer " + accessToken,
    },
    body: JSON.stringify(browseRequest),
  });
 
  if (response.ok) {
    const body = await response.json();

    const videoGenerator = parseTVResponseVideos(body, accessToken);

    for (let i = 0; i < NUM_VIDEOS; i++) {
      const video = (await videoGenerator.next()).value;


      if (!addedRecs.has(JSON.stringify(video))) {
        recommendations.push(video);
        addedRecs.add(JSON.stringify(video));
      }
    }

    // for (const text of parseTVResponseFilterChips(body)) {
    //   if (text && !excluded_chips.includes(text)) {
    //     filterChipTexts.push(text);
    //   }
    // }
    
  } else {
    console.error(`Error retrieving recommendations from innertube browse endpoint: ${await response.text()}`);
  }

  return {recommendations, filterChipTexts};
}

async function* parseTVResponseVideos(body: any, accessToken: string) {
  const tvContentRenderer = body.contents.tvBrowseRenderer.content.tvSurfaceContentRenderer;
  let recommendedShelf;
  
  for (const content of tvContentRenderer.content.sectionListRenderer.contents) {
    const category = content.shelfRenderer?.headerRenderer.shelfHeaderRenderer.avatarLockup.avatarLockupRenderer.title.runs?.[0].text;

    if (category == "Recommended") {
      recommendedShelf = content.shelfRenderer;
    }
  }

  let horizontalList = recommendedShelf?.content.horizontalListRenderer;
  while (true) {
    if (horizontalList) {
      for (const item of horizontalList.items) {
        // videos have tileRenderer while ads have adSlotRenderer
        const tileRenderer = item?.tileRenderer;

        if (tileRenderer && tileRenderer.contentType == 'TILE_CONTENT_TYPE_VIDEO') {
          const title = tileRenderer.metadata.tileMetadataRenderer.title.simpleText;
          const videoId = tileRenderer.onSelectCommand.watchEndpoint?.videoId;
          if (videoId) { // movies do not have videoId
            const channelInfo = tileRenderer.metadata.tileMetadataRenderer.lines[0].lineRenderer.items[0].lineItemRenderer.text;
            const channel = channelInfo.runs?.[0].text || channelInfo.simpleText;
            const newRec = {
              "title": title || "<no title found>",
              "link": youtubeWatchUrl + videoId,
              "channel": channel || "<no channel found>",
            };

            yield newRec;
          }
        }
      }
    }

    // continue request to fetch more videos
    const continuationRequest = {
      ...browseRequest,
      continuation: horizontalList.continuations[0].nextContinuationData.continuation
    }

    const response = await fetch(browseUrl, {
      method: "POST",
      headers: {
        "Authorization": "Bearer " + accessToken,
      },
      body: JSON.stringify(continuationRequest),
    });
  
    if (response.ok) {
      const body = await response.json();
      horizontalList = body.continuationContents.horizontalListContinuation;
    } else {
      console.error("Continuation request failed");
      break
    }
  }
}

function* parseDesktopResponseVideos(body: any) {
  const richGridRenderer = body?.contents?.twoColumnBrowseResultsRenderer?.tabs[0]?.tabRenderer?.content?.richGridRenderer;
  const items = richGridRenderer?.contents || [];

  // get videos
  for (const item of items) {
    // ad items have adSlotRenderer and items to trigger next query have continuationItemRenderer
    const video = item?.richItemRenderer?.content?.videoRenderer;

    // ensure real video
    if (video) {
      const newRec = {
        "title": video?.title?.runs[0]?.text || "<no title found>",
        "link": youtubeWatchUrl + video?.videoId,
        "channel": video?.ownerText?.runs[0]?.text || "<no channel found>",
      };

      yield newRec;
    }
  }
}

function* parseDesktopResponseFilterChips(body: any) {
  const richGridRenderer = body?.contents?.twoColumnBrowseResultsRenderer?.tabs[0]?.tabRenderer?.content?.richGridRenderer;
  const filterChips = richGridRenderer?.header?.feedFilterChipBarRenderer?.contents || [];

  // get filter chips
  for (const chip of filterChips) {
    const text = chip?.chipCloudChipRenderer?.text?.runs[0]?.text;
    if (text) {
      yield text;
    }
  }
}

async function collectRecsYoutubei(userId: string, accessToken: string, refreshToken: string): Promise<{recommendations: any[], filterChipTexts: string[]}> {
  const innertube = await Innertube.create();
  await innertube.session.signIn({
    access_token: accessToken,
    refresh_token: refreshToken,
    expiry_date: new Date(8640000000000000).toISOString(),
  });

  console.log('logged in');

  const browseRequest: BrowseRequest = {
    "browseId": "FEwhat_to_watch",
  };
  
  const recommendations: any[] = [];
  const addedRecs = new Set();
  const filterChipTexts: string[] = [];
  const response = await innertube.actions.execute<'/browse'>('/browse', {
    ...browseRequest,
    parse: true
  });
 
  console.log(response);
  console.log(JSON.stringify(response));
  if (response) {
    // const body = await response.json();
    const richGridRenderer = response.contents?.item().as(YTNodes.TwoColumnBrowseResults).tabs[0].as(YTNodes.Tab).content?.as(YTNodes.RichGrid);
    const items = richGridRenderer?.contents || [];
    const filterChips = richGridRenderer?.header.as(YTNodes.FeedFilterChipBar).contents || [];

    // get videos
    for (const item of items) {
      // ad items have adSlotRenderer and items to trigger next query have continuationItemRenderer
      const video = item?.as(YTNodes.RichItem).content?.as(YTNodes.Video);

      // ensure real video
      if (video) {
        const newRec = {
          "title": video.title.runs?.[0].text || "<no title found>",
          "link": youtubeWatchUrl + video.id,
          "channel": video.author.name || "<no channel found>",
        };

        if (!addedRecs.has(JSON.stringify(newRec))) {
          recommendations.push(newRec);
          addedRecs.add(JSON.stringify(newRec));
        }
      }
    }

    // get filter chips
    for (const chip of filterChips) {
      const text = chip.text;
      if (text && !excluded_chips.includes(text)) {
        filterChipTexts.push(text);
      }
    }


    return {recommendations, filterChipTexts};
  } else {
    console.error(`Error retrieving recommendations from innertube browse endpoint: ${JSON.stringify(response)}`);
    return {recommendations, filterChipTexts};
  }
}

export async function collectRecsUser(userId: string) {
   console.log(new Date().toUTCString());
   const tokens = await getAccessToken(userId);
   if (tokens) {
     const data = await collectRecs(userId, tokens.accessToken);
     storeData(userId, data.recommendations, data.filterChipTexts)
       .then(() => console.log(`Document ${userId} successfully written!\n`))
       .catch(error => console.error(`Error adding document ${userId}: `, error, '\n'));
   }
}

export async function collectAllRecs() {
  console.log(new Date().toUTCString());
  getAllAccessTokens().then(accessTokens => {
    collectRecsAllUsers(accessTokens).then(data => {
      const promises: Promise<void>[] = Object.entries(data).map(([userId, userData]) => 
        storeData(userId, userData.recommendations, userData.filterChipTexts)
          .then(() => console.log(`Document ${userId} successfully written!`))
          .catch(error => console.error(`Error adding document ${userId}: `, error)));
      
      Promise.all(promises).then(() => console.log());
    });
  });
}

