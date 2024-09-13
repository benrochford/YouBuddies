import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'models.dart';

Future<User?> getUserProfile(String userId) async {
  var snapshot = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .withConverter<User>(
          fromFirestore: User.fromFirestore, toFirestore: User.toFirestore)
      .get();

  if (snapshot.exists) {
    final profile = snapshot.data()!;
    return profile;
  }
  log("Could not get user with id: $userId}");
  return null;
}

Future<User?> getUserFromFriendID(String friendId) async {
  var snapshot = await FirebaseFirestore.instance
      .collection('users')
      .withConverter<User>(
          fromFirestore: User.fromFirestore, toFirestore: User.toFirestore)
      .where('friendId', isEqualTo: friendId)
      .get();

  if (snapshot.docs.isNotEmpty) return snapshot.docs.first.data();
  return null;
}

Future<List<User>> fetchFriends(User user) async {
  final friendsDoc = await user.ref.collection('friends').get();

  List<User> friends = [];
  for (var doc in friendsDoc.docs) {
    var snapshot = await doc
        .data()['profile']
        .withConverter<User>(
            fromFirestore: User.fromFirestore, toFirestore: User.toFirestore)
        .get();

    friends.add(snapshot.data()!);
  }

  return friends;
}

Future<List<Recommendations>> fetchRecommendations(User user,
    {int? limit}) async {
  var query = user.ref
      .collection('youtubeRecommendations')
      .withConverter<Recommendations>(
          fromFirestore: Recommendations.fromFirestore,
          toFirestore: Recommendations.toFirestore)
      .orderBy('timestamp', descending: true);

  if (limit != null) {
    query = query.limit(limit);
  }
  final querySnapshot = await query.get();

  return querySnapshot.docs.map((doc) => doc.data()).toList();
}
