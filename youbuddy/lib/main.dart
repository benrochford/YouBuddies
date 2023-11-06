import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'firebase_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'friend_management_view.dart';
import 'recommendation_view.dart';
import 'trends_view.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp());
}

// defines app bar gradient based on time of day
LinearGradient getAppBarGradient() {
  final now = DateTime.now();
  final hour = now.hour;

  if (hour < 11) {
    return LinearGradient(
      colors: [
        Color.fromARGB(255, 205, 162, 232),
        const Color.fromARGB(255, 95, 147, 190)
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (hour < 17) {
    return LinearGradient(
      colors: [Colors.blue.shade200, Color.fromARGB(255, 91, 173, 255)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else if (hour < 20) {
    return LinearGradient(
      colors: [Color.fromARGB(255, 235, 169, 97), Colors.purple.shade200],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  } else {
    return LinearGradient(
      colors: [Colors.purple.shade800, Colors.blue.shade800],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      navigatorKey: navigatorKey,
      home: InitializationWidget(),
    );
  }
}

class InitializationWidget extends StatefulWidget {
  @override
  _InitializationWidgetState createState() => _InitializationWidgetState();
}

class _InitializationWidgetState extends State<InitializationWidget> {
  Future<void>? _initializationFuture;
  late String name;
  late String friendId;

  @override
  void initState() {
    super.initState();
    // line so that the login dialog does not reference context before the widget tree has been built
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() {
        _initializationFuture = _initializeApp();
      });
    });
  }

  Future<void> _initializeApp() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await _getClientIdFromUser(context);
    }

    var profile = await getUserProfile(FirebaseAuth.instance.currentUser!.uid);
    name = profile?['name'];
    friendId = profile?['friendId'];
  }

  Future<UserCredential> _loginWithGoogle() async {
    var provider = GoogleAuthProvider();
    provider.addScope('https://www.googleapis.com/auth/youtube');
    var credential = await FirebaseAuth.instance.signInWithPopup(provider);

    if (credential.additionalUserInfo!.isNewUser) {
      Map<String, dynamic> profile = {};
      profile['name'] = credential.user!.displayName;
      profile['friendId'] = '${UniqueKey().hashCode}';

      FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set(profile);

      FirebaseFirestore.instance
          .collection('tokens')
          .doc(credential.user!.uid)
          .set({'refreshToken': credential.user!.refreshToken});
    }

    return credential;
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // restart the app to get a new clientId
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => InitializationWidget(),
    ));
  }

  Future<void> _getClientIdFromUser(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login'),
          content: ElevatedButton(
              onPressed: () async {
                var credential = await _loginWithGoogle();
                if (credential.user != null) {
                  Navigator.of(context).pop();
                }
              },
              child: Text('Sign in with Google')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          // Use LayoutBuilder to build UI based on available screen width
          return LayoutBuilder(
            builder: (context, constraints) {
              // Define a breakpoint for switching to vertical navigation
              const double breakpoint = 600;
              if (constraints.maxWidth > breakpoint) {
                // Wide screen layout with vertical navigation
                return DefaultTabController(
                  length: 3,
                  initialIndex: 1,
                  child: Scaffold(
                    appBar: AppBar(
                      title: Text(
                        'YouBuddies',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Center(child: Text('[$name]')),
                        ),
                        TextButton(
                          onPressed: _logout,
                          child: Text('Logout'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                      flexibleSpace: Container(
                        decoration: BoxDecoration(
                          gradient: getAppBarGradient(),
                        ),
                      ),
                    ),
                    body: Row(
                      children: [
                        Container(
                          width: 72, // Width of the NavigationRail
                          decoration: BoxDecoration(
                            gradient: getAppBarGradient(),
                          ),
                          child: Builder(
                            builder: (context) {
                              // Obtain the DefaultTabController for the context
                              final TabController tabController =
                                  DefaultTabController.of(context);
                              return NavigationRail(
                                backgroundColor: Colors.transparent,
                                // Makes it take the gradient background
                                selectedIndex: tabController.index,
                                onDestinationSelected: (int index) {
                                  // Change the tab index upon selection
                                  tabController.animateTo(index);
                                  setState(() {
                                    tabController.index = index;
                                  });
                                },
                                destinations: [
                                  NavigationRailDestination(
                                    icon: Icon(Icons.bar_chart_outlined),
                                    label: Text('Trends'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.video_library_rounded),
                                    label: Text('Recommendations'),
                                  ),
                                  NavigationRailDestination(
                                    icon: Icon(Icons.people),
                                    label: Text('Friends'),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              TrendsView(
                                  clientId:
                                      FirebaseAuth.instance.currentUser!.uid),
                              RecommendationView(
                                  clientId:
                                      FirebaseAuth.instance.currentUser!.uid),
                              FriendManagementView(
                                  clientId:
                                      FirebaseAuth.instance.currentUser!.uid,
                              clientFriendId: friendId,),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                // Default layout with horizontal TabBar
                return DefaultTabController(
                  length: 3,
                  initialIndex: 1,
                  child: Scaffold(
                    appBar: AppBar(
                      flexibleSpace: Container(
                        decoration: BoxDecoration(
                          gradient: getAppBarGradient(),
                        ),
                      ),
                      bottom: TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.bar_chart_outlined)),
                          Tab(icon: Icon(Icons.video_library_rounded)),
                          Tab(icon: Icon(Icons.people)),
                        ],
                      ),
                      title: Text(
                        'YouBuddies',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      actions: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Center(child: Text('[$name]')),
                        ),
                        TextButton(
                          onPressed: _logout,
                          child: Text('Logout'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    body: TabBarView(
                      children: [
                        TrendsView(
                            clientId: FirebaseAuth.instance.currentUser!.uid),
                        RecommendationView(
                            clientId: FirebaseAuth.instance.currentUser!.uid),
                        FriendManagementView(
                            clientId: FirebaseAuth.instance.currentUser!.uid,
                          clientFriendId: friendId,),
                      ],
                    ),
                  ),
                );
              }
            },
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}
