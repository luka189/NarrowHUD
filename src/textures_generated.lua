-- NarrowHUD icon textures, made by tools/make_textures.py from art/icons/*.svg: each icon in a ladder of sizes
-- (size, the icon's height in it, the resource id, its width), smallest first, for chef.texture_sizes and chef.bitmap,
-- and once in the game's icon layout. The stim, the reticle and the all-barrels icon are luka189's; the grenade was traced by dogo314 (used with permission).
return {
  all_barrels = { { 64, 64, 'b626867874426b97', 64 }, { 128, 128, 'f02b209ebf7c832f', 128 }, { 256, 256, '5a3a38f0c37a1ed7', 256 } },   -- (square textures, the icon centred: 256 wide, 256 high in the largest)
  all_barrels_game = { { 256, 256, 'e9c523d5e2d76f0d', 256 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 256 wide, 256 high, centred)
  chevron = { { 64, 56, '722157b5c014602a', 55 }, { 128, 112, 'fbf49945fead6c93', 110 }, { 256, 224, 'a552ad10e16e80cf', 221 } },   -- (square textures, the icon centred: 221 wide, 224 high in the largest)
  chevron_game = { { 256, 224, 'fcdd3841020eed35', 221 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 221 wide, 224 high, centred)
  grenade = { { 64, 56, 'ebf6c256d2ff13ca', 38 }, { 128, 112, 'bee9f3d5af5d952b', 75 }, { 256, 224, '6608f6235da63257', 149 } },   -- (square textures, the icon centred: 149 wide, 224 high in the largest)
  grenade_game = { { 256, 224, '4c6c95419a57eff1', 149 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 149 wide, 224 high, centred)
  reticle = { { 64, 56, '4d16a7367325e5c2', 56 }, { 128, 112, '45f732810dd22885', 112 }, { 256, 224, 'd4c0f1ca124a1d9e', 224 } },   -- (square textures, the icon centred: 224 wide, 224 high in the largest)
  reticle_game = { { 256, 224, 'c6ba7791c2215270', 224 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 224 wide, 224 high, centred)
  stim = { { 64, 56, '1f09d2d7afc81813', 21 }, { 128, 112, '53381764199b5679', 41 }, { 256, 224, '82a779fcc996305f', 82 } },   -- (square textures, the icon centred: 82 wide, 224 high in the largest)
  stim_game = { { 256, 224, '241e0d9906daae59', 82 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 82 wide, 224 high, centred)
  decal_zone_cream_game = { { 512, 512, 'adb0308634640429', 512 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  decal_zone_red_game = { { 512, 512, '89d797b8c28caae4', 512 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  decal_ring_cream_game = { { 512, 512, 'e00b42453d994af9', 512 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  decal_ring_red_game = { { 512, 512, 'c5bf27f40829000d', 512 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  decal_pin_cream_game = { { 256, 256, '5e71cb0818cee761', 256 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  decal_pin_red_game = { { 256, 256, 'f380ca34d8d02448', 256 } },   -- (a ground picture, tools/decal_art.py: BC3, every mip level)
  hatch_game = { { 512, 512, '9d1ae52177072a62', 512, { { 8, 0, 64 }, { 10, 64, 64 }, { 12, 128, 64 }, { 14, 192, 64 }, { 16, 256, 64 }, { 20, 320, 64 }, { 24, 384, 64 }, { 32, 448, 64 } } } },   -- (the hatched shade's stripes: BC3, every mip level; bands of { period, first row, rows }, the stripes along u + v)
}
