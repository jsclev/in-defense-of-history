INSERT INTO enemy_type (
    id, enemy_type_key, enemy_type_name, enemy_type_description, image_name, max_hp, speed, cover, discipline, hardiness, damage_min, damage_max, bounty, lives_cost, break_band_lo, break_band_hi, traits, morale_speed_threshold, morale_attack_threshold, morale_speed_multiplier, morale_attack_multiplier
) VALUES
('c972308d-7313-45ae-8cb4-04d2d5b78046', 'loyalist_militia', 'Loyalist Militia', 'Lightly trained troops with fragile morale and modest staying power.', 'loyalist_militia', 50.0, 60.0, 0.35, 0.2, 0.3, 2.0, 4.0, 8, 1, 0.45, 0.65, '[{"type":"wavering"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('369e4cb5-38dc-4857-8701-e6c1320c52bc', 'regimental_drummer', 'Regimental Drummer', 'A military musician who advances with the column but deals no melee damage.', 'regimental_drummer', 60.0, 60.0, 0.1, 0.55, 0.6, 0.0, 0.0, 20, 1, 0.35, 0.5, '[{"type":"rallyBeat","radius":90,"moralePerSecond":6}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('86175b06-0f08-4407-bac0-0aa95cde3f52', 'redcoat_regular', 'Redcoat Regular', 'Disciplined line infantry with balanced speed and staying power.', 'redcoat_regular', 90.0, 60.0, 0.05, 0.6, 0.7, 4.0, 7.0, 15, 1, 0.3, 0.45, '[]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('59cffa58-a230-4b83-b6e4-00cd84175ad1', 'light_infantry', 'Light Infantry', 'Fast skirmishers whose cover reduces incoming melee and explosive damage.', 'light_infantry', 70.0, 85.0, 0.45, 0.5, 0.6, 3.0, 6.0, 18, 1, 0.3, 0.45, '[{"type":"skirmish"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('e8e182d1-c209-4cdd-8f8d-8d95de3fe167', 'hessian_jager', 'Hessian Jäger', 'Accurate riflemen combining strong cover with hard-hitting attacks.', 'hessian_jager', 65.0, 85.0, 0.55, 0.45, 0.55, 6.0, 9.0, 22, 1, 0.3, 0.45, '[{"type":"mercenary"},{"type":"marksman"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('7c014dae-5896-4b32-896e-f95555833e1e', 'hessian_fusilier', 'Hessian Fusilier', 'Sturdy German infantry that holds formation under pressure.', 'hessian_fusilier', 110.0, 60.0, 0.05, 0.7, 0.65, 5.0, 8.0, 20, 1, 0.28, 0.4, '[{"type":"mercenary"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('b3e0cd5e-0128-46eb-a2c3-fe193d728228', 'native_warrior', 'Native Warrior', 'Swift woodland fighters who use cover to close the distance.', 'native_warrior', 60.0, 120.0, 0.6, 0.35, 0.75, 5.0, 8.0, 20, 1, 0.35, 0.55, '[{"type":"skirmish"},{"type":"tag","name":"ambush"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('414fd1af-c633-4780-b513-b70f13018cd3', 'highlander', 'Highlander', 'Fast, hard-hitting infantry with the resolve to press the attack.', 'highlander', 130.0, 85.0, 0.1, 0.75, 0.75, 8.0, 12.0, 30, 1, 0.25, 0.35, '[{"type":"highlandCharge"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('ef3a782a-58db-4ac8-b372-0745a27669b0', 'light_dragoon', 'Light Dragoon', 'Fast cavalry that rides past blocking troops.', 'light_dragoon', 140.0, 120.0, 0.15, 0.65, 0.6, 7.0, 11.0, 35, 1, 0.28, 0.4, '[{"type":"rideDown"},{"type":"falter"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('9ba1961d-cb79-4e0b-a6cd-6806d115813e', 'spy', 'Spy', 'A lightly armed infiltrator with high cover and little staying power.', 'spy', 45.0, 85.0, 0.7, 0.4, 0.5, 1.0, 2.0, 25, 0, 0.35, 0.5, '[{"type":"disguised"},{"type":"saboteur"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('5392e3d1-c1c6-40d0-b54d-2be8aa4dc277', 'grenadier', 'Grenadier', 'Slow, tough assault infantry with powerful close-range attacks.', 'grenadier', 240.0, 40.0, 0.0, 0.85, 0.75, 10.0, 15.0, 45, 2, 0.22, 0.3, '[{"type":"steadyAdvance"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('f00dd278-0466-4bd5-b454-9c5a3dc964ec', 'royal_artillery', 'Royal Artillery', 'Slow-moving gun crews that trade speed for heavy damage.', 'royal_artillery', 300.0, 25.0, 0.1, 0.7, 0.65, 15.0, 25.0, 60, 2, 0.25, 0.35, '[{"type":"bombard"},{"type":"crewed"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('48cf0732-a2a6-4271-b631-232a70c263ce', 'mounted_officer', 'Mounted Officer', 'A durable mounted commander with strong personal discipline.', 'mounted_officer', 180.0, 85.0, 0.1, 0.9, 0.7, 6.0, 10.0, 50, 2, 0.2, 0.3, '[{"type":"commandAura","radius":120,"disciplineBonus":0.25,"deathShock":25}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666),
('8dc553a0-c688-470d-ae0a-f2a0cfa04f45', 'foot_guards', 'Foot Guards', 'Elite infantry with exceptional toughness and strong resistance to morale shock.', 'foot_guards', 500.0, 40.0, 0.0, 1.0, 0.85, 12.0, 20.0, 75, 3, 0.15, 0.25, '[{"type":"steadyAdvance"},{"type":"tag","name":"unbreakable"}]', 0.4, 0.4, 0.6666666666666666, 0.6666666666666666);

-- Three-page enemy encyclopedia. Historical sources checked 2026-09-22.
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
SELECT id, 'Prepare coverage before these fast enemies arrive. Blocking troops can buy time, but their cover reduces melee damage. Direct shots help remove them while they are held. The current game has no hidden ambush or invisibility ability for this unit.',
       'Native nations pursued their own interests, including the survival of their communities and homelands. The Revolution divided the Haudenosaunee Confederacy: many Oneida supported the Americans, while other Six Nations forces fought alongside Britain. Alliances were neither uniform nor permanent, and Native communities suffered devastating losses.',
       'We included this type to acknowledge Native participation in the conflict and the importance of woodland warfare. In opposing waves it represents British-allied fighters only. It must not suggest that all Indigenous people were enemies of the American cause or belonged to one interchangeable culture.',
       'The roster’s broad label and shared artwork compress distinct nations and experiences. Speed and cover are choices for a mobile game role, not inherent ethnic traits. This entry does not assign the sprite to a specific nation without evidence.',
       'National Park Service · The Oneida in the American Revolution',
       'https://www.nps.gov/articles/the-oneida-nation-in-the-american-revolution.htm'
FROM enemy_type WHERE enemy_type_key = 'native_warrior';

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
SELECT id, 'This is currently a quick, durable combatant. Unlike the light dragoon, it can be held by infantry. Keep defenders supported and concentrate fire; its high discipline reduces morale shock. Nearby enemies currently gain no command bonus, and its defeat causes no special morale collapse.',
       'At Saratoga on October 7, 1777, Brigadier General Simon Fraser rode along the British lines trying to rally retreating troops. He was mortally wounded. Mounted command offered mobility and visibility, but also exposed officers to fire at decisive moments.',
       'We included a mounted officer to make leadership visible within the opposing army. The intended command role connects a recognizable figure to the cohesion of a formation, rather than treating every enemy as an isolated weapon.',
       'This figure is a generic officer, not a portrait of Fraser. Command and death-shock bonuses are not active in the current game. A numerical aura would simplify the difficult work of communication and leadership.',
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
