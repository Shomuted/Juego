# Continuidad de The Last Physical Store

La versión actual es la [Alpha 0.2.1](alpha-021.md): 60 copias mezcladas en montones
y sueltas por el suelo de una sola tienda, 1 XP por copia ordenada y guardado JSON v3.
Los handoffs originales y este plan se conservan como antecedentes de diseño.

## Corrección del director después de probar Alpha 0.2

Esta instrucción directa prevalece sobre interpretaciones anteriores:

- El núcleo es encontrar copias entre el desorden del suelo, recogerlas y ordenar
  las estanterías. No entregar juegos ya agrupados en mesas por título o plataforma.
- El desorden debe estar en la tienda, sin separar el trabajo en dos salas.
- Cada copia colocada representa 1 XP. Sin multiplicadores ni bonos por colección.
- Los ingresos proceden de visitantes; clasificar no entrega dinero.
- Priorizar la interacción y las colecciones antes que decorar.
- Mantener movimiento y salto, que el director sí confirmó como satisfactorios.
- Sort'em Ducks es la referencia indicada para la experiencia de buscar y ordenar.

La palabra histórica «bodega» en un documento o campo del save no autoriza convertir
este núcleo en una sala de mesas ordenadas. Las decisiones de ediciones, excedentes
y archivo que siguen abiertas no deben resolverse implícitamente al ampliar sistemas.

## Alcance y evidencia

Este documento organiza los dos informes entregados por el director del proyecto.
El checkout estaba vacío al comenzar. Posteriormente se recibió e importó el
ZIP completo del Sprint 07 con código, escenas, catálogo SQL y pruebas. No se
adjuntaron partidas históricas del usuario. Los resultados ejecutados en esta
máquina se registran en [validación del Sprint 07](validacion-sprint07.md).

La propuesta inicial de un arcade web se retiró al recibir estos antecedentes.
El trabajo continúa sobre la visión de Godot 4 para PC/Steam.

## Reglas que se deben conservar

- Las copias se recuperan, transportan, exhiben y conservan; no se venden.
- Un título del catálogo y una copia física son entidades diferentes. Cada copia
  conserva identidad, condición, edición y procedencia al guardar y cargar.
- Cada título coleccionable pertenece a una plataforma. Otras versiones pueden
  compartir saga, pero siguen siendo títulos coleccionables distintos.
- Una copia ocupa exactamente una ubicación lógica: bodega, inventario,
  exhibición o archivo. La existencia de un nodo 3D no define su existencia lógica.
- El prototipo contempla diez slots por colección. La capacidad debe ser un dato
  configurable; las ediciones especiales no crean slots adicionales.
- Los reemplazos aceptados conservan la categoría requerida y mejoran la condición.
  La copia retirada pasa al archivo. El traslado de ambas copias debe ser atómico.
- La calidad se deriva de las copias exhibidas, sin incluir las archivadas.
- Colección actualmente completa y completada alguna vez son estados distintos.
  La versión actual solo registra el hito: no entrega dinero ni XP adicional.
- Una remodelación visual no modifica IDs, capacidades ni posiciones lógicas.
- Miles de copias persistentes no requieren miles de cuerpos físicos activos.

## Arquitectura conservada al incorporar el código

```text
SQLite de catálogo
  → Tools/build_catalog.py
  → exportación de contenido / CatalogoJuegos
  → representación e interacción en Godot

Estado de partida
  → JSON en user://
  → partida_01.json + respaldo .bak + temporal .tmp
```

SQLite se utiliza en desarrollo como fuente del catálogo. El informe no describe
un complemento SQLite en runtime ni una migración terminada del guardado.
Conservar esta separación al incorporar el proyecto. La elección futura de
persistencia necesita evaluar integración y recuperación reales.

Los nombres de API que el informe exige preservar son:

- `CatalogoJuegos.obtener_juego(id_juego)`
- `CatalogoJuegos.obtener_ids()`
- `CatalogoJuegos.existe(id_juego)`

El inventario inicial reportado tiene cinco posiciones. Las estanterías usan
tres filas de diez columnas y el índice `fila * 10 + columna`. El catálogo
reporta 120 slots definidos y 60 representados en las estanterías jugables;
esas cifras no deben confundirse ni corregirse automáticamente.

## Identidad e interoperabilidad a comprobar

