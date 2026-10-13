extends Node3D

@export_group("Escena")
@export var escena_caja: PackedScene = preload(
    "res://caja_juego.tscn"
)

@export_group("Generación")
@export_range(0, 10000, 1)
var cantidad_inicial: int = 10

@export var generar_al_iniciar: bool = true
@export var campana_controlada: bool = true

@export var consolas_habilitadas: PackedStringArray = PackedStringArray(["PS1", "PS2", "N64"])

@export_group("Área de aparición")
@export_range(0.5, 100.0, 0.5)
var rango_x: float = 8.0

@export_range(0.5, 100.0, 0.5)
var rango_z: float = 8.0

@export_range(0.5, 30.0, 0.5)
var altura_caida: float = 4.0

@export_range(0.0, 5.0, 0.1)
var variacion_altura: float = 1.0

@export_range(0.0, 5.0, 0.1)
var separacion_minima: float = 0.8

@export_range(1, 100, 1)
var intentos_posicion: int = 30

@export_group("Atributos")
@export_range(0.0, 1.0, 0.01)
var probabilidad_especial: float = 0.05

@export_range(0, 100, 1)
var condicion_minima: int = 0

@export_range(0, 100, 1)
var condicion_maxima: int = 100

@export_group("Física")
@export_range(0.0, 5.0, 0.1)
var impulso_horizontal: float = 0.5

@export_range(0.0, 5.0, 0.1)
var impulso_vertical: float = 0.2

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var ids_disponibles: Array[String] = []
var posiciones_usadas: Array[Vector2] = []


func _ready() -> void:
	rng.randomize()
	ids_disponibles.clear()
	for id_juego in CatalogoJuegos.obtener_ids():
		var datos: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
		if str(datos.get("consola", "")) in consolas_habilitadas:
			ids_disponibles.append(id_juego)

	if generar_al_iniciar and not SaveManager.hay_partida():
		if campana_controlada:
			generar_campana()
		else:
			generar_lote(cantidad_inicial)


func generar_campana() -> void:
	# El stock original garantiza diez copias Standard de cada colección montada.
	# Atributos e IDs se guardan individualmente; cargar nunca vuelve a generarlos.
	var estado = get_parent().tienda
	var reglas: Dictionary = estado.reglas
	var titulos: Array = reglas["titulos"]
	var copias_por_titulo: int = int(reglas["copias_por_titulo"])
	cantidad_inicial = titulos.size() * copias_por_titulo
	estado.datos["semilla"] = rng.randi_range(1, 2147483647)
	rng.seed = int(estado.datos["semilla"])
	var copias: Array[CajaJuego] = []
	for grupo in range(titulos.size()):
		for indice in range(copias_por_titulo):
			var caja: CajaJuego = escena_caja.instantiate() as CajaJuego
			var id_copia: String = "camp_%d_%s_%02d" % [estado.datos["semilla"], titulos[grupo], indice]
			if not caja.configurar(str(titulos[grupo]), rng.randi_range(35, 99), false, id_copia):
				caja.free()
				continue
			copias.append(caja)
	distribuir_copias(copias, int(estado.datos["semilla"]))
	for caja in copias:
		add_child(caja)


func distribuir_copias(copias: Array[CajaJuego], semilla: int) -> void:
	# Mezclar identidades ANTES de repartirlas evita preclasificar por título/consola.
	# Solo cambia las transformaciones: también permite migrar las antiguas mesas.
	var azar := RandomNumberGenerator.new()
	azar.seed = semilla
	var mezcladas: Array[CajaJuego] = copias.duplicate()
	for i in range(mezcladas.size() - 1, 0, -1):
		var j: int = azar.randi_range(0, i)
		var intercambio: CajaJuego = mezcladas[i]
		mezcladas[i] = mezcladas[j]
		mezcladas[j] = intercambio
	var suelo: Dictionary = get_parent().tienda.reglas["suelo"]
	var centros: Array[Vector2] = []
	for centro in suelo["montones"]:
		centros.append(Vector2(float(centro[0]), float(centro[1])) + Vector2(
			azar.randf_range(-0.35, 0.35), azar.randf_range(-0.35, 0.35)))
	var por_monton: int = int(suelo["copias_por_monton"])
	var limites: Array = suelo["limites"]
	var sueltas: Array[Vector2] = []
	for i in range(mezcladas.size()):
		var caja: CajaJuego = mezcladas[i]
		var punto: Vector2
		var capa: int = 0
		if i < centros.size() * por_monton:
			# Bases desplazadas y giros distintos: montones irregulares, no torres.
			capa = i % por_monton
			punto = centros[int(i / por_monton)] + Vector2(
				azar.randf_range(-0.16, 0.16), azar.randf_range(-0.16, 0.16))
		else:
			var encontrada: bool = false
			for intento in range(256):
				punto = Vector2(azar.randf_range(limites[0], limites[1]),
					azar.randf_range(limites[2], limites[3]))
				# No introducir copias bajo el mostrador, dentro del jugador ni de un montón.
				if punto.length() < 1.25 or (punto.x > 4.4 and punto.y > -0.8 and punto.y < 2.9):
					continue
				var libre: bool = true
				for anterior in centros + sueltas:
					if punto.distance_to(anterior) < 0.75:
						libre = false
						break
				if libre:
					encontrada = true
					break
			if not encontrada:
				# Un stock mayor no puede bloquear la generación buscando huecos.
				punto = centros[i % centros.size()]
				capa = por_monton + int(i / centros.size())
			sueltas.append(punto)
		# Portadas mayormente hacia arriba, algunas invertidas, todas con giro libre.
		caja.rotation = Vector3(-PI / 2.0 + azar.randf_range(-0.16, 0.16),
			azar.randf_range(-PI, PI), azar.randf_range(-0.12, 0.12))
		if i % 7 == 0:
			caja.rotation.x += PI
		# Separación vertical inicial impide interpenetraciones; caen y se apoyan
		# unas en otras con la física de sus formatos. Ninguna queda congelada.
		caja.position = Vector3(punto.x, 0.16 + capa * 0.20, punto.y)
		caja.linear_velocity = Vector3.ZERO
		caja.angular_velocity = Vector3.ZERO
		caja.continuous_cd = true


