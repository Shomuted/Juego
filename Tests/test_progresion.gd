extends SceneTree

const Modelo = preload("res://Scripts/EstadoTienda.gd")
var pruebas: int = 0
var fallos: int = 0


func _initialize() -> void:
	_probar_campana()
	_probar_economia()
	_probar_jornadas()
	_probar_guardado()
	print("PROGRESIÓN: %d pruebas, %d fallos" % [pruebas, fallos])
	quit(1 if fallos > 0 else 0)


func _comprobar(condicion: bool, descripcion: String) -> void:
	pruebas += 1
	if not condicion:
		fallos += 1
		push_error("FALLO: " + descripcion)


func _probar_campana() -> void:
	var tienda = Modelo.new()
	_comprobar(tienda.validar(tienda.exportar()).is_empty(), "Una partida nueva es válida")
	_comprobar(not tienda.campana_completa() and tienda.progreso() == 0.0, "El manifiesto vacío no gana la campaña")
	var ids: Array = ["copia_1", "copia_2", "copia_3"]
	tienda.registrar_manifiesto(ids)
	ids.append("copia_4")
	_comprobar(tienda.datos["manifiesto"].size() == 3, "El manifiesto conserva una copia independiente")
	tienda.registrar_manifiesto(["otra_copia"])
	_comprobar(tienda.datos["manifiesto"].size() == 3, "No se reemplaza el stock original al cargar o volver a escanear")
	_comprobar(not tienda.registrar_clasificacion(""), "Un ID vacío no concede XP")
	_comprobar(tienda.registrar_clasificacion("copia_1"), "La primera clasificación se registra")
	_comprobar(tienda.datos["xp"] == 5, "Clasificar una copia concede 5 XP")
	_comprobar(not tienda.registrar_clasificacion("copia_1") and tienda.datos["xp"] == 5, "Mover de nuevo una copia no duplica XP")
	_comprobar(is_equal_approx(tienda.progreso(), 1.0 / 3.0), "El progreso cuenta IDs del stock original")
	tienda.registrar_clasificacion("copia_externa")
	_comprobar(is_equal_approx(tienda.progreso(), 1.0 / 3.0), "IDs ajenos no inflan el progreso de campaña")
	tienda.registrar_clasificacion("copia_2")
	_comprobar(not tienda.campana_completa(), "Tantas clasificaciones como stock no bastan si falta una copia original")
	tienda.registrar_clasificacion("copia_3")
	_comprobar(tienda.campana_completa() and tienda.progreso() == 1.0, "Clasificar todo el stock completa la campaña")
	_comprobar(tienda.completar_coleccion("ff7_ps1"), "Una colección se puede premiar por primera vez")
	_comprobar(tienda.datos["dinero"] == 120 and tienda.datos["xp"] == 70, "La ayuda suma créditos y XP a lo existente")
	_comprobar(not tienda.completar_coleccion("ff7_ps1"), "La misma colección no repite el premio")
	_comprobar(tienda.datos["dinero"] == 120 and tienda.datos["xp"] == 70, "Intentar repetir el premio mantiene los saldos")
	tienda.reiniciar()
	_comprobar(tienda.datos["dinero"] == 0 and tienda.datos["xp"] == 0 and tienda.datos["manifiesto"].is_empty(), "Reiniciar borra toda la progresión")
	_comprobar(not tienda.campana_completa(), "Reiniciar no concede la victoria por un stock vacío")
	tienda.registrar_manifiesto(["repetida", "repetida"])
	_comprobar(tienda.datos["manifiesto"].is_empty(), "Un manifiesto con IDs repetidos se rechaza entero")


