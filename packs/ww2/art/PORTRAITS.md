# WWII personnel pictures: where each comes from

## Comic card adaptations (2026-10-04)

The 400 x 200 Encyclopedia cards in `art/characters/` now contain 71 AI-redrawn
portraits in vintage 1940s comic style. Their original
paper, faction stripe, ruled area, white photo borders and black corner mounts are
retained; the replacement artwork is clipped into the existing portrait aperture.
The redraws use the source photographs credited below, with balanced framing and
reconstructed shoulders where the original symbol-removal crop was tight. German
uniforms and caps omit Nazi emblems, eagles, SS insignia and German decorations.
All 71 final cards were visually reviewed for symbols, likeness and framing.

Hitler, Himmler, Raeder and Leclerc were completed on later neutral historical edits after initial image-tool rejections. The historical failures remain logged, and the selected final portraits contain no Nazi symbols. The 80 x 80
portraits and 61 x 25 miniatures of all 71 are cut from their redrawn cards by
`tools/look/make_ww2_small_from_plates.py characters`.

Source author, attribution, licence and licence links below and in `../credits.json`
continue to apply to the adaptations. CC BY-SA adaptations are distributed under
the same listed source licence; the redraw does not remove attribution or
ShareAlike obligations. No additional photographic source was substituted.

All 71 original cards are preserved byte-for-byte in
`characters/backup-originals-2026-10-04/`, with SHA-256 hashes. Finished cards,
1600 x 800 assembled masters, raw generations, prompts, source metadata, review
contact sheets and rejection records are in
`characters/vintage-1940s-comic-masters-2026-10-04/`. Both archive directories have
`.gdignore` files so they are excluded from game imports and exports.

**Regeneration:** `make_ww2_portraits.py` recreates the original photographic cards
and will overwrite these adaptations. After running it, restore the 71 finished
cards from the archive's `game-size/` directory, then run
`make_ww2_small_from_plates.py characters` again. The JSON source records and the
crop table below document the original photographic pipeline.

## Original photographic sources and pipeline

Made by `tools/look/make_ww2_portraits.py` from `tools/look/ww2_portraits.json`. Each character's three pictures (SCHEMA.md
section 14: `characters/<id>.png` 400x200, `portraits/characters/<id>.png`
80x80, `miniatures/characters/<id>.png` 61x25) are cut from one photograph on
Wikimedia Commons: public domain, CC0, CC BY or CC BY-SA only, checked on the
file's own page. The SHA-1 is Commons' own for the original, and the script
refuses a download that does not match it. The crop is `[cx, cy, side]`: the
square's centre as fractions of the picture's width and height, its side as a
fraction of the height. Each is framed as an ID photograph (TeeJ,
2026-09-30): the whole head, its top a tenth of the way down, centred
across, the head about half to three-fifths of the height with the
shoulders below - checked by eye in each rendered square, not only on the
original. Where the photograph runs out it fades out like a studio print.
Where a Nazi symbol sits below the head, a fourth number cuts the
photograph off above it and the print fades out below the cut (the notes);
Model alone keeps his cap cut, below the swastika on its eagle.
No picture shows a swastika or an Iron Cross, and
each German portrait was checked by eye; an eagle may show, as long as the
swastika does not (TeeJ, 2026-09-30). A person with no freely licensed
photograph gets the drawn stand-in instead.

