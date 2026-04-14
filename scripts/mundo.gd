extends Node2D

# --- CONFIGURACIÓN ---
@export var escena_burbuja: PackedScene
@export var escena_explosion: PackedScene # <-- NUEVO: Arrastra aquí tu Explosion.tscn en el editor
@export var filas: int = 7
@export var columnas: int = 30
@export var diametro_burbuja: float = 66
@export var velocidad_disparo: float = 1300.0
@export var margen_top_ui: float = 76
@export var margen_lateral_ui: float = 6.0
@export var tiempo_maximo: float = 600

# --- REFERENCIAS ---
@onready var contenedor = $ContenedorBurbujas
@onready var lanzador = $Lanzador
@onready var pos_carga = $Lanzador/PosicionCarga
@onready var pos_siguiente = $Lanzador/PosicionSiguiente
@onready var linea_derrota = $LineaDerrota
@onready var capa_ui = $FinalNivel
@onready var boton_reintentar = $FinalNivel/ColorRect/Button
@onready var linea_guia = $LineaGuia
@onready var label_score = $UI/LabelScore
@onready var label_timer = $UI/LabelTimer 
@onready var label_titulo_ui = $FinalNivel/ColorRect/LabelTitulo
@onready var contenedor_corazones = $UI/ContenedorCorazones 

# --- REFERENCIAS DEL LEADERBOARD ---
@onready var input_nombre = $FinalNivel/ColorRect/InputNombre
@onready var boton_guardar = $FinalNivel/ColorRect/BotonGuardar
@onready var label_leaderboard = $FinalNivel/ColorRect/LabelLeaderboard

# --- VARIABLES DE ESTADO ---
var burbuja_cargada: CharacterBody2D = null
var burbuja_siguiente: CharacterBody2D = null
var colores = [0, 1, 2, 3, 4, 5] 
var juego_activo: bool = true
var puntaje: int = 0
var tiempo_restante: float = 0.0 
var cronometro_pausado: bool = true 

# --- LEADERBOARD CONFIG ---
const ARCHIVO_LEADERBOARD = "user://top_scores.json"
var puntajes_guardados = []

# --- VARIABLES DE LÓGICA DE JUEGO ---
var fallos_consecutivos: int = 0
const MAX_FALLOS: int = 3
var techo_es_impar: bool = false


# ==========================================
# CICLO DE VIDA DEL NODO
# ==========================================

func _ready():
	var radio = diametro_burbuja / 2.0
	var distancia_y = diametro_burbuja * 0.90
	
	tiempo_restante = tiempo_maximo 
	
	if input_nombre: input_nombre.hide()
	if boton_guardar: 
		boton_guardar.hide()
		if not boton_guardar.pressed.is_connected(_on_boton_guardar_pressed):
			boton_guardar.pressed.connect(_on_boton_guardar_pressed)
	if label_leaderboard: label_leaderboard.hide()
	
	cargar_leaderboard()
	
	if has_node("Tutorial"):
		$Tutorial.tutorial_completado.connect(_on_tutorial_completado)
	else:
		cronometro_pausado = false 
	
	generar_nivel(radio, distancia_y)
	preparar_proyectiles()
	actualizar_ui_fallos() 

func _process(delta):
	if not juego_activo: return 
	
	if not cronometro_pausado:
		tiempo_restante -= delta
		
		if tiempo_restante <= 0.0:
			tiempo_restante = 0.0
			actualizar_ui_timer()
			animar_game_over() 
			return
		
	actualizar_ui_timer()
	dibujar_trayectoria() 
	
	if Input.is_action_just_pressed("click_izquierdo"):
		disparar()
	elif Input.is_action_just_pressed("swap"):
		hacer_swap()

func _on_tutorial_completado():
	cronometro_pausado = false 


# ==========================================
# LÓGICA DE FÍSICAS Y EXPLOSIONES
# ==========================================

