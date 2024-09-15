import 'dart:html';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class AuthHandlerWidget extends StatelessWidget {
  // check https://github.com/ThexXTURBOXx/flutter_web_auth_2 for example handler
  AuthHandlerWidget({Key? key}) : super(key: key) {
    final message = {'flutter-web-auth-2': window.location.href};

    try {
      window.opener?.postMessage(message, window.location.origin);
    } catch (e) {
      localStorage.setItem('flutter-web-auth-2', window.location.href);
    }
    window.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}
