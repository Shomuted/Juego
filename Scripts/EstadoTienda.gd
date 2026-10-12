extends RefCounted
class_name EstadoTienda

## Estado serializable de la campaña. No depende de escenas ni de autoloads.
## El dinero procede de visitas y ayudas por colecciones; las copias se conservan.
const RUTA_REGLAS: String = "res://Database/gameplay_config.json"
const MAX_CONTADOR: int = 1000000000
const MAX_IDS: int = 10000
const MAX_LONGITUD_ID: int = 128
const CAMPOS: Array[String] = [
	"version", "dia", "fase", "restante", "acumulador_visitas", "dinero", "xp",
	"ingresos_hoy", "visitantes_hoy", "visitantes_total", "mejoras", "estilos",
	"completadas", "clasificadas", "manifiesto", "semilla"
]

var datos: Dictionary = {}
var reglas: Dictionary = {}


func _init() -> void:
	_cargar_reglas()
	reiniciar()


func _cargar_reglas() -> void:
	var archivo: FileAccess = FileAccess.open(RUTA_REGLAS, FileAccess.READ)
	if archivo != null:
		var contenido: Variant = JSON.parse_string(archivo.get_as_text())
		if contenido is Dictionary:
			reglas = contenido
			return
	# Respaldo para poder informar de una instalación incompleta sin bloquear carga.
	push_warning("No se pudo leer gameplay_config.json; se usa el balance predeterminado.")
	reglas = {
		"duracion_dia": 180, "intervalo_visitas": 12, "experiencia_clasificar": 5,
		"ticket_base": 4, "recompensa_coleccion": {"dinero": 120, "xp": 50},
		"mejoras": {
			"inventario": {"base": 5, "paso": 2, "costos": [80, 160, 260], "xp": [25, 100, 200]},
			"alcance": {"base": 3.0, "paso": 0.5, "costos": [60, 120, 200], "xp": [25, 75, 150]}
		},
		"estilos": {
			"arcade": {"costos": [60, 120, 180]},
			"museo": {"costos": [60, 120, 180]},
			"cyber": {"costos": [60, 120, 180]}
		}
	}


func reiniciar() -> void:
	datos = {
		"version": 1,
		"dia": 0,
		"fase": "NOCHE",
		"restante": 0.0,
		"acumulador_visitas": 0.0,
		"dinero": 0,
		"xp": 0,
		"ingresos_hoy": 0,
		"visitantes_hoy": 0,
		"visitantes_total": 0,
		"mejoras": {"inventario": 0, "alcance": 0},
		"estilos": {"arcade": 0, "museo": 0, "cyber": 0},
		"completadas": [],
		"clasificadas": [],
		"manifiesto": [],
		"semilla": 20261012
	}


func registrar_manifiesto(ids: Array) -> void:
	if not datos["manifiesto"].is_empty() or not _lista_ids_valida(ids):
		return
	datos["manifiesto"] = ids.duplicate()


func registrar_clasificacion(id: String) -> bool:
	if not _id_valido(id) or datos["clasificadas"].has(id):
		return false
	if datos["clasificadas"].size() >= MAX_IDS:
		return false
	datos["clasificadas"].append(id)
	datos["xp"] = mini(MAX_CONTADOR, int(datos["xp"]) + int(reglas["experiencia_clasificar"]))
	return true


func completar_coleccion(id: String) -> bool:
	if not _id_valido(id) or datos["completadas"].has(id):
		return false
	if datos["completadas"].size() >= MAX_IDS:
		return false
	datos["completadas"].append(id)
	var recompensa: Dictionary = reglas["recompensa_coleccion"]
	datos["dinero"] = mini(MAX_CONTADOR, int(datos["dinero"]) + int(recompensa["dinero"]))
	datos["xp"] = mini(MAX_CONTADOR, int(datos["xp"]) + int(recompensa["xp"]))
	return true


func capacidad_inventario() -> int:
	var mejora: Dictionary = reglas["mejoras"]["inventario"]
	return int(mejora["base"]) + int(mejora["paso"]) * int(datos["mejoras"]["inventario"])


func alcance() -> float:
	var mejora: Dictionary = reglas["mejoras"]["alcance"]
	return float(mejora["base"]) + float(mejora["paso"]) * int(datos["mejoras"]["alcance"])