| Character | id | Commons file | Licence | Author / attribution | SHA-1 and crop |
|---|---|---|---|---|---|
| Adolf Hitler | `hitler` | [Adolf Hitler cropped restored 3x4.jpg](https://commons.wikimedia.org/wiki/File:Adolf_Hitler_cropped_restored_3x4.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 183-S33882 / CC BY-SA 3.0 DE | `5061e9e427ffd617f63638af96fb4ff311a8785e` `[0.52, 0.4389, 1.0293, 0.88]` |
| Benito Mussolini | `mussolini` | [Mussolini mezzobusto.jpg](https://commons.wikimedia.org/wiki/File:Mussolini_mezzobusto.jpg) | Public domain (PD-Italia, PD-1996) | Unknown | `33040b918cd0400c6e68a2c6b0154c82f3c26021` `[0.4449, 0.2838, 0.5737]` |
| Hideki Tojo | `tojo` | [Hideki Tojo.jpg](https://commons.wikimedia.org/wiki/File:Hideki_Tojo.jpg) | Public domain (PD-USGov-Military-Army) | Unknown | `554c245d121c7aa26ffc4cfed0735a69f81f5d78` `[0.5217, 0.2983, 0.695]` |
| Hermann Göring | `goring` | [Hermann Göring - Röhr.jpg](https://commons.wikimedia.org/wiki/File:Hermann_G%C3%B6ring_-_R%C3%B6hr.jpg) | Public domain (PD-Poland) | Robert Röhr | `de2cea82677562642573561736b07c53c186a1bd` `[0.4856, 0.3279, 0.7774, 0.6]` |
| Joseph Goebbels | `goebbels` | [Bundesarchiv Bild 146-1968-101-20A, Joseph Goebbels.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146-1968-101-20A,_Joseph_Goebbels.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 146-1968-101-20A / Heinrich Hoffmann / CC-BY-SA 3.0 | `89d5837f01ae37221f572eeb703b20f5af8d6858` `[0.4806, 0.3785, 0.8531]` |
| Heinrich Himmler | `himmler` | [Bundesarchiv Bild 183-S72707, Heinrich Himmler.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_183-S72707,_Heinrich_Himmler.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 183-S72707 / CC-BY-SA 3.0 | `cf6bd1a5080bcce166a8309a6cd5030da254c6e7` `[0.5377, 0.3287, 0.6895, 0.57]` |
| Wilhelm Canaris | `canaris` | [Bundesarchiv Bild 146-1979-013-43, Wilhelm Canaris.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146-1979-013-43,_Wilhelm_Canaris.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 146-1979-013-43 / CC-BY-SA 3.0 | `53bd3c52dfbcedf145eb11ad2fcd0b7af2b29bcc` `[0.5074, 0.3959, 0.9548, 0.8]` |
| Albert Speer | `speer` | [Bundesarchiv Bild 146II-277, Albert Speer.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146II-277,_Albert_Speer.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 146II-277 / Binder / CC-BY-SA 3.0 | `0d596362de26df9dcf54e56d3687766d132e085b` `[0.4759, 0.4232, 1.0002, 0.88]` |
| Erwin Rommel | `rommel` | [Erwin-Rommel-1941 (2).jpg](https://commons.wikimedia.org/wiki/File:Erwin-Rommel-1941_(2).jpg) | Public domain (PD-US-alien property) | Unknown author | `f303333c71d550d6a1fe7fa292f3023be37ca11e` `[0.4246, 0.3546, 0.844, 0.65]` |
| Heinz Guderian | `guderian` | [Heinz Guderian portrait.jpg](https://commons.wikimedia.org/wiki/File:Heinz_Guderian_portrait.jpg) | Public domain (PD-Poland) | Unknown author | `15136c837418981a0de41cffd0acd1a56e472886` `[0.5101, 0.3365, 0.6958, 0.58]` |
| Erich von Manstein | `manstein` | [Bundesarchiv Bild 183-H01757, Erich von Manstein.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_183-H01757,_Erich_von_Manstein.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 183-H01757 / CC-BY-SA 3.0 | `ebf0871e5c291090c40dfc796887a88cf39645cc` `[0.5443, 0.4156, 0.9606, 0.8]` |
| Albert Kesselring | `kesselring` | [Albert Kesselring portrait.jpg](https://commons.wikimedia.org/wiki/File:Albert_Kesselring_portrait.jpg) | Public domain (PD-Poland) | Unknown author | `715e119c86d10063e737e8d4463719abcf137f79` `[0.4572, 0.4203, 0.8689, 0.62]` |
| Karl Dönitz | `donitz` | [Bundesarchiv Bild 146-1976-127-06A, Karl Dönitz (cropped)(3) (cropped).jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146-1976-127-06A,_Karl_D%C3%B6nitz_(cropped)(3)_(cropped).jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 146-1976-127-06A / CC-BY-SA 3.0 | `7091f0d89889c0592a15d62f71d38639dcb007e7` `[0.4936, 0.2977, 0.6578, 0.49]` |
| Erich Raeder | `raeder` | [Langhammer - Erich Raeder 1936.jpg](https://commons.wikimedia.org/wiki/File:Langhammer_-_Erich_Raeder_1936.jpg) | Public domain (PD-scan) | Franz Langhammer | `51d4c2f4d3a4b6545ed7f762f7a0c04a81672ba0` `[0.5795, 0.2812, 0.4584, 0.55]` |
| Otto Skorzeny | `skorzeny` | [Otto Skorzeny portait.jpg](https://commons.wikimedia.org/wiki/File:Otto_Skorzeny_portait.jpg) | Public domain (PD-Poland) | Unknown author | `8507ca991cf1c06b81942a2f5c56e89854789732` `[0.505, 0.365, 0.7364, 0.565]` |
| Isoroku Yamamoto | `yamamoto` | [Yamamoto-Isoroku.jpg](https://commons.wikimedia.org/wiki/File:Yamamoto-Isoroku.jpg) | Public domain (PD-Japan-oldphoto) | The Advance in Nippon 画報 躍進之日本 (Gaho Yakushin no Nihon) | `09b06c35f460ffe76c4cfcdfc51d09975ed847d5` `[0.4935, 0.4715, 1.0575]` |
| Chuichi Nagumo | `nagumo` | [Chuichi Nagumo.jpg](https://commons.wikimedia.org/wiki/File:Chuichi_Nagumo.jpg) | Public domain (PD-Japan-oldphoto) | Unknown author | `6166d1495baa9697246c19ad32d1c863f98b7a20` `[0.4632, 0.3143, 0.5505]` |
| Tomoyuki Yamashita | `yamashita` | [Yamashita Tomoyuki.jpg](https://commons.wikimedia.org/wiki/File:Yamashita_Tomoyuki.jpg) | Public domain (PD-Japan) | Unknown Japanese Army Photographer | `a378811c09b4bf8b1fc09eabb60ec762c343e732` `[0.525, 0.2574, 0.4623]` |
| Rodolfo Graziani | `graziani` | [Rodolfo Graziani 1940 (Retouched).jpg](https://commons.wikimedia.org/wiki/File:Rodolfo_Graziani_1940_(Retouched).jpg) | Public domain (PD-anon-70-EU) | Unknown author | `55463e98fce7352e592631cca9db65dc1065ff2f` `[0.4699, 0.2651, 0.611]` |
| Galeazzo Ciano | `ciano` | [Galeazzo Ciano 1936.jpg](https://commons.wikimedia.org/wiki/File:Galeazzo_Ciano_1936.jpg) | Public domain (PD-Italy) | Atelier Binder | `e8013b606fc4aa101c0f11e552d52afee7e68ec9` `[0.5387, 0.4001, 0.9354]` |
| Winston Churchill | `churchill` | [Sir Winston Churchill - 19086236948 (restored).jpg](https://commons.wikimedia.org/wiki/File:Sir_Winston_Churchill_-_19086236948_(restored).jpg) | Public domain (PD-Canada, PD-US-1996, cc-by-2.0) | Yousuf Karsh | `005c8e2c7b24a3bbd8d3c243e78cd17b16a0e50e` `[0.5069, 0.2627, 0.4069]` |
| Franklin D. Roosevelt | `roosevelt` | [FDR 1944 Color Portrait.jpg](https://commons.wikimedia.org/wiki/File:FDR_1944_Color_Portrait.jpg) | CC BY 2.0 (cc-by-2.0) | Leon Perskie | `c70fde92ee31c9bb02a5df1153e9c6581cec8ab2` `[0.4908, 0.3961, 0.6901]` |
| Joseph Stalin | `stalin` | [Joseph Stalin official portrait.jpg](https://commons.wikimedia.org/wiki/File:Joseph_Stalin_official_portrait.jpg) | Public domain (PD-Russia-1996, PD-in, Mil.ru) | Ivan Shagin | `bc66dc681a268c66c599e641246f90563c01c686` `[0.5209, 0.3821, 0.9066]` |
| Chiang Kai-shek | `chiang_kai_shek` | [Chiang Kai-shek（蔣中正）.jpg](https://commons.wikimedia.org/wiki/File:Chiang_Kai-shek%EF%BC%88%E8%94%A3%E4%B8%AD%E6%AD%A3%EF%BC%89.jpg) | Public domain (PD-China-1996) | Unknown author | `e13cbd09932ac957c3cee800f3920a22c3ee4707` `[0.4923, 0.1969, 0.3412]` |
| Charles de Gaulle | `de_gaulle` | [General Charles de Gaulle in 1945.jpg](https://commons.wikimedia.org/wiki/File:General_Charles_de_Gaulle_in_1945.jpg) | No restrictions (Flickr-no known copyright restrictions) | The National Archives UK | `3e317d8abedce04bc6f00bf75b3530f643d9c77c` `[0.5065, 0.2613, 0.5794]` |
| Dwight D. Eisenhower | `eisenhower` | [Dwight D. Eisenhower, official photo portrait, May 29, 1959.jpg](https://commons.wikimedia.org/wiki/File:Dwight_D._Eisenhower,_official_photo_portrait,_May_29,_1959.jpg) | Public domain (PD-USGov-POTUS) | White House | `3dbed688659ffdca6f538a8e8d94d7ef5b8a6b63` `[0.4907, 0.4229, 0.9376]` |
| Bernard Montgomery | `montgomery` | [General Sir Bernard Montgomery in England, 1943 TR1036.jpg](https://commons.wikimedia.org/wiki/File:General_Sir_Bernard_Montgomery_in_England,_1943_TR1036.jpg) | Public domain (PD-Scan) | Possibly Edward George William Malindine | `62beeb1385a7fad6d0859eaa8e4daf7f6be699b0` `[0.4335, 0.4015, 0.7805]` |
| George S. Patton | `patton` | [General George Patton by Robert F. Cranston, Lee Elkins, and Harry Warnecke, 1945, color carbro print, from the National Portrait Gallery - NPG-NPG 95 404Patton-000002.jpg](https://commons.wikimedia.org/wiki/File:General_George_Patton_by_Robert_F._Cranston,_Lee_Elkins,_and_Harry_Warnecke,_1945,_color_carbro_print,_from_the_National_Portrait_Gallery_-_NPG-NPG_95_404Patton-000002.jpg) | CC0 (cc-zero) | Robert F. Cranston / Harry Warnecke | `1ed64e91083a262dd06ee0abbc2144019e06ed62` `[0.4777, 0.3867, 0.7268]` |
| Georgy Zhukov | `zhukov` | [Zhukov-LIFE-1944-1945.jpg](https://commons.wikimedia.org/wiki/File:Zhukov-LIFE-1944-1945.jpg) | Public domain (PD-US-not renewed, PD-Russia) | Grigory Vayl | `7da11d378f8bb3f809d17a1f4f7ca98f7db39471` `[0.5055, 0.3473, 0.8264]` |
| Douglas MacArthur | `macarthur` | [MacArthur Manila (cropped2).jpg](https://commons.wikimedia.org/wiki/File:MacArthur_Manila_(cropped2).jpg) | Public domain (PD-USGov-Military-Army, PDreview) | Photographer not credited | `02eb6696613ea37df6209032d9eebb36e9fe11ec` `[0.5405, 0.2768, 0.5544]` |
| Chester Nimitz | `nimitz` | [Chester Nimitz-fleet-admiral.jpg](https://commons.wikimedia.org/wiki/File:Chester_Nimitz-fleet-admiral.jpg) | Public domain (PD-USGov-Military-Navy) | Official U.S. Navy Photograph now in the collections of the National Archive | `ac24d00cd1076132b8e534a90f48fe839250b102` `[0.4804, 0.5137, 1.1609]` |
| William Halsey | `halsey` | [W Halsey.jpg](https://commons.wikimedia.org/wiki/File:W_Halsey.jpg) | Public domain (PD-USGov-Military-Navy) | Official U.S. Navy photograph #80-G-K-15137, now in the National Archives collection | `c7e0b311ef2044e0fefda9737530a568ca355cb8` `[0.5224, 0.3343, 0.8323]` |
| Andrew Cunningham | `cunningham` | [Andrew Cunningham.jpg](https://commons.wikimedia.org/wiki/File:Andrew_Cunningham.jpg) | Public domain (PD-UKGov) | Unknown | `60492df00307a911d63cfeac9665d11878dbab39` `[0.442, 0.3465, 0.5268]` |
| Alan Brooke | `alanbrooke` | [Alan Brooke at desk 1942.jpg](https://commons.wikimedia.org/wiki/File:Alan_Brooke_at_desk_1942.jpg) | Public domain (PD-UKGov) | War Office official photographer | `54b5abfbe695365b252fca398955ea7e08fa6c57` `[0.565, 0.3632, 0.2904]` |
| Hugh Dowding | `dowding` | [Hugh Dowding.jpg](https://commons.wikimedia.org/wiki/File:Hugh_Dowding.jpg) | Public domain (PD-UKGov) | Ministry of Information official photographer | `66fdaf34ac9369ee9cc399b5fc8da309f852c436` `[0.377, 0.4003, 0.8057]` |
| Louis Mountbatten | `mountbatten` | [Admiral Lord Louis Mountbatten, 1943. TR1230 (cropped).jpg](https://commons.wikimedia.org/wiki/File:Admiral_Lord_Louis_Mountbatten,_1943._TR1230_(cropped).jpg) | Public domain (PD-Scan) | British official photographer | `cc21583341fc2724ac28962553fd85b4cea7314f` `[0.4873, 0.4123, 0.9358]` |
| William Slim | `slim` | [FM william Slim.jpg](https://commons.wikimedia.org/wiki/File:FM_william_Slim.jpg) | Public domain (PD-UKGov) | Ministry of Information Photo Division Photographer | `acf52785e0dc15fe1fa9c8f96795c13eaf049b40` `[0.4009, 0.3879, 0.5208]` |
| Omar Bradley | `bradley` | [Omar Bradley, official military photo, 1949.JPEG](https://commons.wikimedia.org/wiki/File:Omar_Bradley,_official_military_photo,_1949.JPEG) | Public domain (PD-USArmy) | United States Army | `5232dfa66d9b5e46abdad3093a3ebc1fd2412e66` `[0.4912, 0.2669, 0.5915]` |
| Ivan Konev | `konev` | [Ivan Stepanovich Konev.jpg](https://commons.wikimedia.org/wiki/File:Ivan_Stepanovich_Konev.jpg) | CC BY 4.0 (Mil.ru) | Mil.ru | `b1b75cadf189925617a02794ac1ce1380c77c995` `[0.4566, 0.2667, 0.5795]` |
| William Donovan | `donovan` | [William Joseph (Wild Bill) Donovan, Head of the OSS.jpg](https://commons.wikimedia.org/wiki/File:William_Joseph_(Wild_Bill)_Donovan,_Head_of_the_OSS.jpg) | Public domain (PD-USGov) | Not provided | `48072b14568162e00b7142fccdb251e32aab6121` `[0.4524, 0.2974, 0.5584]` |
| Alan Turing | `turing` | [Alan Turing (1951) (crop).jpg](https://commons.wikimedia.org/wiki/File:Alan_Turing_(1951)_(crop).jpg) | Public domain (PD-two, PD-in) | Elliott & Fry | `f0545ef42650f09a87b250e107fb82aeed8030a6` `[0.5371, 0.3967, 0.9922]` |
| J. Robert Oppenheimer | `oppenheimer` | [Oppenheimer (cropped).jpg](https://commons.wikimedia.org/wiki/File:Oppenheimer_(cropped).jpg) | Public domain (PD-USGov-DOE) | Unknown author | `c0d52b57c762739f4bcbe8c9f60d835cae54da67` `[0.45, 0.4069, 0.8835]` |
| Joseph Stilwell | `stilwell` | [Stilwell001.jpg](https://commons.wikimedia.org/wiki/File:Stilwell001.jpg) | Public domain (PD-USArmy) | Unknown author | `b2fd96aa3501618d6a59da9613191b440c360559` `[0.5054, 0.3801, 0.879]` |
| Philippe Leclerc | `leclerc` | [Liberation de paris - 26 aout 1944 - portrait du general jacques-philippe leclerc de hautecl 427563.jpg](https://commons.wikimedia.org/wiki/File:Liberation_de_paris_-_26_aout_1944_-_portrait_du_general_jacques-philippe_leclerc_de_hautecl_427563.jpg) | CC0 (cc-zero) | Unknown author, Agence LAPI (Les Actualités Photographiques Internationales) | `1f1ad6989ce187c32944af384b0955b322b42782` `[0.4326, 0.3604, 0.769]` |
| Walter Model | `model` | [Walther Model on the front.jpg](https://commons.wikimedia.org/wiki/File:Walther_Model_on_the_front.jpg) | Public domain (PD-Poland) | Unknown author | `a600a705daca7844c90480a70d3c88e7e32b9295` `[0.36, 0.4325, 0.495]` |
| Gerd von Rundstedt | `rundstedt` | [Bundesarchiv Bild 183-S37772, Gerd v. Rundstedt.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_183-S37772,_Gerd_v._Rundstedt.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 183-S37772 / CC-BY-SA 3.0 | `1a68bfe8ca012d7da369953b8fdb1caad3b947fa` `[0.4917, 0.469, 1.0547, 0.76]` |
| Kurt Student | `student` | [Wolfgang Willrich - General der Flieger Kurt Student, 1941.jpg](https://commons.wikimedia.org/wiki/File:Wolfgang_Willrich_-_General_der_Flieger_Kurt_Student,_1941.jpg) | Public domain (PD-Art) | Wolfgang Willrich | `6035c461ddd6559813f56da479921093fa81c9da` `[0.492, 0.4092, 0.7084, 0.64]` |
| Adolf Galland | `galland` | [Bundesarchiv Bild 146-2006-0123, Adolf Galland.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146-2006-0123,_Adolf_Galland.jpg) | CC BY-SA 3.0 de (cc-by-sa-3.0-de) | Bundesarchiv, Bild 146-2006-0123 / Hoffmann, Heinrich / CC-BY-SA 3.0 | `986eecadd3bd2f3cadc3a7fc778063393ddd26a6` `[0.5564, 0.3814, 0.886, 0.66]` |
| Günther Lütjens | `lutjens` | [Bundesarchiv Bild 146-2003-0027, Günter Lütjens.jpg](https://commons.wikimedia.org/wiki/File:Bundesarchiv_Bild_146-2003-0027,_G%C3%BCnter_L%C3%BCtjens.jpg) | CC BY-SA 3.0 de (Cc-by-sa-3.0-de) | Bundesarchiv, Bild 146-2003-0027 / CC-BY-SA 3.0 | `aa192b95eaf76910b1ed1f535985391923542bdb` `[0.5203, 0.2061, 0.3398, 0.295]` |
| Jisaburo Ozawa | `ozawa` | [Ozawa11.jpg](https://commons.wikimedia.org/wiki/File:Ozawa11.jpg) | Public domain (PD-Japan-oldphoto) | Unknown author | `c4a06db2f63a22374f7282952333363b7d02fc12` `[0.4735, 0.2855, 0.6629]` |
| Masaharu Homma | `homma` | [Portrait of General Masaharu Homma, 1943.jpg](https://commons.wikimedia.org/wiki/File:Portrait_of_General_Masaharu_Homma,_1943.jpg) | Public domain (PD-Japan-oldphoto) | 比島派遣軍 (Japanese army news agency) | `e88b8e6cb2b4172e72332d21a75a760b70f180e2` `[0.53, 0.3827, 0.8996]` |
| Italo Balbo | `balbo` | [Italio Balbo in the mountains (cropped).jpg](https://commons.wikimedia.org/wiki/File:Italio_Balbo_in_the_mountains_(cropped).jpg) | Public domain (PD-Poland) | Unknown author | `6b1e495357872c5634fe99acf5a93aa9b5afd2e7` `[0.4774, 0.3155, 0.7283]` |
| Giovanni Messe | `messe` | [Giovanni Messe.jpg](https://commons.wikimedia.org/wiki/File:Giovanni_Messe.jpg) | Public domain (PD-Italy, PD-retouched-user-w) | Official photograph of Kingdom of Italy with no credited author | `54c8d401369a6d475b53489a48967a51ba5b8d6d` `[0.5104, 0.3957, 0.9257]` |
| Saburo Kurusu | `kurusu` | [Saburo-Kurusu-in-Washington-7-Dec-1941.png](https://commons.wikimedia.org/wiki/File:Saburo-Kurusu-in-Washington-7-Dec-1941.png) | Public domain (PD-US, PD-USGov) | Office for Emergency Management. Office of War Information. Overseas Operations Branch. New York Office. News and Features Bureau. 12/17/1942-9/15/1945 | `d580fe6c7a0081825dfa60edb4e06a63fc172ea8` `[0.5395, 0.328, 0.7887]` |
| George C. Marshall | `marshall` | [General George C. Marshall (4616939916).jpg](https://commons.wikimedia.org/wiki/File:General_George_C._Marshall_(4616939916).jpg) | No restrictions (Flickr-no known copyright restrictions) | NASA on The Commons | `97c7c4c78a3279bba065a52e5dc92800763f5928` `[0.4828, 0.2973, 0.5283]` |
| Ernest King | `king` | [Admiral Ernest J. King, 80-G-K-13715 (26222680321) (cropped).jpg](https://commons.wikimedia.org/wiki/File:Admiral_Ernest_J._King,_80-G-K-13715_(26222680321)_(cropped).jpg) | Public domain (PD-USGov-Military-Navy) | National Museum of the U.S. Navy | `e5ca046c0558ab7dfcdbdb316e9632500f30a290` `[0.5193, 0.485, 0.9664]` |
| Henry H. Arnold | `arnold` | [Henry Harley Arnold.jpg](https://commons.wikimedia.org/wiki/File:Henry_Harley_Arnold.jpg) | Public domain (PD-USGov-Military) | Unknown author | `6b1f83d4c0250b4dbd490c3fe172e0db131ad99e` `[0.47, 0.3854, 0.9263]` |
| Arthur Harris | `harris` | [Air Chief Marshal Sir Arthur Harris.jpg](https://commons.wikimedia.org/wiki/File:Air_Chief_Marshal_Sir_Arthur_Harris.jpg) | Public domain (PD-UKGov) | Fg Off Stannus, Royal Air Force official photographer | `51e16af04761c88a99da522df73e013e2c084000` `[0.5263, 0.3659, 0.5959]` |
| Arthur Tedder | `tedder` | [Tedder1943 detail.jpg](https://commons.wikimedia.org/wiki/File:Tedder1943_detail.jpg) | Public domain (PD-UKGov) | British official photographer | `31eb94d264dd96cc4c0baa23e1d5910099b67021` `[0.5582, 0.3875, 0.8441]` |
| Archibald Wavell | `wavell` | [Archibald Wavell2.jpg](https://commons.wikimedia.org/wiki/File:Archibald_Wavell2.jpg) | Public domain (PD-UKGov) | Unknown | `811b5c77a5e3dd842b455e1765f7820cca487361` `[0.5772, 0.2424, 0.5361]` |
| Claude Auchinleck | `auchinleck` | [Auchinleck.jpg](https://commons.wikimedia.org/wiki/File:Auchinleck.jpg) | Public domain (PD-UKGov) | Palmer (Lt), No 1 Army Film & Photographic Unit | `deadd6410306f52e460cbb07fe472f337565c5c3` `[0.4664, 0.3032, 0.7231]` |
| Konstantin Rokossovsky | `rokossovsky` | [Маршал Советского Союза дважды Герой Советского Союза Константин Константинович Рокоссовский.jpg](https://commons.wikimedia.org/wiki/File:%D0%9C%D0%B0%D1%80%D1%88%D0%B0%D0%BB_%D0%A1%D0%BE%D0%B2%D0%B5%D1%82%D1%81%D0%BA%D0%BE%D0%B3%D0%BE_%D0%A1%D0%BE%D1%8E%D0%B7%D0%B0_%D0%B4%D0%B2%D0%B0%D0%B6%D0%B4%D1%8B_%D0%93%D0%B5%D1%80%D0%BE%D0%B9_%D0%A1%D0%BE%D0%B2%D0%B5%D1%82%D1%81%D0%BA%D0%BE%D0%B3%D0%BE_%D0%A1%D0%BE%D1%8E%D0%B7%D0%B0_%D0%9A%D0%BE%D0%BD%D1%81%D1%82%D0%B0%D0%BD%D1%82%D0%B8%D0%BD_%D0%9A%D0%BE%D0%BD%D1%81%D1%82%D0%B0%D0%BD%D1%82%D0%B8%D0%BD%D0%BE%D0%B2%D0%B8%D1%87_%D0%A0%D0%BE%D0%BA%D0%BE%D1%81%D1%81%D0%BE%D0%B2%D1%81%D0%BA%D0%B8%D0%B9.jpg) | CC BY 4.0 (Mil.ru) | Mil.ru | `822e2fc13b3e7177f3900121e7daa6a0b01eed4d` `[0.454, 0.241, 0.5716]` |
| Aleksandr Vasilevsky | `vasilevsky` | [Aleksandr Vasilevsky 4.jpg](https://commons.wikimedia.org/wiki/File:Aleksandr_Vasilevsky_4.jpg) | CC BY 4.0 (Mil.ru) | Mil.ru | `24edff5766a094e6fb3c38ae74bc628024dbc521` `[0.3433, 0.2397, 0.5863]` |
| Vasily Chuikov | `chuikov` | [Vasily Chuikov's photo from autograf.jpg](https://commons.wikimedia.org/wiki/File:Vasily_Chuikov%27s_photo_from_autograf.jpg) | CC BY 4.0 (mos.ru) | Mos.ru | `21018c590057610ccfb00652d2a36712cbd87808` `[0.342, 0.3522, 0.7493]` |
| Raymond Spruance | `spruance` | [Ray Spruance.jpg](https://commons.wikimedia.org/wiki/File:Ray_Spruance.jpg) | Public domain (PD-USGov-Military-Navy) | U.S. Navy | `5c76d22a36afaef09d888eb1a1571fa137dc3ac7` `[0.4452, 0.424, 1.0038]` |
| Mark Clark | `clark` | [General Mark Wayne Clark, Comandante do 5º Exército Norte Americano.tif](https://commons.wikimedia.org/wiki/File:General_Mark_Wayne_Clark,_Comandante_do_5%C2%BA_Ex%C3%A9rcito_Norte_Americano.tif) | Public domain (Arquivo Nacional PD-license) | Unknown | `f8bc55090360304524aca20288790d4fdf972237` `[0.52, 0.3624, 0.8639]` |
| Alphonse Juin | `juin` | [USA-MTO-NWA-p651 Alphonse Juin.jpg](https://commons.wikimedia.org/wiki/File:USA-MTO-NWA-p651_Alphonse_Juin.jpg) | Public domain (PD-USGov-Military-Army) | Unknown author | `ec5a3fddbb14c351fbbfa5b089e5415e46669d09` `[0.4757, 0.3905, 0.7978]` |
| Orde Wingate | `wingate` | [Ordecharleswingate.jpg](https://commons.wikimedia.org/wiki/File:Ordecharleswingate.jpg) | Public domain (PD-USGov-Military) | U.S. military photo | `8510fe35e726d570801994e65396ab8c6b545dae` `[0.5791, 0.339, 0.7978]` |
| Claire Chennault | `chennault` | [Claire L. Chennault.jpg](https://commons.wikimedia.org/wiki/File:Claire_L._Chennault.jpg) | Public domain (PD-USGov) | Unknown military photographer | `9db293aeab0a509771516bbb803fc9460896f042` `[0.5792, 0.3398, 0.764]` |
| Zhu De | `zhu_de` | [Zhu De (1922).jpg](https://commons.wikimedia.org/wiki/File:Zhu_De_(1922).jpg) | Public domain (PD-anon-70-EU, PD-US-expired) | Unknown | `85b734089efee369b8e0bc1210341b8bf21d68b1` `[0.4696, 0.4002, 0.9434]` |
| Stewart Menzies | `menzies` | [Keith and Stewart Menzies 1914.jpg](https://commons.wikimedia.org/wiki/File:Keith_and_Stewart_Menzies_1914.jpg) | Public domain (PD-old) | Unknown author | `e8fcb69289ce118dbc7b353442e9f3245247661d` `[0.6483, 0.1006, 0.2201]` |

## Notes

- **Hermann Göring**: Cut off above his collar (the Grand Cross of the Iron Cross at his neck, the eagles on his collar tabs) and faded out below like a studio print.
- **Heinrich Himmler**: Cut off at the top of his collar tabs, well above the swastika lower in the photograph, and faded out below.
- **Erwin Rommel**: Cut off above his collar, the Knight's Cross at his neck and the eagle on his breast, and faded out below.
- **Heinz Guderian**: Cut off above the Knight's Cross at his neck and the eagle on his breast, and faded out below; his collar's general's embroidery stays.
- **Albert Kesselring**: Cut off above his collar and the Knight's Cross at his neck, and faded out below and at the sides (the photograph is narrow).
- **Karl Dönitz**: Cut off above his collar, the Knight's Cross at his neck and the eagle on his breast, and faded out below.
- **Otto Skorzeny**: Cut off above his collar tabs (the SS runes) and the Knight's Cross at his neck, and faded out below.
- **Walter Model**: Cropped from below the cap eagle and the swastika in its talons (both above the top edge) to above the collar and its Knight's Cross: the oak wreath and cockade stay (TeeJ, 2026-09-30: the eagle may show, the swastika never).
- **Gerd von Rundstedt**: Cut off above the eagle on his breast and faded out below and at the sides.
- **Kurt Student**: Cut off above the collar insignia of the drawing and faded out below.
- **Adolf Galland**: Cut off above the Knight's Cross at his neck and faded out below and at the sides.
- **Günther Lütjens**: Cut off above the eagle on his breast and the Iron Cross, and faded out below.
- **Stewart Menzies**: Stewart Menzies is the man on the right, beside his brother Keith, in 1914 (TeeJ, 2026-09-30). The only freely licensed photograph of him: the 1953 portraits on Commons carry a licence their uploaders could not grant. Small (497x800, from a book), so his picture is soft.
