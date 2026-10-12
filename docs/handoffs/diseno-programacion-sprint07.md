Este es el informe de traspaso para Astra, escrito desde mi rol de diseñador de videojuegos y programador principal de The Last Physical Store.

Está pensado para que Astra entienda exactamente qué hemos construido, qué decisiones de gameplay debe respetar, cómo estamos trabajando con Godot y SQLite, cuáles son los problemas pendientes y qué esperamos de su trabajo como arquitecto de datos.

# THE LAST PHYSICAL STORE

## Informe técnico de Diseño y Programación para Astra

**Versión:** 0.1 — Traspaso de contexto\
**Motor:** Godot 4\
**Plataforma objetivo:** PC / Steam\
**Última entrega de desarrollo:** Sprint 07 — Integración inicial de datos\
**Responsable de este informe:** Diseño de gameplay y programación

---

# 1. Distribución de responsabilidades

Estamos desarrollando *The Last Physical Store* mediante tres responsabilidades distintas.

**Director del proyecto:** el usuario. Decide las mecánicas definitivas, la experiencia buscada y las prioridades de desarrollo.

**Diseñador y programador:** mi rol. Defino propuestas de gameplay, traduzco las reglas aprobadas a sistemas jugables y desarrollo el proyecto en Godot 4. Soy responsable de integrar sistemas, mantener compatibilidad y entregar versiones completas para pruebas.

**Astra:** analista y arquitecto de datos. Su responsabilidad es transformar las reglas de gameplay en modelos de datos coherentes, integridad, persistencia, migraciones y soluciones escalables.

La arquitectura debe servir al diseño, no imponer nuevas mecánicas simplemente porque resulten convenientes para una tabla o relación.

Al mismo tiempo, Diseño y Programación debe respetar las restricciones e interfaces de datos acordadas, evitando inventar esquemas diferentes dentro de cada script.

---

# 2. Visión general del videojuego

*The Last Physical Store* es un simulador 3D de coleccionismo de videojuegos físicos.

El protagonista posee una enorme bodega de videojuegos adquiridos durante el declive del comercio físico.

La experiencia consiste en recuperar, clasificar, conservar y exhibir videojuegos hasta transformar una tienda pequeña en un museo especializado.

El núcleo del juego es:

1. Buscar copias físicas en la bodega.
2. Identificarlas por su caja, plataforma y título.
3. Recogerlas.
4. Transportarlas mediante un inventario limitado.
5. Colocarlas en la colección correspondiente.
6. Completar colecciones.
7. Mejorar la calidad de las colecciones con ejemplares superiores.
8. Obtener ingresos de visitantes y progresar con mejoras de la tienda.
9. Terminar de organizar el stock original.
10. Continuar opcionalmente perfeccionando las colecciones en la poscampaña.

**Regla fundamental: los videojuegos no se venden.**

No estamos desarrollando un simulador de compraventa convencional.

Las copias forman parte del patrimonio del coleccionista. Los ingresos proceden de la actividad de la tienda-museo, no de desprenderse de los videojuegos.

---

# 3. Escala prevista

El objetivo conceptual de la campaña es procesar aproximadamente **5.000 copias físicas originales**.

Eso no significa 5.000 títulos diferentes.

Un mismo título tendrá varias copias individuales con distintas condiciones y potencialmente distintas ediciones.

La primera versión jugable representativa que queremos construir contempla aproximadamente:

- 200 copias físicas.
- 20 títulos diferentes.
- Cinco estanterías.
- Colecciones con diez posiciones.
- Guardado estable.
- Progresión básica.
- Economía inicial.
- Ciclo comercial de día y noche.

Estas cantidades corresponden a objetivos de desarrollo, no al contenido ya implementado.

La campaña completa debe tener un final reconocible. Después se desbloquearía una poscampaña con nuevos lotes de copias, aproximadamente 500 por solicitud, procedentes de una reserva adicional del protagonista.

La generación de nuevas copias no debe alterar retroactivamente qué unidades pertenecían al stock original de campaña.

---

# 4. Reglas centrales del dominio

## 4.1. Título y copia física son entidades diferentes

Una obra del catálogo no es una unidad física.

Ejemplo conceptual:

