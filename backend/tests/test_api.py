from fastapi.testclient import TestClient

from app.main import app, load_catalog
from app.notices import parse_avisos

client = TestClient(app)

PAGE = """
<tr>
  <td  class="emitido"><a href="./?p=aviso-meteorologico-vigente&a=2026&b=29359&c=00&d=SENA">PRECIPITACIONES EN LA COSTA Y SIERRA</td>
  <td  class="emitido"><a href="./?p=aviso-meteorologico-vigente&a=2026&b=29359&c=00&d=SENA">462 (emitido) </td>
  <td  class="emitido">2026-11-07</td>
  <td  class="emitido">2026-11-09</td>
  <td  class="emitido">2026-11-11</td>
  <td  class="emitido">71 Hrs. </td>
  <td  class="emitido"><span class="cuatro">ROJO</span></td>
</tr>
"""


def test_health_sin_base_lo_dice():
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["database"] == "no_configurada"


def test_catalogo_completo_y_veraz():
    data = client.get("/v1/sources").json()
    assert len(data) >= 10
    for s in data:
        assert s["url"].startswith("https://")
        assert s["license"]
    sigrid = client.get("/v1/sources/cenepred-sigrid").json()
    assert sigrid["state"] == "restringida"
    assert sigrid["probe"] is None, "SIGRID prohíbe /arcgis/ en robots.txt: no debe sondearse"


def test_filtro_y_desconocida():
    assert all(s["state"] == "pendiente" for s in client.get("/v1/sources", params={"state": "pendiente"}).json())
    assert client.get("/v1/sources/inventada").status_code == 404


def test_sin_datos_responde_501_no_relleno():
    assert client.get("/v1/stations/204504/series").status_code == 501
    assert client.get("/v1/exposure", params={"west": -80, "south": -6, "east": -79, "north": -5}).status_code == 501


def test_exposicion_valida_rectangulo():
    assert client.get("/v1/exposure", params={"west": -79, "south": -6, "east": -80, "north": -5}).status_code == 422
    assert client.get("/v1/exposure", params={"west": 10, "south": -6, "east": 11, "north": -5}).status_code == 422


def test_parser_avisos():
    a = parse_avisos(PAGE)[0]
    assert (a.numero, a.estado, a.inicio, a.nivel) == (462, "emitido", "2026-11-09", "ROJO")
    assert parse_avisos("<html>mantenimiento</html>") == []
    assert parse_avisos(PAGE.replace("ROJO", "MORADO"))[0].nivel == "DESCONOCIDO"


def test_catalogo_cargable():
    assert any(s["id"] == "senamhi-avisos" for s in load_catalog())
