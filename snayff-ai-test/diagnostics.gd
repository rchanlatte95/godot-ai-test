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

var fps_fmt = "%10.3f FPS | LOWEST: %6.3f FPS | AVERAGE: %10.3f FPS | 5%% LOW: %6.3f FPS | LOWEST 0.5%%: %6.3f FPS"
var ms_fmt = "%10.3f ms  | LOWEST: %6.3f ms  | AVERAGE: %10.3f ms  | 5%% LOW: %6.3f ms  | LOWEST 0.5%%: %6.3f ms "

# Instead of 1% low FPS, we're doing a weighted average on the lowest 5%
func CalculateLowestFPSWeightedAverage(low_frames: PackedFloat32Array) -> float:
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

func CalculateTrimmedFpsAverage(trimmed_frames: PackedFloat32Array) -> float:
	var avg: float = 0.0
	for frame_time: float in trimmed_frames:
		avg += frame_time
	return avg / trimmed_frames.size()

func TabulateTimeStats() -> void:
	avg_buffer_idx = 0
	avg_buffer.sort()
	lowest_avg_fps = avg_buffer[0]
	low_avg_fps = CalculateLowestFPSWeightedAverage(avg_buffer.slice(0, TARGET_LOW_FRAME_CT))
	trim_avg_fps = CalculateTrimmedFpsAverage(avg_buffer.slice(TARGET_LOW_FRAME_CT, (AVG_BUFFER_SIZE - TARGET_LOW_FRAME_CT)))
	avg_buffer.fill(0.0)

func ResetStatCollection() -> void:
	lowest_fps = 10000000000.0
	print("RESET DEBUG STAT COLLECTION")

func _ready() -> void:
	TimeStats.text = ""
	MemStats.text = ""
	
	avg_buffer.resize(AVG_BUFFER_SIZE)
	
	var file_buffer_sz: int = MinutesToTrack * SECS_PER_MIN
	file_buffer.resize(file_buffer_sz)

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
	avg_buffer_idx = avg_buffer_idx + 1
	lowest_fps = fps if fps < lowest_fps else lowest_fps
	
	if (avg_buffer_idx >= AVG_BUFFER_SIZE):
		TabulateTimeStats()
	
	if (accum >= 0.08333):
		var fps_str = fps_fmt % [fps, lowest_fps, trim_avg_fps, low_avg_fps, lowest_avg_fps]
		
		var ms_per_frame: float = 1000.0 / fps
		var lowest_ms_per_frame: float = 1000.0 / lowest_fps
		var trim_ms_per_frame: float = 1000.0 / trim_avg_fps
		var low_avg_ms_per_frame: float = 1000.0 / low_avg_fps
		var lowest_avg_ms_per_frame: float = 1000.0 / lowest_avg_fps
		var ms_str = ms_fmt % [ms_per_frame, lowest_ms_per_frame, trim_ms_per_frame, low_avg_ms_per_frame, lowest_avg_ms_per_frame]
		var final_str = fps_str + '\n' + ms_str
		TimeStats.text = final_str
		accum = 0.0
