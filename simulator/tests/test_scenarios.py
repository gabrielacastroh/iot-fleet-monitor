import pytest

from simulator.scenarios import (
    DEFAULT_SCENARIO,
    SCENARIOS,
    VehicleProfile,
    expand,
    profiles_from_dicts,
    resolve,
)


def test_default_scenario_builds_one_normal_profile_sized_by_device_count():
    profiles = resolve(DEFAULT_SCENARIO, device_count=4, profiles=None)

    assert len(profiles) == 1
    assert profiles[0].count == 4
    assert profiles[0].fuel_min == 60.0


def test_named_scenario_ignores_device_count():
    profiles = resolve("demo", device_count=99, profiles=None)

    assert profiles is SCENARIOS["demo"]


def test_explicit_profiles_win_over_a_named_scenario():
    custom = (VehicleProfile(label="mine", count=2),)

    assert resolve("demo", device_count=5, profiles=custom) is custom


def test_unknown_scenario_names_the_valid_choices():
    with pytest.raises(ValueError, match="unknown scenario"):
        resolve("nope", device_count=1, profiles=None)


def test_expand_yields_one_profile_per_vehicle_in_declaration_order():
    profiles = (
        VehicleProfile(label="a", count=2),
        VehicleProfile(label="b", count=1),
    )

    labels = [profile.label for profile in expand(profiles)]

    assert labels == ["a", "a", "b"]
    assert all(profile.count == 1 for profile in expand(profiles))


def test_demo_scenario_covers_every_state_the_dashboard_renders():
    """The demo has to be able to show all four states, or it cannot stand in
    for the walkthrough in SETUP.md."""
    profiles = expand(SCENARIOS["demo"])
    by_label = {profile.label for profile in profiles}

    assert by_label == {"normal", "critical", "no-signal", "inactive"}
    # A vehicle whose gauge reads normal but whose burn rate makes autonomy
    # short — that is the whole point of a predictive rule.
    critical = next(p for p in profiles if p.label == "critical")
    assert critical.consumption_per_hour is not None
    assert critical.fuel_min > 20.0
    # Silent and inactive vehicles must not report, or last_seen_at stops
    # telling those two states apart from a working one.
    assert next(p for p in profiles if p.label == "no-signal").silent_after_ticks == 0
    inactive = next(p for p in profiles if p.label == "inactive")
    assert inactive.is_active is False
    assert inactive.silent_after_ticks == 0


def test_profiles_from_dicts_builds_profiles():
    profiles = profiles_from_dicts(
        [{"label": "low", "count": 2, "fuel_min": 10.0, "fuel_max": 12.0}]
    )

    assert profiles[0].label == "low"
    assert profiles[0].count == 2
    assert profiles[0].fuel_max == 12.0


def test_profiles_from_dicts_rejects_a_misspelled_key():
    """Silently ignoring a typo builds the default fleet and the mistake only
    surfaces once the demo is already running."""
    with pytest.raises(ValueError, match="unknown profile keys"):
        profiles_from_dicts([{"label": "low", "fuel_minimum": 10.0}])


def test_profiles_from_dicts_rejects_an_empty_list():
    with pytest.raises(ValueError, match="non-empty"):
        profiles_from_dicts([])


@pytest.mark.parametrize(
    "profile",
    [
        VehicleProfile(label="x", count=0),
        VehicleProfile(label="x", fuel_min=50.0, fuel_max=10.0),
        VehicleProfile(label="x", fuel_max=120.0),
        VehicleProfile(label="x", consumption_per_hour=-1.0),
        VehicleProfile(label="x", silent_after_ticks=-1),
    ],
)
def test_invalid_profiles_are_rejected(profile):
    with pytest.raises(ValueError):
        profile.validate()
