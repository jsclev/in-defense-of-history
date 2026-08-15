DELETE FROM level_wave_enemy_spawn WHERE level_wave_id IN (
    SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
    WHERE li.level_name = 'Charleston'
);

INSERT INTO level_wave_enemy_spawn (
    id, level_wave_id, enemy_type_id, spawn_index,
    num_enemies, spawn_time_since_previous_spawn, spawn_interval, path_index
) VALUES
(
    '19cd33f4-eca2-5032-8200-e6c7dc991353',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 1
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 6, 0.00, 1.20, 0
),
(
    '32f51ffd-0cbd-569e-b989-2d81347f8bb2',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 1
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    1, 4, 4.50, 0.90, 0
),
(
    '2d7bacb7-2eab-5137-b2b5-e344485817fc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 2
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 6, 0.00, 1.10, 1
),
(
    '3c5c3c3d-3f4f-5504-bcfc-27bbb6a1b1eb',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 2
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    1, 4, 4.00, 0.80, 1
),
(
    '7cefb09f-e5fe-5d8b-b1d8-0040b2035923',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 3
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 8, 0.00, 1.00, 0
),
(
    '6234ba1b-b809-524a-ac6b-e9e1f966dc00',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 3
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    1, 8, 0.00, 0.70, 2
),
(
    '2465651d-b9f6-5bef-ad66-dc5248ea4b6c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 3
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    2, 4, 6.00, 0.80, 0
),
(
    'abc94a5c-9701-5e11-a43d-be306031539c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 4
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    0, 8, 0.00, 0.75, 3
),
(
    'ab6b4914-1b6f-5caa-8a93-361520ad0ccd',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 4
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Spy'
    ),
    1, 4, 3.00, 1.00, 1
),
(
    '0981e20a-7578-5d71-9717-a3c1cf5aeb1c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    0, 6, 0.00, 1.40, 0
),
(
    'ab5903ea-23fa-5b02-a668-66047296bd77',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 8, 2.00, 0.90, 2
),
(
    '50c30a9a-efee-58cd-96e0-f4220f56f154',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 5
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    2, 1, 6.00, 1.00, 0
),
(
    '5b63bff5-f7a0-5048-a0ee-165507185cc9',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 6
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    0, 4, 0.00, 1.60, 4
),
(
    'edb5197a-db0e-5703-8f8d-02037627c271',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 6
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    1, 8, 2.00, 0.80, 3
),
(
    'c5ed8c2f-a2b3-5634-a843-28faa45521ed',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 10, 0.00, 0.85, 0
),
(
    '5606d81f-66b3-58ff-83ce-a9b95018c73d',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 10, 0.00, 0.85, 1
),
(
    'f6bbd357-a163-5ae8-8b90-e42682157ac9',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 7
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Highlander'
    ),
    2, 5, 7.00, 1.10, 3
),
(
    '87c32851-bbd8-5a9b-ae3f-21d167f143e7',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    0, 10, 0.00, 0.60, 0
),
(
    '11ceff75-8f90-576d-ad71-31492f2a7d66',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    1, 8, 0.00, 0.60, 2
),
(
    '70f7d447-5f3d-5e0c-a7ad-9eee732edb54',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 8
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    2, 3, 5.00, 1.40, 1
),
(
    '81189a07-6d47-51bb-8fed-954a6ccfad6b',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Royal Artillery'
    ),
    0, 2, 0.00, 4.00, 0
),
(
    '2d8a342f-68b2-5f5c-9a11-dca9c0c55bb5',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    1, 12, 1.00, 0.80, 0
),
(
    '9892bfe3-1404-5254-b181-94153a138fb8',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 9
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    2, 8, 3.50, 1.00, 1
),
(
    '8e462a58-64c7-5526-aa9a-f81b3aa4f673',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    0, 4, 0.00, 2.20, 3
),
(
    'be8a9dfb-641b-5c4c-b358-9791c0ec0393',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    1, 2, 2.00, 3.00, 3
),
(
    '1735692b-4bc3-5a02-a3e6-3383b6b46277',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 10
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Loyalist Militia'
    ),
    2, 12, 4.00, 0.55, 2
),
(
    '9e93d4a3-757a-5514-a8cf-624aae1fdcc1',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    0, 8, 0.00, 0.90, 4
),
(
    'bfec9708-a6a9-583f-95c0-f0298ea61596',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Mounted Officer'
    ),
    1, 3, 3.00, 1.80, 1
),
(
    '369f421b-1929-5846-b387-39f98d6026cc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 11
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Spy'
    ),
    2, 6, 1.50, 0.80, 0
),
(
    'a4414e81-6210-5a45-8093-99874a8e8cab',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    0, 10, 0.00, 0.90, 0
),
(
    '3db0b0ae-b358-521b-9999-576e992a78bc',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Highlander'
    ),
    1, 8, 1.50, 0.90, 1
),
(
    '0c7bc3d3-5b87-5695-b9dc-fedc73d5c9f3',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 12
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    2, 3, 8.00, 2.00, 2
),
(
    '299a831a-0704-5d2b-abac-d1609393aefa',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    0, 14, 0.00, 0.70, 2
),
(
    'fbeb8648-4853-580e-8061-dd75aac6b23c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Infantry'
    ),
    1, 10, 0.00, 0.75, 3
),
(
    'a441edda-e60a-59ee-894e-13c88d2271c1',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Royal Artillery'
    ),
    2, 2, 6.00, 3.50, 1
),
(
    '7ea1fb23-9355-52d7-8bc0-d69c961bd9ec',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 13
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Native Warrior'
    ),
    3, 8, 9.00, 0.60, 0
),
(
    '66f584f2-fa87-5ca6-b107-f699bfecd81c',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Foot Guards'
    ),
    0, 2, 0.00, 5.00, 0
),
(
    'bf86318d-1191-51ac-aea9-4b735d0865ca',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Mounted Officer'
    ),
    1, 4, 2.00, 1.60, 3
),
(
    '7aed972d-86aa-5dc4-b7c3-4053d95ea641',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 14
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Hessian Fusilier'
    ),
    2, 10, 4.00, 0.85, 1
),
(
    '462521ba-ac2c-5cb9-923c-6fbbce0fba7e',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Foot Guards'
    ),
    0, 3, 0.00, 3.50, 1
),
(
    '2bc7e29c-387e-5fdd-9ab7-fe4b02109a52',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Grenadier'
    ),
    1, 5, 1.00, 1.80, 0
),
(
    'fdf4bc5d-0c5e-58d2-8027-081e2c9f7ea5',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Light Dragoon'
    ),
    2, 8, 3.00, 0.80, 4
),
(
    'cd743452-a297-5c15-befe-e0e96284d9ff',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Redcoat Regular'
    ),
    3, 16, 5.00, 0.55, 2
),
(
    '1437783a-1a5a-537b-9c11-48503cb261bf',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Royal Artillery'
    ),
    4, 2, 10.00, 4.00, 3
),
(
    '8d60a77c-faa6-5c03-9947-12909438d797',
    (
        SELECT lw.id FROM level_wave AS lw INNER JOIN level_info AS li ON li.id = lw.level_info_id
        WHERE li.level_name = 'Charleston' AND lw.wave_index = 15
    ),
    (
        SELECT id FROM enemy_type WHERE enemy_type_name = 'Regimental Drummer'
    ),
    5, 2, 12.00, 2.50, 0
);
