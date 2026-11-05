const _weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];

/// The backend sends and expects dates as text, "2026-09-01", so timezones can't shift them.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// "2026-09-01" → "01 SEP". Reads the text directly, so no timezone is involved.
String shortDate(String iso) => '${iso.substring(8, 10)} ${_months[int.parse(iso.substring(5, 7)) - 1]}';

/// "2026-09-01" → "01 SEP 2026".
String longDate(String iso) => '${shortDate(iso)} ${iso.substring(0, 4)}';

/// "2026-09-01" → "TUE". Uses UTC so a timezone can't move the date to the day before.
String weekdayName(String iso) => _weekdays[DateTime.parse('${iso}T00:00:00Z').weekday - 1];

/// An hour and minute as the backend's 24-hour text, "09:05".
String timeText(int hour, int minute) => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
