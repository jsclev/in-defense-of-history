-- Start at level 15: 17/23 upgrades learned (36 stars spent), fourteen
-- three-star Main campaign victories (42 stars earned), six stars available.
-- Startup refreshes these authored values with the rest of the bundled database.
INSERT INTO player_meta_upgrade_profile (profile_key) VALUES ('active'), ('level15');

WITH selections(upgrade_key, is_selected) AS (VALUES
    ('rangeEstimation', 1),
    ('cartridgeDrill', 1),
    ('crossfire', 1),
    ('twoGoodVolleys', 1),
    ('campaignVeterans', 1),
    ('reliefCompanies', 1),
    ('fieldDressings', 1),
    ('bayonetCounterstroke', 1),
    ('gunCarriages', 1),
    ('thunderousReport', 0),
    ('ammunitionWagons', 0),
    ('batteryDoctrine', 0),
    ('forwardWorks', 1),
    ('preparedFireLanes', 1),
    ('workingParties', 0),
    ('powderWorks', 0),
    ('localSuppliers', 1),
    ('supplyConvoys', 1),
    ('forwardMagazines', 1),
    ('fieldHospitals', 0),
    ('artificerCorps', 1),
    ('modelCompany', 1),
    ('frenchContracts', 1)
)
INSERT INTO player_meta_upgrade_selection (profile_key, upgrade_key, is_selected)
SELECT p.profile_key, s.upgrade_key, s.is_selected
FROM player_meta_upgrade_profile p CROSS JOIN selections s;

WITH completed AS (
    SELECT l.id FROM level_info l JOIN campaign c ON c.id = l.campaign_id
    WHERE c.campaign_name = 'Main' ORDER BY l.started_at, l.id LIMIT 14
)
INSERT INTO player_meta_upgrade_level_stars (profile_key, level_info_id, best_stars)
SELECT p.profile_key, l.id, CASE WHEN l.id IN (SELECT id FROM completed) THEN 3 ELSE 0 END
FROM player_meta_upgrade_profile p CROSS JOIN level_info l;
