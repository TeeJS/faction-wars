# The WWII pack's faces

The three faces the pack's look (`../../look.json`, docs/ww2-look-plan.md)
draws in. All three are under the **SIL Open Font License 1.1**; each licence
file sits beside its font and ships with it. The fonts are **unmodified**
(Source Sans carries the Reserved Font Name "Source", so a changed copy could
not keep the name). Downloaded 2026-09-28 with TeeJ's approval; the same facts
are in `packs/ww2/credits.json`, which the Credits sheet reads.

| File | What it is for |
|---|---|
| `Oswald-Variable.ttf` | section labels, headers, title bars: a rework of the "Alternate Gothic" faces of period newspapers and signage |
| `SourceSans3VF-Upright.ttf` | data and body text: humanist, very legible, tabular figures |
| `CourierPrime-Regular.ttf`, `CourierPrime-Bold.ttf` | typed dispatch headings only (Courier dates from 1956: typewriter, not strictly period) |

## Oswald

- Source: https://github.com/googlefonts/OswaldFont, `fonts/variable/Oswald[wght].ttf`
  (172,088 bytes, SHA-256 `5B38C246E255A12F5712D640D56BCCED0472466FC68983D2D0410EC0457C2817`)
  at commit `e94d8f3604e713dec574aa13a69141f3e24599d9` (branch `main` at
  `89795261ac9eeb9aa8cd99f43982c4e4b0e53261`). Renamed to `Oswald-Variable.ttf`
  (a `[` in a resource path is trouble); the bytes are unchanged.
- Licence: `Oswald-OFL.txt` (the repository's `OFL.txt`, 4,483 bytes, SHA-256
  `0FD731A904B729A4E02EAF5E8EBD06783EDD9ABE400E8882760160230675B652`):
  "Copyright 2016 The Oswald Project Authors". Author: Vernon Adams.

## Source Sans 3

- Source: https://github.com/adobe-fonts/source-sans/releases/tag/3.052R,
  `VF-source-sans-3.052R.zip` (795,927 bytes, SHA-256
  `D8E2AC355E06E6A0F0E0A0B1AC0C2451AFA707584D7BB9D6B11EF9E4B749904C`; tag at
  `5d173ba058bda87bcff2bb2d53b9d2c59d440ff6`). `VF/SourceSans3VF-Upright.ttf`
  taken from it unchanged (646,540 bytes, SHA-256
  `1147DB9A3F0EDD4956068DE77930148ACCE2742DD76D57F7239B2B1C687AC63F`); the
  italic is not used.
- Licence: `SourceSans3-LICENSE.txt` (the repository's `LICENSE.md` on branch
  `release`, renamed so the web export carries it - it drops `*.md`; 4,486 bytes,
  SHA-256 `56AF9B9C6715597E458284A474DC118A50A4150E9D547C70F7B4A33C3E6A9328`):
  "Copyright 2010-2024 Adobe ... with Reserved Font Name 'Source'".
  Designed by Paul D. Hunt for Adobe.

## Courier Prime

- Source: https://github.com/quoteunquoteapps/CourierPrime, `fonts/ttf/`
  at commit `33d9d2ca2f56e6d348f6b84d4d10a34550f74220` (branch `master` at
  `7fd585a2dd4c1612c79b3308e300923d1c13df93`):
  `CourierPrime-Regular.ttf` (71,188 bytes, SHA-256
  `72F793376F8E2841656BF21D77A5DE010F2929BD6956A22EE848AD0C7EB978AF`),
  `CourierPrime-Bold.ttf` (72,856 bytes, SHA-256
  `FF1F38786C849D1C41FA8E447960ABDB2BD75FDFB0CFCDEB524FAD65A5AF3638`), unchanged.
- Licence: `CourierPrime-OFL.txt` (the repository's `OFL.txt`, 4,403 bytes,
  SHA-256 `9A755AF092B494944C99F471BE6FDDD19B006A448FEFDC4717E4EE0AA09A97B0`):
  "Copyright 2015 The Courier Prime Project Authors". Authors: Alan
  Dague-Greene, Quote-Unquote Apps.