| Prototipo reportado | Modelo de datos | Regla de integración |
| --- | --- | --- |
| `id_juego` | `title.code` e ID relacional | Establecer una correspondencia explícita; no deducir identidad del nombre visible. |
| `id_copia` | `copy_uuid` | Preservar el identificador existente; no regenerarlo al cargar. |
| `condicion` | Condición 0–100 | Mantener el valor persistido; la escala 0–10 es de presentación. |
| `es_especial` | Edición tipada | `true` no distingue GOTY de Collector; no asignar una categoría arbitraria. |
| Estantería, fila y columna | Shelf, section, collection y slot | Construir un mapeo explícito sin reordenar copias. El índice por sí solo no identifica un slot global. |
| Caja o nodo 3D | Representación de `PHYSICAL_COPY` | Cargar o descargar el nodo no crea ni elimina la copia persistente. |

Esta tabla establece requisitos de integración; no constituye una migración
implementada. Incluso la correspondencia de una copia histórica no especial con
STANDARD se verificará contra los datos reales.

## Plan de estabilización y continuidad

1. Inspeccionar el ZIP, `project.godot`, plugins, scripts y recursos. Determinar
   la versión compatible de Godot y preservar los archivos originales y saves.
2. Abrir/importar el proyecto y ejecutar las pruebas existentes. Registrar por
   separado errores de entorno, defectos del proyecto y resultados aún no probados.
3. Reproducir recoger, inventario limitado, rechazo por plataforma, colocación en
   la fila correcta y estabilidad de posiciones.
4. Guardar, cargar, cerrar y reabrir. Comparar IDs, condiciones, ediciones,
   ubicaciones, asignaciones de filas y posiciones de todas las copias de prueba.
5. Verificar reinicio con `.json`, `.bak` y `.tmp`: un autoguardado pendiente no
   debe restaurar una partida reiniciada. Ensayar archivos dañados usando copias
   de prueba y comprobar el comportamiento de recuperación existente.
6. Revisar esquema y tests recibidos antes de proponer cambios de integridad.
   Diseñar migraciones con respaldo y validación, sin convertir silenciosamente
   las ediciones históricas ni introducir cambios de gameplay.

El informe original dejaba carga y reinicio pendientes de confirmación. Ahora
se comprobaron con archivos temporales, recarga real de escena y reapertura en
otro proceso. La prueba interactiva del usuario y sus saves históricos siguen
siendo comprobaciones distintas.

## Seis brechas SQL reportadas

Las seis brechas descritas por el equipo anterior se reprodujeron con el SQL
recibido en bases temporales. El informe de validación detalla los resultados.
Sus correcciones quedan para un cambio versionado del contrato de datos.

| Brecha | Comprobación requerida |
| --- | --- |
| Cambiar plataforma de un título | Impedir formatos incompatibles en sus ediciones. |
| Cambiar plataforma de una estantería | Mantener compatibilidad con sus secciones y colecciones. |
| Cambiar categoría de un slot ocupado | Mantener compatibilidad con la edición de la copia exhibida. |
| Cambiar tipo de ubicación | Mantener exclusividad y coherencia con los datos de su subtipo. |
| Nivel de mejora | Respetar el máximo definido, además del mínimo. |
| Añadir colecciones al catálogo | No alterar automáticamente el objetivo de campañas existentes. |

Cada corrección debe tener un caso válido, uno inválido y una comprobación de que
el rechazo no deja cambios parciales. Las operaciones de recoger, exhibir y
reemplazar también necesitan pruebas de conservación de identidad y ubicación
única. El manifiesto de campaña es una propuesta para fijar objetivos; no es
una funcionalidad implementada ni una decisión definitiva.

## Decisiones abiertas

Mantener pendientes hasta que el director las defina: tratamiento de excedentes;
descubrimiento y exhibición temprana de ediciones especiales; elección y límites
de conversión de slots; retirada manual; cajas Collector grandes; organización
libre o fija; relación entre archivo y excedentes; lotes de poscampaña e
incorporación de nuevo contenido a partidas anteriores.

Los informes alternan Gold y GOTY. No asumir que son sinónimos ni crear categorías
adicionales sin comprobar el catálogo y la decisión de diseño.

## Artefactos recibidos y compatibilidad pendiente

- **Recibido:** ZIP completo del Sprint 07, incluyendo `project.godot`, escenas,
  scripts, recursos, `Database/`, `Tools/build_catalog.py` y pruebas.
- **Verificado:** esquema v0.1 y catálogo de ejemplo incluidos. No falta el SQL.
- **Aún no disponible:** una partida histórica del usuario. Las pruebas crean
  partidas temporales; su éxito no demuestra migración ni compatibilidad con
  todos los archivos de versiones previas.

Herramientas disponibles: Godot `4.6.3.stable.official`, Python `3.12.14` y SQLite
`3.53.1`. El runner usa rutas XDG temporales escribibles para evitar los errores
iniciales de caché de fuentes y configuración del editor. La ejecución gráfica
interactiva en escritorio se mantiene separada de la validación sin ventana.