**Título:** Adventure Ultimate VII — PS1.

**Copias:**

- `copy_001`: Standard, condición 64.
- `copy_002`: Standard, condición 91.
- `copy_003`: Standard, condición 78.
- `copy_004`: Collector, condición 86.

Todas pertenecen al mismo título, pero deben mantener identidades distintas.

Cada copia tiene un identificador único y persistente.

Su condición y edición no deben regenerarse al cargar la partida.

## 4.2. La plataforma pertenece al título coleccionable

Las versiones de una misma obra para plataformas diferentes se consideran títulos coleccionables distintos.

Pueden pertenecer a una saga común, pero tienen distintas colecciones, ediciones y formatos físicos.

## 4.3. Ubicación única

Una copia física solamente puede ocupar una ubicación lógica a la vez.

Las ubicaciones relevantes son:

- Bodega.
- Inventario del jugador.
- Slot de exhibición.
- Archivo.

El almacenamiento de ejemplares excedentes todavía necesita una definición de gameplay más precisa. No debe resolverse creando ubicaciones que el jugador no pueda comprender o utilizar.

## 4.4. Colecciones con capacidad fija

La unidad fundamental de colección es un título con un conjunto definido de posiciones de exhibición.

El prototipo utiliza diez posiciones por colección.

La incorporación de nuevas copias no debe mover arbitrariamente las copias ya colocadas.

Cada posición debe ser estable.

## 4.5. Ediciones especiales

Una colección no aumenta su capacidad al encontrar una edición Gold, GOTY o Collector.

Ejemplo:

Inicialmente:

10 Standard.

Más adelante:

8 Standard + 1 Gold + 1 Collector.

El total sigue siendo diez.

La edición especial transforma una posición anteriormente normal.

Una vez asignada una categoría especial, los reemplazos deben respetarla:

- Standard sustituye Standard.
- Gold sustituye Gold.
- Collector sustituye Collector.

Todavía no están aprobadas todas las reglas relacionadas con descubrimiento, conversión o límites por edición.

## 4.6. Reemplazos y archivo

Las copias de peor condición podrán sustituirse por otras mejores de la misma categoría.

La copia retirada debe conservarse en el archivo.

No se vende ni desaparece.

La colección mantiene su cantidad de slots, pero puede aumentar su calidad promedio.

## 4.7. Condición de la colección

La condición individual se expresa internamente en escala 0–100.

La interfaz puede expresarla en escala 0–10.

El promedio de una colección se calcula sobre los ejemplares actualmente exhibidos.

Las copias archivadas no contribuyen al promedio.

## 4.8. Primera completación

Recomendamos distinguir entre:

- Colección actualmente completa.
- Colección completada alguna vez.

Una recompensa de primera completación debe concederse una sola vez, incluso cuando más adelante se sustituyan copias.

Esta distinción ya está prevista en el esquema de datos recibido.

---

# 5. Día, noche, progresión y economía

Estos sistemas son parte de la visión del juego, pero no están implementados plenamente.

## Día

El día comercial tiene duración limitada.

Durante esa fase la tienda puede generar ingresos mediante visitantes, colecciones exhibidas, calidad y prestigio.

El jugador también puede recoger y ordenar videojuegos durante el día.

## Noche

La noche no tiene límite temporal.

El jugador puede seguir organizando, decorando y gestionando la colección.

No existen ingresos comerciales infinitos durante esta fase.

La noche termina cuando el jugador activa una palanca física detrás del mostrador.

## Experiencia

La actividad de clasificación otorga XP.

La XP permite mejorar habilidades como capacidad de inventario y alcance de interacción.

## Estilos de la tienda

Existirán tres ramas combinables:

- Arcade.
- Museo.
- Cybercafé / Cyberpunk.

No son clases excluyentes.

El jugador puede mezclar las tres.

Una remodelación estética no debe cambiar los identificadores ni las capacidades lógicas de las estanterías.

---

# 6. Estado real del desarrollo en Godot

Hemos avanzado mediante sprints completos, entregados al usuario como proyectos ZIP que puede abrir directamente en Godot.

Es importante distinguir tres estados:

**Implementado:** el código existe.