func explotar_coincidencias(burbuja_inicial):
	var conectadas = {burbuja_inicial: true} 
	var a_revisar = [burbuja_inicial]
	var color_buscado = burbuja_inicial.mi_color
	var todas = get_tree().get_nodes_in_group("burbujas_fijas")
	var limite_distancia = (diametro_burbuja * 1.15)
	var dist_sq = limite_distancia * limite_distancia

	while a_revisar.size() > 0:
		var actual = a_revisar.pop_back()
		for otra in todas:
			if otra.mi_color == color_buscado and not conectadas.has(otra):
				if actual.global_position.distance_squared_to(otra.global_position) <= dist_sq:
					conectadas[otra] = true
					a_revisar.append(otra)

	var array_conectadas = conectadas.keys()
	if array_conectadas.size() >= 3:
		var puntos_explosion = 50 + ((array_conectadas.size() - 3) * 25)
		sumar_puntos(puntos_explosion)
		
		for i in range(array_conectadas.size()):
			var b = array_conectadas[i]
			
			# --- INSTANCIAR EXPLOSIÓN DE PARTÍCULAS ---
			if escena_explosion:
				var explo = escena_explosion.instantiate()
				explo.global_position = b.global_position
				# Le pasamos el color del Sprite2D de la bomba a la explosión
				if b.has_node("Sprite2D"):
					explo.modulate = b.get_node("Sprite2D").modulate
				add_child(explo)
			
			if i == 0: mostrar_texto_flotante(b.global_position, "+50", Color.YELLOW)
			elif i >= 3: mostrar_texto_flotante(b.global_position, "+25", Color.CYAN)
			
			b.remove_from_group("burbujas_fijas")
			b.queue_free()
		
		fallos_consecutivos = 0
		actualizar_ui_fallos()
		limpiar_huerfanas()
		
		if get_tree().get_nodes_in_group("burbujas_fijas").size() == 0:
			animar_victoria()
		else:
			revisar_colores_proyectiles()
	else:
		fallos_consecutivos += 1
		actualizar_ui_fallos()
		if fallos_consecutivos >= MAX_FALLOS:
			agregar_nueva_fila_superior()
			fallos_consecutivos = 0 
			actualizar_ui_fallos() 

# ==========================================
# RESTO DE FUNCIONES (Siguen igual)
# ==========================================

func generar_nivel(radio: float, dist_y: float):
	for f in range(filas):
		var es_impar = (f % 2) != 0
		var num_columnas = columnas - 1 if es_impar else columnas
		var offset_x = radio if es_impar else 0.0
		
		for c in range(num_columnas):
			var b = escena_burbuja.instantiate()
			contenedor.add_child(b)
			var pos_x = (c * diametro_burbuja) + offset_x + radio + margen_lateral_ui
			b.position = Vector2(pos_x, (f * dist_y) + radio + margen_top_ui)
			b.asignar_color(colores.pick_random())
			b.set_physics_process(false)
			b.add_to_group("burbujas_fijas")

func preparar_proyectiles():
	burbuja_cargada = crear_burbuja_en_marcador(pos_carga)
	burbuja_siguiente = crear_burbuja_en_marcador(pos_siguiente)

func crear_burbuja_en_marcador(marcador: Marker2D) -> CharacterBody2D:
	var b = escena_burbuja.instantiate()
	marcador.add_child(b)
	b.position = Vector2.ZERO 
	b.asignar_color(obtener_color_valido())
	b.set_physics_process(false) 
	b.get_node("CollisionShape2D").disabled = true 
	return b

func disparar():
	if !burbuja_cargada: return
	var proyectil = burbuja_cargada
	var pos_inicio = proyectil.global_position
	pos_carga.remove_child(proyectil)
	add_child(proyectil) 
	proyectil.global_position = pos_inicio
	
	var direccion = (get_global_mouse_position() - pos_inicio).normalized()
	proyectil.velocity = direccion * velocidad_disparo
	proyectil.set_physics_process(true)
	proyectil.get_node("CollisionShape2D").disabled = false
	
	burbuja_cargada = burbuja_siguiente
	pos_siguiente.remove_child(burbuja_cargada)
	pos_carga.add_child(burbuja_cargada)
	burbuja_cargada.position = Vector2.ZERO
	burbuja_siguiente = crear_burbuja_en_marcador(pos_siguiente)

func hacer_swap():
	if !burbuja_cargada or !burbuja_siguiente: return
	var color_temp = burbuja_cargada.mi_color
	burbuja_cargada.asignar_color(burbuja_siguiente.mi_color)
	burbuja_siguiente.asignar_color(color_temp)

