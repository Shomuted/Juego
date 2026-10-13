extends Node

const VERSION: int = 3
const RUTA: String = "user://partida_01.json"
const RUTA_TEMPORAL: String = "user://partida_01.tmp"
const RUTA_RESPALDO: String = "user://partida_01.bak"
const RUTA_LEGACY: String = "user://partida_01_sprint07_original.json"
const RUTA_ALPHA02: String = "user://partida_01_alpha02_original.json"
const ESTADO_TIENDA = preload("res://Scripts/EstadoTienda.gd")
const ESCENA_CAJA: PackedScene = preload("res://caja_juego.tscn")

var guardado_pendiente: bool = false
var guardado_suspendido: bool = false
var restaurando: bool = false
var ultimo_error: String = ""


func hay_partida() -> bool:
	return FileAccess.file_exists(RUTA) or FileAccess.file_exists(RUTA_RESPALDO)


func borrar_partida_para_pruebas() -> bool:
	# Impide que una escritura diferida reconstruya la partida borrada.
	ultimo_error = ""
	if restaurando:
		return _error("No puedes reiniciar mientras se carga una partida.")

	guardado_suspendido = true
	guardado_pendiente = false

	for ruta: String in [RUTA, RUTA_TEMPORAL, RUTA_RESPALDO]:
		if not FileAccess.file_exists(ruta):
			continue

		var resultado: Error = DirAccess.remove_absolute(
			ProjectSettings.globalize_path(ruta)
		)
		if resultado != OK:
			return _error(
				"No se pudo eliminar %s (código %d)." % [ruta, resultado]
			)

	return true


func reanudar_guardado() -> void:
	guardado_pendiente = false
	guardado_suspendido = false


func preparar_carga_por_recarga(escena: Node) -> bool:
	# F9 y el menú nunca reconstruyen cuerpos físicos en la escena activa.
	# Se valida la partida aquí; la restauración se hará al iniciar una escena nueva.
	ultimo_error = ""
	if restaurando:
		return _error("Ya se está restaurando una partida.")
	if guardado_suspendido:
		return _error("Hay una operación de partida en curso.")

	var estado: Dictionary = _leer_estado(RUTA)
	var valido: bool = not estado.is_empty() and _validar_estado(estado, escena).is_empty()
	if not valido:
		var respaldo: Dictionary = _leer_estado(RUTA_RESPALDO)
		if respaldo.is_empty():
			return _error("No hay una partida válida para cargar.")
		var error_respaldo: String = _validar_estado(respaldo, escena)
		if not error_respaldo.is_empty():
			return _error("El guardado y el respaldo están dañados: " + error_respaldo)

	guardado_suspendido = true
	guardado_pendiente = false
	return true


func recargar_escena_para_pruebas() -> void:
	var resultado: Error = get_tree().reload_current_scene()
	if resultado != OK:
		ultimo_error = "No se pudo recargar la escena (código %d)." % resultado
		push_error(ultimo_error)
		var escena: Node = get_tree().current_scene
		if escena != null and escena.has_method("informar_fallo_reinicio"):
			escena.call("informar_fallo_reinicio", ultimo_error)
		else:
			reanudar_guardado()


func solicitar_guardado() -> void:
	if guardado_pendiente or restaurando or guardado_suspendido:
		return
	guardado_pendiente = true
	call_deferred("_procesar_guardado_pendiente")


func _procesar_guardado_pendiente() -> void:
	if not guardado_pendiente or guardado_suspendido:
		return
	guardado_pendiente = false
	if restaurando:
		return
	var escena: Node = get_tree().current_scene
	if escena != null:
		guardar_partida(escena)


func guardar_partida(escena: Node) -> bool:
	ultimo_error = ""
	if guardado_suspendido:
		return false
	if restaurando:
		return _error("No es posible guardar mientras se restaura una partida.")

	var estado: Dictionary = _capturar_estado(escena)
	if estado.is_empty():
		return false

	var mensaje: String = _validar_estado(estado, escena)
	if not mensaje.is_empty():
		return _error("Guardado cancelado: " + mensaje)

	var salida: FileAccess = FileAccess.open(RUTA_TEMPORAL, FileAccess.WRITE)
	if salida == null:
		return _error("No se pudo crear el archivo temporal de guardado.")
	salida.store_string(JSON.stringify(estado, "\t"))
	salida.flush()
	salida.close()

	var temporal: String = ProjectSettings.globalize_path(RUTA_TEMPORAL)
	var principal: String = ProjectSettings.globalize_path(RUTA)
	var respaldo: String = ProjectSettings.globalize_path(RUTA_RESPALDO)

	if FileAccess.file_exists(RUTA):
		var anterior: Dictionary = _leer_estado(RUTA)
		if not anterior.is_empty() and _validar_estado(anterior, escena).is_empty():
			var resultado_copia: Error = DirAccess.copy_absolute(principal, respaldo)
			if resultado_copia != OK:
				DirAccess.remove_absolute(temporal)
				return _error("No fue posible crear el respaldo de la partida anterior.")

	var resultado: Error = DirAccess.rename_absolute(temporal, principal)
	if resultado != OK:
		DirAccess.remove_absolute(temporal)
		return _error("No se pudo finalizar el guardado. Código: %d" % resultado)

	print("Partida guardada: ", RUTA)
	return true


