-- Authored initial settings. Startup always uses the newly bundled database.
INSERT INTO player_settings
    (id, debug_mode, show_debug_info, show_debug_layout_guides, enemy_escape_haptics_enabled, show_ga_solution_button)
VALUES (1, 0, 0, 0, 1, 1);
