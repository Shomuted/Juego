extends SceneTree

var fallos: int = 0
var pruebas: int = 0


func _comprobar(condicion: bool, descripcion: String) -> void:
	pruebas += 1
	if condicion:
		print("OK: ", descripcion)
	else:
		fallos += 1
		push_error("FALLO: " + descripcion)


func _copia(id_juego: String, id_copia: String) -> Dictionary:
	var definicion: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
	return {
		"id_juego": id_juego,
		"id_copia": id_copia,
		"titulo": definicion["titulo"],
		"consola": definicion["consola"],
		"condicion": 72,
		"es_especial": false
	}


func _initialize() -> void:
	call_deferred("_ejecutar")


func _ejecutar() -> void:
	# Los autoloads se crean después de compilar el script --script.
	var save_manager: Node = root.get_node("SaveManager")
	var escena: Node = load("res://node_3d.tscn").instantiate()
	escena.get_node("GeneradorJuegos").generar_al_iniciar = false
	root.add_child(escena)

	var jugador: CharacterBody3D = escena.get_node("Player") as CharacterBody3D
	var estanteria: EstanteriaJuegos = escena.get_node("Estanterias/EstanteriaPS1") as EstanteriaJuegos
	var generador: Node3D = escena.get_node("GeneradorJuegos") as Node3D

	jugador.inventario.append(_copia("mgs_ps1", "inventario_1"))
	_comprobar(estanteria.guardar_juego(_copia("ff7_ps1", "estante_1")), "Copia colocada en estantería")
	var caja: CajaJuego = load("res://caja_juego.tscn").instantiate() as CajaJuego
	_comprobar(caja.configurar("gt4_ps2", 94, true, "bodega_1"), "Copia física configurada")
	generador.add_child(caja)
	caja.position = Vector3(1.0, 2.0, 3.0)

	var estado: Dictionary = save_manager._capturar_estado(escena)
	_comprobar(save_manager._validar_estado(estado, escena).is_empty(), "Estado completo es válido")
	_comprobar(estado["bodega"].size() == 1, "Una copia en bodega")
	_comprobar(estado["inventario"].size() == 1, "Una copia en inventario")
	_comprobar(estado["estanterias"]["EstanteriaPS1"]["copias"].size() == 1, "Una copia en estantería")

	var restaurado: Variant = JSON.parse_string(JSON.stringify(estado))
	_comprobar(typeof(restaurado) == TYPE_DICTIONARY, "Serialización JSON completa")
	_comprobar(save_manager._validar_estado(restaurado, escena).is_empty(), "Estado JSON recuperado es válido")

	var duplicado: Dictionary = restaurado.duplicate(true)
	duplicado["inventario"][0]["id_copia"] = "bodega_1"
	_comprobar(not save_manager._validar_estado(duplicado, escena).is_empty(), "Rechaza ID duplicado entre ubicaciones")

	var posicion_ilegal: Dictionary = restaurado.duplicate(true)
	posicion_ilegal["estanterias"]["EstanteriaPS1"]["copias"][0]["posicion_estanteria"] = 100
	_comprobar(not save_manager._validar_estado(posicion_ilegal, escena).is_empty(), "Rechaza posición fuera de estantería")

	var consola_incorrecta: Dictionary = restaurado.duplicate(true)
	consola_incorrecta["inventario"][0]["consola"] = "N64"
	_comprobar(not save_manager._validar_estado(consola_incorrecta, escena).is_empty(), "Rechaza plataforma alterada")

	var version_invalida: Dictionary = restaurado.duplicate(true)
	version_invalida["version"] = 999
	_comprobar(not save_manager._validar_estado(version_invalida, escena).is_empty(), "Rechaza versión no compatible")

	var fila_incorrecta: Dictionary = restaurado.duplicate(true)
	fila_incorrecta["estanterias"]["EstanteriaPS1"]["filas"][0] = "mgs_ps1"
	_comprobar(not save_manager._validar_estado(fila_incorrecta, escena).is_empty(), "Rechaza alteración de filas reservadas")
	for campo in ["version", "posicion", "condicion", "id_copia"]:
		var corrupto: Dictionary = restaurado.duplicate(true)
		if campo == "version":
			corrupto["version"] = 1.5
		elif campo == "posicion":
			corrupto["estanterias"]["EstanteriaPS1"]["copias"][0]["posicion_estanteria"] = 0.5
		elif campo == "condicion":
			corrupto["inventario"][0]["condicion"] = 100.5
		else:
			corrupto["inventario"][0]["id_copia"] = 123
		_comprobar(not save_manager._validar_estado(corrupto, escena).is_empty(), "Rechaza corrupción de tipo o rango: " + campo)

	print("PRUEBAS: %d, FALLOS: %d" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