**Validado por el usuario:** el usuario lo ejecutó y confirmó su funcionamiento.

**Pendiente de validar:** se entregó o pasó pruebas estáticas, pero aún no tenemos confirmación de ejecución satisfactoria.

## Sprint 01 — Núcleo inicial

Se trabajó en movimiento 3D, interacción con cajas, inventario y clasificación básica.

## Sprint 02 — Estanterías

Se estabilizó el orden por plataforma y título.

El usuario confirmó que funcionaban:

- Recoger cajas.
- Identificar la consola.
- Rechazar consolas incompatibles.
- Asignar títulos a filas.
- Colocar copias consecutivamente en columnas.
- Mantener las posiciones previas.

Este es uno de nuestros comportamientos jugables más importantes y no queremos perderlo.

## Sprint 03 — Guardado

Se incorporó persistencia de:

- Estado del jugador.
- Inventario.
- Cajas de la bodega.
- Identidades de las copias.
- Condiciones.
- Estanterías.
- Filas asignadas.
- Posiciones ocupadas.

El usuario confirmó que la versión funcionaba bien.

## Sprint 04 — Formatos visuales

Se introdujeron tamaños y proporciones distintos por consola, además de portadas provisionales.

Surgió un error de compatibilidad porque se llamó `CatalogoJuegos.obtener_datos()` cuando el método existente era `CatalogoJuegos.obtener_juego()`.

Se corrigió regresando a la lógica de estanterías previamente estable, en lugar de reescribir innecesariamente un sistema que funcionaba.

Lección de integración: **mantener contratos públicos estables entre scripts**.

## Sprint 05 — Formas y física

Se añadieron diferencias entre formatos físicos.

El usuario confirmó que las cajas ya tenían los tamaños que correspondían a sus consolas.

También aparecieron problemas con el reinicio y la carga de partidas.

## Sprint 06 — Carga y reinicio

Se entregó una corrección que incluye un menú de pruebas mediante TAB.

El menú permite:

- Guardar.
- Cargar.
- Reiniciar la partida con confirmación.

La carga se modificó para reconstruir el mundo desde una escena nueva, reduciendo los problemas asociados a eliminar y reinstanciar múltiples objetos dentro de una escena activa.

**Este sprint no tiene todavía confirmación explícita de funcionamiento satisfactorio por parte del usuario.**

No debe tratarse como completamente validado.

## Sprint 07 — Integración inicial del esquema SQL

Es la última entrega de desarrollo.

Se tomó el archivo `tlps_schema_v0_1.sql`, entregado por el analista, y se incorporó al proyecto como base de catálogo.

No se reemplazó el sistema JSON de guardado por SQLite.

---

# 7. Estado técnico del prototipo actual

El proyecto utiliza Godot 4 y scripts GDScript.

Entre los componentes relevantes están:

**`Scripts/catalogo_juegos.gd`**

Catálogo de títulos y plataformas.

Mantiene actualmente métodos públicos como:

- `CatalogoJuegos.obtener_juego(id_juego)`
- `CatalogoJuegos.obtener_ids()`
- `CatalogoJuegos.existe(id_juego)`

Los demás sistemas dependen de estos contratos.

**`Scripts/caja_juego.gd`**

Controla cada caja física.

La clase `CajaJuego` hereda de `RigidBody3D`.

Los datos de una copia incluyen:

- `id_juego`
- `id_copia`
- `titulo`
- `consola`
- `condicion`
- `es_especial`

El campo `es_especial` actualmente es booleano, no un identificador completo de edición.

Este punto es especialmente importante para Astra.

**`generador_juegos.gd`**

Instancia cajas físicas, asigna títulos y condiciones y genera identificadores de copia.

El prototipo utiliza generación aleatoria.

Todavía no es el generador controlado de una campaña de 5.000 copias.

**`Scripts/Player.gd`**

Maneja movimiento, interacción, recogida, inventario y colocación.

El inventario tiene capacidad inicial de cinco copias.

**`Scripts/estanteria_juegos.gd`**

Controla estanterías por consola.

El prototipo utiliza:

- Tres filas por estantería.
- Diez columnas por fila.
- Treinta posiciones por estantería.
- Títulos asignados a filas.
- Posiciones calculadas mediante `fila * 10 + columna`, comenzando en cero.

