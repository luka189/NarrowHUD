-- NarrowHUD blast radii, made by tools/make_blast.py from HD2Runtime's game-data catalogues
-- (https://github.com/SkyeShade/HD2Runtime, SkyeShade): { inner, outer } in metres, the full-damage radius and
-- the outer one. Weapons by network type, grenades by the thrown unit's kind.
return {
  weapons = {
    ['7bfb2e06'] = { 2, 4 },   -- AC-8 Autocannon
    ['eb38d34e'] = { 3.0, 6.0 },   -- CB-9 Exploding Crossbow
    ['17db8107'] = { 3.5, 7.5 },   -- E/GL-21 Grenadier Battlement (the GL-21's round)
    ['6ec2a850'] = { 1.5, 3 },   -- EAT-17 Expendable Anti-Tank
    ['c0ff5282'] = { 10, 25 },   -- EAT-411 Leveller
    ['d724a2f9'] = { 1.6, 8 },   -- EAT-700 Expendable Napalm
    ['83d1036e'] = { 1.5, 3 },   -- FAF-14 Spear
    ['17b02218'] = { 2.25, 5.5 },   -- GL-15 Evictor
    ['8c0aee6e'] = { 3.5, 7.5 },   -- GL-21 Grenade Launcher
    ['6b47e064'] = { 2, 4 },   -- GL-28 Belt-Fed Grenade Launcher
    ['e1f10066'] = { 1, 3 },   -- GL-52 De-Escalator
    ['36fcbd00'] = { 2.0, 12.0 },   -- GP-20 Ultimatum
    ['362577f7'] = { 2.25, 6.5 },   -- GP-31 Grenade Pistol
    ['b2bfd847'] = { 1.5, 3 },   -- GR-8 Recoilless Rifle
    ['366d3622'] = { 1.5, 3 },   -- LAS-99 Quasar Cannon
    ['3d538455'] = { 1, 2 },   -- MLS-4X Commando
    ['16425925'] = { 3.5, 7.5 },   -- One-Two 40MM HE (underbarrel) (the GL-21's round)
    ['a41ddfcd'] = { 1.0, 2.0 },   -- PLAS-1 Scorcher
    ['ba161726'] = { 2.9, 3.0 },   -- PLAS-101 Purifier
    ['314a1bf5'] = { 2.3, 3 },   -- PLAS-45 Epoch
    ['15ae0889'] = { 4.0, 7.0 },   -- R-36 Eruptor
    ['8a3c6fee'] = { 3, 5 },   -- RL-77 Airburst Rocket Launcher
    ['2df95dfe'] = { 2, 5 },   -- S-11 Speargun
    ['303d2220'] = { 2.3, 3.0 },   -- SG-8P Punisher Plasma
  },
  grenades = {
    ['9b75217d8312dd67'] = { 3, 7 },   -- B-1 C4 charge (its backpack's)
    ['04653ab33f3ffb44'] = { 1, 7 },   -- G-10 Incendiary (detonation)
    ['6b11fc757618c57e'] = { 2.5, 7 },   -- G-12 High Explosive (detonation)
    ['c5c05fcb5747c799'] = { 1.5, 2.5 },   -- G-123 Thermite (detonation)
    ['eb725c39fc38b87c'] = { 1, 7 },   -- G-13 Incendiary Impact (detonation)
    ['7686544f539bb9b7'] = { 2.5, 7 },   -- G-16 Impact (detonation)
    ['0080869506299773'] = { 1, 10 },   -- G-23 Stun (detonation)
    ['5de8fd02a05b4b0a'] = { 8, 8 },   -- G-3 Smoke (detonation)
    ['db922a7afc42894b'] = { 1, 10 },   -- G-31 Arc (detonation)
    ['0416984f4922757b'] = { 2, 7 },   -- G-4 Gas (detonation)
    ['46333fc9e3d4bd34'] = { 2, 12 },   -- G-48 Giga Grenade (detonation)
    ['4ce9eab785a79b7b'] = { 4, 10 },   -- G-6 Frag (detonation)
    ['075b19b068fb1045'] = { 4, 10 },   -- G-7 Pineapple (detonation)
    ['5c14f27759dd3be0'] = { 4, 10 },   -- G-8 Immolation (detonation)
    ['dab81b0d80b511c7'] = { 5, 5 },   -- G-89 Smokescreen (detonation)
    ['ee4c107b941ab7f4'] = { 2.5, 6 },   -- G/40-K Melta Mine (detonation)
    ['1b9ac59697006337'] = { 0.4, 4 },   -- G/SH-39 Shield (detonation)
    ['14368dc8784220b0'] = { 6, 12 },   -- TED-63 Dynamite (detonation)
    ['a20683199dfc19e8'] = { 2, 8 },   -- TM-1 Lure Mine (detonation)
  },
}
