import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';

import 'package:youbuddy/firebase_utils.dart';

class RecommendationView extends StatefulWidget {
  final String clientId;

  RecommendationView({required this.clientId});

  @override
  _RecommendationViewState createState() => _RecommendationViewState();
}

class _RecommendationViewState extends State<RecommendationView>
    with TickerProviderStateMixin {
  // mixin gives tick for animation
  Map<String, bool> expansionStateMap = {};
  late Animation<Offset> _slideAnimation;
  late AnimationController _textGradientController;

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

    _textGradientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _textGradientController.dispose();
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

  Future<List<Map<String, dynamic>>> fetchFriendRecommendations(
      String friendId) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(friendId)
        .collection('youtubeRecommendations')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final recentRecommendationsDoc = querySnapshot.docs.first.data();
      if (recentRecommendationsDoc.containsKey('recommendations')) {
        return (recentRecommendationsDoc['recommendations'] as List)
            .map((r) => r as Map<String, dynamic>)
            .toList();
      }
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchCurrentUserRecommendations() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .collection('youtubeRecommendations')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final recentRecommendationsDoc = querySnapshot.docs.first.data();
      if (recentRecommendationsDoc.containsKey('recommendations')) {
        return (recentRecommendationsDoc['recommendations'] as List)
            .map((r) => r as Map<String, dynamic>)
            .toList();
      }
    }
    return [];
  }

  Future<Map<String, Map<String, dynamic>>> findCommonRecommendations(
      List<String> friends) async {
    Map<String, Map<String, dynamic>> commonRecsMap = {};

    // Initialize commonRecsMap with current user's recommendations
    final currentUserRecs = await fetchCurrentUserRecommendations();
    for (var rec in currentUserRecs) {
      commonRecsMap[rec['link']] = {
        'count': 1,
        'title': rec['title'],
        'link': rec['link'],
        'channel': rec['channel'],
        'friendUsernames': ['You!'],
      };
    }

    for (String friend in friends) {
      final friendRecs = await fetchFriendRecommendations(friend);
      for (var rec in friendRecs) {
        if (commonRecsMap.containsKey(rec['link'])) {
          if (commonRecsMap[rec['link']]?['count'] != null) {
            commonRecsMap[rec['link']]!['count'] += 1;
            commonRecsMap[rec['link']]!['friendUsernames'].add(friend);
          }
        } else {
          commonRecsMap[rec['link']] = {
            'count': 1,
            'title': rec['title'],
            'link': rec['link'],
            'channel': rec['channel'],
            'friendUsernames': [friend],
          };
        }
      }
    }

    // return commonRecsMap;  // uncomment to include recs got by only 1 person
    return Map.fromEntries(
        commonRecsMap.entries.where((e) => e.value['count'] >= 2));
  }

  Widget buildCommonRecommendationsWidget(
      Map<String, Map<String, dynamic>> commonRecsMap) {
    List<Widget> commonRecsList = [];

    // Null check and sorting
    if (commonRecsMap.isNotEmpty) {
      var sortedKeys = commonRecsMap.keys.toList(growable: false);
      sortedKeys.sort((k1, k2) {
        return (commonRecsMap[k2]?['count'] ?? 0)
            .compareTo(commonRecsMap[k1]?['count'] ?? 0);
      });

      // Take top 30 or fewer if not available
      for (var i = 0; i < min(30, sortedKeys.length); i++) {
        String url = sortedKeys[i];
        Map<String, dynamic>? details = commonRecsMap[url];
        if (details != null) {
          String title = details['title'] ?? 'Unknown title';
          String thumbnailUrl = "https://img.youtube.com/vi/" +
              details['link'].toString().split('?v=')[1] +
              "/0.jpg";

          commonRecsList.add(InkWell(
            onTap: () async {
              final urlObj = Uri.parse(url);
              if (await canLaunchUrl(urlObj)) {
                await launchUrl(urlObj);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unable to open link')),
                );
              }
            },
            child: ListTile(
              leading: Container(
                width: 56.0,
                height: 32.0,
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: NetworkImage(thumbnailUrl),
                  ),
                ),
              ),
              title: Text(title),
              subtitle: Text(details['channel'] ?? 'Unknown channel'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(details['count'].toString()),
                  IconButton(
                    icon: Icon(Icons.people),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            content: SingleChildScrollView(
                              child: Column(
                                children: List<Widget>.generate(
                                    details['friendUsernames'].length,
                                    (int index) => Text(
                                        details['friendUsernames'][index])),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ));
        }
      }
    }
    // Animated cool text for shared recs
    return ExpansionTile(
      title: AnimatedBuilder(
        animation: _textGradientController,
        builder: (context, _) {
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                colors: [
                  const Color.fromARGB(255, 72, 168, 246),
                  Color.fromARGB(255, 243, 98, 166),
                  Color.fromARGB(255, 81, 72, 246),
                ],
                stops: [
                  _textGradientController.value - 1,
                  _textGradientController.value,
                  _textGradientController.value + 1,
                ],
                tileMode: TileMode.repeated,
              ).createShader(bounds);
            },
            child: Text(
              'Shared Recommendations',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          );
        },
      ),
      children: commonRecsList,
    );
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
      String thumbnailUrl = "https://img.youtube.com/vi/" +
          recommendation['link'].toString().split('?v=')[1] +
          "/0.jpg";

      final url = Uri.parse(recommendation['link']);
      return InkWell(
        onTap: () async {
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to open link')),
            );
          }
        },
        child: ListTile(
          leading: Container(
            width: 56.0,
            height: 32.0,
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(thumbnailUrl),
              ),
            ),
          ),
          title: Text(recommendation['title']),
          subtitle: Text(recommendation['channel'] ?? 'Unknown channel'),
        ),
      );
    }).toList();
  }

  Map<String, String> _friendNamesCache = {};

  Future<void> _fetchAndCacheFriendNames(List<String> friendUIDs) async {
    for (var uid in friendUIDs) {
      if (!_friendNamesCache.containsKey(uid)) {
        try {
          final userProfile = await getUserProfile(uid);
          _friendNamesCache[uid] =
              userProfile?['name'] ?? '<Could not find friend name>';
        } catch (e) {
          _friendNamesCache[uid] = '<Could not find friend name>';
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: fetchFriends(),
      builder: (context, friendsSnapshot) {
        if (!friendsSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final friendsList = friendsSnapshot.data!;
        _fetchAndCacheFriendNames(friendsList);

        return FutureBuilder<List<Map<String, dynamic>>>(
            future: Future.wait([
              fetchRecommendationsFromFriends(friendsList),
              findCommonRecommendations(friendsList)
            ]),
            builder: (context, recommendationsSnapshot) {
              if (!recommendationsSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final recommendationsMap = recommendationsSnapshot.data![0]
                  as Map<String, List<Map<String, dynamic>>>;
              final commonRecsMap = recommendationsSnapshot.data![1]
                  as Map<String, Map<String, dynamic>>;

              return Scaffold(
                appBar: AppBar(
                  title: Text('Recommendations from friends'),
                ),
                body: ListView(
                  children: [
                    buildCommonRecommendationsWidget(commonRecsMap),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: friendsList.length,
                      itemBuilder: (context, index) {
                        final friendUID = friendsList[index];
                        final recommendations = recommendationsMap[friendUID];
                        final friendName =
                            _friendNamesCache[friendUID] ?? 'Loading...';
                        return ExpansionTile(
                          title: Text(
                            friendName,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          initiallyExpanded:
                              expansionStateMap[friendUID] ?? false,
                          onExpansionChanged: (bool isExpanded) {
                            setState(() {
                              expansionStateMap[friendUID] = isExpanded;
                            });
                          },
                          children:
                              buildRecommendationList(recommendations ?? []),
                        );
                      },
                    )
                  ],
                ),
              );
            });
      },
    );
  }
}
