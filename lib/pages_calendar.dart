import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import 'pages_food_form.dart';
import 'providers.dart';
import 'localization.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<FoodProvider>().items;
    final events = <DateTime, List<int>>{}; // date -> indices of items
    for (var i = 0; i < items.length; i++) {
      final d = DateTime(
        items[i].expiryDate.year,
        items[i].expiryDate.month,
        items[i].expiryDate.day,
      );
      events.putIfAbsent(d, () => []).add(i);
    }
    final selected =
        _selectedDay == null
            ? <int>[]
            : events[DateTime(
                  _selectedDay!.year,
                  _selectedDay!.month,
                  _selectedDay!.day,
                )] ??
                <int>[];

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).calendarTitle)),
      body: Column(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TableCalendar(
              locale:
                  context.watch<AppSettingsProvider>().locale.languageCode ==
                          'en'
                      ? 'en'
                      : 'zh_TW',
              firstDay: DateTime.now().subtract(Duration(days: 365)),
              lastDay: DateTime.now().add(Duration(days: 365 * 3)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              calendarStyle: CalendarStyle(
                // 選取日期的背景色 - 使用較深的橘色以突出顯示
                selectedDecoration: BoxDecoration(
                  color: const Color(0xFFFF914D), // 較深的橘色
                  shape: BoxShape.circle,
                ),
                // 選取日期的文字顏色
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                // 今天日期的背景色 - 根據主題調整
                todayDecoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF3A3A3A).withOpacity(
                            0.5,
                          ) // 深色主題使用深灰色
                          : const Color(
                            0xFFFFB366,
                          ).withOpacity(0.3), // 淺色主題使用淺橘色
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors
                                .white // 深色主題使用白色邊框
                            : const Color(0xFFFF914D), // 淺色主題使用深橘色邊框
                    width: 2,
                  ),
                ),
                // 今天日期的文字顏色
                todayTextStyle: const TextStyle(
                  color: Color(0xFFFF914D), // 深橘色文字
                  fontWeight: FontWeight.bold,
                ),
                // 預設日期的文字顏色
                defaultTextStyle: const TextStyle(color: Colors.black87),
                // 週末的文字顏色
                weekendTextStyle: const TextStyle(color: Colors.black87),
              ),
              eventLoader: (day) {
                final key = DateTime(day.year, day.month, day.day);
                return (events[key] ?? const <int>[]);
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, eventList) {
                  if (eventList.isEmpty) return null;
                  return Align(
                    alignment: Alignment.bottomRight,
                    child: Container(
                      margin: const EdgeInsets.only(right: 3, bottom: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).brightness == Brightness.dark
                                ? Colors
                                    .white // 深色主題使用白色
                                : const Color(0xFFFF914D), // 淺色主題使用深橘色
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${eventList.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: selected.length,
              itemBuilder: (context, index) {
                final item = items[selected[index]];
                return ListTile(
                  leading: Icon(
                    Icons.fastfood,
                    color:
                        item.daysLeft < 0
                            ? Colors.red
                            : (item.daysLeft <= 3
                                ? Colors.orange
                                : Colors.green),
                  ),
                  title: Text(item.name),
                  subtitle: Text(
                    '${AppLocalizations.of(context).expiryDate}${item.expiryDate.toString().split(' ').first}',
                  ),
                  trailing: Text('${item.quantity}${item.unit}'),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodFormPage(initial: item),
                        ),
                      ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
