"""Parser de avisos de SENAMHI para el futuro servicio de ingesta.

Misma lógica que `frontend/src/lib/parse.ts`. Si la página cambia devuelve una lista vacía:
la ingesta debe registrarlo como fallo en lugar de escribir filas dudosas.
"""

from __future__ import annotations

import html as html_lib
import re
from dataclasses import dataclass

LEVELS = ("ROJO", "NARANJA", "AMARILLO", "VERDE")
_ROW = re.compile(r'<tr>\s*<td\s+class="[^"]*"[\s\S]*?</tr>')
_CELL = re.compile(r"<td[^>]*>([\s\S]*?)(?=</td>)")
_HREF = re.compile(r'href="\.?/?(\?p=aviso-meteorologico-[^"]+)"')
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _strip(fragment: str) -> str:
    text = re.sub(r"<[^>]+>", " ", fragment)
    return re.sub(r"\s+", " ", html_lib.unescape(text)).strip()


@dataclass(frozen=True)
class Aviso:
    titulo: str
    numero: int | None
    estado: str
    emision: str
    inicio: str
    fin: str
    duracion: str
    nivel: str
    url: str


def parse_avisos(page: str) -> list[Aviso]:
    out: list[Aviso] = []
    for row in _ROW.findall(page):
        href = _HREF.search(row)
        if not href:
            continue
        cells = [_strip(c) for c in _CELL.findall(row)]
        if len(cells) < 7 or not _DATE.match(cells[2]):
            continue
        num = re.search(r"\d+", cells[1])
        state = re.search(r"\(([^)]+)\)", cells[1])
        raw_level = cells[6].upper()
        out.append(
            Aviso(
                titulo=cells[0],
                numero=int(num.group()) if num else None,
                estado=state.group(1).lower() if state else "desconocido",
                emision=cells[2],
                inicio=cells[3],
                fin=cells[4],
                duracion=cells[5],
                nivel=next((lv for lv in LEVELS if lv in raw_level), "DESCONOCIDO"),
                url="https://www.senamhi.gob.pe/" + href.group(1).replace("&amp;", "&"),
            )
        )
    return out
