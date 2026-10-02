#!/usr/bin/env python3
"""Offline GA JSON -> relational conversion. Source is always opened read-only.

DDL comes exclusively from Db/DDL/*.sql. The converter writes a new database,
checks every candidate/evaluation round trip, and never replaces the source.
"""
import argparse
import json
import math
import itertools
import pathlib
import sqlite3
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
STRATEGY_CHILDREN = ('ga_decision', 'ga_meta_upgrade', 'ga_early_wave', 'ga_tactical_order')
EVALUATION_CHILDREN = ('ga_enemy_fate', 'ga_wave_progress', 'ga_wave_leak', 'ga_wave_economy',
                       'ga_reinforcement_deployment', 'ga_wave_call', 'ga_built_tower', 'ga_tactical_action')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def canonical(value):
    """Only dictionary iteration order is immaterial; arrays and numbers are exact."""
    if isinstance(value, dict):
        return {key: canonical(item) for key, item in value.items()}
    if isinstance(value, list):
        return [canonical(item) for item in value]
    return value


def normalized_candidate(candidate):
    result = json.loads(json.dumps(candidate))
    for evaluation in result['evaluations']:
        fates = evaluation['result']['fatesByTypeID']
        if isinstance(fates, list):
            require(len(fates) % 2 == 0, 'Odd fatesByTypeID array')
            require(len(set(fates[::2])) == len(fates) // 2, 'Duplicate enemy type')
            evaluation['result']['fatesByTypeID'] = dict(zip(fates[::2], fates[1::2]))
    return result


class Store:
    def __init__(self, connection):
        self.db = connection
        self.db.row_factory = sqlite3.Row

    def insert(self, table, **values):
        return self.db.execute(f"INSERT INTO {table}({','.join(values)}) VALUES({','.join('?' for _ in values)})", tuple(values.values())).lastrowid

    def rows(self, table, where, args=(), order=''):
        return [dict(row) for row in self.db.execute(f'SELECT * FROM {table} WHERE {where}' + (f' ORDER BY {order}' if order else ''), args)]

    def one(self, table, where, args):
        rows = self.rows(table, where, args)
        require(len(rows) == 1, f'{table}: expected exactly one {where}: {args}')
        return rows[0]

    def run(self, solution):
        c, run = solution['context'], solution['runID']
        values = dict(run_id=run, format_version=solution['formatVersion'], executable_sha256=solution['executableSHA256'],
                      level_info_id=c['levelID'].lower(), difficulty_id=c['difficultyID'].lower(), starting_money=c['startingMoney'],
                      bounty_fraction=c['bountyFraction'], max_game_seconds=c['maxGameSeconds'], content_sha256=c['contentSHA256'],
                      heroes_enabled=solution['heroesEnabled'])
        old = self.rows('ga_run', 'run_id=?', (run,))
        if old:
            require(old[0] == values, f'{run}: inconsistent original context')
            return
        self.insert('ga_run', **values)
        if solution['heroesEnabled']:
            heroes = c['heroLoadout']
            for i, hero in enumerate(heroes['selectedHeroIDs']):
                matches = [(n, d) for n, d in enumerate(heroes['deployments']) if d['heroID'] == hero]
                require(len(matches) <= 1, f'{run}: duplicate hero deployment')
                ordinal, deployment = matches[0] if matches else (None, {})
                point = deployment.get('position', {})
                self.insert('ga_hero', run_id=run, ordinal=i, hero_id=hero, deployment_ordinal=ordinal,
                            role=deployment.get('role'), spawn_feature_id=deployment.get('spawnFeatureID'),
                            x=point.get('x'), y=point.get('y'), ai_enabled=deployment.get('aiEnabled'))

    def strategy(self, run, strategy):
        reinforcement = strategy['reinforcements']
        require(len(reinforcement['priority']) == 1, 'Invalid reinforcement priority')
        priority, data = next(iter(reinforcement['priority'].items()))
        point = data.get('_0', {})
        decisions, upgrades, waves = strategy['decisions'], strategy['metaUpgrades'], strategy['earlyWaves']['decisions']
        sid = self.insert('ga_strategy', run_id=run, reinforcement_priority=priority,
                          reinforcement_x=point.get('x'), reinforcement_y=point.get('y'),
                          reinforcement_hold_seconds=reinforcement['holdSeconds'], decision_count=len(decisions),
                          meta_upgrade_count=len(upgrades), early_wave_count=len(waves), tactical_count=len(strategy['tactics']) if 'tactics' in strategy else None)
        for i, order in enumerate(strategy.get('tactics', [])):
            self.insert('ga_tactical_order', strategy_id=sid, ordinal=i, slot=order['slot'], kind=order['kind'], path_index=order['pathIndex'], progress=order['progress'])
        for i, d in enumerate(decisions):
            require(len(d['step']['action']) == 1, 'Invalid build action')
            action, data = next(iter(d['step']['action'].items()))
            self.insert('ga_decision', strategy_id=sid, ordinal=i, seconds=d['step']['time'], earliest_wave=d['earliestWave'],
                        save_for_purchase=d['saveForPurchase'], action=action, slot=data['slot'],
                        tower_id=data.get('towerID'), upgrade_path_id=data.get('pathID'))
        for i, upgrade in enumerate(upgrades):
            self.insert('ga_meta_upgrade', strategy_id=sid, ordinal=i, upgrade_id=upgrade)
        for i, d in enumerate(waves):
            require(len(d['policy']) == 1, 'Invalid early wave policy')
            policy, data = next(iter(d['policy'].items()))
            self.insert('ga_early_wave', strategy_id=sid, ordinal=i, wave=d['wave'], policy=policy,
                        seconds=data.get('holdSeconds') if policy == 'whenEnemiesAtMost' else data.get('seconds') if policy == 'afterVisible' else None,
                        countdown_seconds=data.get('seconds') if policy == 'whenCountdownAtMost' else None, enemy_count=data.get('count'))
        return sid

    def read_strategy(self, sid):
        r = self.one('ga_strategy', 'strategy_id=?', (sid,))
        reinforcement = {'holdSeconds': r['reinforcement_hold_seconds'], 'priority': {r['reinforcement_priority']: {}}}
        if r['reinforcement_priority'] == 'nearPoint':
            reinforcement['priority']['nearPoint'] = {'_0': {'x': r['reinforcement_x'], 'y': r['reinforcement_y']}}
        decisions = []
        for d in self.rows('ga_decision', 'strategy_id=?', (sid,), 'ordinal'):
            action = {'slot': d['slot']}
            if d['tower_id'] is not None: action['towerID'] = d['tower_id']
            if d['upgrade_path_id'] is not None: action['pathID'] = d['upgrade_path_id']
            decisions.append({'step': {'time': d['seconds'], 'action': {d['action']: action}},
                              'earliestWave': d['earliest_wave'], 'saveForPurchase': bool(d['save_for_purchase'])})
        upgrades = [d['upgrade_id'] for d in self.rows('ga_meta_upgrade', 'strategy_id=?', (sid,), 'ordinal')]
        waves = []
        for d in self.rows('ga_early_wave', 'strategy_id=?', (sid,), 'ordinal'):
            policy, data = d['policy'], {}
            if policy == 'afterVisible': data = {'seconds': d['seconds']}
            elif policy == 'whenCountdownAtMost': data = {'seconds': d['countdown_seconds']}
            elif policy == 'whenEnemiesAtMost': data = {'count': d['enemy_count'], 'holdSeconds': d['seconds']}
            waves.append({'wave': d['wave'], 'policy': {policy: data}})
        value = {'decisions': decisions, 'metaUpgrades': upgrades, 'reinforcements': reinforcement, 'earlyWaves': {'decisions': waves}}
        if r.get('tactical_count') is not None:
            orders = self.rows('ga_tactical_order', 'strategy_id=?', (sid,), 'ordinal')
            require(len(orders) == r['tactical_count'], 'Missing tactical DNA rows')
            value['tactics'] = [{'slot': o['slot'], 'kind': o['kind'], 'pathIndex': o['path_index'], 'progress': o['progress']} for o in orders]
        return value

    def candidate(self, run, panel, expected, candidate):
        candidate = normalized_candidate(candidate)
        cid = candidate['id']
        old = self.rows('ga_candidate', 'run_id=? AND candidate_id=?', (run, cid))
        if old:
            require(old[0]['generation'] == candidate['generation'] and old[0]['stars_used'] == candidate['starsUsed']
                    and self.read_strategy(old[0]['strategy_id']) == candidate['strategy'], f'{run}/{cid}: candidate DNA changed')
        else:
            sid = self.strategy(run, candidate['strategy'])
            self.insert('ga_candidate', run_id=run, candidate_id=cid, generation=candidate['generation'], stars_used=candidate['starsUsed'], strategy_id=sid)
        key = dict(run_id=run, candidate_id=cid, panel=panel)
        old = self.rows('ga_panel', 'run_id=? AND candidate_id=? AND panel=?', tuple(key.values()))
        evaluations = candidate['evaluations']
        if old:
            require(old[0]['expected_samples'] == expected, f'{run}/{cid}/{panel}: inconsistent expected sample count')
            existing = self.read_candidate(run, cid, panel)
            require(existing == candidate, f'{run}/{cid}/{panel}: different original evidence')
            return
        self.insert('ga_panel', **key, expected_samples=expected, sample_count=len(evaluations))
        for ordinal, e in enumerate(evaluations):
            r = e['result']; built = e.get('builtTowersByKind')
            eid = self.insert('ga_evaluation', **key, ordinal=ordinal, seed=str(e['seed']), level_run_id=e.get('runID'),
                outcome=r['outcome'], seconds=r['seconds'], lives_remaining=r['livesRemaining'], gold_remaining=r['goldRemaining'],
                gold_earned=r['goldEarned'], killed=r['killed'], leaked=r['leaked'], waves_started=e['wavesStarted'], built_towers_known=built is not None,
                fate_count=len(r['fatesByTypeID']), progress_count=len(r['waveMaxProgress']), leak_count=len(r['leaksByWave']),
                economy_count=len(e['waveEconomy']), reinforcement_count=len(e['reinforcementDeployments']), wave_call_count=len(e['waveCalls']), built_tower_count=len(built or {}), tactical_count=len(e['tacticalActions']) if 'tacticalActions' in e else None)
            for i, action in enumerate(e.get('tacticalActions', [])):
                self.insert('ga_tactical_action', evaluation_id=eid, ordinal=i, seconds=action['seconds'], wave=action['wave'], slot=action['slot'], kind=action['kind'], **action['point'])
            for kind, fate in r['fatesByTypeID'].items(): self.insert('ga_enemy_fate', evaluation_id=eid, enemy_type_id=kind, **fate)
            for i, value in enumerate(r['waveMaxProgress']): self.insert('ga_wave_progress', evaluation_id=eid, ordinal=i, max_progress=value)
            for i, value in enumerate(r['leaksByWave']): self.insert('ga_wave_leak', evaluation_id=eid, ordinal=i, leaked=value)
            for i, value in enumerate(e['waveEconomy']): self.insert('ga_wave_economy', evaluation_id=eid, ordinal=i, **value)
            for i, value in enumerate(e['reinforcementDeployments']):
                self.insert('ga_reinforcement_deployment', evaluation_id=eid, ordinal=i, seconds=value['seconds'], wave=value['wave'], **value['point'])
            for i, value in enumerate(e['waveCalls']):
                self.insert('ga_wave_call', evaluation_id=eid, ordinal=i, seconds=value['seconds'], wave=value['wave'], countdown_seconds=value.get('countdownSeconds'),
                            early_call_bonus=value['earlyCallBonus'], money_before=value['moneyBefore'], money_after=value['moneyAfter'])
            for kind, count in (built or {}).items(): self.insert('ga_built_tower', evaluation_id=eid, tower_kind=kind, count=count)
        restored = self.read_candidate(run, cid, panel)
        require(restored == candidate, f'{run}/{cid}/{panel}: exact relational round trip failed')

    def read_candidate(self, run, cid, panel):
        c = self.one('ga_candidate', 'run_id=? AND candidate_id=?', (run, cid))
        evaluations = []
        for e in self.rows('ga_evaluation', 'run_id=? AND candidate_id=? AND panel=?', (run, cid, panel), 'ordinal'):
            eid = e['evaluation_id']
            def children(table): return self.rows(table, 'evaluation_id=?', (eid,), 'ordinal')
            result = {'outcome': e['outcome'], 'seconds': e['seconds'], 'livesRemaining': e['lives_remaining'], 'goldRemaining': e['gold_remaining'],
                      'goldEarned': e['gold_earned'], 'killed': e['killed'], 'leaked': e['leaked'],
                      'fatesByTypeID': {r['enemy_type_id']: {'killed': r['killed'], 'leaked': r['leaked']} for r in self.rows('ga_enemy_fate', 'evaluation_id=?', (eid,))},
                      'waveMaxProgress': [r['max_progress'] for r in children('ga_wave_progress')], 'leaksByWave': [r['leaked'] for r in children('ga_wave_leak')]}
            value = {'seed': int(e['seed']), 'result': result, 'wavesStarted': e['waves_started'],
                     'waveEconomy': [{k: r[k] for k in ('wave','seconds','money','lives')} for r in children('ga_wave_economy')],
                     'reinforcementDeployments': [{'seconds': r['seconds'], 'wave': r['wave'], 'point': {'x': r['x'], 'y': r['y']}} for r in children('ga_reinforcement_deployment')],
                     'waveCalls': []}
            for r in children('ga_wave_call'):
                call = {'seconds': r['seconds'], 'wave': r['wave'], 'earlyCallBonus': r['early_call_bonus'], 'moneyBefore': r['money_before'], 'moneyAfter': r['money_after']}
                if r['countdown_seconds'] is not None: call['countdownSeconds'] = r['countdown_seconds']
                value['waveCalls'].append(call)
            if e['level_run_id'] is not None: value['runID'] = e['level_run_id']
            if e['built_towers_known']: value['builtTowersByKind'] = {r['tower_kind']: r['count'] for r in self.rows('ga_built_tower', 'evaluation_id=?', (eid,))}
            if e.get('tactical_count') is not None:
                actions = children('ga_tactical_action')
                require(len(actions) == e['tactical_count'], 'Missing tactical evidence rows')
                value['tacticalActions'] = [dict(seconds=a['seconds'], wave=a['wave'], slot=a['slot'], kind=a['kind'], point=dict(x=a['x'], y=a['y'])) for a in actions]
            evaluations.append(value)
        return {'id': cid, 'generation': c['generation'], 'starsUsed': c['stars_used'], 'strategy': self.read_strategy(c['strategy_id']), 'evaluations': evaluations}


def export_catalog(db, output):
    """Export actual typed values, retaining all Double bits with Python repr."""
    tables = ['ga_run','ga_hero','ga_strategy',*STRATEGY_CHILDREN,'ga_candidate','ga_panel','ga_evaluation',*EVALUATION_CHILDREN,'genetic_solution']
    def literal(v):
        if v is None: return 'NULL'
        if isinstance(v, str): return "'" + v.replace("'", "''") + "'"
        require(not isinstance(v,float) or math.isfinite(v), 'Non-finite SQL value')
        return repr(v)
    with open(output, 'w') as f:
        f.write('-- Relational shipping GA catalog. Consumed by create_db.sh.\nPRAGMA foreign_keys=ON;\nBEGIN;\nDELETE FROM genetic_solution;\n')
        runs = ','.join(literal(r[0]) for r in db.execute('SELECT run_id FROM ga_run ORDER BY run_id'))
        f.write(f'DELETE FROM ga_run WHERE run_id IN ({runs});\n')
        for table in tables:
            columns = [r[1] for r in db.execute(f'PRAGMA table_info({table})')]
            if not columns: continue  # Historical databases predate optional evidence tables.
            for row in db.execute(f'SELECT * FROM {table} ORDER BY {columns[0]}'):
                f.write(f"INSERT INTO {table}({','.join(columns)}) VALUES({','.join(literal(v) for v in row)});\n")
        f.write('COMMIT;\n')


def fitness(evaluations):
    # Match Swift's ordered Double reduce; Python's built-in sum may change its
    # algorithm across versions, as SQLite SUM already did.
    def fold(values):
        total = 0.0
        for value in values: total += value
        return total
    n = len(evaluations)
    return (sum(e['result']['outcome']=='victory' for e in evaluations)/n,
            fold(float(e['result']['livesRemaining']) if e['result']['outcome']=='victory' else 0.0 for e in evaluations)/n,
            fold(float(e['wavesStarted']) for e in evaluations)/n,
            fold(e['result']['seconds'] if e['result']['outcome']=='defeat' else 0.0 for e in evaluations)/n)


def migrate_study(store, source, row, solutions, documents):
    run, config, plans = row['run_id'], json.loads(row['configuration_json']), json.loads(row['plans_json'])
    require(config['algorithm'] == 'genetic-v8', f'{run}: unsupported legacy algorithm {config["algorithm"]}; original preserved')
    matching = [s for s in solutions if s['runID'] == run]
    require(matching, f'{run}: no retained solution context; cannot invent its content fingerprint')
    store.run(matching[0])
    o = config['options']
    store.insert('ga_study', run_id=run, algorithm=config['algorithm'], build_version=config['buildVersion'], snapshot_sha256=config['contentSHA256'],
        workers=o['workers'], population=o['population'], generations=o['generations'], training_seeds=o['trainingSeeds'], validation_seeds=o['validationSeeds'],
        finalists=o['finalists'], max_evaluations=o['maxEvaluations'], hours=o['hours'], search_seed=str(o['seed']), star_minimum=o.get('starMinimum'),
        star_maximum=o.get('starMaximum'), star_step=o['starStep'], fixed_meta=o['fixedMeta'], early_wave_calls=o['earlyWaveCalls'],
        meta_selections=o['metaSelections'], minimum_meta_candidates=o['minimumMetaCandidates'], meta_adaptation_generations=o['metaAdaptationGenerations'],
        hero_ai_override=o.get('heroAIEnabled'), selected_heroes_overridden='selectedHeroIDs' in o,
        majority_tower_kind=o['towerLimits'].get('majorityKind'), earned_stars=config['earnedStars'])
    for panel, seeds in [('training',config['trainingSeeds']),('validation',config['validationSeeds'])]:
        for i, seed in enumerate(seeds): store.insert('ga_study_seed', run_id=run, panel=panel, ordinal=i, seed=str(seed))
    for i, stars in enumerate(config['requestedStarsUsed']):
        store.insert('ga_study_star', run_id=run, ordinal=i, stars_used=stars, reachable=stars in config['reachableStarsUsed'])
    for upgrade in config['databaseSelectedUpgrades']: store.insert('ga_study_upgrade', run_id=run, upgrade_id=upgrade)
    for kind, maximum in o['towerLimits']['maximumByKind'].items(): store.insert('ga_tower_limit', run_id=run, tower_kind=kind, maximum=maximum)
    for role, strategies in [('seed',o['seedStrategies']),('exchange',[o['metaExchangeFrom']] if 'metaExchangeFrom' in o else [])]:
        for i, strategy in enumerate(strategies):
            sid = store.strategy(run, strategy)
            store.insert('ga_input_strategy', run_id=run, role=role, ordinal=i, strategy_id=sid)
    count = 0
    expected_fitness = {}
    for result in source.execute('SELECT * FROM money_study_result WHERE run_id=? ORDER BY placement_plan,upgrade_policy', (run,)):
        require(result['upgrade_policy'] in (0,1), f'{run}: unknown evaluation panel')
        panel = 'training' if result['upgrade_policy'] == 0 else 'validation'
        c = json.loads(result['seed_results_json'])
        require(c['id'] == result['placement_plan'], f'{run}: candidate ID mismatch')
        require(len(c['evaluations']) == result['seeds'], f'{run}: sample count mismatch')
        require([e['seed'] for e in c['evaluations']] == config[panel+'Seeds'][:len(c['evaluations'])], f'{run}: seed panel mismatch')
        store.candidate(run, panel, o[panel+'Seeds'], c)
        expected_fitness[(c['id'],panel)] = fitness(c['evaluations'])
        count += 1
        if count % 1000 == 0: print(f'{run}: verified {count} candidate panels', flush=True)
    actual_fitness = {(r['candidate_id'],r['panel']): tuple(r[k] for k in ('win_rate','mean_victory_lives','mean_waves_started','mean_survival_seconds'))
                      for r in store.db.execute('SELECT * FROM ga_candidate_fitness WHERE run_id=?',(run,))}
    require(actual_fitness == expected_fitness, f'{run}: SQL fitness differs from original ordered Double calculations')
    progress = documents.get('progress.json')
    summary = documents.get('summary.json')
    if progress:
        require(progress['runID'] == run, 'Progress run mismatch')
        store.insert('ga_progress', run_id=run, phase=progress['phase'], percent_complete=progress['percentComplete'], elapsed_seconds=progress['elapsedSeconds'],
            estimated_seconds_remaining=progress.get('estimatedSecondsRemaining'), completed_generations=progress['completedGenerations'],
            training_evaluations=progress['trainingEvaluations'], validation_evaluations=progress['validationEvaluations'])
        for i, milestone in enumerate(progress['milestones']):
            store.insert('ga_progress_milestone', run_id=run, ordinal=i, percent=milestone['percent'], elapsed_seconds=milestone['elapsedSeconds'])
    if summary:
        require(summary['runID'] == run, 'Summary run mismatch')
        # Legacy reports did not persist the stop reason. NULL explicitly means unknown.
        store.insert('ga_summary', run_id=run, search_stop_reason=None, validation_complete=summary['validationComplete'], evaluation_seconds=summary['elapsedSeconds'],
            recording_seconds=summary.get('playbackRecordingSeconds'), total_seconds=summary.get('totalElapsedSeconds'), cache_hits=summary['cacheHits'],
            completed_generations=summary['generations'], unique_candidates=summary['uniqueGenomes'], playback_recordings=summary.get('playbackRecordings'))
    checkpoint = plans.get('checkpoint')
    if checkpoint:
        ids = [r['candidate_id'] for r in store.rows('ga_candidate','run_id=?',(run,))]
        store.insert('ga_checkpoint', run_id=run, completed_generations=summary['generations'] if summary else progress.get('completedGenerations') if progress else None,
                     next_candidate_id=max(ids)+1 if ids else 0, cache_hits=summary['cacheHits'] if summary else None)
        by_selection = {}
        for candidate in store.rows('ga_candidate','run_id=?',(run,)):
            upgrades = tuple(r['upgrade_id'] for r in store.rows('ga_meta_upgrade','strategy_id=?',(candidate['strategy_id'],),'ordinal'))
            by_selection.setdefault((candidate['stars_used'],upgrades),[]).append(candidate['candidate_id'])
        for star_string, selections in checkpoint.items():
            stars = int(star_string)
            detail = next((r for r in summary['starResults'] if r['starsUsed']==stars), None) if summary else None
            active_by_upgrades = {}
            for key,archive in selections.items():
                require(archive, f'{run}: cannot recover upgrade set from empty legacy archive')
                c = store.one('ga_candidate','run_id=? AND candidate_id=?',(run,archive[0]))
                upgrades = tuple(store.read_strategy(c['strategy_id'])['metaUpgrades'])
                active_by_upgrades[upgrades]=(key,archive)
            records = detail['metaSelectionResults'] if detail else [dict(metaUpgrades=list(u), activeAtEnd=True, introducedGeneration=None) for u in active_by_upgrades]
            for i,info in enumerate(records):
                upgrades = tuple(info['metaUpgrades'])
                active = info['activeAtEnd']
                capacity = detail['plansPerMetaSelection'] if detail else o['population']//len(selections)
                members = by_selection.get((stars,upgrades),[])
                if active:
                    require(upgrades in active_by_upgrades, 'Active summary selection missing from checkpoint')
                    key,archive = active_by_upgrades[upgrades]
                else:
                    key = 'legacy-retired:' + ','.join(upgrades)
                    # Retired archives were not duplicated in plans_json. Recover
                    # their exact top-capacity order from all original evaluations.
                    ranked=store.db.execute("SELECT candidate_id FROM ga_candidate_fitness WHERE run_id=? AND panel='training' AND stars_used=? ORDER BY win_rate DESC,mean_victory_lives DESC,mean_waves_started DESC,mean_survival_seconds DESC,candidate_id",(run,stars))
                    member_set=set(members)
                    archive=[r[0] for r in ranked if r[0] in member_set][:capacity]
                if info.get('bestTraining'):
                    require(archive and archive[0]==info['bestTraining']['id'], 'Recovered archive differs from saved champion')
                if 'trainingCandidates' in info: require(len(members)==info['trainingCandidates'],'Selection candidate count changed')
                store.insert('ga_population_selection',run_id=run,stars_used=stars,selection_key=key,ordinal=i,
                    introduced_generation=info['introducedGeneration'],active=active,plans_per_selection=capacity,minimum_candidates=o['minimumMetaCandidates'])
                for upgrade in upgrades: store.insert('ga_population_upgrade',run_id=run,stars_used=stars,selection_key=key,upgrade_id=upgrade)
                for cid in members:
                    store.insert('ga_population_member',run_id=run,stars_used=stars,selection_key=key,candidate_id=cid,archive_ordinal=archive.index(cid) if cid in archive else None)
    # Duplicate report documents must agree with the authoritative original rows.
    for name in ('population.json','validation.json'):
        for c in documents.get(name,[]):
            panel='training' if name=='population.json' else 'validation'
            require(store.read_candidate(run,c['id'],panel)==normalized_candidate(c),f'{name}: candidate {c["id"]} differs from original row')
    return count


def migrate(source_path, destination):
    source_path, destination = pathlib.Path(source_path).resolve(), pathlib.Path(destination).resolve()
    require(source_path != destination, 'Source and destination must be different files')
    require(source_path.is_file(), f'Missing source: {source_path}')
    require(not destination.exists(), f'Refusing to overwrite {destination}')
    # Read-only snapshot: another desktop connection may remain open. The
    # explicit transaction keeps conversion and verification on the same view.
    src = sqlite3.connect(source_path.as_uri()+'?mode=ro', uri=True)
    src.row_factory=sqlite3.Row
    src.execute("BEGIN")
    dst=None
    created=False
    try:
        require(not src.execute("SELECT 1 FROM simulator_run WHERE status='running'").fetchone(),
                'Finish the active study before offline conversion')
        require(not src.execute("SELECT 1 FROM sqlite_master WHERE name='ga_run'").fetchone(), 'Already relational; no conversion needed')
        solutions=[json.loads(r[0]) for r in src.execute('SELECT solution_json FROM genetic_solution')]
        studies=[r for r in src.execute('SELECT * FROM money_study') if json.loads(r['configuration_json']).get('algorithm','').startswith('genetic-')]
        documents={}
        if src.execute("SELECT 1 FROM sqlite_master WHERE name='simulator_document'").fetchone():
            documents={r['name']:json.loads(r['content_json']) for r in src.execute('SELECT * FROM simulator_document')}
        # Exclusive reservation; leave no ambiguous partially converted database.
        with destination.open('xb'): pass
        created=True
        dst=sqlite3.connect(destination)
        src.backup(dst)
        dst.execute('PRAGMA foreign_keys=OFF')
        dst.executescript((ROOT/'Db/Migrations/ga_relational.sql').read_text())
        dst.executescript((ROOT/'Db/DDL/create_genetic_solutions.sql').read_text())
        dst.executescript((ROOT/'Db/DDL/create_genetic_placements.sql').read_text())
        dst.executescript((ROOT/'Db/DDL/create_genetic_studies.sql').read_text())
        dst.executescript((ROOT/'Db/DDL/create_genetic_fitness.sql').read_text())
        store=Store(dst)
        with dst:
            for solution in solutions: store.run(solution)
            for study in studies: migrate_study(store,src,study,solutions,documents)
            for s in solutions:
                store.candidate(s['runID'],s['panel'],s['expectedSamples'],s['candidate'])
                store.insert('genetic_solution',run_id=s['runID'],candidate_id=s['candidate']['id'],panel=s['panel'])
            for study in studies:
                dst.execute('DELETE FROM money_study_result WHERE run_id=?',(study['run_id'],))
                dst.execute('DELETE FROM money_study WHERE run_id=?',(study['run_id'],))
            if studies:
                known={'content.json','configuration.json','run.json','progress.json','worker-configuration.json','population.json','validation.json','summary.json'}
                for name in documents:
                    if name in known or name.startswith('best-stars-'):
                        dst.execute('DELETE FROM simulator_document WHERE name=?',(name,))
        require(dst.execute('PRAGMA integrity_check').fetchone()[0]=='ok','Integrity check failed')
        require(not dst.execute('PRAGMA foreign_key_check').fetchall(),'Foreign key check failed')
        for table in ('level_run','level_action','genetic_solution_recording'):
            if src.execute('SELECT 1 FROM sqlite_master WHERE name=?',(table,)).fetchone():
                # Exact byte-for-byte SQL values for all saved playback rows.
                columns=[r[1] for r in src.execute(f'PRAGMA table_info({table})')]
                order=','.join(columns[:2]) if table=='level_action' else columns[0]
                original=src.execute(f'SELECT * FROM {table} ORDER BY {order}')
                restored=dst.execute(f'SELECT * FROM {table} ORDER BY {order}')
                for a,b in itertools.zip_longest(original,restored): require(a is not None and b is not None and tuple(a)==tuple(b),f'{table}: playback data changed')
        print(f'Converted {len(studies)} studies and {len(solutions)} retained solutions. Exact candidate and recording round trips verified.')
        print(f'Original preserved: {source_path}\nRelational database: {destination}')
    except BaseException:
        if dst is not None:
            dst.close(); dst=None
        if created: destination.unlink(missing_ok=True)
        raise
    finally:
        src.close()
        if dst is not None: dst.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source',type=pathlib.Path)
    parser.add_argument('destination',type=pathlib.Path)
    args=parser.parse_args()
    try: migrate(args.source,args.destination)
    except (ValueError,KeyError,TypeError,sqlite3.Error,OSError) as error:
        parser.exit(1,f'Conversion failed; original preserved: {error}\n')

if __name__=='__main__': main()
