
extends RigidBody3D
class_name CajaJuego

signal recolectada(datos: Dictionary)

@export_group("Interacción")
@export var se_puede_recoger: bool = true

var id_juego: String = ""
var id_copia: String = ""
var titulo: String = ""
var consola: String = ""
var condicion: int = 0
var es_especial: bool = false

var configurada: bool = false
var fue_recolectada: bool = false


func _ready() -> void:
	add_to_group("juego")

	contact_monitor = true
	max_contacts_reported = 4

	if not configurada:
		push_warning(
			"Caja sin configurar: " + str(get_path())
		)


func configurar(
	nuevo_id_juego: String,
	nueva_condicion: int,
	nueva_especial: bool,
	nuevo_id_copia: String
) -> bool:
	if configurada:
		push_warning("Esta caja ya fue configurada.")
		return false

	if not CatalogoJuegos.existe(nuevo_id_juego):
		push_error("Juego desconocido: " + nuevo_id_juego)
		return false

	if nuevo_id_copia.is_empty():
		push_error("La copia necesita un identificador.")
		return false

	var datos_titulo: Dictionary = (
		CatalogoJuegos.obtener_juego(nuevo_id_juego)
	)

	id_juego = nuevo_id_juego
	id_copia = nuevo_id_copia

	titulo = str(datos_titulo["titulo"])
	consola = str(datos_titulo["consola"])

	condicion = clampi(nueva_condicion, 0, 100)
	es_especial = nueva_especial

	configurada = true
	_actualizar_apariencia()
	return true


func obtener_datos() -> Dictionary:
	return {
		"id_juego": id_juego,
		"id_copia": id_copia,
		"titulo": titulo,
		"consola": consola,
		"condicion": condicion,
		"es_especial": es_especial
	}


func recoger() -> bool:
	if not se_puede_recoger:
		return false

	if not configurada or fue_recolectada:
		return false

	fue_recolectada = true
	se_puede_recoger = false

	recolectada.emit(obtener_datos())

	queue_free()
	return true


static func tamano_para_consola(nombre_consola: String) -> Vector3:
	# Medidas aproximadas con una escala visual uniforme para el prototipo.
	# X: ancho, Y: alto, Z: grosor. Todas caben en los slots existentes.
	match nombre_consola:
		"PS1":
			return Vector3(0.34, 0.34, 0.035)
		"PS2":
			return Vector3(0.30, 0.46, 0.040)
		"N64":
			return Vector3(0.35, 0.42, 0.080)
		"PS3":
			return Vector3(0.30, 0.41, 0.035)
		"SNES":
			return Vector3(0.35, 0.43, 0.075)
		"GameCube":
			return Vector3(0.30, 0.43, 0.040)
		"Xbox":
			return Vector3(0.30, 0.46, 0.045)
		_:
			return Vector3(0.30, 0.43, 0.045)


static func masa_para_consola(nombre_consola: String) -> float:
	# Kilogramos aproximados para cajas con disco/cartucho y manual.
	match nombre_consola:
		"PS1":
			return 0.115
		"PS2":
			return 0.135
		"N64":
			return 0.185
		"PS3":
			return 0.125
		"SNES":
			return 0.180
		"GameCube":
			return 0.125
		"Xbox":
			return 0.145
		_:
			return 0.130


static func es_carton(nombre_consola: String) -> bool:
	return nombre_consola == "N64" or nombre_consola == "SNES"


static func rozamiento_para_consola(nombre_consola: String) -> float:
	return 0.78 if es_carton(nombre_consola) else 0.42


static func rebote_para_consola(nombre_consola: String) -> float:
	return 0.025 if es_carton(nombre_consola) else 0.065


static func color_para_consola(nombre_consola: String) -> Color:
	match nombre_consola:
		"PS1":
			return Color(0.70, 0.72, 0.76)
		"PS2":
			return Color(0.09, 0.24, 0.65)
		"N64":
			return Color(0.60, 0.45, 0.28)
		"PS3":
			return Color(0.12, 0.12, 0.14)
		"SNES":
			return Color(0.63, 0.63, 0.70)
		"GameCube":
			return Color(0.39, 0.26, 0.68)
		"Xbox":
			return Color(0.18, 0.53, 0.20)
		_:
			return Color(0.60, 0.60, 0.60)


static func color_franja_para_consola(nombre_consola: String) -> Color:
	match nombre_consola:
		"PS1":
			return Color(0.32, 0.33, 0.39)
		"PS2":
			return Color(0.07, 0.11, 0.26)
		"N64":
			return Color(0.24, 0.36, 0.17)
		"PS3":
			return Color(0.03, 0.03, 0.045)
		_:
			return Color(0.19, 0.19, 0.23)


