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
	for grupo in range(titulos.size()):
		var mesa: Array = reglas["mesas_bodega"][grupo]
		for indice in range(copias_por_titulo):
			var caja: CajaJuego = escena_caja.instantiate() as CajaJuego
			var id_copia: String = "camp_%d_%s_%02d" % [estado.datos["semilla"], titulos[grupo], indice]
			if not caja.configurar(str(titulos[grupo]), rng.randi_range(35, 99), false, id_copia):
				caja.free()
				continue
			# Dos filas separadas sobre cada mesa. No apilar cuerpos físicos.
			caja.position = Vector3(float(mesa[0]) + (indice % 5 - 2) * 0.66,
				1.12, float(mesa[1]) + (-0.4 if indice < 5 else 0.4))
			caja.rotation.y = PI
			add_child(caja)


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
