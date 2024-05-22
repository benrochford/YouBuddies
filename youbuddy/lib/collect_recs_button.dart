import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CollectRecsButton extends StatefulWidget {
  final String clientId;
  final Function? onSuccess;
  final Function? onError;

  CollectRecsButton({required this.clientId, this.onSuccess, this.onError});

  @override
  _CollectRecsButtonState createState() => _CollectRecsButtonState();
}

class _CollectRecsButtonState extends State<CollectRecsButton> {
  Future<void> collectRecsButtonFuture = Future.value();

  Future<bool> collectRecs() async {
    return http.post(
        Uri.http('75.43.176.248:3000', '/collect'),
        headers: {
          HttpHeaders.contentTypeHeader: "application/json",
        },
        body: jsonEncode({'userId': widget.clientId})
    ).then((resp) => resp.statusCode == HttpStatus.ok).catchError((error) {
      print(error);
      return false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
        future: collectRecsButtonFuture,
        builder: (context, loadingSnapshot) {
          if (loadingSnapshot.connectionState == ConnectionState.active
              || loadingSnapshot.connectionState ==  ConnectionState.waiting) {
            return Center(child: Container(
                padding: EdgeInsets.fromLTRB(8, 8, 32, 8),
                child: CircularProgressIndicator()));
          } else {
            return TextButton(onPressed: () {
              setState(() {
                collectRecsButtonFuture =
                    collectRecs().then((success) {
                      if (success) {
                        if (widget.onSuccess != null) {
                          widget.onSuccess!();
                        }
                      } else {
                        if (widget.onError != null) {
                          widget.onError!();
                        }
                      }
                    });
              });
            }
                , child: Text('Collect recs'));
          }
        }
    );
  }

}