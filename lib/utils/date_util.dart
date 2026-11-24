import 'package:intl/intl.dart';

/// 日期时间格式化工具
class DateUtil {
  DateUtil._();

  static final DateFormat _full = DateFormat('yyyy/MM/dd HH:mm');
  static final DateFormat _date = DateFormat('yyyy/MM/dd');
  static final DateFormat _time = DateFormat('HH:mm');

  /// 完整：2026/11/19 15:00
  static String full(DateTime dt) => _full.format(dt);

  /// 仅日期：2026/11/19
  static String date(DateTime dt) => _date.format(dt);

  /// 智能显示：今天显示时分，今年显示月日，往年显示完整
  static String smart(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return _time.format(dt);
    }
    if (dt.year == now.year) {
      return DateFormat('MM/dd HH:mm').format(dt);
    }
    return _full.format(dt);
  }
}
