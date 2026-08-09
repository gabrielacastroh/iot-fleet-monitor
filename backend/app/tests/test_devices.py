import uuid

import pytest

PAYLOAD = {"vehicle_name": "Truck 1", "device_code": "dev-1", "plate": "abc123"}


# Crea un dispositivo de prueba vía la API.
async def _create_device(async_client, admin_headers, **overrides) -> dict:
    response = await async_client.post(
        "/devices", json={**PAYLOAD, **overrides}, headers=admin_headers
    )
    assert response.status_code == 201, response.text
    return response.json()


@pytest.mark.asyncio
async def test_list_devices_requires_authentication(async_client):
    response = await async_client.get("/devices")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_create_normalizes_code_and_plate(async_client, admin_headers):
    created = await _create_device(async_client, admin_headers)
    # Código y matrícula se guardan en mayúsculas para que la búsqueda no
    # falle por diferencias de mayúsculas/minúsculas.
    assert created["device_code"] == "DEV-1"
    assert created["plate"] == "ABC123"
    assert created["is_active"] is True


@pytest.mark.asyncio
async def test_any_authenticated_user_can_read(async_client, admin_headers, user_headers):
    created = await _create_device(async_client, admin_headers)

    list_response = await async_client.get("/devices", headers=user_headers)
    assert list_response.status_code == 200
    assert [device["id"] for device in list_response.json()] == [created["id"]]

    detail_response = await async_client.get(f"/devices/{created['id']}", headers=user_headers)
    assert detail_response.status_code == 200


@pytest.mark.asyncio
async def test_non_admin_cannot_write(async_client, admin_headers, user_headers):
    created = await _create_device(async_client, admin_headers)

    assert (await async_client.post("/devices", json=PAYLOAD, headers=user_headers)).status_code == 403
    patch_response = await async_client.patch(
        f"/devices/{created['id']}", json={"vehicle_name": "Hacked"}, headers=user_headers
    )
    assert patch_response.status_code == 403
    delete_response = await async_client.delete(f"/devices/{created['id']}", headers=user_headers)
    assert delete_response.status_code == 403


@pytest.mark.asyncio
async def test_create_rejects_duplicate_device_code(async_client, admin_headers):
    await _create_device(async_client, admin_headers)

    response = await async_client.post(
        "/devices", json={**PAYLOAD, "plate": "XYZ789"}, headers=admin_headers
    )
    assert response.status_code == 409
    # El cliente muestra un mensaje por campo, así que el campo que chocó
    # tiene que venir identificado, no solo mencionado en un texto.
    assert response.json()["detail"]["field"] == "device_code"


@pytest.mark.asyncio
async def test_create_rejects_duplicate_plate(async_client, admin_headers):
    await _create_device(async_client, admin_headers)

    response = await async_client.post(
        "/devices", json={**PAYLOAD, "device_code": "DEV-2"}, headers=admin_headers
    )
    assert response.status_code == 409
    assert response.json()["detail"]["field"] == "plate"


@pytest.mark.asyncio
async def test_patch_only_touches_sent_fields(async_client, admin_headers):
    created = await _create_device(async_client, admin_headers)

    response = await async_client.patch(
        f"/devices/{created['id']}", json={"is_active": False}, headers=admin_headers
    )
    assert response.status_code == 200
    updated = response.json()
    assert updated["is_active"] is False
    assert updated["vehicle_name"] == created["vehicle_name"]
    assert updated["device_code"] == created["device_code"]


@pytest.mark.asyncio
async def test_patch_allows_keeping_its_own_device_code(async_client, admin_headers):
    created = await _create_device(async_client, admin_headers)

    response = await async_client.patch(
        f"/devices/{created['id']}",
        json={"device_code": "dev-1", "vehicle_name": "Truck 2"},
        headers=admin_headers,
    )
    assert response.status_code == 200
    assert response.json()["vehicle_name"] == "Truck 2"


@pytest.mark.asyncio
async def test_patch_rejects_code_taken_by_another_device(async_client, admin_headers):
    first = await _create_device(async_client, admin_headers)
    await _create_device(async_client, admin_headers, device_code="DEV-2", plate="XYZ789")

    response = await async_client.patch(
        f"/devices/{first['id']}", json={"device_code": "DEV-2"}, headers=admin_headers
    )
    assert response.status_code == 409


@pytest.mark.asyncio
async def test_delete_removes_device(async_client, admin_headers):
    created = await _create_device(async_client, admin_headers)

    delete_response = await async_client.delete(f"/devices/{created['id']}", headers=admin_headers)
    assert delete_response.status_code == 204

    detail_response = await async_client.get(f"/devices/{created['id']}", headers=admin_headers)
    assert detail_response.status_code == 404


@pytest.mark.asyncio
async def test_unknown_device_returns_404(async_client, admin_headers):
    unknown_id = uuid.uuid4()

    assert (await async_client.get(f"/devices/{unknown_id}", headers=admin_headers)).status_code == 404
    patch_response = await async_client.patch(
        f"/devices/{unknown_id}", json={"vehicle_name": "Ghost"}, headers=admin_headers
    )
    assert patch_response.status_code == 404
    assert (
        await async_client.delete(f"/devices/{unknown_id}", headers=admin_headers)
    ).status_code == 404