func cargar_partida(escena: Node) -> bool:
	ultimo_error = ""
	if restaurando:
		return _error("Ya se está restaurando una partida.")

	var estado: Dictionary = _leer_estado(RUTA)
	var cargado_desde_respaldo: bool = false
	var mensaje: String = _validar_estado(estado, escena) if not estado.is_empty() else "El archivo principal no se pudo leer."

	if not mensaje.is_empty():
		var estado_respaldo: Dictionary = _leer_estado(RUTA_RESPALDO)
		var mensaje_respaldo: String = _validar_estado(estado_respaldo, escena) if not estado_respaldo.is_empty() else "El respaldo no se pudo leer."
		if not mensaje_respaldo.is_empty():
			return _error("No hay una partida válida. Principal: %s Respaldo: %s" % [mensaje, mensaje_respaldo])
		estado = estado_respaldo
		cargado_desde_respaldo = true
		push_warning("Se recuperó la partida desde el respaldo.")

	var generador: Node3D = escena.get_node_or_null("GeneradorJuegos") as Node3D
	if generador == null:
		return _error("No se encontró GeneradorJuegos.")
	if int(estado["version"]) == 1 and not FileAccess.file_exists(RUTA_LEGACY):
		var original: String = RUTA_RESPALDO if cargado_desde_respaldo else RUTA
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(original), ProjectSettings.globalize_path(RUTA_LEGACY)) != OK:
			return _error("No se pudo conservar una copia del guardado antiguo.")
	if int(estado["version"]) == 2 and not FileAccess.file_exists(RUTA_ALPHA02):
		var original: String = RUTA_RESPALDO if cargado_desde_respaldo else RUTA
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(original), ProjectSettings.globalize_path(RUTA_ALPHA02)) != OK:
			return _error("No se pudo conservar la partida original de Alpha 0.2.")

	var nuevas_cajas: Array[CajaJuego] = []
	for registro in estado["bodega"]:
		var instancia: Node = ESCENA_CAJA.instantiate()
		if not instancia is CajaJuego:
			for preparada in nuevas_cajas:
				preparada.free()
			instancia.free()
			return _error("La escena de caja no contiene CajaJuego.")

		var caja: CajaJuego = instancia as CajaJuego
		var datos: Dictionary = registro["datos"]
		if not caja.configurar(
			str(datos["id_juego"]),
			int(datos["condicion"]),
			bool(datos["es_especial"]),
			str(datos["id_copia"])
		):
			caja.free()
			for preparada in nuevas_cajas:
				preparada.free()
			return _error("No se pudo reconstruir una copia.")
		nuevas_cajas.append(caja)
	# Alpha 0.2 entregaba cajas preordenadas en mesas. Se corrige solo el suelo:
	# inventario, slots, atributos e identidades se conservan. v1 ya tenía suelo.
	if int(estado["version"]) == 2:
		generador.distribuir_copias(nuevas_cajas, int(estado["tienda"]["semilla"]))

	restaurando = true
	guardado_pendiente = false
	for nodo in generador.get_children():
		if nodo is CajaJuego:
			generador.remove_child(nodo)
			nodo.free()

	var estanterias: Dictionary = _obtener_estanterias(escena)
	for nombre: String in estanterias.keys():
		var estanteria: EstanteriaJuegos = estanterias[nombre]
		var informacion: Dictionary = estado["estanterias"][nombre]
		estanteria.restaurar_estado(informacion["copias"], informacion["filas"])

	var jugador: CharacterBody3D = escena.get_node("Player") as CharacterBody3D
	jugador.inventario.clear()
	for registro in estado["inventario"]:
		jugador.inventario.append(_datos_canonicos(registro))
	jugador.global_position = _a_vector3(estado["jugador"]["posicion"])
	jugador.rotation.y = float(estado["jugador"]["rotacion_y"])
	jugador.get_node("Head").rotation.x = float(estado["jugador"]["cabeza_x"])
	jugador.velocity = Vector3.ZERO

	for i in range(nuevas_cajas.size()):
		var caja_nueva: CajaJuego = nuevas_cajas[i]
		var registro_caja: Dictionary = estado["bodega"][i]
		if int(estado["version"]) != 2:
			caja_nueva.position = _a_vector3(registro_caja["posicion"])
			caja_nueva.rotation = _a_vector3(registro_caja["rotacion"])
		generador.add_child(caja_nueva)
		if int(estado["version"]) != 2:
			caja_nueva.linear_velocity = _a_vector3(registro_caja["velocidad_lineal"])
			caja_nueva.angular_velocity = _a_vector3(registro_caja["velocidad_angular"])
		caja_nueva.continuous_cd = true
	escena.tienda.restaurar(_estado_tienda(estado))

	restaurando = false
	if cargado_desde_respaldo:
		var copia_respaldo: Error = DirAccess.copy_absolute(
			ProjectSettings.globalize_path(RUTA_RESPALDO),
			ProjectSettings.globalize_path(RUTA)
		)
		if copia_respaldo != OK:
			push_warning("No fue posible reparar el archivo principal desde el respaldo.")
	print("Partida restaurada: %d cajas en el suelo." % nuevas_cajas.size())
	return true


