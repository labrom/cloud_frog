import 'dart:io';

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Provides time locally and in specific timezones.
class DateTimeService {

  /// Gets the [DateTimeService] singleton.
  factory DateTimeService() => _instance;

  DateTimeService._() {
    tz.initializeTimeZones();
  }

  static final _instance = DateTimeService._();

  /// Returns the current time in the local timezone.
  /// 
  /// The local timezone name is read from the 'TZ' environment variable.
  /// If the TZ environment variable isn't set, [DateTime.now()] is returned,
  /// which is also supposed to be the local time, but is system-dependent.
  /// The timezone in the 'TZ' environment variable should be specified as in
  /// the following examples: 'America/New_York', 'Europe/London', 'Asia/Tokyo'.
  DateTime localNow() {
    final timezone = Platform.environment['TZ'];
    if (timezone == null) {
      return DateTime.now();
    }
    return now(timezone);
  }

  /// Returns the current time in the specified [timezone].
  /// Example: 'America/New_York', 'Europe/London', 'Asia/Tokyo'
  tz.TZDateTime now(String timezone) {
    try {
      final location = tz.getLocation(timezone);
      return tz.TZDateTime.now(location);
    } on tz.LocationNotFoundException {
      // Fallback or error handling if the timezone string is invalid
      throw ArgumentError('Invalid timezone: $timezone');
    }
  }

  /// Helper to convert an existing DateTime to a specific timezone
  tz.TZDateTime translate(DateTime dateTime, String timezoneName) {
    final location = tz.getLocation(timezoneName);
    return tz.TZDateTime.from(dateTime, location);
  }
}
