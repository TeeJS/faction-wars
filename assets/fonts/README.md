# Fonts

**Liberation Sans 2.1.5** (Regular, Bold) - the game's face wherever the
original's own is not there.

The original draws every word in **Arial**: REBEXE names that one face for
GDI's `CreateFontIndirectA` and ships no font of its own, so it is Windows'.
Arial may not be redistributed, and a web game cannot use the computer's own
fonts (Godot's `SystemFont` "is implemented on iOS, Linux, macOS and Windows,
on other platforms it will fallback to default theme font"). Liberation Sans
is built to Arial's metrics - every letter the same width - so text wraps and
fits as the original's does.

Where the game finds a face, first to last (`OUI.Face`):

1. the original's own Arial in the player's art set (`fonts/arial.ttf`,
   `arialbd.ttf`) - the exporter copies the player's Windows Arial there,
   as it does the original's pictures;
2. the system's Arial (desktop builds);
3. these files.

- Source: the Liberation Fonts project's release 2.1.5,
  https://github.com/liberationfonts/liberation-fonts/releases -
  `liberation-fonts-ttf-2.1.5.tar.gz` (2,385,008 bytes, SHA-256
  `7191C669BF38899F73A2094ED00F7B800553364F90E2637010A69C0E268F25D0`),
  downloaded 2026-09-28. The two .ttf files, `LICENSE` and `AUTHORS` are
  copied unchanged.
- Licence: SIL Open Font License 1.1 (`LICENSE`): digitized data copyright
  (c) 2010 Google Corporation, copyright (c) 2012 Red Hat, Inc., Reserved Font
  Name "Liberation". Its designer and maintainers are in `AUTHORS`.
