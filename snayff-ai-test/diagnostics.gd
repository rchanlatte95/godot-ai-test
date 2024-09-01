extends AspectRatioContainer

@export var TimeStats: Label
@export var MemStats: Label
@export_range(5, 30) var MinutesToTrack: int

const MAX_FPS: int = 999
const TARGET_FPS: int = 72
const MILISECS_PER_SEC: int = 1000
const SECS_PER_MIN: int = 60
const MINS_PER_HOUR: int = 60
const SECS_PER_HOUR: int = (SECS_PER_MIN * MINS_PER_HOUR)

const MAX_FRAMES_PER_MIN: int = (MAX_FPS * SECS_PER_MIN)
const MAX_FRAMES_PER_HOUR: int = (MAX_FPS * SECS_PER_HOUR)

const LOWEST_PCT_RANGE: float = 0.05

var file_buffer: PackedFloat32Array

var avg_buffer_idx: int = 0
var TARGET_LOW_FRAME_CT: int = 16
var AVG_BUFFER_SIZE: int = (int)(TARGET_LOW_FRAME_CT / LOWEST_PCT_RANGE)
var avg_buffer: PackedFloat32Array
var lowest_fps: float = 1000.0 * 1000.0
var accum: float = 0.0
var low_avg_fps: float = 0.0
var lowest_avg_fps: float = 0.0
var trim_avg_fps: float = 0.0

const AUTO_FLUSH_MAX: int = 10
var auto_flush_ctr: int = 0

var stat_id: int = randi()
var stat_id_str: String = "%X" % [stat_id]
const file_fmt: String = "res://%s_%s_timingStats.txt"
const fps_fmt: String = "%8.2f FPS | LOWEST: %0.2f FPS | AVERAGE: %8.2f FPS | 5%% LOW: %0.2f FPS | LOWEST 0.5%%: %0.2f FPS"
const ms_fmt: String = "%0.2f ms | LOWEST: %0.2f ms | AVERAGE: %0.2f ms | 5%% LOW: %0.2f ms | LOWEST 0.5%%: %0.2f ms"

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

func ResetStatCollection() -> void:
	lowest_fps = 10000000000.0
	print("RESET DEBUG STAT COLLECTION")

func FlushStatsToFile() -> void:
	var fn: String = file_fmt % [Time.get_date_string_from_system(), stat_id_str]
	
	var file
	if FileAccess.file_exists(fn):
		file = FileAccess.open(fn, FileAccess.READ_WRITE)
		file.seek_end()
	else:
		file = FileAccess.open(fn, FileAccess.WRITE_READ)

	var fmt_str: String = "%.3f "
	var data: String = fmt_str % [lowest_fps]
	
	for fps: float in avg_buffer:
		data += fmt_str % [fps]
	
	file.store_line(data)
	file.close()
	
	print("STATS FLUSHED TO FILE!")

func _ready() -> void:
	TimeStats.text = ""
	MemStats.text = ""
	
	avg_buffer.resize(AVG_BUFFER_SIZE)
	
	var file_buffer_sz: int = MinutesToTrack * SECS_PER_MIN
	file_buffer.resize(file_buffer_sz)
	
	accum = -1.0

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
		
		auto_flush_ctr += 1
		if (auto_flush_ctr >= AUTO_FLUSH_MAX):
			FlushStatsToFile()
			auto_flush_ctr = 0
	
	if (accum >= 0.08333):
		var fps_str = fps_fmt % [fps, lowest_fps, trim_avg_fps, low_avg_fps, lowest_avg_fps]
		
		var ms_per_frame: float = 1000.0 / fps
		var lowest_ms_per_frame: float = 1000.0 / lowest_fps
		var trim_ms_per_frame: float = 1000.0 / trim_avg_fps
		var low_avg_ms_per_frame: float = 1000.0 / low_avg_fps
		var lowest_avg_ms_per_frame: float = 1000.0 / lowest_avg_fps
		var ms_str = ms_fmt % [ms_per_frame, lowest_ms_per_frame, trim_ms_per_frame, low_avg_ms_per_frame, lowest_avg_ms_per_frame]
		var final_str = fps_str + " | " + ms_str
		TimeStats.text = final_str
		accum = 0.0
