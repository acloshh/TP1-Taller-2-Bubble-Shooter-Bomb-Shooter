extends GPUParticles2D

func _ready():
	emitting = true # Dispara la explosión
	await finished # Espera a que termine la animación
	queue_free() # Se borra de la memoria
