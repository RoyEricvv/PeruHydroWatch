# Estructura del proyecto y componentes

```
web/
├── dev.ps1                       Arranque en Windows sin instalar nada
├── docker-compose.yml            PostGIS, Redis, objetos, API (Etapa 2)
├── docs/                         Esta documentación
├── backend/
│   ├── app/main.py               API: catálogo y salud; 501 donde aún no hay datos
│   ├── app/notices.py            Parser de avisos para la futura ingesta
│   ├── app/sources.json          Exportado desde frontend/src/lib/sources.ts
│   ├── db/schema.sql             Modelo de datos
│   └── tests/
└── frontend/
    ├── scripts/
    │   ├── build-data.mjs        Pipeline de datos con procedencia
    │   ├── warm-tiles.mjs        Precarga de teselas lentas
    │   ├── smoke-api.mjs         Prueba de cada API contra datos reales
    │   └── screenshot.mjs        Recorrido en Chrome con capturas
    ├── public/data/              Copias locales y manifest.json
    ├── tests/                    Pruebas unitarias
    └── src/
        ├── app/api/              Rutas: avisos, quebradas, enfen, enso, grid,
        │                         point, history, health, tiles, legend
        ├── components/           Interfaz (ver abajo)
        └── lib/
            ├── layers.ts         Registro único de capas
            ├── sources.ts        Catálogo de fuentes
            ├── parse.ts          Parsers puros, con pruebas
            ├── store.ts          Estado global
            ├── time.ts           Fechas en hora de Lima, horizontes
            ├── server/cache.ts   Caché, reintentos, límite por host
            └── map/              terrain, heat, geo, selection
```

## Componentes reutilizables

| Componente | Función | Para reutilizarlo |
|---|---|---|
| `ClassChip` | Etiqueta la clase del dato | Pasar una `DataClass` |
| `LevelBadge` | Nivel oficial con color, icono y texto | Pasar `level` y `text` |
| `Provenance` | Fuente, antigüedad y copia guardada | Debajo de todo dato |
| `Notice` | Limitación o advertencia | `tone="warn"` si afecta a la lectura |
| `Stat` | Cifra con unidad | Sin color de serie |
| `Skeleton` | Espera con `aria-busy` | Indicar altura |
| `Chart` | ECharts con redimensionado y vista de tabla | Pasar `option`, `label`, `table` |
| `Card` | Sección del panel | Título y contenido |
| `useApi` | Datos con refresco; conserva el último dato si falla | URL e intervalo |
| `HeatLegend` | Escala por bandas | Lee `BANDS` |

## Añadir una capa

1. Verifica el servicio contra su URL real: `GetCapabilities`, una tesela y su leyenda.
2. Agrégala a `LAYERS` en `lib/layers.ts` con `dataClass`, `note` y `caveat`.
3. Si es una fuente nueva, añádela a `lib/sources.ts` con lo verificado.
4. Añádela a `smoke-api.mjs`.

No hay más pasos: visor, panel, proxy y leyenda leen del registro.

## Módulos de servidor

| Función | Contrato |
|---|---|
| `cachedJson(ns, key, ttl, fetcher)` | Devuelve `{data, retrievedAt, stale}`. Si falla y hay copia, `stale: true`. Si no hay copia, lanza error |
| `cachedBinary(...)` | Igual para teselas; `null` si no hay nada que servir |
| `politeFetch(url, timeout, init, attempts)` | Límite por host y reintentos de conexión |

## Cuidado con estas fuentes

- **Susceptibilidad de INGEMMET.** No uses `SERV_IMG_SUSCEP_*`: sus códigos no coinciden con los mapas publicados. En (-76.9, -11.9) el raster da 5 y el vector da 4, y el raster de inundación tiene 4 clases frente a 3. Usa los `MapServer`.
- **Aviso de quebradas.** El DBF está en ISO-8859-1, declarado en un `.cst` que `shpjs` no lee. La ruta ya lo resuelve.
- **ENFEN.** Algunos comunicados no llevan el estado en el RSS. Se lee de su página; nunca se hereda del anterior.
- **`adm0.json`.** `mapshaper` emite `GeometryCollection` tras `-dissolve`; el pipeline lo normaliza.