Los títulos tienen posiciones reservadas y no deben mezclarse.

**`Scripts/SaveManager.gd`**

Gestiona persistencia JSON, restauración, archivos temporales y respaldo.

**`Scripts/Main.gd`**

Orquesta la partida, el autoguardado y el menú de pruebas.

**`Scripts/HudTienda.gd`**

Muestra inventario, mensajes, interacción y progreso visible.

---

# 8. Situación exacta del Sprint 07

En el Sprint 07 se incorporaron estos archivos:

- `Database/schema_v0_1.sql`
- `Database/seed_prototype.sql`
- `Database/tlps_catalog_prototype.db`
- `Database/catalog_export.json`
- `Database/INTEGRACION_SPRINT07.txt`
- `Tools/build_catalog.py`
- `Tests/test_schema_contract.py`

El SQL recibido se utilizó como punto de partida, sin redefinir arbitrariamente el modelo del analista.

## Contenido sembrado

Actualmente la base de catálogo incluye:

- 12 títulos.
- 7 formatos físicos.
- 3 estanterías.
- 6 secciones asignadas a esas estanterías.
- 120 definiciones de slots en el catálogo.
- 60 posiciones de exhibición efectivamente representadas en las tres estanterías jugables.
- Reglas iniciales de stock para seis títulos jugables.

La distinción entre 120 slots definidos y 60 slots montados físicamente es intencional.

El catálogo contiene títulos de plataformas que todavía no cuentan con estanterías jugables.

## Pipeline de datos

Actualmente tenemos:

SQLite de catálogo → exportación de contenido → generación de `catalogo_juegos.gd` → consumo por los scripts de Godot.

El script `Tools/build_catalog.py` permite regenerar el catálogo de Godot a partir de los datos del proyecto.

Esto significa que SQLite es una **fuente de configuración y catálogo durante el desarrollo**.

No significa que el videojuego consulte SQLite directamente durante cada interacción.

No se incorporó todavía un complemento SQLite de runtime a Godot.

## Formatos físicos

La base incluye dimensiones y parámetros de formatos físicos.

Sin embargo, durante el Sprint 07 se preservó el comportamiento físico de las cajas desarrollado anteriormente.

Los parámetros de formato guardados en SQLite aún no reemplazan automáticamente las dimensiones o masas utilizadas por Godot.

Hay una duplicación temporal entre la definición de contenido y la representación jugable que deberá resolverse posteriormente mediante un contrato claro.

---

# 9. Persistencia actual

El juego continúa utilizando archivos JSON bajo `user://`.

Los archivos principales son:

- `partida_01.json`
- `partida_01.bak`
- `partida_01.tmp`

El sistema representa una partida con información sobre jugador, inventario, bodega y estanterías.

El autoguardado está configurado aproximadamente cada 60 segundos, además de las operaciones de guardado solicitadas por el jugador.

El reinicio para pruebas debe borrar el archivo principal, el respaldo y el temporal, evitando que una escritura pendiente vuelva a generar la partida anterior.

La carga del Sprint 06 intenta validar el archivo y recargar la escena antes de reconstruir el estado.

**Todavía no hemos migrado las partidas a SQLite.**

Astra debe entender que el esquema relacional y el archivo JSON actual son dos representaciones diferentes, todavía no unificadas.

---

# 10. Problema más importante de migración: las ediciones

El prototipo utiliza:

`es_especial: bool`

Los valores posibles son verdadero o falso.

El esquema SQL diferencia:

- STANDARD.
- GOTY.
- COLLECTOR.

Por lo tanto, una copia guardada con `es_especial = true` no permite saber si originalmente era GOTY o Collector.

No existe una conversión histórica inequívoca.

**Decisión de programación:** no transformar silenciosamente todas las copias especiales antiguas en una categoría arbitraria.

Necesitamos una estrategia de migración explícita antes de adoptar ediciones tipadas en partidas existentes.

Astra debería proponer alternativas y sus consecuencias, sin decidir unilateralmente qué edición recibirán las copias históricas.

---

# 11. Segundo problema de migración: slots

En Godot, las posiciones actuales utilizan el índice:

