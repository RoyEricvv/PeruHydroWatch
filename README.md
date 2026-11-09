# Perú HydroWatch 3D

Plataforma geoespacial para seguir lluvias, quebradas, ríos y avisos oficiales en los 24 departamentos del Perú y el Callao.

**No sustituye a los avisos oficiales.** No calcula probabilidades propias de activación ni de inundación.

## Arrancar

En Windows, sin instalar nada en el sistema (usa Node portable en `.tools/`):

```powershell
.\dev.ps1                # desarrollo, en http://localhost:3000
.\dev.ps1 -Prod          # compila y sirve en modo producción
.\dev.ps1 -RefreshData   # vuelve a descargar los datos oficiales
```

Con Node 24 en cualquier sistema:

```bash
cd frontend
npm ci
NODE_OPTIONS=--use-system-ca npm run data   # solo si falta public/data
NODE_OPTIONS=--use-system-ca npm run dev
```

No hacen falta claves de API. `--use-system-ca` es necesario porque el servidor de INGEMMET no envía su certificado intermedio: **no desactives la verificación TLS**. En Linux, instala ese certificado con `NODE_EXTRA_CA_CERTS`.

Tras arrancar, conviene precargar las capas lentas de INGEMMET (20-45 s por tesela la primera vez):

```powershell
cd frontend; npm run warm
```

## Qué hay hoy

| Módulo | Estado |
|---|---|
| Visor 3D con relieve real, 2D, navegación, búsqueda en 3535 lugares | Funciona |
| Avisos de SENAMHI y estado de alerta de ENFEN, en vivo | Funciona |
| Polígonos del aviso de activación de quebradas | Funciona |
| Mapa de lluvia del modelo ECMWF animado por fecha | Funciona |
| Lluvia, ensamble y caudal simulado por punto | Funciona; son modelos, no mediciones |
| Comparación con 1982-83, 1997-98, 2017 y 2023 | Funciona: mapas SENAMHI y curvas ERA5 |
| Inventario INGEMMET: 37 826 eventos | Funciona |
| Susceptibilidad, red vial, centros poblados | Funciona |
| Lecturas de estaciones (nivel, caudal) y umbrales | **Pendiente, Etapa 2** |
| Exposición con PostGIS, noticias, mapas lado a lado | **Pendiente, Etapa 3 y 5** |
| HEC-HMS / HEC-RAS 2D, asistente RAG | **Pendiente, Etapas 4 y 5** |
| API FastAPI, PostGIS, Redis, objetos | Esqueleto; la app aún no los usa |

## Entregables

| # | Entregable | Dónde |
|---|---|---|
| 1 | Arquitectura general | [docs/ARQUITECTURA.md](docs/ARQUITECTURA.md) |
| 2 | Diseño de la interfaz | [docs/INTERFAZ.md](docs/INTERFAZ.md) |
| 3 | Estructura del proyecto | [docs/ESTRUCTURA-Y-COMPONENTES.md](docs/ESTRUCTURA-Y-COMPONENTES.md) |
| 4 | Modelo de base de datos | [docs/MODELO-DE-DATOS.md](docs/MODELO-DE-DATOS.md), [backend/db/schema.sql](backend/db/schema.sql) |
| 5 | Catálogo de fuentes verificadas | [docs/CATALOGO-DE-FUENTES.md](docs/CATALOGO-DE-FUENTES.md), y dentro de la app |
| 6 | Componentes reutilizables | [docs/ESTRUCTURA-Y-COMPONENTES.md](docs/ESTRUCTURA-Y-COMPONENTES.md) |
| 7 | Visor 3D funcional | [frontend/src/components/map/CesiumMap.tsx](frontend/src/components/map/CesiumMap.tsx) |
| 8 | MVP ejecutable | Esta carpeta: `.\dev.ps1` |
| 9 | Plan de integración de datos | [docs/PLAN-DE-DATOS.md](docs/PLAN-DE-DATOS.md) |
| 10 | Plan de validación y expansión | [docs/PLAN-DE-VALIDACION.md](docs/PLAN-DE-VALIDACION.md) |

## Comprobaciones

```powershell
cd frontend
npm test            # parsers, geometría, horizontes
npm run typecheck
npm run smoke       # con la app en marcha: cada API contra datos reales
npm run shot -- salida all   # recorrido en Chrome con capturas
```

```powershell
cd backend
uv run --extra dev pytest -q
```

## Decisiones que requieren a una persona

1. **Uso comercial.** Open-Meteo es gratuito solo para uso no comercial, y Esri World Imagery tiene términos propios. Si el producto será comercial, contrata ambos o cámbialos.
2. **Permisos institucionales.** INGEMMET, ANA y SENAMHI no publican licencia en sus servicios. Confirma antes de redistribuir copias de sus datos.
3. **CENEPRED.** El `robots.txt` de SIGRID prohíbe `/arcgis/` a procesos automáticos. Hay que pedir convenio.
