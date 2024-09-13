import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:youbuddy/firebase_utils.dart';

import 'models.dart';

class TrendsView extends StatefulWidget {
  final User currentUser;
  TrendsView({required this.currentUser});

  @override
  _TrendsViewState createState() => _TrendsViewState();
}

class _TrendsViewState extends State<TrendsView> {
  late Future<List<Recommendations>> _dataFuture;
  final Map<String, int> _channelRecFrequency = {};
  final Map<String, Map<DateTime, int>> _topicTrendData = {};
  final Map<String, int> _cumulativeChannelData = {};
  final Map<String, int> _cumulativeTopicData = {};
  final Map<DateTime, Map<String, int>> _timeOfDayData = {};

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRecommendations(widget.currentUser).then((data) {
      processData(data); // Process the data once it's fetched
      return data; // pass the data along
    });
  }

  Future<void> processData(List<Recommendations> data) async {
    for (var rec in data) {
      for (var video in rec.videos) {
        final channel = video.channel;
        final topics = rec.topics;
        final timestamp = rec.timestamp;

        // Process channel recommendation frequency
        _channelRecFrequency[channel] =
            (_channelRecFrequency[channel] ?? 0) + 1;

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
  }

  // Methods for CSV download

  String generateRecommendationsCSV(
      List<Recommendations> recommendations) {
    List<List<dynamic>> rows = [
      ['Timestamp', 'Title', 'Channel', 'Link'], // CSV header
    ];

    for (var rec in recommendations) {
      for (var video in rec.videos) {
        List<dynamic> row = [
          rec.timestamp.toIso8601String(),
          video.title,
          video.channel,
          video.link,
        ];
        rows.add(row);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  String generateTagsCSV(List<Recommendations> recommendations) {
    List<List<dynamic>> rows = [
      ['Timestamp', 'Tags'], // CSV header
    ];

    List<DateTime> dates = [];
    for (var rec in recommendations) {
      if (!dates.contains(rec.timestamp)) {
        dates.add(rec.timestamp); // avoid duplicates

        // Filter out ignored topics from the topics list
        List<String> topics = List<String>.from(rec.topics);
        List<String> filteredTopics =
            topics.where((topic) => !ignoreTopics.contains(topic)).toList();
        String filteredTopicsString = filteredTopics.join(', ');

        List<dynamic> row = [
          rec.timestamp.toIso8601String(),
          filteredTopicsString,
        ];
        rows.add(row);
      }
    }

    return const ListToCsvConverter().convert(rows);
  }

  Future<void> downloadFile(String csvContent, String baseFileName) async {
    String formattedDateTime = DateFormat('MM_dd_yy').format(DateTime.now());

    // Construct the file name with the user's name and the current date-time
    String fileName = '${baseFileName}_$formattedDateTime.csv';

    Uint8List bytes = Uint8List.fromList(csvContent.codeUnits);
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: bytes,
      mimeType: MimeType.csv,
    );
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
      List<Recommendations> recommendations) {
    return recommendations.first.videos.map((video) {
      String thumbnailUrl = "https://img.youtube.com/vi/" +
          video.link.toString().split('?v=')[1] +
          "/0.jpg";

      final url = Uri.parse(video.link);
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
          title: Text(video.title),
          subtitle: Text(video.channel),
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
      body: FutureBuilder<List<Recommendations>>(
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
                .map((rec) => rec.timestamp)
                .toSet() // Remove duplicates
                .toList()
              ..sort((a, b) => b.compareTo(a)); // Sort in descending order

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Historical recs browser AND CSV download buttons
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Browse your recs',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        // Download Rec Data Button
                        ElevatedButton(
                          onPressed: () async {
                            final recommendations =
                                await fetchRecommendations(widget.currentUser);
                            final recommendationsCSV =
                                generateRecommendationsCSV(recommendations);
                            final tagsCSV = generateTagsCSV(recommendations);

                            await downloadFile(
                                recommendationsCSV, 'recommendations');
                            await downloadFile(tagsCSV, 'tags');
                          },
                          child: Text('Download Rec Data'),
                        ),
                      ],
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
                          return rec.timestamp
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
                        SizedBox(width: 8),
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
                    child: Container(
                      height: 425.0,
                      child: charts.BarChart(
                        channelRecFrequencySeries,
                        animate: true,
                        vertical: false,
                        barGroupingType: charts.BarGroupingType.grouped,
                        // Configure the domain axis (now Y-axis) to show the labels
                        domainAxis: charts.OrdinalAxisSpec(
                          renderSpec: charts.SmallTickRendererSpec(
                            labelStyle: charts.TextStyleSpec(
                                fontSize: 10, color: charts.Color.white),
                            lineStyle: charts.LineStyleSpec(
                                color:
                                    charts.MaterialPalette.gray.shadeDefault),
                          ),
                        ),
                        // Configure the measure axis (now X-axis) to show the counts
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
                            'Channel Rec Counts',
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
                      height: 400.0,
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