`fila * 10 + columna`

Es un índice de cero a veintinueve dentro de una estantería de tres filas.

El esquema SQL utiliza entidades como:

- `collection_definition`
- `collection_slot_definition`
- `shelf`
- `shelf_section`
- `collection_slot_state`
- `collection_slot_location`

Los `slot_id` y `slot_index` no son equivalentes directamente a la posición numérica usada por el prototipo.

Necesitamos una correspondencia estable:

- Estantería de Godot.
- Fila/sección.
- Colección.
- Columna.
- ID lógico del slot.

Esa correspondencia debe preservar todas las copias ya exhibidas.

No podemos aceptar una migración que cambie accidentalmente el orden, duplique copias o asigne una caja a otra colección.

---

# 12. Observaciones de integridad sobre el esquema v0.1

El esquema SQLite v0.1 fue revisado y probado a nivel de datos.

La revisión documentó:

- 35 tablas.
- 19 triggers.
- 3 vistas.
- Seis pruebas automáticas de integración superadas.
- Verificación de integridad y claves foráneas sobre la base sembrada.

Esto demuestra que la estructura inicial puede crearse y operar en los casos probados, pero no significa que todas las invariantes estén protegidas.

Identificamos seis brechas principales.

## A. Cambio de plataforma de un título

Puede actualizarse `title.platform_id` sin garantizar que sus ediciones sigan utilizando formatos físicos compatibles.

Resultado potencial: un título cambia de plataforma, pero su edición conserva un formato de otra consola.

## B. Cambio de plataforma de una estantería

Puede modificarse `shelf.platform_id` sin validar las secciones de colección que ya contiene.

Resultado potencial: una estantería termina asociada a una plataforma distinta de sus títulos.

## C. Cambio de categoría de un slot ocupado

Puede modificarse `collection_slot_state.current_title_edition_id` aunque una copia incompatible ya ocupe el slot.

Resultado potencial: el estado lógico del slot deja de coincidir con la edición de la copia exhibida.

Este punto es crítico para la mecánica futura de ediciones especiales.

## D. Cambio del tipo de ubicación

Puede modificarse `location.location_kind` sin asegurar coherencia con su subtipo correspondiente.

Resultado potencial: una ubicación conserva datos propios de una categoría incompatible.

## E. Niveles de mejoras

`save_upgrade.level` permite valores positivos sin impedir necesariamente que superen `upgrade_definition.max_level`.

Resultado potencial: el guardado contiene una mejora de nivel superior al máximo definido.

## F. Colecciones añadidas mediante actualizaciones

La vista `v_collection_progress` incluye definiciones del catálogo para las partidas existentes.

Cuando el catálogo crezca, podrían aparecer colecciones nuevas en partidas antiguas sin que hayamos diseñado todavía cómo se incorpora ese contenido.

Necesitamos una regla de elegibilidad, una instantánea de campaña o una estrategia equivalente, según lo que se apruebe.

**Estas brechas deben resolverse sin cambiar las reglas del videojuego de manera implícita.**

---

# 13. Reglas técnicas para futuras operaciones con copias

Antes de trasladar el guardado a SQLite, necesitamos definir operaciones de dominio confiables.

Entre ellas:

**Recoger copia**

Una copia pasa de la bodega al inventario.

Debe comprobarse la capacidad disponible y evitar que el identificador esté simultáneamente en ambas ubicaciones.

**Exhibir copia**

Una copia pasa del inventario a un slot compatible.

Deben validarse consola, título, categoría de edición y ocupación.

**Completar colección**

Al completar los slots, el sistema reconoce el estado completo.

La primera recompensa no debe repetirse.

**Reemplazar copia**

Se valida que la nueva copia pertenezca al mismo título y edición requerida.

La copia antigua pasa al archivo.

La nueva ocupa el slot.

Las dos operaciones deben ser atómicas: no podemos terminar con ambas en el mismo slot ni perder una de ellas.

**Convertir slot a edición especial**

Es una operación diferente de reemplazar una copia de la misma edición.

Debe respetar las reglas de descubrimiento y disponibilidad que apruebe el director.

**Guardar y cargar**

Se debe reconstruir el estado sin repetir generación aleatoria sobre copias ya existentes.

