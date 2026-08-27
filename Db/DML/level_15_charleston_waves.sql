-- Charleston (level 15): 15 waves over the four edge lanes of the new map.
-- All roads run toward the town: path 0 = left -> bottom (long main lane);
-- path 1 = top -> right; path 2 = top -> left (short, late-game pressure);
-- path 3 = right -> bottom. path 4 (the short mid-map lane) carries no waves.
-- Every wave must be cleared (all spawned, none alive) before the next wave's start button appears.

DELETE FROM level_wave_enemy_spawn WHERE level_wave_id IN (
    SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
    INNER JOIN campaign AS c ON li.campaign_id = c.id
    WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
);
DELETE FROM level_wave WHERE level_info_id IN (
    SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
    WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
);

INSERT INTO level_wave (id, level_info_id, wave_index, spawn_time) VALUES
(
    'dad762fe-2a0e-5af8-a3b7-b4433af68529',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    1, 5.0
),
(
    'e24ab7b2-c906-5197-b112-6d18fe86c7cc',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    2, 23.0
),
(
    'f1318874-c56f-5dc4-ab5d-ff1e7e7aaa26',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    3, 42.0
),
(
    '7da7dc20-112d-5f29-a20e-d53f83c39cac',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    4, 62.5
),
(
    'e59219fa-41d6-55cd-b143-5219f63be76d',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    5, 82.5
),
(
    'e1839bfb-a905-552c-bfc0-134f838670b8',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    6, 105.5
),
(
    'b2b862ee-73e0-50ff-9fe7-5b7572135dae',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    7, 129.5
),
(
    '0adc19d8-340e-5fd0-81f5-8d7794f8894e',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    8, 154.5
),
(
    '777bb7b3-74d6-5b3a-a8e6-2aae1b403536',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    9, 180.4
),
(
    '200052e1-23ef-5286-9a31-7fb9fa1776e1',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    10, 209.0
),
(
    '806e941e-a051-583e-a083-d8fbb41f7165',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    11, 235.0
),
(
    'cc7eb305-4635-5747-9d7c-b751d2b2739f',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    12, 264.6
),
(
    '68778987-a236-5178-9098-99c4debc27f1',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    13, 295.0
),
(
    '8ff0e90c-4e07-5b61-940b-bff2b1037989',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    14, 328.0
),
(
    '0f43d15d-27d1-500c-94cd-8bf4c9c148c6',
    (
        SELECT li.id FROM level_info AS li INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main'
    ),
    15, 361.7
);

