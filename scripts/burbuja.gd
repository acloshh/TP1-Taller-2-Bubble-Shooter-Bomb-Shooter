extends CharacterBody2D

# 1. Definimos los colores posibles y le asignamos los números de los poderes
enum ColorBurbuja {
	ROJO = 0, 
	AZUL = 1, 
	VERDE = 2, 
	AMARILLO = 3, 
	ROSA = 4, 
	NARANJA = 5, 
	BOMBA = 10,  # <-- Nuestro poder de área
	LASER = 11   # <-- Nuestro poder de fila
}

# 2. Variable exportada para elegir el color (ahora usamos 'int' para mayor flexibilidad)
@export var mi_color: int = ColorBurbuja.ROJO

@onready var simbolo_daltonico = $SimboloDaltonico
@onready var sprite_base = $SpriteBase

# 3. Nuestro diccionario de colores bien vibrantes (incluyendo los poderes)
var paleta = {
	ColorBurbuja.ROJO: Color.RED,
	ColorBurbuja.AZUL: Color.BLUE,
	ColorBurbuja.VERDE: Color.GREEN,
	ColorBurbuja.AMARILLO: Color.YELLOW,
	ColorBurbuja.ROSA: Color.PINK,
	ColorBurbuja.NARANJA: Color.ORANGE,
	ColorBurbuja.BOMBA: Color.BLACK,   # La bomba se verá Negra
	ColorBurbuja.LASER: Color.WHITE    # El láser se verá Blanco (o podés poner Color.CYAN)
}

# 4. Diccionario de símbolos para daltónicos
var texturas_simbolos = {
	ColorBurbuja.ROJO: preload("res://assets/daltonicos/triangulo.png"),
	ColorBurbuja.AZUL: preload("res://assets/daltonicos/cuadrado.png"),
	ColorBurbuja.VERDE: preload("res://assets/daltonicos/rayo.png"),
	ColorBurbuja.AMARILLO: preload("res://assets/daltonicos/circulo.png"),
	ColorBurbuja.ROSA: preload("res://assets/daltonicos/corazon.png"),
	ColorBurbuja.NARANJA: preload("res://assets/daltonicos/estrella.png")
	# Nota: No le ponemos textura a los poderes para que queden lisos, 
	# o podés agregarles un iconito de calavera/rayo después si querés.
}


func _ready():
	# Ni bien aparece en la pantalla, se pinta
	asignar_color(mi_color)

func asignar_color(nuevo_color_id):
	mi_color = nuevo_color_id
	
	# Pintamos el sprite (verificamos que el color exista en la paleta por las dudas)
	if paleta.has(mi_color):
		sprite_base.modulate = paleta[mi_color] 
	
	# Le asignamos el dibujito correspondiente
	if simbolo_daltonico:
		if texturas_simbolos.has(mi_color):
			simbolo_daltonico.texture = texturas_simbolos[mi_color]
		else:
			# Si es un poder (10 u 11), borramos el símbolo para que no quede el del color anterior
			simbolo_daltonico.texture = null 

# Esta función la llamaremos desde el Mundo
func alternar_modo_daltonico(activado: bool):
	if simbolo_daltonico:
		simbolo_daltonico.visible = activado

func _physics_process(delta):
	var colision = move_and_collide(velocity * delta)
	
	if colision:
		var objeto_chocado = colision.get_collider()
		
		# Si toca una pared lateral, rebota
		if objeto_chocado.is_in_group("paredes"):
			velocity.x = -velocity.x
			
		# Si toca el techo u otra burbuja
		elif objeto_chocado.is_in_group("techo") or objeto_chocado.is_in_group("burbujas_fijas"):
			# ¡Frenado de emergencia absoluto!
			velocity = Vector2.ZERO
			set_physics_process(false)
			
			# Le avisa al mundo que se pegó
			get_parent().encastrar_y_evaluar(self)
