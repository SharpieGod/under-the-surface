extends Node

signal hand_updated(is_left: bool, position: Vector2, is_closed: bool)
signal hand_lost(is_left: bool)

var hand_landmarks: Array = []
var _last_raw: String = ""

func _ready():
	if not OS.has_feature("web"):
		push_warning("Hand tracking only works in Web export!")
		return
	_inject_mediapipe_js()

func _inject_mediapipe_js():
	JavaScriptBridge.eval("""
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js';
        script.crossOrigin = 'anonymous';
        script.onload = () => { initHandTracking(); };
        document.head.appendChild(script);

        const camScript = document.createElement('script');
        camScript.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js';
        camScript.crossOrigin = 'anonymous';
        document.head.appendChild(camScript);

        window._handData = [];

        window.initHandTracking = function() {
            const videoEl = document.createElement('video');
			videoEl.style.display = 'none'
            document.body.appendChild(videoEl);

            const hands = new Hands({
                locateFile: (file) =>
                    `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`
            });

            hands.setOptions({
                maxNumHands: 2,
                modelComplexity: 1,
                minDetectionConfidence: 0.85,
                minTrackingConfidence: 0.8
            });

            hands.onResults((results) => {
                const landmarks = results.multiHandLandmarks || [];
                const handedness = results.multiHandedness || [];
                window._handData = landmarks.map((lm, i) => ({
                    landmarks: lm,
                    isLeft: handedness[i]?.label === "Left"
                }));
            });

            navigator.mediaDevices.getUserMedia({ video: true }).then((stream) => {
                videoEl.srcObject = stream;
                videoEl.play();

                const camera = new Camera(videoEl, {
                    onFrame: async () => { await hands.send({ image: videoEl }); },
                    width: 640,
                    height: 480
                });
                camera.start();
            });
        };
	""", true)

func _process(_delta):
	if not OS.has_feature("web"):
		return

	var raw = JavaScriptBridge.eval("JSON.stringify(window._handData || [])", true)
	if raw == null or raw == "null" or raw == _last_raw:
		return

	var prev_hands = hand_landmarks.duplicate()
	_last_raw = raw

	var json = JSON.new()
	if json.parse(raw) != OK:
		return

	hand_landmarks = json.get_data()

	var prev_lefts = prev_hands.filter(func(h): return h.isLeft)
	var prev_rights = prev_hands.filter(func(h): return not h.isLeft)
	var cur_lefts = hand_landmarks.filter(func(h): return h.isLeft)
	var cur_rights = hand_landmarks.filter(func(h): return not h.isLeft)

	if prev_lefts.size() > 0 and cur_lefts.size() == 0:
		emit_signal("hand_lost", true)
	if prev_rights.size() > 0 and cur_rights.size() == 0:
		emit_signal("hand_lost", false)

	_process_hands()

func _process_hands():
	for entry in hand_landmarks:
		var landmarks = entry.landmarks
		var is_left: bool = entry.isLeft
		var index_tip = landmarks[8]

		var screen_pos = Vector2(
			index_tip.x * get_viewport().size.x,
			index_tip.y * get_viewport().size.y
		)

		var closed = _is_hand_closed(landmarks)
		emit_signal("hand_updated", is_left, screen_pos, closed)

func _is_hand_closed(landmarks: Array) -> bool:
	var finger_pairs = [
		[8,  6],
		[12, 10],
		[16, 14],
		[20, 18],
	]
	var curled_count = 0
	for pair in finger_pairs:
		var tip = landmarks[pair[0]]
		var pip = landmarks[pair[1]]
		if tip.y > pip.y:
			curled_count += 1
	return curled_count >= 3
