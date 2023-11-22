import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:charts_flutter/flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class TrendsView extends StatefulWidget {
  final String clientId;
  TrendsView({required this.clientId});

  @override
  _TrendsViewState createState() => _TrendsViewState();
}

class _TrendsViewState extends State<TrendsView> {
  late Future<List<Map<String, dynamic>>> _dataFuture;
  final Map<String, int> _channelRecFrequency = {};
  final Map<String, Map<DateTime, int>> _topicTrendData = {};
  final Map<String, int> _cumulativeChannelData = {};
  final Map<String, int> _cumulativeTopicData = {};
  final Map<DateTime, Map<String, int>> _timeOfDayData = {};

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchCurrentUserRecommendations().then((data) {
      processData(data); // Process the data once it's fetched
      return data; // pass the data along
    });
  }

  Future<List<Map<String, dynamic>>> fetchCurrentUserRecommendations() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.clientId)
        .collection('youtubeRecommendations')
        .orderBy('timestamp', descending: true)
        .get(); // removed limit(1) to fetch all data

    List<Map<String, dynamic>> recommendationsList = [];
    if (querySnapshot.docs.isNotEmpty) {
      for (var doc in querySnapshot.docs) {
        final recommendationsDoc = doc.data();
        if (recommendationsDoc.containsKey('recommendations')) {
          final recommendations =
              (recommendationsDoc['recommendations'] as List)
                  .map((r) => r as Map<String, dynamic>)
                  .toList();
          final topics =
              (recommendationsDoc['topics'] as List?)?.cast<String>() ?? [];
          final timestamp =
              (recommendationsDoc['timestamp'] as Timestamp?)?.toDate() ??
                  DateTime.now();
          var rank = 1;
          for (var recommendation in recommendations) {
            recommendationsList.add({
              ...recommendation,
              'rank': rank,
              'topics': topics,
              'timestamp': timestamp,
            });
            rank++;
          }
        }
      }
    }
    return recommendationsList;
  }

  Future<void> processData(List<Map<String, dynamic>> data) async {
    for (var rec in data) {
      final channel = rec['channel'] as String? ?? 'Unknown';
      final topics = (rec['topics'] as List?)?.cast<String>() ?? [];
      final timestamp = rec['timestamp'] as DateTime;

      // Process channel recommendation frequency
      _channelRecFrequency[channel] = (_channelRecFrequency[channel] ?? 0) + 1;

      // Process topic trend data
      for (var topic in topics) {
        _topicTrendData[topic] = _topicTrendData[topic] ?? {};
        final date = DateTime(timestamp.year, timestamp.month, timestamp.day);
        _topicTrendData[topic]?[date] =
            (_topicTrendData[topic]?[date] ?? 0) + 1;
      }

      // Process cumulative channel data
      _cumulativeChannelData[channel] =
          (_cumulativeChannelData[channel] ?? 0) + 1;

      // Process cumulative topic data
      for (var topic in topics) {
        _cumulativeTopicData[topic] = (_cumulativeTopicData[topic] ?? 0) + 1;
      }

      // Process time of day data
      final date = DateTime(
        timestamp.year,
        timestamp.month,
        timestamp.day,
        timestamp.hour,
      );
      _timeOfDayData[date] = _timeOfDayData[date] ?? {};
      _timeOfDayData[date]?[channel] =
          (_timeOfDayData[date]?[channel] ?? 0) + 1;
    }
  }

  List<charts.Series<_ChannelRecFrequencyData, String>>
      _createChannelRecFrequencySeries(int itemCount) {
    var data = _channelRecFrequency.entries
        .where((entry) => entry.key != 'Unknown') // Ignore 'Unknown' channel
        .map<_ChannelRecFrequencyData>((entry) {
      return _ChannelRecFrequencyData(entry.key, entry.value);
    }).toList();

    data.sort((a, b) => b.frequency.compareTo(a.frequency));

    // Limit the number of data items
    data = data.take(itemCount).toList();

    return [
      charts.Series<_ChannelRecFrequencyData, String>(
        id: 'ChannelRecFrequency',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (_ChannelRecFrequencyData datum, _) => datum.channel,
        measureFn: (_ChannelRecFrequencyData datum, _) => datum.frequency,
        labelAccessorFn: (_ChannelRecFrequencyData datum, _) =>
            '${datum.channel}: ${datum.frequency}',
        data: data,
      )
    ];
  }

  final List<String> ignoreTopics = [
    'Live',
    'Gaming',
    'Mixes',
    'Podcasts',
    'Music'
  ];

  List<charts.Series<_TopicData, String>> _createTopicSeries(int itemCount) {
    var data = _cumulativeTopicData.entries
        .where((entry) => !ignoreTopics.contains(entry.key))
        .map<_TopicData>((entry) {
      return _TopicData(entry.key, entry.value);
    }).toList();

    data.sort((a, b) => b.count.compareTo(a.count));

    // Limit the number of data items
    data = data.take(itemCount).toList();

    return [
      charts.Series<_TopicData, String>(
        id: 'TopicCount',
        colorFn: (_, __) => charts.MaterialPalette.blue.shadeDefault,
        domainFn: (_TopicData datum, _) => datum.topic,
        measureFn: (_TopicData datum, _) => datum.count,
        labelAccessorFn: (_TopicData datum, _) =>
            '${datum.topic}: ${datum.count}',
        data: data,
      )
    ];
  }

  List<Widget> buildRecommendationList(
      List<Map<String, dynamic>> recommendations) {
    return recommendations.map((recommendation) {
      String thumbnailUrl = "https://img.youtube.com/vi/" +
          recommendation['link'].toString().split('?v=')[1] +
          "/0.jpg";

      final url = Uri.parse(recommendation['link']);
      return InkWell(
        onTap: () async {
          if (await canLaunchUrl(url)) {
            await launchUrl(url);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Unable to open link')),
            );
          }
        },
        child: ListTile(
          leading: Container(
            width: 56.0,
            height: 32.0,
            decoration: BoxDecoration(
              image: DecorationImage(
                fit: BoxFit.cover,
                image: NetworkImage(thumbnailUrl),
              ),
            ),
          ),
          title: Text(recommendation['title']),
          subtitle: Text(recommendation['channel'] ?? 'Unknown channel'),
        ),
      );
    }).toList();
  }

  DateTime? selectedTimestamp;
  int _channelRecsItemCount = 10;
  int _topicsItemCount = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recs History'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else {
            final data = snapshot.data!;
            final channelRecFrequencySeries =
                _createChannelRecFrequencySeries(_channelRecsItemCount);

            // Create a list of timestamps
            final timestamps = data
                .map((rec) => rec['timestamp'] as DateTime)
                .toSet() // Remove duplicates
                .toList()
              ..sort((a, b) => b.compareTo(a)); // Sort in descending order

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Historical recs browser
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Browse your recs',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DropdownButton<DateTime>(
                      isExpanded: true, // go full width
                      hint: Text('Choose a time'),
                      value: selectedTimestamp,
                      onChanged: (DateTime? newValue) {
                        setState(() {
                          selectedTimestamp = newValue;
                        });
                      },
                      items: timestamps
                          .map<DropdownMenuItem<DateTime>>((DateTime value) {
                        return DropdownMenuItem<DateTime>(
                          value: value,
                          child: Text(DateFormat('MMMM d, yyyy  hh:mm a')
                              .format(value)),
                        );
                      }).toList(),
                    ),
                  ),
                  if (selectedTimestamp != null) // create if timestamp
                    ExpansionTile(
                      title: Icon(Icons.video_library_outlined),
                      children: buildRecommendationList(
                        data.where((rec) {
                          final recTimestamp = rec['timestamp'] as DateTime;
                          return recTimestamp
                              .isAtSameMomentAs(selectedTimestamp!);
                        }).toList(),
                      ),
                    ),

                  // spacer
                  Padding(
                    padding:
                        EdgeInsets.only(top: 16.0), // Add padding on top only
                  ),

                  // Time Series Analysis Section

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Text('Show top'),
                        SizedBox(width: 8), // Add some spacing
                        DropdownButton<int>(
                          value: _channelRecsItemCount,
                          onChanged: (int? newValue) {
                            setState(() {
                              _channelRecsItemCount = newValue!;
                            });
                          },
                          items: [10, 25, 50]
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal, // Horizontal scrolling
                      child: Container(
                        width: 1000.0, // Adjust width to accommodate all bars
                        height: 200.0,
                        child: charts.BarChart(
                          channelRecFrequencySeries,
                          animate: true,
                          barGroupingType: charts.BarGroupingType.grouped,
                          barRendererDecorator: null,
                          domainAxis: charts.OrdinalAxisSpec(
                            renderSpec: charts.SmallTickRendererSpec(
                              labelRotation: 45,
                              labelStyle: charts.TextStyleSpec(
                                  fontSize: 11, color: charts.Color.white),
                            ),
                          ),
                          primaryMeasureAxis: charts.NumericAxisSpec(
                            renderSpec: charts.GridlineRendererSpec(
                              labelStyle: charts.TextStyleSpec(
                                fontSize: 10,
                                color: charts.MaterialPalette.gray.shadeDefault,
                              ),
                              lineStyle: charts.LineStyleSpec(
                                  color:
                                      charts.MaterialPalette.gray.shadeDefault),
                            ),
                          ),
                          behaviors: [
                            charts.ChartTitle(
                              'Channel Rec Counts',
                              behaviorPosition: charts.BehaviorPosition.top,
                              titleOutsideJustification:
                                  charts.OutsideJustification.startDrawArea,
                              titleStyleSpec: charts.TextStyleSpec(
                                  color: charts.Color.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Topics Analysis Section

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Text('Show top'),
                        SizedBox(width: 8), // Add some spacing
                        DropdownButton<int>(
                          value: _topicsItemCount,
                          onChanged: (int? newValue) {
                            setState(() {
                              _topicsItemCount = newValue!;
                            });
                          },
                          items: [10, 25, 50]
                              .map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text(value.toString()),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Container(
                      height: 300.0,
                      child: charts.BarChart(
                        _createTopicSeries(_topicsItemCount),
                        animate: true,
                        vertical:
                            false, // Set to false for horizontal bar chart
                        barGroupingType: charts.BarGroupingType.grouped,
                        // Configure the axis to show the topics on the Y-axis
                        domainAxis: charts.OrdinalAxisSpec(
                          renderSpec: charts.SmallTickRendererSpec(
                            labelRotation: 0,
                            labelStyle: charts.TextStyleSpec(
                                fontSize: 10, color: charts.Color.white),
                            lineStyle: charts.LineStyleSpec(
                                color:
                                    charts.MaterialPalette.gray.shadeDefault),
                          ),
                        ),
                        // Configure the measure axis to show the counts on the X-axis
                        primaryMeasureAxis: charts.NumericAxisSpec(
                          renderSpec: charts.GridlineRendererSpec(
                            labelStyle: charts.TextStyleSpec(
                                fontSize: 11,
                                color:
                                    charts.MaterialPalette.gray.shadeDefault),
                            lineStyle: charts.LineStyleSpec(
                                color:
                                    charts.MaterialPalette.gray.shadeDefault),
                          ),
                        ),
                        behaviors: [
                          charts.ChartTitle(
                            'Topic Counts',
                            behaviorPosition: charts.BehaviorPosition.top,
                            titleOutsideJustification:
                                charts.OutsideJustification.startDrawArea,
                            titleStyleSpec:
                                charts.TextStyleSpec(color: charts.Color.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

class _ChannelRecFrequencyData {
  final String channel;
  final int frequency;

  _ChannelRecFrequencyData(this.channel, this.frequency);
}

class _TopicData {
  final String topic;
  final int count;

  _TopicData(this.topic, this.count);
}
