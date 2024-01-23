// Initialize Firebase
const firebaseConfig = {
  apiKey: "AIzaSyCZ27QeqRNfDhF_LQioK0AjxhAwCGlaU",
  authDomain: "youbuddy-96438.firebaseapp.com",
  projectId: "youbuddy-96438",
  storageBucket: "youbuddy-96438.appspot.com",
  messagingSenderId: "963863199423",
  databaseURL: "https://youbuddy-96438-default-rtdb.firebaseio.com",
  appId: "1:963863199423:web:8a5f95110a5bf9f53f900a"
};

firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

// Listen for a message from bridge.html
window.addEventListener("message", function(event) {
  console.log("Message received in popup", event.data);
  if (event.data.action === "collectData") {
    const data = event.data.data;
    // yyyy_MM_dd_HH_mm_ss for document name
    const date = new Date();
    const datetimeString = date.toISOString().replace(/-|:/g, '_').replace(/\.\d{3}Z/g, '');
    db.collection("users")
      .doc(document.getElementById("username").value)
      .collection("youtubeRecommendations")
      .doc(datetimeString)  // Using datetime with underscores as document ID
      .set({ // Send recommendations to database
        recommendations: data.recommendations,
        topics: data.tabTexts,
        timestamp: firebase.firestore.FieldValue.serverTimestamp()
      })
      .then(() => {
        console.log("Document written with ID: ", datetimeString);
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