func generar_lote(cantidad: int) -> void:
	if escena_caja == null:
		push_error("No se ha asignado una escena de caja.")
		return

	if ids_disponibles.is_empty():
		push_error("El catálogo está vacío.")
		return

	if cantidad <= 0:
		return

	posiciones_usadas.clear()

	for i in range(cantidad):
		generar_caja()


func generar_caja() -> CajaJuego:
	if escena_caja == null:
		push_error("No se ha asignado una escena de caja.")
		return null

	if ids_disponibles.is_empty():
		push_error("El catálogo está vacío.")
		return null

	var instancia: Node = escena_caja.instantiate()

	if not instancia is CajaJuego:
		push_error(
            "La escena debe tener CajaJuego como nodo raíz."
		)
		instancia.free()
		return null

	var caja: CajaJuego = instancia as CajaJuego

	var id_aleatorio: String = ids_disponibles[
		rng.randi_range(0, ids_disponibles.size() - 1)
	]

	var minimo: int = mini(
		condicion_minima,
		condicion_maxima
	)

	var maximo: int = maxi(
		condicion_minima,
		condicion_maxima
	)

	var nueva_condicion: int = rng.randi_range(
		minimo,
		maximo
	)

	var nueva_especial: bool = (
		rng.randf() < probabilidad_especial
	)

	var nuevo_id_copia: String = generar_id_copia()

	var configuracion_correcta: bool = caja.configurar(
		id_aleatorio,
		nueva_condicion,
		nueva_especial,
		nuevo_id_copia
	)

	if not configuracion_correcta:
		caja.free()
		return null

	var posicion_local: Vector3 = obtener_posicion()

	caja.position = posicion_local
	caja.rotation = Vector3(
		rng.randf_range(-0.25, 0.25),
		rng.randf_range(0.0, TAU),
		rng.randf_range(-0.25, 0.25)
	)

	add_child(caja)

	var impulso: Vector3 = Vector3(
		rng.randf_range(
			-impulso_horizontal,
			impulso_horizontal
		),
		rng.randf_range(
			0.0,
			impulso_vertical
		),
		rng.randf_range(
			-impulso_horizontal,
			impulso_horizontal
		)
	)

	caja.apply_central_impulse(impulso)

	return caja


func obtener_posicion() -> Vector3:
	var posicion_2d: Vector2 = Vector2.ZERO
	var encontrada: bool = false

	for intento in range(intentos_posicion):
		posicion_2d = Vector2(
			rng.randf_range(-rango_x, rango_x),
			rng.randf_range(-rango_z, rango_z)
		)

		var posicion_valida: bool = true

		for posicion_anterior in posiciones_usadas:
			if posicion_2d.distance_to(
				posicion_anterior
			) < separacion_minima:
				posicion_valida = false
				break

		if posicion_valida:
			encontrada = true
			break

	if not encontrada:
		push_warning(
            "No se pudo respetar la separación mínima."
		)

	posiciones_usadas.append(posicion_2d)

	return Vector3(
		posicion_2d.x,
		altura_caida + rng.randf_range(
			0.0,
			variacion_altura
		),
		posicion_2d.y
	)


func generar_id_copia() -> String:
	return (
		str(Time.get_ticks_usec())
		+ "_"
		+ str(rng.randi())
		+ "_"
		+ str(rng.randi())
	)
