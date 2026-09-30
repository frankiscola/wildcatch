import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/type_badge_assets.dart';

/// Round icon for a type option in a filter: the type's badge art from
/// assets/type_badges/, or a plain colored circle for any type that
/// doesn't have a badge image.
class TypeOptionIcon extends StatelessWidget {
  final String type;
  final double size;

  const TypeOptionIcon({super.key, required this.type, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final asset = TypeBadgeAssets.of(type);
    return SizedBox(
      width: size,
      height: size,
      child: asset != null
          ? Image.asset(asset, fit: BoxFit.contain)
          : DecoratedBox(
              decoration: BoxDecoration(color: TypeColors.of(type), shape: BoxShape.circle),
            ),
    );
  }
}

/// Round icon for an animal-species option: an emoji for the common
/// animals, a paw print for anything not in the list.
///
/// Species come from on-device image recognition, so they are an
/// open-ended set of labels ("Beetle", "Grub", "Parrot"...) rather
/// than a fixed list — [_animalEmoji] only covers the common ones and
/// unknown species simply get the paw. Add entries as new species show
/// up in the journal.
class AnimalOptionIcon extends StatelessWidget {
  final String species;
  final double size;

  const AnimalOptionIcon({super.key, required this.species, this.size = 30});

  @override
  Widget build(BuildContext context) {
    final emoji = _emojiFor(species);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.grassGreen.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: emoji != null
          ? Text(emoji, style: TextStyle(fontSize: size * 0.55, height: 1.0))
          : Icon(Icons.pets, size: size * 0.55, color: AppColors.grassGreen),
    );
  }

  /// Matches whole words only ("caterpillar" must not match "cat",
  /// "beetle" must not match "bee"), and tolerates a plural "s".
  static String? _emojiFor(String species) {
    final words = species.toLowerCase().split(RegExp(r'[^a-z]+'));
    for (final word in words) {
      if (word.isEmpty) continue;
      final direct = _animalEmoji[word];
      if (direct != null) return direct;
      if (word.endsWith('s')) {
        final singular = _animalEmoji[word.substring(0, word.length - 1)];
        if (singular != null) return singular;
      }
    }
    return null;
  }
}

const Map<String, String> _animalEmoji = {
  // Pets & farm
  'cat': '🐱',
  'kitten': '🐱',
  'dog': '🐶',
  'puppy': '🐶',
  'horse': '🐴',
  'pony': '🐴',
  'cow': '🐮',
  'cattle': '🐮',
  'pig': '🐷',
  'sheep': '🐑',
  'goat': '🐐',
  'rabbit': '🐰',
  'bunny': '🐰',
  'hare': '🐰',
  'mouse': '🐭',
  'rat': '🐀',
  'hamster': '🐹',
  // Birds
  'bird': '🐦',
  'parrot': '🦜',
  'owl': '🦉',
  'duck': '🦆',
  'chicken': '🐔',
  'rooster': '🐓',
  'eagle': '🦅',
  'penguin': '🐧',
  'swan': '🦢',
  'pigeon': '🕊️',
  'dove': '🕊️',
  // Wild mammals
  'fox': '🦊',
  'wolf': '🐺',
  'bear': '🐻',
  'deer': '🦌',
  'squirrel': '🐿️',
  'hedgehog': '🦔',
  'bat': '🦇',
  'raccoon': '🦝',
  'otter': '🦦',
  'monkey': '🐵',
  'elephant': '🐘',
  'lion': '🦁',
  'tiger': '🐯',
  'giraffe': '🦒',
  'zebra': '🦓',
  // Reptiles & amphibians
  'frog': '🐸',
  'toad': '🐸',
  'turtle': '🐢',
  'tortoise': '🐢',
  'lizard': '🦎',
  'gecko': '🦎',
  'reptile': '🦎',
  'snake': '🐍',
  'crocodile': '🦎',
  'alligator': '🦎',
  // Water
  'fish': '🐟',
  'goldfish': '🐟',
  'shark': '🦈',
  'whale': '🐳',
  'dolphin': '🐬',
  'octopus': '🐙',
  'crab': '🦀',
  'shrimp': '🦐',
  // Bugs & crawlers
  'butterfly': '🦋',
  'moth': '🦋',
  'bee': '🐝',
  'wasp': '🐝',
  'ant': '🐜',
  'ladybug': '🐞',
  'ladybird': '🐞',
  'beetle': '🪲',
  'spider': '🕷️',
  'scorpion': '🦂',
  'snail': '🐌',
  'slug': '🐌',
  'caterpillar': '🐛',
  'grub': '🐛',
  'larva': '🐛',
  'worm': '🪱',
  'insect': '🐛',
  'bug': '🐛',
  'fly': '🪰',
  'mosquito': '🦟',
  'cricket': '🦗',
  'grasshopper': '🦗',
};