INSERT INTO level_wave_enemy_spawn (
    id, level_wave_id, enemy_type_id, spawn_index,
    num_enemies, spawn_time_since_previous_spawn, spawn_interval, path_index
) VALUES
(
    '19cd33f4-eca2-5032-8200-e6c7dc991353',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 1
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    0, 6, 0.00, 1.20, 0
),
(
    '2d7bacb7-2eab-5137-b2b5-e344485817fc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 2
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    0, 8, 0.00, 1.00, 0
),
(
    '3c5c3c3d-3f4f-5504-bcfc-27bbb6a1b1eb',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 2
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 3, 4.00, 1.50, 0
),
(
    '7cefb09f-e5fe-5d8b-b1d8-0040b2035923',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 3
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 6, 0.00, 1.20, 3
),
(
    '6234ba1b-b809-524a-ac6b-e9e1f966dc00',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 3
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    1, 6, 2.00, 0.90, 3
),
(
    'abc94a5c-9701-5e11-a43d-be306031539c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 4
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    0, 6, 0.00, 1.00, 0
),
(
    'ab6b4914-1b6f-5caa-8a93-361520ad0ccd',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 4
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 6, 0.00, 1.20, 3
),
(
    '0981e20a-7578-5d71-9717-a3c1cf5aeb1c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 8, 0.00, 1.00, 1
),
(
    'ab5903ea-23fa-5b02-a668-66047296bd77',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    1, 1, 3.00, 1.00, 1
),
(
    '50c30a9a-efee-58cd-96e0-f4220f56f154',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Jäger'
    ),
    2, 4, 0.00, 1.20, 1
),
(
    '5b63bff5-f7a0-5048-a0ee-165507185cc9',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 6
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    0, 6, 0.00, 1.30, 0
),
(
    'edb5197a-db0e-5703-8f8d-02037627c271',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 6
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    1, 6, 0.00, 0.90, 3
),
(
    'a465fc0f-e0e8-5e90-b86a-1c3ec2e46b30',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 6
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Spy'
    ),
    2, 2, 6.00, 2.00, 0
),
(
    'c5ed8c2f-a2b3-5634-a843-28faa45521ed',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    0, 8, 0.00, 0.80, 1
),
(
    '5606d81f-66b3-58ff-83ce-a9b95018c73d',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 8, 0.00, 1.00, 0
),
(
    'f6bbd357-a163-5ae8-8b90-e42682157ac9',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    2, 1, 4.00, 1.00, 1
),
(
    '87c32851-bbd8-5a9b-ae3f-21d167f143e7',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Highlander'
    ),
    0, 6, 0.00, 1.30, 3
),
(
    '11ceff75-8f90-576d-ad71-31492f2a7d66',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    1, 6, 0.00, 1.20, 1
),
(
    '70f7d447-5f3d-5e0c-a7ad-9eee732edb54',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    2, 8, 3.00, 0.70, 3
),
(
    '81189a07-6d47-51bb-8fed-954a6ccfad6b',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    0, 5, 0.00, 1.40, 0
),
(
    '2d8a342f-68b2-5f5c-9a11-dca9c0c55bb5',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 10, 0.00, 0.90, 1
),
(
    '9892bfe3-1404-5254-b181-94153a138fb8',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Spy'
    ),
    2, 3, 5.00, 1.80, 3
),
(
    '8e462a58-64c7-5526-aa9a-f81b3aa4f673',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    0, 4, 0.00, 2.00, 2
),
(
    'be8a9dfb-641b-5c4c-b358-9791c0ec0393',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Highlander'
    ),
    1, 6, 0.00, 1.20, 0
),
(
    '1735692b-4bc3-5a02-a3e6-3383b6b46277',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    2, 1, 2.00, 1.00, 2
),
(
    '9e93d4a3-757a-5514-a8cf-624aae1fdcc1',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Mounted Officer'
    ),
    0, 2, 0.00, 3.00, 1
),
(
    'bfec9708-a6a9-583f-95c0-f0298ea61596',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    1, 8, 0.00, 1.00, 3
),
(
    '369f421b-1929-5846-b387-39f98d6026cc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    2, 8, 2.00, 0.80, 0
),
(
    'a4414e81-6210-5a45-8093-99874a8e8cab',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Royal Artillery'
    ),
    0, 2, 0.00, 4.00, 2
),
(
    '3db0b0ae-b358-521b-9999-576e992a78bc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    1, 8, 0.00, 0.90, 3
),
(
    '0c7bc3d3-5b87-5695-b9dc-fedc73d5c9f3',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    2, 4, 3.00, 1.80, 1
),
(
    '299a831a-0704-5d2b-abac-d1609393aefa',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    0, 6, 0.00, 1.60, 0
),
(
    'fbeb8648-4853-580e-8061-dd75aac6b23c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    1, 6, 0.00, 1.20, 1
),
(
    'a441edda-e60a-59ee-894e-13c88d2271c1',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    2, 2, 2.00, 2.00, 3
),
(
    '7ea1fb23-9355-52d7-8bc0-d69c961bd9ec',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Spy'
    ),
    3, 3, 6.00, 1.50, 0
),
(
    '66f584f2-fa87-5ca6-b107-f699bfecd81c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Foot Guards'
    ),
    0, 2, 0.00, 3.00, 2
),
(
    'bf86318d-1191-51ac-aea9-4b735d0865ca',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Highlander'
    ),
    1, 8, 0.00, 1.10, 0
),
(
    '7aed972d-86aa-5dc4-b7c3-4053d95ea641',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Mounted Officer'
    ),
    2, 2, 4.00, 2.50, 1
),
(
    '462521ba-ac2c-5cb9-923c-6fbbce0fba7e',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Foot Guards'
    ),
    0, 4, 0.00, 2.50, 0
),
(
    '2bc7e29c-387e-5fdd-9ab7-fe4b02109a52',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Royal Artillery'
    ),
    1, 2, 2.00, 4.00, 1
),
(
    'fdf4bc5d-0c5e-58d2-8027-081e2c9f7ea5',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    2, 6, 3.00, 1.50, 2
),
(
    'cd743452-a297-5c15-befe-e0e96284d9ff',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    3, 6, 4.00, 1.00, 3
),
(
    '1437783a-1a5a-537b-9c11-48503cb261bf',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        INNER JOIN campaign AS c ON li.campaign_id = c.id
        WHERE li.level_name = 'Charleston' AND c.campaign_name = 'Main' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Mounted Officer'
    ),
    4, 1, 10.00, 1.00, 0
);

UPDATE level_info SET num_waves = 15 WHERE id = '4ca73a47-98f6-41b6-815d-c2c797aa746e';
