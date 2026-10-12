extends Node3D
class_name EstanteriaJuegos

signal coleccion_completada(id_juego: String)

@export_enum("PS1", "PS2", "N64") var consola: String = "PS1"
@export_group("Colecciones por fila")
@export var ids_por_fila: PackedStringArray = PackedStringArray()

const COLUMNAS: int = 10
const FILAS: int = 3
const ANCHO: float = 4.0
const PROFUNDIDAD: float = 0.7
const ESPACIADO_HORIZONTAL: float = 0.37
const ESPACIADO_VERTICAL: float = 0.76
const POSICION_INICIAL_X: float = -1.68
const ALTURA_PRIMERA_FILA: float = 0.51

var capacidad: int = COLUMNAS * FILAS
var juegos_guardados: Array[Dictionary] = []
var ids_asignados_por_fila: Array[String] = []
var ultimo_error: String = ""

var exhibicion: Node3D
var contador: Label3D
var etiquetas_fila: Array[Label3D] = []


func _ready() -> void:
    add_to_group("estanteria")
    _configurar_filas()
    _construir_estanteria()
    _crear_colision()
    _actualizar_etiquetas()


func _configurar_filas() -> void:
    ids_asignados_por_fila.clear()
    for fila in range(FILAS):
        ids_asignados_por_fila.append("")

    if ids_por_fila.size() > FILAS:
        push_warning("La estantería %s solo admite %d filas." % [consola, FILAS])

    for fila in range(mini(ids_por_fila.size(), FILAS)):
        var id_juego: String = ids_por_fila[fila].strip_edges()
        if id_juego.is_empty():
            continue

        if not CatalogoJuegos.existe(id_juego):
            push_warning("ID desconocido en la fila %d: %s" % [fila + 1, id_juego])
            continue

        var definicion: Dictionary = CatalogoJuegos.obtener_juego(id_juego)
        if str(definicion.get("consola", "")) != consola:
            push_warning("%s no pertenece a la estantería %s." % [id_juego, consola])
            continue

        if ids_asignados_por_fila.has(id_juego):
            push_warning("La colección %s está repetida en esta estantería." % id_juego)
            continue

        ids_asignados_por_fila[fila] = id_juego


func guardar_juego(datos: Dictionary) -> bool:
    ultimo_error = ""
    var id_juego: String = str(datos.get("id_juego", ""))
    var id_copia: String = str(datos.get("id_copia", ""))

    if not CatalogoJuegos.existe(id_juego):
        ultimo_error = "Ese título no existe en el catálogo."
        return false

    if id_copia.is_empty():
        ultimo_error = "La copia no tiene un identificador válido."
        return false

    if str(datos.get("consola", "")) != consola:
        ultimo_error = "Este juego pertenece a otra consola."
        return false

    if str(CatalogoJuegos.obtener_juego(id_juego).get("consola", "")) != consola:
        ultimo_error = "El título no corresponde a esta consola."
        return false

    for existente in juegos_guardados:
        if str(existente.get("id_copia", "")) == id_copia:
            ultimo_error = "Esta copia ya está en la estantería."
            return false

    var fila: int = _buscar_fila(id_juego)
    if fila < 0:
        ultimo_error = "No queda una fila disponible para este título."
        return false

    var columna: int = _primera_columna_libre(fila)
    if columna < 0:
        ultimo_error = "La colección de este título ya tiene 10 copias."
        return false

    if ids_asignados_por_fila[fila].is_empty():
        ids_asignados_por_fila[fila] = id_juego

    var copia: Dictionary = datos.duplicate(true)
    copia["posicion_estanteria"] = fila * COLUMNAS + columna
    juegos_guardados.append(copia)

    _mostrar_copia(copia)
    _actualizar_etiquetas()

    if cantidad_de_copias(id_juego) == COLUMNAS:
        coleccion_completada.emit(id_juego)

    return true


