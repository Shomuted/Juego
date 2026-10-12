extends Node3D
class_name TiendaVisual
## Escenografía procedural: no guarda progreso ni altera las copias del catálogo.

const CREMA := Color("e5dac2")
const TEAL := Color("285759")
const OSCURO := Color("163338")
const AMBAR := Color("edba70")
const MADERA := Color("996848")
const MENTA := Color("9fcbb1")

var punto_palanca: Vector3 = Vector3(7, 1.2, 0)
var _materiales: Dictionary = {}
var _luces: Array[OmniLight3D] = []
var _decoraciones: Dictionary = {}
var _visitantes: Array[Dictionary] = []
var _rotulo_abierto: Label3D
var _palanca: Node3D
var _palanca_tween: Tween
var _azar := RandomNumberGenerator.new()
var _abierta: bool = false


func _ready() -> void:
	name = "TiendaVisual"
	_azar.randomize()
	_construir_sala()
	_construir_iluminacion()
	_construir_mostrador()
	_construir_bodega()
	_construir_decoraciones()
	actualizar_ambiente(false, {})


func _material(color: Color, brillo: float = 0.0) -> StandardMaterial3D:
	var clave: String = color.to_html() + ":" + str(brillo)
	if _materiales.has(clave):
		return _materiales[clave] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	if brillo > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = brillo
	_materiales[clave] = material
	return material


func _caja(padre: Node3D, centro: Vector3, tamano: Vector3, color: Color,
		colision: bool = false, brillo: float = 0.0) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	var malla := BoxMesh.new()
	malla.size = tamano
	pieza.mesh = malla
	pieza.material_override = _material(color, brillo)
	pieza.position = centro
	padre.add_child(pieza)
	if colision:
		var cuerpo := StaticBody3D.new()
		cuerpo.collision_layer = 1
		cuerpo.collision_mask = 0
		pieza.add_child(cuerpo)
		var forma := CollisionShape3D.new()
		var caja := BoxShape3D.new()
		caja.size = tamano
		forma.shape = caja
		cuerpo.add_child(forma)
	return pieza


func _cilindro(padre: Node3D, centro: Vector3, radio: float, alto: float,
		color: Color, radio_superior: float = -1.0) -> MeshInstance3D:
	var pieza := MeshInstance3D.new()
	var malla := CylinderMesh.new()
	malla.top_radius = radio if radio_superior < 0.0 else radio_superior
	malla.bottom_radius = radio
	malla.height = alto
	malla.radial_segments = 10
	pieza.mesh = malla
	pieza.material_override = _material(color)
	pieza.position = centro
	padre.add_child(pieza)
	return pieza


func _texto(padre: Node3D, texto: String, centro: Vector3, tamano: int,
		color: Color = CREMA, giro: float = 0.0, pixel: float = 0.003) -> Label3D:
	var etiqueta := Label3D.new()
	etiqueta.text = texto
	etiqueta.position = centro
	etiqueta.rotation.y = giro
	etiqueta.font_size = tamano
	etiqueta.pixel_size = pixel
	etiqueta.modulate = color
	etiqueta.outline_size = 3
	etiqueta.outline_modulate = Color(0.035, 0.07, 0.075, 0.9)
	etiqueta.no_depth_test = false
	etiqueta.shaded = false
	etiqueta.double_sided = false
	padre.add_child(etiqueta)
	return etiqueta