func dibujar_trayectoria():
	linea_guia.clear_points()
	if not burbuja_cargada: return
	
	var pos_inicio = pos_carga.global_position
	var direccion = (get_global_mouse_position() - pos_inicio).normalized()
	linea_guia.add_point(pos_inicio)
	
	var espacio = get_world_2d().direct_space_state
	var longitud_maxima = 2000
	var parametros = PhysicsRayQueryParameters2D.create(pos_inicio, pos_inicio + (direccion * longitud_maxima))
	var resultado = espacio.intersect_ray(parametros)
	
	if resultado:
		linea_guia.add_point(resultado.position)
		var objeto_chocado = resultado.collider
		if objeto_chocado.is_in_group("paredes"):
			var normal = resultado.normal
			var direccion_rebote = direccion.bounce(normal)
			var pos_rebote = resultado.position
			
			var params_rebote = PhysicsRayQueryParameters2D.create(pos_rebote, pos_rebote + (direccion_rebote * longitud_maxima))
			params_rebote.exclude = [objeto_chocado.get_rid()]
			
			var resultado_rebote = espacio.intersect_ray(params_rebote)
			if resultado_rebote:
				linea_guia.add_point(resultado_rebote.position)
			else:
				linea_guia.add_point(pos_rebote + (direccion_rebote * longitud_maxima))
	else:
		linea_guia.add_point(pos_inicio + (direccion * longitud_maxima))

func encastrar_y_evaluar(burbuja):
	var radio = diametro_burbuja / 2.0
	var dist_y = diametro_burbuja * 0.90
	var pos_y_fila_cero = radio + margen_top_ui 
	var fila_absoluta = int(round((burbuja.position.y - pos_y_fila_cero) / dist_y))
	if fila_absoluta < 0: fila_absoluta = 0
	
	var es_impar = ((techo_es_impar as int + fila_absoluta) % 2) != 0
	var offset_x = radio if es_impar else 0.0
	var columna = int(round((burbuja.position.x - offset_x - radio - margen_lateral_ui) / diametro_burbuja))
	
	var max_columnas_en_esta_fila = (columnas - 1) if es_impar else columnas
	if columna < 0: columna = 0 
	elif columna >= max_columnas_en_esta_fila: columna = max_columnas_en_esta_fila - 1 
	
	var pos_final_x = (columna * diametro_burbuja) + offset_x + radio + margen_lateral_ui
	burbuja.position = Vector2(pos_final_x, (fila_absoluta * dist_y) + pos_y_fila_cero)
	
	remove_child(burbuja)
	contenedor.add_child(burbuja)
	burbuja.add_to_group("burbujas_fijas")
	
	explotar_coincidencias(burbuja)

func limpiar_huerfanas():
	var vivas = get_tree().get_nodes_in_group("burbujas_fijas")
	if vivas.size() == 0: return
	var conectadas_al_techo = {}
	var a_revisar = []
	var radio = diametro_burbuja / 2.0
	var pos_y_fila_cero = radio + margen_top_ui

	for b in vivas:
		if b.global_position.y <= pos_y_fila_cero + 5.0:
			conectadas_al_techo[b] = true
			a_revisar.append(b)

	var limite_distancia = (diametro_burbuja * 1.15)
	var dist_sq = limite_distancia * limite_distancia

	while a_revisar.size() > 0:
		var actual = a_revisar.pop_back()
		for otra in vivas:
			if not conectadas_al_techo.has(otra):
				if actual.global_position.distance_squared_to(otra.global_position) <= dist_sq:
					conectadas_al_techo[otra] = true
					a_revisar.append(otra)

	for b in vivas:
		if not conectadas_al_techo.has(b): hacer_caer(b)

