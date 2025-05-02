import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarWidget extends StatelessWidget {
  final Function(DateTime) onDateSelected;
  final DateTime focusedDay;

  const CalendarWidget({
    super.key,
    required this.onDateSelected,
    required this.focusedDay,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
          focusedDay: focusedDay,
          firstDay: DateTime(2020),
          lastDay: DateTime(2030),
          onDaySelected: (selectedDay, _) => onDateSelected(selectedDay),
        ),
      ),
    );
  }
}
