# Plan de validación y expansión

## Lo comprobado hasta ahora

| Comprobación | Resultado |
|---|---|
| Pruebas unitarias del frontend | 13 pasan |
| Pruebas de la API | 7 pasan |
| Esquema en PostgreSQL WASM con PostGIS | Se aplica y rechaza los casos inválidos |
| Rutas contra fuentes reales (`npm run smoke`) | 34 de 35 el 2026-11-08. Falla la capa ANA D.U. 015-2023: ANA devolvía HTTP 500 en esa pasada, y la interfaz lo indica |
| Recorrido en Chrome headless con WebGL por software | Búsqueda, selección, clic en polígono, fechas, 2D, histórico, móvil |

## Lo que no se ha comprobado

- Rendimiento con GPU real. Solo se probó por software, a menos de 1 fotograma por segundo, así que no dice nada de la fluidez real.
- Dispositivos móviles físicos. Solo emulación a 400 px.
- Lector de pantalla.
- `docker-compose.yml` y el contenedor de PostGIS.
- Carga concurrente de usuarios, ni despliegue en Linux.
- Exactitud de los modelos en Perú: lluvia y caudal se muestran sin verificación local.

## Validación científica

| Producto | Método | Criterio para mostrarlo sin advertencia reforzada |
|---|---|---|
| Lluvia ECMWF | Comparar corridas guardadas con estaciones SENAMHI: sesgo, MAE, CSI por umbral, región y plazo | Métricas publicadas en la app |
| Rango del ensamble | Diagramas de rango, CRPS | Calibración conocida por región |
| Caudal GloFAS | Comparar con estaciones, por cuenca: KGE, sesgo | Solo en cuencas con resultado aceptable, fijado con hidrólogos |
| Aviso de quebradas | Solo describir: cruzar polígonos con eventos reportados. La evaluación oficial corresponde a SENAMHI | Sin índice propio |
| Modelo propio de quebradas | Inventario con fechas, validación temporal, Brier y curva de fiabilidad frente a una referencia | **No se publica como probabilidad si no supera la referencia y no está calibrado** |
| HEC-RAS 2D | Contrastar con huella observada: Sentinel-1, 2017 y 2023. Marcas de agua y sensibilidad | `validated = true` con informe enlazado |

El inventario de INGEMMET no basta para entrenar: muchos registros no tienen fecha de evento, y solo hay casos positivos. Antes hay que reconstruir fechas y casos negativos.

## Revisión de experto

Antes de abrir al público, un hidrólogo y un meteorólogo deben revisar:

1. Los textos de limitación de cada capa.
2. El uso de los colores de nivel en el aviso de quebradas: se asociaron los niveles 2, 3 y 4 a amarillo, naranja y rojo por la clase usada en la tabla de avisos de SENAMHI, no por un documento específico.
3. La lectura de las capas históricas y su leyenda.
4. Si `peligro-masa` y `anomalia` son operativas: el servicio no publica fecha.

## Calidad operativa

| Indicador | Objetivo inicial |
|---|---|
| Interacción fluida con GPU integrada | 30 fps |
| Primer mapa | < 5 s en 4G |
| Antigüedad del aviso de quebradas | < 1 h desde su publicación |
| Fallos de una fuente | No rompen la interfaz; el panel lo indica |

Falta añadir registro estructurado y métricas: hoy solo existe `/api/health` y los registros del servidor.

## Expansión

1. **Etapa 2:** lecturas de estaciones, guardar avisos, migrar a FastAPI.
2. **Etapa 3:** ECMWF Open Data, comparación lado a lado, análisis de exposición.
3. **Etapa 4:** simulaciones en Piura, luego Rímac y Tumbes, y evaluación de pronósticos.
4. **Etapa 5:** asistente, noticias y alertas automáticas.

**Criterio de paso entre etapas:** cada dato nuevo tiene fuente verificada, estado de fallo, prueba de humo y limitación escrita.
