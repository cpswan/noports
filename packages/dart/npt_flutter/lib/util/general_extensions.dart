extension StringExtension on String {
  String atsignify() {
    var value = this;
    if (!startsWith('@')) {
      value = '@$this';
    }
    if (endsWith(' ')) {
      value = trim();
    }
    return value;
  }
}
