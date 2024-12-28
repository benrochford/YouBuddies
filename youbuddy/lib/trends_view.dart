import 'package:flutter/material.dart';
import 'package:community_charts_flutter/community_charts_flutter.dart' as charts;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:csv/csv.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:youbuddy/firebase_utils.dart';
import 'package:flutter/gestures.dart';

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

  String selectedTimeframe = 'Weekly';
  String? selectedTopic;
  List<String> allTopics = [];
  Map<String, List<FlSpot>> topicTimeSeriesData = {};
  List<String> selectedTopics = [];
  TextEditingController searchController = TextEditingController();
  List<String> filteredTopics = [];
  final List<Color> topicColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.amber,
    Colors.cyan,
    Colors.indigo,
  ];

  final ScrollController _topicsScrollController = ScrollController();
  final ScrollController _searchScrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = fetchRecommendations(widget.currentUser).then((data) {
      processData(data); // Process the data once it's fetched
      return data; // pass the data along
    });
    _loadTopicsData();
  }

  @override
  void dispose() {
    _searchScrollController.dispose();
    _topicsScrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTopicsData() async {
    // Fetch all recommendations to analyze topics
    final allRecs = await fetchRecommendations(widget.currentUser);
    Set<String> topics = {};
    Map<String, Map<DateTime, int>> topicCounts = {};
    Set<DateTime> daysWithData = {}; // Track days where we have any recommendations

    // Process recommendations to get topics and their counts over time
    for (var rec in allRecs) {
      // Round to start of day
      final date = DateTime(rec.timestamp.year, rec.timestamp.month, rec.timestamp.day);
      daysWithData.add(date); // Mark this day as having data
      
      for (var topic in rec.topics) {
        topics.add(topic);
        topicCounts.putIfAbsent(topic, () => {});
        topicCounts[topic]![date] = (topicCounts[topic]![date] ?? 0) + 1;
      }
    }

    // Convert to chart data, only including days where we have recommendations
    for (var topic in topics) {
      var filteredCounts = Map.fromEntries(
        topicCounts[topic]!.entries.where((e) => daysWithData.contains(e.key))
      );
      var spots = _generateTimeSeriesSpots(filteredCounts, selectedTimeframe);
      topicTimeSeriesData[topic] = spots;
    }

    setState(() {
      allTopics = topics.toList()..sort();
      if (allTopics.isNotEmpty) {
        selectedTopic = allTopics.first;
      }
    });
  }

  List<FlSpot> _generateTimeSeriesSpots(Map<DateTime, int> dateCounts, String timeframe) {
    var groupedCounts = <DateTime, int>{};
    
    // Group by selected timeframe
    dateCounts.forEach((date, count) {
      DateTime groupKey;
      if (timeframe == 'Weekly') {
        // Round to start of week
        groupKey = date.subtract(Duration(days: date.weekday - 1));
      } else {
        // Monthly
        groupKey = DateTime(date.year, date.month, 1);
      }
      groupedCounts[groupKey] = (groupedCounts[groupKey] ?? 0) + count;
    });

    // Convert to spots, only including days with data
    return groupedCounts.entries
        .where((e) => e.value > 0) // Only include entries with data
        .map((e) => FlSpot(e.key.millisecondsSinceEpoch.toDouble(), e.value.toDouble()))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  Widget _buildTopicTimeSeriesChart() {
    if (topicTimeSeriesData.isEmpty) {
      return Container();
    }

    return Column(
      children: [
        // Topic Selection and Search
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Focus(
                onFocusChange: (hasFocus) {
                  setState(() {
                    _isSearching = hasFocus;
                  });
                },
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: 'Search topics...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear_all),
                      tooltip: 'Reset selection',
                      onPressed: () {
                        setState(() {
                          selectedTopics.clear();
                        });
                      },
                    ),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      filteredTopics = allTopics
                          .where((topic) => topic.toLowerCase().contains(value.toLowerCase()))
                          .toList();
                    });
                  },
                  focusNode: _searchFocusNode,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
              ),
              SizedBox(height: 8),
              // Single Topics List with scrolling
              Container(
                constraints: BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Scrollbar(
                  controller: _topicsScrollController,
                  thumbVisibility: true,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context).copyWith(
                      scrollbars: true,
                      dragDevices: {
                        PointerDeviceKind.touch,
                        PointerDeviceKind.mouse,
                      },
                    ),
                    child: ListView.builder(
                      controller: _topicsScrollController,
                      itemCount: (searchController.text.isEmpty ? allTopics : filteredTopics).length,
                      itemBuilder: (context, index) {
                        final topic = (searchController.text.isEmpty ? allTopics : filteredTopics)[index];
                        return CheckboxListTile(
                          dense: true,
                          title: Text(topic),
                          value: selectedTopics.contains(topic),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                if (selectedTopics.length < topicColors.length) {
                                  selectedTopics.add(topic);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Maximum ${topicColors.length} topics allowed')),
                                  );
                                }
                              } else {
                                selectedTopics.remove(topic);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              // Timeframe Selection
              DropdownButton<String>(
                value: selectedTimeframe,
                items: ['Weekly', 'Monthly']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedTimeframe = value!;
                    _loadTopicsData();
                  });
                },
              ),
            ],
          ),
        ),
        // Bar Chart
        Container(
          height: 300,
          padding: EdgeInsets.all(16),
          child: BarChart(
            BarChartData(
              gridData: FlGridData(show: true),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, _) => Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          DateFormat('MMM yy').format(
                            DateTime.fromMillisecondsSinceEpoch(value.toInt())
                          ),
                          style: TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    reservedSize: 40,
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, _) => Text(value.toInt().toString()),
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              barGroups: _generateBarGroups(),
              minY: 0,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  tooltipBgColor: Colors.blueGrey,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final timestamp = DateTime.fromMillisecondsSinceEpoch(group.x.toInt());
                    // Get first day of week (assuming week starts on Monday)
                    final firstDayOfWeek = timestamp.subtract(Duration(days: timestamp.weekday - 1));
                    final topic = selectedTopics[rodIndex];
                    return BarTooltipItem(
                      '${DateFormat('MMM dd, yyyy').format(firstDayOfWeek)}\n$topic: ${rod.toY.toInt()}',
                      const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedTopics.asMap().entries.map((entry) {
              final colorIndex = entry.key % topicColors.length;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    color: topicColors[colorIndex],
                  ),
                  SizedBox(width: 4),
                  Text(entry.value),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<BarChartGroupData> _generateBarGroups() {
    if (selectedTopics.isEmpty) return [];

    // Find all unique timestamps across selected topics
    Set<int> timestamps = {};
    for (var topic in selectedTopics) {
      if (topicTimeSeriesData[topic] != null) {
        timestamps.addAll(
          topicTimeSeriesData[topic]!
              .map((spot) => spot.x.toInt())
        );
      }
    }

    var sortedTimestamps = timestamps.toList()..sort();
    
    return sortedTimestamps.map((timestamp) {
      List<BarChartRodData> rods = selectedTopics.asMap().entries.map((entry) {
        final topic = entry.value;
        final colorIndex = entry.key % topicColors.length;
        final spots = topicTimeSeriesData[topic] ?? [];
        final spot = spots.firstWhere(
          (s) => s.x.toInt() == timestamp,
          orElse: () => FlSpot(timestamp.toDouble(), 0),
        );

        return BarChartRodData(
          toY: spot.y,
          color: topicColors[colorIndex],
          width: 16 / selectedTopics.length, // Adjust width based on number of topics
        );
      }).toList();

      return BarChartGroupData(
        x: timestamp,
        barRods: rods,
      );
    }).toList();
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

                  _buildTopicTimeSeriesChart(), 
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
