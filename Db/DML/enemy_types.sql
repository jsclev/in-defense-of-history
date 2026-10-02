-- The replacement keeps its stable enemy UUID and canonical artwork identifier for existing references.
INSERT INTO enemy_type (
    id, enemy_type_key, enemy_type_name, enemy_type_long_name, enemy_type_description, image_name, icon_image_name, max_hp, speed, cover, discipline, hardiness, damage_min, damage_max, bounty, lives_cost, break_band_lo, break_band_hi, traits, morale_speed_threshold, morale_attack_threshold, morale_speed_multiplier, morale_attack_multiplier
) VALUES
('c972308d-7313-45ae-8cb4-04d2d5b78046', 'loyalist_militia', 'Loyalist Militia', 'Loyalist Militia', 'Lightly trained troops with fragile morale and modest staying power.', 'loyalist_militia', 'loyalist_militia', 50.0, 60.0, 0.35, 0.2, 0.3, 2.0, 4.0, 8, 1, 0.45, 0.65, '[{"type":"wavering"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('369e4cb5-38dc-4857-8701-e6c1320c52bc', 'regimental_drummer', 'Regimental Drummer', 'Regimental Drummer', 'A military musician who advances with the column but deals no melee damage.', 'regimental_drummer', 'regimental_drummer', 60.0, 60.0, 0.1, 0.55, 0.6, 0.0, 0.0, 20, 1, 0.35, 0.5, '[{"type":"rallyBeat","radius":90,"moralePerSecond":6}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('86175b06-0f08-4407-bac0-0aa95cde3f52', 'redcoat_regular', 'Redcoat Regular', 'Redcoat Regular', 'Disciplined line infantry with balanced speed and staying power.', 'redcoat_regular', 'redcoat_regular', 90.0, 60.0, 0.05, 0.6, 0.7, 4.0, 7.0, 15, 1, 0.3, 0.45, '[]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('59cffa58-a230-4b83-b6e4-00cd84175ad1', 'light_infantry', 'Light Infantry', 'Light Infantry', 'Fast skirmishers whose cover reduces incoming melee and explosive damage.', 'light_infantry', 'light_infantry', 70.0, 85.0, 0.45, 0.5, 0.6, 3.0, 6.0, 18, 1, 0.3, 0.45, '[{"type":"skirmish"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('e8e182d1-c209-4cdd-8f8d-8d95de3fe167', 'hessian_jager', 'Hessian Jäger', 'Hessian Jäger', 'Accurate riflemen combining strong cover with hard-hitting attacks.', 'hessian_jager', 'hessian_jager', 65.0, 85.0, 0.55, 0.45, 0.55, 6.0, 9.0, 22, 1, 0.3, 0.45, '[{"type":"mercenary"},{"type":"marksman"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('7c014dae-5896-4b32-896e-f95555833e1e', 'hessian_fusilier', 'Hessian Fusilier', 'Hessian Fusilier', 'Sturdy German infantry that holds formation under pressure.', 'hessian_fusilier', 'hessian_fusilier', 110.0, 60.0, 0.05, 0.7, 0.65, 5.0, 8.0, 20, 1, 0.28, 0.4, '[{"type":"mercenary"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('b3e0cd5e-0128-46eb-a2c3-fe193d728228', 'queens_ranger', 'Queen''s Ranger', 'Queen''s Ranger', 'Green-coated light infantry that slips past ground troops under cover; nearby heroes expose it.', 'native_warrior', 'native_warrior', 60.0, 120.0, 0.6, 0.35, 0.75, 5.0, 8.0, 20, 1, 0.35, 0.55, '[{"type":"concealment","duration":3.4,"visibleInterval":4.5,"troopRadius":100,"heroRevealRadius":110,"opacity":0.34}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('414fd1af-c633-4780-b513-b70f13018cd3', 'highlander', 'Highlander', 'Highlander', 'Fast, hard-hitting infantry with the resolve to press the attack.', 'highlander', 'highlander', 130.0, 85.0, 0.1, 0.75, 0.75, 8.0, 12.0, 30, 1, 0.25, 0.35, '[{"type":"highlandCharge"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('ef3a782a-58db-4ac8-b372-0745a27669b0', 'light_dragoon', 'Light Dragoon', 'Light Dragoon', 'Fast cavalry that rides past blocking troops.', 'light_dragoon', 'light_dragoon', 140.0, 120.0, 0.15, 0.65, 0.6, 7.0, 11.0, 35, 1, 0.28, 0.4, '[{"type":"rideDown"},{"type":"falter"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('9ba1961d-cb79-4e0b-a6cd-6806d115813e', 'spy', 'Spy', 'Spy', 'A lightly armed infiltrator with high cover and little staying power.', 'spy', 'spy', 45.0, 85.0, 0.7, 0.4, 0.5, 1.0, 2.0, 25, 0, 0.35, 0.5, '[{"type":"disguised"},{"type":"saboteur"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('5392e3d1-c1c6-40d0-b54d-2be8aa4dc277', 'grenadier', 'Grenadier', 'Grenadier', 'Slow, tough assault infantry with powerful close-range attacks.', 'grenadier', 'grenadier', 240.0, 40.0, 0.0, 0.85, 0.75, 10.0, 15.0, 45, 2, 0.22, 0.3, '[{"type":"steadyAdvance"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('f00dd278-0466-4bd5-b454-9c5a3dc964ec', 'royal_artillery', 'Royal Artillery', 'Royal Artillery', 'Slow-moving gun crews that trade speed for heavy damage.', 'royal_artillery', 'royal_artillery', 300.0, 25.0, 0.1, 0.7, 0.65, 15.0, 25.0, 60, 2, 0.25, 0.35, '[{"type":"bombard"},{"type":"crewed"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('48cf0732-a2a6-4271-b631-232a70c263ce', 'mounted_officer', 'Mounted Officer', 'Mounted Officer', 'A mounted commander who can signal a limited reserve of regular infantry into battle.', 'mounted_officer', 'mounted_officer', 180.0, 85.0, 0.1, 0.9, 0.7, 6.0, 10.0, 50, 2, 0.2, 0.3, '[{"type":"commandAura","radius":120,"disciplineBonus":0.25,"deathShock":25},{"type":"reinforcementCall","enemyTypeKey":"redcoat_regular","initialDelay":8,"interval":14,"windup":2,"count":2,"maxCalls":2,"spawnInterval":1}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('8dc553a0-c688-470d-ae0a-f2a0cfa04f45', 'foot_guards', 'Foot Guards', 'Foot Guards', 'Elite infantry with exceptional toughness and strong resistance to morale shock.', 'foot_guards', 'foot_guards', 500.0, 40.0, 0.0, 1.0, 0.85, 12.0, 20.0, 75, 3, 0.15, 0.25, '[{"type":"steadyAdvance"},{"type":"tag","name":"unbreakable"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666);

-- Campaign bosses represent command groups and formations, not superhuman individuals.
-- Historical sources and adaptation notes checked 2026-10-02.
INSERT INTO enemy_type (
    id, enemy_type_key, enemy_type_name, enemy_type_long_name, enemy_type_description, image_name, icon_image_name, max_hp, speed, cover, discipline, hardiness, damage_min, damage_max, bounty, lives_cost, break_band_lo, break_band_hi, traits, morale_speed_threshold, morale_attack_threshold, morale_speed_multiplier, morale_attack_multiplier
) VALUES
('df3c681f-3dfc-5b0a-a412-2bda75e0bfa7', 'howe_assault', 'General Howe', 'General William Howe', 'A major assault formation that restores the morale of nearby enemies as it advances.', 'howe_assault', 'howe_assault_icon', 2500.0, 35.0, 0.1, 0.9, 0.9, 22.0, 32.0, 250, 20, 0.15, 0.25, '[{"type":"boss","renderScale":1.4,"rallyRadius":100,"rallyMoralePerSecond":15,"meleeSplashRadius":0,"barrageRange":0,"barrageRadius":0,"barrageInterval":0,"barrageWindup":0,"barrageDamage":0}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('7df9377b-c140-578a-8085-3d5c35a9b7e0', 'hill_rearguard', 'Lt. Colonel Hill', 'Lieutenant Colonel John Hill', 'A regimental command group that calls infantry reserves and strikes clustered defenders in melee.', 'hill_rearguard', 'hill_rearguard_icon', 4000.0, 40.0, 0.15, 0.95, 0.9, 30.0, 44.0, 400, 20, 0.12, 0.2, '[{"type":"boss","renderScale":1.4,"rallyRadius":0,"rallyMoralePerSecond":0,"meleeSplashRadius":110,"barrageRange":0,"barrageRadius":0,"barrageInterval":0,"barrageWindup":0,"barrageDamage":0},{"type":"reinforcementCall","enemyTypeKey":"redcoat_regular","initialDelay":6,"interval":12,"windup":2,"count":3,"maxCalls":3,"spawnInterval":0.8}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('78259b8a-81de-5a1f-9aa7-918754acbb5d', 'clinton_siege', 'General Clinton', 'General Henry Clinton', 'A heavy siege detachment that bombards groups of defenders unless engaged in melee.', 'clinton_siege', 'clinton_siege_icon', 6000.0, 22.0, 0.2, 1.0, 0.95, 35.0, 50.0, 600, 20, 0.1, 0.18, '[{"type":"boss","renderScale":1.4,"rallyRadius":0,"rallyMoralePerSecond":0,"meleeSplashRadius":0,"barrageRange":160,"barrageRadius":45,"barrageInterval":6,"barrageWindup":2,"barrageDamage":80}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666);

-- Three-page enemy encyclopedia. Original roster sources checked 2026-09-22.
-- Strategies describe the shared BattleEngine, including abilities not yet active.
INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Use an early infantry post to hold these troops under fire. Their limited health makes them easier to remove than regulars, and low discipline leaves them more vulnerable to artillery morale shock. Do not let a crowded wave occupy every defender while later enemies pass.',
       'Loyalists were American colonists who supported continued membership in the British Empire. At Kings Mountain in 1780, Americans fought on both sides; Loyalist forces included local men as well as trained provincial soldiers. The Revolution was also a civil conflict between neighbors.',
       'We included Loyalist Militia to show that the opposing army was not simply an overseas force. They provide an accessible first test of holding a road and sustaining fire while introducing the divided loyalties of the war.',
       'Low health and discipline are balancing choices for this militia archetype, not a judgment about the courage or competence of all Loyalists.',
       'National Park Service · Patriots and Loyalists',
       'https://www.nps.gov/kimo/learn/patriots-and-loyalists.htm'
FROM enemy_type WHERE enemy_type_key = 'loyalist_militia';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'This enemy currently advances without dealing melee damage. Infantry can hold it while towers fire. Its rallying role is part of the roster design, but nearby enemies do not receive a drummer morale bonus in the current game.',
       'Drummers and fifers conveyed orders, regulated camp routines and helped troops keep marching cadence. A drum could carry a signal through battlefield noise more effectively than a shouted command. Military music also supported ceremony and camp morale.',
       'We included the drummer to give military communication a visible place among the fighting troops. Its intended support role asks players to notice the people who help an army function, beyond those carrying weapons.',
       'The intended morale-restoration ability is not active in the current game. The demonstration shows the same unarmed advance used in battles; it does not stage a healing effect. A future rally radius would be an abstraction of communication, not a literal historical power.',
       'National Park Service · Fife and Drum',
       'https://www.nps.gov/cowp/learn/education/unit-4-the-war-for-american-independence.htm'
FROM enemy_type WHERE enemy_type_key = 'regimental_drummer';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Treat these troops as the baseline for a defended approach. Infantry buys firing time, while overlapping towers finish enemies before the next group arrives. Their discipline reduces artillery morale shock, so plan for sustained damage as well as disruption.',
       'British regular infantry brought training and regimental organization to the war. On the retreat from Concord in April 1775, British soldiers used flankers and coordinated movement under sustained attack. Their experience was more adaptable than the familiar image of men who only stood in rigid lines.',
       'We included the regular as the reference point for the roster. A dependable middle ground in speed, health and damage makes the faster, heavier and more specialized opponents easier to understand.',
       'A single figure stands for part of a much larger formation. Road-following movement and individual health bars simplify regimental tactics; the encounter is not a reconstruction of a historical battle.',
       'National Park Service · The Embattled British Column',
       'https://www.nps.gov/articles/000/the-embattled-british-column-survival-against-the-odds-on-the-battle-road.htm'
FROM enemy_type WHERE enemy_type_key = 'redcoat_regular';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Cover the approach early: these troops spend less time in each firing lane than regulars. Their cover reduces incoming melee damage and helps against explosions according to the weapon’s cover penetration. Direct tower shots remain useful while infantry holds them.',
       'British light infantry operated in open order and rough country. At Guilford Courthouse, the Crown army included both British light troops and German riflemen. Skirmishing was part of British practice, not an exclusively American innovation.',
       'We included light infantry to challenge short firing lanes and static defenses. Their pace and cover encourage players to combine holding troops with sustained direct fire, while representing the army’s adaptable specialists.',
       'Cover is a damage modifier in this game, not invisibility or a chance to dodge every shot. There is no separate skirmish movement mode in the current battle engine.',
       'National Park Service · Crown Forces Soldiers',
       'https://www.nps.gov/guco/crownforcessoldiers.htm'
FROM enemy_type WHERE enemy_type_key = 'light_infantry';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Use direct tower fire and keep your blocking troops supported. These enemies combine quick movement with cover and strong melee hits. Their rifle artwork identifies their historical role; they do not shoot at distant defenders in the current game.',
       'Jäger units were German rifle-armed light infantry serving with the British. They fought in loose order and rough terrain. German contingents served under agreements between their rulers and Britain; individual soldiers were not simply freelancers selling themselves to the highest bidder.',
       'We included the Jäger to distinguish German specialist troops from ordinary line infantry. The combination of cover and strong attacks creates pressure on exposed defenders and acknowledges the international character of the Crown forces.',
       'The current game expresses this specialist through movement, cover and melee damage. It does not simulate rifle range or a separate marksman ability. The internal mercenary label does not describe how these state auxiliaries were recruited.',
       'National Park Service · Crown Forces Soldiers',
       'https://www.nps.gov/guco/crownforcessoldiers.htm'
FROM enemy_type WHERE enemy_type_key = 'hessian_jager';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Allow more firing time than you would for lightly trained militia. These troops can absorb punishment and resist morale shock. Hold them in an overlapping firing lane instead of relying on one brief burst as they pass.',
       'Britain employed auxiliary regiments supplied by German states, including Hesse-Cassel. The soldiers remained members of their own armies. Men of the von Knyphausen regiment are among those buried at St. Paul’s Church after service in America, a reminder of the war’s human cost beyond Britain and the colonies.',
       'We included a German line-infantry type alongside the Jäger so that German participation is not reduced to a single specialist. Its staying power supplies a steady pressure test between the regular infantry and the heaviest assault units.',
       'This is a broad fusilier archetype, not a portrait of one named soldier or regiment. Its durability is a gameplay distinction, not a claim that nationality determines fighting ability; the mercenary tag grants no additional combat power.',
       'National Park Service · The Hessians',
       'https://www.nps.gov/articles/000/the-hessians.htm'
FROM enemy_type WHERE enemy_type_key = 'hessian_fusilier';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Bring a hero close to expose this enemy. It hides briefly as it approaches melee-tower troops on its path, slipping past their blocking line. If its path has no living melee-tower troops, it periodically takes cover anyway. The faint figure keeps moving and cannot take any damage while concealed; nearby living heroes reveal it for every defender. Attack during the visible interval between hiding bursts.',
       'The Queen''s Rangers were a Loyalist light corps that served the Crown during the American Revolution, fighting at Brandywine, Monmouth, Charleston and Yorktown. Under John Graves Simcoe the corps developed into a legion of infantry and cavalry known for green uniforms, patrol work and unconventional tactics.',
       'We included the Queen''s Ranger to make scouting and hero placement matter. Its green coat and distinctive light-infantry cap identify a trained Loyalist specialist alongside the regulars and militia.',
       'Brief immunity and a hero''s revealing radius are gameplay abstractions of concealment and detection, not literal historical powers. This unit replaces the former broad Native Warrior archetype in authored waves; its campaign appearances are a gameplay roster choice rather than an exact order of battle.',
       'Museum of the American Revolution · The Queen''s American Rangers',
       'https://www.amrevmuseum.org/read-the-revolution/the-queen-s-american-rangers'
FROM enemy_type WHERE enemy_type_key = 'queens_ranger';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Support infantry before this fast, hard-hitting opponent reaches them. A lone blocking post can lose troops while waiting for help. Sustained fire is important because strong discipline limits the effect of morale shock.',
       'Fraser’s Highlanders, the 71st Regiment of Foot, were raised in Scotland in 1775. They served extensively in America: one battalion was captured at Cowpens, while another fought at Guilford Courthouse. Their record includes both determined service and defeat.',
       'We included Highland infantry to give Scotland’s regimental contribution a recognizable place in the army. Its combination of pace and force creates an opponent that pressures the defenders themselves, rather than merely absorbing tower fire.',
       'The current game has no separate charge burst. Strong melee damage is the abstraction used here; it is not a claim that every Scottish soldier fought in the same manner or possessed unusual physical strength.',
       'National Park Service · Crown Forces Soldiers',
       'https://www.nps.gov/guco/crownforcessoldiers.htm'
FROM enemy_type WHERE enemy_type_key = 'highlander';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Build firing coverage along the route instead of relying on infantry to stop these riders. They pass blocking troops, so short gaps between towers matter. Slowing effects and concentrated fire can extend the time available before they reach the exit.',
       'Light dragoons served as mobile cavalry in the Revolutionary War. At Cowpens, the British force included men of the 17th Light Dragoons and the British Legion’s mounted troops. The Legion combined cavalry and infantry rather than forming one uniform body of British regulars.',
       'We included light dragoons to make cavalry change the defensive problem. Their ability to pass infantry forces players to plan coverage along the road and gives mounted troops a role beyond being faster foot soldiers.',
       'Passing every blocking soldier is a deliberate game rule, not historical invulnerability. Real cavalry could be checked by terrain, fire and prepared infantry. The demonstration uses ordinary movement rather than an invented trampling attack.',
       'National Park Service · British Units at the Cowpens',
       'https://www.nps.gov/cowp/learn/historyculture/british-units-at-the-cowpens.htm'
FROM enemy_type WHERE enemy_type_key = 'light_dragoon';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'This fragile, quick opponent has high cover but can still be blocked and targeted normally. Direct fire avoids relying on melee damage. Check its exit cost before diverting fire from a more dangerous threat; it currently causes no loss of lives on escape.',
       'Espionage linked couriers, concealed messages and agents behind opposing lines. British courier Daniel Taylor was captured in 1777 carrying a message hidden in a small silver container. Such work depended on secrecy and information, not on fighting as a battlefield regiment.',
       'We included the spy to acknowledge the war beyond formal battles. A fragile infiltrator introduces a different target-priority decision and provides a place to tell the story of intelligence gathering.',
       'The visible road-travelling figure is a game abstraction. Disguise and sabotage are not active combat abilities here: spies do not become untargetable, damage towers or steal money. Their historical importance was much greater than a health bar can show.',
       'George Washington’s Mount Vernon · Spy Techniques',
       'https://www.mountvernon.org/george-washington/the-revolutionary-war/spying-and-espionage/spy-techniques-of-the-revolutionary-war'
FROM enemy_type WHERE enemy_type_key = 'spy';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Use the slow approach to deliver repeated hits. These tough assault troops can punish unsupported infantry once they reach it. Their discipline makes morale disruption less reliable, so keep enough damage focused on the road they must cross.',
       'Grenadier companies were selected elite infantry. British commanders combined grenadiers and light infantry for the expedition to Concord in April 1775. Their role in that operation was infantry combat; the name does not mean that every grenadier continually threw grenades.',
       'We included grenadiers as the deliberate, heavy assault opponent. They reward preparation and sustained fire while making the cost of an unsupported blocking line visible.',
       'Large health reserves and slow movement make this role readable in play; they are not literal measurements of historical soldiers. This enemy has no grenade attack or separate steady-advance ability in the current game.',
       'National Park Service · The Embattled British Column',
       'https://www.nps.gov/articles/000/the-embattled-british-column-survival-against-the-odds-on-the-battle-road.htm'
FROM enemy_type WHERE enemy_type_key = 'grenadier';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Start damaging this slow, durable unit well before it reaches your defenders. Its heavy melee damage can overwhelm a blocking post. Concentrated fire exploits the long approach, but do not assume the crew will stop at a distance to bombard your towers.',
       'The Royal Artillery served the British war effort with trained gun crews. At Yorktown, cannon, howitzers and mortars had different tasks: direct fire, shell fire and high-angle bombardment. Moving and serving these weapons required people, equipment and coordinated labor.',
       'We included an artillery crew to represent the material weight of the Crown army. A slow, costly threat makes players consider sustained damage and defense in depth, while its history connects field combat to siege warfare.',
       'The current enemy behaves as a moving ground unit with close-combat damage. It does not fire cannon projectiles or bombard towers from range. Its artwork and historical role should not be mistaken for an implemented ranged attack.',
       'National Park Service · Revolutionary War Artillery',
       'https://www.nps.gov/york/learn/historyculture/revolutionary-war-artillery.htm'
FROM enemy_type WHERE enemy_type_key = 'royal_artillery';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Block this officer or defeat it early to interrupt its reserve signals. After an unopposed signal, two regulars arrive through the same road entrance; it can make two calls, adding at most four enemies. Dispatched reserves remain after the officer falls. Its high discipline reduces morale shock. Nearby enemies gain no command-aura bonus, and its defeat causes no special morale collapse.',
       'At Saratoga on October 7, 1777, Brigadier General Simon Fraser rode along the British lines trying to rally retreating troops. He was mortally wounded. Mounted command offered mobility and visibility, but also exposed officers to fire at decisive moments.',
       'We included a mounted officer to make leadership visible within the opposing army. Calling a finite reserve gives players a reason to engage a commander promptly and represents the organization of fresh or regrouped troops.',
       'This figure is a generic officer, not a portrait of Fraser. Reserve calls compress dispatching and regrouping into seconds; troops arrive from the road entrance, and defeated soldiers are never resurrected. Command-aura and death-shock bonuses remain inactive.',
       'National Park Service · Wilkinson Trail Audio Tour',
       'https://www.nps.gov/sara/learn/photosmultimedia/wilkinson-trail-audio-tour.htm'
FROM enemy_type WHERE enemy_type_key = 'mounted_officer';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Commit sustained damage early and keep the approach covered. These slow troops have exceptional health and punish a weak blocking line. Their discipline strongly resists artillery morale shock; do not expect disruption alone to stop them.',
       'The Brigade of Guards serving in America drew selected men from Britain’s three Foot Guards regiments. These household troops served overseas as field soldiers. A Guards contingent remained with Cornwallis at Yorktown in 1781, where the British army ultimately surrendered.',
       'We included the Guards as the roster’s strongest test of sustained defense. Their historical prestige supports a distinctive elite role, while their slow approach gives players time to recognize the threat and commit resources.',
       'Their large health pool and discipline are game balancing choices, not proof that elite soldiers were invulnerable. The unbreakable tag is not a separate immunity in the current game; the displayed discipline value is what reduces morale shock.',
       'National Park Service · British Units at Yorktown',
       'https://www.nps.gov/york/learn/historyculture/british-units-at-yorktown.htm'
FROM enemy_type WHERE enemy_type_key = 'foot_guards';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Concentrate sustained fire on the command group while infantry holds its approach. Nearby enemies recover morale continuously, so artillery disruption alone will not keep its escort shaken. Defeating the formation ends the rally effect. Its escape costs twenty lives.',
       'General William Howe commanded the British army in Boston when Washington fortified Dorchester Heights on the night of March 4, 1776. Howe planned an attack, but a storm prevented the immediate assault. He then decided to evacuate Boston; the British departed on March 17.',
       'The first major boss gives the Dorchester chapter a recognizable British command and tests whether players can focus on a leader while an accompanying column recovers its resolve.',
       'This encounter is explicitly a what-if: the planned assault on Dorchester Heights goes ahead. The command group and its large health pool represent an assault formation, not Howe personally surviving thousands of shots. The rally radius compresses communication and leadership into a readable game mechanic.',
       'National Park Service · Dorchester Heights',
       'https://www.nps.gov/places/dorchester-heights.htm'
FROM enemy_type WHERE enemy_type_key = 'howe_assault';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Spread defenders around the blocking position: this command group damages nearby troops and heroes together with each melee attack. Blocking also interrupts its reserve signal. If left free, it can make three calls of three regulars through the same entrance, adding at most nine enemies. Dispatched troops remain after the group falls. Its escape costs twenty lives.',
       'Lieutenant Colonel John Hill commanded the British 9th Regiment of Foot during the pursuit from Fort Ticonderoga in July 1777. At Fort Ann on July 8, Hill and the regiment fought American troops led by Colonel Pierse Long in dense woodland. The Americans withdrew toward Fort Edward; Hill later surrendered with Burgoyne at Saratoga.',
       'Hill connects the Fort Ann boss directly to the commander and regiment that fought there. A compact assault formation and finite reserve make this encounter about defender placement and timely engagement as well as sustained damage.',
       'The figure represents Hill with a regimental command group. Its health and attacks stand for the pressure of several soldiers, not exceptional personal strength. The exact reserve-call schedule is a game adaptation of committing fresh or regrouped troops, not a documented sequence at Fort Ann. No dead soldier returns to life.',
       'American Battlefield Trust · John Hill',
       'https://www.battlefields.org/learn/biographies/john-hill'
FROM enemy_type WHERE enemy_type_key = 'hill_rearguard';

INSERT INTO enemy_encyclopedia (enemy_type_id, strategy_text, historical_description, inclusion_reason, adaptation_text, source_title, source_url)
SELECT id, 'Engage the siege detachment in melee to stop its bombardment. While unblocked it aims at a defender, then fires on that fixed location after a two-second warning. Move heroes out of the marked area and avoid crowding the gun with unsupported troops. Sustained fire must wear down the heavy formation before it reaches the exit, where it costs twenty lives.',
       'Sir Henry Clinton commanded the British army besieging Charleston in 1780. British and Hessian troops built successive siege parallels across Charleston Neck, bringing guns closer to the American defenses. Bombardment began on April 13, and the siege ended with the American garrison surrendering in May.',
       'The Charleston boss turns the siege itself into a final military threat: a heavy gun detachment under Clinton''s command. Its bombardment asks players to move exposed defenders and keep a blocking force alive long enough for towers to finish the engagement.',
       'The moving siege train condenses weeks of engineering, transport and bombardment into one battle unit. Its health represents crews, equipment and protection, not Clinton''s body. Fixed siege batteries did not repeatedly roll down a road to duel individual defenders; that movement and the warning marker are deliberate gameplay abstractions.',
       'National Park Service · Siege of Charleston 1780',
       'https://www.nps.gov/articles/siege-of-charleston-1780.htm'
FROM enemy_type WHERE enemy_type_key = 'clinton_siege';
