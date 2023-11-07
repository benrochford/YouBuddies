import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:youbuddy/firebase_utils.dart';

class FriendManagementView extends StatefulWidget {
  final String clientId;
  final String clientFriendId;

  FriendManagementView({required this.clientId, required this.clientFriendId});

  @override
  _FriendManagementViewState createState() => _FriendManagementViewState();
}

class _FriendManagementViewState extends State<FriendManagementView> {
  final _friendIdController = TextEditingController();

  Map<String, dynamic> friendProfiles = {};
  // Fetch and update friend profiles
  Future<void> fetchFriendProfiles(List friends) async {
    Map<String, dynamic> profiles = {};
    for (var friend in friends) {
      final friendUID = friend['id'];
      final profileData = await getUserProfile(friendUID);
      profiles[friendUID] = profileData;
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
      final clientId = widget.clientId;

      // Bypass the database check if in testing mode
      if (testing) {
        _saveFriend(clientId, friendId);
        return;
      }

      // Check if friendId exists as a clientId in the database
      final friendUID = await getUserFromFriendID(friendId);

      if (friendUID != null) {
        _saveFriend(clientId, friendUID);
      } else {
        print('Friend ID does not exist in the database.');
      }
    }
  }

  // Helper method to save friend
  void _saveFriend(String clientId, String friendUID) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(clientId)
        .collection('friends')
        .doc(friendUID)
        .set({'id': friendUID});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Follow Friends'), actions: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SelectableText.rich(
              TextSpan(text: 'Your Friend ID: ', children: [
                TextSpan(
                    text: widget.clientFriendId,
                    style: TextStyle(color: Colors.blue),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () async {
                        await Clipboard.setData(
                            ClipboardData(text: widget.clientFriendId));
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Friend ID copied to clipboard!')));
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
                labelText: 'Enter Friend ID to follow',
              ),
              onSubmitted: (_) => _addFriend(),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.clientId)
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
                          profile != null ? profile['name'] : 'Loading...'),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.clientId)
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
