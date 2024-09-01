extends AspectRatioContainer

@export_range (1, 500) var MilisecondsPerUpdate: int
@export var TimeStats: Label
@export var MemStats: Label
@export var PhysicsTimeStats: Label

const MILISECS_PER_SEC: int = 1000
const MILISECS_TO_SECS: float = 1.0 / MILISECS_PER_SEC
const SECS_PER_MIN: int = 60
const MINS_PER_HOUR: int = 60
const SECS_PER_HOUR: int = (SECS_PER_MIN * MINS_PER_HOUR)

const LOWEST_PCT_RANGE: float = 0.05

var file_buffer: PackedFloat32Array

var accum: float = 0.0

var avg_buffer_idx: int = 0
var TARGET_LOW_FRAME_CT: int = 50
var AVG_BUFFER_SIZE: int = (int)(TARGET_LOW_FRAME_CT / LOWEST_PCT_RANGE)

var avg_buffer: PackedFloat32Array
var lowest_fps: float = 1000.0 * 1000.0
var low_avg_fps: float = 0.0
var lowest_avg_fps: float = 0.0
var trim_avg_fps: float = 0.0

var avg_physics_buffer: PackedFloat32Array
var physics_lowest_fps: float = 1000.0 * 1000.0
var physics_low_avg_fps: float = 0.0
var physics_lowest_avg_fps: float = 0.0
var physics_trim_avg_fps: float = 0.0

const AUTO_FLUSH_MAX: int = 100
var auto_flush_ctr: int = 0

var stat_id: int = randi()
var stat_id_str: String = "%X" % [stat_id]
const file_fmt: String = "res://%s_%s_timingStats.txt"
const time_fmt: String = "%8.2f FPS, %0.2f ms | LOWEST: %0.2f FPS, %0.2f ms | AVERAGE: %8.2f FPS, %0.2f ms | 5%% LOW: %0.2f FPS, %0.2f ms | LOWEST 0.5%%: %0.2f FPS, %0.2f ms"
const mem_fmt: String = "%d Draw Calls | %0.2f MB Alloc, %0.2f MB Used | Video Mem %0.2f Used, Textures %0.2f MB Used, Render Buffer %0.2f MB Used, Misc %0.2f MB Used"
const physics_time_fmt: String = "PHYSICS: %8.2f FPS, %0.2f ms | LOWEST: %0.2f FPS, %0.2f ms | AVERAGE: %8.2f FPS, %0.2f ms | 5%% LOW: %0.2f FPS, %0.2f ms | LOWEST 0.5%%: %0.2f FPS, %0.2f ms"

# Instead of 1% low FPS, we're doing a weighted average on the lowest 5%
func LowestFpsWeightedAverage(low_frames: PackedFloat32Array) -> float:
	var avg: float = 0.0
	var low_frame_ct: float = TARGET_LOW_FRAME_CT
	var half_frame_ct = low_frame_ct / 2
	
	var slowest_frame_weight_proportion = 0.5
	avg += low_frames[0] * slowest_frame_weight_proportion
	
	var slower_frame_weight_proportion = 0.3
	var slower_frame_weight: float = slower_frame_weight_proportion / (half_frame_ct - 1)
	for i in range(1, half_frame_ct):
		avg += low_frames[i] * slower_frame_weight
	
	var slow_frame_weight: float = 1.0 - (slowest_frame_weight_proportion + slower_frame_weight_proportion)
	slow_frame_weight /= half_frame_ct
	for i in range(half_frame_ct, TARGET_LOW_FRAME_CT):
		avg += low_frames[i] * slow_frame_weight
	
	return avg

func Average(trimmed_frames: PackedFloat32Array) -> float:
	var avg: float = 0.0
	for frame_time: float in trimmed_frames:
		avg += frame_time
	return avg / trimmed_frames.size()

func TabulateTimeStats() -> void:
	avg_buffer_idx = 0
	avg_buffer.sort()
	lowest_avg_fps = avg_buffer[0]
	low_avg_fps = LowestFpsWeightedAverage(avg_buffer.slice(0, TARGET_LOW_FRAME_CT))
	trim_avg_fps = Average(avg_buffer.slice(TARGET_LOW_FRAME_CT, (AVG_BUFFER_SIZE - TARGET_LOW_FRAME_CT)))

func TabulatePhysicsTimeStats() -> void:
	avg_buffer_idx = 0
	avg_physics_buffer.sort()
	physics_lowest_fps = avg_physics_buffer[0]
	physics_low_avg_fps = LowestFpsWeightedAverage(avg_physics_buffer.slice(0, TARGET_LOW_FRAME_CT))
	physics_trim_avg_fps = Average(avg_physics_buffer.slice(TARGET_LOW_FRAME_CT, (AVG_BUFFER_SIZE - TARGET_LOW_FRAME_CT)))

func ResetStatCollection() -> void:
	lowest_fps = 10000000000.0
	print("RESET DEBUG STAT COLLECTION")

func CreateStatsFile() -> void:
	var fn: String = file_fmt % [Time.get_date_string_from_system(), stat_id_str]
	var file = FileAccess.open(fn, FileAccess.WRITE_READ)
	var data: String = "%d" % AVG_BUFFER_SIZE
	file.store_line(data)
	file.close()
	
	if (FileAccess.file_exists(fn)):
		print("STATS FILE CREATED: " + fn)
	else:
		printerr("FAILED TO CREATE STATS FILE: " + fn)
		get_tree().quit()

