"""API de Perú HydroWatch 3D (esqueleto de la Etapa 2).

En la Etapa 1 la app Next.js consulta las fuentes directamente con caché en disco.
Este servicio es el destino de esa lógica: expone el catálogo y la salud de la base,
y crecerá con ingesta, series y análisis PostGIS. Hoy no sirve datos hidrológicos:
un endpoint que aún no tiene datos responde 501, nunca valores de relleno.
"""

from __future__ import annotations

import json
import logging
import os
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware

from .notices import parse_avisos

log = logging.getLogger("hydrowatch")
logging.basicConfig(level=os.getenv("LOG_LEVEL", "INFO"))

CATALOG_PATH = Path(os.getenv("CATALOG_PATH", Path(__file__).parent / "sources.json"))
DATABASE_URL = os.getenv("DATABASE_URL")
PERU_BOUNDS = {"west": -85.0, "south": -22.0, "east": -65.0, "north": 3.0}

app = FastAPI(title="Perú HydroWatch 3D API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CORS_ORIGINS", "http://localhost:3000").split(","),
    allow_methods=["GET"],
    allow_headers=["*"],
)


def load_catalog() -> list[dict[str, Any]]:
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


@app.get("/health")
async def health() -> dict[str, Any]:
    """Estado del servicio. `database` dice la verdad: no configurada, accesible o caída."""
    state = "no_configurada"
    if DATABASE_URL:
        try:
            import psycopg

            async with await psycopg.AsyncConnection.connect(DATABASE_URL, connect_timeout=3) as conn:
                row = await (await conn.execute("SELECT postgis_version()")).fetchone()
                state = f"ok ({row[0]})"
        except Exception as exc:  # noqa: BLE001 - se informa, no se oculta
            log.warning("Base de datos no accesible: %s", exc)
            state = "error"
    return {"status": "ok", "database": state, "version": app.version}


@app.get("/v1/sources")
async def sources(state: str | None = Query(default=None)) -> list[dict[str, Any]]:
    items = load_catalog()
    return [s for s in items if s["state"] == state] if state else items


@app.get("/v1/sources/{source_id}")
async def source(source_id: str) -> dict[str, Any]:
    for s in load_catalog():
        if s["id"] == source_id:
            return s
    raise HTTPException(404, "Fuente desconocida")


@app.get("/v1/stations/{station_id}/series")
async def station_series(station_id: str) -> None:
    raise HTTPException(501, "Series de estaciones no integradas (Etapa 2). No se devuelven valores de relleno.")


@app.get("/v1/exposure")
async def exposure(
    west: float = Query(ge=PERU_BOUNDS["west"], le=PERU_BOUNDS["east"]),
    south: float = Query(ge=PERU_BOUNDS["south"], le=PERU_BOUNDS["north"]),
    east: float = Query(ge=PERU_BOUNDS["west"], le=PERU_BOUNDS["east"]),
    north: float = Query(ge=PERU_BOUNDS["south"], le=PERU_BOUNDS["north"]),
) -> None:
    if west >= east or south >= north:
        raise HTTPException(422, "Rectángulo inválido")
    raise HTTPException(501, "Análisis de exposición no integrado (Etapa 3).")


__all__ = ["app", "parse_avisos"]
