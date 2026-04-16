extends CharacterBody2D

# 1. Definimos los colores posibles
enum ColorBurbuja {ROJO, AZUL, VERDE, AMARILLO, ROSA, NARANJA}

# 2. Variable exportada para elegir el color desde el panel derecho
@export var mi_color: ColorBurbuja = ColorBurbuja.ROJO
@onready var simbolo_daltonico = $SimboloDaltonico

# 3. Nuestro diccionario de colores bien vibrantes
var paleta = {
	ColorBurbuja.ROJO: Color.RED,
	ColorBurbuja.AZUL: Color.BLUE,
	ColorBurbuja.VERDE: Color.GREEN,
	ColorBurbuja.AMARILLO: Color.YELLOW,
	ColorBurbuja.ROSA: Color.PINK,
	ColorBurbuja.NARANJA: Color.ORANGE
}

# 4. Agarramos las referencias a los dos sprites
@onready var sprite_base = $SpriteBase

func _ready():
	# Ni bien aparece en la pantalla, se pinta
	asignar_color(mi_color)

func asignar_color(nuevo_color_id):
	mi_color = nuevo_color_id
	$SpriteBase.modulate = paleta[mi_color] # Tu código actual
	
	# Le asignamos el dibujito correspondiente
	if texturas_simbolos.has(mi_color):
		simbolo_daltonico.texture = texturas_simbolos[mi_color]

# Esta función la llamaremos desde el Mundo
func alternar_modo_daltonico(activado: bool):
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

var texturas_simbolos = {
	0: preload("res://assets/daltonicos/triangulo.png"),
	1: preload("res://assets/daltonicos/cuadrado.png"),
	2: preload("res://assets/daltonicos/rayo.png"),
	3: preload("res://assets/daltonicos/circulo.png"),
	4: preload("res://assets/daltonicos/corazon.png"),
	5: preload("res://assets/daltonicos/estrella.png")
}
