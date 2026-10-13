extends PanelContainer
class_name PanelGestion

const TINTA: Color = Color("101d2b")
const CREMA: Color = Color("f2e6cd")
const MENTA: Color = Color("83dcc6")
const APAGADO: Color = Color("a1b4bf")
const CORAL: Color = Color("ee9e84")
const TITULOS: Array[String] = ["ff7_ps1", "mgs_ps1", "gt4_ps2", "sh2_ps2", "mario64_n64", "zeldaoot_n64"]
const NOMBRES_MEJORAS: Dictionary = {"inventario": "Mochila de conservador", "alcance": "Alcance de recuperación"}
const NOMBRES_ESTILOS: Dictionary = {"arcade": "Arcade", "museo": "Museo", "cyber": "Cyber"}
const DESCRIPCIONES_ESTILOS: Dictionary = {
	"arcade": "Luz cálida y memoria de los salones recreativos.",
	"museo": "Vitrinas y piezas para un archivo con carácter.",
	"cyber": "Acentos de neón y tecnología de otra época."
}

var escena: Node
var resumen: Label
var guia_mostrador: Label
var ficha_coleccion: Label
var compras: Array[Dictionary] = []
var colecciones: Array[Dictionary] = []
var _refrescar_en: float = 0.0


func construir(principal: Node) -> void:
	escena = principal
	name = "PanelGestion"
	custom_minimum_size = Vector2(580, 0)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var pestanas: TabContainer = TabContainer.new()
	pestanas.custom_minimum_size.y = 332
	pestanas.add_theme_font_size_override("font_size", 15)
	pestanas.add_theme_color_override("font_selected_color", TINTA)
	pestanas.add_theme_color_override("font_unselected_color", APAGADO)
	pestanas.add_theme_color_override("font_hovered_color", CREMA)
	pestanas.add_theme_stylebox_override("panel", _estilo(Color("172735"), 11))
	pestanas.add_theme_stylebox_override("tab_selected", _estilo(MENTA, 12))
	pestanas.add_theme_stylebox_override("tab_unselected", _estilo(TINTA, 12))
	pestanas.add_theme_stylebox_override("tab_hovered", _estilo(Color("294452"), 12))
	add_child(pestanas)
	var tienda: VBoxContainer = _pagina(pestanas, "Tienda")
	resumen = _texto(tienda, "Preparando el archivo…", 14, MENTA)
	guia_mostrador = _texto(tienda, "Acércate al mostrador y pulsa R para abrir.", 12, APAGADO)
	_texto(tienda, "HERRAMIENTAS DEL CONSERVADOR", 11, CORAL)
	for tipo in ["inventario", "alcance"]:
		_crear_compra(tienda, "mejoras", tipo)
	_texto(tienda, "IDENTIDAD DEL MUSEO  ·  ESTILOS COMBINABLES", 11, CORAL)
	for tipo in ["arcade", "museo", "cyber"]:
		_crear_compra(tienda, "estilos", tipo)
	_texto(tienda, "Cada copia colocada por primera vez en su estantería suma 1 XP. La experiencia se conserva al comprar; las compras consumen dinero de las visitas. Cada estilo tiene tres niveles y aumenta el ingreso por entrada.", 11, APAGADO)

	var archivo: VBoxContainer = _pagina(pestanas, "Colecciones")
	ficha_coleccion = _texto(archivo, "ORDENADOS  ·  0 / 60 COPIAS", 15, MENTA)
	_texto(archivo, "Los juegos están mezclados y amontonados por el suelo de la tienda. Encuentra y ordena diez copias de cada título para completar seis colecciones. Cada copia conserva su condición y su edición.", 12, APAGADO)
	for id_juego in TITULOS:
		var marco: PanelContainer = PanelContainer.new()
		marco.add_theme_stylebox_override("panel", _estilo(Color("1e3340"), 10))
		archivo.add_child(marco)
		var grupo: VBoxContainer = VBoxContainer.new()
		grupo.add_theme_constant_override("separation", 4)
		marco.add_child(grupo)
		var fila: HBoxContainer = HBoxContainer.new()
		grupo.add_child(fila)
		var datos: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
		var nombre: Label = _texto(fila, "%s  ·  %s" % [str(datos.get("consola", "")), str(datos.get("titulo", id_juego))], 13, CREMA)
		nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cuenta: Label = _texto(fila, "0 / 10", 13, MENTA)
		var calidad: Label = _texto(grupo, "Sin ejemplares exhibidos.", 11, APAGADO)
		var barra: ProgressBar = ProgressBar.new()
		barra.max_value = 10
		barra.show_percentage = false
		barra.custom_minimum_size.y = 4
		barra.add_theme_stylebox_override("background", _estilo(Color("344451"), 0))
		barra.add_theme_stylebox_override("fill", _estilo(MENTA, 0))
		grupo.add_child(barra)
		colecciones.append({"id": id_juego, "cuenta": cuenta, "calidad": calidad, "barra": barra})

	var ayuda: VBoxContainer = _pagina(pestanas, "Ayuda")
	_texto(ayuda, "DEL DESORDEN A LA COLECCIÓN", 15, MENTA)
	_texto(ayuda, "La tienda empieza con juegos tirados y amontonados por todas partes. Busca entre el desorden, recoge las copias y llévalas a su estantería. Los juegos permanecen contigo: tus ingresos vienen de las visitas.", 13, CREMA)
	_ayuda(ayuda, "01  BUSCAR Y RECOGER", "Explora el suelo de la tienda y sus montones de juegos mezclados. Apunta a una copia y pulsa CLIC. Su plataforma, condición y edición viajan con ella en tu inventario.")
	_ayuda(ayuda, "02  ORDENAR", "Acércate a la estantería de su plataforma y pulsa E. Cada título tiene una fila de diez copias. Cada copia colocada por primera vez aporta exactamente 1 XP. Completar la fila registra la colección, sin premios adicionales de XP o dinero.")
	_ayuda(ayuda, "03  ABRIR LAS PUERTAS", "Acércate al mostrador y pulsa R. El público visita la exposición durante la jornada. La colección y su calidad aportan valor a las entradas. Puedes seguir clasificando durante las visitas.")
	_ayuda(ayuda, "04  HACER CRECER EL ARCHIVO", "Usa la recaudación en herramientas y decoración desde la pestaña Tienda. Combina Arcade, Museo y Cyber. Al acabar la jornada, prepara la siguiente apertura desde el mostrador.")
	_ayuda(ayuda, "05  COMPLETAR LAS COLECCIONES", "Despeja el suelo llevando las 60 copias a sus estanterías. Completa las seis colecciones para terminar de ordenar la tienda. Después puedes continuar recibiendo visitantes y mejorando el museo.")
	_texto(ayuda, "CONTROLES", 11, CORAL)
	_texto(ayuda, "WASD · caminar    Ratón · mirar    Espacio · saltar\nCLIC · recoger    E · clasificar    R · mostrador\nTAB · gestión y pausa    ESC · cerrar el menú\nF6 · guardar    F9 · cargar el último guardado", 12, CREMA)
	_texto(ayuda, "La partida se guarda automáticamente. Cargar recupera el último guardado; reiniciar requiere confirmación y borra el progreso.", 11, APAGADO)
	actualizar()


