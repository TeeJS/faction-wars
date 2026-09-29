# world_1941_detail.jpg: provenance

The sector windows' theatre plates (src/ui/look_sector.gd; look.json
`textures.map_detail`). It is the strategic map's own picture again with
more pixels, so a theatre stays sharp at the window's scale. It covers
the same area as `world_1941.jpg`, so `pack.json`'s `map_image_rect`
applies to both.

## The work

| | |
|---|---|
| Title | Политическая карта мира (Political Map of the World) |
| In | Географический атлас для 5-го и 6-го классов средней школы (Geographic Atlas for the 5th and 6th Grades of Secondary School), 1941, pages 42-43 |
| Author | Главное Управление Геодезии и Картографии при СНК СССР (Main Administration of Geodesy and Cartography under the Council of People's Commissars of the USSR). Developed by its Central Research Institute of Geodesy, Aerial Survey and Cartography, with Moscow school teachers. Approved for printing 9 January to 3 June 1941. |

## The file it was made from

| | |
|---|---|
| Page | https://commons.wikimedia.org/wiki/File:42-43_%D0%9F%D0%BE%D0%BB%D0%B8%D1%82%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B0%D1%8F_%D0%BA%D0%B0%D1%80%D1%82%D0%B0_%D0%BC%D0%B8%D1%80%D0%B0.jpg |
| Original | https://upload.wikimedia.org/wikipedia/commons/9/90/42-43_%D0%9F%D0%BE%D0%BB%D0%B8%D1%82%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B0%D1%8F_%D0%BA%D0%B0%D1%80%D1%82%D0%B0_%D0%BC%D0%B8%D1%80%D0%B0.jpg |
| Uploaded | 6 October 2012, by Bestalex |
| Downloaded | 29 September 2026 |
| Size | 5,498 x 3,393 px, 4,593,635 bytes |
| SHA-1 | f5e820090a1f6bb418d43a331cd21a2fea0a9377 (matches the SHA-1 Commons publishes for the file) |
| SHA-256 | 843c341b780597a6d75f73f2fe54a2d5dfca8a32fc6d1762efc202ec8bc595d0 |

## Licence

Wikimedia Commons marks it **public domain** (Public Domain Mark 1.0):
"This work is in the public domain in its country of origin and other
countries and areas where the copyright term is the author's life plus 70
years or fewer."

⚠ The Commons page also says a United States public domain tag must be added
to show why it is public domain in the United States, and that tag is not on
the page. The same applies to `world_1941.jpg`, which is the same atlas scan
(see below). Its credit is CC0 from its contributor on publicdomainpictures.net.

## What was done to it

It is the same scan as `world_1941.jpg`: 4,375 of 4,455 matched SIFT features
fit one similarity transform, with 0.001 degree rotation, scale 2.864 and a
median residual of 0.55 scan pixels. The scan was resampled through that
transform onto `world_1941.jpg`'s own frame (bicubic at 3x, then area down to
4096 x 2458) and saved once as JPEG quality 88. The script rebuilds it byte
for byte.

Brought back down to 1750 x 1050, the result correlates 0.979 with
`world_1941.jpg`.

