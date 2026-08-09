import pytest

from simulator.config import load_config


def test_requires_email_and_password():
    with pytest.raises(ValueError):
        load_config(["--devices", "3"])


def test_cli_flags_override_defaults():
    config = load_config(
        ["--email", "a@a.com", "--password", "x", "--devices", "7", "--interval", "2.5"]
    )
    assert config.device_count == 7
    assert config.interval_seconds == 2.5


def test_config_file_supplies_the_base_values(tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text('{"device_count": 12, "email": "file@a.com", "password": "filepass"}')

    config = load_config(["--config", str(config_path)])

    assert config.device_count == 12
    assert config.email == "file@a.com"


def test_cli_flags_override_the_config_file(tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text('{"device_count": 12, "email": "file@a.com", "password": "filepass"}')

    config = load_config(["--config", str(config_path), "--devices", "3"])

    assert config.device_count == 3


def test_env_credentials_override_the_config_file(tmp_path, monkeypatch):
    config_path = tmp_path / "config.json"
    config_path.write_text('{"email": "file@a.com", "password": "filepass"}')
    monkeypatch.setenv("SIMULATOR_EMAIL", "env@a.com")

    config = load_config(["--config", str(config_path)])

    assert config.email == "env@a.com"


def test_cli_credentials_override_the_environment(monkeypatch):
    monkeypatch.setenv("SIMULATOR_EMAIL", "env@a.com")

    config = load_config(["--email", "cli@a.com", "--password", "x"])

    assert config.email == "cli@a.com"


def test_center_flag_sets_both_coordinates():
    config = load_config(
        ["--email", "a@a.com", "--password", "x", "--center", "10.0", "20.0"]
    )
    assert config.center_latitude == 10.0
    assert config.center_longitude == 20.0


def test_rejects_a_non_positive_interval():
    with pytest.raises(ValueError):
        load_config(["--email", "a@a.com", "--password", "x", "--interval", "0"])


def test_rejects_fewer_than_one_device():
    with pytest.raises(ValueError):
        load_config(["--email", "a@a.com", "--password", "x", "--devices", "0"])


def _base(*extra: str) -> list[str]:
    return ["--email", "a@a.com", "--password", "x", *extra]


def test_the_default_interval_keeps_the_backends_fuel_window_wide_enough():
    """At a few seconds per reading the backend's twenty-sample window covers
    barely a minute of driving, and the consumption it measures then swings
    across the one-hour threshold on sensor noise alone."""
    config = load_config(_base())

    assert config.interval_seconds >= 30.0


def test_seed_flag_is_read():
    assert load_config(_base("--seed", "42")).seed == 42


def test_no_seed_leaves_the_run_random():
    assert load_config(_base()).seed is None


def test_scenario_flag_selects_a_fleet_composition():
    config = load_config(_base("--scenario", "demo"))

    assert config.scenario == "demo"
    assert len(config.fleet_profiles()) > 1


def test_default_scenario_follows_device_count():
    config = load_config(_base("--devices", "3"))

    profiles = config.fleet_profiles()
    assert len(profiles) == 1
    assert profiles[0].count == 3


def test_rejects_an_unknown_scenario_at_startup():
    """Better than discovering the typo after the fleet has already logged in."""
    with pytest.raises(ValueError, match="unknown scenario"):
        load_config(_base("--scenario", "nope"))


def test_rejects_negative_jitter():
    with pytest.raises(ValueError):
        load_config(_base("--jitter", "-1"))


def test_config_file_can_describe_the_fleet_profile_by_profile(tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text(
        '{"email": "a@a.com", "password": "x", "profiles": ['
        '{"label": "normal", "count": 2},'
        '{"label": "thirsty", "count": 1, "fuel_min": 30.0, "fuel_max": 35.0,'
        ' "consumption_per_hour": 50.0}]}'
    )

    config = load_config(["--config", str(config_path)])

    profiles = config.fleet_profiles()
    assert [p.label for p in profiles] == ["normal", "thirsty"]
    assert profiles[1].consumption_per_hour == 50.0


def test_explicit_profiles_override_a_named_scenario(tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text(
        '{"email": "a@a.com", "password": "x", "profiles": [{"label": "only", "count": 1}]}'
    )

    config = load_config(["--config", str(config_path), "--scenario", "demo"])

    assert [p.label for p in config.fleet_profiles()] == ["only"]


def test_rejects_an_invalid_profile_in_a_config_file(tmp_path):
    config_path = tmp_path / "config.json"
    config_path.write_text(
        '{"email": "a@a.com", "password": "x",'
        ' "profiles": [{"label": "bad", "fuel_min": 90.0, "fuel_max": 10.0}]}'
    )

    with pytest.raises(ValueError):
        load_config(["--config", str(config_path)])