func _pagina(pestanas: TabContainer, titulo: String) -> VBoxContainer:
	var desplazamiento: ScrollContainer = ScrollContainer.new()
	desplazamiento.name = titulo
	desplazamiento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	desplazamiento.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pestanas.add_child(desplazamiento)
	var columna: VBoxContainer = VBoxContainer.new()
	columna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columna.add_theme_constant_override("separation", 11)
	desplazamiento.add_child(columna)
	return columna


func _crear_compra(padre: Node, categoria: String, tipo: String) -> void:
	var marco: PanelContainer = PanelContainer.new()
	marco.add_theme_stylebox_override("panel", _estilo(Color("1e3340"), 10))
	padre.add_child(marco)
	var fila: HBoxContainer = HBoxContainer.new()
	fila.add_theme_constant_override("separation", 12)
	marco.add_child(fila)
	var detalles: VBoxContainer = VBoxContainer.new()
	detalles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detalles.add_theme_constant_override("separation", 4)
	fila.add_child(detalles)
	var nombre: Label = _texto(detalles, "", 13, CREMA)
	var descripcion: Label = _texto(detalles, "", 11, APAGADO)
	var boton: Button = Button.new()
	boton.custom_minimum_size = Vector2(150, 43)
	boton.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	boton.add_theme_font_size_override("font_size", 12)
	boton.add_theme_color_override("font_color", TINTA)
	boton.add_theme_color_override("font_hover_color", TINTA)
	boton.add_theme_color_override("font_pressed_color", TINTA)
	boton.add_theme_color_override("font_disabled_color", APAGADO)
	boton.add_theme_stylebox_override("normal", _estilo(MENTA, 9))
	boton.add_theme_stylebox_override("hover", _estilo(Color("b6eedc"), 9))
	boton.add_theme_stylebox_override("pressed", _estilo(Color("60bba5"), 9))
	boton.add_theme_stylebox_override("disabled", _estilo(Color("344451"), 9))
	var foco: StyleBoxFlat = _estilo(Color(0, 0, 0, 0), 9)
	foco.border_color = CREMA
	foco.set_border_width_all(2)
	boton.add_theme_stylebox_override("focus", foco)
	boton.pressed.connect(_comprar.bind(categoria, tipo))
	fila.add_child(boton)
	compras.append({"categoria": categoria, "tipo": tipo, "nombre": nombre, "descripcion": descripcion, "boton": boton})