func _capturar_estado(escena: Node) -> Dictionary:
	var jugador: CharacterBody3D = escena.get_node_or_null("Player") as CharacterBody3D
	var generador: Node3D = escena.get_node_or_null("GeneradorJuegos") as Node3D
	if jugador == null or generador == null:
		_error("Faltan el jugador o el generador en la escena.")
		return {}

	var inventario_guardado: Array[Dictionary] = []
	for datos in jugador.inventario:
		inventario_guardado.append(_datos_canonicos(datos))

	var bodega: Array[Dictionary] = []
	for nodo in generador.get_children():
		if not nodo is CajaJuego or nodo.is_queued_for_deletion():
			continue
		var caja: CajaJuego = nodo as CajaJuego
		bodega.append({
			"datos": _datos_canonicos(caja.obtener_datos()),
			"posicion": _de_vector3(caja.position),
			"rotacion": _de_vector3(caja.rotation),
			"velocidad_lineal": _de_vector3(caja.linear_velocity),
			"velocidad_angular": _de_vector3(caja.angular_velocity)
		})

	var estanterias_guardadas: Dictionary = {}
	var estanterias: Dictionary = _obtener_estanterias(escena)
	for nombre: String in estanterias.keys():
		var estanteria: EstanteriaJuegos = estanterias[nombre]
		var copias: Array[Dictionary] = []
		for datos in estanteria.juegos_guardados:
			var copia: Dictionary = _datos_canonicos(datos)
			copia["posicion_estanteria"] = int(datos.get("posicion_estanteria", -1))
			copias.append(copia)
		estanterias_guardadas[nombre] = {
			"consola": estanteria.consola,
			"filas": Array(estanteria.ids_asignados_por_fila),
			"copias": copias
		}

	return {
		"version": VERSION,
		"guardado_en": Time.get_datetime_string_from_system(),
		"jugador": {
			"posicion": _de_vector3(jugador.global_position),
			"rotacion_y": jugador.rotation.y,
			"cabeza_x": jugador.get_node("Head").rotation.x
		},
		"inventario": inventario_guardado,
		"bodega": bodega,
		"estanterias": estanterias_guardadas,
		"tienda": escena.tienda.exportar()
	}


func _leer_estado(ruta: String) -> Dictionary:
	if not FileAccess.file_exists(ruta):
		return {}
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if archivo == null:
		return {}
	var contenido: String = archivo.get_as_text()
	archivo.close()
	var json: JSON = JSON.new()
	if json.parse(contenido) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


