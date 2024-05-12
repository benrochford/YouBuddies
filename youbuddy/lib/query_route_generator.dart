import 'package:flutter/material.dart';

import 'main.dart';
import 'oauth2_handler.dart';

class QueryRouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    String? route;
    Map? queryParameters;
    Widget? page;

    if (settings.name != null) {
      var uriData = Uri.parse(settings.name!);
      route = uriData.path;
      queryParameters = uriData.queryParameters;
    }

    switch(route) {
      case '/':
        page = InitializationWidget();
        break;
      case '/__/custom/auth/handler':
        page = AuthHandlerWidget();
        break;
    }

    return MaterialPageRoute(
      builder: (context) {
        return page!;
      },
      settings: settings,
    );
  }
}