extends SceneTree

var pruebas: int = 0
var fallos: int = 0
var gestor: Node


func _initialize() -> void:
	call_deferred("_ejecutar")


func _comprobar(condicion: bool, texto: String) -> void:
	pruebas += 1
	if not condicion:
		fallos += 1
		push_error("FALLO: " + texto)


func _ejecutar() -> void:
	gestor = root.get_node("SaveManager")
	var ruta: String = OS.get_environment("TLPS_TEST_USER_DIR")
	if ruta != OS.get_user_data_dir() or not ruta.begins_with("/tmp/") or gestor.hay_partida():
		push_error("Se requiere un directorio temporal nuevo creado por el runner.")
		quit(2)
		return
	var escena: Node = load("res://node_3d.tscn").instantiate()
	root.add_child(escena)
	current_scene = escena
	await process_frame
	await process_frame
	var jugador: CharacterBody3D = escena.get_node("Player")
	jugador.set_physics_process(false)
	gestor.guardado_suspendido = true
	var generador: Node3D = escena.get_node("GeneradorJuegos")
	var copias: Array = generador.get_children().duplicate()
	_comprobar(copias.size() == 60, "Se generan 60 copias originales")
	_comprobar(escena.tienda.datos["manifiesto"].size() == 60, "La campaña fija el stock original")
	var titulos: Dictionary = {}
	var ids: Dictionary = {}
	for caja in copias:
		titulos[caja.id_juego] = int(titulos.get(caja.id_juego, 0)) + 1
		_comprobar(not ids.has(caja.id_copia), "Identidad única en stock")
		ids[caja.id_copia] = true
		_comprobar(caja.condicion >= 35 and caja.condicion <= 99 and not caja.es_especial, "Atributos dentro del catálogo de campaña")
	_comprobar(titulos.size() == 6, "Hay seis títulos coleccionables")
	for cantidad in titulos.values():
		_comprobar(cantidad == 10, "Cada colección puede completarse con diez copias")
	for caja in copias:
		jugador.inventario.append(caja.obtener_datos().duplicate(true))
		_comprobar(caja.recoger(), "La copia sale de bodega")
		var estanteria: EstanteriaJuegos
		for candidata in escena.get_node("Estanterias").get_children():
			if candidata.consola == caja.consola:
				estanteria = candidata
		jugador.global_position = estanteria.global_position + Vector3(0, 1.05, 2)
		jugador.rotation = Vector3.ZERO
		jugador.intentar_ordenar()
		_comprobar(jugador.inventario.is_empty(), "Colocar transfiere la copia sin duplicarla")
	await process_frame
	jugador.set_physics_process(false)
	_comprobar(generador.get_child_count() == 0, "La bodega se vacía al terminar")
	_comprobar(escena.tienda.campana_completa() and escena.victoria_anunciada, "Se reconoce el final de campaña")
	_comprobar(escena.tienda.datos["dinero"] == 720, "Seis recompensas únicas")
	_comprobar(escena.tienda.datos["xp"] == 600, "XP de clasificación y colección")
	var dinero: int = escena.tienda.datos["dinero"]
	for id_juego in titulos:
		escena._al_completar_coleccion(id_juego)
	_comprobar(escena.tienda.datos["dinero"] == dinero, "La recompensa histórica no se repite")
	escena.comprar_mejora("inventario")
	_comprobar(jugador.obtener_capacidad() == 7, "La mejora se aplica al jugador")
	escena.comprar_mejora("alcance")
	_comprobar(is_equal_approx(jugador.obtener_alcance(), 3.5), "El alcance se aplica al raycast")
	for estilo in ["arcade", "museo", "cyber"]:
		escena.comprar_estilo(estilo)
		_comprobar(escena.tienda.datos["estilos"][estilo] == 1, "Los estilos se pueden combinar")
	jugador.global_position = Vector3.ZERO
	escena.interactuar_mostrador()
	_comprobar(escena.tienda.datos["fase"] == "NOCHE", "La palanca requiere proximidad")
	jugador.global_position = Vector3(7, 1.05, -1)
	escena.interactuar_mostrador()
	_comprobar(escena.tienda.datos["fase"] == "DIA" and escena.tienda.datos["dia"] == 1, "La palanca inicia la jornada")
	dinero = escena.tienda.datos["dinero"]
	escena._process(12.0)
	_comprobar(escena.tienda.datos["dinero"] > dinero and escena.tienda.datos["visitantes_hoy"] == 1, "Las entradas generan ingresos")
	_comprobar(escena.mundo._visitantes.size() == 1, "El ingreso tiene representación de visitante")
	escena._abrir_menu_pruebas()
	var restante: float = escena.tienda.datos["restante"]
	escena._process(180.0)
	_comprobar(escena.tienda.datos["restante"] == restante, "La gestión pausa el tiempo comercial")
	escena._cerrar_menu_pruebas()
	jugador.set_physics_process(false)
	escena._process(180.0)
	_comprobar(escena.tienda.datos["fase"] == "NOCHE" and escena.tienda.datos["visitantes_hoy"] == 15, "La jornada finaliza sin visitas infinitas")
	dinero = escena.tienda.datos["dinero"]
	escena._process(1000.0)
	_comprobar(escena.tienda.datos["dinero"] == dinero, "La noche no genera ingresos")
	gestor.reanudar_guardado()
	_comprobar(gestor.guardar_partida(escena), "El progreso avanzado se guarda")
	var guardado: Dictionary = gestor._leer_estado(gestor.RUTA)
	_comprobar(guardado["version"] == 2 and guardado["tienda"]["dinero"] == dinero, "Guardado versionado incluye economía")
	escena.tienda.datos["dinero"] = 0
	_comprobar(gestor.cargar_partida(escena), "El estado avanzado se carga")
	_comprobar(escena.tienda.datos["dinero"] == dinero and jugador.obtener_capacidad() == 7, "Dinero y mejoras se restauran")
	_comprobar(escena.tienda.campana_completa(), "El final de campaña persiste")
	var capacidad: Dictionary = guardado.duplicate(true)
	var origen: Array = capacidad["estanterias"]["EstanteriaPS1"]["copias"]
	for i in range(7):
		var copia: Dictionary = origen.pop_back()
		copia.erase("posicion_estanteria")
		capacidad["inventario"].append(copia)
	_comprobar(gestor._validar_estado(capacidad, escena).is_empty(), "El guardado admite siete copias con la mejora")
	capacidad["tienda"]["mejoras"]["inventario"] = 0
	_comprobar(not gestor._validar_estado(capacidad, escena).is_empty(), "El guardado rechaza capacidad sin mejora")
	var invalido: Dictionary = guardado.duplicate(true)
	invalido["tienda"]["clasificadas"].append("copia_inexistente")
	_comprobar(not gestor._validar_estado(invalido, escena).is_empty(), "Progreso no puede referenciar copias inexistentes")
	var antiguo: Dictionary = guardado.duplicate(true)
	antiguo["version"] = 1
	antiguo.erase("tienda")
	antiguo["estanterias"]["EstanteriaPS1"]["copias"][0]["es_especial"] = true
	var texto: String = JSON.stringify(antiguo)
	var archivo: FileAccess = FileAccess.open(gestor.RUTA, FileAccess.WRITE)
	archivo.store_string(texto)
	archivo.close()
	_comprobar(gestor.cargar_partida(escena), "Se admite el formato del Sprint 07")
	_comprobar(FileAccess.get_file_as_string(gestor.RUTA_LEGACY) == texto, "El original antiguo se conserva intacto")
	var recuperado: Dictionary = gestor._capturar_estado(escena)
	var estanterias_recuperadas: Dictionary = JSON.parse_string(JSON.stringify(recuperado["estanterias"]))
	var estanterias_originales: Dictionary = JSON.parse_string(JSON.stringify(antiguo["estanterias"]))
	_comprobar(estanterias_recuperadas == estanterias_originales, "Migrar conserva IDs, slots, condiciones y edición booleana")
	_comprobar(escena.tienda.datos["dinero"] == 0 and escena.tienda.datos["xp"] == 0, "Migrar no inventa recompensas pasadas")
	_comprobar(escena.tienda.campana_completa(), "Migrar reconoce las copias ya clasificadas")
	_comprobar(gestor.guardar_partida(escena), "La partida migrada se guarda como versión dos")
	_comprobar(FileAccess.get_file_as_string(gestor.RUTA_LEGACY) == texto, "El nuevo guardado no pisa el original antiguo")
	print("CAMPAÑA: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
