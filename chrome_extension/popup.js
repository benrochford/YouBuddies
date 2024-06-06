// Initialize Firebase
const firebaseConfig = {
  apiKey: "AIzaSyCZ27QeqRNfDhF_LQioK0AjxhAwCGlaU-M",
  authDomain: "youbuddy-96438.firebaseapp.com",
  projectId: "youbuddy-96438",
  storageBucket: "youbuddy-96438.appspot.com",
  messagingSenderId: "963863199423",
  databaseURL: "https://youbuddy-96438-default-rtdb.firebaseio.com",
  appId: "1:963863199423:web:8a5f95110a5bf9f53f900a"
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

const googleOAuthConfig = {
  "client_id": "963863199423-gq6l1ur7gtgg9li2o124j5hrn96th2c4.apps.googleusercontent.com",
  "client_secret": "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",
  "scopes": [
    "https://www.googleapis.com/auth/youtube",
    "openid"
  ]
}

if (!firebase.auth().currentUser) {
  document.getElementById("status").innerHTML = "Status: Login to collect recommendation with one click!";
}

setLoginButton()

function setLoginButton() {
  const loginButton = document.getElementById("login");
  if (firebase.auth().currentUser) {
    loginButton.addEventListener("click", () =>
      firebase.auth()
        .signOut()
        .then(() => setLoginButton())
        .catch((error) => {
          console.log("Error logging in", error.message)
    }));
    document.getElementById("status").innerHTML = "Status: ready. Click to update all user recommendations!";
  } else {
    loginButton.addEventListener("click", () =>
    {
      document.getElementById("bridge").contentWindow.postMessage({action: "login"}, "*");
      setLoginButton();
    });
  }

  loginButton.innerHTML = firebase.auth().currentUser ? "Log out" : "Login";
}

/** Retrieve access tokens by exchanging refresh tokens in firebase
 * Google OAuth implementation can be seen at https://developers.google.com/identity/protocols/oauth2
 */
async function getOAuthTokens() {
  const googleOAuthEndpoint = new URL("/token", "https://oauth2.googleapis.com");
  googleOAuthEndpoint.searchParams.set("client_secret", googleOAuthConfig.client_secret);
  googleOAuthEndpoint.searchParams.set("client_id", googleOAuthConfig.client_id);
  googleOAuthEndpoint.searchParams.set("grant_type", "refresh_token");

  const snapshot = await db.collection('tokens').get();
  const docs = [];
  snapshot.forEach((doc) => docs.push(doc))
  let accessTokens = {};

  for (const doc of docs) {
    const userId = doc.id;
    const refreshToken = doc.data().refreshToken;
    if (refreshToken) {
      googleOAuthEndpoint.searchParams.set("refresh_token", refreshToken);
      const response = await fetch(googleOAuthEndpoint, {
        method: "POST",
      });

      const data = await response.json();
      if (response.ok) {
        accessTokens[userId] = data['access_token'];
        console.error("Access token retrieved");
      } else {
        console.error(`Error retrieving access token: ${JSON.stringify(data)}`);
      }
    }
  }

  return accessTokens;
}

function storeData(userId, { recommendations, filterChipTexts }) {
  // yyyy_MM_dd_HH_mm_ss for document name
  const date = new Date();
  const datetimeString = date.toISOString().replace(/-|:/g, '_').replace(/\.\d{3}Z/g, '');

  return (
    db.collection("users")
      .doc(userId)
      .collection("youtubeRecommendations")
      .doc(datetimeString)  // Using datetime with underscores as document ID
      .set({ // Send recommendations to database
        recommendations: recommendations,
        topics: filterChipTexts,
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      })
  );
}

// Listen for a message from bridge.html
window.addEventListener("message", function(event) {
  console.log("Message received in popup", event.data);
  let writePromise;
  if (event.data.action === "collectData") {
    writePromise = storeData(document.getElementById("username").value, event.data.data)
  } else if (event.data.action === "collectAllUserData") {
    // promise completes after all storage calls
    writePromise = Promise.all(Object.entries(event.data.data).map(([userId, data]) => storeData(userId, data)));
  } else if (event.data.action === "login") {
    const result = event.data.token;
    const accessToken = result.access_token;
    const refreshToken = result.refresh_token;
    const credential = firebase.auth.GoogleAuthProvider.credential(null, accessToken);

    firebase.auth()
      .signInWithCredential(credential)
      .then((result) => {
        const user = result.user;
        if (user) {
          const credential = result.credential;
          setLoginButton();
          if (refreshToken) {
            db.collection("tokens")
              .doc(user.uid)
              .update({"refreshToken": refreshToken});
          }
        }
      }).catch((error) => {
        console.error("Error signing in with Google", error.message);
        document.getElementById("status").innerHTML = "Status: Error logging in";
    });
  }

  if (writePromise) {
    writePromise
      .then(() => {
        console.log("Document(s) successfully written!");
        document.getElementById("status").innerHTML = "Status: recommendations saved by YouBuddies!";
      })
      .catch((error) => {
        console.error("Error adding document: ", error);
      });
  }
});

// Send a message to bridge.html
document.getElementById("collect").addEventListener("click", () => {
  const username = document.getElementById("username").value;
  if (username) {
    document.getElementById("bridge").contentWindow.postMessage({action: "collectData", username: username}, "*");
    document.getElementById("status").innerHTML = "Status: collecting";
  } else {
    console.error("Username is required.");
  }
});

document.getElementById("collectAll").addEventListener("click", async () => {
  document.getElementById("bridge").contentWindow.postMessage({action: "collectAllUserData", oauthTokens: await getOAuthTokens()}, "*");
  document.getElementById("status").innerHTML = "Status: collecting";
});