func hacer_caer(burbuja):
	sumar_puntos(20) 
	mostrar_texto_flotante(burbuja.global_position, "+20", Color.GREEN)
	burbuja.remove_from_group("burbujas_fijas")
	burbuja.get_node("CollisionShape2D").set_deferred("disabled", true)
	var tween = create_tween()
	tween.tween_property(burbuja, "global_position", burbuja.global_position + Vector2(0, 800), 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(burbuja.queue_free)

func agregar_nueva_fila_superior():
	var dist_y = diametro_burbuja * 0.866
	var radio = diametro_burbuja / 2.0
	var todas = get_tree().get_nodes_in_group("burbujas_fijas")
	for b in todas: b.position.y += dist_y

	techo_es_impar = !techo_es_impar
	var num_columnas = columnas - 1 if techo_es_impar else columnas
	var offset_x = radio if techo_es_impar else 0.0
	var colores_validos = []
	if todas.size() == 0: colores_validos = colores 
	else:
		var diccionario = {}
		for b in todas: diccionario[b.mi_color] = true
		colores_validos = diccionario.keys()
	
	for c in range(num_columnas):
		var b = escena_burbuja.instantiate()
		contenedor.add_child(b)
		var pos_final_x = (c * diametro_burbuja) + offset_x + radio + margen_lateral_ui
		b.position = Vector2(pos_final_x, radio + margen_top_ui)
		b.asignar_color(colores_validos.pick_random())
		b.set_physics_process(false)
		b.add_to_group("burbujas_fijas")
	
	for b in get_tree().get_nodes_in_group("burbujas_fijas"):
		if (b.global_position.y + radio) >= linea_derrota.global_position.y: 
			animar_game_over()
			break

func actualizar_ui_timer():
	var minutos: int = int(tiempo_restante / 60)
	var segundos: int = int(tiempo_restante) % 60
	if label_timer: 
		label_timer.text = "TIEMPO: %02d:%02d" % [minutos, segundos]
		if tiempo_restante <= 10.0: label_timer.modulate = Color.RED
		else: label_timer.modulate = Color.WHITE

func actualizar_ui_fallos():
	if contenedor_corazones:
		var restantes = MAX_FALLOS - fallos_consecutivos
		var corazones = contenedor_corazones.get_children() 
		for i in range(corazones.size()):
			if i < restantes: corazones[i].modulate = Color.WHITE 
			else: corazones[i].modulate = Color(0.3, 0.3, 0.3, 0.5)

func sumar_puntos(cantidad: int):
	puntaje += cantidad
	label_score.text = "PUNTOS: " + str(puntaje)
	var tween = create_tween() 
	tween.tween_property(label_score, "scale", Vector2(1.5, 1.5), 0.1)
	tween.tween_property(label_score, "scale", Vector2(1.0, 1.0), 0.15)

func mostrar_texto_flotante(posicion: Vector2, texto: String, color_texto: Color):
	var label = Label.new()
	label.text = texto
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.modulate = color_texto
	label.position = posicion - Vector2(25, 20)
	label.z_index = 50
	add_child(label)
	var tween = create_tween()
	tween.set_parallel(true) 
	tween.tween_property(label, "position", label.position - Vector2(0, 60), 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)

func revisar_colores_proyectiles():
	var vivas = get_tree().get_nodes_in_group("burbujas_fijas")
	if vivas.size() == 0: return
	var colores_presentes = {}
	for b in vivas: colores_presentes[b.mi_color] = true
	var colores_validos = colores_presentes.keys()
	if burbuja_cargada and not colores_presentes.has(burbuja_cargada.mi_color):
		burbuja_cargada.asignar_color(colores_validos.pick_random())
	if burbuja_siguiente and not colores_presentes.has(burbuja_siguiente.mi_color):
		burbuja_siguiente.asignar_color(colores_validos.pick_random())

func obtener_color_valido() -> int:
	var vivas = get_tree().get_nodes_in_group("burbujas_fijas")
	if vivas.size() == 0: return colores.pick_random()
	var colores_presentes = {}
	for b in vivas: colores_presentes[b.mi_color] = true
	return colores_presentes.keys().pick_random()

func _on_button_pressed() -> void:
	get_tree().reload_current_scene()

func cargar_leaderboard():
	if FileAccess.file_exists(ARCHIVO_LEADERBOARD):
		var archivo = FileAccess.open(ARCHIVO_LEADERBOARD, FileAccess.READ)
		var json_texto = archivo.get_as_text()
		var json = JSON.new()
		var error = json.parse(json_texto)
		if error == OK:
			puntajes_guardados = json.data
		archivo.close()

func guardar_leaderboard():
	var archivo = FileAccess.open(ARCHIVO_LEADERBOARD, FileAccess.WRITE)
	var json_string = JSON.stringify(puntajes_guardados)
	archivo.store_string(json_string)
	archivo.close()

func mostrar_ui_leaderboard():
	var texto_final = "TOP 5 JUGADORES\n\n"
	for i in range(puntajes_guardados.size()):
		var p = puntajes_guardados[i]
		texto_final += str(i+1) + ". " + str(p["nombre"]) + " | " + str(p["puntos"]) + " PTS | T: " + str(p["tiempo"]) + "s | " + str(p["fecha"]) + "\n"
	
	if label_leaderboard:
		label_leaderboard.text = texto_final
		label_leaderboard.show()

func _on_boton_guardar_pressed():
	var nombre = input_nombre.text.strip_edges()
	if nombre == "": nombre = "Anónimo"
	
	var tiempo_usado = int(tiempo_maximo - tiempo_restante)
	var fecha_dic = Time.get_datetime_dict_from_system()
	
	var dia = "%02d" % fecha_dic.day
	var mes = "%02d" % fecha_dic.month
	var anio = str(fecha_dic.year)
	var hora_24 = fecha_dic.hour
	var minuto = "%02d" % fecha_dic.minute
	var am_pm = "AM"
	var hora_12 = hora_24
	
	if hora_24 >= 12:
		am_pm = "PM"
		if hora_24 > 12: hora_12 -= 12
	if hora_12 == 0: hora_12 = 12
	var hora_str = "%02d" % hora_12
	var fecha_str = dia + "/" + mes + "/" + anio + " " + hora_str + ":" + minuto + " " + am_pm
	
	puntajes_guardados.append({
		"nombre": nombre,
		"puntos": puntaje,
		"tiempo": tiempo_usado,
		"fecha": fecha_str
	})
	
	puntajes_guardados.sort_custom(func(a, b): 
		if a["puntos"] != b["puntos"]: 
			return a["puntos"] > b["puntos"]
		return a["tiempo"] < b["tiempo"]
	)
	
	if puntajes_guardados.size() > 5: puntajes_guardados.resize(5)
	
	guardar_leaderboard()
	
	input_nombre.hide()
	boton_guardar.hide()
	mostrar_ui_leaderboard()
	boton_reintentar.show()

func animar_victoria():
	juego_activo = false 
	if burbuja_cargada: burbuja_cargada.hide()
	if burbuja_siguiente: burbuja_siguiente.hide()
	
	var puntos_bonus = int(tiempo_restante) * 10 
	sumar_puntos(puntos_bonus)
	if label_timer: mostrar_texto_flotante(label_timer.global_position + Vector2(50, 50), "TIME BONUS! +" + str(puntos_bonus), Color.GOLD)
	
	if label_titulo_ui:
		label_titulo_ui.text = "¡GANASTE!"
		label_titulo_ui.modulate = Color.GREEN
		
	await get_tree().create_timer(1.0).timeout 
	
	if input_nombre: input_nombre.show()
	if boton_guardar: boton_guardar.show()
	if boton_reintentar: boton_reintentar.hide()
	
	capa_ui.show()
	linea_guia.hide()

func animar_game_over():
	juego_activo = false 
	if burbuja_cargada: burbuja_cargada.hide()
	if burbuja_siguiente: burbuja_siguiente.hide()
	
	if label_titulo_ui:
		if tiempo_restante <= 0.0: label_titulo_ui.text = "¡TIEMPO AGOTADO!"
		else: label_titulo_ui.text = "FIN DEL JUEGO"
		label_titulo_ui.modulate = Color.RED 
	
	var vivas = get_tree().get_nodes_in_group("burbujas_fijas")
	vivas.sort_custom(func(a, b): return a.position.y > b.position.y)
	
	if vivas.size() > 0:
		var y_actual = vivas[0].position.y 
		for b in vivas:
			if b.position.y < y_actual - 10: 
				y_actual = b.position.y
				await get_tree().create_timer(0.1).timeout 
			b.modulate = Color(0.3, 0.3, 0.3)
		
	await get_tree().create_timer(0.5).timeout
	
	mostrar_ui_leaderboard()
	capa_ui.show()
	linea_guia.hide()