func _texto(padre: Node, contenido: String, tamano: int, color: Color) -> Label:
	var etiqueta: Label = Label.new()
	etiqueta.text = contenido
	etiqueta.add_theme_font_size_override("font_size", tamano)
	etiqueta.add_theme_color_override("font_color", color)
	etiqueta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	etiqueta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	padre.add_child(etiqueta)
	return etiqueta


func _ayuda(padre: Node, titulo: String, contenido: String) -> void:
	_texto(padre, titulo, 11, CORAL)
	_texto(padre, contenido, 12, CREMA)


func _estilo(color: Color, margen: int) -> StyleBoxFlat:
	var estilo: StyleBoxFlat = StyleBoxFlat.new()
	estilo.bg_color = color
	estilo.set_corner_radius_all(5)
	estilo.content_margin_left = margen
	estilo.content_margin_right = margen
	estilo.content_margin_top = margen
	estilo.content_margin_bottom = margen
	return estilo


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refrescar_en -= delta
	if _refrescar_en <= 0.0:
		_refrescar_en = 0.35
		actualizar()


func actualizar() -> void:
	if escena == null or not escena.has_method("comprar_mejora"):
		return
	var tienda: Object = escena.get("tienda") as Object
	if tienda == null:
		return
	var datos: Dictionary = tienda.get("datos")
	var reglas: Dictionary = tienda.get("reglas")
	var dinero: int = int(datos.get("dinero", 0))
	var xp: int = int(datos.get("xp", 0))
	resumen.text = "DÍA %02d   ·   $ %d DISPONIBLES   ·   %d XP\nHoy: %d visitas y $ %d recaudados   ·   %d visitas totales" % [
		int(datos.get("dia", 1)), dinero, xp, int(datos.get("visitantes_hoy", 0)), int(datos.get("ingresos_hoy", 0)), int(datos.get("visitantes_total", 0))
	]
	guia_mostrador.text = "El museo está abierto. La jornada termina automáticamente." if str(datos.get("fase", "NOCHE")) == "DIA" else "Acércate al mostrador y pulsa R para abrir."
	for compra in compras:
		var categoria: String = str(compra["categoria"])
		var tipo: String = str(compra["tipo"])
		var niveles: Dictionary = datos.get(categoria, {})
		var configuraciones: Dictionary = reglas.get(categoria, {})
		var regla: Dictionary = configuraciones.get(tipo, {})
		var costos: Array = regla.get("costos", [])
		var requisitos: Array = regla.get("xp", [])
		var nivel: int = int(niveles.get(tipo, 0))
		var completo: bool = nivel >= costos.size()
		var nombre: String = str(NOMBRES_MEJORAS[tipo]) if categoria == "mejoras" else str(NOMBRES_ESTILOS[tipo])
		(compra["nombre"] as Label).text = "%s  ·  %d / %d" % [nombre, nivel, costos.size()]
		var descripcion: Label = compra["descripcion"] as Label
		if categoria == "estilos":
			descripcion.text = str(DESCRIPCIONES_ESTILOS.get(tipo, ""))
		elif tipo == "inventario":
			var capacidad: int = int(regla.get("base", 5)) + nivel * int(regla.get("paso", 2))
			descripcion.text = "%d copias en tus manos%s" % [capacidad, " → %d" % (capacidad + int(regla.get("paso", 2))) if not completo else " · máxima capacidad"]
		else:
			var alcance: float = float(regla.get("base", 3.0)) + nivel * float(regla.get("paso", 0.5))
			descripcion.text = "Recogida a %.1f m%s" % [alcance, " → %.1f m" % (alcance + float(regla.get("paso", 0.5))) if not completo else " · máximo alcance"]
		var boton: Button = compra["boton"] as Button
		if completo:
			boton.text = "NIVEL MÁXIMO"
			boton.disabled = true
			boton.tooltip_text = "Has completado esta mejora."
			continue
		var precio: int = int(costos[nivel])
		var xp_requerida: int = int(requisitos[nivel]) if nivel < requisitos.size() else 0
		boton.text = "$ %d%s" % [precio, " · %d XP" % xp_requerida if xp_requerida > 0 else " · MEJORAR"]
		boton.disabled = dinero < precio or xp < xp_requerida
		boton.tooltip_text = "Cuesta $ %d. Requiere %d XP acumulada; la experiencia se conserva." % [precio, xp_requerida]
		if dinero < precio:
			boton.tooltip_text += " Faltan $ %d." % (precio - dinero)
		if xp < xp_requerida:
			boton.tooltip_text += " Faltan %d XP." % (xp_requerida - xp)

	var preservadas: int = 0
	var completas: int = 0
	for coleccion in colecciones:
		var id_juego: String = str(coleccion["id"])
		var cantidad: int = 0
		var calidad_total: float = 0.0
		var especiales: int = 0
		for estanteria in get_tree().get_nodes_in_group("estanteria"):
			if not estanteria.has_method("cantidad_de_copias"):
				continue
			var piezas: int = int(estanteria.call("cantidad_de_copias", id_juego))
			cantidad += piezas
			calidad_total += float(estanteria.call("promedio_condicion", id_juego)) * piezas
			var guardadas: Array = estanteria.get("juegos_guardados")
			for copia in guardadas:
				if str(copia.get("id_juego", "")) == id_juego and bool(copia.get("es_especial", false)):
					especiales += 1
		preservadas += cantidad
		if cantidad >= 10:
			completas += 1
		(coleccion["cuenta"] as Label).text = "%d / 10%s" % [cantidad, "  COMPLETA" if cantidad >= 10 else ""]
		(coleccion["barra"] as ProgressBar).value = cantidad
		(coleccion["calidad"] as Label).text = "Calidad media %.1f / 10  ·  %d ediciones especiales" % [calidad_total / cantidad, especiales] if cantidad > 0 else "Todavía no hay ejemplares exhibidos."
	ficha_coleccion.text = "%d / 60 COPIAS ORDENADAS   ·   %d / 6 COLECCIONES" % [preservadas, completas]


func _comprar(categoria: String, tipo: String) -> void:
	if escena == null:
		return
	var metodo: String = "comprar_mejora" if categoria == "mejoras" else "comprar_estilo"
	if escena.has_method(metodo):
		escena.call(metodo, tipo)
		actualizar()
