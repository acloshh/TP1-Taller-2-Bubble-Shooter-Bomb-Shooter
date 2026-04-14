extends AnimatedSprite2D

func _ready():
	# Asegurate de que la animación se llame "default", 
	# o cambiá este texto por el nombre que le hayas puesto.
	play("default") 
	
	# Esperamos a que la animación termine su ciclo
	await animation_finished 
	
	# La borramos de la memoria
	queue_free()
