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
import {AppOptions, initializeApp} from "firebase-admin/app";
import {getFirestore, FieldValue} from "firebase-admin/firestore";

// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
import {logger} from "firebase-functions";

import {onSchedule} from "firebase-functions/v2/scheduler";
import {onDocumentCreated} from "firebase-functions/v2/firestore";

// Initialize Firebase
const firebaseConfig: AppOptions = {
  projectId: "youbuddy-96438",
  databaseURL: "https://youbuddy-96438-default-rtdb.firebaseio.com",
};

const app = initializeApp(firebaseConfig);
const db = getFirestore(app);

// Config from Google Cloud Project
const googleOAuthConfig = {
  clientSecret: "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",
  clientId: "963863199423-gq6l1ur7gtgg9li2o124j5hrn96th2c4.apps.googleusercontent.com",
};

/** Retrieve access tokens by exchanging refresh tokens in firebase
 * Google OAuth implementation can be seen at https://developers.google.com/identity/protocols/oauth2
 */
async function getAllAccessTokens() {
  const snapshot = await db.collection("tokens").get();
  const docs: any[] = [];
  snapshot.forEach((doc) => docs.push(doc));
  const accessTokens: Record<string, string> = {};

  for (const doc of docs) {
    const userId = doc.id;
    const refreshToken = doc.refreshToken;

    accessTokens[userId] = await getAccessToken(userId, refreshToken) || "";
  }

  return accessTokens;
}

async function getAccessToken(userId: string, refreshToken?: string): Promise<string | null> {
  const googleOAuthEndpoint = new URL("/token", "https://oauth2.googleapis.com");
  googleOAuthEndpoint.searchParams.set("client_secret", googleOAuthConfig.clientSecret);
  googleOAuthEndpoint.searchParams.set("client_id", googleOAuthConfig.clientId);
  googleOAuthEndpoint.searchParams.set("grant_type", "refresh_token");

  if (!refreshToken) {
    const snapshot = await db.collection("tokens").doc(userId).get();
    const doc = snapshot.data();
    if (doc === undefined) {
      logger.error(`Error retrieving token from db for ${userId}`);
      return null;
    }

    refreshToken = doc.refreshToken;
  }

  googleOAuthEndpoint.searchParams.set("refresh_token", <string>refreshToken);
  const response = await fetch(googleOAuthEndpoint, {
    method: "POST",
  });

  const data = await response.json();
  if (response.ok) {
    logger.log("Access token retrieved", JSON.stringify(data));
    return data.access_token;
  } else {
    logger.error(`Error retrieving access token: ${JSON.stringify(data)}`);
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
        recommendations: recommendations,
        topics: filterChipTexts,
        timestamp: FieldValue.serverTimestamp(),
      })
  );
}

const excluded_chips = ["N/A", "All", "Recently uploaded", "Watched", "New to you"];

async function collectRecsAllUsers(accessTokens: Record<string, string>) {
  const data: Record<string, any> = {};
  for (const [userId, accessToken] of Object.entries(accessTokens)) {
    data[userId] = await collectRecs(userId, accessToken);
  }

  return data;
}

async function collectRecs(userId: string, accessToken: string): Promise<{recommendations: any[], filterChipTexts: string[]}> {
  const youtubeUrl = "https://www.youtube.com";
  const browseEndpoint = "/youtubei/v1/browse";
  const browseUrl = new URL(browseEndpoint, youtubeUrl);
  const browseRequest = {
    "context": {
      "client": {
        "clientName": "WEB",
        "clientVersion": "2.20231101.05.00",
      },
    },
    "browseId": "FEwhat_to_watch",
  };

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
    const richGridRenderer = body?.contents?.twoColumnBrowseResultsRenderer?.tabs[0]?.tabRenderer?.content?.richGridRenderer;
    const items = richGridRenderer?.contents || [];
    const filterChips = richGridRenderer?.header?.feedFilterChipBarRenderer?.contents || [];
    const youtubeWatchUrl = "https://www.youtube.com/watch?v=";

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

        if (!addedRecs.has(JSON.stringify(newRec))) {
          recommendations.push(newRec);
          addedRecs.add(JSON.stringify(newRec));
        }
      }
    }

    // get filter chips
    for (const chip of filterChips) {
      const text = chip?.chipCloudChipRenderer?.text?.runs[0]?.text;
      if (text && !excluded_chips.includes(text)) {
        filterChipTexts.push(text);
      }
    }

    return {recommendations, filterChipTexts};
  } else {
    logger.error(`Error retrieving recommendations from innertube browse endpoint: ${await response.text()}`);
    return {recommendations, filterChipTexts};
  }
}

exports.collectRecsNewUser = onDocumentCreated("tokens/{userId}", async (event) => {
  logger.log(event.data?.id);
  logger.log(event.data?.data());
  const userId = event.data?.id || "";
  const refreshToken = event.data?.get("refreshToken") || "";
  const accessToken = await getAccessToken(userId, refreshToken);
  if (accessToken) {
    const data = await collectRecs(userId, accessToken);
    storeData(userId, data.recommendations, data.filterChipTexts).then(() => {
      logger.log(`Document ${userId} successfully written!`);
    })
      .catch((error) => {
        logger.error(`Error adding document ${userId}: `, error);
      });
  }
});

exports.collectRecsScheduled = onSchedule("every day 00:00", async (event) => {
  const accessTokens = await getAllAccessTokens();
  const data = await collectRecsAllUsers(accessTokens);
  for (const userId in data) {
    const userData = data[userId];
    storeData(userId, userData.recommendations, userData.filterChipTexts).then(() => {
      logger.log(`Document ${userId} successfully written!`);
    })
      .catch((error) => {
        logger.error(`Error adding document ${userId}: `, error);
      });
  }
});

