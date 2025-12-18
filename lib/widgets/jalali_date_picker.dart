import 'package:flutter/material.dart';
import '../utils/jalali_date.dart';
import '../theme/app_theme.dart';

/// نمایش DatePicker شمسی
Future<DateTime?> showJalaliDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  return showDialog<DateTime>(
    context: context,
    builder: (context) => _JalaliDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _JalaliDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _JalaliDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_JalaliDatePickerDialog> createState() => _JalaliDatePickerDialogState();
}

class _JalaliDatePickerDialogState extends State<_JalaliDatePickerDialog> {
  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;
  late JalaliDate _jalaliFirst;
  late JalaliDate _jalaliLast;

  @override
  void initState() {
    super.initState();
    final jalali = JalaliDate.fromDateTime(widget.initialDate);
    _selectedYear = jalali.year;
    _selectedMonth = jalali.month;
    _selectedDay = jalali.day;
    _jalaliFirst = JalaliDate.fromDateTime(widget.firstDate);
    _jalaliLast = JalaliDate.fromDateTime(widget.lastDate);
  }

  List<int> get _years {
    return List.generate(
      _jalaliLast.year - _jalaliFirst.year + 1,
      (i) => _jalaliFirst.year + i,
    );
  }

  int get _daysInMonth {
    if (_selectedMonth <= 6) return 31;
    if (_selectedMonth <= 11) return 30;
    // اسفند - سال کبیسه
    return _isLeapYear(_selectedYear) ? 30 : 29;
  }

  bool _isLeapYear(int year) {
    final a = [1, 5, 9, 13, 17, 22, 26, 30];
    return a.contains(year % 33);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // عنوان
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'انتخاب تاریخ تولد',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // انتخاب‌گرها
              Row(
                children: [
                  // روز
                  Expanded(
                    child: Column(
                      children: [
                        const Text('روز', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedDay > _daysInMonth ? _daysInMonth : _selectedDay,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: List.generate(_daysInMonth, (i) => i + 1)
                                .map((d) => DropdownMenuItem(value: d, child: Text('$d')))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedDay = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ماه
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        const Text('ماه', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedMonth,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: List.generate(12, (i) => i + 1)
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(JalaliDate.monthNames[m - 1]),
                                    ))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedMonth = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // سال
                  Expanded(
                    child: Column(
                      children: [
                        const Text('سال', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButton<int>(
                            value: _selectedYear,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: _years
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                .toList(),
                            onChanged: (v) => setState(() => _selectedYear = v!),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // نمایش تاریخ انتخاب شده
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$_selectedDay ${JalaliDate.monthNames[_selectedMonth - 1]} $_selectedYear',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // دکمه‌ها
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('انصراف'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final day = _selectedDay > _daysInMonth ? _daysInMonth : _selectedDay;
                        final jalali = JalaliDate(_selectedYear, _selectedMonth, day);
                        Navigator.pop(context, jalali.toDateTime());
                      },
                      child: const Text('تایید'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