static func color_portada_para_juego(id_titulo: String) -> Color:
	# Un color estable por título, sin modificar ni guardar nuevos datos.
	var paleta: Array[Color] = [
		Color(0.84, 0.40, 0.32),
		Color(0.30, 0.57, 0.79),
		Color(0.39, 0.64, 0.50),
		Color(0.74, 0.58, 0.34),
		Color(0.55, 0.46, 0.75),
		Color(0.71, 0.42, 0.58)
	]
	var indice: int = posmod(id_titulo.hash(), paleta.size())
	return paleta[indice]


static func _crear_material(color: Color, rugosidad: float, metalico: float = 0.0) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rugosidad
	material.metallic = metalico
	return material


static func _agregar_bloque(
	padre: Node3D,
	nombre: String,
	dimensiones: Vector3,
	centro: Vector3,
	material: StandardMaterial3D
) -> MeshInstance3D:
	var nodo: MeshInstance3D = MeshInstance3D.new()
	nodo.name = nombre
	var malla: BoxMesh = BoxMesh.new()
	malla.size = dimensiones
	nodo.mesh = malla
	nodo.material_override = material
	nodo.position = centro
	padre.add_child(nodo)
	return nodo


static func _titulo_en_dos_lineas(titulo_completo: String) -> String:
	var palabras: PackedStringArray = titulo_completo.split(" ", false)
	var lineas: Array[String] = []
	var linea: String = ""
	for palabra in palabras:
		if linea.is_empty():
			linea = palabra
		elif linea.length() + palabra.length() + 1 <= 13:
			linea += " " + palabra
		else:
			lineas.append(linea)
			linea = palabra
			if lineas.size() == 2:
				break
	if lineas.size() < 2 and not linea.is_empty():
		lineas.append(linea)
	if lineas.size() > 2:
		lineas.resize(2)
	var resultado: String = ""
	for i in range(lineas.size()):
		if i > 0:
			resultado += "\n"
		resultado += lineas[i].substr(0, 13)
	return resultado


static func _agregar_detalles_de_formato(
	visual: Node3D,
	nombre_consola: String,
	tamano: Vector3
) -> void:
	var claro: StandardMaterial3D = _crear_material(Color(0.86, 0.88, 0.92), 0.23)
	var bisagra: StandardMaterial3D = _crear_material(Color(0.38, 0.42, 0.48), 0.44)
	var oscuro: StandardMaterial3D = _crear_material(Color(0.055, 0.06, 0.085), 0.32)
	var carton: StandardMaterial3D = _crear_material(Color(0.73, 0.59, 0.36), 0.92)
	var azul: StandardMaterial3D = _crear_material(Color(0.07, 0.18, 0.56), 0.36)

	match nombre_consola:
		"PS1":
			# Jewel case: cuadrado delgado, bisagra y bordes plásticos claros.
			_agregar_bloque(
				visual, "BisagraCD",
				Vector3(0.018, tamano.y * 0.96, tamano.z * 0.96),
				Vector3(-tamano.x * 0.46, 0.0, 0.0), bisagra
			)
			for sentido in [-1.0, 1.0]:
				_agregar_bloque(
					visual, "MarcoJewel",
					Vector3(tamano.x * 0.94, 0.009, tamano.z * 0.90),
					Vector3(0.0, sentido * tamano.y * 0.47, 0.0), claro
				)
		"PS2", "GameCube", "Xbox":
			# Caja DVD: lomo grueso y pequeña unión de tapa en el borde.
			_agregar_bloque(
				visual, "LomoDVD",
				Vector3(0.022, tamano.y * 0.97, tamano.z * 0.96),
				Vector3(-tamano.x * 0.465, 0.0, 0.0), azul
			)
			_agregar_bloque(
				visual, "CierreDVD",
				Vector3(0.007, tamano.y * 0.30, 0.009),
				Vector3(tamano.x * 0.485, 0.0, tamano.z * 0.06), claro
			)
		"PS3":
			# Blu-ray: carcasa negra, lomo fino y cabecera diferenciada.
			_agregar_bloque(
				visual, "LomoBluRay",
				Vector3(0.016, tamano.y * 0.97, tamano.z * 0.96),
				Vector3(-tamano.x * 0.47, 0.0, 0.0), oscuro
			)
			_agregar_bloque(
				visual, "CabeceraBluRay",
				Vector3(tamano.x * 0.98, 0.038, tamano.z * 1.01),
				Vector3(0.0, tamano.y * 0.46, 0.0), oscuro
			)
			_agregar_bloque(
				visual, "LineaBluRay",
				Vector3(tamano.x * 0.94, 0.007, tamano.z * 0.96),
				Vector3(0.0, tamano.y * 0.405, 0.0), claro
			)
		"N64", "SNES":
			# Cartón: cuerpo más profundo, solapa superior y dobleces.
			_agregar_bloque(
				visual, "SolapaSuperior",
				Vector3(tamano.x * 0.92, 0.014, tamano.z * 0.92),
				Vector3(0.0, tamano.y * 0.48, 0.0), carton
			)
			_agregar_bloque(
				visual, "DoblezLateral",
				Vector3(0.012, tamano.y * 0.94, tamano.z * 0.90),
				Vector3(tamano.x * 0.47, 0.0, 0.0), carton
			)