func _construir_sala() -> void:
	var techo: MeshInstance3D = _caja(self, Vector3(0, 4.48, 0.75), Vector3(22, 0.12, 22.5), Color("dfd7c5"))
	techo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Revestimientos sin colisión: el suelo físico pertenece a la escena original.
	_caja(self, Vector3(0, 0.006, -3.25), Vector3(22, 0.012, 14.5), CREMA)
	_caja(self, Vector3(0, 0.007, 8), Vector3(22, 0.014, 8), Color("b3ac9b"))
	for x in range(-10, 11, 2):
		_caja(self, Vector3(x, 0.014, -3.25), Vector3(0.025, 0.006, 14.5), Color("b6af9e"))
	for z in range(-10, 5, 2):
		_caja(self, Vector3(0, 0.014, z), Vector3(22, 0.006, 0.025), Color("b6af9e"))
	# Alfombra de recorrido; el centro permanece libre de obstáculos.
	_caja(self, Vector3(0, 0.022, -3.1), Vector3(15.5, 0.015, 3.5), OSCURO)
	_caja(self, Vector3(0, 0.031, -3.1), Vector3(15.15, 0.01, 3.15), TEAL)
	for x in [-7.2, 7.2]:
		_caja(self, Vector3(x, 0.04, -3.1), Vector3(0.05, 0.01, 2.75), AMBAR)
	_caja(self, Vector3(0, 2.2, -10.5), Vector3(22.4, 4.4, 0.3), CREMA, true)
	_caja(self, Vector3(0, 2.2, 12), Vector3(22.4, 4.4, 0.3), CREMA, true)
	for x in [-11.0, 11.0]:
		_caja(self, Vector3(x, 2.2, 0.75), Vector3(0.3, 4.4, 22.5), CREMA, true)
		_caja(self, Vector3(x * 0.983, 0.62, 0.75), Vector3(0.05, 1.24, 22.2), TEAL)
		_caja(self, Vector3(x * 0.98, 1.26, 0.75), Vector3(0.07, 0.06, 22.2), AMBAR)
		_caja(self, Vector3(x * 0.982, 0.07, 0.75), Vector3(0.08, 0.14, 22.2), OSCURO)
	_caja(self, Vector3(0, 0.62, -10.3), Vector3(21.7, 1.24, 0.05), TEAL)
	_caja(self, Vector3(0, 3.7, -10.28), Vector3(21.7, 0.87, 0.06), OSCURO)
	_caja(self, Vector3(0, 3.24, -10.23), Vector3(21.7, 0.035, 0.04), AMBAR, false, 0.3)
	_texto(self, "THE LAST PHYSICAL STORE", Vector3(0, 3.76, -10.21), 136, CREMA)
	_texto(self, "UN REFUGIO PARA LOS JUEGOS QUE TODAVÍA PODEMOS TOCAR", Vector3(0, 3.38, -10.2), 39, AMBAR)
	# Frontales de colección por encima de las estanterías existentes.
	for indice in range(3):
		var x: float = [-5.0, 0.0, 5.0][indice]
		_caja(self, Vector3(x, 3.34, -8), Vector3(3.85, 0.26, 0.12), TEAL)
		_texto(self, ["01 / PRIMERA PLAYSTATION", "02 / GENERACIÓN PLAYSTATION 2", "03 / MUNDO NINTENDO 64"][indice],
			Vector3(x, 3.34, -7.92), 43, AMBAR, 0, 0.0024)
	# Vigas y listones abiertos dejan entrar la iluminación general.
	for z in [-9.0, -3.0, 3.8, 11.0]:
		_caja(self, Vector3(0, 4.32, z), Vector3(22, 0.2, 0.18), MADERA)
	for x in [-8.0, 8.0]:
		_caja(self, Vector3(x, 4.4, 0.5), Vector3(0.15, 0.14, 22), MADERA)
	_construir_ventana(Vector3(-10.78, 2.35, -6.4), PI / 2.0)
	_construir_ventana(Vector3(10.78, 2.35, -5.6), -PI / 2.0)
	# La entrada es escenográfica; la pared limita el espacio jugable.
	var puerta := Node3D.new()
	puerta.position = Vector3(-10.79, 0, 0)
	puerta.rotation.y = PI / 2.0
	add_child(puerta)
	_caja(puerta, Vector3(0, 1.5, 0), Vector3(2.2, 3, 0.09), OSCURO)
	_caja(puerta, Vector3(0, 1.7, 0.06), Vector3(1.88, 2.28, 0.035), Color("78a8ae"), false, 0.2)
	for x in [-0.94, 0.94]:
		_caja(puerta, Vector3(x, 1.5, 0.1), Vector3(0.08, 3, 0.09), MADERA)
	_caja(puerta, Vector3(0, 1.16, 0.1), Vector3(1.9, 0.08, 0.08), MADERA)
	_caja(puerta, Vector3(0.7, 1.18, 0.17), Vector3(0.045, 0.34, 0.08), AMBAR)
	_texto(puerta, "BIENVENIDOS", Vector3(0, 3.25, 0.1), 61, OSCURO)
	_caja(puerta, Vector3(0, 2.05, 0.15), Vector3(1.5, 0.4, 0.06), OSCURO)
	_rotulo_abierto = _texto(puerta, "CERRADO", Vector3(0, 2.05, 0.19), 74, AMBAR)
	_caja(self, Vector3(-9.5, 0.025, 0), Vector3(2.35, 0.02, 2.4), OSCURO)
	_planta(self, Vector3(-9.55, 0, -9), 1.0)
	_planta(self, Vector3(9.5, 0, -9), 1.15)
	_poster(self, Vector3(10.76, 2.35, -1.1), -PI / 2.0, "CONSERVAR\nES RECORDAR", AMBAR, 0)
	_poster(self, Vector3(-10.76, 2.3, 2.8), PI / 2.0, "INSERTA\nRECUERDOS", MENTA, 1)