**Procesar stock original**

Debe registrarse qué copias originales cuentan para el progreso de campaña, independientemente de su ubicación actual.

Estas operaciones deberían contar con pruebas de casos válidos e inválidos.

---

# 14. Rendimiento: las 5.000 copias no deben equivaler a 5.000 cuerpos físicos activos

Una regla técnica importante es separar:

**Estado lógico de la copia:** identidad, condición, edición, origen y ubicación persistente.

**Representación 3D:** malla, colisión, materiales, textos, física y animaciones.

La copia debe continuar existiendo aunque su objeto 3D no esté cargado.

Durante el prototipo usamos `RigidBody3D` para las cajas del mundo.

Eso funciona a pequeña escala, pero no debería convertirse en un requisito de mantener miles de simulaciones físicas simultáneas.

La arquitectura definitiva debe permitir activar o desactivar representaciones físicas según la zona del jugador y los objetos relevantes para la interacción.

Una copia archivada no necesita un cuerpo físico activo cuando su compartimento no está siendo visualizado.

---

# 15. Modelado de formatos físicos

Ya implementamos representaciones distintas según consola.

PS1 se inspira en una caja jewel case.

PS2 utiliza un formato tipo DVD.

N64 se representa como caja de cartón, no como cartucho suelto.

PS3 tiene preparado un formato compacto tipo Blu-ray.

Las diferencias incluyen:

- Ancho.
- Alto.
- Grosor.
- Masa.
- Materiales.
- Fricción.
- Rebote.
- Detalles de silueta.
- Portada provisional.

La representación de Godot conserva escalas adecuadas para las estanterías actuales.

**Para la evolución técnica, recomiendo que el catálogo de formatos físicos sea la fuente de verdad.**

Godot debería consumir parámetros normalizados y aplicar una conversión de unidades estable.

No queremos que las dimensiones, masas y materiales se editen de manera independiente en SQLite y en diferentes scripts GDScript.

Sin embargo, todavía no hemos realizado esa unificación.

---

# 16. Estado del catálogo y propiedad intelectual

El prototipo mantiene doce títulos con nombres de videojuegos comerciales conocidos.

Estos datos son provisionales.

No deben interpretarse como el catálogo autorizado del producto final.

Nuestro objetivo es utilizar videojuegos ficticios originales que transmitan nostalgia por diferentes épocas y géneros.

La identidad de un título debe separarse de su nombre y de sus recursos visuales para poder cambiar el contenido sin destruir las relaciones o el progreso de las copias.

Un código estable de catálogo es importante para esa transición.

Las carátulas finales, personajes, logotipos y referencias artísticas deben revisarse desde la perspectiva de propiedad intelectual antes de la publicación comercial.

---

# 17. Qué no queremos que ocurra durante la integración

Como diseñador y programador, quiero prevenir los siguientes errores:

1. Reemplazar todo el proyecto jugable por un sistema de datos que todavía no controla correctamente las interacciones físicas.
2. Romper partidas antiguas sin migración o respaldo.
3. Convertir una copia especial booleana a GOTY o Collector sin una regla explícita.
4. Perder la identidad de copias al moverlas entre ubicaciones.
5. Duplicar copias cuando se carga una escena o se restaura un archivo.
6. Reorganizar estanterías durante actualizaciones del catálogo.
7. Crear posiciones nuevas porque aparece una edición rara.
8. Instanciar todas las copias del archivo y la bodega simultáneamente.
9. Introducir venta de videojuegos como salida automática para excedentes.
10. Bloquear la programación de funciones sencillas por intentar implementar todo el esquema definitivo de una sola vez.

Queremos avanzar de manera incremental, pero con contratos estables.

---

# 18. Decisiones de gameplay todavía abiertas

Estas cuestiones necesitan la decisión del director y no deben ser cerradas unilateralmente por Astra:

**Copias excedentes:** qué hacemos con copias que no caben en las colecciones y cómo se procesan para la campaña.

**Ediciones raras tempranas:** si pueden exhibirse antes de completar la colección normal.

**Descubrimiento:** si una edición se considera descubierta al verla, recogerla o inspeccionarla.

**Conversión de slot:** cómo se selecciona la posición normal que se transforma en especial.

