/// Formats d'affichage. Règle validée : jamais de montant abrégé (« 214 k »).
const _nbsp = ' ';

/// 1248500 → « 1 248 500 » (espaces insécables, pas de coupure de ligne).
String formatInt(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(_nbsp);
    buf.write(digits[i]);
  }
  return '${negative ? '−' : ''}$buf';
}

/// 588256 → « 588 256 FCFA ».
String formatFcfa(int amount) => '${formatInt(amount)}${_nbsp}FCFA';

/// 0.5807 → « 58,1 % ».
String formatPercent(double? ratio, {int decimals = 1}) {
  if (ratio == null) return '—';
  final s = (ratio * 100).toStringAsFixed(decimals).replaceAll('.', ',');
  return '$s$_nbsp%';
}

const _months = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];
const _weekdays = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];

/// « 23 novembre 2026 » : mois écrit en toutes lettres.
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// « samedi 22 novembre 2026 ».
String formatLongDate(DateTime d) => '${_weekdays[d.weekday - 1]} ${formatDate(d)}';

/// Âge d'un lot en jours, calculé à partir de sa date (jamais saisi).
int ageInDays(DateTime start, DateTime today) {
  final s = DateTime(start.year, start.month, start.day);
  final t = DateTime(today.year, today.month, today.day);
  final d = t.difference(s).inDays;
  return d < 0 ? 0 : d;
}
