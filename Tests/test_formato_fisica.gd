extends SceneTree

var verificaciones: int = 0
var errores: int = 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _verificar(valor: bool, descripcion: String) -> void:
	verificaciones += 1
	if valor:
		print("OK: " + descripcion)
	else:
		errores += 1
		push_error("FALLÓ: " + descripcion)


func _crear_caja(id_juego: String, id_copia: String) -> CajaJuego:
	var escena: PackedScene = load("res://caja_juego.tscn") as PackedScene
	var copia: CajaJuego = escena.instantiate() as CajaJuego
	if not copia.configurar(id_juego, 84, false, id_copia):
		copia.free()
		return null
	root.add_child(copia)
	return copia


func _verificar_plataforma(
	copia: CajaJuego,
	nombre_consola: String,
	detalle_esperado: String
) -> void:
	_verificar(copia != null, "Caja creada para " + nombre_consola)
	if copia == null:
		return

	var tamano: Vector3 = CajaJuego.tamano_para_consola(nombre_consola)
	var colision: CollisionShape3D = copia.get_node("CollisionShape3D") as CollisionShape3D
	_verificar(colision.shape is BoxShape3D, "Colisión propia de " + nombre_consola)
	_verificar(
		(colision.shape as BoxShape3D).size.is_equal_approx(tamano),
		"Dimensiones físicas correctas para " + nombre_consola
	)
	_verificar(
		is_equal_approx(copia.mass, CajaJuego.masa_para_consola(nombre_consola)),
		"Masa física correcta para " + nombre_consola
	)
	_verificar(
		copia.physics_material_override != null,
		"Material físico asignado a " + nombre_consola
	)
	if copia.physics_material_override != null:
		_verificar(
			is_equal_approx(
				copia.physics_material_override.friction,
				CajaJuego.rozamiento_para_consola(nombre_consola)
			),
			"Rozamiento propio para " + nombre_consola
		)
		_verificar(
			is_equal_approx(
				copia.physics_material_override.bounce,
				CajaJuego.rebote_para_consola(nombre_consola)
			),
			"Rebote propio para " + nombre_consola
		)

	var visual: Node3D = copia.get_node_or_null("VisualCaja") as Node3D
	_verificar(visual != null, "Visual propio de " + nombre_consola)
	if visual != null:
		_verificar(
			visual.get_node_or_null(detalle_esperado) != null,
			"Detalle de silueta: " + detalle_esperado
		)
		_verificar(
			visual.get_node_or_null("PortadaProvisional") != null,
			"Frente identificable de " + nombre_consola
		)


func _ejecutar() -> void:
	_verificar(
		CajaJuego.tamano_para_consola("PS1").y < CajaJuego.tamano_para_consola("PS2").y,
		"PS1 es más cuadrado que la caja DVD de PS2"
	)
	_verificar(
		CajaJuego.tamano_para_consola("N64").z > CajaJuego.tamano_para_consola("PS2").z,
		"Cartón N64 más grueso"
	)
	_verificar(
		CajaJuego.masa_para_consola("N64") > CajaJuego.masa_para_consola("PS1"),
		"Caja N64 con cartucho pesa más que jewel case"
	)
	_verificar(
		CajaJuego.es_carton("N64") and not CajaJuego.es_carton("PS1"),
		"Materiales físicos cartón y plástico diferenciados"
	)

	var ps1: CajaJuego = _crear_caja("ff7_ps1", "test_fisica_ps1")
	var ps2: CajaJuego = _crear_caja("gt4_ps2", "test_fisica_ps2")
	var n64: CajaJuego = _crear_caja("mario64_n64", "test_fisica_n64")

	_verificar_plataforma(ps1, "PS1", "BisagraCD")
	_verificar_plataforma(ps2, "PS2", "LomoDVD")
	_verificar_plataforma(n64, "N64", "SolapaSuperior")

	# PS3 está preparada visualmente, aunque el catálogo inicial no tenga PS3.
	var portada_ps3: Node3D = CajaJuego.crear_visual_para_datos({
		"id_juego": "prueba_ps3",
		"titulo": "Aventura Futura III",
		"consola": "PS3",
		"es_especial": false
	})
	root.add_child(portada_ps3)
	_verificar(
		portada_ps3.get_node_or_null("CabeceraBluRay") != null,
		"Formato PS3 con cabecera oscura preparado"
	)

	if ps1 != null:
		ps1.queue_free()
	if ps2 != null:
		ps2.queue_free()
	if n64 != null:
		n64.queue_free()
	portada_ps3.queue_free()

	print("FORMATOS FÍSICOS: %d pruebas, %d errores" % [verificaciones, errores])
	quit(1 if errores > 0 else 0)