**Límites por edición:** si se admite una única Gold/Collector o cantidades configurables.

**Retirada manual:** si una copia puede extraerse libremente de una colección sin reemplazarla.

**Cajas coleccionistas grandes:** cómo exhibirlas manteniendo los diez slots.

**Estanterías:** si la asignación de títulos es siempre fija o puede organizarla el jugador.

**Archivo:** si el almacenamiento de excedentes utiliza la misma instalación física que los reemplazos.

**Poscampaña:** variantes de lotes, filtrado por título/plataforma y balance económico.

**Nuevas actualizaciones:** cómo introducir nuevos títulos en campañas ya iniciadas sin alterar su objetivo original.

Astra puede diseñar estructuras flexibles para estos casos, pero no debe presentarlas como reglas de gameplay aprobadas.

---

# 19. Prioridades de implementación

Mi propuesta de orden de trabajo es la siguiente.

## Prioridad 1 — Estabilizar el proyecto jugable

Confirmar en Godot el flujo completo:

- Guardar.
- Cargar.
- Reiniciar.
- Recoger.
- Clasificar.
- Cerrar el juego.
- Reabrir.
- Recuperar correctamente el inventario y las estanterías.

El Sprint 06 introdujo correcciones, pero necesitamos validación real del usuario.

## Prioridad 2 — Establecer contrato de datos v0.2

Corregir las brechas de integridad conocidas.

Definir identidades y correspondencias para:

- Título.
- Edición.
- Copia.
- Ubicación.
- Colección.
- Slot.
- Estado de colección.
- Procedencia.

Mantener compatibilidad con el modelo jugable existente.

## Prioridad 3 — Resolver la migración del guardado

Decidir si el runtime del juego utilizará SQLite directamente mediante una integración compatible con Godot o si continuará leyendo datos exportados y guardando el estado en otra representación.

No es obligatorio introducir SQLite dentro del runtime solamente porque el catálogo esté en SQLite.

La elección debe considerar:

- Integridad.
- Rendimiento.
- Facilidad de distribución en Steam.
- Compatibilidad con builds.
- Mantenimiento.
- Versionado.
- Recuperación de partidas dañadas.
- Pruebas automatizadas.

## Prioridad 4 — Colecciones completas y progresión

Implementar la primera colección completa como mecánica real:

- Diez slots.
- Diez copias individuales.
- Estado completo.
- Primera recompensa.
- Persistencia.
- Calidad promedio.

## Prioridad 5 — Reemplazos y archivo

Implementar movimientos seguros para ejemplares retirados.

Primero con las ediciones normales; después incorporar las reglas especiales aprobadas.

## Prioridad 6 — Ciclo comercial y progresión de tienda

Conectar las colecciones a:

- XP.
- Dinero.
- Días comerciales.
- Noche ilimitada.
- Palanca de avance.
- Mejoras del personaje.
- Ramas de tienda.

## Prioridad 7 — Escalabilidad y contenido

Preparar la generación controlada de la campaña, añadir nuevas plataformas y títulos y escalar desde decenas a cientos y luego miles de copias.

---

# 20. Qué necesito específicamente de Astra

Como diseñador y programador, necesito que Astra nos entregue una arquitectura de datos que pueda utilizarse realmente en Godot.

Los entregables más útiles serían:

### A. Contrato de dominio v0.2

Definiciones estables de cada entidad y sus responsabilidades.

No basta con nombres de tablas: necesitamos saber qué invariantes deben cumplirse después de cada acción del jugador.

### B. Revisión de integridad del SQL

Correcciones y pruebas para las seis brechas ya identificadas.

También una revisión de operaciones que involucren varias tablas y deban ejecutarse de manera atómica.

### C. Contrato de interoperabilidad

Especificar cómo se mapean los datos de SQLite a objetos y diccionarios utilizados por Godot.

Ejemplo:

El código actualmente reconoce `id_juego` e `id_copia`.

El esquema utiliza `title.code`, `copy_uuid` e identificadores relacionales.

Necesitamos una correspondencia documentada.

### D. Estrategia de migración de partidas

Cómo convertir de forma segura el JSON actual al futuro sistema.

