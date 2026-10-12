extends Node3D

const INTERVALO_AUTOGUARDADO: float = 60.0

var temporizador: Timer
var inicializada: bool = false
var operacion_en_curso: bool = false
var menu_visible: bool = false
var menu_fondo: ColorRect
var etiqueta_estado_menu: Label
var confirmacion_reinicio: ConfirmationDialog
var tienda = preload("res://Scripts/EstadoTienda.gd").new()
var mundo: Node3D
var panel_gestion: PanelContainer
var victoria_anunciada: bool = false


func _ready() -> void:
	mundo = preload("res://Scripts/TiendaVisual.gd").new()
	mundo.name = "TiendaVisual"
	add_child(mundo)
	for estanteria in $Estanterias.get_children():
		if estanteria is EstanteriaJuegos:
			estanteria.coleccion_completada.connect(_al_completar_coleccion)
	temporizador = Timer.new()
	temporizador.name = "TemporizadorGuardado"
	temporizador.wait_time = INTERVALO_AUTOGUARDADO
	temporizador.one_shot = false
	temporizador.timeout.connect(_guardar_automaticamente)
	add_child(temporizador)
	_crear_menu_pruebas()
	get_window().close_requested.connect(_guardar_al_cerrar)
	call_deferred("_iniciar_partida")


func _iniciar_partida() -> void:
	SaveManager.reanudar_guardado()
	if SaveManager.hay_partida():
		if SaveManager.cargar_partida(self):
			_mensaje("Partida recuperada. TAB: menú de pruebas")
		else:
			push_warning(SaveManager.ultimo_error)
			SaveManager.guardado_suspendido = true
			_mensaje("No se pudo recuperar la partida. Conservamos sus archivos: usa TAB para cargar o iniciar una campaña nueva.")
	else:
		_mensaje("Nueva partida. TAB: gestión. La bodega está detrás de ti; CLIC recoge y E clasifica.")
		var ids: Array = []
		for caja in $GeneradorJuegos.get_children():
			if caja is CajaJuego:
				ids.append(caja.id_copia)
		tienda.registrar_manifiesto(ids)
	inicializada = true
	operacion_en_curso = false
	temporizador.start()
	mundo.actualizar_ambiente(tienda.datos["fase"] == "DIA", tienda.datos["estilos"])
	victoria_anunciada = tienda.campana_completa()


func _process(delta: float) -> void:
	if not inicializada or operacion_en_curso or menu_visible:
		return
	var cantidad: int = 0
	var condicion: float = 0.0
	for estanteria in $Estanterias.get_children():
		if estanteria is EstanteriaJuegos:
			for copia in estanteria.juegos_guardados:
				cantidad += 1
				condicion += float(copia["condicion"])
	var calidad: float = condicion / cantidad if cantidad > 0 else 0.0
	for evento in tienda.avanzar(delta, cantidad, calidad):
		if evento["tipo"] == "visitante":
			mundo.mostrar_visitante()
		elif evento["tipo"] == "noche":
			mundo.actualizar_ambiente(false, tienda.datos["estilos"])
			_mensaje("Jornada terminada: %d visitantes · $%d. Organiza sin prisa; R en el mostrador abre el siguiente día." % [tienda.datos["visitantes_hoy"], tienda.datos["ingresos_hoy"]])
		SaveManager.solicitar_guardado()


func puede_interactuar_mostrador() -> bool:
	var jugador: Node3D = get_node_or_null("Player")
	return jugador != null and not menu_visible and jugador.global_position.distance_to(Vector3(7.0, jugador.global_position.y, 0.0)) <= 3.0


func interactuar_mostrador() -> void:
	if not puede_interactuar_mostrador():
		_mensaje("Acércate a la palanca del mostrador y pulsa R.")
		return
	if not tienda.abrir_dia():
		_mensaje("La tienda ya está abierta. Puedes seguir clasificando mientras llegan visitantes.")
		return
	mundo.activar_palanca()
	mundo.actualizar_ambiente(true, tienda.datos["estilos"])
	_mensaje("Día %d · Tienda abierta. Las entradas generan ingresos por tus colecciones." % tienda.datos["dia"])
	SaveManager.solicitar_guardado()


func registrar_clasificacion(id_copia: String) -> void:
	tienda.registrar_clasificacion(id_copia)
	if tienda.campana_completa() and not victoria_anunciada:
		victoria_anunciada = true
		_mensaje("¡Museo inaugurado! Has recuperado todo el stock de la campaña. Puedes seguir abriendo la tienda y mejorándola.")


