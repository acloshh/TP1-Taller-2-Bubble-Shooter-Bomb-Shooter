extends Label

func _process(_delta):
	# 1. Obtenemos los FPS actuales
	var fps = Engine.get_frames_per_second()
	
	# 2. Obtenemos la memoria RAM en MB
	var memoria_mb = OS.get_static_memory_usage() / 1048576.0 
	
	# 3. ¡NUEVO! Obtenemos el tiempo de proceso del CPU
	# Esto devuelve el tiempo en segundos, así que lo multiplicamos por 1000 para tener milisegundos (ms)
	var tiempo_cpu = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	
	# 4. Actualizamos el texto en pantalla sumando la nueva línea de CPU
	text = "FPS: %d\nRAM: %.2f MB\nCPU: %.2f ms" % [fps, memoria_mb, tiempo_cpu]
	
	# Cambiamos el color según la salud del juego
	if fps >= 60:
		modulate = Color.GREEN # Todo joya (CPU tardando menos de 16.6ms)
	elif fps >= 30:
		modulate = Color.YELLOW # Ojo, bajando (CPU tardando más de 16.6ms)
	else:
		modulate = Color.RED # ¡Se traba! (CPU tardando más de 33.3ms)