func _validar_estado(estado: Dictionary, escena: Node) -> String:
	var version: Variant = estado.get("version", -1)
	if not _numero_valido(version) or float(version) not in [1.0, 2.0, float(VERSION)]:
		return "Versión de guardado desconocida."
	var modelo = ESTADO_TIENDA.new()
	if int(estado["version"]) >= 2:
		var error_tienda: String = modelo.validar(estado.get("tienda"))
		if not error_tienda.is_empty():
			return error_tienda
		modelo.restaurar(estado["tienda"])
	if not estado.has("jugador") or typeof(estado["jugador"]) != TYPE_DICTIONARY:
		return "Datos del jugador inválidos."
	var jugador: Dictionary = estado["jugador"]
	if not _vector_valido(jugador.get("posicion")) or not _numero_valido(jugador.get("rotacion_y")) or not _numero_valido(jugador.get("cabeza_x")):
		return "Transformación del jugador inválida."
	if not estado.has("inventario") or typeof(estado["inventario"]) != TYPE_ARRAY:
		return "Inventario inválido."
	if estado["inventario"].size() > modelo.capacidad_inventario():
		return "El inventario excede su capacidad."
	if not estado.has("bodega") or typeof(estado["bodega"]) != TYPE_ARRAY:
		return "Lista de bodega inválida."
	if not estado.has("estanterias") or typeof(estado["estanterias"]) != TYPE_DICTIONARY:
		return "Estado de estanterías inválido."

	var identificadores: Dictionary = {}
	for copia in estado["inventario"]:
		var error_copia: String = _validar_copia(copia, identificadores)
		if not error_copia.is_empty():
			return "Inventario: " + error_copia

	for registro in estado["bodega"]:
		if typeof(registro) != TYPE_DICTIONARY:
			return "Registro de bodega inválido."
		if not registro.has("datos"):
			return "Faltan datos de una caja de bodega."
		for campo in ["posicion", "rotacion", "velocidad_lineal", "velocidad_angular"]:
			if not _vector_valido(registro.get(campo)):
				return "Vector de caja inválido: " + campo
		var error_copia: String = _validar_copia(registro["datos"], identificadores)
		if not error_copia.is_empty():
			return "Bodega: " + error_copia

	var estanterias: Dictionary = _obtener_estanterias(escena)
	if estado["estanterias"].size() != estanterias.size():
		return "La cantidad de estanterías no coincide."
	for nombre: String in estanterias.keys():
		if not estado["estanterias"].has(nombre):
			return "Falta la estantería " + nombre
		var estanteria: EstanteriaJuegos = estanterias[nombre]
		var info: Variant = estado["estanterias"][nombre]
		if typeof(info) != TYPE_DICTIONARY:
			return "Estantería con datos inválidos."
		if info.get("consola") != estanteria.consola:
			return "Consola diferente en estantería " + nombre
		if typeof(info.get("filas")) != TYPE_ARRAY or info["filas"].size() != EstanteriaJuegos.FILAS:
			return "Filas inválidas en estantería " + nombre
		if typeof(info.get("copias")) != TYPE_ARRAY or info["copias"].size() > estanteria.capacidad:
			return "Capacidad inválida en estantería " + nombre

		var filas_ocupadas: Dictionary = {}
		var ids_fila: Dictionary = {}
		for fila in range(EstanteriaJuegos.FILAS):
			var id_fila: Variant = info["filas"][fila]
			if typeof(id_fila) != TYPE_STRING:
				return "ID de fila inválido."
			if not str(id_fila).is_empty():
				if not CatalogoJuegos.existe(id_fila):
					return "Título de fila desconocido."
				if str(CatalogoJuegos.obtener_juego(id_fila).get("consola", "")) != estanteria.consola:
					return "Título de fila en consola incorrecta."
				if ids_fila.has(id_fila):
					return "Título asignado a dos filas."
				ids_fila[id_fila] = true
			if fila < estanteria.ids_por_fila.size() and not str(estanteria.ids_por_fila[fila]).is_empty() and str(estanteria.ids_por_fila[fila]) != str(id_fila):
				return "Cambió una fila reservada en la escena."

		for copia in info["copias"]:
			var error_copia: String = _validar_copia(copia, identificadores)
			if not error_copia.is_empty():
				return "Estantería: " + error_copia
			if str(copia["consola"]) != estanteria.consola:
				return "Copia guardada en otra consola."
			var posicion: int = int(copia.get("posicion_estanteria", -1))
			if not _numero_valido(copia.get("posicion_estanteria")) or float(copia["posicion_estanteria"]) != float(posicion):
				return "La posición de estantería debe ser un entero."
			if posicion < 0 or posicion >= estanteria.capacidad:
				return "Posición de estantería fuera de rango."
			if filas_ocupadas.has(posicion):
				return "Dos copias comparten una posición."
			filas_ocupadas[posicion] = true
			if str(info["filas"][int(posicion / EstanteriaJuegos.COLUMNAS)]) != str(copia["id_juego"]):
				return "La copia no coincide con el título de su fila."

	if int(estado["version"]) >= 2:
		for campo in ["manifiesto", "clasificadas"]:
			for id_copia in estado["tienda"][campo]:
				if not identificadores.has(id_copia):
					return "El progreso referencia una copia inexistente: " + str(id_copia)
		for id_juego in estado["tienda"]["completadas"]:
			if not CatalogoJuegos.existe(id_juego):
				return "El progreso referencia una colección desconocida."
	return ""


