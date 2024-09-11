import 'dart:html';

import 'package:flutter/material.dart';

class AuthHandlerWidget extends StatelessWidget {
  AuthHandlerWidget({Key? key}) : super(key: key) {
    final baseWindow = window.opener;
    baseWindow?.postMessage({
      'flutter-web-auth-2': window.location.href
    }, window.location.origin);
    window.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}