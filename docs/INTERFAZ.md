# Diseño de la interfaz

## Disposición

```
┌───────────────────────────────────────────────────────────────┐
│ Logo · Buscador · Fecha · ENFEN · SENAMHI · Fuentes · 2D/3D   │
├─────────┬───────────────────────────────────────┬─────────────┤
│ Capas   │                                       │ Panorama    │
│         │          Mapa a pantalla completa     │ o lugar     │
│ Grupos  │                                       │             │
│ y fichas│                 Leyenda               │ Lluvia, río │
│         │                 Créditos              │ historia    │
├─────────┴───────────────────────────────────────┴─────────────┤
│ ▶ Fecha · Barras de lluvia por horizonte · Incertidumbre · Comparar │
└───────────────────────────────────────────────────────────────┘
```

El mapa ocupa el 100 % de la ventana, con los paneles flotando encima.

**Espacio libre medido** a 1600×900 con ambos paneles abiertos: 62 % del ancho, 85 % del alto y 53 % del área. Es menos que el 70-80 % pedido. Con un panel cerrado se llega al 67-70 % del área, y con ambos cerrados al 85 %. Los paneles son translúcidos y plegables; por debajo de 1100 px arrancan cerrados y solo se abre uno.

## Lenguaje visual

| Elemento | Decisión |
|---|---|
| Fondo | `#03070f`, azul casi negro |
| Paneles | Vidrio: `rgba(9,18,33,.84)` con desenfoque; más sólido si el usuario pide menos transparencia. Con menos opacidad, el mapa interfería con la lectura |
| Acento | Cian `#67e8f9`, solo para selección e interacción |
| Peligro | Rojo, naranja y amarillo reservados a niveles oficiales, siempre con icono y texto |
| Tipografía | Space Grotesk para títulos y cifras; Inter para texto |
| Fuera de Perú | Máscara oscura que se desvanece al acercarse |

## Cómo se distinguen los datos

Cada capa lleva una etiqueta de clase: **Observación, Modelo, Aviso oficial, Amenaza, Susceptibilidad, Exposición, Inventario, Referencia**. Su ficha añade metodología, limitación, fuente, leyenda y opacidad.

Los módulos sin dato defendible aparecen deshabilitados con el motivo, por ejemplo "Riesgo" o "Probabilidad propia de activación". Es deliberado: el usuario debe ver qué falta.

## Línea de tiempo

Ventana de −14 a +14 días. Las barras son la media de las celdas de la malla, no un promedio areal, y su color marca el horizonte: pasado, 24-72 h, 3-7 días, 7-15 días. No se puede ir más allá del límite del modelo.

La incertidumbre es real: con un lugar seleccionado muestra el rango p10-p90 de los 51 miembros del ensamble ECMWF para ese día. Sin lugar, explica la fiabilidad del horizonte.

"Comparar con" sustituye el mapa de calor por la capa histórica de SENAMHI, con un letrero que aclara que no es un pronóstico.

## Gráficos

Hechos con ECharts. Paleta validada con pruebas de daltonismo sobre la superficie real (`#0c1728`). Un solo eje por gráfico, y siempre una vista de tabla. Los meses futuros se dejan vacíos: no se proyectan.

## Adaptación

| Ancho | Comportamiento |
|---|---|
| ≥ 1100 px | Ambos paneles abiertos |
| 768-1099 px | Cerrados al inicio; uno a la vez |
| < 768 px | El buscador pasa a su propia fila; línea de tiempo en dos filas; sin desbordamiento horizontal a 400 px |

## Accesibilidad

Navegación por teclado, foco visible, regiones y botones etiquetados, línea de tiempo operable como control deslizante, color nunca como único canal, vista de tabla en los gráficos, y respeto de `prefers-reduced-motion`. **No se ha hecho auditoría con lector de pantalla.**