static func crear_visual_para_datos(datos: Dictionary) -> Node3D:
	var visual: Node3D = Node3D.new()
	visual.name = "VisualCaja"

	var nombre_consola: String = str(datos.get("consola", ""))
	var id_titulo: String = str(datos.get("id_juego", ""))
	var titulo_copia: String = str(datos.get("titulo", "Juego"))
	var especial: bool = bool(datos.get("es_especial", false))
	var tamano: Vector3 = tamano_para_consola(nombre_consola)
	var formato_carton: bool = es_carton(nombre_consola)
	var rugosidad: float = 0.87 if formato_carton else 0.37
	var brillo_metal: float = 0.0 if formato_carton else (0.18 if especial else 0.02)

	_agregar_bloque(
		visual,
		"Cuerpo",
		tamano,
		Vector3.ZERO,
		_crear_material(color_para_consola(nombre_consola), rugosidad, brillo_metal)
	)

	_agregar_detalles_de_formato(visual, nombre_consola, tamano)

	# Cara frontal hacia +Z; las estanterías se miran desde el interior de la tienda.
	var ancho_frente: float = tamano.x * 0.91
	var alto_frente: float = tamano.y * 0.90
	var plano_z: float = tamano.z * 0.5 + 0.003
	var profundidad_cubierta: float = 0.006
	_agregar_bloque(
		visual,
		"PortadaProvisional",
		Vector3(ancho_frente, alto_frente, profundidad_cubierta),
		Vector3(0.0, 0.0, plano_z),
		_crear_material(color_portada_para_juego(id_titulo), 0.72 if formato_carton else 0.55)
	)

	var cabecera_y: float = tamano.y * 0.37
	_agregar_bloque(
		visual,
		"FranjaConsola",
		Vector3(ancho_frente, tamano.y * 0.16, profundidad_cubierta),
		Vector3(0.0, cabecera_y, plano_z + 0.004),
		_crear_material(color_franja_para_consola(nombre_consola), 0.47)
	)

	var rotulo_consola: Label3D = Label3D.new()
	rotulo_consola.name = "NombreConsola"
	rotulo_consola.text = nombre_consola
	rotulo_consola.font_size = 38
	rotulo_consola.pixel_size = 0.0019
	rotulo_consola.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_consola.modulate = Color.WHITE
	rotulo_consola.position = Vector3(0.0, cabecera_y, plano_z + 0.009)
	visual.add_child(rotulo_consola)

	var rotulo_titulo: Label3D = Label3D.new()
	rotulo_titulo.name = "NombreJuego"
	rotulo_titulo.text = _titulo_en_dos_lineas(titulo_copia)
	rotulo_titulo.font_size = 30
	rotulo_titulo.pixel_size = 0.0015
	rotulo_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotulo_titulo.modulate = Color(0.08, 0.08, 0.12)
	rotulo_titulo.position = Vector3(0.0, -tamano.y * 0.03, plano_z + 0.009)
	visual.add_child(rotulo_titulo)

	if especial:
		_agregar_bloque(
			visual,
			"DetalleEspecial",
			Vector3(ancho_frente * 0.55, tamano.y * 0.055, profundidad_cubierta),
			Vector3(0.0, -tamano.y * 0.36, plano_z + 0.004),
			_crear_material(Color(0.93, 0.77, 0.28), 0.3, 0.25)
		)

	return visual


func _actualizar_apariencia() -> void:
	var malla: MeshInstance3D = get_node_or_null("MeshInstance3D") as MeshInstance3D
	var colision: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	var tamano: Vector3 = tamano_para_consola(consola)

	if malla != null:
		# Material y malla exclusivos por instancia, para no alterar otras copias.
		var forma_visual: BoxMesh = BoxMesh.new()
		forma_visual.size = tamano
		malla.mesh = forma_visual
		malla.material_override = _crear_material(
			color_para_consola(consola),
			0.87 if consola == "N64" else 0.4,
			0.16 if es_especial else 0.0
		)
		malla.visible = false

	if colision != null:
		var forma_colision: BoxShape3D = BoxShape3D.new()
		forma_colision.size = tamano
		colision.shape = forma_colision

	var anterior: Node3D = get_node_or_null("VisualCaja") as Node3D
	if anterior != null:
		remove_child(anterior)
		anterior.queue_free()

	var visual: Node3D = crear_visual_para_datos(obtener_datos())
	add_child(visual)

	# La física utiliza el contorno exterior; los detalles de la caja son visuales.
	mass = masa_para_consola(consola)
	var fisica: PhysicsMaterial = PhysicsMaterial.new()
	fisica.friction = rozamiento_para_consola(consola)
	fisica.bounce = rebote_para_consola(consola)
	physics_material_override = fisica
