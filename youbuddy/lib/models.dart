import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class User {
  DocumentReference ref;
  String name;
  String friendId;

  List<User>? friends;
  List<Recommendations>? recs;

  User(
      {required this.ref,
      required this.name,
      required this.friendId,
      this.friends,
      this.recs});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
        ref: json['ref'],
        name: json['name'],
        friendId: json['friendId'],
        friends: json['friends'],
        recs: json['recs']);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'friendId': friendId};
  }

  static User fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot, SnapshotOptions? o) {
    var data = snapshot.data()!;
    data['ref'] = snapshot.reference;

    return User.fromJson(data);
  }

  static Map<String, dynamic> toFirestore(User user, SetOptions? o) =>
      user.toJson();

  @override
  bool operator ==(Object other) {
    return other is User && this.ref.id == other.ref.id;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}

class Recommendations {
  List<Video> videos;
  List<String> topics;
  DateTime timestamp;

  Recommendations({required this.videos, required this.topics, required this.timestamp});

  factory Recommendations.fromJson(Map<String, dynamic> json) {
    final rec = Recommendations(
        videos: json['recommendations'].map<Video>((rec) => Video.fromJson(rec)).toList(),
        topics: json['topics'].cast<String>(),
        timestamp: json['timestamp'].toDate());

    return rec;
  }

  Map<String, dynamic> toJson() => {
        'recommendations': videos.map((video) => video.toJson()).toList(),
        'topics': topics,
        'timestamp': timestamp
      };

  static Recommendations fromFirestore(
          DocumentSnapshot<Map<String, dynamic>> snapshot,
          SnapshotOptions? o) =>
      Recommendations.fromJson(snapshot.data()!);

  static Map<String, dynamic> toFirestore(
          Recommendations recSet, SetOptions? o) =>
      recSet.toJson();

  bool operator ==(Object other) {
    return other is Recommendations &&
        setEquals(this.videos.toSet(), other.videos.toSet());
  }
}

class Video {
  String channel;
  String link;
  String title;

  Video(
      {required this.channel, required this.link, required this.title});

  factory Video.fromJson(Map<String, dynamic> json) => Video(
      channel: json['channel'], link: json['link'], title: json['title']);

  Map<String, dynamic> toJson() =>
      {'channel': channel, 'link': link, 'title': title};

  @override
  bool operator ==(Object other) {
    return other is Video && this.link == other.link;
  }

  @override
  String toString() {
    return toJson().toString();
  }
}