func _buscar_fila(id_juego: String) -> int:
    var asignada: int = ids_asignados_por_fila.find(id_juego)
    if asignada >= 0:
        return asignada

    for fila in range(FILAS):
        if ids_asignados_por_fila[fila].is_empty():
            return fila

    return -1


func _primera_columna_libre(fila: int) -> int:
    for columna in range(COLUMNAS):
        var posicion: int = fila * COLUMNAS + columna
        var ocupada: bool = false
        for datos in juegos_guardados:
            if int(datos.get("posicion_estanteria", -1)) == posicion:
                ocupada = true
                break
        if not ocupada:
            return columna
    return -1


func cantidad_de_copias(id_juego: String) -> int:
    var cantidad: int = 0
    for datos in juegos_guardados:
        if str(datos.get("id_juego", "")) == id_juego:
            cantidad += 1
    return cantidad


func coleccion_esta_completa(id_juego: String) -> bool:
    return cantidad_de_copias(id_juego) == COLUMNAS


func promedio_condicion(id_juego: String) -> float:
    var cantidad: int = 0
    var suma: int = 0
    for datos in juegos_guardados:
        if str(datos.get("id_juego", "")) == id_juego:
            suma += int(datos.get("condicion", 0))
            cantidad += 1
    if cantidad == 0:
        return 0.0
    return float(suma) / float(cantidad) / 10.0


func obtener_copia_en_posicion(fila: int, columna: int) -> Dictionary:
    if fila < 0 or fila >= FILAS or columna < 0 or columna >= COLUMNAS:
        return {}
    var posicion: int = fila * COLUMNAS + columna
    for datos in juegos_guardados:
        if int(datos.get("posicion_estanteria", -1)) == posicion:
            return datos.duplicate(true)
    return {}


func _construir_estanteria() -> void:
    var madera: StandardMaterial3D = StandardMaterial3D.new()
    madera.albedo_color = Color(0.32, 0.20, 0.12)
    var metal: StandardMaterial3D = StandardMaterial3D.new()
    metal.albedo_color = Color(0.11, 0.12, 0.15)
    var color_rotulo: Color = Color(0.9, 0.9, 1.0)
    match consola:
        "PS1":
            color_rotulo = Color(0.35, 0.75, 1.0)
        "PS2":
            color_rotulo = Color(0.75, 0.65, 1.0)
        "N64":
            color_rotulo = Color(0.7, 1.0, 0.45)

    _pieza("LateralIzquierdo", Vector3(-2.0, 1.35, 0), Vector3(0.12, 2.7, PROFUNDIDAD), madera)
    _pieza("LateralDerecho", Vector3(2.0, 1.35, 0), Vector3(0.12, 2.7, PROFUNDIDAD), madera)
    _pieza("Fondo", Vector3(0, 1.35, 0.32), Vector3(ANCHO, 2.7, 0.08), madera)
    for nivel in range(FILAS + 1):
        _pieza("Bandeja%d" % nivel, Vector3(0, 0.16 + nivel * ESPACIADO_VERTICAL, 0), Vector3(ANCHO, 0.12, PROFUNDIDAD), madera)
    _pieza("Cabecera", Vector3(0, 2.92, 0.02), Vector3(ANCHO + 0.12, 0.35, 0.8), metal)

    var nombre: Label3D = Label3D.new()
    nombre.text = consola
    nombre.font_size = 90
    nombre.pixel_size = 0.003
    nombre.modulate = color_rotulo
    nombre.position = Vector3(0, 2.92, -0.42)
    nombre.rotation.y = PI
    nombre.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    add_child(nombre)

    contador = Label3D.new()
    contador.font_size = 48
    contador.pixel_size = 0.003
    contador.position = Vector3(0, 2.63, -0.42)
    contador.rotation.y = PI
    contador.modulate = Color.WHITE
    add_child(contador)

    for fila in range(FILAS):
        var etiqueta: Label3D = Label3D.new()
        etiqueta.name = "EtiquetaFila%d" % (fila + 1)
        etiqueta.font_size = 35
        etiqueta.pixel_size = 0.0032
        etiqueta.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
        etiqueta.modulate = Color(1.0, 0.91, 0.73)
        etiqueta.position = Vector3(1.81, 0.18 + fila * ESPACIADO_VERTICAL, -0.41)
        etiqueta.rotation.y = PI
        add_child(etiqueta)
        etiquetas_fila.append(etiqueta)

    exhibicion = Node3D.new()
    exhibicion.name = "JuegosOrdenados"
    add_child(exhibicion)