func FlushStatsToFile() -> void:
	var fn: String = file_fmt % [Time.get_date_string_from_system(), stat_id_str]
	
	var file
	if FileAccess.file_exists(fn):
		file = FileAccess.open(fn, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		CreateStatsFile()
		file = FileAccess.open(fn, FileAccess.READ_WRITE)

	var fmt_str: String = "%.2f "
	var data: String = fmt_str % [lowest_fps]
	
	for fps: float in avg_buffer:
		data += fmt_str % [fps]
	
	file.store_line(data)
	file.close()
	
	print("STATS FLUSHED TO FILE: " + fn)

func DisplayMemStats() -> void:
	
	const BYTES_IN_MB: float = 1048576.0
	const BYTES_TO_MB: float = 1.0 / BYTES_IN_MB
	
	var draw_calls: int = ceil(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	
	# Available static memory.
	var static_mem_alloc: float = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
	# Static memory currently used, in bytes.
	var static_mem_used: float = Performance.get_monitor(Performance.MEMORY_STATIC)
	# The amount of video memory used (texture and vertex memory combined, in bytes). Since this metric also includes miscellaneous allocations, this value is always greater than the sum of RENDER_TEXTURE_MEM_USED and RENDER_BUFFER_MEM_USED.
	var total_video_mem_used: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	# The amount of texture memory used (in bytes).
	var tex_mem_used: float = Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED)
	# The amount of render buffer memory used (in bytes).
	var render_buffer_mem_used: float = Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED)
	var misc_gfx_mem_used: float = total_video_mem_used - (tex_mem_used + render_buffer_mem_used)
	
	static_mem_alloc *= BYTES_TO_MB
	static_mem_used *= BYTES_TO_MB
	total_video_mem_used *= BYTES_TO_MB
	tex_mem_used *= BYTES_TO_MB
	render_buffer_mem_used *= BYTES_TO_MB
	misc_gfx_mem_used *= BYTES_TO_MB
	var final_str = mem_fmt % [draw_calls, 
							static_mem_alloc, static_mem_used, 
							total_video_mem_used, tex_mem_used, render_buffer_mem_used, misc_gfx_mem_used]
	MemStats.text = final_str

func DisplayTimeStats() -> void:
	var delta: float = Performance.get_monitor(Performance.TIME_PROCESS)
	var fps: float = 1.0 / delta
	var ms_per_frame: float = 1000.0 * delta
	var lowest_ms_per_frame: float = 1000.0 / lowest_fps
	var trim_ms_per_frame: float = 1000.0 / trim_avg_fps
	var low_avg_ms_per_frame: float = 1000.0 / low_avg_fps
	var lowest_avg_ms_per_frame: float = 1000.0 / lowest_avg_fps
	
	var final_str = time_fmt % [fps, ms_per_frame,
							 lowest_fps, lowest_ms_per_frame,
							 trim_avg_fps, trim_ms_per_frame,
							 low_avg_fps, low_avg_ms_per_frame,
							 lowest_avg_fps, lowest_avg_ms_per_frame]
	TimeStats.text = final_str

func DisplayPhysicsTimeStats() -> void:
	var delta: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
	if (delta <= 0.000001): 
		PhysicsTimeStats.text = "PHYSICS: No Physics simulated this frame."
	
	var fps: float = 1.0 / delta
	var ms_per_frame: float = 1000.0 * delta
	var lowest_ms_per_frame: float = 1000.0 / lowest_fps
	var trim_ms_per_frame: float = 1000.0 / trim_avg_fps
	var low_avg_ms_per_frame: float = 1000.0 / low_avg_fps
	var lowest_avg_ms_per_frame: float = 1000.0 / lowest_avg_fps
	
	var final_str = time_fmt % [fps, ms_per_frame,
							 lowest_fps, lowest_ms_per_frame,
							 trim_avg_fps, trim_ms_per_frame,
							 low_avg_fps, low_avg_ms_per_frame,
							 lowest_avg_fps, lowest_avg_ms_per_frame]
	PhysicsTimeStats.text = final_str

func _ready() -> void:
	TimeStats.text = ""
	MemStats.text = ""
	PhysicsTimeStats.text = ""
	
	avg_buffer.resize(AVG_BUFFER_SIZE)
	avg_physics_buffer.resize(AVG_BUFFER_SIZE)
	accum = -1.0
	
	CreateStatsFile()

func _input(event):
	# Ctrl+Del
	if event.is_action_pressed("ui_text_delete_word"):
		ResetStatCollection()

func _process(delta: float) -> void:
	
	accum += delta
	if (accum < 0.0):
		return

	var fps: float = 1.0 / delta
	avg_buffer[avg_buffer_idx] = fps
	avg_buffer_idx += 1
	lowest_fps = fps if fps < lowest_fps else lowest_fps
	
	if (avg_buffer_idx >= AVG_BUFFER_SIZE):
		TabulateTimeStats()
		TabulatePhysicsTimeStats()
		
		auto_flush_ctr += 1
		if (auto_flush_ctr >= AUTO_FLUSH_MAX):
			FlushStatsToFile()
			auto_flush_ctr = 0
	
	var update_threshold = MilisecondsPerUpdate * MILISECS_TO_SECS
	if (accum >= update_threshold):
		DisplayTimeStats()
		DisplayMemStats()
		DisplayPhysicsTimeStats()
		accum = 0.0

func _physics_process(delta: float) -> void:
	
	if (accum < 0.0):
		return
	
	var fps: float = 1.0 / delta
	physics_lowest_fps = fps if fps < physics_lowest_fps else physics_lowest_fps
	avg_physics_buffer[avg_buffer_idx] = fps
