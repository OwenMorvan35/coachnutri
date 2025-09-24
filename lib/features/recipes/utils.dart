import 'dart:core';

String toKey(String s) {
  final lower = s.toLowerCase();
  final noDiacritics = _removeDiacritics(lower);
  final onlyAlnum = noDiacritics.replaceAll(RegExp(r'[^a-z0-9]'), '');
  return onlyAlnum;
}

String mapCategory(String? raw) {
  final k = toKey(raw ?? '');
  if (k.isEmpty) return 'autres';
  if (k.contains('boucher') || k.contains('viande') || k.contains('charcut')) {
    return 'boucherie';
  }
  if (k.contains('poisson')) {
    return 'boucherie'; // proche des protéines animales, regrouper simplement
  }
  if (k.contains('fruit') || k.contains('legume') || k.contains('salade')) {
    return 'fruits_legumes';
  }
  if (k.contains('lait') || k.contains('fromage') || k.contains('yaourt') || k.contains('creme')) {
    return 'cremerie';
  }
  if (k.contains('pain') || k.contains('boulanger')) {
    return 'boulangerie';
  }
  if (k.contains('surgele')) {
    return 'surgele';
  }
  if (k.contains('boisson') || k.contains('eau')) {
    return 'boissons';
  }
  if (k.contains('epicerie') || k.contains('pates') || k.contains('riz') || k.contains('conserve') || k.contains('huile') || k.contains('epice')) {
    return 'epicerie';
  }
  return 'autres';
}

String _removeDiacritics(String input) {
  // Basique et ciblé FR pour éviter dépendances externes
  const Map<String, String> map = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'æ': 'ae',
    'ç': 'c',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
    'ñ': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'œ': 'oe',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
    'ý': 'y', 'ÿ': 'y',
  };
  final sb = StringBuffer();
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    sb.write(map[ch] ?? ch);
  }
  return sb.toString();
}

