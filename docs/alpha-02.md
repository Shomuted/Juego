# Alpha 0.2 — Campaña y gestión de la tienda

## Flujo jugable

Nueva campaña → recuperar en bodega → llevar un inventario limitado → clasificar
por título y plataforma → completar colecciones → abrir la jornada desde el
mostrador → recibir visitantes y entradas → invertir en herramientas y decoración
→ organizar por la noche → completar el stock original → inaugurar el museo.

La campaña contiene 60 copias, diez de cada uno de los seis títulos ya presentes en
las estanterías del prototipo. El catálogo conserva sus IDs. Las copias nuevas son
Standard y la generación evita colecciones incompletables. La campaña de miles de
copias y las reglas de especiales y excedentes son objetivos posteriores.

## Sistemas integrados

`EstadoTienda.gd` mantiene un estado serializable independiente de nodos:
manifestación del stock original, clasificación histórica, recompensas únicas,
dinero, XP, días, reloj, estadísticas, niveles y estilos. El balance se carga de
`Database/gameplay_config.json`.

`Main.gd` conecta la interacción, los eventos de colección, la jornada, las compras,
la representación de visitantes y el reconocimiento de final de campaña.
El menú pausa los controles y el reloj comercial; los visitantes visibles son una
representación y no la fuente de verdad económica.

`TiendaVisual.gd` genera paredes, techo, entrada, mostrador, palanca, mesas de bodega,
iluminación, decoraciones y NPCs. Las estanterías conservan sus posiciones e IDs.
Se orientaron sus portadas y etiquetas hacia el jugador. No se necesitan texturas
ni modelos externos para abrir esta alpha.

`HudTienda.gd` muestra inventario, condición, exposición, reloj, dinero, XP, objetivos
y final de campaña. `PanelGestion.gd` contiene compras, colecciones y ayuda.

## Balance provisional

- Jornada: 180 segundos. Un visitante cada 12 segundos si hay copias exhibidas.
- Entrada: 4 + condición media / 20 redondeada hacia abajo + copias exhibidas / 10
  redondeadas hacia abajo + suma de niveles de estilo.
- Clasificar por primera vez una copia: 5 XP.
- Completar una colección por primera vez: 120 créditos y 50 XP.
- Inventario: 5, 7, 9 u 11 copias. Costes 80/160/260; XP requerida 25/100/200.
- Alcance: 3, 3.5, 4 o 4.5 metros. Costes 60/120/200; XP requerida 25/75/150.
- Arcade, Museo y Cyber: tres niveles por rama, combinables. Costes 60/120/180.
- La XP requerida es acumulada y no se gasta al comprar.

No se venden copias. Las recompensas por colección son ayudas únicas; las entradas
son recurrentes durante el día. La noche no genera dinero y el reloj no se renueva
si se pulsa dos veces la palanca durante una jornada.

## Guardado y compatibilidad

El formato JSON v2 añade `tienda` al estado anterior. Valida tipos, rangos,
ubicaciones únicas, referencias a copias existentes y capacidad según mejoras.
Los datos de copias y slots siguen siendo la fuente de verdad de la exposición.
No se cambió el esquema SQLite ni se instaló un complemento de runtime.

Una partida v1 se restaura sin regenerar copias ni reinterpretar `es_especial`.
Su stock existente forma el manifiesto histórico y sus ejemplares exhibidos se
reconocen como clasificados. Se marcan las colecciones ya completas sin entregar
recompensas retroactivas. Antes de la carga se conserva el archivo original.

## Verificación

Se ejecutó `python3 Tools/run_checks.py` desde la raíz: **707 comprobaciones Godot y 6 pruebas SQLite aprobadas**, con código de salida 0. Además de las pruebas
previas, se prueban el modelo económico, límites de mejoras, rechazo de estados
corruptos, fin de campaña, compras, apertura física, visitas, pausas, noche,
guardado v2 y carga del formato v1. La reapertura de otro proceso comprueba que
no se necesita mantener objetos en memoria para conservar la progresión.

Se renderizó la escena real con Godot 4.6.3 y OpenGL/Mesa en una pantalla virtual.
Las capturas de tienda, bodega y gestión muestran un estado de demostración con
30 copias ya expuestas; las partidas normales empiezan con las 60 en la bodega.
La generación de capturas se realizó con datos temporales y no forma parte del
inicio normal del juego.

El proyecto declara Godot 4.6 y utiliza el renderer Compatibility, coincidiendo
con la ejecución gráfica verificada. La prueba interactiva prolongada, el ajuste
de balance y la comprobación en el PC del usuario siguen siendo validaciones útiles.

## Trabajo restante para el producto final

Arte y audio definitivos; catálogo de títulos ficticios; archivo y reemplazos;
política de ediciones especiales y excedentes; poscampaña; campaña de mayor escala;
correcciones del contrato SQL antes de adoptarlo para partidas; exportaciones y
pruebas por plataforma; integración de Steam. Esta entrega no pretende acreditar
esas funciones ni una publicación comercial.
