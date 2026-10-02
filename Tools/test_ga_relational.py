#!/usr/bin/env python3
"""Regression checks for offline migration, with disposable legacy fixtures."""
import copy
import hashlib
import json
import pathlib
import sqlite3
import tempfile
import unittest
from ga_relational import Store, migrate, normalized_candidate

RUN='11111111-1111-4111-8111-111111111111'
LEVEL='22222222-2222-4222-8222-222222222222'
DIFFICULTY='33333333-3333-4333-8333-333333333333'
HERO='44444444-4444-4444-8444-444444444444'

class MigrationTests(unittest.TestCase):
    def solution(self):
        strategy={'decisions':[{'earliestWave':2,'saveForPurchase':True,'step':{'time':1.2345678901234567,'action':{'build':{'slot':0,'towerID':LEVEL}}}}],
                  'metaUpgrades':[], 'reinforcements':{'priority':{'nearPoint':{'_0':{'x':1.2345678901234567,'y':9.876543210987654}}},'holdSeconds':3},
                  'earlyWaves':{'decisions':[{'wave':2,'policy':{'whenEnemiesAtMost':{'count':3,'holdSeconds':5.2}}}]}}
        result={'outcome':'victory','seconds':123.45678901234567,'livesRemaining':19,'goldRemaining':15,'goldEarned':35,'killed':2,'leaked':1,
                'fatesByTypeID':[LEVEL,{'killed':2,'leaked':1}],'waveMaxProgress':[0.12345678901234567,1],'leaksByWave':[1]}
        evaluation={'seed':2**64-1,'result':result,'wavesStarted':3,'builtTowersByKind':{},
                    'waveEconomy':[{'wave':2,'seconds':3.2,'money':13,'lives':19}],
                    'reinforcementDeployments':[{'seconds':3.3,'wave':2,'point':{'x':12.34,'y':56.78}}],
                    'waveCalls':[{'seconds':3.4,'wave':2,'countdownSeconds':3,'earlyCallBonus':2,'moneyBefore':13,'moneyAfter':15}]}
        return {'runID':RUN,'panel':'validation','formatVersion':2,'heroesEnabled':True,'expectedSamples':1,'executableSHA256':'a'*64,
                'context':{'levelID':LEVEL,'difficultyID':DIFFICULTY,'startingMoney':100,'bountyFraction':1,'maxGameSeconds':1800,'contentSHA256':'b'*64,
                           'heroLoadout':{'selectedHeroIDs':[HERO],'deployments':[{'heroID':HERO,'role':'primary','spawnFeatureID':'spawn',
                               'position':{'x':1.1,'y':2.2},'aiEnabled':False}]}},
                'candidate':{'id':1,'generation':2,'starsUsed':0,'strategy':strategy,'evaluations':[evaluation]}}

    def source(self, directory, solution=None):
        path=pathlib.Path(directory)/'original.sqlite'
        # Model only the historical schema needed by the converter. Production
        # destination DDL is loaded from the maintained authored SQL files.
        db=sqlite3.connect(':memory:')
        db.executescript('''
            CREATE TABLE level_info(id TEXT PRIMARY KEY,level_name TEXT);
            CREATE TABLE difficulty(id TEXT PRIMARY KEY);
            CREATE TABLE meta_upgrade(upgrade_key TEXT PRIMARY KEY);
            CREATE TABLE simulator_run(id TEXT PRIMARY KEY,status TEXT);
            CREATE TABLE money_study(run_id TEXT,configuration_json TEXT,plans_json TEXT);
            CREATE TABLE genetic_solution(run_id TEXT,candidate_id INTEGER,panel TEXT,solution_json TEXT);
        ''')
        db.execute('INSERT INTO level_info VALUES(?,?)',(LEVEL,'fixture'))
        db.execute('INSERT INTO difficulty VALUES(?)',(DIFFICULTY,))
        db.execute('INSERT INTO genetic_solution VALUES(?,?,?,?)',(RUN,1,'validation',json.dumps(solution or self.solution())))
        db.commit()
        target=sqlite3.connect(path);db.backup(target);target.close();db.close()
        return path

    def test_exact_conversion_with_max_seed_and_all_evidence_and_open_reader(self):
        with tempfile.TemporaryDirectory(prefix='td-ga-migration-test-') as directory:
            source=self.source(directory); target=pathlib.Path(directory)/'relational.sqlite'
            before=hashlib.sha256(source.read_bytes()).digest()
            reader=sqlite3.connect(source);reader.execute('SELECT * FROM genetic_solution').fetchall()
            try:migrate(source,target)
            finally:reader.close()
            self.assertEqual(before,hashlib.sha256(source.read_bytes()).digest())
            db=sqlite3.connect(target);store=Store(db)
            self.assertEqual(store.read_candidate(RUN,1,'validation'),normalized_candidate(self.solution()['candidate']))
            self.assertFalse(any('json' in r[1] for r in db.execute('PRAGMA table_info(genetic_solution)')))
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(),[])
            self.assertEqual(db.execute('SELECT seed FROM ga_evaluation').fetchone()[0],str(2**64-1))
            db.close()

    def test_failed_conversion_removes_only_its_new_output(self):
        with tempfile.TemporaryDirectory(prefix='td-ga-migration-test-') as directory:
            broken=self.solution();del broken['candidate']['strategy']['reinforcements']
            source=self.source(directory,broken);before=source.read_bytes();target=pathlib.Path(directory)/'relational.sqlite'
            with self.assertRaises(KeyError):migrate(source,target)
            self.assertFalse(target.exists());self.assertEqual(source.read_bytes(),before)

    def test_tactical_intent_and_actual_sites_survive_conversion(self):
        with tempfile.TemporaryDirectory(prefix='td-ga-migration-test-') as directory:
            solution = self.solution()
            solution['candidate']['strategy']['tactics'] = [dict(slot=0,kind='rally',pathIndex=1,progress=0.1234567890123456)]
            solution['candidate']['evaluations'][0]['tacticalActions'] = [dict(seconds=1.2,wave=0,slot=0,kind='rally',point=dict(x=1.2345678901234567,y=4.567890123456789))]
            source=self.source(directory,solution);target=pathlib.Path(directory)/'relational.sqlite'
            migrate(source,target)
            db=sqlite3.connect(target)
            self.assertEqual(Store(db).read_candidate(RUN,1,'validation'),normalized_candidate(solution['candidate']))
            db.close()

    def test_never_overwrites_a_destination_or_source(self):
        with tempfile.TemporaryDirectory(prefix='td-ga-migration-test-') as directory:
            source=self.source(directory);before=source.read_bytes()
            with self.assertRaises(ValueError):migrate(source,source)
            target=pathlib.Path(directory)/'existing.sqlite';target.write_bytes(b'preserve')
            with self.assertRaises(ValueError):migrate(source,target)
            self.assertEqual(target.read_bytes(),b'preserve');self.assertEqual(source.read_bytes(),before)

    def test_refuses_active_studies(self):
        with tempfile.TemporaryDirectory(prefix='td-ga-migration-test-') as directory:
            source=self.source(directory);db=sqlite3.connect(source)
            db.execute("INSERT INTO simulator_run VALUES(?,'running')",(RUN,));db.commit();db.close()
            target=pathlib.Path(directory)/'relational.sqlite'
            with self.assertRaisesRegex(ValueError,'active study'):migrate(source,target)
            self.assertFalse(target.exists())

if __name__=='__main__':unittest.main()
