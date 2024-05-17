import 'dart:html';

import 'package:flutter/material.dart';

class AuthHandlerWidget extends StatelessWidget {
  AuthHandlerWidget({Key? key}) : super(key: key) {
    final params = Uri.base.queryParameters;
    final baseWindow = window.opener;
    baseWindow?.postMessage(params, window.location.origin);
    window.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Container());
  }
}