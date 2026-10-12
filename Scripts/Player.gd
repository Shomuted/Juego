extends CharacterBody3D

const SPEED: float = 6.0
const JUMP_VELOCITY: float = 4.5
const MOUSE_SENSITIVITY: float = 0.002

const LIMITE_INVENTARIO: int = 5
const DISTANCIA_RECOGIDA: float = 3.0
const DISTANCIA_ESTANTERIA: float = 3.5

var gravity: float = ProjectSettings.get_setting(
	"physics/3d/default_gravity"
)

var inventario: Array[Dictionary] = []

@onready var cabeza: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var raycast: RayCast3D = $Head/Camera3D/RayCast3D
@onready var hud: HudTienda = $HUD


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.use_accumulated_input = true

	floor_snap_length = 0.3

	camera.current = true
	camera.fov = 75.0

	raycast.enabled = true
	raycast.target_position = Vector3(
		0.0,
		0.0,
		-DISTANCIA_RECOGIDA
	)
	raycast.add_exception(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_E:
			intentar_ordenar()
			get_viewport().set_input_as_handled()
			return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			intentar_recoger()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var movimiento: Vector2 = event.screen_relative
		rotate_y(-movimiento.x * MOUSE_SENSITIVITY)
		cabeza.rotation.x = clampf(
			cabeza.rotation.x - movimiento.y * MOUSE_SENSITIVITY,
			deg_to_rad(-85.0), deg_to_rad(85.0)
		)
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("Saltar") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var input_dir: Vector2 = Input.get_vector(
		"Mover_izquierda",
		"Mover_derecha",
		"Mover_adelante",
		"Mover_atras"
	)

	var direction: Vector3 = (
		transform.basis
		* Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	if direction.length_squared() > 0.0:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED * delta * 10.0
		)

		velocity.z = move_toward(
			velocity.z,
			0.0,
			SPEED * delta * 10.0
		)

	move_and_slide()


func intentar_recoger() -> void:
	raycast.target_position.z = -obtener_alcance()
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return

	var caja: CajaJuego = raycast.get_collider() as CajaJuego
	if caja == null:
		return

	if inventario.size() >= obtener_capacidad():
		mostrar_mensaje("Inventario lleno. No puedes cargar más juegos.")
		return

	var datos_juego: Dictionary = caja.obtener_datos().duplicate(true)
	if not caja.recoger():
		return

	inventario.append(datos_juego)
	SaveManager.solicitar_guardado()

	var etiqueta_especial: String = ""
	if bool(datos_juego.get("es_especial", false)):
		etiqueta_especial = " [EDICIÓN ESPECIAL]"

	print(
		"Recogiste: %s (%s) - Grado: %d/100%s"
		% [
			str(datos_juego.get("titulo", "Desconocido")),
			str(datos_juego.get("consola", "Desconocida")),
			int(datos_juego.get("condicion", 0)),
			etiqueta_especial
		]
	)

	mostrar_mensaje(
		"Recogiste: %s (%s)" % [
			str(datos_juego.get("titulo", "")),
			str(datos_juego.get("consola", ""))
		]
	)

func obtener_estanteria_objetivo() -> EstanteriaJuegos:
	raycast.target_position.z = -obtener_alcance()
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var impacto: Node = raycast.get_collider() as Node
		while impacto != null:
			if impacto is EstanteriaJuegos:
				return impacto as EstanteriaJuegos
			impacto = impacto.get_parent()

	var cercana: EstanteriaJuegos = null
	var distancia: float = maxf(DISTANCIA_ESTANTERIA, obtener_alcance())
	for nodo in get_tree().get_nodes_in_group("estanteria"):
		if nodo is EstanteriaJuegos:
			var candidata: EstanteriaJuegos = nodo as EstanteriaJuegos
			var d: float = global_position.distance_to(candidata.global_position)
			if d < distancia:
				distancia = d
				cercana = candidata
	return cercana


func intentar_ordenar() -> void:
	var estanteria: EstanteriaJuegos = obtener_estanteria_objetivo()
	if estanteria == null:
		mostrar_mensaje("Acércate a una estantería y pulsa E.")
		return

	var hay_copia_compatible: bool = false
	var primer_error: String = ""

	for i in range(inventario.size()):
		var datos: Dictionary = inventario[i]
		if str(datos.get("consola", "")) != estanteria.consola:
			continue

		hay_copia_compatible = true
		if estanteria.guardar_juego(datos):
			inventario.remove_at(i)
			if get_parent().has_method("registrar_clasificacion"):
				get_parent().registrar_clasificacion(str(datos.get("id_copia", "")))
			SaveManager.solicitar_guardado()

			var id_juego: String = str(datos.get("id_juego", ""))
			if estanteria.cantidad_de_copias(id_juego) == EstanteriaJuegos.COLUMNAS:
				mostrar_mensaje("¡Colección completa! %s (10/10)" % str(datos.get("titulo", "Juego")))
			else:
				mostrar_mensaje("Guardado: %s en %s" % [
					str(datos.get("titulo", "Juego")),
					estanteria.consola
				])
			return

		if primer_error.is_empty():
			primer_error = estanteria.ultimo_error

	if not hay_copia_compatible:
		mostrar_mensaje("No llevas juegos de %s." % estanteria.consola)
	elif not primer_error.is_empty():
		mostrar_mensaje(primer_error)
	else:
		mostrar_mensaje("No hay una posición disponible para estos juegos.")


func mostrar_mensaje(mensaje: String) -> void:
	print(mensaje)
	if hud != null:
		hud.mostrar_mensaje(mensaje)


func obtener_capacidad() -> int:
	var escena: Node = get_parent()
	if escena != null and escena.get("tienda") != null:
		return escena.tienda.capacidad_inventario()
	return LIMITE_INVENTARIO


func obtener_alcance() -> float:
	var escena: Node = get_parent()
	if escena != null and escena.get("tienda") != null:
		return escena.tienda.alcance()
	return DISTANCIA_RECOGIDA
