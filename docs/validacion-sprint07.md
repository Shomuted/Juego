# Validación del Sprint 07 recibido

## Procedencia y cambios

ZIP recibido: `The_Last_Physical_Store_Sprint07_Integracion_Datos.zip`.
SHA-256: `3ef414bd70da04117a688b8c07c6796772c78161c2b1ebd138cc992e7ad2bd6a`.
Se incorporaron sus 42 archivos y se conservaron los informes previos.

La primera importación con Godot detectó dos errores que impedían cargar scripts:

- `Scripts/Player.gd`: el método `intentar_ordenar` usaba espacios de sangría
  en un archivo que ya utilizaba tabulaciones. Se uniformó ese bloque.
- `Scripts/Main.gd`: faltaba el operador `+` entre las dos cadenas del mensaje
  de confirmación de reinicio. Se agregó la concatenación explícita.

La prueba `Tests/test_guardado.gd` también usaba el autoload como identificador
al compilar su entrada `--script`. Se obtiene ahora el nodo `SaveManager` desde
el árbol para ejecutar la prueba. Esto no cambia el guardado del juego.

Se añadieron pruebas de persistencia e interacción, y `Tools/run_checks.py`
para ejecutar la validación con datos temporales. El esquema SQLite, los IDs,
el catálogo, las reglas de juego y el formato de guardado se conservaron.

## Entorno

- Godot `4.6.3.stable.official.7d41c59c4` en Linux, modo sin ventana.
- Python `3.12.14`, SQLite `3.53.1`.
- Godot declara `4.7` en `project.godot`, como en el ZIP recibido. No se alteró
  esa metadata ni se verificó una instalación de Godot 4.7.
- Configuración, caché y datos de pruebas se aíslan con variables XDG en `/tmp`.
  Esto resuelve los errores iniciales de escritura en la configuración del editor.

## Resultado de la ejecución completa

Comando: `python3 Tools/run_checks.py`, desde la raíz del proyecto.
Resultado: código de salida **0**, **232 comprobaciones Godot** y **6 pruebas SQLite**
aprobadas. Ninguna suite se omitió.

| Componente | Comprobaciones aprobadas |
| --- | ---: |
| Estanterías y colecciones | 36 |
| Formatos visuales y colisiones | 20 |
| Parámetros físicos de cajas | 35 |
| Validación de estructura del guardado | 13 |
| Guardado real, recarga, respaldo y reinicio | 69 |
| Recogida mediante raycast, inventario, colocación y menú | 41 |
| Guardado en el primer proceso Godot | 7 |
| Recuperación en un segundo proceso Godot | 11 |

También pasó la importación del editor y el inicio de una partida durante 120
fotogramas sin errores de script. La recuperación deliberada de un archivo
principal dañado emite el aviso esperado de uso del respaldo; no es un fallo.

La prueba de persistencia comprueba archivos en disco, IDs y ubicación única,
condiciones, edición especial booleana, posiciones estables y representaciones
visuales de estanterías. La recarga usa la ruta del menú; el reinicio se ensaya
con un guardado diferido pendiente y con principal, respaldo y temporal presentes.
La prueba de reapertura usa dos procesos independientes y el mismo directorio
temporal. No depende de mantener objetos en memoria entre ejecuciones.

## Catálogo

Se ejecutaron las seis pruebas de `Tests/test_schema_contract.py`: todas pasan.
La base incluida fue abierta en modo de solo lectura:

- `PRAGMA integrity_check`: `ok`.
- `PRAGMA foreign_key_check`: sin filas de error.
- 35 tablas, 19 triggers y 3 vistas.
- 12 títulos, 7 formatos físicos, 120 definiciones de slot y 6 secciones asignadas.
- La base de catálogo contiene cero partidas y cero copias físicas.

Se reconstruyó el catálogo en una carpeta temporal, sin reemplazar los outputs
recibidos. El JSON exportado y `catalogo_juegos.gd` son idénticos byte a byte.
La base reconstruida tiene el mismo contenido lógico salvo
`catalog_version.created_at`, que usa `CURRENT_TIMESTAMP`. No se promete igualdad
binaria de las bases generadas en momentos diferentes.

## Brechas conocidas del esquema v0.1

Se reprodujeron en bases independientes en memoria con claves foráneas activadas.
No se aplicaron migraciones ni se cambiaron decisiones de gameplay.

| Caso | Resultado observado |
| --- | --- |
| A: cambiar plataforma del título | Se acepta y puede dejar ediciones con formato de otra plataforma. |
| B: cambiar plataforma de estantería | Se acepta aunque las colecciones asignadas sean de otra plataforma. |
| C: cambiar edición de slot ocupado | Se acepta aunque la copia exhibida conserve una edición incompatible. |
| D: cambiar tipo de ubicación | Se acepta aunque quede un registro en el subtipo anterior. |
| E: superar nivel máximo de mejora | Se acepta nivel 999 para una mejora cuyo máximo es 1. |
| F: ampliar catálogo con una partida existente | La vista aumenta de 12 colecciones/120 slots a 13/130 aunque la partida conserve su versión anterior de catálogo. |

`foreign_key_check` no detecta esas inconsistencias de dominio. El validador del
build detecta B; los otros cinco casos pasan ese validador. Deben abordarse antes
de adoptar las tablas como persistencia de partidas. El juego actual sigue usando JSON.

## Límites de esta entrega

La ejecución automática sin ventana no valida el aspecto visual ni sustituye una
partida interactiva en el PC del usuario. No se recibió un save histórico:
las comprobaciones de persistencia usan partidas creadas por las pruebas.
No se implementaron economía, visitantes, migración de ediciones, reglas de
excedentes ni generación garantizada de una campaña completa.

Las notas de sprints anteriores se conservaron como historia. Para controles y
comandos actuales, usar el README de la raíz.
