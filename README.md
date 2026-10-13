# The Last Physical Store — Alpha 0.2.1

Una campaña jugable de coleccionismo y gestión de una tienda-museo 3D en Godot 4.
Busca videojuegos mezclados y amontonados por el suelo de la tienda, recógelos y
ordénalos en sus colecciones. Cada copia colocada por primera vez representa **1 XP**.
Las copias se conservan; el dinero procede de las entradas de los visitantes.

Esta versión amplía el Sprint 07 recibido. Usa arte procedural provisional.

![Inicio real: copias mezcladas por el suelo](docs/capturas/alpha-021-tienda.png)

## Jugar

Descarga [el proyecto Alpha 0.2.1 en ZIP](https://github.com/Shomuted/Juego/raw/refs/heads/main/downloads/The_Last_Physical_Store_Alpha021_Suelo.zip).
Incluye el proyecto editable; requiere Godot y no es un ejecutable independiente.
También puedes descargar el repositorio desde **Code → Download ZIP**.

1. Descomprime el proyecto e importa `project.godot` en Godot **4.6.3 o posterior**.
2. Pulsa **F5** para ejecutar el juego. Mira al suelo: las copias están mezcladas por la tienda.
3. Busca entre los montones, recoge cajas con clic y colócalas con **E** en su estantería.
4. Cuando tengas una exposición, acércate a la palanca del mostrador y pulsa **R**.
5. Invierte el dinero de las entradas en mejoras desde **TAB**.
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

- Una sola tienda con montones físicos irregulares y cajas sueltas por el suelo;
  títulos y plataformas mezclados, portadas y formatos físicos identificables.
- Campaña con seis títulos y diez copias Standard de cada uno, generadas con una
  semilla persistida. Todas las colecciones pueden completarse.
- Copias con identidad y condición permanentes; posiciones de exposición estables.
- Jornadas de tres minutos y noches ilimitadas para organizar.
- Visitantes animados e ingresos por entradas según exposición, calidad y estilo.
- 1 XP por copia clasificada, sin bonos de XP ni dinero por completar colecciones.
  Recoger una copia todavía no da XP: hay que colocarla correctamente.
- Inventario mejorable de 5 a 11 copias y alcance de 3 a 4.5 metros.
- Tres estilos combinables, Arcade/Museo/Cyber, con decoración y tres niveles cada uno.
- HUD, objetivos, catálogo de colecciones, gestión y final de campaña persistente.
- Guardado JSON v3: dinero, XP, tiempo, mejoras, estilos y stock original.

Los parámetros de balance están en `Database/gameplay_config.json`.
El catálogo sigue procediendo de SQLite; el juego no necesita un plugin SQLite.

## Partidas anteriores

No necesitas borrar tu partida para usar esta corrección. Al cargar:

- Sprint 07 (v1): conserva las posiciones originales del suelo, inventario y estanterías.
- Alpha 0.2 (v2): mezcla en el suelo únicamente las copias pendientes que estaban en
  las mesas; conserva inventario, colecciones, IDs, condición, edición, dinero y compras.
- La XP se ajusta a una unidad por copia clasificada, también en partidas anteriores.
- Antes de migrar se conserva el archivo original en `user://partida_01_sprint07_original.json`
  o `user://partida_01_alpha02_original.json`, según su versión.
- Los nuevos guardados v3 conservan posiciones, giros y velocidades del suelo al cargar;
  no vuelven a generar ni redistribuir las copias.

El campo técnico `bodega` del JSON continúa representando las copias físicas del
mundo; no implica una habitación separada. La edición booleana antigua no se convierte
a GOTY/Collector. La compatibilidad se prueba con fixtures: no se recibió una partida
histórica real del usuario.

El reinicio desde TAB borra el progreso actual con confirmación, conserva los originales
de migración y genera una campaña nueva. Si principal y respaldo están dañados, se
suspende el guardado para conservarlos.

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

Ver [corrección de la Alpha 0.2.1](docs/alpha-021.md),
[antecedente de la Alpha 0.2](docs/alpha-02.md),
[validación anterior del Sprint 07](docs/validacion-sprint07.md) y
[reglas y contexto del diseño](docs/continuidad.md).