func _construir_ventana(pos: Vector3, giro: float) -> void:
	var ventana := Node3D.new()
	ventana.position = pos
	ventana.rotation.y = giro
	add_child(ventana)
	_caja(ventana, Vector3.ZERO, Vector3(5, 2, 0.1), OSCURO)
	_caja(ventana, Vector3(0, 0, 0.065), Vector3(4.75, 1.78, 0.06), Color("97b9be"), false, 0.3)
	# Silueta urbana abstracta original, sin texturas ni marcas externas.
	for indice in range(8):
		var altura: float = 0.35 + float((indice * 7) % 5) * 0.15
		_caja(ventana, Vector3(-2.05 + indice * 0.58, -0.84 + altura / 2.0, 0.104),
			Vector3(0.46, altura, 0.018), Color("6d949c"))
	for x in [-2.43, 0.0, 2.43]:
		_caja(ventana, Vector3(x, 0, 0.14), Vector3(0.09, 2, 0.08), MADERA)
	_caja(ventana, Vector3(0, -1.03, 0.16), Vector3(5.2, 0.12, 0.42), MADERA)
	_caja(ventana, Vector3(0, 0, 0.14), Vector3(5, 0.07, 0.08), MADERA)


func _construir_iluminacion() -> void:
	for pos in [Vector3(-5.5, 3.9, -5), Vector3(5.5, 3.9, -5), Vector3(0, 3.9, 1), Vector3(0, 3.9, 8.6)]:
		var luz := OmniLight3D.new()
		luz.position = pos
		luz.light_color = Color("ffe4b5")
		luz.light_energy = 1.0
		luz.omni_range = 11.0
		luz.omni_attenuation = 1.4
		luz.shadow_enabled = false
		add_child(luz)
		_luces.append(luz)
		_caja(self, pos + Vector3(0, 0.06, 0), Vector3(2.2, 0.12, 0.52), OSCURO)
		_caja(self, pos + Vector3(0, -0.015, 0), Vector3(2, 0.025, 0.38), Color("ffe5b6"), false, 1.6)
		for x in [-0.85, 0.85]:
			_caja(self, pos + Vector3(x, 0.22, 0), Vector3(0.025, 0.34, 0.025), OSCURO)


