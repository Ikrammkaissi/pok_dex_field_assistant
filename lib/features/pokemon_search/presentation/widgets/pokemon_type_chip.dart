/// Colored pill badge that displays a Pokémon type name.
/// Each type has its own background colour drawn from the official game palette.
import 'package:flutter/material.dart';

/// Maps PokéAPI type names to their canonical game colours.
/// Keys are lowercase as returned by the API (e.g. 'fire', 'grass').
const Map<String, Color> _typeColors = {
  'normal': Color(0xFFA8A77A),
  'fire': Color(0xFFEE8130),
  'water': Color(0xFF6390F0),
  'electric': Color(0xFFF7D02C),
  'grass': Color(0xFF7AC74C),
  'ice': Color(0xFF96D9D6),
  'fighting': Color(0xFFC22E28),
  'poison': Color(0xFFA33EA1),
  'ground': Color(0xFFE2BF65),
  'flying': Color(0xFFA98FF3),
  'psychic': Color(0xFFF95587),
  'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136),
  'ghost': Color(0xFF735797),
  'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746),
  'steel': Color(0xFFB7B7CE),
  'fairy': Color(0xFFD685AD),
};

/// A small rounded chip showing [typeName] with its type-specific background.
class PokemonTypeChip extends StatelessWidget {
  /// Pokémon type name in lowercase (e.g. 'fire', 'grass').
  final String typeName;

  /// Creates a [PokemonTypeChip] for [typeName].
  const PokemonTypeChip({super.key, required this.typeName});

  @override
  Widget build(BuildContext context) {
    /// Fall back to grey for any unknown type names.
    final color = _typeColors[typeName] ?? Colors.grey;

    return Container(
      /// Horizontal padding gives the pill shape more breathing room.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        /// Fully rounded ends make this a pill / lozenge shape.
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        /// Capitalise the first letter for display (e.g. 'Fire', 'Grass').
        typeName[0].toUpperCase() + typeName.substring(1),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
