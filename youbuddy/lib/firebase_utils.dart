import 'package:cloud_firestore/cloud_firestore.dart';

Future<Map<String, dynamic>?> getUserProfile(String clientId) async {
  var snapshot =
      await FirebaseFirestore.instance.collection('users').doc(clientId).get();

  if (snapshot.exists) {
    final profile = snapshot.data()!;
    return profile;
  }
  return null;
}

Future<String?> getUserFromFriendID(String friendId) async {
  var snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('friendId', isEqualTo: friendId)
      .get();

  if (snapshot.docs.isNotEmpty) return snapshot.docs.first.id;
  return null;
}
