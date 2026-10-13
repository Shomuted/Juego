extends CanvasLayer
class_name HudTienda

const TINTA: Color = Color("101d2b")
const CREMA: Color = Color("f2e6cd")
const MENTA: Color = Color("83dcc6")
const APAGADO: Color = Color("a1b4bf")
const CORAL: Color = Color("ee9e84")
const TITULOS: Array[String] = ["ff7_ps1", "mgs_ps1", "gt4_ps2", "sh2_ps2", "mario64_n64", "zeldaoot_n64"]
const NOMBRES: Array[String] = ["Final Fantasy VII", "Metal Gear Solid", "Gran Turismo 4", "Silent Hill 2", "Super Mario 64", "Zelda: Ocarina of Time"]

@onready var jugador: CharacterBody3D = get_parent() as CharacterBody3D

var inventario_label: Label
var lista_label: Label
var progreso_label: Label
var interaccion_label: Label
var mensaje_label: Label
var ultimo_mensaje: String = ""
var tiempo_mensaje: float = 0.0
var dia_label: Label
var economia_label: Label
var visitas_label: Label
var objetivo_label: Label
var objetivo_barra: ProgressBar
var victoria: PanelContainer
var notificacion: PanelContainer
var mira: Label
var filas_coleccion: Array[Dictionary] = []
var _actualizar_en: float = 0.0


func _ready() -> void:
	layer = 5
	var interfaz: Control = Control.new()
	interfaz.name = "Interfaz"
	interfaz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(interfaz)

	var cabecera: PanelContainer = _panel(interfaz, TINTA, 0.96)
	cabecera.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	cabecera.offset_left = 20
	cabecera.offset_right = -20
	cabecera.offset_top = 18
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 18)
	cabecera.add_child(fila)
	var marca: Label = _texto(fila, "TL/PS", 24, MENTA)
	marca.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var identidad: VBoxContainer = _columna(fila, 0)
	_texto(identidad, "THE LAST PHYSICAL STORE", 19, CREMA)
	_texto(identidad, "CADA COPIA TIENE UNA HISTORIA", 10, APAGADO)
	var espacio: Control = Control.new()
	espacio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fila.add_child(espacio)
	var estado: VBoxContainer = _columna(fila, 1)
	dia_label = _texto(estado, "DÍA 01  /  PREPARACIÓN", 14, CREMA)
	visitas_label = _texto(estado, "0 visitantes hoy", 11, APAGADO)
	var dinero: VBoxContainer = _columna(fila, 1)
	economia_label = _texto(dinero, "$ 0    ·    0 XP", 19, MENTA)
	economia_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var gestion: Label = _texto(dinero, "TAB  ·  GESTIÓN DEL MUSEO", 10, APAGADO)
	gestion.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var mochila: PanelContainer = _panel(interfaz)
	mochila.position = Vector2(20, 108)
	mochila.custom_minimum_size = Vector2(252, 0)
	var contenido: VBoxContainer = _columna(mochila, 8)
	inventario_label = _texto(contenido, "EN TUS MANOS  0 / 5", 13, MENTA)
	lista_label = _texto(contenido, "Busca juegos entre los montones del suelo.", 12, CREMA)
	lista_label.custom_minimum_size.x = 220
	lista_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lista_label.clip_text = true
	_texto(contenido, "CLIC recoger  ·  E clasificar", 10, APAGADO)

	var archivo: PanelContainer = _panel(interfaz)
	archivo.anchor_left = 1.0
	archivo.anchor_right = 1.0
	archivo.offset_left = -246
	archivo.offset_right = -20
	archivo.offset_top = 108
	var colecciones: VBoxContainer = _columna(archivo, 9)
	progreso_label = _texto(colecciones, "ORDENADOS  ·  0 / 60", 13, MENTA)
	for indice in range(TITULOS.size()):
		var grupo: VBoxContainer = _columna(colecciones, 3)
		var fila_nombre: HBoxContainer = HBoxContainer.new()
		grupo.add_child(fila_nombre)
		var nombre: Label = _texto(fila_nombre, NOMBRES[indice], 11, CREMA)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var contador: Label = _texto(fila_nombre, "0/10", 11, APAGADO)
		var barra: ProgressBar = _barra(grupo, 10.0, 3)
		filas_coleccion.append({"contador": contador, "barra": barra})

	var objetivo: PanelContainer = _panel(interfaz)
	objetivo.anchor_top = 1.0
	objetivo.anchor_bottom = 1.0
	objetivo.offset_left = 20
	objetivo.offset_right = 272
	objetivo.offset_top = -171
	objetivo.offset_bottom = -67
	var tarea: VBoxContainer = _columna(objetivo, 5)
	_texto(tarea, "DEL SUELO A LA ESTANTERÍA", 10, CORAL)
	objetivo_label = _texto(tarea, "Ordena las 60 copias del suelo\ny completa las 6 colecciones.", 12, CREMA)
	objetivo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objetivo_barra = _barra(tarea, 60.0, 4)

	mira = _texto(interfaz, "·", 34, CREMA)
	mira.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mira.offset_left = -8
	mira.offset_top = -24
	mira.offset_right = 8
	mira.offset_bottom = 24
	mira.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mira.add_theme_color_override("font_shadow_color", TINTA)
	mira.add_theme_constant_override("shadow_offset_x", 1)
	mira.add_theme_constant_override("shadow_offset_y", 1)

	var indicacion: PanelContainer = _panel(interfaz, TINTA, 0.96)
	indicacion.anchor_left = 0.5
	indicacion.anchor_right = 0.5
	indicacion.anchor_top = 1.0
	indicacion.anchor_bottom = 1.0
	indicacion.offset_left = -208
	indicacion.offset_right = 238
	indicacion.offset_top = -103
	indicacion.offset_bottom = -62
	interaccion_label = _texto(indicacion, "Busca entre los montones y recoge tu primera copia", 12, CREMA)
	interaccion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaccion_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaccion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	notificacion = _panel(interfaz, Color("204839"), 0.98)
	notificacion.anchor_left = 0.5
	notificacion.anchor_right = 0.5
	notificacion.anchor_top = 1.0
	notificacion.anchor_bottom = 1.0
	notificacion.offset_left = -208
	notificacion.offset_right = 238
	notificacion.offset_top = -170
	notificacion.offset_bottom = -115
	mensaje_label = _texto(notificacion, "", 12, CREMA)
	mensaje_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mensaje_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notificacion.visible = false

	victoria = _panel(interfaz, Color("d2b977"), 0.99)
	victoria.anchor_left = 0.5
	victoria.anchor_right = 0.5
	victoria.offset_left = -198
	victoria.offset_right = 198
	victoria.offset_top = 104
	var anuncio: VBoxContainer = _columna(victoria, 2)
	var titulo: Label = _texto(anuncio, "¡TIENDA ORDENADA!", 21, TINTA)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var detalle: Label = _texto(anuncio, "60 copias en su sitio · 6 colecciones completas", 11, TINTA)
	detalle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victoria.visible = false

	var controles: PanelContainer = _panel(interfaz, TINTA, 0.96)
	controles.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	controles.offset_top = -42
	controles.offset_bottom = -10
	controles.offset_left = 20
	controles.offset_right = -20
	var ayuda: Label = _texto(controles, "WASD  MOVER      RATÓN  MIRAR      CLIC  RECOGER      E  CLASIFICAR      R  MOSTRADOR      TAB  GESTIÓN      F6 / F9  GUARDAR / CARGAR", 10, APAGADO)
	ayuda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ignorar_raton(interfaz)
	_actualizar_datos()


