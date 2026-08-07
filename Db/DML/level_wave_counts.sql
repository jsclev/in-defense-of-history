-- Designer-fixed wave counts for the 15 Main-campaign levels, mirroring the
-- first 15 levels of the Kingdom Rush Frontiers main campaign (campaign-mode
-- wave counts from the KR wiki, matched by campaign position). The simulator
-- reads num_waves and generates compositions; it never permutes the count.
UPDATE level_info SET num_waves = 6  WHERE level_name = 'Lexington and Concord';  -- 1  Hammerhold
UPDATE level_info SET num_waves = 8  WHERE level_name = 'Bunker Hill';            -- 2  Sandhawk Hamlet
UPDATE level_info SET num_waves = 10 WHERE level_name = 'Great Bridge';           -- 3  Sape Oasis
UPDATE level_info SET num_waves = 14 WHERE level_name = 'Moore''s Creek Bridge';  -- 4  Dunes of Despair
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Dorchester Heights';     -- 5  Buccaneer's Den
UPDATE level_info SET num_waves = 14 WHERE level_name = 'Sullivan''s Island';     -- 6  Nazeru's Gates
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Long Island';            -- 7  Crimson Valley
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Trenton';                -- 8  Snapvine Bridge
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Princeton';              -- 9  Lost Jungle
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Fort Ann';               -- 10 Ma'qwa Urqu
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Saratoga';               -- 11 Temple of Saqra
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Kettle Creek';           -- 12 The Underpass
UPDATE level_info SET num_waves = 15 WHERE level_name = 'New Haven';              -- 13 Beresad's Lair
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Savannah';               -- 14 The Dark Descent
UPDATE level_info SET num_waves = 15 WHERE level_name = 'Charleston';             -- 15 Emberspike Depths