func _probar_economia() -> void:
	var tienda = Modelo.new()
	_comprobar(tienda.capacidad_inventario() == 5 and is_equal_approx(tienda.alcance(), 3.0), "Capacidad y alcance iniciales")
	var inicial: Dictionary = tienda.exportar()
	_comprobar(not tienda.comprar_mejora("inventario").is_empty() and tienda.datos == inicial, "Una mejora bloqueada no consume recursos")
	_comprobar(not tienda.comprar_estilo("arcade").is_empty() and tienda.datos == inicial, "Un estilo sin dinero no cambia el estado")
	_comprobar(not tienda.comprar_mejora("inexistente").is_empty(), "Se rechazan mejoras desconocidas")
	_comprobar(not tienda.comprar_estilo("inexistente").is_empty(), "Se rechazan estilos desconocidos")
	tienda.datos["dinero"] = 1000
	_comprobar(not tienda.comprar_mejora("inventario").is_empty() and tienda.datos["dinero"] == 1000, "El dinero no evita el requisito de XP")
	tienda.datos["xp"] = 25
	tienda.datos["dinero"] = 79
	_comprobar(not tienda.comprar_mejora("inventario").is_empty() and tienda.datos["dinero"] == 79, "El precio completo es necesario")
	tienda.datos["dinero"] = 80
	_comprobar(tienda.comprar_mejora("inventario").is_empty(), "Se compra con dinero y XP exactos")
	_comprobar(tienda.capacidad_inventario() == 7 and tienda.datos["dinero"] == 0 and tienda.datos["xp"] == 25, "Comprar cobra dinero y conserva la experiencia")
	tienda.datos["dinero"] = 5000
	tienda.datos["xp"] = 1000
	tienda.comprar_mejora("inventario")
	tienda.comprar_mejora("inventario")
	_comprobar(tienda.capacidad_inventario() == 11, "Inventario alcanza once espacios en nivel tres")
	var saldo: int = int(tienda.datos["dinero"])
	_comprobar(not tienda.comprar_mejora("inventario").is_empty() and tienda.datos["dinero"] == saldo, "Comprar por encima del máximo no cobra")
	for _nivel: int in range(3):
		_comprobar(tienda.comprar_mejora("alcance").is_empty(), "Nivel de alcance adquirido")
	_comprobar(is_equal_approx(tienda.alcance(), 4.5), "El alcance tiene un máximo de 4.5 metros")
	_comprobar(not tienda.comprar_mejora("alcance").is_empty(), "El alcance no supera el máximo")
	for estilo: String in ["arcade", "museo", "cyber"]:
		for _nivel: int in range(3):
			_comprobar(tienda.comprar_estilo(estilo).is_empty(), "Compra de estilo %s" % estilo)
		_comprobar(not tienda.comprar_estilo(estilo).is_empty(), "El estilo %s respeta el máximo" % estilo)
	_comprobar(tienda.datos["estilos"] == {"arcade": 3, "museo": 3, "cyber": 3}, "Los estilos son combinables")
	tienda.abrir_dia()
	var eventos: Array[Dictionary] = tienda.avanzar(12.0, 10, 80.0)
	_comprobar(eventos.size() == 1 and eventos[0]["importe"] == 18, "La entrada incluye calidad, exposición y tres estilos combinados")
	_comprobar(tienda.validar(tienda.exportar()).is_empty(), "Una partida con todas las mejoras sigue siendo serializable")


func _probar_jornadas() -> void:
	var tienda = Modelo.new()
	var inicial: Dictionary = tienda.exportar()
	_comprobar(tienda.avanzar(1000000000.0, 60, 100.0).is_empty() and tienda.datos == inicial, "La noche nunca genera dinero ni visitas")
	_comprobar(tienda.abrir_dia(), "Se puede abrir la primera jornada")
	_comprobar(not tienda.abrir_dia() and tienda.datos["dia"] == 1, "Abrir dos veces no renueva el reloj")
	var antes: Dictionary = tienda.exportar()
	for delta: float in [-1.0, 0.0, INF, NAN]:
		_comprobar(tienda.avanzar(delta, 10, 80.0).is_empty() and tienda.datos == antes, "Delta no positivo o no finito no altera el estado")
	_comprobar(tienda.avanzar(11.5, 10, 80.0).is_empty(), "No hay visitantes antes del intervalo")
	var eventos: Array[Dictionary] = tienda.avanzar(0.5, 10, 80.0)
	_comprobar(eventos.size() == 1 and eventos[0]["tipo"] == "visitante" and eventos[0]["importe"] == 9, "El primer visitante llega al completar doce segundos")
	_comprobar(tienda.datos["dinero"] == 9 and tienda.datos["visitantes_hoy"] == 1, "La visita actualiza dinero y contadores")
	eventos = tienda.avanzar(1000000000.0, 10, 80.0)
	_comprobar(eventos.size() == 15 and eventos.back()["tipo"] == "noche", "Un salto enorme solo consume el resto de una jornada")
	_comprobar(tienda.datos["visitantes_hoy"] == 15 and tienda.datos["dinero"] == 135, "Hay como máximo quince visitas de doce segundos por jornada")
	_comprobar(tienda.datos["fase"] == "NOCHE" and tienda.datos["restante"] == 0.0, "La jornada se cierra al agotar el tiempo")
	_comprobar(tienda.validar(tienda.exportar()).is_empty(), "La jornada cerrada pasa validación")
	antes = tienda.exportar()
	_comprobar(tienda.avanzar(12.0, 10, 80.0).is_empty() and tienda.datos == antes, "Cerrar no deja ingresos nocturnos pendientes")
	tienda.abrir_dia()
	_comprobar(tienda.datos["dia"] == 2 and tienda.datos["ingresos_hoy"] == 0 and tienda.datos["visitantes_hoy"] == 0, "El nuevo día limpia solo las estadísticas diarias")
	_comprobar(tienda.datos["dinero"] == 135 and tienda.datos["visitantes_total"] == 15, "Cambiar de día conserva créditos y visitantes totales")
	_comprobar(tienda.avanzar(24.0, 0, 100.0).is_empty() and tienda.datos["dinero"] == 135, "No se cobran entradas sin juegos exhibidos")
	_comprobar(tienda.avanzar(1.0, 10, 80.0).is_empty(), "Exhibir después no cobra visitas acumuladas de una sala vacía")
	eventos = tienda.avanzar(11.0, 10, NAN)
	_comprobar(eventos.size() == 1 and eventos[0]["importe"] == 5, "Calidad no finita se trata como cero")
	var continua = Modelo.new()
	var fraccionada = Modelo.new()
	continua.abrir_dia()
	fraccionada.abrir_dia()
	continua.avanzar(180.0, 20, 60.0)
	for _tick: int in range(720):
		fraccionada.avanzar(0.25, 20, 60.0)
	_comprobar(continua.exportar() == fraccionada.exportar(), "El resultado económico no depende de la frecuencia de actualización")
	var vacia = Modelo.new()
	vacia.abrir_dia()
	eventos = vacia.avanzar(180.0, 0, 0.0)
	_comprobar(eventos.size() == 1 and eventos[0]["tipo"] == "noche" and vacia.datos["dinero"] == 0, "Una jornada vacía termina normalmente sin ingresos")


