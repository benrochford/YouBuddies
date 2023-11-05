import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<String>? _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeApp();
  }

  Future<String> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    String? clientId = prefs.getString('clientId');

    if (clientId == null || clientId.isEmpty) {
      clientId = await _getClientIdFromUser(context); // Pass context here
      await prefs.setString('clientId', clientId);
    }

    return clientId;
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('clientId');
    // restart the app to get a new clientId
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (context) => InitializationWidget(),
    ));
  }

  Future<String> _getClientIdFromUser(BuildContext context) async {
    final TextEditingController _clientIdController = TextEditingController();
    String? clientId;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login'),
          content: SingleChildScrollView(
            child: TextField(
              controller: _clientIdController,
              decoration: InputDecoration(
                labelText: 'Provide username',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('YES!'),
              onPressed: () {
                clientId = _clientIdController.text;
                if (clientId != null && clientId!.isNotEmpty) {
                  Navigator.of(context).pop(clientId);
                }
              },
            ),
          ],
        );
      },
    ).then((value) => value ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final clientId = snapshot.data!;
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
                          child: Center(child: Text('[$clientId]')),
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
                                backgroundColor: Colors
                                    .transparent, // Makes it take the gradient background
                                selectedIndex: tabController.index,
                                onDestinationSelected: (int index) {
                                  // Change the tab index upon selection
                                  tabController.animateTo(index);
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
                              TrendsView(clientId: clientId),
                              RecommendationView(clientId: clientId),
                              FriendManagementView(clientId: clientId),
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
                          child: Center(child: Text('[$clientId]')),
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
                        TrendsView(clientId: clientId),
                        RecommendationView(clientId: clientId),
                        FriendManagementView(clientId: clientId),
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
