"""
Monthly VAR for Ukraine with recursive (Cholesky) identification of shocks.

Variables (in Cholesky order, most exogenous first):
    Oil_growth, GDP_growth, Core_CPI, M2_growth, d_Policy_Rate,
    d_OVDP_Yield, Exchange_growth

Outputs (written to OUT_DIR): IRF figures with bootstrap bands, FEVD figure
and the inverse-roots stability plot. Diagnostics are printed to the console.
"""

import math
import os
import warnings

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from statsmodels.tsa.api import VAR
from statsmodels.tsa.stattools import adfuller

# ---------------------------------------------------------------- settings
DATA_PATH = "NBU_SVAR_clean.csv"
OUT_DIR = "output"

LAGS = 2
MAX_LAGS_SEARCH = 6
IRF_HORIZON = 18
FEVD_HORIZON = 12
BOOT_REPL = 1000
SIGNIF = 0.05
SEED = 42

# Level-shift dummies for crisis periods; use an empty dict to disable.
DUMMY_PERIODS = {
    "D_2015": ("2015-01-01", "2015-12-01"),
    "D_2022": ("2022-03-01", "2022-12-01"),
}


# -------------------------------------------------------------------- data
def load_data(path):
    """Read the CSV and convert all columns to numeric, indexed by month."""
    df = pd.read_csv(path, dtype=str)
    df.columns = df.columns.str.strip().str.replace("**", "", regex=False)
    if "Date" not in df.columns and "Unnamed: 0" in df.columns:
        df = df.rename(columns={"Unnamed: 0": "Date"})
    if "Date" not in df.columns:
        raise ValueError(f"Date column not found. Columns: {list(df.columns)}")

    for col in df.columns.drop("Date"):
        df[col] = pd.to_numeric(
            df[col]
            .str.replace(",", ".", regex=False)
            .str.replace("**", "", regex=False)
            .str.strip()
        )

    df["Date"] = pd.to_datetime(df["Date"].str.strip(), format="%m/%Y")
    return df.set_index("Date").sort_index()


def build_variables(df):
    """Construct the stationary VAR variables in Cholesky order."""
    log_diff = lambda s: np.log(s).diff() * 100

    data = pd.DataFrame(index=df.index)
    data["Oil_growth"] = log_diff(df["Ціни на паливо"])
    data["GDP_growth"] = df["Real GDP growth"]
    data["Core_CPI"] = df["БІСЦ (% р/р)"]
    data["M2_growth"] = log_diff(df["M2"])
    data["d_Policy_Rate"] = df["Облікова ставка, %"].diff()
    data["d_OVDP_Yield"] = df["Дохідність ОВДП"].diff()
    data["Exchange_growth"] = log_diff(df["Курс до долара"])

    data = data.replace([np.inf, -np.inf], np.nan).dropna()
    data.index.freq = "MS"
    return data


def build_dummies(index, periods):
    """Level-shift dummies for the given periods, or None if there are none."""
    if not periods:
        return None
    dummies = pd.DataFrame(index=index)
    for name, (start, end) in periods.items():
        in_period = (index >= pd.Timestamp(start)) & (index <= pd.Timestamp(end))
        dummies[name] = in_period.astype(float)
    return dummies


# ------------------------------------------------------------- diagnostics
def run_diagnostics(data, model, results):
    print("\nADF test (p-value; < 0.05 -> stationary)")
    with warnings.catch_warnings():
        warnings.simplefilter("ignore", FutureWarning)
        for col in data.columns:
            print(f"  {col:18s} {adfuller(data[col], autolag='AIC')[1]:.3f}")

    print("\nLag order selection")
    print(model.select_order(maxlags=MAX_LAGS_SEARCH).summary())

    inv_roots = 1.0 / np.abs(results.roots)
    print(f"\nStable: {results.is_stable()} | max inverse root: {inv_roots.max():.4f}")

    print("\nResidual autocorrelation (Portmanteau, 12 lags)")
    print(results.test_whiteness(nlags=12).summary())

    print("\nResidual normality")
    print(results.test_normality().summary())

    print("\nGranger block-exogeneity (p-value; others -> variable)")
    for caused in data.columns:
        causing = [c for c in data.columns if c != caused]
        p_value = results.test_causality(caused, causing, kind="f").pvalue
        print(f"  {caused:18s} {p_value:.3f}")