func _construir_mostrador() -> void:
	_caja(self, Vector3(7, 0.5, 1.5), Vector3(4, 1, 1.4), TEAL, true)
	_caja(self, Vector3(7, 1.03, 1.5), Vector3(4.18, 0.12, 1.6), MADERA, true)
	_caja(self, Vector3(7, 0.55, 0.782), Vector3(3.65, 0.62, 0.025), OSCURO)
	_texto(self, "ARCHIVO / RECEPCIÓN", Vector3(7, 0.6, 0.755), 75, AMBAR, PI)
	_texto(self, "EL VALOR ESTÁ EN CONSERVAR", Vector3(7, 0.34, 0.752), 34, CREMA, PI)
	for x in range(6, 9):
		_caja(self, Vector3(x, 0.075, 0.77), Vector3(0.035, 0.14, 0.025), AMBAR)
	# Terminal CRT y teclado, orientados hacia el pasillo.
	_caja(self, Vector3(8, 1.17, 1.45), Vector3(0.55, 0.17, 0.38), OSCURO)
	_caja(self, Vector3(8, 1.49, 1.48), Vector3(0.83, 0.6, 0.61), Color("c5bfab"))
	_caja(self, Vector3(8, 1.51, 1.163), Vector3(0.66, 0.43, 0.025), OSCURO)
	_texto(self, "ARCHIVO\nONLINE", Vector3(8, 1.51, 1.142), 30, MENTA, PI, 0.0028)
	_caja(self, Vector3(8, 1.1, 0.99), Vector3(0.64, 0.035, 0.22), Color("c5bfab"))
	for fila in range(3):
		for tecla in range(9):
			_caja(self, Vector3(7.76 + tecla * 0.06, 1.121, 0.92 + fila * 0.05), Vector3(0.043, 0.01, 0.033), OSCURO)
	# Pequeño atril de apertura separado del mostrador: R es la acción real.
	_caja(self, Vector3(7, 0.49, 0.1), Vector3(0.34, 0.98, 0.34), OSCURO, true)
	_caja(self, Vector3(7, 1.025, 0.05), Vector3(0.62, 0.11, 0.5), AMBAR)
	_palanca = Node3D.new()
	_palanca.position = Vector3(7, 1.09, 0)
	add_child(_palanca)
	_cilindro(_palanca, Vector3(0, 0.11, 0), 0.025, 0.22, OSCURO)
	_caja(_palanca, Vector3(0, 0.23, 0), Vector3(0.23, 0.085, 0.09), Color("b35943"))
	_texto(self, "R / ABRIR JORNADA", Vector3(7, 1.7, -0.03), 51, AMBAR, PI)
	_texto(self, "TAB / GESTIONAR ARCHIVO", Vector3(7, 1.49, -0.03), 34, CREMA, PI)
	# Cuadernos de donaciones junto a la terminal.
	for indice in range(3):
		_caja(self, Vector3(5.7, 1.12 + indice * 0.075, 1.5), Vector3(0.45, 0.07, 0.58), [MENTA, AMBAR, CREMA][indice])
	_planta(self, Vector3(10.1, 0, 2.7), 0.8)


func _construir_bodega() -> void:
	# Puerta central de 3.6 metros; se preserva el tránsito entre ambas salas.
	for x in [-6.4, 6.4]:
		_caja(self, Vector3(x, 1.85, 4), Vector3(9.2, 3.7, 0.2), TEAL, true)
		_caja(self, Vector3(x, 0.1, 3.88), Vector3(9.2, 0.2, 0.05), OSCURO)
	_caja(self, Vector3(0, 3.85, 4), Vector3(22, 0.5, 0.2), TEAL, true)
	for x in [-1.85, 1.85]:
		_caja(self, Vector3(x, 1.8, 4), Vector3(0.1, 3.6, 0.28), MADERA)
	_texto(self, "BODEGA / CLASIFICACIÓN", Vector3(0, 3.3, 3.86), 61, AMBAR, PI)
	_texto(self, "SALA DE COLECCIONES", Vector3(0, 3.3, 4.14), 61, AMBAR)
	_texto(self, "TODO COMIENZA\nCON UNA COPIA", Vector3(-6, 2.1, 3.87), 95, CREMA, PI)
	_texto(self, "RECUPERAR  /  CLASIFICAR  /  CONSERVAR", Vector3(0, 3.45, 11.78), 96, OSCURO, PI)
	_texto(self, "MESA DE TRABAJO · LOS NUEVOS LOTES LLEGAN AQUÍ", Vector3(0, 2.98, 11.77), 44, TEAL, PI)
	for fila in range(2):
		for columna in range(3):
			var x: float = [-6.0, 0.0, 6.0][columna]
			var z: float = [6.5, 9.5][fila]
			var mesa := Node3D.new()
			mesa.name = "MesaLotes%d" % (fila * 3 + columna + 1)
			mesa.position = Vector3(x, 0, z)
			add_child(mesa)
			# Superficie exacta y=0.75, igual que la configuración de entregas.
			_caja(mesa, Vector3(0, 0.69, 0), Vector3(4, 0.12, 1.6), MADERA, true)
			for dx in [-1.8, 1.8]:
				for dz in [-0.6, 0.6]:
					_caja(mesa, Vector3(dx, 0.315, dz), Vector3(0.09, 0.63, 0.09), OSCURO, true)
			_caja(mesa, Vector3(0, 0.14, 0), Vector3(3.8, 0.08, 1.2), OSCURO)
			_caja(mesa, Vector3(0, 0.535, -0.812), Vector3(0.75, 0.19, 0.024), CREMA)
			_texto(mesa, "LOTE %02d" % (fila * 3 + columna + 1), Vector3(0, 0.535, -0.831), 39, OSCURO, PI, 0.002)
			_caja(mesa, Vector3(-1.2, 0.31, 0.12), Vector3(0.85, 0.25, 0.7), Color("ba9871"))
			_caja(mesa, Vector3(-1.2, 0.44, 0.12), Vector3(0.14, 0.015, 0.72), CREMA)
	# Franjas en el umbral indican la zona de recepción sin bloquear el paso.
	for x in range(-3, 4):
		_caja(self, Vector3(x * 0.43, 0.025, 4.18), Vector3(0.22, 0.02, 0.45), AMBAR)


