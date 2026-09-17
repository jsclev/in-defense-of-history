INSERT INTO sim_tower_sweep (profile, tuning) VALUES
('coarse', '{
  "upgradeGrowth": [1.3, 1.5, 1.7, 1.9, 2.1],
  "rof": {
    "ranged": [0.5, 0.65, 0.8, 1.0, 1.2],
    "special": [0.8, 1.0, 1.2, 1.5, 1.8],
    "areaOfEffect": [1.6, 2.0, 2.4, 2.8, 3.2],
    "melee": [0]
  },
  "splash": {"ranged": [0], "melee": [0], "special": [0], "areaOfEffect": [70, 85, 100, 115, 130]},
  "falloff": [0.5, 1.0, 3.0],
  "projectileSpeed": {
    "ranged": [300, 425, 550, 800, 1100],
    "areaOfEffect": [80, 160, 320, 640, 1280],
    "special": [275, 550, 1100],
    "melee": [0]
  },
  "rangeModes": {"ranged": "sweep", "melee": "authored", "special": "authored", "areaOfEffect": "authored"}
}'),
('fine', '{
  "upgradeGrowth": [1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2],
  "rof": {
    "ranged": [0.5, 0.55, 0.6, 0.65, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 1.05, 1.1, 1.15, 1.2],
    "special": [0.8, 0.9, 1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8],
    "areaOfEffect": [1.6, 1.7, 1.8, 1.9, 2.0, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 3.0, 3.1, 3.2],
    "melee": [0]
  },
  "splash": {"ranged": [0], "melee": [0], "special": [0], "areaOfEffect": [70, 75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130]},
  "falloff": [0.5, 0.75, 1.0, 1.5, 2.0, 3.0],
  "projectileSpeed": {
    "ranged": [300, 425, 550, 800, 1100],
    "areaOfEffect": [80, 160, 320, 640, 1280],
    "special": [275, 550, 1100],
    "melee": [0]
  },
  "rangeModes": {"ranged": "sweep", "melee": "authored", "special": "authored", "areaOfEffect": "authored"}
}');