func comprar_mejora(tipo: String) -> String:
	if not datos["mejoras"].has(tipo):
		return "Mejora desconocida."
	var nivel: int = int(datos["mejoras"][tipo])
	var mejora: Dictionary = reglas["mejoras"][tipo]
	if nivel >= mejora["costos"].size():
		return "Esta mejora ya está al máximo."
	var xp_necesaria: int = int(mejora["xp"][nivel])
	if int(datos["xp"]) < xp_necesaria:
		return "Necesitas %d XP para esta mejora." % xp_necesaria
	var costo: int = int(mejora["costos"][nivel])
	if int(datos["dinero"]) < costo:
		return "Necesitas %d créditos para esta mejora." % costo
	datos["dinero"] = int(datos["dinero"]) - costo
	datos["mejoras"][tipo] = nivel + 1
	return ""


func comprar_estilo(tipo: String) -> String:
	if not datos["estilos"].has(tipo):
		return "Estilo desconocido."
	var nivel: int = int(datos["estilos"][tipo])
	var costos: Array = reglas["estilos"][tipo]["costos"]
	if nivel >= costos.size():
		return "Este estilo ya está al máximo."
	var costo: int = int(costos[nivel])
	if int(datos["dinero"]) < costo:
		return "Necesitas %d créditos para este estilo." % costo
	datos["dinero"] = int(datos["dinero"]) - costo
	datos["estilos"][tipo] = nivel + 1
	return ""


func abrir_dia() -> bool:
	if datos["fase"] != "NOCHE" or int(datos["dia"]) >= MAX_CONTADOR:
		return false
	datos["dia"] = int(datos["dia"]) + 1
	datos["fase"] = "DIA"
	datos["restante"] = float(reglas["duracion_dia"])
	datos["acumulador_visitas"] = 0.0
	datos["ingresos_hoy"] = 0
	datos["visitantes_hoy"] = 0
	return true


func avanzar(delta: float, exhibidas: int, calidad: float) -> Array[Dictionary]:
	var eventos: Array[Dictionary] = []
	if datos["fase"] != "DIA" or not is_finite(delta) or delta <= 0.0:
		return eventos
	# Solo transcurre el tiempo que aún queda de apertura, incluso tras una pausa.
	var transcurrido: float = minf(delta, float(datos["restante"]))
	var intervalo: float = float(reglas["intervalo_visitas"])
	var acumulado: float = float(datos["acumulador_visitas"]) + transcurrido
	var pulsos: int = int(floor((acumulado + 0.00000001) / intervalo))
	datos["acumulador_visitas"] = maxf(0.0, acumulado - pulsos * intervalo)
	datos["restante"] = maxf(0.0, float(datos["restante"]) - transcurrido)
	# Una estantería vacía no genera visitas ni acumula visitas para después.
	if exhibidas > 0:
		var calidad_segura: float = clampf(calidad, 0.0, 100.0) if is_finite(calidad) else 0.0
		var importe: int = int(reglas["ticket_base"]) + int(floor(calidad_segura / 20.0))
		importe += mini(exhibidas, MAX_IDS) / 10
		for nivel: Variant in datos["estilos"].values():
			importe += int(nivel)
		for _pulso: int in range(pulsos):
			var ingreso: int = mini(importe, MAX_CONTADOR - int(datos["dinero"]))
			datos["dinero"] = int(datos["dinero"]) + ingreso
			datos["ingresos_hoy"] = mini(MAX_CONTADOR, int(datos["ingresos_hoy"]) + ingreso)
			datos["visitantes_hoy"] = mini(MAX_CONTADOR, int(datos["visitantes_hoy"]) + 1)
			datos["visitantes_total"] = mini(MAX_CONTADOR, int(datos["visitantes_total"]) + 1)
			eventos.append({"tipo": "visitante", "importe": ingreso})
	if float(datos["restante"]) <= 0.0:
		datos["fase"] = "NOCHE"
		datos["acumulador_visitas"] = 0.0
		eventos.append({
			"tipo": "noche", "dia": int(datos["dia"]),
			"ingresos": int(datos["ingresos_hoy"]), "visitantes": int(datos["visitantes_hoy"])
		})
	return eventos


