# The Last Physical Store — Alpha 0.2

Una campaña jugable de coleccionismo y gestión de una tienda-museo 3D en Godot 4.
Recupera videojuegos físicos de la bodega, completa la exposición y abre las puertas
al público. Las copias se conservan; el dinero proviene de entradas y recompensas
por la primera colección completa.

Esta versión amplía el Sprint 07 recibido. Usa arte procedural provisional.

## Jugar

Descarga [el proyecto Alpha 0.2 en ZIP](https://github.com/Shomuted/Juego/raw/refs/heads/main/downloads/The_Last_Physical_Store_Alpha02_Avanzado.zip).
Incluye el proyecto editable; requiere Godot y no es un ejecutable independiente.
También puedes descargar el repositorio desde **Code → Download ZIP**.

1. Descomprime el proyecto e importa `project.godot` en Godot **4.6.3 o posterior**.
2. Pulsa **F5** para ejecutar el juego. La bodega está detrás del punto de inicio.
3. Recoge cajas de las mesas y colócalas en las estanterías de su plataforma.
4. Cuando tengas una exposición, acércate a la palanca del mostrador y pulsa **R**.
5. Invierte entradas y recompensas en mejoras desde **TAB**.
6. Clasifica las 60 copias originales para inaugurar el museo. Puedes seguir
   abriendo jornadas y mejorándolo después de completar la campaña.

| Control | Acción |
| --- | --- |
| WASD / ratón | Caminar / mirar |
| Espacio | Saltar |
| Clic izquierdo | Recoger una caja a tu alcance |
| E | Clasificar una copia compatible en una estantería cercana |
| R | Abrir la jornada desde la palanca física del mostrador |
| TAB | Gestión: compras, colecciones, ayuda y guardado |
| Escape | Cerrar gestión o liberar el cursor |
| F6 / F9 | Guardar / cargar |

La gestión pausa al jugador y el reloj comercial. Reiniciar desde el menú requiere
confirmación y elimina el progreso actual. F8 detiene el juego en el editor.

## Qué incluye

- Tienda cerrada y bodega con seis mesas; portadas y formatos físicos por plataforma.
- Campaña con seis títulos y diez copias Standard de cada uno, generadas con una
  semilla persistida. Todas las colecciones pueden completarse.
- Copias con identidad y condición permanentes; posiciones de exposición estables.
- Jornadas de tres minutos y noches ilimitadas para organizar.
- Visitantes animados e ingresos por entradas según exposición, calidad y estilo.
- Recompensas de primera colección y experiencia de primera clasificación.
- Inventario mejorable de 5 a 11 copias y alcance de 3 a 4.5 metros.
- Tres estilos combinables, Arcade/Museo/Cyber, con decoración y tres niveles cada uno.
- HUD, objetivos, catálogo de colecciones, gestión y final de campaña persistente.
- Guardado JSON v2: dinero, XP, tiempo, mejoras, estilos y stock original.

Los parámetros de balance están en `Database/gameplay_config.json`.
El catálogo sigue procediendo de SQLite; el juego no necesita un plugin SQLite.

## Partidas del Sprint 07

El cargador acepta el formato v1 y conserva IDs, condiciones, edición booleana,
inventario, posiciones y asignación de filas. Antes de migrar guarda una copia del
original en `user://partida_01_sprint07_original.json`. No asigna GOTY/Collector ni
inventa dinero o experiencia histórica. Los nuevos guardados usan versión 2.
La compatibilidad se ensayó con fixtures v1; no se recibió una partida histórica
real del usuario.

`user://` contiene el principal `partida_01.json`, respaldo `.bak` y temporal `.tmp`.
El reinicio elimina esos tres, conserva el respaldo original del Sprint 07 y comienza
una campaña nueva. Si principal y respaldo no son válidos, se suspende el guardado
para que los archivos dañados no se sobrescriban automáticamente.

## Pruebas automáticas

En Linux, con Python 3 y Godot 4 disponibles:

```bash
python3 Tools/run_checks.py
```

Para indicar el ejecutable:

```bash
python3 Tools/run_checks.py --godot /ruta/al/Godot
```

El runner importa los recursos, prueba catálogo, dominio, campaña completa,
interacción física, guardado, recuperación y reinicio. La reapertura usa dos
procesos independientes y comprueba también dinero, mejoras, estilos y reloj.
Cada prueba usa datos XDG temporales; no modifica tu partida normal. No se requieren
paquetes pip/npm ni servicios externos.

Para cambiar contenido y regenerar el catálogo:

```bash
python3 Tools/build_catalog.py
python3 Tools/run_checks.py
```

La regeneración sobrescribe la base de catálogo, su exportación JSON y
`Scripts/catalogo_juegos.gd`; no hace falta ejecutarla para jugar.

## Alcance de esta entrega

Es una alpha jugable con una campaña pequeña completa. Aún faltan el contenido
final, audio y arte definitivos, archivo/reemplazos jugables, ediciones tipadas,
lotes de poscampaña, escala de miles de copias e integración y publicación en Steam.
Las seis brechas conocidas del esquema SQL v0.1 siguen documentadas; las partidas
usan JSON y no se han migrado a SQL.

Ver [detalle de la Alpha 0.2](docs/alpha-02.md),
[validación anterior del Sprint 07](docs/validacion-sprint07.md) y
[reglas y contexto del diseño](docs/continuidad.md).
