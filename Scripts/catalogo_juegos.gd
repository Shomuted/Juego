extends RefCounted
class_name CatalogoJuegos

# Archivo generado por Tools/build_catalog.py desde SQLite.
# Se conservan los nombres de métodos del proyecto para compatibilidad.
const JUEGOS: Dictionary = {
	"ff7_ps1": {"titulo": "Final Fantasy VII", "consola": "PS1"},
	"mgs_ps1": {"titulo": "Metal Gear Solid", "consola": "PS1"},
	"gt4_ps2": {"titulo": "Gran Turismo 4", "consola": "PS2"},
	"sh2_ps2": {"titulo": "Silent Hill 2", "consola": "PS2"},
	"mario64_n64": {"titulo": "Super Mario 64", "consola": "N64"},
	"zeldaoot_n64": {"titulo": "The Legend of Zelda: Ocarina of Time", "consola": "N64"},
	"smw_snes": {"titulo": "Super Mario World", "consola": "SNES"},
	"supermetroid_snes": {"titulo": "Super Metroid", "consola": "SNES"},
	"sunshine_gc": {"titulo": "Super Mario Sunshine", "consola": "GameCube"},
	"windwaker_gc": {"titulo": "The Legend of Zelda: The Wind Waker", "consola": "GameCube"},
	"halo_xbox": {"titulo": "Halo: Combat Evolved", "consola": "Xbox"},
	"fable_xbox": {"titulo": "Fable", "consola": "Xbox"}
}


static func obtener_juego(id_juego: String) -> Dictionary:
	if not JUEGOS.has(id_juego):
		push_warning("ID de juego desconocido: " + id_juego)
		return {}

	return JUEGOS[id_juego].duplicate(true)


static func obtener_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_juego: String in JUEGOS.keys():
		ids.append(id_juego)
	return ids


static func existe(id_juego: String) -> bool:
	return JUEGOS.has(id_juego)
