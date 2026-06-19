import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
    
    // Inicializar fuso horário
    tz.initializeTimeZones();
    final currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone.identifier));
  }

  Future<void> scheduleRestNotification(int seconds) async {
    await flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: 'Descanso Finalizado!',
      body: 'Hora de voltar para a próxima série!',
      scheduledDate: tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer_channel',
          'Temporizador de Descanso',
          channelDescription: 'Notificações de fim de descanso no treino',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showActiveTimerNotification(int remainingSeconds, int totalSeconds) async {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: '⏱️ Descanso em Andamento',
      body: 'Tempo restante: $timeString',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer_channel',
          'Temporizador de Descanso',
          channelDescription: 'Notificações de fim de descanso no treino',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true, // Faz a notificação ficar constante
          autoCancel: false,
          showWhen: false,
          onlyAlertOnce: true, // Evita som/vibração a cada atualização
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> updateTimerNotification(int remainingSeconds) async {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final timeString = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    await flutterLocalNotificationsPlugin.show(
      id: 1,
      title: '⏱️ Descanso em Andamento',
      body: 'Tempo restante: $timeString',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'rest_timer_channel',
          'Temporizador de Descanso',
          channelDescription: 'Notificações de fim de descanso no treino',
          importance: Importance.high,
          priority: Priority.high,
          ongoing: true,
          autoCancel: false,
          showWhen: false,
          onlyAlertOnce: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: false,
          presentBadge: true,
          presentSound: false,
        ),
      ),
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
