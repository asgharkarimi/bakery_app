/// تبدیل تاریخ میلادی به شمسی
class JalaliDate {
  final int year;
  final int month;
  final int day;

  JalaliDate(this.year, this.month, this.day);

  /// تبدیل از DateTime میلادی به شمسی
  factory JalaliDate.fromDateTime(DateTime date) {
    final result = _gregorianToJalali(date.year, date.month, date.day);
    return JalaliDate(result[0], result[1], result[2]);
  }

  /// تبدیل به DateTime میلادی
  DateTime toDateTime() {
    final result = _jalaliToGregorian(year, month, day);
    return DateTime(result[0], result[1], result[2]);
  }

  /// نام ماه‌های شمسی
  static const List<String> monthNames = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
    'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  String get monthName => monthNames[month - 1];

  @override
  String toString() => '$year/$month/$day';

  String toFullString() => '$day $monthName $year';

  /// تبدیل میلادی به شمسی
  static List<int> _gregorianToJalali(int gy, int gm, int gd) {
    List<int> gdm = [0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    int jy;
    if (gy > 1600) {
      jy = 979;
      gy -= 1600;
    } else {
      jy = 0;
      gy -= 621;
    }
    int gy2 = (gm > 2) ? (gy + 1) : gy;
    int days = (365 * gy) +
        ((gy2 + 3) ~/ 4) -
        ((gy2 + 99) ~/ 100) +
        ((gy2 + 399) ~/ 400) -
        80 +
        gd;
    for (int i = 0; i < gm; ++i) {
      days += gdm[i];
    }
    jy += 33 * (days ~/ 12053);
    days %= 12053;
    jy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      jy += ((days - 1) ~/ 365);
      days = (days - 1) % 365;
    }
    int jm, jd;
    if (days < 186) {
      jm = 1 + (days ~/ 31);
      jd = 1 + (days % 31);
    } else {
      jm = 7 + ((days - 186) ~/ 30);
      jd = 1 + ((days - 186) % 30);
    }
    return [jy, jm, jd];
  }

  /// تبدیل شمسی به میلادی
  static List<int> _jalaliToGregorian(int jy, int jm, int jd) {
    int gy;
    if (jy > 979) {
      gy = 1600;
      jy -= 979;
    } else {
      gy = 621;
    }
    int days = (365 * jy) +
        ((jy ~/ 33) * 8) +
        (((jy % 33) + 3) ~/ 4) +
        78 +
        jd +
        ((jm < 7) ? (jm - 1) * 31 : ((jm - 7) * 30) + 186);
    gy += 400 * (days ~/ 146097);
    days %= 146097;
    if (days > 36524) {
      gy += 100 * (--days ~/ 36524);
      days %= 36524;
      if (days >= 365) days++;
    }
    gy += 4 * (days ~/ 1461);
    days %= 1461;
    if (days > 365) {
      gy += ((days - 1) ~/ 365);
      days = (days - 1) % 365;
    }
    int gd = days + 1;
    List<int> sal = [
      0, 31, ((gy % 4 == 0 && gy % 100 != 0) || (gy % 400 == 0)) ? 29 : 28,
      31, 30, 31, 30, 31, 31, 30, 31, 30, 31
    ];
    int gm = 0;
    for (gm = 0; gm < 13 && gd > sal[gm]; gm++) {
      gd -= sal[gm];
    }
    return [gy, gm, gd];
  }
}
