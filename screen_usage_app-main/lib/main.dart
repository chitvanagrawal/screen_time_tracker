import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:screen_state/screen_state.dart';
import 'package:pausable_timer/pausable_timer.dart';
import 'package:flutter_background/flutter_background.dart';

void main() async {
  runApp(const MyApp());
  final androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Screen Usage App",
    notificationText: "I'm still running to keep track of your screen usage!",
    notificationImportance: AndroidNotificationImportance.Default,
    notificationIcon: AndroidResource(
        name: 'background_icon',
        defType: 'drawable'), // Default is ic_launcher from folder mipmap
  );
  bool initializeFunction =
      await FlutterBackground.initialize(androidConfig: androidConfig);
  bool backgroundFunction = await FlutterBackground.enableBackgroundExecution();
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: "Screen Usage Tracker",
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class ScreenStateEventEntry {
  ScreenStateEvent event;
  DateTime? time;

  ScreenStateEventEntry(this.event) {
    time = DateTime.now();
  }
}

class _MainScreenState extends State<MainScreen> {
  final Screen _screen = Screen();
  late StreamSubscription<ScreenStateEvent> _subscription;
  bool started = false;
  final List<ScreenStateEventEntry> _log = [];
  static const countdownDuration = Duration(hours: 3, minutes: 0, seconds: 0);
  Duration duration = const Duration();
  Timer? timer;
  bool isCountdown = false;
  late final notificationTime = PausableTimer(
      Duration(seconds: notificationTimerDurationSec),
      () => showNotification());
  var flp = FlutterLocalNotificationsPlugin();
  int notificationTimerDurationSec = 10;

  @override
  void initState() {
    super.initState();
    initPlatformState();
    startTimer();
    notificationTime.start();
    resetTimer();
    setup();
  }

  Future<void> initPlatformState() async {
    startListening();
  }

  void onData(ScreenStateEvent event) {
    setState(() {
      _log.add(ScreenStateEventEntry(event));
      print(event);
      if (event == ScreenStateEvent.SCREEN_ON) {
        startTimer();
        notificationTime.start();
      } else if (event == ScreenStateEvent.SCREEN_OFF) {
        pauseTimer();
        notificationTime.pause();
      }
    });
  }

  void startListening() {
    try {
      _subscription = _screen.screenStateStream!.listen(onData);
      setState(() => started = true);
    } on ScreenStateException catch (exception) {
      print(exception);
    }
  }

  void reset() {
    if (isCountdown) {
      setState(() {
        duration = countdownDuration;
      });
    } else {
      setState(() {
        duration = const Duration();
      });
    }
  }

  void addTime() {
    final addSeconds = isCountdown ? -1 : 1;

    setState(() {
      final seconds = duration.inSeconds + addSeconds;

      if (seconds < 0) {
        timer?.cancel();
      } else {
        duration = Duration(seconds: seconds);
      }
    });
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) => addTime());
  }

  void stopTimer({bool resets = true}) {
    if (resets) {
      reset();
      setState(() {
        timer?.cancel();
      });
    }
  }

  void pauseTimer() {
    setState(() {
      timer?.cancel();
    });
  }

  void resetTimer() {
    Timer.periodic(const Duration(hours: 24), (_) => reset());
  }

  Future<void> setup() async {
    var androidSetting =
        const AndroidInitializationSettings("@mipmap/ic_launcher");
    var iosSetting = const IOSInitializationSettings();
    var setupSetting =
        InitializationSettings(android: androidSetting, iOS: iosSetting);

    await flp.initialize(setupSetting,
        onSelectNotification: selectNotification);
  }

  Future<void> selectNotification(payLoad) async {
    if (payLoad != null) {
      print("Notification Selected: $payLoad");
    }
  }

  Future<void> showNotification() async {
    var androidNotificationDetail = const AndroidNotificationDetails(
      "Channel ID",
      "Channel Title",
      priority: Priority.high,
      importance: Importance.max,
    );
    var iosNotificationDetail = const IOSNotificationDetails();
    var notificationDetail = NotificationDetails(
        android: androidNotificationDetail, iOS: iosNotificationDetail);
    await flp.show(
        0,
        "🕒 SCREEN TIMEOUT 🕒",
        "The screen is on for $notificationTimerDurationSec seconds.",
        notificationDetail);
  }

  Widget buildTime() {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildTimeCard(time: hours, header: 'HOURS'),
        const SizedBox(width: 8),
        buildTimeCard(time: minutes, header: 'MINUTES'),
        const SizedBox(width: 8),
        buildTimeCard(time: seconds, header: 'SECONDS'),
      ],
    );
  }

  Widget buildTimeCard({required String time, required String header}) =>
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 72,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(header),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "You are using the screen for",
              style: TextStyle(fontSize: 30),
            ),
            buildTime(),
            /*ElevatedButton(
                onPressed: () {
                  startTimer();
                },
                child: Text("Start Timer")),
            ElevatedButton(
                onPressed: () {
                  stopTimer();
                },
                child: Text("Stop Timer")),*/
          ],
        ),
      ),
    );
  }
}
