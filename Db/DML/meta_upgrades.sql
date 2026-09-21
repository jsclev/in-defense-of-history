-- Historical practices inspire the mechanics; all numerical effects are game tuning.
BEGIN TRANSACTION;
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('marksmanship', 'Marksmanship', 'Marksmen', 1);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('rangeEstimation', 'marksmanship', 1, 1, NULL, 'Range Estimation', 'Ranged towers gain 15% range. Cover a second approach from the same position.', 'meta_range_estimation', 'Long rifles traded a slower, more involved loading process for effective aimed fire at greater distances than smoothbore muskets. Judging distance and selecting a firing position made that advantage useful. This upgrade represents that practice; its range bonus is game tuning.', 'NPS · Muskets and Rifles', 'https://www.nps.gov/cowp/learn/education/unit-4-the-war-for-american-independence.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('rangeEstimation', 'rangeMultiplier', 1.15);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('cartridgeDrill', 'marksmanship', 2, 2, 'rangeEstimation', 'Loading Drill', 'Ranged towers reload in 15% less time.', 'meta_cartridge_drill', 'Loading and firing muzzle-loading weapons required a practiced sequence of movements. Muskets and rifles used different loading methods, but both rewarded familiarity and discipline. The reduced interval represents proficiency across the ranged branch, not a claim that every rifle used musket cartridges.', 'NPS · Muskets and Rifles', 'https://www.nps.gov/cowp/learn/education/unit-4-the-war-for-american-independence.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('cartridgeDrill', 'reloadMultiplier', 0.85);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('crossfire', 'marksmanship', 3, 3, 'cartridgeDrill', 'Combined Arms', 'Ranged shots deal 20% more damage to enemies blocked by soldiers when fired.', 'meta_combined_arms', 'At Cowpens in January 1781, Morgan assigned different tasks to sharpshooters, militia, Continental infantry and cavalry. Their cooperation allowed each force to support the others. A bonus against blocked enemies is a game abstraction of mutual support, rather than a literal instruction to fire into friendly troops.', 'NPS · The Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('crossfire', 'damageMultiplier', 1.2);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('twoGoodVolleys', 'marksmanship', 4, 4, 'crossfire', 'Two Good Volleys', 'Ranged towers begin with two shots dealing 30% extra damage. Eight seconds without a target prepares another pair; changing targets or upgrading does not refill them.', 'meta_two_good_volleys', 'Morgan asked the militia at Cowpens to deliver two volleys before withdrawing behind the Continental line. The later Continental withdrawal resulted from a misunderstood order and was not wholly preplanned. Here, a prepared opening burst adapts the militia tactic to towers; units never retreat automatically.', 'NPS · The Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('twoGoodVolleys', 'damageMultiplier', 1.3),
    ('twoGoodVolleys', 'shotCount', 2),
    ('twoGoodVolleys', 'preparationSeconds', 8);
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('infantry', 'Infantry', 'Infantry', 2);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('campaignVeterans', 'infantry', 1, 1, NULL, 'Campaign Veterans', 'Barracks soldiers and reinforcements gain 25% maximum health.', 'meta_campaign_veterans', 'Morgan placed Continental infantry behind his militia at Cowpens. These experienced troops maintained order even when a maneuver was misunderstood, then faced about and fought effectively. Extra health represents endurance and cohesion, not historical invulnerability.', 'NPS · The Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('campaignVeterans', 'healthMultiplier', 1.25);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('reliefCompanies', 'infantry', 2, 2, 'campaignVeterans', 'Relief Companies', 'Replacement barracks soldiers arrive in 30% less time.', 'meta_relief_companies', 'The Continental Army developed specialized support and garrison organizations as the war continued. Men assigned to depot and garrison duties could free field troops for other service. Faster replacements represent organized manpower and relief; fallen soldiers are replaced, not brought back to life.', 'U.S. Army · The Continental Army, Chapter 6', 'https://webdoc.sub.gwdg.de/ebook/p/2005/CMH_2/www.army.mil/cmh-pg/books/revwar/contarmy/ca-06.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('reliefCompanies', 'respawnMultiplier', 0.7);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('fieldDressings', 'infantry', 3, 3, 'reliefCompanies', 'Field Dressings', 'Barracks soldiers and reinforcements recover health twice as quickly while disengaged.', 'meta_field_dressings', 'After Cowpens, Morgan arranged care for wounded soldiers of both sides. Accounts describe surgeons dressing wounds and patients being moved to nearby houses and a makeshift hospital. Disengaged recovery compresses care and regrouping into game time; serious historical wounds often required months of recovery.', 'NPS · After the Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/forty-eight-hours-following-the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('fieldDressings', 'healingMultiplier', 2);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('bayonetCounterstroke', 'infantry', 4, 4, 'fieldDressings', 'Bayonet Counterstroke', 'Barracks soldiers and reinforcements deal 25% more melee damage against enemies below half morale.', 'meta_bayonet_counterstroke', 'At Cowpens, the Continental line faced about and fired at close range as the British advanced in disorder. A fierce bayonet counterattack helped break the charge. This doctrine rewards infantry that exploits an enemy formation already disrupted by fire.', 'NPS · The Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('bayonetCounterstroke', 'damageMultiplier', 1.25),
    ('bayonetCounterstroke', 'moraleThreshold', 0.5);
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('artillery', 'Artillery', 'Artillery', 3);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('gunCarriages', 'artillery', 1, 1, NULL, 'Gun Carriages', 'Artillery turns 50% faster, spending less time tracking its next target.', 'meta_gun_carriages', 'Cannon depended on timber carriages, drag ropes and the work of their detachments. Moving and laying the piece was part of serving the gun. Faster turning abstracts better handling and maintained equipment, not a modern powered turret.', 'U.S. Army · History of Field Artillery', 'https://cgsc.contentdm.oclc.org/digital/api/collection/p15766coll2/id/77/download');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('gunCarriages', 'turnMultiplier', 1.5);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('thunderousReport', 'artillery', 2, 2, 'gunCarriages', 'Thunderous Report', 'Artillery inflicts 30% more morale damage. Disrupt a column before the infantry counterstroke.', 'meta_thunderous_report', 'Explosive shells affected more than the point of impact. The Army history notes that their noise and flash unsettled men and horses. This upgrade emphasizes bombardment as a means of disrupting cohesion, with the numerical morale effect set for the game.', 'U.S. Army · History of Field Artillery', 'https://cgsc.contentdm.oclc.org/digital/api/collection/p15766coll2/id/77/download');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('thunderousReport', 'moraleMultiplier', 1.3);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('ammunitionWagons', 'artillery', 3, 3, 'thunderousReport', 'Ammunition Wagons', 'Artillery reloads in 10% less time.', 'meta_ammunition_wagons', 'Only a small ammunition supply could be carried on a gun carriage. Most traveled in carts, tumbrels or wagons, while assistants passed ammunition to the gun crew. A steady supply supports sustained fire without changing the identity of shells, grapeshot or solid shot.', 'U.S. Army · History of Field Artillery', 'https://cgsc.contentdm.oclc.org/digital/api/collection/p15766coll2/id/77/download');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('ammunitionWagons', 'reloadMultiplier', 0.9);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('batteryDoctrine', 'artillery', 4, 4, 'ammunitionWagons', 'Battery Doctrine', 'Enfilading Fire: solid shot deals 25% extra damage after its first enemy. Close Grape: grapeshot deals 25% extra damage within half its firing reach. Plunging Shells: shells ignore 35% of remaining cover protection.', 'meta_battery_doctrine', 'Different ammunition called for different employment. Solid shot was useful against columns and flanked infantry lines; grapeshot and canister scattered smaller projectiles against troops; high-curving explosive shells reached fortified positions. Enfilading fire means firing along an enemy formation. Each branch receives its own game adaptation rather than a shared explosive-radius bonus.', 'U.S. Army · History of Field Artillery', 'https://cgsc.contentdm.oclc.org/digital/api/collection/p15766coll2/id/77/download');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('batteryDoctrine', 'secondaryHitMultiplier', 1.25),
    ('batteryDoctrine', 'closeRangeMultiplier', 1.25),
    ('batteryDoctrine', 'closeRangeFraction', 0.5),
    ('batteryDoctrine', 'coverPierceFraction', 0.35);
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('engineering', 'Engineering', 'Engineers', 4);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('forwardWorks', 'engineering', 1, 1, NULL, 'Forward Works', 'Engineers and sappers gain 20% placement range. Abatis beds are 20% longer and wider.', 'meta_forward_works', 'Kosciuszko selected and fortified ground at Bemis Heights so that works on the heights protected the road and river defenses below. The position used the landscape and mutual support. Greater placement reach represents the ability to establish useful forward works.', 'NPS · The Defenses of Bemis Heights', 'https://www.nps.gov/places/tour-stop-3-bemus-heights.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('forwardWorks', 'rangeMultiplier', 1.2),
    ('forwardWorks', 'obstacleSizeMultiplier', 1.2);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('preparedFireLanes', 'engineering', 2, 2, 'forwardWorks', 'Prepared Fire Lanes', 'Ranged and artillery hits deal 15% more damage to enemies inside friendly abatis at impact. Overlapping beds grant the bonus once.', 'meta_prepared_fire_lanes', 'The works and batteries at Bemis Heights formed an interlocking defense that restricted safe approaches. Obstacles and supporting fire work together in this doctrine. The abatis damage bonus is a game abstraction of preparing and covering an approach, not a claim that branches themselves increased bullet power.', 'NPS · The Defenses of Bemis Heights', 'https://www.nps.gov/places/tour-stop-3-bemus-heights.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('preparedFireLanes', 'damageMultiplier', 1.15);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('workingParties', 'engineering', 3, 3, 'preparedFireLanes', 'Working Parties', 'Sappers prepare replacement charges in 30% less time. Their first charge remains ready to place.', 'meta_working_parties', 'Before opening their siege lines at Yorktown, allied troops prepared gabions, fascines and other materials under their engineers. Organized working parties made complex operations possible. Here the principle speeds preparation of replacement charges; it does not change the fuse or the automatic detonation rule.', 'NPS · Siege of Yorktown Chronology', 'https://www.nps.gov/york/learn/historyculture/siegetimeline.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('workingParties', 'preparationMultiplier', 0.7);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('powderWorks', 'engineering', 4, 4, 'workingParties', 'Powder Works', 'Demolition charges deal 20% more damage and 30% more morale damage.', 'meta_powder_works', 'Congress and the Pennsylvania Committee of Safety funded powder and gun works at French Creek in 1776 to address severe shortages. Domestic production supported the army even though this particular complex suffered an explosion and later destruction. The upgrade represents dependable ordnance supply; its blast and morale effects are game abstractions.', 'NPS · Continental Powder Works', 'https://www.nps.gov/articles/000/gunpowder-and-shot-researching-the-continental-powder-works-at-french-creek.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('powderWorks', 'damageMultiplier', 1.2),
    ('powderWorks', 'moraleMultiplier', 1.3);
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('supply', 'Supply', 'Supply', 5);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('localSuppliers', 'supply', 1, 1, NULL, 'Local Suppliers', 'Supply posts cost 20% less to build and advance through tower tiers.', 'meta_local_suppliers', 'Greene expanded procurement, filled administrative vacancies and sought supplies beyond the army’s immediate surroundings. Local agents and broader purchasing networks helped address shortages. Lower supply-post prices represent this organization rather than free material or a larger starting treasury.', 'U.S. Army Quartermaster Museum · Nathanael Greene', 'https://qmmuseum.army.mil/research/history-heritage/history/Nathanael-Green-and-the-Supply-of-the-Continental-Army.html');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('localSuppliers', 'priceMultiplier', 0.8);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('supplyConvoys', 'supply', 2, 2, 'localSuppliers', 'Supply Convoys', 'Income-producing supply posts deliver 25% more gold each wave, rounded down.', 'meta_supply_convoys', 'Stores were only useful if they reached the army. Greene worked to obtain horses, wagons and boats and improved roads and bridges for transportation. Regular game income represents delivered provisions and equipment, with gold serving as the shared resource abstraction.', 'U.S. Army Quartermaster Museum · Nathanael Greene', 'https://qmmuseum.army.mil/research/history-heritage/history/Nathanael-Green-and-the-Supply-of-the-Continental-Army.html');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('supplyConvoys', 'incomeMultiplier', 1.25);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('forwardMagazines', 'supply', 3, 3, 'supplyConvoys', 'Forward Magazines', 'Every supply tower gains a service area. Tower tier upgrades inside it cost 15% less. A post cannot discount itself; overlapping posts do not stack. Ability ranks keep their normal prices.', 'meta_forward_magazines', 'Greene developed a network of grain depots and used smaller magazines to support an army whose theater of operations could shift. Organized transport connected stocks with the troops that needed them. A nearby upgrade discount translates access to supplies into a placement decision; the radius is a game abstraction.', 'U.S. Army Quartermaster Museum · Nathanael Greene', 'https://qmmuseum.army.mil/research/history-heritage/history/Nathanael-Green-and-the-Supply-of-the-Continental-Army.html');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('forwardMagazines', 'priceMultiplier', 0.85),
    ('forwardMagazines', 'serviceRange', 300);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('fieldHospitals', 'supply', 4, 4, 'forwardMagazines', 'Field Hospitals', 'Supply posts that provide healing gain 25% service radius and heal 50% faster. Overlapping healing still uses the strongest post.', 'meta_field_hospitals', 'After Cowpens, wounded soldiers received attention from surgeons and were moved to treatment sites away from the battlefield, including a makeshift hospital in a tavern. Better coverage represents an organized chain of care. Healing is compressed for play and does not recreate the speed or limits of eighteenth-century medicine.', 'NPS · After the Battle of Cowpens', 'https://www.nps.gov/cowp/learn/historyculture/forty-eight-hours-following-the-battle-of-cowpens.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('fieldHospitals', 'healingMultiplier', 1.5),
    ('fieldHospitals', 'rangeMultiplier', 1.25);
INSERT INTO meta_upgrade_track (track_key, title, short_title, display_order) VALUES ('command', 'Command', 'Command', 6);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('artificerCorps', 'command', 1, 1, NULL, 'Artificer Corps', 'Building any tower costs 10% less gold. Discounts combine before rounding up.', 'meta_artificer_corps', 'Flower’s artillery artificers maintained weapons and military equipment. Baldwin’s work crews built works, maintained wheeled vehicles and repaired roads, becoming a permanent regiment in 1779. Construction savings represent skilled labor and maintenance, not interchangeable industrial parts.', 'U.S. Army · The Continental Army, Chapter 6', 'https://webdoc.sub.gwdg.de/ebook/p/2005/CMH_2/www.army.mil/cmh-pg/books/revwar/contarmy/ca-06.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('artificerCorps', 'priceMultiplier', 0.9);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('modelCompany', 'command', 2, 2, 'artificerCorps', 'Model Company', 'After a tower family buys tier 2 or 3, later purchases of that same tier in that family cost 15% less for the battle. Specializations and ability ranks are excluded.', 'meta_model_company', 'Steuben used about 120 selected men as a model company to demonstrate common drills at Valley Forge. Lessons spread through brigade, regimental and company officers. This upgrade turns that diffusion of training into a choice between developing one position and extending a proven practice across several towers.', 'NPS · Steuben at Valley Forge', 'https://www.nps.gov/vafo/learn/historyculture/vonsteuben.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('modelCompany', 'priceMultiplier', 0.85);

INSERT INTO meta_upgrade (upgrade_key, track_key, display_order, star_cost, prerequisite_key, title, description, icon_name, historical_information, source_title, source_url)
VALUES ('frenchContracts', 'command', 3, 3, 'modelCompany', 'French Contracts', 'The first level-four specialization purchased in each battle costs 25% less. The offer is shared by every tower family and is consumed only by a successful purchase.', 'meta_french_contracts', 'The Amphitrite arrived at Portsmouth in April 1777 carrying cannon, muskets, ammunition, tents and entrenching tools. Roderigue Hortalez and Company arranged supplies using French and Spanish funds before the formal French alliance. The one-time discount represents obtaining the equipment for an early specialized formation.', 'NPS · French Cannons and Saratoga', 'https://www.nps.gov/sara/learn/historyculture/cloak-dagger-french-cannons-and-the-battles-of-saratoga.htm');
INSERT INTO meta_upgrade_effect (upgrade_key, parameter, value) VALUES
    ('frenchContracts', 'priceMultiplier', 0.75);

-- Reinforcements have one cooldown; the stored-deployment upgrade is retired.
COMMIT;
