# Tests del enmascarado del código de dispositivo. Se prueba la función
# pura por separado (ahí vive la regla) y también los endpoints por HTTP
# (para confirmar que todos los caminos de lectura realmente la aplican).

import pytest

from app.services.device_service import mask_device_code

PAYLOAD = {"vehicle_name": "Truck 1", "device_code": "DEV-1234-XC54", "plate": "ABC123"}


# Crea un dispositivo de prueba vía la API.
async def _create_device(async_client, admin_headers, **overrides) -> dict:
    response = await async_client.post(
        "/devices", json={**PAYLOAD, **overrides}, headers=admin_headers
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_masks_the_middle_of_a_long_code():
    assert mask_device_code("DEV-1234-XC54") == "DEV-****-XC54"


def test_short_code_keeps_only_its_prefix():
    # "DEV-001" no tiene nada entre el prefijo y el final: mostrar el final
    # revelaría el identificador completo, justo lo que se quiere proteger.
    assert mask_device_code("DEV-001") == "DEV-****"


def test_masked_code_never_contains_the_hidden_middle():
    masked = mask_device_code("DEV-SECRET99-XC54")
    assert "SECRET" not in masked


def test_shortest_maskable_code_still_hides_two_characters():
    # Caso límite: 9 caracteres es el primer largo que todavía deja mostrar un final.
    assert mask_device_code("ABC123456") == "ABC-****-3456"
    assert mask_device_code("ABC12345") == "ABC-****"


def test_masking_is_stable():
    # Mismo código de entrada, mismo resultado siempre: quien mira una lista
    # debe ver un solo código por vehículo, no uno que cambia entre filas o requests.
    assert mask_device_code("DEV-1234-XC54") == mask_device_code("DEV-1234-XC54")


@pytest.mark.asyncio
async def test_admin_reads_the_whole_code(async_client, admin_headers):
    created = await _create_device(async_client, admin_headers)

    response = await async_client.get("/devices", headers=admin_headers)
    assert response.status_code == 200
    assert response.json()[0]["device_code"] == "DEV-1234-XC54"

    detail = await async_client.get(f"/devices/{created['id']}", headers=admin_headers)
    assert detail.json()["device_code"] == "DEV-1234-XC54"


@pytest.mark.asyncio
async def test_non_admin_reads_a_masked_code_from_both_routes(
    async_client, admin_headers, user_headers
):
    created = await _create_device(async_client, admin_headers)

    listed = await async_client.get("/devices", headers=user_headers)
    assert listed.status_code == 200
    assert listed.json()[0]["device_code"] == "DEV-****-XC54"

    detail = await async_client.get(f"/devices/{created['id']}", headers=user_headers)
    assert detail.status_code == 200
    assert detail.json()["device_code"] == "DEV-****-XC54"


@pytest.mark.asyncio
async def test_masking_leaves_the_rest_of_the_device_untouched(
    async_client, admin_headers, user_headers
):
    # Solo el código es sensible: el enmascarado no debe convertirse en un
    # segundo sistema de permisos silencioso sobre campos que sí debería ver.
    created = await _create_device(async_client, admin_headers)

    detail = await async_client.get(f"/devices/{created['id']}", headers=user_headers)
    body = detail.json()
    assert body["id"] == created["id"]
    assert body["vehicle_name"] == created["vehicle_name"]
    assert body["plate"] == created["plate"]
    assert body["is_active"] == created["is_active"]
