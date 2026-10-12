extends SceneTree

var fallos: int = 0
var comprobaciones: int = 0


func _initialize() -> void:
    call_deferred("_ejecutar")


func _comprobar(condicion: bool, descripcion: String) -> void:
    comprobaciones += 1
    if not condicion:
        fallos += 1
        push_error("FALLO: " + descripcion)
    else:
        print("OK: " + descripcion)


func _copia(id_juego: String, id_copia: String, consola: String = "PS1") -> Dictionary:
    return {
        "id_juego": id_juego,
        "id_copia": id_copia,
        "titulo": str(CatalogoJuegos.obtener_juego(id_juego).get("titulo", "Juego")),
        "consola": consola,
        "condicion": 67,
        "es_especial": false
    }


func _ejecutar() -> void:
    var estanteria: EstanteriaJuegos = EstanteriaJuegos.new()
    estanteria.consola = "PS1"
    estanteria.ids_por_fila = PackedStringArray(["ff7_ps1", "mgs_ps1"])
    root.add_child(estanteria)

    _comprobar(estanteria.capacidad == 30, "30 posiciones fijas")
    _comprobar(estanteria.ids_asignados_por_fila[0] == "ff7_ps1", "Primera fila reservada")
    _comprobar(estanteria.ids_asignados_por_fila[1] == "mgs_ps1", "Segunda fila reservada")
    _comprobar(estanteria.ids_asignados_por_fila[2].is_empty(), "Tercera fila sin asignar")

    _comprobar(estanteria.guardar_juego(_copia("mgs_ps1", "mgs_1")), "Primera copia de fila 2")
    _comprobar(estanteria.obtener_copia_en_posicion(1, 0).get("id_copia", "") == "mgs_1", "Fila 2, columna 1")
    _comprobar(estanteria.guardar_juego(_copia("ff7_ps1", "ff7_1")), "Primera copia de fila 1")
    _comprobar(estanteria.obtener_copia_en_posicion(0, 0).get("id_copia", "") == "ff7_1", "Fila 1, columna 1")

    _comprobar(estanteria.guardar_juego(_copia("mgs_ps1", "mgs_2")), "Segunda copia de fila 2")
    _comprobar(estanteria.obtener_copia_en_posicion(1, 1).get("id_copia", "") == "mgs_2", "Fila 2, columna 2")
    _comprobar(estanteria.obtener_copia_en_posicion(0, 0).get("id_copia", "") == "ff7_1", "No se mueven copias existentes")
    _comprobar(estanteria.juegos_guardados[0].get("condicion", -1) == 67, "Condición preservada")

    _comprobar(not estanteria.guardar_juego(_copia("ff7_ps1", "ff7_1")), "Rechazo de ID de copia duplicado")
    _comprobar(not estanteria.guardar_juego(_copia("gt4_ps2", "ps2_1", "PS2")), "Rechazo de consola incorrecta")
    _comprobar(not estanteria.guardar_juego(_copia("ff7_ps1", "")), "Rechazo de copia sin ID")
    _comprobar(estanteria.juegos_guardados.size() == 3, "Rechazos no alteran la estantería")

    var veces_completada: Array[String] = []
    estanteria.coleccion_completada.connect(func(id: String) -> void:
        veces_completada.append(id)
    )

    for i in range(2, 11):
        _comprobar(estanteria.guardar_juego(_copia("ff7_ps1", "ff7_%d" % i)), "Agregar copia FF7 %d" % i)

    _comprobar(estanteria.cantidad_de_copias("ff7_ps1") == 10, "Colección completa de 10")
    _comprobar(estanteria.coleccion_esta_completa("ff7_ps1"), "Estado de colección completa")
    _comprobar(is_equal_approx(estanteria.promedio_condicion("ff7_ps1"), 6.7), "Calidad promedio 6.7/10")
    _comprobar(veces_completada.size() == 1 and veces_completada[0] == "ff7_ps1", "Señal de colección emitida una vez")
    _comprobar(not estanteria.guardar_juego(_copia("ff7_ps1", "ff7_11")), "No se permite la copia número 11")
    _comprobar(estanteria.obtener_copia_en_posicion(0, 9).get("id_copia", "") == "ff7_10", "Último slot de la primera fila")
    _comprobar(estanteria.obtener_copia_en_posicion(1, 0).get("id_copia", "") == "mgs_1", "La segunda fila no se mueve")

    var sin_reserva: EstanteriaJuegos = EstanteriaJuegos.new()
    sin_reserva.consola = "N64"
    root.add_child(sin_reserva)
    var mario: Dictionary = _copia("mario64_n64", "n64_1", "N64")
    var zelda: Dictionary = _copia("zeldaoot_n64", "n64_2", "N64")
    _comprobar(sin_reserva.guardar_juego(zelda), "Asignación automática de primera fila")
    _comprobar(sin_reserva.guardar_juego(mario), "Asignación automática de segunda fila")
    _comprobar(sin_reserva.guardar_juego(_copia("zeldaoot_n64", "n64_3", "N64")), "Reutiliza la primera fila por ID")
    _comprobar(sin_reserva.obtener_copia_en_posicion(0, 1).get("id_copia", "") == "n64_3", "Slots independientes en modo automático")

    print("RESULTADO: %d comprobaciones, %d fallos." % [comprobaciones, fallos])
    quit(1 if fallos > 0 else 0)
