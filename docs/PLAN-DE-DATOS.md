# Plan de integración de datos reales

Prioridades según el contexto actual: el Comunicado ENFEN N.° 19-2026 mantiene la **Alerta de El Niño Costero**, con lluvias sobre lo normal en la costa norte y central y ríos priorizados: **Tumbes, Chira, Piura, La Leche, Jequetepeque, y desde diciembre Chillón, Rímac y Lurín**.

## Ya integrado

Ver el [catálogo](CATALOGO-DE-FUENTES.md).

## Etapa 2: observaciones y avisos

| Prioridad | Tarea | Fuente | Lo que se sabe | Por averiguar |
|---|---|---|---|---|
| 1 | Lecturas de nivel y caudal | SENAMHI | 259 estaciones hidrológicas con ubicación vía WFS. La página menciona un "Observatorio Nacional del Tiempo, Agua y Clima" | Si hay servicio de lecturas o solo páginas. **Es la mayor carencia** |
| 2 | Umbrales oficiales de ríos | ANA, SENAMHI | No localizados | Dónde se publican por estación |
| 3 | Avisos hidrológicos | SENAMHI | `?p=avisos-hidrologicos` existe y tiene vista de mapa | Formato y estructura |
| 4 | Detalle de avisos: áreas y texto | SENAMHI | La tabla enlaza al detalle; WMS `g_aviso:view_aviso` | Cómo asociar polígono y número |
| 5 | Monitoreo de lluvia | SENAMHI | IDESEP tiene `dhi_vigi_moni_hidro` (81 capas) | Qué representan y su fecha |
| 6 | Pasar la lógica a FastAPI y PostGIS | Propio | Esquema validado | Cargas iniciales y horarios |
| 7 | Guardar cada aviso diario | SENAMHI | ZIP diario desde al menos octubre | Antigüedad disponible. Permite evaluar aciertos |
| 8 | Emergencias de INDECI | INDECI | RSS probado: HTTP 400. ENFEN cita el "Visor 11" | Servicio y condiciones |

## Etapa 3: mapas y territorio

| Tarea | Fuente | Nota |
|---|---|---|
| Lluvia observada propia | CHIRPS, GES DISC IMERG | La URL probada de CHIRPS dio 404: hallar la vigente. GIBS solo da imagen |
| Malla 0.25° de pronóstico | ECMWF Open Data | Sustituye al muestreo de 0.75° y evita la cuota de Open-Meteo |
| Anomalías con climatología | ERA5 y CDS | Requiere registro; base 1991-2020 |
| Producto SONICS de humedad | SENAMHI `dhi-seh-sonics` | 57 capas con pronóstico a 7 días; confirmar método |
| Exposición: salud, educación, puentes | MINSA, MINEDU, MTC | Sin verificar; SIGRID restringe procesos automáticos |
| Población | INEI | Sin verificar |
| Convenio con CENEPRED | SIGRID | Escenarios de riesgo. Solicitud formal |
| Comparación lado a lado | MapLibre | Dos mapas sincronizados, datos ya disponibles |
| Eventos históricos | INDECI, ANA, INGEMMET | Distritos, vías, daños; marcar los vacíos |

## Etapa 4: pronósticos y simulación

Cuencas sugeridas, por el comunicado de ENFEN: **Piura** primero, luego Rímac y Tumbes.

1. HEC-HMS: requiere DEM, suelos, cobertura, lluvia y caudales para calibrar.
2. HEC-RAS 2D: requiere DEM de alta resolución y secciones de río. **Terrarium no sirve para esto.**
3. Publicar extensión y profundidad solo con `validated = true` y evidencia enlazada.
4. Pronóstico estacional: evaluar productos oficiales de probabilidad. Open-Meteo ofrece una API estacional, respondió en las pruebas pero no se ha evaluado.
5. Archivar cada emisión para evaluar su desempeño.

## Etapa 5: asistente y noticias

- **Noticias.** GDELT respondió 429 en la prueba: revisar sus límites. Definir la lista de RSS autorizados.
- **Asistente.** El modelo de lenguaje solo accede a herramientas con parámetros fijos: consulta espacial, serie, documento. Toda cifra debe salir de una herramienta, con fuente y fecha. Si no hay dato, responde que no hay dato.
- **Cuando el asistente diga "qué cambió en 24 h"**, compara filas guardadas, no lo que el modelo recuerde.

## Reglas para cada fuente nueva

1. Probar el servicio real y anotar lo probado.
2. Leer `robots.txt` y condiciones **antes** de la primera consulta automática.
3. Comprobar que leyenda y dato coinciden en un punto conocido.
4. Registrar frecuencia real y latencia; la interfaz no debe sugerir tiempo real.
5. Añadir prueba de humo y estado de fallo.
