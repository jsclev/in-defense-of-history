#!/usr/bin/env python3
"""Author Charleston's 15-wave finale in SQL, GeoJSON, and the saved editor map.

Routes 0/2/4 use entrance 0; routes 1/3/5 use entrance 1.
The lower and central roads end at the bottom, the upper roads at the right.
First run GenerateCharlestonRoutes with the current native map to produce a fresh
GeoJSON base and replacement routes, then pass both outputs to this script.
The generated LineStrings are the source for SQL; marker positions are preserved.
"""
import json
import re
import uuid
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LEVEL_ID = "4ca73a47-98f6-41b6-815d-c2c797aa746e"
WAVE_IDS = [
    "dad762fe-2a0e-5af8-a3b7-b4433af68529", "e24ab7b2-c906-5197-b112-6d18fe86c7cc",
    "f1318874-c56f-5dc4-ab5d-ff1e7e7aaa26", "7da7dc20-112d-5f29-a20e-d53f83c39cac",
    "e59219fa-41d6-55cd-b143-5219f63be76d", "e1839bfb-a905-552c-bfc0-134f838670b8",
    "b2b862ee-73e0-50ff-9fe7-5b7572135dae", "0adc19d8-340e-5fd0-81f5-8d7794f8894e",
    "777bb7b3-74d6-5b3a-a8e6-2aae1b403536", "200052e1-23ef-5286-9a31-7fb9fa1776e1",
    "806e941e-a051-583e-a083-d8fbb41f7165", "cc7eb305-4635-5747-9d7c-b751d2b2739f",
    "68778987-a236-5178-9098-99c4debc27f1", "8ff0e90c-4e07-5b61-940b-bff2b1037989",
    "0f43d15d-27d1-500c-94cd-8bf4c9c148c6",
]
M, R, L, J, F = "loyalist_militia", "redcoat_regular", "light_infantry", "hessian_jager", "hessian_fusilier"
N, H, D, S = "native_warrior", "highlander", "light_dragoon", "spy"
G, A, O, B, T = "grenadier", "royal_artillery", "mounted_officer", "foot_guards", "regimental_drummer"

# Each group is (enemy, count, route, seconds after wave start, individual interval).
# Introduce one alternate road at a time before combining all six in the finale.
# The shortest northern routes start lightly; slow siege units use longer roads.
PLAN = [
    ("Entrance 0: lower road", [(M,10,0,0,1.0), (R,6,0,7,1.3)]),
    ("Entrance 1: upper road", [(M,8,1,0,.95), (R,6,1,5,1.25), (L,4,0,10,.85)]),
    ("Both entrances", [(R,8,0,0,1.0), (F,6,1,3,1.2), (N,7,0,10,.8)]),
    ("Entrance 0: upper road", [(L,8,2,0,.8), (J,6,0,5,1.0), (R,8,1,8,.95), (T,1,2,2,1)]),
    ("Entrance 1: central road", [(M,8,3,0,.9), (F,8,0,2,1.0), (H,6,1,9,1.2), (T,1,0,3,1), (T,1,3,4,1)]),
    ("Entrance 0: central road", [(F,10,4,0,.9), (N,8,2,5,.8), (L,6,3,9,.85), (S,3,0,12,1.5)]),
    ("Entrance 1: right road", [(D,6,5,0,1.25), (R,10,2,1,.9), (J,6,3,9,1.0), (T,2,2,3,3)]),
    ("Three-road assault", [(H,10,4,0,1.1), (F,8,3,2,1.0), (N,8,5,10,.75), (T,1,4,2,1), (T,1,3,4,1)]),
    ("Infantry and cavalry", [(G,6,0,0,1.5), (L,8,2,3,.8), (D,6,5,10,1.0), (S,4,3,12,1.3)]),
    ("Officers at both entrances", [(O,1,4,0,1), (O,1,5,0,1), (G,8,4,2,1.4), (F,10,5,3,.9), (N,8,2,13,.7), (T,1,4,5,1), (T,1,5,5,1)]),
    ("Artillery on the long roads", [(A,3,4,0,3.5), (H,8,0,4,1.1), (R,10,5,1,.8), (D,6,1,13,1.0)]),
    ("Guards at both exits", [(B,4,0,0,2.2), (G,8,1,2,1.3), (L,10,4,8,.8), (N,8,3,12,.75), (T,1,0,3,1), (T,1,1,5,1)]),
    ("Fast flanking attack", [(B,4,5,0,2.1), (G,8,4,1,1.3), (D,10,2,9,.9), (F,8,3,10,.9), (S,2,0,17,1.3), (S,2,1,17,1.3)]),
    ("All roads under attack", [(B,3,0,0,2.1), (B,3,1,0,2.1), (O,2,4,4,2.2), (O,2,5,4,2.2), (H,5,4,9,1.0), (H,5,5,9,1.0), (F,5,2,13,.8), (F,5,3,13,.8), (D,6,1,18,.9)]),
    ("Final assault", [(B,4,0,0,2.2), (B,4,1,0,2.2), (A,2,4,4,3.5), (A,2,5,4,3.5), (T,1,0,6,1), (T,1,1,6,1), (G,6,2,9,1.0), (G,6,3,9,1.0), (F,6,4,13,.7), (F,6,5,13,.7), (O,1,4,13,1), (O,1,5,13,1), (D,5,2,20,.7), (D,5,3,20,.7)]),
]
# Nominal starts relative to the player's first call. Early calls shift the
# remaining schedule relative to that wave's actual start, as WaveStartSchedule requires.
STARTS = [0,32,66,100,135,171,208,246,285,325,366,408,451,495,540]