func _poster(padre: Node3D, centro: Vector3, giro: float, titulo: String,
		color: Color, variante: int) -> Node3D:
	var poster := Node3D.new()
	poster.position = centro
	poster.rotation.y = giro
	padre.add_child(poster)
	_caja(poster, Vector3.ZERO, Vector3(1.65, 2.03, 0.07), MADERA)
	_caja(poster, Vector3(0, 0, 0.05), Vector3(1.51, 1.89, 0.02), OSCURO)
	var figura: MeshInstance3D = _caja(poster, Vector3(0, 0.35, 0.071), Vector3(0.62, 0.62, 0.02), color)
	figura.rotation.z = PI / 4.0 if variante == 0 else 0.0
	_caja(poster, Vector3(0.12, 0.45, 0.09), Vector3(0.22, 0.22, 0.015), OSCURO)
	for indice in range(3):
		_caja(poster, Vector3(-0.42 + indice * 0.42, -0.12, 0.075), Vector3(0.24, 0.035, 0.015), color)
	_texto(poster, titulo, Vector3(0, -0.55, 0.084), 56, CREMA, 0, 0.0022)
	return poster


func _planta(padre: Node3D, pos: Vector3, escala: float) -> void:
	var planta := Node3D.new()
	planta.position = pos
	planta.scale = Vector3.ONE * escala
	padre.add_child(planta)
	_cilindro(planta, Vector3(0, 0.24, 0), 0.25, 0.48, MADERA, 0.32)
	_cilindro(planta, Vector3(0, 0.48, 0), 0.3, 0.04, OSCURO)
	_cilindro(planta, Vector3(0, 0.91, 0), 0.035, 0.9, Color("547658"))
	for indice in range(7):
		var angulo: float = float(indice) * 2.4
		var hoja: MeshInstance3D = _caja(planta,
			Vector3(sin(angulo) * 0.2, 0.79 + indice * 0.08, cos(angulo) * 0.2),
			Vector3(0.22, 0.065, 0.55), MENTA if indice % 2 == 0 else Color("4e876e"))
		hoja.rotation = Vector3(0.35, angulo, 0.15)


