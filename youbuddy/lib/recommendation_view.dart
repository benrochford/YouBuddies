import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youbuddy/collect_recs_button.dart';
import 'dart:math';

import 'package:youbuddy/firebase_utils.dart';

import 'models.dart';

class RecommendationView extends StatefulWidget {
  final User currentUser;

  RecommendationView({required this.currentUser});

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
  late Future<List<Map<dynamic, dynamic>>> fetchRecommendationsFuture;
  late Future<List<User>> fetchFriendsFuture;

  @override
  void initState() {
    super.initState();
    fetchFriendsFuture = fetchFriends(widget.currentUser);

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

  Future<Map<User, List<Recommendations>>> fetchRecommendationsFromFriends(
      List<User> friends) async {
    Map<User, List<Recommendations>> friendRecommendationsMap = {};
    for (User friend in friends) {
      List<Recommendations> recs = await fetchRecommendations(friend, limit: 7);
      friendRecommendationsMap[friend] = recs;
    }

    return friendRecommendationsMap;
  }

  Future<Map<Video, Map<String, dynamic>>> findCommonRecommendations(
      Map<User, List<Recommendations>> friendRecs) async {
    Map<Video, Map<String, dynamic>> commonRecsMap = {};

    // Initialize commonRecsMap with current user's recommendations
    final currentUserRecs =
        await fetchRecommendations(widget.currentUser, limit: 7);
    for (final rec in currentUserRecs) {
      for (final video in rec.videos) {
        commonRecsMap[video] = {
          'count': 1,
          'friendUsernames': ['You!'],
        };
      }
    }

    for (MapEntry<User, List<Recommendations>> entry in friendRecs.entries) {
      final friend = entry.key;
      final recs = entry.value;
      for (final rec in recs) {
        for (var video in rec.videos) {
          if (commonRecsMap.containsKey(video)) {
            if (commonRecsMap[video]?['count'] != null &&
                !commonRecsMap[video]?['friendUsernames'].contains(friend.name)) {
              commonRecsMap[video]!['count'] += 1;
              commonRecsMap[video]!['friendUsernames'].add(friend.name);
            }
          } else {
            commonRecsMap[video] = {
              'count': 1,
              'friendUsernames': [friend.name],
            };
          }
        }
      }
    }

    // return commonRecsMap;  // uncomment to include recs got by only 1 person
    return Map.fromEntries(
        commonRecsMap.entries.where((e) => e.value['count'] >= 2));
  }

  Widget buildCommonRecommendationsWidget(
      Map<Video, Map<String, dynamic>> commonRecsMap) {
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
        Video video = sortedKeys[i];
        Map<String, dynamic>? details = commonRecsMap[video];

        if (details != null) {
          String thumbnailUrl = "https://img.youtube.com/vi/" +
              video.link.toString().split('?v=')[1] +
              "/0.jpg";

          commonRecsList.add(InkWell(
            onTap: () async {
              final urlObj = Uri.parse(video.link);
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
              title: Text(video.title),
              subtitle: Text(video.channel),
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

  List<Widget> buildRecommendationList(List<Recommendations> recommendations) {
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

    return recommendations.first.videos.map((video) {
      String thumbnailUrl = "https://img.youtube.com/vi/" +
          video.link.toString().split('?v=')[1] +
          "/0.jpg";

      final url = Uri.parse(video.link);
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
          title: Text(video.title),
          subtitle: Text(video.channel),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<User>>(
      future: fetchFriendsFuture,
      builder: (context, friendsSnapshot) {
        if (!friendsSnapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        final friendsList = friendsSnapshot.data!;

        fetchRecommendationsFuture =
            fetchRecommendationsFromFriends(friendsList).then(
                (friendRecs) async =>
                    [friendRecs, await findCommonRecommendations(friendRecs)]);

        return FutureBuilder<List<Map<dynamic, dynamic>>>(
            future: fetchRecommendationsFuture,
            builder: (context, recommendationsSnapshot) {
              if (!recommendationsSnapshot.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final friendRecsMap = recommendationsSnapshot.data![0]
                  as Map<User, List<Recommendations>>;
              final commonRecsMap = recommendationsSnapshot.data![1]
                  as Map<Video, Map<String, dynamic>>;

              return Scaffold(
                appBar: AppBar(
                    title: Text('Recommendations from friends'),
                    actions: [
                      CollectRecsButton(
                        user: widget.currentUser,
                        onSuccess: () => setState(() {
                          fetchRecommendationsFuture =
                              fetchRecommendationsFromFriends(friendsList).then(
                                  (friendRecs) async => [
                                        friendRecs,
                                        await findCommonRecommendations(
                                            friendRecs)
                                      ]);
                        }),
                      )
                    ]),
                body: ListView(
                  children: [
                    buildCommonRecommendationsWidget(commonRecsMap),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: friendsList.length,
                      itemBuilder: (context, index) {
                        final friend = friendsList[index];
                        final recommendations = friendRecsMap[friend];

                        return ExpansionTile(
                          title: Text(friend.name,
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          initiallyExpanded:
                              expansionStateMap[friend.ref.id] ?? false,
                          onExpansionChanged: (bool isExpanded) {
                            expansionStateMap[friend.ref.id] = isExpanded;
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