func _al_completar_coleccion(id_juego: String) -> void:
	if tienda.completar_coleccion(id_juego):
		_mensaje("Primera colección completada: recompensa y experiencia obtenidas.")
		SaveManager.solicitar_guardado()


func comprar_mejora(tipo: String) -> void:
	var error: String = tienda.comprar_mejora(tipo)
	_mostrar_estado(error if not error.is_empty() else "Mejora adquirida: " + tipo)
	panel_gestion.actualizar()
	if error.is_empty():
		SaveManager.solicitar_guardado()


func comprar_estilo(tipo: String) -> void:
	var error: String = tienda.comprar_estilo(tipo)
	_mostrar_estado(error if not error.is_empty() else "La tienda estrena una mejora de estilo " + tipo)
	mundo.actualizar_ambiente(tienda.datos["fase"] == "DIA", tienda.datos["estilos"])
	panel_gestion.actualizar()
	if error.is_empty():
		SaveManager.solicitar_guardado()


func _input(event: InputEvent) -> void:
	if not inicializada or operacion_en_curso:
		return
	if not event is InputEventKey:
		return
	var tecla: InputEventKey = event as InputEventKey
	if not tecla.pressed or tecla.echo:
		return

	if tecla.keycode == KEY_TAB:
		_alternar_menu_pruebas()
		get_viewport().set_input_as_handled()
	elif tecla.keycode == KEY_ESCAPE and menu_visible:
		if not confirmacion_reinicio.visible:
			_cerrar_menu_pruebas()
			get_viewport().set_input_as_handled()
	elif tecla.keycode == KEY_F6:
		_guardar_desde_menu()
		get_viewport().set_input_as_handled()
	elif tecla.keycode == KEY_F9:
		_cargar_desde_menu()
		get_viewport().set_input_as_handled()
	elif tecla.physical_keycode == KEY_R and not menu_visible:
		interactuar_mostrador()
		get_viewport().set_input_as_handled()


func _crear_menu_pruebas() -> void:
	var capa: CanvasLayer = CanvasLayer.new()
	capa.name = "MenuPruebas"
	capa.layer = 90
	add_child(capa)

	menu_fondo = ColorRect.new()
	menu_fondo.name = "FondoMenu"
	menu_fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_fondo.color = Color(0.02, 0.03, 0.06, 0.78)
	menu_fondo.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_fondo.visible = false
	capa.add_child(menu_fondo)

	var centrador: CenterContainer = CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centrador.mouse_filter = Control.MOUSE_FILTER_PASS
	menu_fondo.add_child(centrador)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 600)
	centrador.add_child(panel)
	var desplazamiento: ScrollContainer = ScrollContainer.new()
	desplazamiento.custom_minimum_size = Vector2(740, 600)
	desplazamiento.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(desplazamiento)

	var margen: MarginContainer = MarginContainer.new()
	margen.add_theme_constant_override("margin_left", 20)
	margen.add_theme_constant_override("margin_right", 20)
	margen.add_theme_constant_override("margin_top", 20)
	margen.add_theme_constant_override("margin_bottom", 20)
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desplazamiento.add_child(margen)

	var columna: VBoxContainer = VBoxContainer.new()
	columna.add_theme_constant_override("separation", 12)
	margen.add_child(columna)

	var titulo: Label = Label.new()
	titulo.text = "THE LAST PHYSICAL STORE · GESTIÓN"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 19)
	columna.add_child(titulo)

	var descripcion: Label = Label.new()
	descripcion.text = "Conserva cada copia. Construye un museo."
	descripcion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(descripcion)
	panel_gestion = preload("res://Scripts/PanelGestion.gd").new()
	columna.add_child(panel_gestion)
	panel_gestion.construir(self)

	var boton_guardar: Button = _crear_boton_menu(columna, "Guardar partida (F6)")
	boton_guardar.pressed.connect(_guardar_desde_menu)

	var boton_cargar: Button = _crear_boton_menu(columna, "Cargar partida guardada (F9)")
	boton_cargar.pressed.connect(_cargar_desde_menu)

	var boton_reiniciar: Button = _crear_boton_menu(columna, "Nueva campaña — borrar progreso actual")
	boton_reiniciar.pressed.connect(_solicitar_confirmacion_reinicio)

	var boton_volver: Button = _crear_boton_menu(columna, "Continuar jugando (TAB)")
	boton_volver.pressed.connect(_cerrar_menu_pruebas)

	etiqueta_estado_menu = Label.new()
	etiqueta_estado_menu.text = "Pulsa TAB para volver al juego."
	etiqueta_estado_menu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	etiqueta_estado_menu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	columna.add_child(etiqueta_estado_menu)

	confirmacion_reinicio = ConfirmationDialog.new()
	confirmacion_reinicio.title = "Confirmar borrado de partida"
	confirmacion_reinicio.dialog_text = (
		"¿Borrar la partida, el respaldo y el archivo temporal?\n"
		+ "Esta acción no se puede deshacer."
	)
	confirmacion_reinicio.ok_button_text = "Sí, borrar y empezar de cero"
	confirmacion_reinicio.confirmed.connect(_confirmar_reinicio)
	capa.add_child(confirmacion_reinicio)


