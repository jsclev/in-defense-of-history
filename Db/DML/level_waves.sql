-- Wave table for every level.
-- Main campaign wave counts follow Kingdom Rush Frontiers stages 1-15:
-- stage 1 has 6 waves and stage 15 has 15, ramping monotonically between.
-- Mini-campaign levels ramp 8-12 across each campaign.
-- spawn_time is seconds from level start: first wave at 5s, then every 25s.

-- Main
-- Lexington and Concord: 6 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('58a4045d-cf16-428c-9f46-11d4e29e3305',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 1, 5.0),
('43e72179-bae1-462d-a08c-01f7b7454b3d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 2, 30.0),
('48543733-3925-440d-b783-0f4f2b92a8bd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 3, 55.0),
('5696e7f8-adae-4976-9da4-826644b94460',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 4, 80.0),
('7d24d7eb-0815-45b6-a516-461d610d6583',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 5, 105.0),
('77f4a7f9-c6e4-4afe-b786-43b66a23ac9d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Lexington and Concord' AND c.campaign_name = 'Main'),
 6, 130.0);

-- Bunker Hill: 7 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('9732d295-062a-402a-80cc-160a196f0d65',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 1, 5.0),
('458b2e63-f20f-4cf5-842e-eda67fed96cb',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 2, 30.0),
('cbe711aa-ef98-4034-859e-c772646c162e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 3, 55.0),
('93febc9a-6c81-433c-b121-4926b949daf3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 4, 80.0),
('f9f98f35-c658-4049-8f78-4e398e919189',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 5, 105.0),
('47256705-5f8e-42ce-a379-358d8d6ad7ca',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 6, 130.0),
('7e75486c-1daa-4393-945b-0fe36755d3cf',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bunker Hill' AND c.campaign_name = 'Main'),
 7, 155.0);

-- Great Bridge: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('09389ed8-5411-4695-9e6c-8aa7f7d05fd0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 1, 5.0),
('490eab73-3fe3-424d-82a4-05e8f26b5a99',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 2, 30.0),
('fb80cdea-6540-415d-9d3f-b1e360e61ab5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 3, 55.0),
('1a504f45-448a-440e-9b89-a22ae914d368',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 4, 80.0),
('289a1dbd-7f60-49b5-ad1b-900b68dbe2cc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 5, 105.0),
('f1d4997f-2803-4306-91ee-f0d08082057f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 6, 130.0),
('9e2514d5-4213-4a7f-94dc-8f1567fdab12',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 7, 155.0),
('08db1a02-b3a0-41ac-ab23-6aa7906124f5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Great Bridge' AND c.campaign_name = 'Main'),
 8, 180.0);

-- Moore's Creek Bridge: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('0641f3b1-18d0-43aa-968d-bf0a594c39c3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 1, 5.0),
('95f59d89-8566-446e-ba68-a09c74b12f9a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 2, 30.0),
('bb2ef025-88d8-43bb-9412-7b0cb7dc9e13',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 3, 55.0),
('f03ad0eb-7921-4dff-870a-b19f27a46bdd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 4, 80.0),
('1914b37d-748c-44df-8991-e008f0134224',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 5, 105.0),
('09ae399e-d6e8-4ccc-a884-588c05b73e31',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 6, 130.0),
('e53f71f3-412e-46e1-a85d-511568c850a6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 7, 155.0),
('28857f77-6769-40b2-a4df-577329ee11a0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Moore''s Creek Bridge' AND c.campaign_name = 'Main'),
 8, 180.0);

-- Dorchester Heights: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('7d36e60b-0a9c-4640-ab97-d45d1652593c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 1, 5.0),
('523c7569-c05c-4b44-b247-50134c90a57f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 2, 30.0),
('92743788-e0b2-49b8-94ad-5ab1b0c2297d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 3, 55.0),
('6ce1bade-9567-483b-b0ee-1944d4fe779c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 4, 80.0),
('465a774d-28d4-4c69-a4d5-7c9c6540118f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 5, 105.0),
('7d483edb-09d1-48dd-a574-ff189f606cdf',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 6, 130.0),
('ad91ef30-b91b-40b8-8094-dc66798854f2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 7, 155.0),
('a16e084a-a027-4871-b32d-9b804e87a6e3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 8, 180.0),
('67c96ac6-9d60-4c1e-89b8-1fa0f79536e0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Dorchester Heights' AND c.campaign_name = 'Main'),
 9, 205.0);

-- Sullivan's Island: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('d3979ea5-a0e8-4a7a-988d-184d4bdc9a88',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 1, 5.0),
('889f28f2-0dfb-48d0-b248-f8f6de5e4e32',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 2, 30.0),
('618d50e7-e978-4d79-9d27-a4415c0ae8d1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 3, 55.0),
('8fc03a8f-d6df-404c-a713-53629e264cfe',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 4, 80.0),
('270ffbd5-10a7-4d90-b266-2918db03ed0a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 5, 105.0),
('9832ff8e-d187-41a0-bb35-f9e2094d0593',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 6, 130.0),
('c972bc10-91b5-4e4d-bf76-4525935a603d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 7, 155.0),
('c1d6f185-545e-47b1-be98-8da0a2310744',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 8, 180.0),
('5fb7d945-224a-4b57-a5ae-cec8e8049089',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 9, 205.0),
('fcb71cc1-0f0e-4aa1-81f2-cd4b3511a4f0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Sullivan''s Island' AND c.campaign_name = 'Main'),
 10, 230.0);

-- Long Island: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('126dd11f-7d9e-40df-90bb-586612a4f79d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 1, 5.0),
('3ae9263a-76d8-4000-9054-7b54a5ebe319',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 2, 30.0),
('05dc6112-9170-4b9a-b603-eec4807348c6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 3, 55.0),
('b7bddb98-c3ad-40af-bcd9-5b885b300d9d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 4, 80.0),
('338d74c6-30e5-4791-9b65-2daa7fbeaa52',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 5, 105.0),
('53f9f9ee-09ca-4c29-906d-1667c13a1a10',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 6, 130.0),
('fccd5c6f-f88a-4d73-a000-e4f3c6508672',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 7, 155.0),
('9febc13b-740c-4c85-bf96-9a7699904582',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 8, 180.0),
('fd9befb5-2117-44d7-9ef6-ac47fb486400',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 9, 205.0),
('2c69a63f-7d2f-44da-b9d9-7a86b3f85875',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Long Island' AND c.campaign_name = 'Main'),
 10, 230.0);

-- Trenton: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('2c3de8d8-5d9b-4ebc-ab6f-709b19543881',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 1, 5.0),
('091bab78-c994-4f20-9e51-9abc3b9be607',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 2, 30.0),
('8a31e2a0-7ad1-4154-9ae8-02137d83ffbe',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 3, 55.0),
('b0fe9eba-6ec0-4ffb-a408-4151b546595f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 4, 80.0),
('8a9b4907-e77d-4bb6-a478-01a7e720f1e3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 5, 105.0),
('f201dd7b-1fbf-4165-a2ef-253f4a8c1314',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 6, 130.0),
('ed4fac5b-eefd-4be8-9fe1-35e5dfcc4d90',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 7, 155.0),
('f2c3acca-91c0-4b2a-a977-7517271c929d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 8, 180.0),
('6aaa8559-9c12-429a-a478-b76f223697f6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 9, 205.0),
('4c0f8393-0e24-4e85-b993-e3879fe457b3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 10, 230.0),
('7c052c06-118c-4908-9283-eccead8975af',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Trenton' AND c.campaign_name = 'Main'),
 11, 255.0);

-- Princeton: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('2049a11d-d41c-4bd9-97e4-8c3e2762efdf',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 1, 5.0),
('f0324350-154d-43bf-b45e-504590fcfeb1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 2, 30.0),
('6ac64f70-56b3-40ea-84d8-bcec3a135dc4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 3, 55.0),
('e1364ec0-a657-4d5a-987d-4a88e125d586',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 4, 80.0),
('74a6bef4-5cf4-49eb-913a-b277177153ef',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 5, 105.0),
('27c4a37f-cca6-40c6-9f35-eda64f9aa332',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 6, 130.0),
('ae64175c-60cd-4dbb-9f71-075d8913112f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 7, 155.0),
('7bc19110-5b86-4a32-b439-98de9fa264cd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 8, 180.0),
('69c806fa-7158-4564-9a07-3359867ab0d2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 9, 205.0),
('38918d3e-5817-4e27-8777-b6392860fad0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 10, 230.0),
('af14bf85-66db-4e8a-b1f9-c9dbcc03d51d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 11, 255.0),
('a4dabee0-ad81-4e72-8db7-03e922ff5b55',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Princeton' AND c.campaign_name = 'Main'),
 12, 280.0);

-- Fort Ann: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('c17b6c02-83c6-4987-8571-13cad7200389',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 1, 5.0),
('2dbec270-69e5-4bd6-b6fe-881a02d43728',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 2, 30.0),
('1368e9ff-ccba-418e-b8a6-783cd256cf4e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 3, 55.0),
('35078aca-309d-4407-a41b-7a63b1f8cd20',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 4, 80.0),
('06f52b41-cf3e-4c76-96a1-b659ede40584',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 5, 105.0),
('e4860988-12cb-4211-aac5-0d7eaf25b11c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 6, 130.0),
('6fe9659d-9175-4fe6-b875-4d9b711ec4f3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 7, 155.0),
('1dba2e42-8fe8-4dad-9c49-098e0f783ad5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 8, 180.0),
('0e87123a-0d35-437b-ada5-108ada6f9cd4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 9, 205.0),
('bd7df686-174a-4414-9054-b8329d458553',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 10, 230.0),
('6fcf47c7-143b-4b4f-8d1b-c9fd1c90b09d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 11, 255.0),
('6829ccd5-3933-4c4d-aa3e-3593a0728bc5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Ann' AND c.campaign_name = 'Main'),
 12, 280.0);

-- Saratoga: 13 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('620793df-d348-463a-bdb2-e167dabc8c3a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 1, 5.0),
('b4f999f4-7af8-478a-a4e9-0d67ac6c73e9',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 2, 30.0),
('d7a8d5b3-2507-496b-832c-ae9ba39565d0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 3, 55.0),
('44560c8e-4db0-43b4-a895-10760275a09e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 4, 80.0),
('d07a2e14-c08d-485c-be66-a41f85633aa5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 5, 105.0),
('be95356a-f320-41e9-b5b0-447621dec054',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 6, 130.0),
('dc83cb66-0bb9-45b4-a8bb-9001c9b4bb54',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 7, 155.0),
('709f802c-65c5-4a45-b9b7-da208ab85221',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 8, 180.0),
('6b4c2833-dd88-4e72-9021-9aeb06a2ee96',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 9, 205.0),
('e455500f-f903-4ce0-894a-96d106300007',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 10, 230.0),
('929dad00-c477-44b1-bde2-1cb40f8c97b4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 11, 255.0),
('22899a54-e635-4e59-910d-8b029c51cbba',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 12, 280.0),
('5fe8ee6a-483c-4032-aeb3-05d58e3035e2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Saratoga' AND c.campaign_name = 'Main'),
 13, 305.0);

-- Kettle Creek: 13 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('442fce88-33a0-4995-8617-bea9d6ef1df6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 1, 5.0),
('324123fc-4f61-4b8a-b4e7-a04079c4d5dd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 2, 30.0),
('1955bbf1-97fc-43e9-8e81-8cbe1c4707c0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 3, 55.0),
('e2adb93a-0d6f-411f-8622-9fdd4dcad2b5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 4, 80.0),
('31e83569-cc40-4f1b-9428-aeb5c64790af',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 5, 105.0),
('d9ad570c-5c1c-489a-a40f-cfe12c816881',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 6, 130.0),
('fce5b05f-781e-4d55-8bab-fbff5080e6ad',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 7, 155.0),
('f6c93b58-8df8-41be-bc72-61aa66060737',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 8, 180.0),
('2832b647-32e5-40c3-84d9-18715d6c555a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 9, 205.0),
('d21ae802-9252-4ccb-859f-39f9ef2e263e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 10, 230.0),
('8493fd0e-3b99-422a-977f-42f854346a34',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 11, 255.0),
('686f3fcd-e6a9-4a2f-b464-bb8d9f7dd118',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 12, 280.0),
('667b2c48-28d0-4b39-810e-b8c20f61603c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kettle Creek' AND c.campaign_name = 'Main'),
 13, 305.0);

-- New Haven: 14 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('cd1e620f-6577-4c8e-a4e2-cfc0a69cc83d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 1, 5.0),
('5c59bf3f-3699-4eaf-9976-d40c6685a27b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 2, 30.0),
('2be0b47b-9a5a-415c-a530-50021adf8378',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 3, 55.0),
('699e5dd9-7299-4951-bff2-2e309a0c7724',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 4, 80.0),
('6586567f-b575-4e69-afc9-979c9af8b646',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 5, 105.0),
('cf8bd5e8-0f10-440d-b6a2-932709a6def8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 6, 130.0),
('bc31358d-ce73-4bd3-aad4-7e837dadb986',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 7, 155.0),
('20564472-0a47-4953-9328-bb52fe477fdc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 8, 180.0),
('08606007-a519-4c8b-a454-1dacfb77c296',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 9, 205.0),
('85da6d64-5218-436b-aa1b-3c1496d43593',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 10, 230.0),
('42bc57e8-310a-4b91-9636-00ddfd2c9653',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 11, 255.0),
('93a0ad66-da98-4a9a-8edf-791297c000ac',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 12, 280.0),
('8cb9a6b6-c8e3-4002-8d4d-ef60ff6b5648',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 13, 305.0),
('890d6698-1439-4df6-b3eb-bc9a51123cc2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'New Haven' AND c.campaign_name = 'Main'),
 14, 330.0);

-- Savannah: 14 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('2c669a19-a98f-4707-b697-11b6bffe4399',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 1, 5.0),
('88328d88-6f83-4a96-92ea-52351e672680',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 2, 30.0),
('85d8279c-d1eb-4836-b1b0-b5b130b2055c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 3, 55.0),
('e94535ab-cef8-4532-9437-d1ee2b02eb34',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 4, 80.0),
('478f5deb-76ac-450c-8586-16e83dfcbbc1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 5, 105.0),
('3ae09f31-6d2b-437a-8f89-9598a38e3459',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 6, 130.0),
('670fdcf2-f082-40a0-b502-ed7a548d6555',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 7, 155.0),
('2b9af965-bf76-40e3-b87e-dfd1ff879fab',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 8, 180.0),
('131393c8-33a5-4eeb-91b0-eb868ab5b8db',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 9, 205.0),
('3c1748e3-0349-4df3-aeac-77ed9755a5e3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 10, 230.0),
('127a0865-7817-430f-9551-bc73c81ba903',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 11, 255.0),
('b0f8dc01-28d9-4c03-8992-0629093d6a02',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 12, 280.0),
('22bcb548-8013-4d8e-9572-f07ef2ca03b4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 13, 305.0),
('e7d4d4f0-7812-47a8-9b29-43258f8a2fe8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'Main'),
 14, 330.0);

-- Charleston: 15 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('38761627-d196-4f59-99a3-ba04053cbf53',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 1, 5.0),
('d4ebfc94-f22b-47de-9cbd-017298f0052b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 2, 30.0),
('fc75741d-549e-4a5d-ac9e-f15925c39fe9',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 3, 55.0),
('2387b68c-e9a6-43e3-8906-298d9609d5bd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 4, 80.0),
('72166c85-9712-4ca4-a5c9-bd37ca825bff',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 5, 105.0),
('735152a8-1510-4d92-ab83-6bcc2995b935',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 6, 130.0),
('e9fddec7-0dc7-4f4c-8a78-3f6e74a73be0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 7, 155.0),
('55e72cfe-6459-4958-ac58-00305dceea1a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 8, 180.0),
('ada3ab9c-fb05-4cbf-80ca-85cd1687c27f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 9, 205.0),
('0f6ed0b0-9170-4af5-ae82-7cbe5a7b9a6a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 10, 230.0),
('08774df9-658e-4fc4-8db3-8fba95ecd250',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 11, 255.0),
('dcd4486a-a166-47ab-b83f-574daf7db436',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 12, 280.0),
('a6caf5d0-62e0-456c-90b9-ab628f999f68',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 13, 305.0),
('a90083fe-1297-4ff3-9204-18807ea580ca',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 14, 330.0),
('48a44e78-6156-459b-83f7-d4ab52abe807',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'),
 15, 355.0);

-- The Fall of New York
-- Kip's Bay: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('44f52463-32ed-41ce-947d-19018be1fd04',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 1, 5.0),
('506830a2-1519-4db5-a771-1cd3e17d5fb0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 2, 30.0),
('412027b5-63de-4f73-af49-3a220fa5cda8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 3, 55.0),
('e929f52a-3a36-4b23-b732-154226bd5790',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 4, 80.0),
('220fc62a-f821-4e8d-a4aa-be29c19a7f78',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 5, 105.0),
('2a58d97e-30d1-4554-8e53-0d9f89bb4ef6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 6, 130.0),
('ad3f100f-0c7a-45fe-98d5-e83d97b1b6c7',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 7, 155.0),
('7e675b27-0b0b-4de1-8c7d-647f01324dd2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kip''s Bay' AND c.campaign_name = 'The Fall of New York'),
 8, 180.0);

-- Harlem Heights: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('410192f4-94b2-4875-b3a5-8811fc49a87e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 1, 5.0),
('5a3bf909-482c-4b02-bcfa-dabf898d9a3b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 2, 30.0),
('a706ca89-21a5-484a-a270-e5463c727445',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 3, 55.0),
('856715d7-d80a-45d4-9174-3afe149d628a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 4, 80.0),
('24f97233-4124-4eab-b358-7c6d5942e332',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 5, 105.0),
('cc146526-7bd6-4bd8-8adf-24279f89fd95',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 6, 130.0),
('0ea391d5-caf7-468c-bf72-295997de09f3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 7, 155.0),
('a45a5f88-cf5d-495e-9e0e-8789d71a0ce2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 8, 180.0),
('3745a0ea-484c-4764-a23e-8d45fc9d2235',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Harlem Heights' AND c.campaign_name = 'The Fall of New York'),
 9, 205.0);

-- Pell's Point: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('e01e0a9a-d6ef-4098-b32e-a4e71c04dba7',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 1, 5.0),
('247de1c3-746e-43f1-8d8d-baa9b5e5c0dd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 2, 30.0),
('cea78034-5b62-48a3-9c4c-4eeb88e47831',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 3, 55.0),
('83327df1-98bf-4684-a484-223b457e31bd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 4, 80.0),
('b3333a7d-bbef-4aaf-b11f-a28349741e04',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 5, 105.0),
('68c612f4-77d8-4c58-b384-8928a2f4baae',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 6, 130.0),
('fdd58f13-1ed1-4c1b-964f-40fcee488c09',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 7, 155.0),
('e18cac77-aa09-45b4-853f-ce22c481cae7',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 8, 180.0),
('3ff346c2-3181-43bc-9dae-bafd2d104e74',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 9, 205.0),
('2ecc66b9-8fbb-4f65-b441-c4684ae95896',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Pell''s Point' AND c.campaign_name = 'The Fall of New York'),
 10, 230.0);

-- White Plains: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('ece9cd36-93d2-48c1-9dc3-fe0db7acdc8d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 1, 5.0),
('e48d6889-dd2d-41c6-8f6b-1dfea3fec7c4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 2, 30.0),
('7b450e13-422b-489e-a113-d83e3334f673',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 3, 55.0),
('b8041cb7-8197-4f37-b39c-3a0b85af190f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 4, 80.0),
('4a237c06-7b0a-4267-a2f9-a83267c284b8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 5, 105.0),
('6c53f019-02d1-4082-b919-8629c45da8f2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 6, 130.0),
('74a68dfa-8289-44f9-8775-f8ed1a9e95f6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 7, 155.0),
('bb2e7868-429e-4e15-b5ef-9dbf5e1a93d3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 8, 180.0),
('7657bad4-1ab1-4d58-a702-9cf98b483a3d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 9, 205.0),
('8210461e-09c8-4aa5-8016-2c19d8e4586d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 10, 230.0),
('2e09e869-5d53-450a-bca8-f1f95604506f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Plains' AND c.campaign_name = 'The Fall of New York'),
 11, 255.0);

-- Fort Washington: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('eb24961a-483f-4d80-ae9f-672d84806693',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 1, 5.0),
('b00233b9-745a-46a8-84a6-2897d39572d6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 2, 30.0),
('83e96119-1ef4-4d52-b269-1f91f9b947fb',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 3, 55.0),
('2c277555-6082-4401-8e8a-c3cb55d6c802',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 4, 80.0),
('885838f2-364e-44bf-be0f-4dfc0361a12b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 5, 105.0),
('df323b4d-2f6d-4e75-8614-94c7894f22a7',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 6, 130.0),
('bf024d95-2aef-4d8e-b7d2-f549a018db3b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 7, 155.0),
('4382628a-38fb-4acc-833c-8528bea5bea3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 8, 180.0),
('6e2389e7-a1a9-444d-85d5-5826e09015d0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 9, 205.0),
('b7d6360e-2fae-4d6f-bb35-8d3ed7b35102',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 10, 230.0),
('6b1c8715-8ad6-41c9-aa6b-79946a24fd7a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 11, 255.0),
('e1cc6456-109e-4935-acbb-7004c25aa746',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Washington' AND c.campaign_name = 'The Fall of New York'),
 12, 280.0);

-- The French Alliance
-- Monmouth: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('81d56ddd-3169-48fc-b100-4ea71383e2ce',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 1, 5.0),
('b6b8090b-84a4-4488-88d8-98a3b2f6ac11',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 2, 30.0),
('1b15df92-c8e5-4d9a-9adb-51077cd200e4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 3, 55.0),
('543f65df-9b01-48f0-a9c2-40ef0b95f47c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 4, 80.0),
('c83244db-78b0-43f3-ac9e-9404059c0be1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 5, 105.0),
('9f407c19-d79d-49ad-ba31-812dc255f657',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 6, 130.0),
('3ce17652-108b-45ec-9fbe-ac0af38bd80d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 7, 155.0),
('35e08da8-2565-44ec-a43d-09a963054876',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Monmouth' AND c.campaign_name = 'The French Alliance'),
 8, 180.0);

-- Rhode Island: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('0a5e5836-0375-4012-b563-b9b6c504a105',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 1, 5.0),
('faef4c6e-ba43-44b2-aee5-7018b19026af',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 2, 30.0),
('b8aa7571-f953-4774-9e40-b0322658c8a4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 3, 55.0),
('8e271718-7fe1-4f3d-81b1-819e27ee4eed',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 4, 80.0),
('3ef0c005-7b8e-493a-81c6-1ff91a01f223',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 5, 105.0),
('d1bcc775-5ff4-4dea-8d85-91c50ebfa475',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 6, 130.0),
('d169d4ae-5842-43c8-88c5-48a32cd40e81',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 7, 155.0),
('3c6b891a-1966-470d-b462-90508b93572b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 8, 180.0),
('3286901f-496f-4bc5-8aa1-b7e912fb8bcb',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Rhode Island' AND c.campaign_name = 'The French Alliance'),
 9, 205.0);

-- Stony Point: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('30bd3b1c-9180-43b5-a606-574f1a1c9852',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 1, 5.0),
('8f90e3dd-082d-4025-945d-4187cde84263',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 2, 30.0),
('f9a1db36-2946-4039-ad61-b8627a5a7de8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 3, 55.0),
('ab76b92c-9c22-4483-ad36-1c5216d8d546',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 4, 80.0),
('1a20eeb0-72ae-445b-864a-0a14cc66addc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 5, 105.0),
('c65af715-b69f-4cf2-a338-2dead270c603',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 6, 130.0),
('7138f074-0ed4-441b-b355-b569a0079449',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 7, 155.0),
('e0667058-465e-4f6c-848a-1c4608a19870',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 8, 180.0),
('708fb15a-01aa-44eb-9760-23d53986caa4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 9, 205.0),
('e688b265-05ca-4328-9750-0a82f1637c3e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Stony Point' AND c.campaign_name = 'The French Alliance'),
 10, 230.0);

-- Savannah: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('396924a6-1e4c-4ecc-8463-286e5e90c6fc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 1, 5.0),
('55b30542-2e5c-4291-b2fc-79352f0fb274',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 2, 30.0),
('a774def1-9a30-4b55-85ed-b58591a23cd6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 3, 55.0),
('0c3b61ce-d435-4ca2-90e8-08ae0db8f869',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 4, 80.0),
('9d394406-8e3b-4323-8b9a-e3c985deb9eb',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 5, 105.0),
('8de16a86-208f-4993-9703-c4d47ffe7606',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 6, 130.0),
('2fd0c656-ea76-44ce-b044-395887244e68',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 7, 155.0),
('cf6db06c-1bbb-45af-bd62-f8f055a54c77',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 8, 180.0),
('c517b0e6-6064-422d-9eaa-5f4d7daa6d05',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 9, 205.0),
('e09986bc-c813-413d-8178-5cc634665faf',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 10, 230.0),
('9dcb7100-fe1c-4ee5-ad49-e78d5ec1b3c3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Savannah' AND c.campaign_name = 'The French Alliance'),
 11, 255.0);

-- Flamborough Head: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('285f8a39-3f19-48bb-a9b5-18c49af74b29',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 1, 5.0),
('10b54b0d-e9dc-4e45-ba3a-931a1ec9ad1e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 2, 30.0),
('fefb9975-e2da-48fc-b0e0-d8a33c8b6cb1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 3, 55.0),
('c4257ab8-6241-4399-9ad0-5a94e8d1d5ef',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 4, 80.0),
('57bbf326-5e3b-4ebd-a981-1f8803a39771',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 5, 105.0),
('31c64363-1703-481a-a4af-20fa5d65016d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 6, 130.0),
('21b4d0bf-95bf-4c05-9c79-2769d5284383',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 7, 155.0),
('0f16ec5f-028c-4bdb-9449-4373c4668774',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 8, 180.0),
('d24d7421-8e3a-4dd0-a488-812536296ed0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 9, 205.0),
('12e4f3c6-20a8-46a1-b295-23f90ceb862c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 10, 230.0),
('9e0c4a83-c666-4f73-a80d-7b6c0665bd4d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 11, 255.0),
('06ef2280-d079-4f13-9061-156da0e48191',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Flamborough Head' AND c.campaign_name = 'The French Alliance'),
 12, 280.0);

-- The Northern Campaign
-- Québec: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('22b76e50-6a55-4d91-b1ff-09dc8644f3e3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('a9dbd5b3-2638-4e06-ab14-2a2f04a81c53',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('7e0ccd71-0ea3-4224-94f8-e91b218e51b0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('e46e26e5-3f55-4ac1-a29c-c4dcf0b1c22e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('9e95d3dc-1d6e-45cf-a506-afc3b516b59d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('7620f1fa-54ae-42bb-add7-613ef31be515',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('fb52c50b-ce62-40bc-a9c1-3dacbb3b5489',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('98f292eb-ff6a-4fd9-a2f9-25976853ca10',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Québec' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0);

-- Valcour Island: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('32ade549-0ac9-4275-ad35-526bbb1ea6d5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('62aad92f-98ee-49b5-a09a-088fa96c2181',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('55632ab6-9e1f-4591-a1e3-23456113e393',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('1faa5e36-4589-47fc-a04a-06388a24af0c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('2ec0ad20-4965-4179-9fd9-828256c65fbc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('27c4ce67-a20e-4b52-aca7-e7f290eaf0a8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('49debdf1-af45-454b-901d-e455d0133b40',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('29f993de-8ef0-4fbf-8064-8584dc0e311b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0),
('be8e5458-a1c8-4d60-8bc2-b30cc78d2463',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Valcour Island' AND c.campaign_name = 'The Northern Campaign'),
 9, 205.0);

-- Hubbardton: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('fb789c91-6319-44e1-8f10-40c25ced2e36',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('597f4c9e-755c-4d1e-89a5-b97d9904548d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('ef4f9711-c593-4006-a337-0e40af760ce1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('d2978720-ca52-472b-9300-68c0f8360e6a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('e4906f11-8a4a-4fe8-b11d-73def5a7462e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('ce4db129-e6c8-45b8-9c5c-fd3e10b5f09a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('e296d33c-8c29-401b-a9c3-91d6148712fa',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('0218aeda-1725-4a6d-91a9-03532e51280c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0),
('a1931f5a-299c-4878-b0b7-06d2d6a88430',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 9, 205.0),
('ef07ea16-dfd8-4432-a90c-363de872b011',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Hubbardton' AND c.campaign_name = 'The Northern Campaign'),
 10, 230.0);

-- Fort Stanwix: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('0e400ea6-60de-42e7-ae11-9d8d67d9c303',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('13106470-7ba4-4cb7-91f9-88903d92b23f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('f94852fe-b5d3-4b10-9316-6f598dc7c74b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('b6d2b8d1-ebc3-4847-9046-69a840b333b2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('357061f7-e4d5-420d-814e-84507ba4c98c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('6f581332-18eb-480f-a738-cd5b66b8884c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('43e336fd-8e0b-4b05-ae0c-bfed8270ba81',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('2b253a98-5606-47ed-a2f1-645681304afd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0),
('f949b508-3380-4623-8e52-9ee48026e79a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 9, 205.0),
('81f08f96-c721-4504-bc53-f68e5f87eeb8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Fort Stanwix' AND c.campaign_name = 'The Northern Campaign'),
 10, 230.0);

-- Oriskany: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('0b913a6f-197d-47cd-8fa5-2b956e39e8d6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('d85836ef-eb51-4f27-ac13-ab59e2b7d881',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('0812523b-dc73-467c-b864-58797c3dca46',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('2f6b165c-44a7-45cc-97a2-3b9e4f34d60f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('026c399e-554c-44a8-b78c-a76999e8f781',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('996b03fa-0f5f-488b-87ab-e7497edb5490',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('8d88ee16-c853-4b6c-bafd-03d7d5d9de70',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('fbd81e63-7866-431d-b63b-0b63ce1ffa2c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0),
('70d1fb8e-55bc-4173-b00b-0ee6f9ce1ae5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 9, 205.0),
('f50b33ce-dc1c-426c-8ccd-1e5caaacd2ad',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 10, 230.0),
('0342a2cb-94c8-423e-b6e6-ba602cd9669a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Oriskany' AND c.campaign_name = 'The Northern Campaign'),
 11, 255.0);

-- Bennington: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('770b4b45-f8cf-4c7e-bdda-03b57cb35d54',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 1, 5.0),
('9cb5d36a-1dbc-4391-97b0-54e5f5e96380',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 2, 30.0),
('751b9624-dc4e-40fd-8577-6598164c7e07',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 3, 55.0),
('54473831-c73f-4e86-a096-18787e0934f3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 4, 80.0),
('211f488f-30b2-4aa4-bdfd-651e0bb7e915',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 5, 105.0),
('60c8f026-461f-4450-8991-abe3c2cdb4d8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 6, 130.0),
('31b06ae8-8aa4-4c0a-8b67-2609020ed2c2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 7, 155.0),
('c67f283e-7f2c-43c4-9c29-045e6d28e6be',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 8, 180.0),
('6bd0025e-aa76-4aa1-a265-514b4fc47416',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 9, 205.0),
('ab5d4f9d-cfc3-43ff-b5f7-326695fe1fc1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 10, 230.0),
('4c46b402-ef8e-4de7-8a63-e72db771ab1b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 11, 255.0),
('2ef21d07-33d1-4233-8efb-a8f77d690013',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Bennington' AND c.campaign_name = 'The Northern Campaign'),
 12, 280.0);

-- The Philadelphia Campaign
-- Cooch's Bridge: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('b7c9e1a9-fb10-4d10-8bbd-cc1e3f489159',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 1, 5.0),
('0979286a-f089-4b5c-b824-30a50050b9ff',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 2, 30.0),
('12290a33-60d5-4316-8893-eb1c3c6b1840',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 3, 55.0),
('53fd2b34-890c-434f-8215-0559448ed8d6',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 4, 80.0),
('9d0e2176-f203-4728-b834-ef343fd93372',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 5, 105.0),
('2f54a1ef-b332-425f-a57b-9f347fc8db76',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 6, 130.0),
('36a27d95-19fd-47af-bf1a-cf48c0a06397',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 7, 155.0),
('a0644a38-cefb-4585-ae16-3d0801e0ee15',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cooch''s Bridge' AND c.campaign_name = 'The Philadelphia Campaign'),
 8, 180.0);

-- Brandywine: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('1d84a5fa-da8d-4ebc-acad-6271314f7d8e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 1, 5.0),
('e0d60499-c5db-40e2-9b38-51849b5d2ed1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 2, 30.0),
('01ce0ba9-da8a-43c7-b77e-7f6ecc8e6759',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 3, 55.0),
('69eba23a-7741-4460-80cb-b248e0a3893e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 4, 80.0),
('68be29a6-75df-488e-be7d-9e0f0bb811f9',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 5, 105.0),
('675a019f-0c4e-496a-9a31-b7193f1aad7c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 6, 130.0),
('8868fdcb-be86-41e5-a043-8da087b206bc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 7, 155.0),
('58bec795-38e0-4b68-a8b3-fbf315aefaf2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 8, 180.0),
('8d608903-c513-4966-a38c-cadbc92b9a85',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Brandywine' AND c.campaign_name = 'The Philadelphia Campaign'),
 9, 205.0);

-- Paoli: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('0659e202-dfed-4d88-83ee-be1b9dc68bcd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 1, 5.0),
('33fbbd1e-df2e-41b4-b1b0-9471cee6eae0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 2, 30.0),
('4f9cc3ec-774f-4b57-a74c-6ab2e536fbb3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 3, 55.0),
('c05bba27-247e-488e-a219-88eac2a2cbb0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 4, 80.0),
('df8b74c1-f879-4a98-a3ce-e08b82bf813d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 5, 105.0),
('fc753843-b359-448c-acb5-fe6bfa188e04',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 6, 130.0),
('96f93775-3a47-48e0-b6d3-82e80c52fe1d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 7, 155.0),
('9c15768e-dd0d-4e98-a5c4-a1e36cc5f814',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 8, 180.0),
('5deb66b8-a9db-42d8-a1ca-cb9ecf1a19e4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 9, 205.0),
('350ec94a-02b8-451c-a1c2-89848a96361f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Paoli' AND c.campaign_name = 'The Philadelphia Campaign'),
 10, 230.0);

-- Germantown: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('f543c806-6e82-45f6-a358-ed110926aa25',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 1, 5.0),
('05bf3865-a193-47d1-8cd8-83d1ba6917b8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 2, 30.0),
('13ed153f-531e-4a0c-b8ad-ed3b59bfbde8',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 3, 55.0),
('43269e50-d8be-48c1-90ce-ac51bbbfbaae',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 4, 80.0),
('85c91f43-928b-4898-b0c0-611d3c9f6922',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 5, 105.0),
('f7cc91e1-0ceb-47a7-a4cc-0535a2b9a3c9',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 6, 130.0),
('357a183e-a563-4676-9d76-b1124d86cbb5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 7, 155.0),
('746fb1a9-cb6f-47d5-a66e-74bea9fa7b61',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 8, 180.0),
('52bfff3b-2930-4cae-90e8-4244258d6868',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 9, 205.0),
('ef771a53-e528-4269-bb83-19ae7b449188',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 10, 230.0),
('1379af06-8b52-4c75-8ab7-5d6e2fb4c618',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Germantown' AND c.campaign_name = 'The Philadelphia Campaign'),
 11, 255.0);

-- White Marsh: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('79583241-f14e-4609-9459-e75da74a112b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 1, 5.0),
('df3dee10-d2fe-4ac6-9832-a4e9f1f84c4e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 2, 30.0),
('f743d7b8-5632-4b1e-9460-c1ad99fa0d9a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 3, 55.0),
('f7867c64-4663-49c8-a85f-7f7908ab0b99',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 4, 80.0),
('9b3dde17-9fb3-4279-8f11-ac0f8e7bdc59',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 5, 105.0),
('effa0c5f-2ae5-4089-896e-23777602eedd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 6, 130.0),
('8ff2c7f5-b7cf-4a74-9b07-47efbace8406',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 7, 155.0),
('145ff2ef-a595-43ee-acd2-bbafb3065733',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 8, 180.0),
('2cb1dfcf-9bb5-4f32-b8fb-54f0956c6c7e',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 9, 205.0),
('cd21fc9f-d9ca-4a8d-849a-8a1cbcd36041',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 10, 230.0),
('33cdf863-83b2-4d98-b81f-c2c4f1e50806',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 11, 255.0),
('6be6dc00-62d4-486d-bae8-3a5128974c6a',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'White Marsh' AND c.campaign_name = 'The Philadelphia Campaign'),
 12, 280.0);

-- The Southern Campaign
-- Camden: 8 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('a169f862-a419-445c-b7c7-668c3b96a558',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 1, 5.0),
('3812469a-8d60-4935-8eca-dd920ea5d764',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 2, 30.0),
('2faa1203-49ed-4539-bc66-66e5436a0993',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 3, 55.0),
('44bc5f73-063c-4bec-8bcf-20f192c7bbfd',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 4, 80.0),
('69395dce-6445-46b6-a102-ed5b1e4e3bfc',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 5, 105.0),
('be2e4f78-7054-4384-b93b-84c1d6c3cb1b',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 6, 130.0),
('ea5f8f68-aadb-4e59-b666-9b3275075d34',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 7, 155.0),
('3ade7512-3d03-42fd-bf82-742b42c8fff4',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Camden' AND c.campaign_name = 'The Southern Campaign'),
 8, 180.0);

-- Kings Mountain: 9 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('ce1bbae5-8f0d-436f-97d0-672434bb80d2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 1, 5.0),
('7a9cabe5-fe77-4a92-be0c-e17e0b8ad967',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 2, 30.0),
('81eead00-4d00-4948-aaef-cc3ba519fb7c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 3, 55.0),
('7ac144d8-bbc2-4c3c-8327-947d5a53ddc3',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 4, 80.0),
('ad5dfe6d-ab13-4d28-a6de-922a1ce143c5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 5, 105.0),
('18708608-b7f9-41eb-ac12-82b9d1741d8d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 6, 130.0),
('88a7edb5-205a-45c7-bb9e-7e022eccffad',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 7, 155.0),
('e784ce78-343f-41f8-9320-62892464faee',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 8, 180.0),
('da93d52f-3736-4d43-aec6-d4bf6d0bdbea',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Kings Mountain' AND c.campaign_name = 'The Southern Campaign'),
 9, 205.0);

-- Cowpens: 10 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('ff4a571a-670c-4cd7-9884-1662ea1858be',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 1, 5.0),
('337c34e9-a6ca-4083-837c-3a2aef19afd5',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 2, 30.0),
('7c25fc37-5a92-4615-899a-24baf681415c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 3, 55.0),
('a7c8caca-d958-40b9-bb83-fbe97a905efe',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 4, 80.0),
('5827a60a-39ad-44e5-8d26-e28fda0b7679',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 5, 105.0),
('9d761e85-91dc-4fec-89cb-f91f027e9b87',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 6, 130.0),
('2fea27be-a856-4178-8e5c-b7b7400bc77c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 7, 155.0),
('58300b65-0edc-4ba2-a430-d890b69258d1',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 8, 180.0),
('c4f4d37b-02cd-4e93-a633-2318d8a4b2e0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 9, 205.0),
('ce96a976-11b6-4c6b-b237-94b45fda0d1d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Cowpens' AND c.campaign_name = 'The Southern Campaign'),
 10, 230.0);

-- Guilford Courthouse: 11 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('ae8d4268-ae43-4f65-932c-cb40bbde3871',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 1, 5.0),
('ffd894b3-d287-4767-8e1c-4e020c1c66c0',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 2, 30.0),
('828304fc-9c2a-4b28-9a41-f6ada73df381',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 3, 55.0),
('a009f343-02eb-4e3c-8914-4f8e500a4226',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 4, 80.0),
('a23434f1-32ab-4698-9c0c-57932f611081',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 5, 105.0),
('7ca53816-ce72-4d3e-8b2e-721a013522ba',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 6, 130.0),
('c8c3eeb6-d3e8-4d3a-b29e-64cb5d6a0b87',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 7, 155.0),
('559051a0-b358-409e-89c6-310b7870063f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 8, 180.0),
('9c4755fd-8ce6-431c-9c04-446d78c86639',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 9, 205.0),
('6bb86e4a-c935-463b-88b0-115c37523796',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 10, 230.0),
('991f12b3-80a6-44a7-9b16-df7890a43c88',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Guilford Courthouse' AND c.campaign_name = 'The Southern Campaign'),
 11, 255.0);

-- Eutaw Springs: 12 waves
INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
('22f02dbe-bea8-4a08-8fcc-a4136c9b8b8c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 1, 5.0),
('be7b4449-345c-435d-b8ad-4f247c5b5f75',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 2, 30.0),
('89799d48-e60a-4383-90cf-628fd50d539f',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 3, 55.0),
('e7e29910-ca19-4d22-87d4-1da6c4fdc2bf',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 4, 80.0),
('9a938b11-5372-4ab9-bbec-ca2e3ab09ced',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 5, 105.0),
('d5dd5c24-4e0b-4e7c-8aad-7bbc73780541',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 6, 130.0),
('c880983b-ad6b-4db4-ab0e-a96be43db46c',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 7, 155.0),
('304ecaa6-dd44-4848-81d5-994aff9b99ad',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 8, 180.0),
('fd0955be-0ac7-49ac-9f84-20894446516d',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 9, 205.0),
('c97d4479-479f-42cb-a65f-3b9e9552c2e2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 10, 230.0),
('19fb8926-ddb5-4c49-a33e-f100586a6dd2',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 11, 255.0),
('682789e5-979d-4981-bf35-e028303ba620',
 (SELECT li.id FROM level_info li JOIN campaign c ON c.id = li.campaign_id
   WHERE li.level_name = 'Eutaw Springs' AND c.campaign_name = 'The Southern Campaign'),
 12, 280.0);
