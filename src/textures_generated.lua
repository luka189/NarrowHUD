-- NarrowHUD icon textures, made by tools/make_textures.py from art/icons/*.svg: each icon in a ladder of sizes
-- (size, the icon's height in it, the resource id, its width), smallest first, for chef.texture_sizes and chef.bitmap,
-- and once in the game's icon layout. The stim and the reticle are luka189's; the grenade was traced by dogo314 (used with permission).
return {
  grenade = { { 64, 56, 'ebf6c256d2ff13ca', 38 }, { 128, 112, 'bee9f3d5af5d952b', 75 }, { 256, 224, '6608f6235da63257', 149 } },   -- (square textures, the icon centred: 149 wide, 224 high in the largest)
  grenade_game = { { 256, 224, '4c6c95419a57eff1', 149 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 149 wide, 224 high, centred)
  reticle = { { 64, 56, '4d16a7367325e5c2', 56 }, { 128, 112, '45f732810dd22885', 112 }, { 256, 224, 'd4c0f1ca124a1d9e', 224 } },   -- (square textures, the icon centred: 224 wide, 224 high in the largest)
  reticle_game = { { 256, 224, 'c6ba7791c2215270', 224 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 224 wide, 224 high, centred)
  stim = { { 64, 56, '1f09d2d7afc81813', 21 }, { 128, 112, '53381764199b5679', 41 }, { 256, 224, '82a779fcc996305f', 82 } },   -- (square textures, the icon centred: 82 wide, 224 high in the largest)
  stim_game = { { 256, 224, '241e0d9906daae59', 82 } },   -- (the game's icon layout: BC3, 9 mip levels; the icon 82 wide, 224 high, centred)
}
