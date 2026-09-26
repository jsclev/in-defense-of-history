-- Private to a standalone simulator invocation; never player state.
CREATE TABLE IF NOT EXISTS simulator_invocation (
    singleton INTEGER PRIMARY KEY CHECK (singleton = 1),
    schema_version INTEGER NOT NULL CHECK (schema_version = 1),
    invocation_id TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    source_database TEXT NOT NULL,
    command_line_json TEXT NOT NULL CHECK (json_valid(command_line_json))
);

CREATE TABLE IF NOT EXISTS simulator_map (
    map_image_name TEXT PRIMARY KEY NOT NULL,
    geojson TEXT NOT NULL CHECK (json_valid(geojson))
);

CREATE TABLE IF NOT EXISTS simulator_document (
    name TEXT PRIMARY KEY NOT NULL,
    content_json TEXT NOT NULL CHECK (json_valid(content_json))
);