func _crear_colision() -> void:
    var cuerpo: StaticBody3D = StaticBody3D.new()
    cuerpo.name = "ColisionEstanteria"
    cuerpo.collision_layer = 1
    cuerpo.collision_mask = 1
    add_child(cuerpo)
    var forma: CollisionShape3D = CollisionShape3D.new()
    var caja: BoxShape3D = BoxShape3D.new()
    caja.size = Vector3(ANCHO, 2.7, PROFUNDIDAD)
    forma.shape = caja
    forma.position = Vector3(0, 1.35, 0)
    cuerpo.add_child(forma)


func _pieza(nombre: String, centro: Vector3, tamano: Vector3, material: Material) -> void:
    var visual: MeshInstance3D = MeshInstance3D.new()
    visual.name = nombre
    var malla: BoxMesh = BoxMesh.new()
    malla.size = tamano
    visual.mesh = malla
    visual.material_override = material
    visual.position = centro
    add_child(visual)


func _mostrar_copia(datos: Dictionary) -> void:
    if exhibicion == null:
        return

    var posicion: int = int(datos.get("posicion_estanteria", -1))
    if posicion < 0 or posicion >= capacidad:
        push_error("Posición fuera de la estantería: %d" % posicion)
        return

    var fila: int = posicion / COLUMNAS
    var columna: int = posicion % COLUMNAS
    var visual: Node3D = CajaJuego.crear_visual_para_datos(datos)
    visual.rotation.y = PI
    visual.name = "Posicion_%02d" % posicion
    visual.set_meta("id_copia", str(datos.get("id_copia", "")))

    # La altura depende de la forma de la caja, sin alterar filas ni columnas.
    var tamano: Vector3 = CajaJuego.tamano_para_consola(str(datos.get("consola", "")))
    var superficie_fila: float = 0.22 + fila * ESPACIADO_VERTICAL
    visual.position = Vector3(
        POSICION_INICIAL_X + columna * ESPACIADO_HORIZONTAL,
        superficie_fila + tamano.y * 0.5,
        -0.10
    )
    exhibicion.add_child(visual)

func _actualizar_etiquetas() -> void:
    if contador == null:
        return
    contador.text = "%d / %d juegos" % [juegos_guardados.size(), capacidad]
    for fila in range(FILAS):
        var id_juego: String = ids_asignados_por_fila[fila]
        if id_juego.is_empty():
            etiquetas_fila[fila].text = "FILA %d - LIBRE" % (fila + 1)
            continue
        var titulo: String = str(CatalogoJuegos.obtener_juego(id_juego).get("titulo", id_juego))
        if titulo.length() > 21:
            titulo = titulo.substr(0, 20) + "..."
        etiquetas_fila[fila].text = "%s  %d/%d" % [titulo, cantidad_de_copias(id_juego), COLUMNAS]


func restaurar_estado(copias: Array, filas: Array) -> void:
    for nodo in exhibicion.get_children():
        exhibicion.remove_child(nodo)
        nodo.free()

    juegos_guardados.clear()
    ids_asignados_por_fila.clear()
    for id_fila in filas:
        ids_asignados_por_fila.append(str(id_fila))

    for datos in copias:
        var copia: Dictionary = datos.duplicate(true)
        juegos_guardados.append(copia)
        _mostrar_copia(copia)
    _actualizar_etiquetas()