func _crear_boton_menu(padre: Node, texto: String) -> Button:
	var boton: Button = Button.new()
	boton.text = texto
	boton.custom_minimum_size = Vector2(0, 44)
	boton.focus_mode = Control.FOCUS_ALL
	padre.add_child(boton)
	return boton


func _alternar_menu_pruebas() -> void:
	if menu_visible:
		if not confirmacion_reinicio.visible:
			_cerrar_menu_pruebas()
	else:
		_abrir_menu_pruebas()


func _abrir_menu_pruebas() -> void:
	menu_visible = true
	menu_fondo.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var jugador: Node = get_node_or_null("Player")
	if jugador != null:
		jugador.set_physics_process(false)
		jugador.set_process_unhandled_input(false)
	etiqueta_estado_menu.text = "Puedes guardar, cargar o reiniciar desde aquí."
	panel_gestion.actualizar()


func _cerrar_menu_pruebas() -> void:
	menu_visible = false
	menu_fondo.visible = false
	var jugador: Node = get_node_or_null("Player")
	if jugador != null:
		jugador.set_physics_process(true)
		jugador.set_process_unhandled_input(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _guardar_desde_menu() -> void:
	if not inicializada or operacion_en_curso:
		return
	if SaveManager.guardar_partida(self):
		_mostrar_estado("Partida guardada correctamente.")
	else:
		_mostrar_estado("Error al guardar: " + SaveManager.ultimo_error)


func _cargar_desde_menu() -> void:
	if not inicializada or operacion_en_curso:
		return
	if not SaveManager.preparar_carga_por_recarga(self):
		_mostrar_estado("Error al cargar: " + SaveManager.ultimo_error)
		return

	_empezar_operacion()
	_mostrar_estado("Restaurando la partida desde una escena nueva...")
	SaveManager.call_deferred("recargar_escena_para_pruebas")


func _solicitar_confirmacion_reinicio() -> void:
	if not inicializada or operacion_en_curso:
		return
	confirmacion_reinicio.popup_centered(Vector2i(500, 180))


func _confirmar_reinicio() -> void:
	if not inicializada or operacion_en_curso:
		return

	_empezar_operacion()
	if not SaveManager.borrar_partida_para_pruebas():
		informar_fallo_reinicio("Error al borrar partida: " + SaveManager.ultimo_error)
		return

	_mostrar_estado("Partida eliminada. Creando una partida nueva...")
	SaveManager.call_deferred("recargar_escena_para_pruebas")


func _empezar_operacion() -> void:
	operacion_en_curso = true
	inicializada = false
	temporizador.stop()


func informar_fallo_reinicio(mensaje: String) -> void:
	operacion_en_curso = false
	inicializada = true
	SaveManager.reanudar_guardado()
	temporizador.start()
	_mostrar_estado(mensaje)


func _mostrar_estado(mensaje: String) -> void:
	print(mensaje)
	if etiqueta_estado_menu != null:
		etiqueta_estado_menu.text = mensaje
	_mensaje(mensaje)


func _guardar_automaticamente() -> void:
	if inicializada and not operacion_en_curso:
		SaveManager.guardar_partida(self)


func _mensaje(texto: String) -> void:
	var jugador: Node = get_node_or_null("Player")
	if jugador != null:
		jugador.call("mostrar_mensaje", texto)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_guardar_al_cerrar()


func _guardar_al_cerrar() -> void:
	if inicializada and not operacion_en_curso:
		SaveManager.guardar_partida(self)
