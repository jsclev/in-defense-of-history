INSERT INTO level_info (
    id, campaign_id, level_name, world_map_x, world_map_y,
    started_at, ended_at, starting_money, num_starting_lives,
    playable_rect_x, playable_rect_y, playable_rect_width, playable_rect_height
) VALUES (
    '23eecc79-4ceb-4527-bf6f-217fa43c0a2c',
    '9fef24bb-34b9-4588-85b4-25aa9aa2c6c9',
    'Fort Washington',
    0.0,
    0.0,
    julianday('1776-11-16T07:00:00-05:00'),
    julianday('1776-11-16T15:00:00-05:00'),
    300,
    20,
    190.0, 226.125, 1164.0, 654.75
);