def wave_models():
    result = []
    previous_spawn_end = 0
    for i, (_, groups) in enumerate(PLAN):
        gap = 0 if i == 0 else STARTS[i] - STARTS[i - 1]
        countdown = 0 if i == 0 else 13
        # The editor's legacy breather starts after the previous wave's final
        # spawn; interactive timing starts at the previous wave's first spawn.
        breather = round(STARTS[i] - previous_spawn_end, 6)
        assert breather >= 0
        result.append(dict(
            breather=breather, callButtonDelay=gap-countdown,
            autoStartCountdown=countdown, earlyCallBonus=countdown,
            lines=[dict(foe=enemy, count=count, pathIndex=route, delay=delay, every=interval)
                   for enemy, count, route, delay, interval in sorted(groups, key=lambda g: g[3])]))
        previous_spawn_end = STARTS[i] + max(delay + (count - 1) * interval
                                           for _, count, _, delay, interval in groups)
    return result


def replace_waves(path, waves, native=False):
    # Preserve the user's geometry, markers, embedded artwork, and formatting.
    text = path.read_text()
    match = re.search(r'"waves"\s*:\s*', text)
    assert match, f"No waves array in {path}"
    _, length = json.JSONDecoder().raw_decode(text[match.end():])
    indent = "    " if native else "  "
    block = json.dumps(waves, ensure_ascii=False, indent=2)
    block = block.replace("\n", "\n" + indent)
    path.write_text(text[:match.end()] + block + text[match.end()+length:])