func _panel(padre: Node, color: Color = TINTA, opacidad: float = 0.88) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = Color(color, opacidad)
	estilo.corner_radius_top_left = 6
	estilo.corner_radius_top_right = 6
	estilo.corner_radius_bottom_left = 6
	estilo.corner_radius_bottom_right = 6
	estilo.content_margin_left = 14
	estilo.content_margin_right = 14
	estilo.content_margin_top = 11
	estilo.content_margin_bottom = 11
	estilo.border_color = Color(MENTA, 0.14)
	estilo.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", estilo)
	padre.add_child(panel)
	return panel


func _columna(padre: Node, separacion: int) -> VBoxContainer:
	var columna: VBoxContainer = VBoxContainer.new()
	columna.add_theme_constant_override("separation", separacion)
	padre.add_child(columna)
	return columna


func _texto(padre: Node, contenido: String, tamano: int, color: Color = CREMA) -> Label:
	var etiqueta: Label = Label.new()
	etiqueta.text = contenido
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	padre.add_child(etiqueta)
	return etiqueta


func _barra(padre: Node, maximo: float, altura: int) -> ProgressBar:
	var barra: ProgressBar = ProgressBar.new()
	barra.show_percentage = false
	barra.max_value = maximo
	barra.custom_minimum_size.y = altura
	var fondo: StyleBoxFlat = StyleBoxFlat.new()
	fondo.bg_color = Color("344451")
	var relleno: StyleBoxFlat = StyleBoxFlat.new()
	relleno.bg_color = MENTA
	barra.add_theme_stylebox_override("background", fondo)
	barra.add_theme_stylebox_override("fill", relleno)
	padre.add_child(barra)
	return barra


