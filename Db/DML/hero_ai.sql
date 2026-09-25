-- AI strategy selection/tuning and player control are explicitly authored.
-- Every hero begins under manual control; AI can be enabled in Settings.
INSERT INTO hero_ai (hero_id, controller, decision_interval, retreat_health_fraction, resume_health_fraction) VALUES
('75a615ca-f880-44ca-8386-e28f72fe2f7f', 'israel_putnam', 0.25, 0.25, 0.75),
('43b37067-8f24-4f3e-ba9b-3c7f10cc629d', 'henry_knox', 0.25, 0.25, 0.75),
('4f5ea61b-2be4-46b1-ad0b-21c1a80ab8e4', 'louis_duportail', 0.25, 0.25, 0.75),
('fac6c094-9cbc-474a-975e-8d2a170e07da', 'george_washington', 0.25, 0.25, 0.75),
('ca5f165f-d3e1-44e4-a224-65c8a798c022', 'mary_hays', 0.25, 0.25, 0.75),
('c418c84b-0eb0-46a6-badb-ea0302ca89a7', 'daniel_morgan', 0.25, 0.25, 0.75),
('5c689e4f-5105-4bab-8dd9-63f61124bd35', 'benedict_arnold', 0.25, 0.25, 0.75),
('1d9dba5f-e46a-4ca6-ac50-d62b22e7bd1b', 'friedrich_von_steuben', 0.25, 0.25, 0.75),
('a72abee1-88a6-4856-a5d4-da460a2233b9', 'francis_marion', 0.25, 0.25, 0.75),
('31f3c69a-094a-4923-8dd0-a7411216d3cb', 'nathanael_greene', 0.25, 0.25, 0.75),
('dd5b7c53-5f26-4035-aa43-b78b5e177b08', 'william_prescott', 0.25, 0.25, 0.75),
('4e290eb7-6af2-4e3e-8bd6-ff0759b1b13d', 'thaddeus_kosciuszko', 0.25, 0.25, 0.75),
('90048c5e-9113-4b6e-987f-047d95f3590a', 'salem_poor', 0.25, 0.25, 0.75),
('1feb2d3f-815d-4139-9e47-b99aac112fc8', 'john_glover', 0.25, 0.25, 0.75),
('a8c1a230-8fb2-421e-bd22-4aadf6770c3a', 'horatio_gates', 0.25, 0.25, 0.75);

INSERT INTO player_hero_control (hero_id, ai_enabled) VALUES
('75a615ca-f880-44ca-8386-e28f72fe2f7f', 0),
('43b37067-8f24-4f3e-ba9b-3c7f10cc629d', 0),
('4f5ea61b-2be4-46b1-ad0b-21c1a80ab8e4', 0),
('fac6c094-9cbc-474a-975e-8d2a170e07da', 0),
('ca5f165f-d3e1-44e4-a224-65c8a798c022', 0),
('c418c84b-0eb0-46a6-badb-ea0302ca89a7', 0),
('5c689e4f-5105-4bab-8dd9-63f61124bd35', 0),
('1d9dba5f-e46a-4ca6-ac50-d62b22e7bd1b', 0),
('a72abee1-88a6-4856-a5d4-da460a2233b9', 0),
('31f3c69a-094a-4923-8dd0-a7411216d3cb', 0),
('dd5b7c53-5f26-4035-aa43-b78b5e177b08', 0),
('4e290eb7-6af2-4e3e-8bd6-ff0759b1b13d', 0),
('90048c5e-9113-4b6e-987f-047d95f3590a', 0),
('1feb2d3f-815d-4139-9e47-b99aac112fc8', 0),
('a8c1a230-8fb2-421e-bd22-4aadf6770c3a', 0);
