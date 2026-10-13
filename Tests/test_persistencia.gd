extends SceneTree

# Ejecutar con XDG_DATA_HOME, XDG_CONFIG_HOME y XDG_CACHE_HOME temporales.
# TLPS_TEST_USER_DIR debe ser exactamente OS.get_user_data_dir().
# La prueba principal rechaza carpetas con partidas. La fase de reapertura
# solo lee la fixture creada por otro proceso del runner en su carpeta temporal.
var fallos: int = 0
var pruebas: int = 0
var save_manager: Node


func _initialize() -> void:
	call_deferred("_ejecutar")


func _comprobar(condicion: bool, descripcion: String) -> void:
	pruebas += 1
	if condicion:
		print("OK: ", descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)


func _entorno_aislado(lectura: bool = false) -> bool:
	var esperado: String = OS.get_environment("TLPS_TEST_USER_DIR")
	if esperado.is_empty() or esperado != OS.get_user_data_dir():
		push_error("Prueba cancelada: TLPS_TEST_USER_DIR debe coincidir con user://.")
		return false
	if not esperado.simplify_path().begins_with("/tmp/"):
		push_error("Prueba cancelada: user:// debe estar dentro de /tmp/.")
		return false
	# Solo la fase de lectura de otro proceso puede recibir la fixture ya guardada.
	if lectura:
		return FileAccess.file_exists(save_manager.RUTA)
	for ruta: String in [save_manager.RUTA, save_manager.RUTA_RESPALDO, save_manager.RUTA_TEMPORAL]:
		if FileAccess.file_exists(ruta):
			push_error("Prueba cancelada: el directorio temporal ya contiene una partida.")
			return false
	return true


func _copia(id_juego: String, id_copia: String, condicion: int = 72) -> Dictionary:
	var definicion: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
	return {
		"id_juego": id_juego,
		"id_copia": id_copia,
		"titulo": definicion["titulo"],
		"consola": definicion["consola"],
		"condicion": condicion,
		"es_especial": false
	}


func _esperar_escena(id_anterior: int = 0) -> Node:
	for intento in range(60):
		await process_frame
		if current_scene != null and current_scene.get_instance_id() != id_anterior:
			if current_scene.inicializada:
				current_scene.get_node("Player").set_physics_process(false)
				return current_scene
	_comprobar(false, "La escena termina de inicializarse tras la recarga")
	return null


func _ubicaciones(estado: Dictionary) -> Dictionary:
	var resultado: Dictionary = {}
	for copia in estado["inventario"]:
		_comprobar(not resultado.has(copia["id_copia"]), "ID único en inventario")
		resultado[copia["id_copia"]] = "inventario"
	for registro in estado["bodega"]:
		var id_copia: String = str(registro["datos"]["id_copia"])
		_comprobar(not resultado.has(id_copia), "ID único en bodega")
		resultado[id_copia] = "bodega"
	for nombre: String in estado["estanterias"]:
		for copia in estado["estanterias"][nombre]["copias"]:
			_comprobar(not resultado.has(copia["id_copia"]), "ID único en estantería")
			resultado[copia["id_copia"]] = "%s:%d" % [nombre, copia["posicion_estanteria"]]
	return resultado


func _comprobar_fixture(escena: Node, condicion_inventario: int, descripcion: String) -> void:
	var estado: Dictionary = save_manager._capturar_estado(escena)
	_comprobar(save_manager._validar_estado(estado, escena).is_empty(), descripcion + ": estado válido")
	_comprobar(_ubicaciones(estado) == {
		"inventario_1": "inventario",
		"bodega_1": "bodega",
		"estante_1": "EstanteriaPS1:0",
		"estante_2": "EstanteriaPS1:1"
	}, descripcion + ": IDs y posiciones preservados")
	_comprobar(estado["inventario"].size() == 1 and estado["inventario"][0]["condicion"] == condicion_inventario,
		descripcion + ": condición del inventario preservada")
	_comprobar(estado["bodega"].size() == 1 and estado["bodega"][0]["datos"]["condicion"] == 94
		and estado["bodega"][0]["datos"]["es_especial"], descripcion + ": atributos de bodega preservados")
	var estanteria: EstanteriaJuegos = escena.get_node("Estanterias/EstanteriaPS1")
	_comprobar(estanteria.exhibicion.get_child_count() == 2, descripcion + ": dos representaciones de estantería")
	_comprobar(estanteria.exhibicion.get_node("Posicion_00").get_meta("id_copia") == "estante_1"
		and estanteria.exhibicion.get_node("Posicion_01").get_meta("id_copia") == "estante_2",
		descripcion + ": representación y estado lógico coinciden")
	_comprobar(estado["tienda"]["xp"] == 2 and estado["tienda"]["clasificadas"].size() == 2,
		descripcion + ": dos copias exhibidas conservan exactamente 2 XP")