# --------------------------------------------------------------------- IRF
def bootstrap_irf_bands(results, data, exog, lags, steps, repl, signif, seed):
    """
    Residual-bootstrap percentile bands for orthogonalised IRFs.

    Resamples centred residuals, rebuilds the series from the estimated
    coefficients (including exogenous dummies), re-estimates the VAR and
    recomputes the IRFs. Does not assume normal errors.
    """
    rng = np.random.default_rng(seed)
    cols = list(data.columns)
    n = len(cols)
    params = results.params
    resid = results.resid.values
    resid = resid - resid.mean(axis=0)
    n_obs = resid.shape[0]

    const = params.loc["const"].values
    lag_mats = [
        params.loc[[f"L{lag}.{c}" for c in cols]].values
        for lag in range(1, lags + 1)
    ]
    if exog is not None:
        exog_mat = params.loc[list(exog.columns)].values
        exog_vals = exog.values[lags:]

    draws = np.full((repl, steps + 1, n, n), np.nan)
    for r in range(repl):
        shocks = resid[rng.integers(0, n_obs, size=n_obs)]
        y = np.empty((n_obs + lags, n))
        y[:lags] = data.values[:lags]
        for t in range(n_obs):
            y_t = const.copy()
            for lag in range(1, lags + 1):
                y_t = y_t + y[lags + t - lag] @ lag_mats[lag - 1]
            if exog is not None:
                y_t = y_t + exog_vals[t] @ exog_mat
            y[lags + t] = y_t + shocks[t]

        sim = pd.DataFrame(y, index=data.index, columns=cols)
        try:
            draws[r] = VAR(sim, exog=exog).fit(lags).irf(steps).orth_irfs
        except Exception:
            continue

    lower = np.nanpercentile(draws, 100 * signif / 2, axis=0)
    upper = np.nanpercentile(draws, 100 * (1 - signif / 2), axis=0)
    return lower, upper


def plot_irfs(irf_values, lower, upper, variables, out_dir, signif):
    """One figure per response variable, one panel per shock."""
    n = len(variables)
    n_rows = math.ceil(n / 2)
    horizons = np.arange(irf_values.shape[0])
    level = int((1 - signif) * 100)

    for i, response in enumerate(variables):
        fig, axes = plt.subplots(n_rows, 2, figsize=(16, 4.5 * n_rows))
        axes = axes.flatten()

        for j, impulse in enumerate(variables):
            ax = axes[j]
            ax.plot(horizons, irf_values[:, i, j], linewidth=2)
            ax.fill_between(
                horizons, lower[:, i, j], upper[:, i, j], alpha=0.2,
                label=f"{level}% bootstrap interval",
            )
            ax.axhline(0, color="black", linewidth=0.8)
            ax.set_title(f"Shock: {impulse}", fontsize=11)
            ax.set_xlabel("Months after shock")
            ax.set_ylabel(response)
            ax.grid(True, alpha=0.3)

        for ax in axes[n:]:
            ax.set_visible(False)

        fig.suptitle(f"Impulse responses: {response}", fontsize=17, fontweight="bold")
        fig.tight_layout(rect=[0, 0, 1, 0.97])
        fig.savefig(os.path.join(out_dir, f"IRF_{response}.png"),
                    dpi=300, bbox_inches="tight")
        plt.close(fig)


# -------------------------------------------------------- FEVD and stability
def plot_fevd(fevd, out_dir):
    fevd.plot()
    plt.tight_layout()
    plt.savefig(os.path.join(out_dir, "FEVD.png"), dpi=300, bbox_inches="tight")
    plt.close("all")


def plot_inverse_roots(results, out_dir):
    """Inverse roots of the AR polynomial; the VAR is stable if all lie inside."""
    inv_roots = 1.0 / results.roots
    theta = np.linspace(0, 2 * np.pi, 200)

    fig, ax = plt.subplots(figsize=(6, 6))
    ax.plot(np.cos(theta), np.sin(theta), color="gray", linestyle="--", linewidth=1)
    ax.axhline(0, color="gray", linewidth=0.5)
    ax.axvline(0, color="gray", linewidth=0.5)
    ax.scatter(inv_roots.real, inv_roots.imag, color="black", s=30)
    ax.set_xlim(-1.2, 1.2)
    ax.set_ylim(-1.2, 1.2)
    ax.set_aspect("equal")
    ax.set_title("Inverse roots of AR characteristic polynomial")
    ax.set_xlabel("Real")
    ax.set_ylabel("Imaginary")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(os.path.join(out_dir, "inverse_roots.png"), dpi=300)
    plt.close(fig)


# -------------------------------------------------------------------- main
def main():
    os.makedirs(OUT_DIR, exist_ok=True)

    data = build_variables(load_data(DATA_PATH))
    exog = build_dummies(data.index, DUMMY_PERIODS)
    print(f"Sample: {data.index[0]:%Y-%m} to {data.index[-1]:%Y-%m}, "
          f"{len(data)} observations, {data.shape[1]} variables")

    model = VAR(data, exog=exog)
    results = model.fit(LAGS)
    print(results.summary())

    run_diagnostics(data, model, results)

    irf_values = results.irf(IRF_HORIZON).orth_irfs
    print(f"\nBootstrapping IRF bands ({BOOT_REPL} replications)...")
    lower, upper = bootstrap_irf_bands(
        results, data, exog, LAGS, IRF_HORIZON, BOOT_REPL, SIGNIF, SEED
    )
    plot_irfs(irf_values, lower, upper, list(data.columns), OUT_DIR, SIGNIF)

    fevd = results.fevd(FEVD_HORIZON)
    print("\nForecast error variance decomposition")
    fevd.summary()
    plot_fevd(fevd, OUT_DIR)

    plot_inverse_roots(results, OUT_DIR)
    print(f"\nFigures saved to '{OUT_DIR}/'")


if __name__ == "__main__":
    main()
