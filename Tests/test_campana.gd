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
	# La primera recogida usa el raycast real. La fixture se inmoviliza a la
	# vista para probar la interacción sin depender del orden aleatorio del suelo.
	var primera: CajaJuego = copias.pop_front()
	var primer_id: String = primera.id_copia
	var primera_consola: String = primera.consola
	primera.freeze = true
	jugador.global_position = Vector3(0, 1.05, 0)
	jugador.rotation = Vector3.ZERO
	jugador.get_node("Head").rotation = Vector3.ZERO
	primera.global_position = jugador.camera.global_position - jugador.camera.global_basis.z * 2.0
	for _i in range(2):
		await physics_frame
		await process_frame
	jugador.intentar_recoger()
	_comprobar(jugador.inventario.size() == 1 and jugador.inventario[0]["id_copia"] == primer_id, "Recoger alcanza una copia original con el raycast")
	_comprobar(escena.tienda.datos["xp"] == 0 and escena.tienda.datos["dinero"] == 0, "Recoger del suelo no concede XP ni dinero")
	var primera_estanteria: EstanteriaJuegos
	var estanteria_incorrecta: EstanteriaJuegos
	for candidata in escena.get_node("Estanterias").get_children():
		if candidata.consola == primera_consola:
			primera_estanteria = candidata
		else:
			estanteria_incorrecta = candidata
	jugador.global_position = estanteria_incorrecta.global_position + Vector3(0, 1.05, 2)
	jugador.intentar_ordenar()
	_comprobar(jugador.inventario.size() == 1 and escena.tienda.datos["xp"] == 0 and escena.tienda.datos["dinero"] == 0, "Rechazar una plataforma incorrecta conserva la copia y no premia")
	jugador.global_position = primera_estanteria.global_position + Vector3(0, 1.05, 2)
	jugador.intentar_ordenar()
	_comprobar(jugador.inventario.is_empty() and escena.tienda.datos["xp"] == 1, "La primera copia aceptada en estantería concede exactamente 1 XP")
	jugador.intentar_ordenar()
	escena.registrar_clasificacion(primer_id)
	_comprobar(escena.tienda.datos["xp"] == 1 and escena.tienda.datos["dinero"] == 0, "Repetir clasificación o pulsar sin copias no duplica XP ni crea dinero")
	var clasificadas: int = 1
	for caja in copias:
		jugador.inventario.append(caja.obtener_datos().duplicate(true))
		_comprobar(caja.recoger(), "La copia sale del suelo")
		_comprobar(escena.tienda.datos["xp"] == clasificadas and escena.tienda.datos["dinero"] == 0, "Cargar una copia no premia")
		var estanteria: EstanteriaJuegos
		for candidata in escena.get_node("Estanterias").get_children():
			if candidata.consola == caja.consola:
				estanteria = candidata
		jugador.global_position = estanteria.global_position + Vector3(0, 1.05, 2)
		jugador.rotation = Vector3.ZERO
		jugador.intentar_ordenar()
		_comprobar(jugador.inventario.is_empty(), "Colocar transfiere la copia sin duplicarla")
		clasificadas += 1
		_comprobar(escena.tienda.datos["xp"] == clasificadas and escena.tienda.datos["dinero"] == 0, "Cada copia exhibida suma solo 1 XP, incluso al completar colección")
	await process_frame
	jugador.set_physics_process(false)
	_comprobar(generador.get_child_count() == 0, "No quedan copias en el suelo al terminar")
	_comprobar(escena.tienda.campana_completa() and escena.victoria_anunciada, "Se reconoce el final de campaña")
	_comprobar(escena.tienda.datos["dinero"] == 0, "Completar seis colecciones no crea dinero")
	_comprobar(escena.tienda.datos["xp"] == 60, "60 copias exhibidas equivalen exactamente a 60 XP")
	var dinero: int = escena.tienda.datos["dinero"]
	for id_juego in titulos:
		escena._al_completar_coleccion(id_juego)
	_comprobar(escena.tienda.datos["dinero"] == dinero and escena.tienda.datos["xp"] == 60, "Repetir eventos de colección no cambia dinero ni XP")
	escena.comprar_mejora("inventario")
	_comprobar(jugador.obtener_capacidad() == 5 and escena.tienda.datos["dinero"] == 0, "La experiencia de ordenar no sustituye los ingresos necesarios para comprar")
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
	escena.interactuar_mostrador()
	escena._process(180.0)
	_comprobar(escena.tienda.datos["dinero"] >= 320 and escena.tienda.datos["visitantes_total"] == 30, "Dos jornadas reales de entradas financian las mejoras y estilos")
	dinero = escena.tienda.datos["dinero"]
	escena.comprar_mejora("inventario")
	_comprobar(jugador.obtener_capacidad() == 7, "La mejora pagada con entradas se aplica al jugador")
	escena.comprar_mejora("alcance")
	_comprobar(is_equal_approx(jugador.obtener_alcance(), 3.5), "El alcance pagado con entradas se aplica al raycast")
	for estilo in ["arcade", "museo", "cyber"]:
		escena.comprar_estilo(estilo)
		_comprobar(escena.tienda.datos["estilos"][estilo] == 1, "Los estilos se pueden combinar")
	_comprobar(escena.tienda.datos["dinero"] == dinero - 320 and escena.tienda.datos["xp"] == 60, "Las compras descuentan los precios y conservan los 60 XP")
	dinero = escena.tienda.datos["dinero"]
	gestor.reanudar_guardado()
	_comprobar(gestor.guardar_partida(escena), "El progreso avanzado se guarda")
	var guardado: Dictionary = gestor._leer_estado(gestor.RUTA)
	_comprobar(guardado["version"] == 3 and guardado["tienda"]["dinero"] == dinero, "Guardado versión tres incluye economía")
	escena.tienda.datos["dinero"] = 0
	_comprobar(gestor.cargar_partida(escena), "El estado avanzado se carga")
	_comprobar(escena.tienda.datos["dinero"] == dinero and jugador.obtener_capacidad() == 7, "Dinero y mejoras se restauran")
	_comprobar(escena.tienda.campana_completa(), "El final de campaña persiste")
	_comprobar(escena.tienda.datos["xp"] == 60, "Cargar no suma XP ni premios de colección")
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
	_comprobar(escena.tienda.datos["dinero"] == 0 and escena.tienda.datos["xp"] == 60, "Migrar Sprint 07 reconoce 1 XP por copia exhibida sin crear dinero")
	_comprobar(escena.tienda.campana_completa(), "Migrar reconoce las copias ya clasificadas")
	_comprobar(gestor.guardar_partida(escena), "La partida migrada se guarda como versión tres")
	_comprobar(FileAccess.get_file_as_string(gestor.RUTA_LEGACY) == texto, "El nuevo guardado no pisa el original antiguo")
	# Una Alpha 0.2 parcialmente ordenada conserva sus compras y dinero, pero
	# abandona las mesas y recalcula la XP a partir de sus copias clasificadas.
	var alpha02: Dictionary = guardado.duplicate(true)
	alpha02["version"] = 2
	alpha02["tienda"]["xp"] = 600
	alpha02["tienda"]["dinero"] = 720
	var originales_suelo: Dictionary = {}
	for i in range(5):
		var copia: Dictionary = alpha02["estanterias"]["EstanteriaPS1"]["copias"].pop_back()
		copia.erase("posicion_estanteria")
		alpha02["tienda"]["clasificadas"].erase(copia["id_copia"])
		alpha02["tienda"]["completadas"].erase(copia["id_juego"])
		if i < 2:
			alpha02["inventario"].append(copia)
		else:
			copia["es_especial"] = i == 2
			originales_suelo[copia["id_copia"]] = copia.duplicate(true)
			alpha02["bodega"].append({
				"datos": copia,
				"posicion": [float(i), 1.12, 6.5],
				"rotacion": [0.0, PI, 0.0],
				"velocidad_lineal": [0.0, 0.0, 0.0],
				"velocidad_angular": [0.0, 0.0, 0.0]
			})
	var texto_alpha02: String = JSON.stringify(alpha02)
	archivo = FileAccess.open(gestor.RUTA, FileAccess.WRITE)
	archivo.store_string(texto_alpha02)
	archivo.close()
	_comprobar(gestor.cargar_partida(escena), "Se admite la campaña anterior de Alpha 0.2")
	_comprobar(FileAccess.get_file_as_string(gestor.RUTA_ALPHA02) == texto_alpha02, "La Alpha 0.2 original se conserva intacta antes de migrar")
	_comprobar(escena.tienda.datos["xp"] == 55 and escena.tienda.datos["dinero"] == 720, "Migrar Alpha 0.2 corrige XP inflada y conserva dinero previo")
	_comprobar(jugador.obtener_capacidad() == 7 and is_equal_approx(jugador.obtener_alcance(), 3.5), "Migrar conserva las mejoras pagadas")
	_comprobar(escena.tienda.datos["estilos"] == alpha02["tienda"]["estilos"], "Migrar conserva los tres estilos pagados")
	var migrado: Dictionary = gestor._capturar_estado(escena)
	_comprobar(JSON.parse_string(JSON.stringify(migrado["inventario"])) == JSON.parse_string(JSON.stringify(alpha02["inventario"])), "Migrar conserva cada copia que el jugador llevaba")
	_comprobar(JSON.parse_string(JSON.stringify(migrado["estanterias"])) == JSON.parse_string(JSON.stringify(alpha02["estanterias"])), "Migrar Alpha 0.2 conserva títulos, copias y slots ya ordenados")
	_comprobar(migrado["bodega"].size() == 3, "Migrar redistribuye solo las copias sueltas")
	for registro in migrado["bodega"]:
		var id_suelo: String = registro["datos"]["id_copia"]
		_comprobar(originales_suelo.has(id_suelo) and JSON.parse_string(JSON.stringify(registro["datos"])) == JSON.parse_string(JSON.stringify(originales_suelo[id_suelo])), "Redistribuir preserva ID, título, condición y edición de cada copia")
		_comprobar(float(registro["posicion"][1]) < 1.0, "Las copias migradas parten cerca del suelo, fuera de las antiguas mesas")
	_comprobar(not escena.tienda.campana_completa(), "La migración conserva el trabajo de ordenar pendiente")
	_comprobar(gestor.guardar_partida(escena), "La Alpha 0.2 migrada se guarda en versión tres")
	var corregido: Dictionary = gestor._leer_estado(gestor.RUTA)
	_comprobar(corregido["version"] == 3 and corregido["tienda"]["xp"] == 55, "El nuevo archivo persiste la regla de 1 XP por copia")
	_comprobar(gestor.cargar_partida(escena), "El archivo migrado se puede volver a cargar")
	var recargado: Dictionary = gestor._capturar_estado(escena)
	_comprobar(JSON.parse_string(JSON.stringify(recargado["bodega"])) == corregido["bodega"], "Recargar versión tres preserva posiciones, rotaciones y velocidades sin redistribuir otra vez")
	_comprobar(escena.tienda.datos["xp"] == 55 and escena.tienda.datos["dinero"] == 720, "Recargar la migración no añade XP ni dinero")
	_comprobar(FileAccess.get_file_as_string(gestor.RUTA_ALPHA02) == texto_alpha02, "Guardar y cargar no modifica la copia original de Alpha 0.2")
	print("CAMPAÑA: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