func _escribir(ruta: String, texto: String) -> void:
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	_comprobar(archivo != null, "Se puede escribir el fixture temporal")
	if archivo != null:
		archivo.store_string(texto)
		archivo.close()


func _ejecutar() -> void:
	save_manager = root.get_node("SaveManager")
	var lectura: bool = "--leer-reapertura" in OS.get_cmdline_user_args()
	var escritura: bool = "--escribir-reapertura" in OS.get_cmdline_user_args()
	if not _entorno_aislado(lectura):
		quit(2)
		return

	var escena: Node = load("res://node_3d.tscn").instantiate()
	escena.get_node("GeneradorJuegos").generar_al_iniciar = false
	root.add_child(escena)
	current_scene = escena
	escena = await _esperar_escena()
	if escena == null:
		quit(1)
		return
	if lectura:
		_comprobar_fixture(escena, 93, "Reapertura en otro proceso Godot")
		_comprobar(not save_manager.guardado_suspendido, "La reapertura deja el guardado habilitado")
		_comprobar(escena.tienda.datos["dinero"] == 321 and escena.tienda.datos["xp"] == 2,
			"Reabrir una Alpha 0.2 conserva dinero y corrige la XP a sus dos copias exhibidas")
		_comprobar(escena.get_node("Player").obtener_capacidad() == 7 and is_equal_approx(escena.tienda.alcance(), 3.5),
			"Las mejoras sobreviven a cerrar el proceso")
		_comprobar(escena.tienda.datos["estilos"]["arcade"] == 1,
			"El estilo se recupera en el proceso nuevo")
		_comprobar(escena.tienda.datos["fase"] == "DIA" and escena.tienda.datos["dia"] == 1
			and float(escena.tienda.datos["restante"]) > 173.0 and float(escena.tienda.datos["restante"]) <= 175.0,
			"El día comercial continúa desde el tiempo guardado")
		print("REAPERTURA LECTURA: %d pruebas, %d fallos" % [pruebas, fallos])
		quit(1 if fallos > 0 else 0)
		return

	var jugador: CharacterBody3D = escena.get_node("Player")
	jugador.inventario.append(_copia("mgs_ps1", "inventario_1"))
	var estanteria: EstanteriaJuegos = escena.get_node("Estanterias/EstanteriaPS1")
	_comprobar(estanteria.guardar_juego(_copia("ff7_ps1", "estante_1", 61)), "Primera copia colocada")
	_comprobar(estanteria.guardar_juego(_copia("ff7_ps1", "estante_2", 89)), "Segunda copia colocada")
	escena.registrar_clasificacion("estante_1")
	escena.registrar_clasificacion("estante_2")
	var caja: CajaJuego = load("res://caja_juego.tscn").instantiate()
	_comprobar(caja.configurar("gt4_ps2", 94, true, "bodega_1"), "Copia física configurada")
	caja.position = Vector3(1.0, 2.0, 3.0)
	caja.freeze = true
	escena.get_node("GeneradorJuegos").add_child(caja)
	jugador.global_position = Vector3(0.0, 1.0, 0.0)
	jugador.rotation.y = 0.25
	jugador.get_node("Head").rotation.x = -0.15

	_comprobar(save_manager.guardar_partida(escena), "Guardado real a disco")
	_comprobar(FileAccess.file_exists(save_manager.RUTA), "Existe archivo principal")
	jugador.inventario[0]["condicion"] = 93
	if escritura:
		# Fixture de la Alpha 0.2 anterior: compras y saldo ya existentes, con
		# la XP antigua inflada. El segundo proceso debe migrar sin premiar.
		escena.tienda.datos["dinero"] = 321
		escena.tienda.datos["xp"] = 120
		escena.tienda.datos["mejoras"] = {"inventario": 1, "alcance": 1}
		escena.tienda.datos["estilos"]["arcade"] = 1
		escena.tienda.abrir_dia()
		escena.tienda.avanzar(5.0, 0, 0.0)
	_comprobar(save_manager.guardar_partida(escena), "Segundo guardado genera respaldo")
	var respaldo: Dictionary = save_manager._leer_estado(save_manager.RUTA_RESPALDO)
	_comprobar(respaldo["inventario"][0]["condicion"] == 72, "Respaldo conserva el estado anterior")
	if escritura:
		var anterior: Dictionary = save_manager._leer_estado(save_manager.RUTA)
		anterior["version"] = 2
		_escribir(save_manager.RUTA, JSON.stringify(anterior))
		print("REAPERTURA ESCRITURA: %d pruebas, %d fallos" % [pruebas, fallos])
		quit(1 if fallos > 0 else 0)
		return

	# La API directa restaura sobre objetos existentes; no prueba la ruta de F9.
	jugador.inventario.clear()
	jugador.global_position = Vector3(8.0, 3.0, 8.0)
	var filas: Array = estanteria.ids_asignados_por_fila.duplicate()
	estanteria.restaurar_estado([], filas)
	caja.free()
	_comprobar(save_manager.cargar_partida(escena), "Carga directa reconstruye el mundo alterado")
	_comprobar_fixture(escena, 93, "Carga directa")
	_comprobar(jugador.global_position.is_equal_approx(Vector3(0.0, 1.0, 0.0))
		and is_equal_approx(jugador.rotation.y, 0.25)
		and is_equal_approx(jugador.get_node("Head").rotation.x, -0.15), "Transformación del jugador restaurada")

	# Ruta real del menú/F9: validación, suspensión, recarga y carga al iniciar.
	var id_anterior: int = escena.get_instance_id()
	jugador.inventario.clear()
	escena._cargar_desde_menu()
	_comprobar(save_manager.guardado_suspendido, "La recarga suspende guardados diferidos")
	escena = await _esperar_escena(id_anterior)
	if escena == null:
		quit(1)
		return
	_comprobar_fixture(escena, 93, "Recarga desde menú")
	_comprobar(not save_manager.guardado_suspendido, "La escena nueva reactiva guardado")

	# La recuperación debe usar el respaldo y reparar el principal.
	_escribir(save_manager.RUTA, "{ guardado dañado")
	id_anterior = escena.get_instance_id()
	escena._cargar_desde_menu()
	escena = await _esperar_escena(id_anterior)
	if escena == null:
		quit(1)
		return
	_comprobar_fixture(escena, 72, "Recuperación de respaldo")
	var reparado: Dictionary = save_manager._leer_estado(save_manager.RUTA)
	_comprobar(reparado["inventario"][0]["condicion"] == 72, "Principal reparado desde respaldo")

	# Una solicitud anterior al reinicio no debe resucitar ninguno de los tres archivos.
	_escribir(save_manager.RUTA_TEMPORAL, "temporal pendiente")
	save_manager.solicitar_guardado()
	_comprobar(save_manager.guardado_pendiente, "Hay guardado diferido antes del reinicio")
	id_anterior = escena.get_instance_id()
	escena._confirmar_reinicio()
	escena = await _esperar_escena(id_anterior)
	if escena == null:
		quit(1)
		return
	await process_frame
	for ruta: String in [save_manager.RUTA, save_manager.RUTA_RESPALDO, save_manager.RUTA_TEMPORAL]:
		_comprobar(not FileAccess.file_exists(ruta), "Reinicio elimina y no regenera " + ruta)
	var nuevo_estado: Dictionary = save_manager._capturar_estado(escena)
	var nuevas_ubicaciones: Dictionary = _ubicaciones(nuevo_estado)
	_comprobar(nuevo_estado["inventario"].is_empty(), "Reinicio vacía inventario")
	_comprobar(nuevo_estado["bodega"].size() == escena.get_node("GeneradorJuegos").cantidad_inicial,
		"Reinicio genera el lote inicial una sola vez")
	for id_copia: String in ["inventario_1", "bodega_1", "estante_1", "estante_2"]:
		_comprobar(not nuevas_ubicaciones.has(id_copia), "Reinicio descarta la antigua copia " + id_copia)
	for info: Dictionary in nuevo_estado["estanterias"].values():
		_comprobar(info["copias"].is_empty(), "Reinicio vacía estantería")
	_comprobar(save_manager.guardar_partida(escena), "La partida nueva se puede guardar")
	_comprobar(FileAccess.file_exists(save_manager.RUTA), "Se persiste la partida nueva")

	print("PERSISTENCIA: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