func _estado_tienda(estado: Dictionary) -> Dictionary:
	if int(estado["version"]) >= 2:
		return estado["tienda"].duplicate(true)
	# Migración aditiva del Sprint 07: no cambia identidades ni ediciones.
	# Cuenta un XP por cada copia exhibida, sin inventar premios monetarios pasados.
	var modelo = ESTADO_TIENDA.new()
	var ids: Array = []
	for copia in estado["inventario"]:
		ids.append(copia["id_copia"])
	for registro in estado["bodega"]:
		ids.append(registro["datos"]["id_copia"])
	for estanteria in estado["estanterias"].values():
		var cantidades: Dictionary = {}
		for copia in estanteria["copias"]:
			ids.append(copia["id_copia"])
			modelo.datos["clasificadas"].append(copia["id_copia"])
			var id_juego: String = str(copia["id_juego"])
			cantidades[id_juego] = int(cantidades.get(id_juego, 0)) + 1
		for id_juego in cantidades:
			if cantidades[id_juego] == EstanteriaJuegos.COLUMNAS:
				modelo.datos["completadas"].append(id_juego)
	modelo.registrar_manifiesto(ids)
	modelo.datos["xp"] = modelo.datos["clasificadas"].size()
	return modelo.exportar()


func _validar_copia(valor: Variant, ids: Dictionary) -> String:
	if typeof(valor) != TYPE_DICTIONARY:
		return "Los datos de una copia no son un diccionario."
	var datos: Dictionary = valor
	for campo in ["id_juego", "id_copia", "consola", "titulo", "condicion", "es_especial"]:
		if not datos.has(campo):
			return "Falta el campo " + campo
	var id_juego: String = str(datos["id_juego"])
	var id_copia: String = str(datos["id_copia"])
	if typeof(datos["id_juego"]) != TYPE_STRING or typeof(datos["id_copia"]) != TYPE_STRING:
		return "Los identificadores de copia y título deben ser texto."
	if id_copia.is_empty() or ids.has(id_copia):
		return "ID vacío o duplicado: " + id_copia
	if not CatalogoJuegos.existe(id_juego):
		return "Título desconocido: " + id_juego
	if str(CatalogoJuegos.obtener_juego(id_juego).get("consola", "")) != str(datos["consola"]):
		return "La plataforma de la copia no coincide con su título."
	if not _numero_valido(datos["condicion"]) or float(datos["condicion"]) < 0.0 or float(datos["condicion"]) > 100.0 or float(datos["condicion"]) != floor(float(datos["condicion"])):
		return "Condición fuera de rango."
	if typeof(datos["es_especial"]) != TYPE_BOOL:
		return "Tipo de edición inválido."
	ids[id_copia] = true
	return ""


func _obtener_estanterias(escena: Node) -> Dictionary:
	var resultado: Dictionary = {}
	var padre: Node = escena.get_node_or_null("Estanterias")
	if padre == null:
		return resultado
	for nodo in padre.get_children():
		if nodo is EstanteriaJuegos:
			resultado[nodo.name] = nodo
	return resultado


func _datos_canonicos(datos: Dictionary) -> Dictionary:
	var id_juego: String = str(datos.get("id_juego", ""))
	var info: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
	return {
		"id_juego": id_juego,
		"id_copia": str(datos.get("id_copia", "")),
		"titulo": str(info.get("titulo", datos.get("titulo", ""))),
		"consola": str(info.get("consola", datos.get("consola", ""))),
		"condicion": int(datos.get("condicion", 0)),
		"es_especial": bool(datos.get("es_especial", false))
	}


func _de_vector3(valor: Vector3) -> Array[float]:
	return [valor.x, valor.y, valor.z]


func _a_vector3(valor: Array) -> Vector3:
	return Vector3(float(valor[0]), float(valor[1]), float(valor[2]))


func _vector_valido(valor: Variant) -> bool:
	if typeof(valor) != TYPE_ARRAY or valor.size() != 3:
		return false
	for componente in valor:
		if not _numero_valido(componente):
			return false
	return true


func _numero_valido(valor: Variant) -> bool:
	if typeof(valor) != TYPE_INT and typeof(valor) != TYPE_FLOAT:
		return false
	return is_finite(float(valor))


func _error(mensaje: String) -> bool:
	ultimo_error = mensaje
	push_error(mensaje)
	return false
