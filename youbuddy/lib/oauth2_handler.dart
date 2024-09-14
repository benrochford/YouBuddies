import 'dart:html';

import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';

class AuthHandlerWidget extends StatelessWidget {
  AuthHandlerWidget({Key? key}) : super(key: key) {
    final message = {
      'flutter-web-auth-2': window.location.href
    };

    if (window.opener != null) {
      window.opener!.postMessage(message, window.location.origin);
      window.close();
    } else if (window.parent != null && window.parent != window) {
      window.parent!.postMessage(message, window.location.origin);
    } else {
      localStorage.setItem('flutter-web-auth-2', window.location.href);
      window.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}