func _construir_decoraciones() -> void:
	for estilo in ["arcade", "museo", "cyber"]:
		var niveles: Array[Node3D] = []
		for nivel in range(3):
			var nodo := Node3D.new()
			nodo.name = "%s_Nivel%d" % [estilo, nivel + 1]
			add_child(nodo)
			niveles.append(nodo)
		_decoraciones[estilo] = niveles
	for nivel in range(3):
		var arcade: Node3D = _decoraciones["arcade"][nivel]
		var maquina := Node3D.new()
		maquina.position = Vector3(-9.6, 0, -3.1 - nivel * 1.65)
		maquina.rotation.y = PI / 2.0
		arcade.add_child(maquina)
		_caja(maquina, Vector3(0, 0.56, 0), Vector3(0.88, 1.12, 0.8), OSCURO)
		_caja(maquina, Vector3(0, 1.35, -0.18), Vector3(0.92, 0.98, 0.45), [AMBAR, MENTA, Color("bf9cc9")][nivel])
		_caja(maquina, Vector3(0, 1.43, 0.052), Vector3(0.73, 0.53, 0.04), OSCURO)
		_texto(maquina, ["PIXEL\nORBIT", "COSMIC\nGARDEN", "BYTE\nRUNNER"][nivel], Vector3(0, 1.44, 0.08), 41, MENTA, 0, 0.002)
		_caja(maquina, Vector3(0, 1.03, 0.3), Vector3(0.95, 0.12, 0.5), MADERA)
		_cilindro(maquina, Vector3(-0.22, 1.17, 0.33), 0.035, 0.19, AMBAR)
		for x in [0.12, 0.29]:
			_cilindro(maquina, Vector3(x, 1.105, 0.35), 0.055, 0.03, Color("b85e54"))
		var museo: Node3D = _decoraciones["museo"][nivel]
		_poster(museo, Vector3(-7.6 + nivel * 7.6, 2.15, 11.77), PI,
			["MEMORIA\nCOMPARTIDA", "LAS HISTORIAS\nPERMANECEN", "EL FUTURO\nTIENE PASADO"][nivel], AMBAR, nivel % 2)
		_planta(museo, Vector3(10.0, 0, 5.5 + nivel * 2.6), 0.8 + nivel * 0.1)
		var cyber: Node3D = _decoraciones["cyber"][nivel]
		var color_neon: Color = [Color("79d0ce"), Color("ba99d8"), AMBAR][nivel]
		for x in [-10.74, 10.74]:
			_caja(cyber, Vector3(x, 3.6 + nivel * 0.1, -3.2), Vector3(0.025, 0.035, 13.5), color_neon, false, 1.2)
		_caja(cyber, Vector3(0, 3.7 + nivel * 0.1, 3.84), Vector3(21.5, 0.035, 0.025), color_neon, false, 1.2)


func actualizar_ambiente(es_dia: bool, estilos: Dictionary) -> void:
	_abierta = es_dia
	if is_instance_valid(_rotulo_abierto):
		_rotulo_abierto.text = "ABIERTO" if es_dia else "CERRADO"
		_rotulo_abierto.modulate = MENTA if es_dia else AMBAR
	for luz in _luces:
		luz.light_energy = 1.25 if es_dia else 0.9
		luz.light_color = Color("fff0d3") if es_dia else Color("ffe2af")
	for estilo: String in _decoraciones:
		var nivel: int = clampi(int(estilos.get(estilo, 0)), 0, 3)
		var nodos: Array = _decoraciones[estilo]
		for indice in range(nodos.size()):
			(nodos[indice] as Node3D).visible = indice < nivel


