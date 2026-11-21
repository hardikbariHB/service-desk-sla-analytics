-- Written for SQLite so you can run it anywhere. Postgres/SQL Server notes are in README.md.
-- name: clean_view
DROP VIEW IF EXISTS clean_tickets;
CREATE VIEW clean_tickets AS
WITH dedup AS (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY ticket_id ORDER BY opened_at) AS rn
  FROM raw_tickets
)
SELECT ticket_id, opened_at, NULLIF(resolved_at,'') AS resolved_at, priority, category, assignment_group, reopen_count,
       CASE priority WHEN 'P1' THEN 4 WHEN 'P2' THEN 8 WHEN 'P3' THEN 24 WHEN 'P4' THEN 72 END AS sla_hours,
       ROUND((julianday(NULLIF(resolved_at,'')) - julianday(opened_at)) * 24, 2) AS resolution_hours
FROM dedup
WHERE rn = 1
  AND category <> ''
  AND priority IN ('P1','P2','P3','P4')
  AND (NULLIF(resolved_at,'') IS NULL OR resolved_at >= opened_at);

-- name: data_quality_summary
SELECT (SELECT COUNT(*) FROM raw_tickets) AS raw_rows,
       (SELECT COUNT(*) FROM clean_tickets) AS clean_rows,
       (SELECT COUNT(*) FROM raw_tickets) - (SELECT COUNT(*) FROM clean_tickets) AS rows_removed;

-- name: sla_breach_by_priority
SELECT priority, COUNT(*) AS resolved_tickets,
       ROUND(AVG(resolution_hours),1) AS avg_hours, MAX(sla_hours) AS sla_hours,
       ROUND(100.0 * SUM(resolution_hours > sla_hours) / COUNT(*), 1) AS breach_pct
FROM clean_tickets WHERE resolved_at IS NOT NULL
GROUP BY priority ORDER BY priority;

-- name: worst_categories
SELECT category, COUNT(*) AS tickets,
       ROUND(100.0 * SUM(resolution_hours > sla_hours) / COUNT(*), 1) AS breach_pct,
       ROUND(AVG(resolution_hours / sla_hours), 2) AS avg_sla_consumed
FROM clean_tickets WHERE resolved_at IS NOT NULL
GROUP BY category ORDER BY breach_pct DESC;

-- name: monthly_trend
SELECT strftime('%Y-%m', opened_at) AS month, COUNT(*) AS tickets,
       ROUND(100.0 * SUM(resolution_hours > sla_hours) / SUM(resolved_at IS NOT NULL), 1) AS breach_pct
FROM clean_tickets GROUP BY month ORDER BY month;

-- name: peak_hours
SELECT strftime('%H', opened_at) AS hour_of_day, COUNT(*) AS tickets
FROM clean_tickets GROUP BY hour_of_day ORDER BY tickets DESC LIMIT 5;

-- name: repeat_incidents
SELECT category, COUNT(*) AS tickets, SUM(reopen_count > 0) AS reopened,
       ROUND(100.0 * SUM(reopen_count > 0) / COUNT(*), 1) AS reopen_pct
FROM clean_tickets GROUP BY category ORDER BY reopen_pct DESC;

-- name: group_performance
SELECT assignment_group, COUNT(*) AS tickets, ROUND(AVG(resolution_hours / sla_hours), 2) AS avg_sla_consumed
FROM clean_tickets WHERE resolved_at IS NOT NULL
GROUP BY assignment_group ORDER BY avg_sla_consumed DESC;
