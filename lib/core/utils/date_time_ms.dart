/// Último instante del día local correspondiente a [fechaMs].
int endOfLocalDayMs(int fechaMs) {
  final d = DateTime.fromMillisecondsSinceEpoch(fechaMs);
  final end = DateTime(d.year, d.month, d.day, 23, 59, 59, 999);
  return end.millisecondsSinceEpoch;
}
