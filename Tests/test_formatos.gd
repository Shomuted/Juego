extends SceneTree

var pruebas: int = 0
var fallos: int = 0


func _initialize() -> void:
	call_deferred("_ejecutar")


func _comprobar(ok: bool, nombre: String) -> void:
	pruebas += 1
	if ok:
		print("OK: " + nombre)
	else:
		fallos += 1
		push_error("FALLO: " + nombre)


func _ejecutar() -> void:
	var tam_ps1: Vector3 = CajaJuego.tamano_para_consola("PS1")
	var tam_ps2: Vector3 = CajaJuego.tamano_para_consola("PS2")
	var tam_n64: Vector3 = CajaJuego.tamano_para_consola("N64")
	var tam_ps3: Vector3 = CajaJuego.tamano_para_consola("PS3")

	_comprobar(tam_ps1 != tam_ps2, "PS1 y PS2 usan formatos distintos")
	_comprobar(tam_n64.y > tam_ps1.y, "N64 de cartón más alta que jewel case PS1")
	_comprobar(tam_n64.z > tam_ps2.z, "N64 de cartón más gruesa que caja DVD PS2")
	_comprobar(tam_ps3 != tam_ps2, "Formato PS3 preparado para uso posterior")
	_comprobar(CajaJuego.color_para_consola("PS1") != CajaJuego.color_para_consola("PS2"), "Colores de consola diferentes")
	_comprobar(CajaJuego.color_portada_para_juego("ff7_ps1") == CajaJuego.color_portada_para_juego("ff7_ps1"), "Portada provisional estable para el mismo título")

	var caja: CajaJuego = load("res://caja_juego.tscn").instantiate() as CajaJuego
	_comprobar(caja.configurar("ff7_ps1", 68, false, "test_s04_01"), "Configuración de copia")
	root.add_child(caja)
	var colision: CollisionShape3D = caja.get_node("CollisionShape3D") as CollisionShape3D
	_comprobar(colision.shape is BoxShape3D, "Colisión rectangular")
	_comprobar((colision.shape as BoxShape3D).size == tam_ps1, "Colisión y tamaño físico coinciden")
	var visual: Node3D = caja.get_node_or_null("VisualCaja") as Node3D
	_comprobar(visual != null, "Visual de caja creado")
	if visual != null:
		_comprobar(visual.get_node_or_null("PortadaProvisional") != null, "Portada provisional visible")
		var titulo: Label3D = visual.get_node_or_null("NombreJuego") as Label3D
		_comprobar(titulo != null and titulo.text.length() > 0, "Etiqueta del título presente")
		_comprobar(visual.get_node_or_null("NombreConsola") != null, "Franja identificadora de consola presente")
	_comprobar(caja.obtener_datos()["id_copia"] == "test_s04_01", "Identidad de copia preservada")

	var estanteria: EstanteriaJuegos = EstanteriaJuegos.new()
	estanteria.consola = "PS1"
	estanteria.ids_por_fila = PackedStringArray(["ff7_ps1", "mgs_ps1"])
	root.add_child(estanteria)
	_comprobar(estanteria.guardar_juego(caja.obtener_datos()), "Se guarda en estantería")
	_comprobar(estanteria.obtener_copia_en_posicion(0, 0).get("id_copia", "") == "test_s04_01", "Posición 0,0 conservada")
	_comprobar(estanteria.exhibicion.get_child_count() == 1, "Una caja visual exhibida")
	_comprobar(estanteria.exhibicion.get_child(0).get_node_or_null("PortadaProvisional") != null, "Portada también existe en estantería")

	var copia_ps2: CajaJuego = load("res://caja_juego.tscn").instantiate() as CajaJuego
	_comprobar(copia_ps2.configurar("gt4_ps2", 50, false, "test_s04_02"), "Otra plataforma configurada")
	_comprobar(not estanteria.guardar_juego(copia_ps2.obtener_datos()), "No admite plataformas incorrectas")

	estanteria.queue_free()
	caja.queue_free()
	copia_ps2.free()

	print("SPRINT 04: %d comprobaciones, %d fallos." % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)