func _ignorar_raton(nodo: Node) -> void:
	if nodo is Control:
		(nodo as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hijo in nodo.get_children():
		_ignorar_raton(hijo)


func _estado() -> Object:
	if jugador == null:
		return null
	var escena: Node = jugador.get_parent()
	if escena != null and escena.has_method("comprar_mejora"):
		return escena.get("tienda") as Object
	return null


func _process(delta: float) -> void:
	if jugador == null:
		return
	tiempo_mensaje = maxf(0.0, tiempo_mensaje - delta)
	notificacion.visible = tiempo_mensaje > 0.0
	mensaje_label.text = ultimo_mensaje if tiempo_mensaje > 0.0 else ""
	_actualizar_en -= delta
	if _actualizar_en <= 0.0:
		_actualizar_en = 0.15
		_actualizar_datos()
		_actualizar_interaccion()


func _actualizar_datos() -> void:
	if jugador == null:
		return
	var juegos: Array = jugador.get("inventario")
	var capacidad: int = int(jugador.call("obtener_capacidad")) if jugador.has_method("obtener_capacidad") else 5
	inventario_label.text = "EN TUS MANOS  %d / %d" % [juegos.size(), capacidad]
	var lineas: PackedStringArray = PackedStringArray()
	for indice in range(mini(juegos.size(), 5)):
		var juego: Dictionary = juegos[indice]
		var titulo: String = str(juego.get("titulo", "Juego"))
		if titulo.length() > 25:
			titulo = titulo.left(24) + "…"
		lineas.append("%s\n%s · %d/100%s" % [titulo, str(juego.get("consola", "?")), int(juego.get("condicion", 0)), " · ESPECIAL" if bool(juego.get("es_especial", false)) else ""])
	if juegos.size() > 5:
		lineas.append("+ %d copias más · E para clasificar" % (juegos.size() - 5))
	lista_label.text = "\n".join(lineas) if not lineas.is_empty() else "Busca juegos entre los montones del suelo.\nCada copia ordenada aporta 1 XP."

	var total: int = 0
	var completas: int = 0
	for indice in range(TITULOS.size()):
		var cantidad: int = 0
		for estanteria in get_tree().get_nodes_in_group("estanteria"):
			if estanteria.has_method("cantidad_de_copias"):
				cantidad += int(estanteria.call("cantidad_de_copias", TITULOS[indice]))
		total += cantidad
		if cantidad >= 10:
			completas += 1
		var contador: Label = filas_coleccion[indice]["contador"] as Label
		contador.text = "%d/10" % cantidad
		contador.add_theme_color_override("font_color", MENTA if cantidad == 10 else APAGADO)
		(filas_coleccion[indice]["barra"] as ProgressBar).value = cantidad
	progreso_label.text = "ORDENADOS  ·  %d / 60" % total
	objetivo_barra.value = total

	var tienda: Object = _estado()
	if tienda == null:
		return
	var datos: Dictionary = tienda.get("datos")
	var es_dia: bool = str(datos.get("fase", "NOCHE")) == "DIA"
	var segundos: int = maxi(0, ceili(float(datos.get("restante", 0))))
	dia_label.text = "DÍA %02d  /  %s" % [int(datos.get("dia", 1)), ("ABIERTO  %02d:%02d" % [segundos / 60, segundos % 60]) if es_dia else "PREPARACIÓN"]
	economia_label.text = "$ %d    ·    %d XP" % [int(datos.get("dinero", 0)), int(datos.get("xp", 0))]
	visitas_label.text = "%d visitantes hoy  ·  $%d recaudados" % [int(datos.get("visitantes_hoy", 0)), int(datos.get("ingresos_hoy", 0))]
	victoria.visible = tienda.has_method("campana_completa") and bool(tienda.call("campana_completa"))
	if victoria.visible:
		objetivo_label.text = "60 copias en su sitio.\nLa tienda está ordenada."
	elif total == 0 and juegos.is_empty():
		objetivo_label.text = "Mira al suelo y recoge\ntu primera copia con CLIC."
	elif not juegos.is_empty():
		objetivo_label.text = "Pulsa E junto a su estantería.\nCada copia nueva suma 1 XP."
	elif es_dia:
		objetivo_label.text = "Sigue despejando el suelo\nmientras llegan las visitas."
	else:
		objetivo_label.text = "%d / 6 colecciones completas.\nBusca más copias en el suelo." % completas


func _actualizar_interaccion() -> void:
	var escena: Node = jugador.get_parent()
	var menu_abierto: bool = bool(escena.get("menu_visible")) if escena.has_method("comprar_mejora") else false
	mira.visible = not menu_abierto
	interaccion_label.text = "CLIC recoger  ·  E clasificar  ·  R mostrador"
	var estanteria: Object = jugador.call("obtener_estanteria_objetivo")
	if estanteria != null:
		var juegos: Array = estanteria.get("juegos_guardados")
		interaccion_label.text = "[ E ]  Clasificar en %s   ·   %d / %d" % [str(estanteria.get("consola")), juegos.size(), int(estanteria.get("capacidad"))]
	var raycast: RayCast3D = jugador.get("raycast") as RayCast3D
	if raycast != null:
		raycast.force_raycast_update()
		if raycast.is_colliding():
			var objeto: Node = raycast.get_collider() as Node
			if objeto != null and objeto.is_in_group("juego"):
				interaccion_label.text = "[ CLIC ]  %s  ·  %s" % [str(objeto.get("titulo")), str(objeto.get("consola"))]
	if escena.has_method("puede_interactuar_mostrador") and escena.puede_interactuar_mostrador():
		var tienda: Object = _estado()
		var datos: Dictionary = tienda.get("datos") if tienda != null else {}
		interaccion_label.text = "Museo abierto · visita en curso" if str(datos.get("fase", "NOCHE")) == "DIA" else "[ R ]  Abrir el museo al público"


func mostrar_mensaje(mensaje: String) -> void:
	ultimo_mensaje = mensaje
	tiempo_mensaje = 6.2
