-- No parameters. Requires SQLite's standard dbstat virtual table.
SELECT name,COUNT(*) AS pages,SUM(pgsize) AS allocated_bytes,SUM(payload) AS payload_bytes
FROM dbstat WHERE name GLOB 'ga_*' OR name GLOB 'genetic_*'
GROUP BY name ORDER BY allocated_bytes DESC;
