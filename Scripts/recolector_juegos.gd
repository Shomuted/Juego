extends RayCast3D
# Componente opcional de detección. La recogida principal está en Player.gd.

func obtener_caja_en_mira() -> CajaJuego:
    force_raycast_update()
    var cuerpo: Object = get_collider()
    if cuerpo is CajaJuego:
        return cuerpo as CajaJuego
    return null
