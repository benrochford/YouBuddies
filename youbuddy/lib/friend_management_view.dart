import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FriendManagementView extends StatefulWidget {
  final String clientId;
  FriendManagementView({required this.clientId});

  @override
  _FriendManagementViewState createState() => _FriendManagementViewState();
}

class _FriendManagementViewState extends State<FriendManagementView> {
  final _friendIdController = TextEditingController();

  Future<void> _addFriend({bool testing = true}) async {
    final friendId = _friendIdController.text;
    if (friendId.isNotEmpty) {
      final clientId = widget.clientId;

      // Bypass the database check if in testing mode
      if (testing) {
        _saveFriend(clientId, friendId);
        return;
      }

      // Check if friendId exists as a clientId in the database
      final friendExists = await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .get()
          .then((DocumentSnapshot documentSnapshot) {
        return documentSnapshot.exists;
      });

      if (friendExists) {
        _saveFriend(clientId, friendId);
      } else {
        print('Friend ID does not exist in the database.');
      }
    }
  }

  // Helper method to save friend
  void _saveFriend(String clientId, String friendId) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(clientId)
        .collection('friends')
        .doc(friendId)
        .set({'id': friendId});
  }

  @override
  Widget build(BuildContext context) {
    final clientId = widget.clientId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Follow Friends'),
      ),
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
                  .doc(clientId)
                  .collection('friends')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return CircularProgressIndicator();
                final friends = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friendId = friends[index]['id'];
                    return ListTile(
                      title: Text(friendId),
                      trailing: IconButton(
                        icon: Icon(Icons.delete),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(clientId)
                              .collection('friends')
                              .doc(friendId)
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
