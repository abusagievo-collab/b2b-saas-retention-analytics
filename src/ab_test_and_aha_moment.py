"""
Поиск Aha-момента (критерий хи-квадрат) и расчет размера выборки для A/B-теста онбординга.
"""

import numpy as np
import pandas as pd
from scipy.stats import chi2_contingency
from statsmodels.stats.power import NormalIndPower
from statsmodels.stats.proportion import proportion_effectsize


def evaluate_aha_moment(df: pd.DataFrame) -> dict:
    """
    Оценивает статистическую значимость и Lift конверсии для пользователей,
    достигших Aha-момента (приглашение коллеги + 3 задачи за 48 часов).
    """
    df = df.copy()
    df["reached_aha"] = (df["invited_teammate_48h"] == 1) & (df["completed_3_tasks_48h"] == 1)

    contingency_table = pd.crosstab(df["reached_aha"], df["converted_to_paid"])
    chi2, p_value, _, _ = chi2_contingency(contingency_table)

    cr_aha = df[df["reached_aha"]]["converted_to_paid"].mean()
    cr_baseline = df[~df["reached_aha"]]["converted_to_paid"].mean()
    lift = cr_aha / cr_baseline if cr_baseline > 0 else np.nan

    return {
        "cr_aha_pct": round(cr_aha * 100, 2),
        "cr_baseline_pct": round(cr_baseline * 100, 2),
        "lift": round(lift, 2),
        "p_value": float(p_value),
    }


def calculate_ab_sample_size(baseline_cr: float = 0.042, mde_relative: float = 0.25, alpha: float = 0.05, power: float = 0.80) -> int:
    """
    Рассчитывает необходимый размер выборки на одну группу для A/B-теста конверсии.
    """
    target_cr = baseline_cr * (1 + mde_relative)
    effect_size = proportion_effectsize(baseline_cr, target_cr)
    analysis = NormalIndPower()
    sample_size = analysis.solve_power(
        effect_size=effect_size, power=power, alpha=alpha, ratio=1.0, alternative="two-sided"
    )
    return int(np.ceil(sample_size))


if __name__ == "__main__":
    sample_df = pd.read_csv("data/processed/saas_user_events_sample.csv")
    metrics = evaluate_aha_moment(sample_df)
    required_n = calculate_ab_sample_size()
    print(f"Результаты анализа Aha-момента: {metrics}")
    print(f"Необходимый размер выборки на каждую группу A/B-теста: {required_n:,} пользователей")
