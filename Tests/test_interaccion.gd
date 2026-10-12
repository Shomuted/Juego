extends SceneTree

# Ejecutar con XDG_DATA_HOME aislado: esta prueba nunca borra partidas.
var pruebas: int = 0
var fallos: int = 0
var terminada: bool = false
var escena: Node3D
var jugador: CharacterBody3D
var generador: Node3D
var save_manager: Node
var escena_caja: PackedScene = preload("res://caja_juego.tscn")


func _initialize() -> void:
	call_deferred("_ejecutar")


func _comprobar(condicion: bool, descripcion: String) -> void:
	pruebas += 1
	if condicion:
		print("OK: " + descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)


func _terminar() -> void:
	if terminada:
		return
	terminada = true
	Input.action_release("Mover_derecha")
	print("INTERACCIÓN: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)


func _esperar_fisica(cantidad: int = 2) -> void:
	for _i in range(cantidad):
		await physics_frame
		await process_frame


func _apuntar_desde_inicio() -> void:
	jugador.global_position = Vector3(0, 1.05, 0)
	jugador.rotation = Vector3.ZERO
	jugador.get_node("Head").rotation = Vector3.ZERO
	jugador.velocity = Vector3.ZERO


func _crear_caja(id_juego: String, id_copia: String, distancia: float = 2.0) -> CajaJuego:
	var caja: CajaJuego = escena_caja.instantiate() as CajaJuego
	if not caja.configurar(id_juego, 83, true, id_copia):
		_comprobar(false, "Se configura la copia física " + id_copia)
		caja.free()
		return null
	# La colisión permanece real; congelar la fixture evita que la gravedad
	# cambie el punto al que apunta el jugador durante esta prueba de interacción.
	caja.freeze = true
	generador.add_child(caja)
	var camera: Camera3D = jugador.get_node("Head/Camera3D") as Camera3D
	caja.global_position = camera.global_position - camera.global_basis.z * distancia
	return caja


func _mirar_estanteria(estanteria: EstanteriaJuegos) -> void:
	jugador.global_position = estanteria.global_position + Vector3(0, 1.05, 2)
	jugador.rotation = Vector3.ZERO
	jugador.get_node("Head").rotation = Vector3.ZERO
	await _esperar_fisica()
	_comprobar(
		jugador.obtener_estanteria_objetivo() == estanteria,
		"El jugador apunta a la estantería " + estanteria.consola
	)


func _enviar_tecla(codigo: Key) -> void:
	var evento: InputEventKey = InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = true
	root.push_input(evento)
	evento = InputEventKey.new()
	evento.keycode = codigo
	evento.physical_keycode = codigo
	evento.pressed = false
	root.push_input(evento)
	await process_frame


func _ejecutar() -> void:
	create_timer(35.0).timeout.connect(func() -> void:
		_comprobar(false, "La interacción termina antes del límite de 35 segundos")
		_terminar()
	)
	# Los autoloads aún no existen al compilar un script de SceneTree.
	save_manager = root.get_node("SaveManager")
	if save_manager.hay_partida():
		_comprobar(false, "Usar un XDG_DATA_HOME vacío y aislado; se conserva la partida existente")
		_terminar()
		return

	escena = load("res://node_3d.tscn").instantiate() as Node3D
	escena.get_node("GeneradorJuegos").generar_al_iniciar = false
	root.add_child(escena)
	jugador = escena.get_node("Player") as CharacterBody3D
	generador = escena.get_node("GeneradorJuegos") as Node3D
	# Main reanuda guardado en _iniciar_partida, llamado de forma diferida.
	for _i in range(3):
		await process_frame
		if escena.inicializada:
			break
	save_manager.guardado_suspendido = true
	save_manager.guardado_pendiente = false
	escena.temporizador.stop()
	jugador.set_physics_process(false)
	_apuntar_desde_inicio()
	_comprobar(escena.inicializada, "La escena real termina su inicialización")
	_comprobar(generador.get_child_count() == 0, "El generador está deshabilitado")
	_comprobar(jugador.inventario.is_empty(), "La partida de prueba inicia sin inventario")

	var caja: CajaJuego = _crear_caja("mgs_ps1", "interaccion_mgs_1", 4.0)
	if caja == null:
		_terminar()
		return
	var datos: Dictionary = caja.obtener_datos().duplicate(true)
	await _esperar_fisica()
	jugador.intentar_recoger()
	_comprobar(jugador.inventario.is_empty() and not caja.fue_recolectada, "No recoge una caja fuera del alcance de 3 metros")
	caja.global_position = jugador.camera.global_position - jugador.camera.global_basis.z * 2.0
	await _esperar_fisica()
	jugador.raycast.force_raycast_update()
	_comprobar(jugador.raycast.get_collider() == caja, "El raycast físico impacta la caja configurada")
	jugador.intentar_recoger()
	jugador.intentar_recoger()
	_comprobar(jugador.inventario.size() == 1, "Dos recogidas en el mismo frame agregan solo una copia")
	_comprobar(caja.fue_recolectada and caja.is_queued_for_deletion(), "Recoger marca y retira el cuerpo de la bodega")
	_comprobar(jugador.inventario.size() == 1 and jugador.inventario[0] == datos, "Recoger conserva ID, título, plataforma, condición y edición especial")
	await process_frame
	_comprobar(not is_instance_valid(caja), "La caja física desaparece después del frame")
	var estado: Dictionary = save_manager._capturar_estado(escena)
	_comprobar(estado["bodega"].is_empty() and estado["inventario"].size() == 1, "La captura de estado ubica la copia solo en inventario")

	var ps1: EstanteriaJuegos = escena.get_node("Estanterias/EstanteriaPS1") as EstanteriaJuegos
	var ps2: EstanteriaJuegos = escena.get_node("Estanterias/EstanteriaPS2") as EstanteriaJuegos
	await _mirar_estanteria(ps2)
	jugador.intentar_ordenar()
	_comprobar(jugador.inventario.size() == 1 and ps2.juegos_guardados.is_empty(), "Ordenar rechaza la plataforma incorrecta sin perder la copia")
	_comprobar(jugador.hud.ultimo_mensaje.contains("No llevas juegos de PS2"), "El rechazo de plataforma informa al jugador")
	await _mirar_estanteria(ps1)
	jugador.intentar_ordenar()
	_comprobar(jugador.inventario.is_empty(), "Ordenar retira del inventario la copia aceptada")
	var guardada: Dictionary = ps1.obtener_copia_en_posicion(1, 0)
	var esperado: Dictionary = datos.duplicate(true)
	esperado["posicion_estanteria"] = 10
	_comprobar(guardada == esperado, "MGS conserva todos sus atributos en el slot reservado 10")
	var visual_original: Node3D = ps1.exhibicion.get_node_or_null("Posicion_10") as Node3D
	_comprobar(visual_original != null, "La copia ordenada tiene un visual en su slot")
	var transformacion_original: Transform3D = visual_original.transform if visual_original != null else Transform3D.IDENTITY

	_apuntar_desde_inicio()
	for titulo in ["ff7_ps1", "mgs_ps1"]:
		caja = _crear_caja(titulo, "interaccion_segunda_" + titulo)
		if caja == null:
			_terminar()
			return
		await _esperar_fisica()
		jugador.intentar_recoger()
		await process_frame
	_comprobar(jugador.inventario.size() == 2, "El raycast permite recoger dos títulos consecutivos")
	await _mirar_estanteria(ps1)
	jugador.intentar_ordenar()
	jugador.intentar_ordenar()
	_comprobar(ps1.obtener_copia_en_posicion(0, 0).get("id_copia") == "interaccion_segunda_ff7_ps1", "FF7 ocupa su fila reservada sin desplazar MGS")
	_comprobar(ps1.obtener_copia_en_posicion(1, 1).get("id_copia") == "interaccion_segunda_mgs_ps1", "La segunda copia MGS ocupa el siguiente slot libre")
	_comprobar(ps1.obtener_copia_en_posicion(1, 0) == esperado, "El ID y los atributos del slot original permanecen estables")
	_comprobar(is_instance_valid(visual_original) and visual_original.transform == transformacion_original, "Agregar copias no mueve el visual existente")
	_comprobar(jugador.inventario.is_empty() and ps1.juegos_guardados.size() == 3, "Las tres copias se transfieren sin duplicados")

	_apuntar_desde_inicio()
	for indice in range(6):
		caja = _crear_caja("ff7_ps1", "interaccion_limite_%d" % indice)
		if caja == null:
			_terminar()
			return
		await _esperar_fisica()
		jugador.intentar_recoger()
		_comprobar(jugador.inventario.size() == mini(indice + 1, 5), "Recogida %d respeta la capacidad de cinco copias" % (indice + 1))
		if indice < 5:
			await process_frame
	_comprobar(is_instance_valid(caja) and not caja.fue_recolectada and not caja.is_queued_for_deletion(), "La sexta caja permanece disponible en la bodega")
	_comprobar(jugador.hud.ultimo_mensaje.contains("Inventario lleno"), "El límite de capacidad informa al jugador")
	estado = save_manager._capturar_estado(escena)
	_comprobar(estado["bodega"].size() == 1 and estado["inventario"].size() == 5, "El estado conserva cinco copias cargadas y una en bodega")
	_comprobar(save_manager._validar_estado(estado, escena).is_empty(), "El estado completo tras las interacciones mantiene IDs y ubicaciones válidas")

	jugador.set_physics_process(true)
	await _esperar_fisica()
	await _enviar_tecla(KEY_TAB)
	_comprobar(escena.menu_visible and escena.menu_fondo.visible, "TAB abre el menú de pruebas")
	_comprobar(not jugador.is_physics_processing() and not jugador.is_processing_unhandled_input(), "El menú pausa movimiento y controles del jugador")
	var posicion_pausada: Vector3 = jugador.global_position
	Input.action_press("Mover_derecha")
	await _esperar_fisica(4)
	_comprobar(jugador.global_position.is_equal_approx(posicion_pausada), "Mantener movimiento con el menú abierto no desplaza al jugador")
	await _enviar_tecla(KEY_ESCAPE)
	_comprobar(not escena.menu_visible and not escena.menu_fondo.visible, "ESC cierra el menú de pruebas")
	_comprobar(jugador.is_physics_processing() and jugador.is_processing_unhandled_input(), "Cerrar el menú reactiva movimiento y controles")
	await _esperar_fisica(4)
	Input.action_release("Mover_derecha")
	_comprobar(jugador.global_position.x > posicion_pausada.x + 0.05, "El jugador vuelve a moverse tras cerrar el menú")
	_comprobar(not save_manager.hay_partida(), "La prueba termina sin escribir ni borrar partidas")
	_terminar()
