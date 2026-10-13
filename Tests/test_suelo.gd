extends SceneTree

# Regresión del ciclo central: ninguna caja se mueve ni se congela desde esta
# prueba. Solo se sitúa al jugador en lugares libres y se utiliza su raycast.
var pruebas: int = 0
var fallos: int = 0
var terminada: bool = false
var escena: Node3D
var jugador: CharacterBody3D
var generador: Node3D
var gestor: Node


func _initialize() -> void:
	call_deferred("_ejecutar")


func _comprobar(condicion: bool, texto: String) -> void:
	pruebas += 1
	if not condicion:
		fallos += 1
		push_error("FALLO: " + texto)


func _terminar() -> void:
	if terminada:
		return
	terminada = true
	print("SUELO: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)


func _fisica(cantidad: int) -> void:
	for _i in range(cantidad):
		await physics_frame
		await process_frame


func _cajas() -> Array[CajaJuego]:
	var resultado: Array[CajaJuego] = []
	for nodo in generador.get_children():
		if nodo is CajaJuego and not nodo.fue_recolectada:
			resultado.append(nodo)
	return resultado


func _mirar(punto: Vector3) -> void:
	var direccion: Vector3 = punto - jugador.camera.global_position
	jugador.rotation = Vector3(0, atan2(-direccion.x, -direccion.z), 0)
	jugador.cabeza.rotation = Vector3(atan2(direccion.y,
		Vector2(direccion.x, direccion.z).length()), 0, 0)
	jugador.velocity = Vector3.ZERO
	jugador.raycast.target_position.z = -jugador.obtener_alcance()
	jugador.raycast.force_raycast_update()


func _lugar_libre(posicion: Vector3) -> bool:
	var consulta := PhysicsShapeQueryParameters3D.new()
	consulta.shape = jugador.get_node("CollisionShape3D").shape
	consulta.transform = Transform3D(Basis.IDENTITY, posicion)
	consulta.collision_mask = 1
	consulta.exclude = [jugador.get_rid()]
	return escena.get_world_3d().direct_space_state.intersect_shape(consulta, 1).is_empty()


func _buscar_copia_visible() -> CajaJuego:
	var pendientes: Array[CajaJuego] = _cajas()
	# Retirar primero las cajas altas va descubriendo las que están debajo.
	pendientes.sort_custom(func(a: CajaJuego, b: CajaJuego) -> bool:
		return a.global_position.y > b.global_position.y)
	for objetivo in pendientes:
		for radio in [1.1, 1.6]:
			for lado in range(8):
				var angulo: float = lado * TAU / 8.0
				var lugar: Vector3 = Vector3(objetivo.global_position.x + cos(angulo) * radio,
					0.95, objetivo.global_position.z + sin(angulo) * radio)
				if not _lugar_libre(lugar):
					continue
				jugador.global_position = lugar
				_mirar(objetivo.global_position)
				var visible: CajaJuego = jugador.raycast.get_collider() as CajaJuego
				if visible != null and not visible.fue_recolectada:
					return visible
	return null


func _ejecutar() -> void:
	gestor = root.get_node("SaveManager")
	var ruta: String = OS.get_environment("TLPS_TEST_USER_DIR")
	if ruta != OS.get_user_data_dir() or not ruta.begins_with("/tmp/") or gestor.hay_partida():
		push_error("La prueba del suelo requiere un directorio temporal nuevo del runner.")
		quit(2)
		return
	create_timer(60.0).timeout.connect(func() -> void:
		_comprobar(false, "Las copias del suelo se pueden recoger antes del límite de la prueba")
		_terminar())
	escena = load("res://node_3d.tscn").instantiate() as Node3D
	root.add_child(escena)
	current_scene = escena
	await process_frame
	await process_frame
	jugador = escena.get_node("Player") as CharacterBody3D
	generador = escena.get_node("GeneradorJuegos") as Node3D
	gestor.guardado_suspendido = true
	gestor.guardado_pendiente = false
	escena.temporizador.stop()
	jugador.set_physics_process(false)
	_comprobar(escena.inicializada and _cajas().size() == 60, "La partida real comienza con sus 60 copias en el suelo")
	_comprobar(jugador.inventario.is_empty() and escena.tienda.datos["xp"] == 0,
		"El jugador comienza sin copias recogidas ni experiencia")
	# Cuatro segundos de física real, suficientes para caer y formar montones.
	await _fisica(240)
	var originales: Dictionary = {}
	var titulos: Dictionary = {}
	var copias: Array[CajaJuego] = _cajas()
	var excluidas: Array[RID] = [jugador.get_rid()]
	var minimo := Vector3(INF, INF, INF)
	var maximo := Vector3(-INF, -INF, -INF)
	for caja in copias:
		_comprobar(not originales.has(caja.id_copia), "Cada copia física conserva una identidad única")
		originales[caja.id_copia] = caja.obtener_datos().duplicate(true)
		titulos[caja.id_juego] = int(titulos.get(caja.id_juego, 0)) + 1
		excluidas.append(caja.get_rid())
		minimo = minimo.min(caja.global_position)
		maximo = maximo.max(caja.global_position)
		_comprobar(not caja.freeze and caja.global_position.y > -0.08 and caja.global_position.y < 1.3,
			"La copia es física y reposa sobre el suelo o sobre otras copias")
		_comprobar(absf(caja.global_position.x) < 10.5 and caja.global_position.z > -7.5 and caja.global_position.z < 11.5,
			"Las caídas conservan las copias dentro de la zona accesible")
		_comprobar(caja.linear_velocity.length() < 0.6,
			"La pila se estabiliza sin expulsar continuamente sus copias")
	_comprobar(titulos.size() == 6, "Los montones contienen los seis títulos de campaña")
	for cantidad in titulos.values():
		_comprobar(cantidad == 10, "Cada colección conserva sus diez copias disponibles")
	_comprobar(maximo.x - minimo.x > 10.0 and maximo.z - minimo.z > 12.0,
		"El desorden ocupa la tienda en ambas direcciones")
	var grupos_mezclados: int = 0
	for centro in escena.tienda.reglas["suelo"]["montones"]:
		var juegos: Dictionary = {}
		var plataformas: Dictionary = {}
		for caja in copias:
			if Vector2(caja.position.x, caja.position.z).distance_to(Vector2(centro[0], centro[1])) < 1.35:
				juegos[caja.id_juego] = true
				plataformas[caja.consola] = true
		if juegos.size() >= 2 and plataformas.size() >= 2:
			grupos_mezclados += 1
	_comprobar(grupos_mezclados >= 4, "Los montones mezclan títulos y plataformas, sin preclasificarlos")
	var espacio: PhysicsDirectSpaceState3D = escena.get_world_3d().direct_space_state
	var tapadas: Dictionary = {}
	for caja in copias:
		var consulta := PhysicsRayQueryParameters3D.create(
			Vector3(caja.global_position.x, 2.0, caja.global_position.z), caja.global_position, 1)
		var impacto: Dictionary = espacio.intersect_ray(consulta)
		var encima: CajaJuego = impacto.get("collider") as CajaJuego
		if encima != null and encima != caja and encima.global_position.y > caja.global_position.y + 0.035:
			tapadas[caja.id_copia] = encima.id_copia
	_comprobar(tapadas.size() >= 3, "Hay copias realmente tapadas por otras después de asentarse la física")
	# Las posiciones donde había seis mesas deben estar abiertas hasta el suelo.
	for z in [6.5, 9.5]:
		for x in [-6.0, 0.0, 6.0]:
			var consulta := PhysicsRayQueryParameters3D.create(Vector3(x, 2, z), Vector3(x, -0.1, z), 1, excluidas)
			var impacto: Dictionary = espacio.intersect_ray(consulta)
			_comprobar(not impacto.is_empty() and absf(impacto["position"].y) < 0.05,
				"No queda una mesa física que preordene las copias")
	for x in [-8.0, -3.0, 0.0, 3.0, 8.0]:
		var consulta := PhysicsRayQueryParameters3D.create(Vector3(x, 1.5, 2.8), Vector3(x, 1.5, 5.2), 1, excluidas)
		_comprobar(espacio.intersect_ray(consulta).is_empty(), "La tienda permite pasar entre ambos sectores sin un tabique interior")
	print("SUELO observado: %d montones mezclados, %d copias tapadas." % [grupos_mezclados, tapadas.size()])
	# Guardar y restaurar no vuelve a sortear ni a repartir las copias de v3.
	gestor.reanudar_guardado()
	_comprobar(gestor.guardar_partida(escena), "El desorden físico se puede guardar")
	var guardado: Dictionary = gestor._leer_estado(gestor.RUTA)
	_comprobar(guardado["version"] == 3, "Se utiliza el formato que conserva el reparto corregido")
	_comprobar(gestor.cargar_partida(escena), "El desorden guardado se puede restaurar")
	var recargado: Dictionary = gestor._capturar_estado(escena)
	_comprobar(JSON.parse_string(JSON.stringify(recargado["bodega"])) == guardado["bodega"],
		"Cargar conserva las posiciones, giros, velocidades y atributos de las 60 copias")
	gestor.guardado_suspendido = true
	gestor.guardado_pendiente = false
	await _fisica(2)
	var recogidas: Dictionary = {}
	var descubiertas: int = 0
	for indice in range(60):
		var visible: CajaJuego = _buscar_copia_visible()
		_comprobar(visible != null, "Se puede apuntar a una copia física pendiente desde un lugar libre")
		if visible == null:
			break
		var id_copia: String = visible.id_copia
		var consola: String = visible.consola
		if tapadas.has(id_copia) and recogidas.has(tapadas[id_copia]):
			descubiertas += 1
		_comprobar(jugador.camera.global_position.distance_to(visible.global_position) <= jugador.obtener_alcance(),
			"La recogida desde el suelo está dentro del alcance normal")
		jugador.intentar_recoger()
		_comprobar(jugador.inventario.size() == 1 and jugador.inventario[0] == originales[id_copia],
			"El raycast recoge exactamente la copia visible y todos sus atributos")
		_comprobar(escena.tienda.datos["xp"] == indice and escena.tienda.datos["dinero"] == 0,
			"Recoger una caja del montón no premia experiencia ni dinero")
		recogidas[id_copia] = true
		await _fisica(1)
		var estanteria: EstanteriaJuegos
		for candidata in escena.get_node("Estanterias").get_children():
			if candidata.consola == consola:
				estanteria = candidata
		jugador.global_position = estanteria.global_position + Vector3(0, 0.95, 2)
		jugador.rotation = Vector3.ZERO
		jugador.cabeza.rotation = Vector3.ZERO
		jugador.intentar_ordenar()
		_comprobar(jugador.inventario.is_empty() and escena.tienda.datos["xp"] == indice + 1,
			"Colocar la copia física en su estantería añade exactamente 1 XP")
		_comprobar(escena.tienda.datos["dinero"] == 0, "Ordenar y completar colecciones no concede dinero")
		await _fisica(1)
	_comprobar(descubiertas >= 1, "Retirar las cajas superiores descubre y permite recoger copias que estaban tapadas")
	_comprobar(recogidas.size() == 60 and _cajas().is_empty(), "Las 60 copias originales se recogen mediante raycast, sin cajas inaccesibles")
	var exhibidas: Dictionary = {}
	for estanteria in escena.get_node("Estanterias").get_children():
		for datos in estanteria.juegos_guardados:
			var copia: Dictionary = datos.duplicate(true)
			copia.erase("posicion_estanteria")
			_comprobar(copia == originales[copia["id_copia"]] and not exhibidas.has(copia["id_copia"]),
				"La exposición conserva una sola copia de cada identidad y sus atributos originales")
			exhibidas[copia["id_copia"]] = true
	_comprobar(exhibidas.size() == 60 and escena.tienda.datos["xp"] == 60 and escena.tienda.campana_completa(),
		"Ordenar todo el desorden completa las seis colecciones y termina con 60 XP")
	_terminar()
