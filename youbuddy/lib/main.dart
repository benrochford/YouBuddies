import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'friend_management_view.dart';
import 'recommendation_view.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
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
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: TabBar(
                  tabs: [
                    Tab(text: 'Recommendations'),
                    Tab(text: 'Friends'),
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
                    child: Text('logout'),
                  ),
                ],
              ),
              body: TabBarView(
                children: [
                  RecommendationView(clientId: clientId),
                  FriendManagementView(clientId: clientId),
                ],
              ),
            ),
          );
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}
