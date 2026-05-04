extends CanvasLayer

signal arrancar_reloj # <--- 1. SEÑAL RENOMBRADA PARA QUE TENGA SENTIDO

@onready var fondo_gris = $ColorRect 
@onready var texto_instruccion = $TextoTutorial 
@onready var imagen_mouse = $ImagenMouse 

var icono_mover = preload("res://assets/mouse/mouse movimiento.png")
var icono_clic_izquierdo = preload("res://assets/mouse/mouse click izq.png")
var icono_clic_derecho = preload("res://assets/mouse/mouse click der.png")

var paso_actual: int = 1

func _ready():
	iniciar_paso_1()

# --- FUNCIONES DE CADA PASO ---

func iniciar_paso_1():
	paso_actual = 1
	texto_instruccion.text = "Mueve el mouse\npara APUNTAR"
	imagen_mouse.texture = icono_mover 

func iniciar_paso_2():
	paso_actual = 2
	texto_instruccion.text = "Haz clic izquierdo\npara DISPARAR"
	imagen_mouse.texture = icono_clic_izquierdo 
	fondo_gris.hide() 

func iniciar_paso_3():
	paso_actual = 3
	texto_instruccion.text = "Haz clic derecho\npara CAMBIAR BOMBA"
	imagen_mouse.texture = icono_clic_derecho 
	arrancar_reloj.emit()

func finalizar_tutorial():
	paso_actual = 4
	hide() 



func _input(event):
	if paso_actual >= 4:
		return
		
	match paso_actual:
		1:
			if event is InputEventMouseMotion and event.relative.length() > 10:
				iniciar_paso_2()
		2:
			if event.is_action_pressed("click_izquierdo"):
				iniciar_paso_3()
		3:
			if event.is_action_pressed("swap"):
				finalizar_tutorial()
