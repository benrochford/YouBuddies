import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:youbuddy/firebase_utils.dart';

import 'models.dart';

class FriendManagementView extends StatefulWidget {
  final User currentUser;

  FriendManagementView({required this.currentUser});

  @override
  _FriendManagementViewState createState() => _FriendManagementViewState();
}

class _FriendManagementViewState extends State<FriendManagementView> {
  final _friendIdController = TextEditingController();

  Map<String, User> friendProfiles = {};
  // Fetch and update friend profiles
  Future<void> fetchFriendProfiles(List friends) async {
    Map<String, User> profiles = {};
    for (var friend in friends) {
      final user = await getUserProfile(friend.id);
      if (user != null) {
        profiles[friend.id] = user;
      }
    }
    if (mounted) {
      setState(() {
        friendProfiles = profiles;
      });
    }
  }

  Future<void> _addFriend({bool testing = false}) async {
    final friendId = _friendIdController.text;
    if (friendId.isNotEmpty) {
      // Check if friendId exists as a clientId in the database
      final user = await getUserFromFriendID(friendId);

      // Bypass the database check if in testing mode
      if (testing) {
        _saveFriend(user!);
        return;
      }

      if (user != null) {
        _saveFriend(user);
      } else {
        print('Friend ID does not exist in the database.');
      }
    }
  }

  // Helper method to save friend
  void _saveFriend(User user) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(user.ref.id)
        .collection('friends')
        .doc(user.ref.id)
        .set({'profile': user.ref});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Follow Buddies'), actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SelectableText.rich(
              TextSpan(text: 'Your Buddy Tag: ', children: [
                TextSpan(
                    text: widget.currentUser.friendId,
                    style: TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.currentUser.friendId));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Buddy Tag copied to clipboard!')));
                      })
              ]),
            ),
          ),
        )
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _friendIdController,
              decoration: InputDecoration(
                labelText: 'Enter a Buddy Tag to follow',
              ),
              onSubmitted: (_) => _addFriend(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: widget.currentUser.ref
                  .collection('friends')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                final friends = snapshot.data!.docs;

                fetchFriendProfiles(friends);

                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendUID = friends[index]['id'];
                    final profile = friendProfiles[friendUID];

                    return ListTile(
                      title: Text(
                          profile != null ? profile.name : 'Loading...'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          widget.currentUser.ref
                              .collection('friends')
                              .doc(friendUID)
                              .delete();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFriend,
        child: Icon(Icons.add),
      ),
    );
  }
}