func activar_palanca() -> void:
	if not is_instance_valid(_palanca):
		return
	if _palanca_tween != null and _palanca_tween.is_valid():
		_palanca_tween.kill()
	_palanca_tween = create_tween()
	_palanca_tween.tween_property(_palanca, "rotation:x", -0.7, 0.14).set_trans(Tween.TRANS_SINE)
	_palanca_tween.tween_property(_palanca, "rotation:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func mostrar_visitante() -> void:
	if _visitantes.size() >= 4:
		return
	var visitante := Node3D.new()
	visitante.name = "Visitante"
	visitante.position = Vector3(-10, 0, 0)
	add_child(visitante)
	var cuerpo := Node3D.new()
	visitante.add_child(cuerpo)
	var color_ropa: Color = [Color("ca795b"), Color("5b929b"), Color("9e86a6"), Color("91a26e")][_azar.randi_range(0, 3)]
	var piel: Color = [Color("dda77e"), Color("a57559"), Color("edc6a1")][_azar.randi_range(0, 2)]
	_caja(cuerpo, Vector3(0, 0.94, 0), Vector3(0.47, 0.65, 0.27), color_ropa)
	_cilindro(cuerpo, Vector3(0, 1.43, 0), 0.18, 0.35, piel)
	_caja(cuerpo, Vector3(0, 1.61, 0.015), Vector3(0.36, 0.14, 0.32), OSCURO)
	for x in [-0.065, 0.065]:
		_caja(cuerpo, Vector3(x, 1.46, -0.171), Vector3(0.024, 0.025, 0.018), OSCURO)
	var extremidades: Array[Node3D] = []
	for lado in [-1.0, 1.0]:
		var pierna := Node3D.new()
		pierna.position = Vector3(lado * 0.12, 0.61, 0)
		cuerpo.add_child(pierna)
		_caja(pierna, Vector3(0, -0.26, 0), Vector3(0.17, 0.52, 0.2), Color("44545c"))
		_caja(pierna, Vector3(0, -0.54, -0.035), Vector3(0.19, 0.09, 0.28), OSCURO)
		extremidades.append(pierna)
		var brazo := Node3D.new()
		brazo.position = Vector3(lado * 0.31, 1.2, 0)
		cuerpo.add_child(brazo)
		_caja(brazo, Vector3(0, -0.19, 0), Vector3(0.14, 0.4, 0.18), color_ropa)
		_caja(brazo, Vector3(0, -0.42, 0), Vector3(0.12, 0.13, 0.14), piel)
		extremidades.append(brazo)
	var comentario: Label3D = _texto(visitante, "", Vector3(0, 1.95, 0), 32, CREMA, 0, 0.0027)
	comentario.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	comentario.visible = false
	var recorrido: Array[Vector3] = [Vector3(-5, 0, -5.4), Vector3(0, 0, -5.4), Vector3(5, 0, -5.4), Vector3(7, 0, -1.1), Vector3(-9.7, 0, -0.3), Vector3(-10.5, 0, 0)]
	_visitantes.append({"nodo": visitante, "cuerpo": cuerpo, "extremidades": extremidades,
		"recorrido": recorrido, "paso": 0, "espera": 0.0, "tiempo": 0.0,
		"velocidad": _azar.randf_range(1.6, 2.1), "comentario": comentario})


func _process(delta: float) -> void:
	for indice in range(_visitantes.size() - 1, -1, -1):
		var datos: Dictionary = _visitantes[indice]
		var visitante: Node3D = datos["nodo"]
		if not is_instance_valid(visitante):
			_visitantes.remove_at(indice)
			continue
		var espera: float = float(datos["espera"])
		var partes: Array = datos["extremidades"]
		var comentario: Label3D = datos["comentario"]
		if espera > 0.0:
			datos["espera"] = maxf(espera - delta, 0.0)
			for parte: Node3D in partes:
				parte.rotation.x = lerpf(parte.rotation.x, 0.0, minf(delta * 9, 1))
			continue
		comentario.visible = false
		var paso: int = int(datos["paso"])
		var recorrido: Array[Vector3] = datos["recorrido"]
		if paso >= recorrido.size():
			visitante.queue_free()
			_visitantes.remove_at(indice)
			continue
		var destino: Vector3 = recorrido[paso]
		var direccion: Vector3 = destino - visitante.position
		visitante.position = visitante.position.move_toward(destino, delta * float(datos["velocidad"]))
		var cuerpo: Node3D = datos["cuerpo"]
		if direccion.length_squared() > 0.01:
			cuerpo.rotation.y = lerp_angle(cuerpo.rotation.y, atan2(-direccion.x, -direccion.z), minf(delta * 7.0, 1.0))
		datos["tiempo"] = float(datos["tiempo"]) + delta
		var oscilacion: float = sin(float(datos["tiempo"]) * 9.0) * 0.28
		for extremidad in range(partes.size()):
			(partes[extremidad] as Node3D).rotation.x = oscilacion * (1.0 if extremidad == 0 or extremidad == 3 else -1.0)
		if visitante.position.distance_to(destino) < 0.05:
			datos["paso"] = paso + 1
			if paso < 3:
				datos["espera"] = 2.5 + _azar.randf() * 1.5
				cuerpo.rotation.y = 0.0
				comentario.text = ["Cuántos recuerdos…", "Todavía existe en físico.", "Un lugar para volver."][paso]
				comentario.visible = true