def write_routes(geo, native, routes):
    source = json.loads(geo.read_text())
    source['features'] = [f for f in source['features'] if f['properties']['kind'] != 'enemy_route']
    for route in routes:
        fid = f"gameplay.enemy_route.{route['index']}"
        points = [[p['x'], p['y']] for p in route['points']]
        source['features'].append(dict(type='Feature', id=fid,
            geometry=dict(type='LineString', coordinates=points),
            properties=dict(category='gameplay', id=fid, name=route['name'], kind='enemy_route',
                pathIndex=route['index'], entranceID=route['entranceID'], exitID=route['exitID'],
                layer=45, playable=True, insidePlayArea=all(474 <= x <= 2394 and 492 <= y <= 1572 for x,y in points))))
    for feature in source['features']:
        if feature['properties']['kind'] == 'call_wave_button':
            entrance = min((f for f in source['features'] if f['properties']['kind']=='spawn_point'),
                           key=lambda f: sum((a-b)**2 for a,b in zip(f['geometry']['coordinates'],feature['geometry']['coordinates'])))
            feature['properties']['pathIndices'] = [r['index'] for r in routes if r['entranceID'] == entrance['id']]
    geo.write_text(json.dumps(source, ensure_ascii=False, indent=2) + '\n')
    # Patch only small metadata fields in the native file; embedded art and road
    # editing data are preserved byte for byte.
    text = native.read_text()
    route_text = json.dumps(routes, ensure_ascii=False, indent=2)
    match = re.search(r'"enemyRoutes"\s*:\s*', text)
    if match:
        _, size = json.JSONDecoder().raw_decode(text[match.end():])
        text = text[:match.end()] + route_text + text[match.end()+size:]
    else:
        match = re.search(r'"draft"\s*:\s*\{', text)
        text = text[:match.end()] + '\n    "enemyRoutes": ' + route_text + ',' + text[match.end():]
    buttons = [dict(x=f['geometry']['coordinates'][0], y=f['geometry']['coordinates'][1],
                    pathIndices=f['properties']['pathIndices']) for f in source['features'] if f['properties']['kind']=='call_wave_button']
    match = re.search(r'"callWaveButtons"\s*:\s*', text)
    _, size = json.JSONDecoder().raw_decode(text[match.end():])
    text = text[:match.end()] + json.dumps(buttons, indent=2) + text[match.end()+size:]
    native.write_text(text)
    rows = []
    for route in routes:
        for i, point in enumerate(route['points']):
            uid = uuid.uuid5(uuid.UUID(LEVEL_ID), f"geojson-route-{route['index']}-point-{i}")
            rows.append(f"('{uid}', '{LEVEL_ID}', {route['index']}, {i}, {point['x']!r}, {point['y']!r})")
    path = ROOT / 'Db/DML/Levels/level_15_charleston.sql'
    previous = path.read_text()
    prefix = previous[:previous.index('-- Authored routes:')]
    path.write_text(prefix + '-- Authored routes: generated from enemy_route LineStrings in level_15_charleston.geojson.\n'
                   + '-- Regenerate with Tools/generate_charleston_waves.py; do not maintain a second geometry here.\n'
                   + 'INSERT INTO level_path_point (id, level_info_id, path_index, point_index, map_position_x, map_position_y) VALUES\n'
                   + ',\n'.join(rows) + ';\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--routes', type=Path, required=True, help='Replacement routes from GenerateCharlestonRoutes')
    parser.add_argument('--geojson-base', type=Path, required=True, help='Fresh export from the same generator run')
    args = parser.parse_args()
    geo = ROOT / "Db/level_15_charleston.geojson"
    native = ROOT / "Db/level_15_charleston.tdmap"
    routes = json.loads(args.routes.read_text())
    base = json.loads(args.geojson_base.read_text())
    assert len(routes) == 6 and [r['index'] for r in routes] == list(range(6))
    draft = json.loads(native.read_text())['draft']
    for kind, points in [('spawn_point', draft['entrances']), ('goal_point', draft['exits'])]:
        exported = [f['geometry']['coordinates'] for f in base['features'] if f['properties']['kind'] == kind]
        assert exported == [[p['x'], p['y']] for p in points], 'Regenerate from the latest native map'
    geo.write_text(json.dumps(base, ensure_ascii=False, indent=2) + '\n')
    write_routes(geo, native, routes)
    waves = wave_models()
    assert len(waves) == len(WAVE_IDS) == 15
    geo = ROOT / "Db/level_15_charleston.geojson"
    source = json.loads(geo.read_text())
    assert sum(f['properties']['kind'] == 'spawn_point' for f in source['features']) == 2
    assert sum(f['properties']['kind'] == 'goal_point' for f in source['features']) == 2
    wave_rows, spawn_rows = [], []
    for i, wave in enumerate(waves):
        wid = WAVE_IDS[i]
        wave_rows.append(f"('{wid}', '{LEVEL_ID}', {i+1}, {STARTS[i]}, {wave['callButtonDelay']}, {wave['autoStartCountdown']}, {wave['earlyCallBonus']})")
        previous_delay = 0
        for index, line in enumerate(wave['lines']):
            enemy = line['foe'].replace("'", "''")
            sid = uuid.uuid5(uuid.UUID(LEVEL_ID), f"two-entrance-wave-{i+1}-spawn-{index}")
            gap = line['delay'] - previous_delay
            assert gap >= 0 and line['pathIndex'] in range(len(routes))
            spawn_rows.append(f"('{sid}', '{wid}', (SELECT id FROM enemy_type WHERE enemy_type_key = '{enemy}'), {index}, {line['count']}, {gap}, {line['every']}, {line['pathIndex']})")
            previous_delay = line['delay']
    sql = """-- Generated by Tools/generate_charleston_waves.py: Charleston's two-entrance, six-route finale.
-- Routes: 0 entrance 0/lower -> exit 1; 1 entrance 1/upper -> exit 0;
-- 2 entrance 0/upper -> exit 0; 3 entrance 1/central -> exit 1;
-- 4 entrance 0/central -> exit 0; 5 entrance 1/right -> exit 1.
-- Fifteen waves; first call is manual.
-- spawn_time is the nominal no-early-call schedule relative to wave 1.
-- Delay + countdown runs from the previous wave's actual start; early-call reward = 13.
-- Keep existing wave IDs because hero unlocks reference them.
"""
    sql += f"DELETE FROM level_wave_enemy_spawn WHERE level_wave_id IN (SELECT id FROM level_wave WHERE level_info_id = '{LEVEL_ID}');\n\n"
    sql += "INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time, call_button_delay, auto_start_countdown, early_call_bonus) VALUES\n"
    sql += ",\n".join(wave_rows) + "\nON CONFLICT(id) DO UPDATE SET spawn_time=excluded.spawn_time, call_button_delay=excluded.call_button_delay, auto_start_countdown=excluded.auto_start_countdown, early_call_bonus=excluded.early_call_bonus;\n\n"
    sql += f"DELETE FROM level_wave WHERE level_info_id = '{LEVEL_ID}' AND wave_index > 15;\n"
    sql += f"UPDATE level_info SET num_waves = 15 WHERE id = '{LEVEL_ID}';\n\n"
    sql += "INSERT INTO level_wave_enemy_spawn (id, level_wave_id, enemy_type_id, spawn_index, num_enemies, spawn_time_since_previous_spawn, spawn_interval, path_index) VALUES\n"
    sql += ",\n".join(spawn_rows) + ";\n"
    (ROOT / "Db/DML/level_15_charleston_waves.sql").write_text(sql)
    replace_waves(geo, waves)
    native = ROOT / "Db/level_15_charleston.tdmap"
    if native.exists():
        native_waves = json.loads(json.dumps(waves))
        for wave in native_waves:
            for line in wave['lines']:
                line['road'] = line.pop('pathIndex')
        replace_waves(native, native_waves, native=True)
    print(f"Authored {len(routes)} GeoJSON/SQL routes, 15 waves, {sum(sum(l['count'] for l in w['lines']) for w in waves)} enemies; final wave at 9:00.")


if __name__ == "__main__":
    main()