Debe considerar el booleano `es_especial` y los índices de slots.

No se deben destruir copias ni inventar datos que no existan.

### E. Operaciones transaccionales

Definir contratos para recoger, colocar, reemplazar, archivar y trasladar copias, incluyendo errores recuperables.

### F. Pruebas

Proponer pruebas automatizadas que permitan demostrar que el modelo no duplica copias, no rompe colecciones ni acepta ubicaciones incompatibles.

### G. Estrategia de catálogo y contenido

Conservar el enfoque data-driven.

Permitir añadir títulos, ediciones, formatos y nuevas plataformas sin tener que modificar manualmente una gran cantidad de scripts.

---

# 21. Forma de colaboración a partir de ahora

Propongo este flujo:

1. Diseño establece o confirma una regla de gameplay.
2. Astra define su representación e invariantes.
3. Astra entrega un contrato de datos y pruebas.
4. Programación incorpora ese contrato a Godot.
5. Se entrega un ZIP completo para probar.
6. El director ejecuta el juego y confirma si la experiencia funciona.
7. Los errores o ambigüedades vuelven al responsable correspondiente.
8. Solo entonces damos el sprint por estable.

Esto evita tener tres fuentes diferentes de verdad.

El código jugable no debe inventar reglas que contradigan al diseño.

La base de datos no debe imponer mecánicas que el director no ha autorizado.

Y una funcionalidad no se considera totalmente validada solamente porque un script compile o una prueba de SQLite pase.

---

# 22. Resumen ejecutivo para Astra

**Estado del juego:** existe un prototipo jugable con recogida, inventario, clasificación, estanterías, cajas físicas diferenciadas y persistencia JSON.

**Estado de validación:** el usuario confirmó funcionamiento de los sistemas fundamentales y de los tamaños de cajas. La corrección más reciente del flujo de carga y reinicio sigue pendiente de confirmación.

**Estado de datos:** recibimos e integramos el esquema SQLite v0.1. La base de catálogo funciona como fuente de contenido durante el desarrollo, y el catálogo de Godot se genera a partir de ella.

**Estado de migración:** no migramos todavía las partidas a SQLite.

**Riesgos principales:** integridad de ubicaciones y slots, ediciones antiguas representadas mediante booleanos, mapeo de posiciones, actualización de catálogos y escalabilidad de objetos físicos.

**Prioridad compartida:** estabilizar el contrato de copias, ediciones, colecciones, slots y ubicaciones antes de introducir una migración definitiva de guardados.

**Objetivo final:** construir un videojuego de coleccionismo físico profundo, escalable y comercialmente viable, sin destruir las mecánicas que ya han demostrado funcionar.

---

## Solicitud final

Astra, utiliza este informe como contexto del estado real de Diseño y Programación.

Necesito que tu siguiente propuesta se concentre en:

1. El contrato de datos v0.2.
2. Las seis brechas de integridad detectadas.
3. La correspondencia entre identificadores actuales de Godot y entidades del esquema.
4. Los riesgos de migración del guardado JSON.
5. Las operaciones transaccionales necesarias para los movimientos de copias.

No necesitamos todavía una implementación masiva de toda la economía, todas las mejoras o las 5.000 copias.

**Primero consolidemos una arquitectura estable que el juego pueda utilizar sin perder su identidad ni sus progresos.**

Fin del informe.

### Lo que considero más importante de este traspaso

Astra debe entender que ya tenemos un videojuego en desarrollo, no solamente un esquema por diseñar. Por tanto, cualquier arquitectura nueva debe tener una ruta de integración con los scripts existentes.

También quiero mantener una diferencia clara entre el SQL v0.1 que ya integramos y una futura persistencia SQLite dentro del juego. El primero ya está preparado; la segunda todavía requiere decisiones y pruebas.

Cuando Astra devuelva el contrato v0.2, podremos utilizarlo como especificación para el siguiente sprint sin improvisar las estructuras.

🧙‍♂️ Siguientes pasos:

- W 📤 — Enviar este informe completo a Astra.
- E 🛠️ — Preparar el siguiente sprint a partir del contrato v0.2.
- D 🔍 — Revisar las decisiones de gameplay que podrían bloquear la integración.