extends CharacterBody2D

# 1. Definimos los colores posibles
enum ColorBurbuja {ROJO, AZUL, VERDE, AMARILLO, ROSA, NARANJA}

# 2. Variable exportada para elegir el color desde el panel derecho
@export var mi_color: ColorBurbuja = ColorBurbuja.ROJO

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

func asignar_color(nuevo_color):
	mi_color = nuevo_color
	
	# ¡ACÁ ESTÁ LA MAGIA!
	# Solo teñimos la base blanca. El brillo queda intacto.
	sprite_base.modulate = paleta[mi_color]

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