func _probar_guardado() -> void:
	var tienda = Modelo.new()
	tienda.registrar_manifiesto(["uno", "dos"])
	tienda.registrar_clasificacion("uno")
	tienda.completar_coleccion("ff7_ps1")
	tienda.comprar_estilo("arcade")
	tienda.abrir_dia()
	tienda.avanzar(13.25, 10, 80.0)
	var guardado: Dictionary = tienda.exportar()
	guardado["mejoras"]["inventario"] = 3
	guardado["manifiesto"].append("invasor")
	_comprobar(tienda.capacidad_inventario() == 5 and tienda.datos["manifiesto"].size() == 2, "Exportar no expone referencias mutables internas")
	guardado = JSON.parse_string(JSON.stringify(tienda.exportar()))
	_comprobar(tienda.validar(guardado).is_empty(), "Los números enteros de JSON son aceptados")
	var cargada = Modelo.new()
	_comprobar(cargada.restaurar(guardado), "La tienda restaura su estado completo")
	_comprobar(cargada.exportar() == guardado, "Restaurar conserva todos los valores del JSON sin conceder recursos")
	guardado["estilos"]["arcade"] = 3
	_comprobar(cargada.datos["estilos"]["arcade"] == 1, "Restaurar toma una copia independiente")
	_comprobar(not cargada.registrar_clasificacion("uno") and not cargada.completar_coleccion("ff7_ps1"), "Persisten las marcas que evitan premios duplicados")
	_comprobar(not cargada.campana_completa() and cargada.progreso() == 0.5, "La carga conserva el stock original y el progreso real")
	var eventos_original: Array[Dictionary] = tienda.avanzar(10.75, 10, 80.0)
	var eventos_cargados: Array[Dictionary] = cargada.avanzar(10.75, 10, 80.0)
	_comprobar(eventos_original == eventos_cargados and tienda.datos["dinero"] == cargada.datos["dinero"], "La visita que cruza un guardado paga exactamente una vez")
	_comprobar(not tienda.validar([]).is_empty() and not tienda.validar(null).is_empty(), "Solo se aceptan objetos de estado")
	var corrupciones: Array[Dictionary] = [
		{"xp": -1}, {"xp": true}, {"dinero": 0.5}, {"dinero": INF},
		{"dinero": 1000000001}, {"version": 2}, {"dia": "1"}, {"fase": "VENTA"},
		{"restante": NAN}, {"restante": -1}, {"restante": 181},
		{"restante": 0}, {"acumulador_visitas": -1}, {"acumulador_visitas": 12},
		{"semilla": 1.5}, {"visitantes_total": 0},
		{"mejoras": {"inventario": 4, "alcance": 0}},
		{"mejoras": {"inventario": true, "alcance": 0}},
		{"estilos": {"arcade": 1, "museo": 0}},
		{"completadas": ["repetida", "repetida"]}, {"clasificadas": [42]},
		{"manifiesto": [""]}, {"manifiesto": ["x".repeat(129)]},
		{"manifiesto": [" espacio"]}, {"manifiesto": ["con\nsalto"]},
		{"clasificadas": "no es una lista"}
	]
	var antes: Dictionary = cargada.exportar()
	for cambio: Dictionary in corrupciones:
		var corrupto: Dictionary = antes.duplicate(true)
		corrupto.merge(cambio, true)
		_comprobar(not cargada.validar(corrupto).is_empty(), "Validación rechaza estado corrupto: " + str(cambio.keys()))
		_comprobar(not cargada.restaurar(corrupto) and cargada.exportar() == antes, "Restauración inválida es atómica: " + str(cambio.keys()))
	var incompleto: Dictionary = antes.duplicate(true)
	incompleto.erase("xp")
	_comprobar(not cargada.restaurar(incompleto) and cargada.exportar() == antes, "Un campo ausente no destruye la partida")
	var desconocido: Dictionary = antes.duplicate(true)
	desconocido["extra"] = 1
	_comprobar(not cargada.restaurar(desconocido) and cargada.exportar() == antes, "Los campos desconocidos se rechazan de forma atómica")
	var nocturno: Dictionary = antes.duplicate(true)
	nocturno["fase"] = "NOCHE"
	_comprobar(not cargada.restaurar(nocturno), "La noche no admite temporizadores de apertura activos")
