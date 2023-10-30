import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class RecommendationView extends StatefulWidget {
  final String clientId;
  RecommendationView({required this.clientId});

  @override
  _RecommendationViewState createState() => _RecommendationViewState();
}

class _RecommendationViewState extends State<RecommendationView>
    with SingleTickerProviderStateMixin {
  // mixin gives tick for animation
  Map<String, bool> expansionStateMap = {};
  late Animation<Offset> _slideAnimation;

  // animation stuff for funny empty list icon
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _slideAnimation = Tween<Offset>(
      begin: Offset(-0.1, 0.0),
      end: Offset(0.1, 0.0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<String>> fetchFriends() async {
    final friendsDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .collection('friends')
        .get();

    return friendsDoc.docs.map((doc) => doc.id).toList();
  }

  Future<Map<String, List<Map<String, dynamic>>>>
      fetchRecommendationsFromFriends(List<String> friends) async {
    Map<String, List<Map<String, dynamic>>> friendRecommendationsMap = {};
    for (String friend in friends) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(friend)
          .collection('youtubeRecommendations')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final recentRecommendationsDoc = querySnapshot.docs.first.data();
        if (recentRecommendationsDoc.containsKey('recommendations')) {
          final friendRecommendations =
              (recentRecommendationsDoc['recommendations'] as List)
                  .map((r) => r as Map<String, dynamic>)
                  .toList();
          friendRecommendationsMap[friend] = friendRecommendations;
        }
      }
    }

    return friendRecommendationsMap;
  }

  List<Widget> buildRecommendationList(
      List<Map<String, dynamic>> recommendations) {
    if (recommendations.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SlideTransition(
                    position: _slideAnimation,
                    child: Text(
                      "👻",
                      style: TextStyle(
                        fontSize: 25.0,
                        color: Colors.grey,
                      ),
                    )),
                SizedBox(width: 12.0),
                Text(
                  "nothing!",
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    return recommendations.map((recommendation) {
      return ListTile(
        title: Text(recommendation['title']),
        subtitle: InkWell(
          onTap: () async {
            final url = Uri.parse(recommendation['link']);
            if (await canLaunchUrl(url)) {
              await launchUrl(url);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unable to open link')),
              );
            }
          },
          child: Text(
            recommendation['link'],
            style: TextStyle(
                color: Colors.blue, decoration: TextDecoration.underline),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: fetchFriends(),
      builder: (context, friendsSnapshot) {
        if (!friendsSnapshot.hasData) {
          return CircularProgressIndicator();
        }

        final friendsList = friendsSnapshot.data!;
        return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: fetchRecommendationsFromFriends(friendsList),
          builder: (context, recommendationsSnapshot) {
            if (!recommendationsSnapshot.hasData) {
              return CircularProgressIndicator();
            }

            final recommendationsMap = recommendationsSnapshot.data!;

            return Scaffold(
              appBar: AppBar(
                title: Text('YouTube Recommendations from Friends'),
              ),
              body: ListView.builder(
                  itemCount: friendsList.length,
                  itemBuilder: (context, index) {
                    final friendName = friendsList[index];
                    final recommendations = recommendationsMap[friendName];

                    return ExpansionTile(
                      title: Text(
                        friendName,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      initiallyExpanded: expansionStateMap[friendName] ?? false,
                      onExpansionChanged: (bool isExpanded) {
                        setState(() {
                          expansionStateMap[friendName] = isExpanded;
                        });
                      },
                      children: buildRecommendationList(recommendations ?? []),
                    );
                  }),
            );
          },
        );
      },
    );
  }
}
