-- ============================================================================
-- Проект: Когортный анализ Retention и воронка активации B2B SaaS
-- Описание: Расчет конверсии шагов онбординга и недельного Retention по когортам
-- ============================================================================

WITH user_cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('week', MIN(event_timestamp))::DATE AS cohort_week,
        MIN(event_timestamp) AS signup_ts
    FROM user_events
    WHERE event_name = 'sign_up'
    GROUP BY user_id
),
onboarding_funnel AS (
    SELECT
        c.user_id,
        c.cohort_week,
        MAX(CASE WHEN e.event_name = 'workspace_created' THEN 1 ELSE 0 END) AS step_1_workspace,
        MAX(CASE WHEN e.event_name = 'teammate_invited'
                  AND e.event_timestamp <= c.signup_ts + INTERVAL '48 hours' THEN 1 ELSE 0 END) AS step_2_invite_48h,
        MAX(CASE WHEN e.event_name = 'third_task_completed'
                  AND e.event_timestamp <= c.signup_ts + INTERVAL '48 hours' THEN 1 ELSE 0 END) AS step_3_tasks_48h,
        MAX(CASE WHEN e.event_name = 'subscription_paid' THEN 1 ELSE 0 END) AS converted_to_paid
    FROM user_cohorts c
    LEFT JOIN user_events e ON c.user_id = e.user_id
    GROUP BY c.user_id, c.cohort_week
)
SELECT
    cohort_week,
    COUNT(user_id) AS signups,
    SUM(step_1_workspace) AS workspace_created,
    SUM(step_2_invite_48h) AS invited_teammate_48h,
    SUM(step_3_tasks_48h) AS completed_3_tasks_48h,
    SUM(converted_to_paid) AS paid_users,
    ROUND(100.0 * SUM(converted_to_paid) / NULLIF(COUNT(user_id), 0), 2) AS overall_cr_pct,
    ROUND(
        100.0 * SUM(CASE WHEN step_2_invite_48h = 1 AND step_3_tasks_48h = 1 AND converted_to_paid = 1 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN step_2_invite_48h = 1 AND step_3_tasks_48h = 1 THEN 1 ELSE 0 END), 0),
        2
    ) AS aha_moment_cr_pct
FROM onboarding_funnel
GROUP BY cohort_week
ORDER BY cohort_week;