4096 wide keeps it within the texture size nearly all hardware supports in
a browser (WebGL's own minimum is lower). The scan itself has 2.86 times our
map's pixels over the same area.

Rebuild it with:

```
python tools/look/make_ww2_map_detail.py <the downloaded original> packs/ww2/look/world_1941_detail.jpg
```

| | |
|---|---|
| Result | 4096 x 2458 px, 2,251,754 bytes |
| SHA-256 | a32c36acacfb1ea3c3cbe74f3f77b8262847232af002466201d1b71e3bb651d8 |

# europe_1941.jpg: provenance

The Europe inset (look.json `map_insets`). The window spreads a theatre's
systems to fill it, so the five small European theatres (British Isles,
Western Europe, Central Europe, Iberia, Italian Peninsula) need the world map
magnified 5.1 to 8.8 times, where even the detail copy is too soft. This is
the same atlas's large-scale page of Europe, warped onto the strategic map's
frame, so those theatres are cut from it at 1.4 to 2.5 times (TeeJ,
2026-09-29: "we need them all to be the same").

## The work

| | |
|---|---|
| Title | Западная Европа. Политическая карта (Western Europe: Political Map), 1:25,000,000, Lambert azimuthal projection |
| In | the same atlas as above, page 14 |
| Author | Главное Управление Геодезии и Картографии при СНК СССР, as above |

## The file it was made from

| | |
|---|---|
| Page | https://commons.wikimedia.org/wiki/File:14_%D0%97%D0%B0%D0%BF%D0%B0%D0%B4%D0%BD%D0%B0%D1%8F_%D0%95%D0%B2%D1%80%D0%BE%D0%BF%D0%B0._%D0%9F%D0%BE%D0%BB%D0%B8%D1%82%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B0%D1%8F_%D0%BA%D0%B0%D1%80%D1%82%D0%B0.jpg |
| Original | https://upload.wikimedia.org/wikipedia/commons/c/c8/14_%D0%97%D0%B0%D0%BF%D0%B0%D0%B4%D0%BD%D0%B0%D1%8F_%D0%95%D0%B2%D1%80%D0%BE%D0%BF%D0%B0._%D0%9F%D0%BE%D0%BB%D0%B8%D1%82%D0%B8%D1%87%D0%B5%D1%81%D0%BA%D0%B0%D1%8F_%D0%BA%D0%B0%D1%80%D1%82%D0%B0.jpg |
| Uploaded | 6 October 2012, by Bestalex |
| Downloaded | 29 September 2026 |
| Size | 2,743 x 3,395 px, 2,680,364 bytes |
| SHA-1 | 95c90b6c7c9eb9fb29de16785aceb366a648466a (matches the SHA-1 Commons publishes for the file) |
| SHA-256 | fabbae49cddab9fca815ef38112a97fd5914e7f55734eeed3bfc5272abf03850 |

## Licence

The same as the world page: Commons marks it **public domain** (Public Domain
Mark 1.0, "PD Old"), with the same ⚠ missing United States tag.

## What was done to it

Page 14 is a different projection from the world page, so no single
transform lines them up. `tools/look/make_ww2_map_europe.py` fits one from
the two pages themselves, automatically: the sea of each as a mask; a search
for the best overlap; coastline patches matched shape against shape, then
country fills matched inland; a thin-plate spline through the 193 anchors
that agree. Its docstring has the steps. The page was warped through it onto
map units 328-385 x 120-172 of the strategic map's frame (look.json `at`
[328, 120, 57, 52]), 21 px per map unit (page 14's own density), Lanczos, and
saved once as JPEG quality 88. The script rebuilds it byte for byte.

How close it is:

| | |
|---|---|
| Anchors, each left out in turn | median 0.9, 90% 1.6, worst 2.5 px of the detail map |
| Anchors per theatre (within 40 px) | British Isles 20, Western Europe 42, Central Europe 35, Iberia 12, Italian Peninsula 46 |
| City symbols read on both pages | 5 to 15 px of the detail map apart at some (Lisbon, Prague) |
| The pack's own systems | placed on the world page by a fit of 18 px RMS on the 1750-px map (PACK.md, "Map layout"), about 40 px of the detail map |

So the plate sits each of those theatres' systems in its own country, as the
strategic map does. Gibraltar's system was on the Moroccan shore on both,
where the pack had put it; #403 moves it onto the Rock.

Iberia is the softest of the five (2.5 times, 2.9 once Gibraltar is on the
Rock and its window turns landscape). The atlas's Spain and Portugal page
(p19, 1:5,000,000) was looked at and not used (TeeJ, 2026-09-29, "stay on
page 14"): it is a physical map, coloured by height rather than by country,
and it ends at about 35.7 N, short of the window's southern edge.

Rebuild it with:

```
python tools/look/make_ww2_map_europe.py <the downloaded original> packs/ww2/look/europe_1941.jpg
```

| | |
|---|---|
| Result | 1197 x 1092 px, 443,126 bytes |
| SHA-256 | b7ce77b13e46065b82d4c870e8131c4262f393f974bf822d56c7d544d99d5c89 |
