INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('9dcef9c8-fa3c-4d26-ad86-ae80c5fd8b20', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 1080.0, 669.0),
('7e382b1a-9fdc-4ef0-979b-158b300672b3', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 921.0, 454.0),
('93bd8328-7778-415f-8c98-a22dd53c01d1', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 656.0, 565.0),
('60b75c75-5483-4053-8a6e-98248ab16f4d', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 492.0, 578.0),
('20bcc452-1bb7-4b82-939d-12d0c18a4f70', (SELECT id FROM level_info WHERE level_name = 'Lexington and Concord'), 485.0, 579.0);

-- Bunker Hill: the ten numbered platforms painted on the map (slot order
-- follows the art's badge numbers 1-10).
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('abb1fbb8-2523-4ac6-93ef-de922b44aa01', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 500.0, 313.0),
('479315db-b690-49d8-8d68-101d2897c756', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 741.0, 308.0),
('02f132e6-2c0c-404b-9091-7485de70458b', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 939.0, 321.0),
('0031751a-b816-437a-8542-2260ebdf3754', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 1048.0, 477.0),
('d0a8718e-ab1e-4079-b0e5-3605224b8bd6', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 656.0, 462.0),
('440df2be-02b1-4d65-9330-af8293f8c0f7', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 931.0, 481.0),
('129b5bf3-b2fa-46f1-8c30-4d965838a201', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 707.0, 589.0),
('215503bb-38fb-4ce6-8834-104d1176fb9f', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 906.0, 594.0),
('079f2581-fcbc-46c3-b11c-1ae41c1c9e2b', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 490.0, 602.0),
('294d9440-531a-4a50-89c1-11025c61a5b5', (SELECT id FROM level_info WHERE level_name = 'Bunker Hill'), 1077.0, 588.0);

-- Great Bridge: the five square platforms on the militia bank.
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('3f813cb7-de72-4f15-9527-7a8d2c2666db', (SELECT id FROM level_info WHERE level_name = 'Great Bridge'), 480.0, 747.0),
('b41db800-d6ef-4b4b-a310-38b7ca6f5121', (SELECT id FROM level_info WHERE level_name = 'Great Bridge'), 679.0, 753.0),
('b0440d18-44b1-4bbf-8d5a-6803dab6b447', (SELECT id FROM level_info WHERE level_name = 'Great Bridge'), 569.0, 844.0),
('e1e6c952-8296-429f-b662-a4503c19a28c', (SELECT id FROM level_info WHERE level_name = 'Great Bridge'), 366.0, 884.0),
('0efcaf7a-f816-4afc-afd8-584c765d7ba8', (SELECT id FROM level_info WHERE level_name = 'Great Bridge'), 516.0, 929.0);

-- Moore's Creek Bridge: nine platforms, stored in the art's shield order
-- (the painted numbering skips 9 -- shields run 1-8 then 10).
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('9455cea2-415d-41d0-97bd-f9df7fc087df', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 458.0, 682.0),
('149abd09-6686-4d85-b168-abf55af30938', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 640.0, 752.0),
('b7a1307d-7263-4cda-b2a1-d33da56f4cf5', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 628.0, 578.0),
('7f57f9e2-9042-46f1-bf3d-db1556d878fc', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 943.0, 322.0),
('46de73cd-4372-47fa-b856-b3af85f0b08d', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 1170.0, 362.0),
('17ff4805-2de2-4834-9ea9-4c451a3c2c68', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 1395.0, 462.0),
('96d21d47-356f-4716-844f-a8c063aaff3b', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 1000.0, 527.0),
('59ae45da-5c20-4daa-a9e0-9645844bfeb1', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 1291.0, 635.0),
('35191e08-1751-4289-8912-c47b229a2e1c', (SELECT id FROM level_info WHERE level_name = 'Moore''s Creek Bridge'), 1000.0, 692.0);

-- Long Island: the ten platforms across the battlefield.
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('94ff3607-162a-41a7-9f87-c9594ffc8d90', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 684.0, 344.0),
('a97abd3d-80b6-4092-963a-2e6df82e2c0b', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 818.0, 414.0),
('e436cb15-a55d-41b9-8e4f-ce5c952560cf', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 1046.0, 367.0),
('95a54975-661d-4d68-a979-1cd15754592f', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 1028.0, 451.0),
('240be546-bbee-4575-b2d8-e0167c235431', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 574.0, 497.0),
('9daa0374-ffab-46b5-9b6f-d58de80d2e67', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 692.0, 458.0),
('2ee059ae-85d2-4822-a8b1-fb8347c0825b', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 739.0, 519.0),
('47bb819f-1e3e-4deb-b159-319c9afeecd6', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 853.0, 591.0),
('a9d679bc-a4df-4ed5-98ab-9f98f266d2b2', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 934.0, 541.0),
('d7f28453-c113-4e5b-8d28-7e4b3bfcbabb', (SELECT id FROM level_info WHERE level_name = 'Long Island'), 1071.0, 613.0);

-- Trenton: the nine round pads.
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('0718035e-cf44-4706-a81f-8cdbacf92606', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 835.0, 315.0),
('4825e9e0-d130-4418-85b2-2a415a4b627e', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 985.0, 425.0),
('ce62f1f7-a1d9-408e-adae-93c9823172af', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 520.0, 415.0),
('8b5e3e84-d046-41fc-a2a5-894af054db26', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 540.0, 520.0),
('13e01bd4-0052-4ad0-b9e7-8308b1ec9d12', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 735.0, 590.0),
('25abb7bd-eb9a-4da8-9d3d-59f25dcbd214', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 1195.0, 490.0),
('3daf4bba-5f92-44ee-add4-2915a8fe6988', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 1165.0, 635.0),
('eddf4b93-5a3a-42cf-81e4-ff54cfb2541f', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 975.0, 735.0),
('1e987d35-1c6f-47cc-a095-965edd35bcd8', (SELECT id FROM level_info WHERE level_name = 'Trenton'), 1130.0, 822.0);

-- Princeton: the twelve road-bend pads.
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('8a77b489-505e-4496-a495-3dd82db9174f', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 390.0, 325.0),
('978a0ce0-9105-408d-b0be-178618fe6d29', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 715.0, 365.0),
('3296a818-c4d9-4d50-a583-b4e897ba63ec', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 940.0, 410.0),
('a039f43e-4220-4e8b-9e18-7fe169edda0d', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 880.0, 515.0),
('7d92d50b-a5a0-4713-b235-1f7e5aa1e2a4', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 470.0, 555.0),
('94fa878d-6485-45ff-b32f-410459a2cd55', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 655.0, 560.0),
('cde23a70-0c0c-44d0-92c8-9296280299b9', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 490.0, 650.0),
('93c3f74e-e411-465b-837a-7bd613a41b6d', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 720.0, 720.0),
('ec79987f-0e1e-43fa-80d1-f83cb7fe7de7', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 1080.0, 590.0),
('1c929982-963a-40da-9111-7f2ea277de16', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 995.0, 690.0),
('0ffba21c-df1b-43f9-87fd-9cf28b750076', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 600.0, 840.0),
('06b7d49d-5523-44d4-83cb-91f4ea2b1fae', (SELECT id FROM level_info WHERE level_name = 'Princeton'), 1030.0, 835.0);

-- Charleston: the ten bastion platforms of the city works.
INSERT INTO tower_slot (id, level_info_id, map_position_x, map_position_y) VALUES
('ea1beb4d-b754-4c22-acb2-f23b31b4a8c0', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 600.0, 298.0),
('a80b53cb-7201-4cd2-91a6-3ebc7844ff2c', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 838.0, 293.0),
('bfbc8411-5a20-4709-82c8-fd580ebc7832', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 490.0, 407.0),
('35abb36e-2b54-48b4-ba0c-c32b31c5d6ed', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 645.0, 399.0),
('c025ba4f-4fee-4f7f-9305-ee00bcf47591', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 880.0, 406.0),
('32d6b740-e313-456c-8eb3-fec547561923', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 462.0, 501.0),
('458fff19-8bb2-4ac0-919e-8f4f8d3528fb', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 978.0, 489.0),
('4c9d19a8-4dbd-47f1-ad39-30e12c7a0b30', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 432.0, 606.0),
('715e08e8-b953-4fba-acbe-95bbad8f79de', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 520.0, 674.0),
('06c9cfd1-d49a-46a8-a0e8-236c2f5e1d6b', (SELECT id FROM level_info WHERE level_name = 'Charleston'), 905.0, 684.0);