func campana_completa() -> bool:
	if datos["manifiesto"].is_empty():
		return false
	for id: String in datos["manifiesto"]:
		if not datos["clasificadas"].has(id):
			return false
	return true


func progreso() -> float:
	if datos["manifiesto"].is_empty():
		return 0.0
	var completadas: int = 0
	for id: String in datos["manifiesto"]:
		if datos["clasificadas"].has(id):
			completadas += 1
	return float(completadas) / datos["manifiesto"].size()


func exportar() -> Dictionary:
	return datos.duplicate(true)


func validar(value: Variant) -> String:
	if not value is Dictionary:
		return "El estado de la tienda debe ser un objeto."
	if value.size() != CAMPOS.size():
		return "El estado de la tienda contiene campos ausentes o desconocidos."
	for campo: String in CAMPOS:
		if not value.has(campo):
			return "Falta el campo de tienda: " + campo
	if not _entero_en_rango(value["version"], 1, 1):
		return "Versión de tienda incompatible."
	for campo: String in ["dia", "dinero", "xp", "ingresos_hoy", "visitantes_hoy", "visitantes_total"]:
		if not _entero_en_rango(value[campo], 0, MAX_CONTADOR):
			return "Contador de tienda inválido: " + campo
	if not _entero_en_rango(value["semilla"], 0, 2147483647):
		return "Semilla inválida."
	if not value["fase"] is String or not value["fase"] in ["DIA", "NOCHE"]:
		return "Fase de tienda inválida."
	if not _numero_en_rango(value["restante"], 0.0, float(reglas["duracion_dia"])):
		return "Tiempo de apertura inválido."
	if not _numero_en_rango(value["acumulador_visitas"], 0.0, float(reglas["intervalo_visitas"])):
		return "Tiempo de visitas inválido."
	if float(value["acumulador_visitas"]) >= float(reglas["intervalo_visitas"]):
		return "El acumulador de visitas excede un intervalo."
	if value["fase"] == "NOCHE" and (float(value["restante"]) != 0.0 or float(value["acumulador_visitas"]) != 0.0):
		return "Una tienda cerrada no puede tener tiempo de apertura pendiente."
	if value["fase"] == "DIA" and (float(value["restante"]) <= 0.0 or int(value["dia"]) < 1):
		return "Una tienda abierta debe tener un día y tiempo válidos."
	if int(value["visitantes_hoy"]) > int(value["visitantes_total"]):
		return "Las visitas de hoy exceden las visitas totales."
	for grupo: String in ["mejoras", "estilos"]:
		if not value[grupo] is Dictionary or value[grupo].size() != reglas[grupo].size():
			return "Grupo de progresión inválido: " + grupo
		for tipo: String in reglas[grupo]:
			if not value[grupo].has(tipo) or not _entero_en_rango(value[grupo][tipo], 0, reglas[grupo][tipo]["costos"].size()):
				return "Nivel de progresión inválido: " + tipo
	for campo: String in ["completadas", "clasificadas", "manifiesto"]:
		if not _lista_ids_valida(value[campo]):
			return "Lista de identificadores inválida: " + campo
	return ""


func restaurar(value: Dictionary) -> bool:
	if not validar(value).is_empty():
		return false
	# Restaurar nunca vuelve a conceder XP, premios ni ingresos.
	datos = value.duplicate(true)
	return true


func _entero_en_rango(value: Variant, minimo: int, maximo: int) -> bool:
	if not _numero_en_rango(value, float(minimo), float(maximo)):
		return false
	return float(value) == floor(float(value))


func _numero_en_rango(value: Variant, minimo: float, maximo: float) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numero: float = float(value)
	return is_finite(numero) and numero >= minimo and numero <= maximo


func _id_valido(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length() > MAX_LONGITUD_ID:
		return false
	if value != value.strip_edges():
		return false
	for i: int in range(value.length()):
		if value.unicode_at(i) < 32:
			return false
	return true


func _lista_ids_valida(value: Variant) -> bool:
	if not value is Array or value.size() > MAX_IDS:
		return false
	var encontrados: Dictionary = {}
	for id: Variant in value:
		if not _id_valido(id) or encontrados.has(id):
			return false
		encontrados[id] = true
	return true
