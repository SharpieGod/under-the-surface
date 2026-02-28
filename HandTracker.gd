extends Node

signal hand_updated(hand_index: int, position: Vector2, is_closed: bool)
signal hand_lost(hand_index: int)

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
            videoEl.style.display = 'none';
            document.body.appendChild(videoEl);

            const hands = new Hands({
                locateFile: (file) =>
                    `https://cdn.jsdelivr.net/npm/@mediapipe/hands/${file}`
            });

            hands.setOptions({
                maxNumHands: 2,
                modelComplexity: 1,
                minDetectionConfidence: 0.7,
                minTrackingConfidence: 0.5
            });

            hands.onResults((results) => {
                window._handData = results.multiHandLandmarks || [];
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

	var prev_count = hand_landmarks.size()
	_last_raw = raw

	var json = JSON.new()
	if json.parse(raw) != OK:
		return

	hand_landmarks = json.get_data()

	for i in range(hand_landmarks.size(), prev_count):
		emit_signal("hand_lost", i)

	_process_hands()

func _process_hands():
	for i in range(hand_landmarks.size()):
		var landmarks = hand_landmarks[i]
		var index_tip = landmarks[8]

		var screen_pos = Vector2(
			index_tip.x * get_viewport().size.x,
			index_tip.y * get_viewport().size.y
		)

		var closed = _is_hand_closed(landmarks)
		emit_signal("hand_updated", i, screen_pos, closed)

# Checks how many fingers are curled.
# For each finger (index, middle, ring, pinky):
#   if the fingertip Y is BELOW its PIP knuckle Y, the finger is curled.
#   (Y increases downward in MediaPipe normalized coords)
# If 3 or more fingers are curled, the hand is considered closed.
func _is_hand_closed(landmarks: Array) -> bool:
	# [tip_index, pip_index] for each of the 4 fingers
	var finger_pairs = [
		[8,  6],   # Index:  tip, PIP
		[12, 10],  # Middle: tip, PIP
		[16, 14],  # Ring:   tip, PIP
		[20, 18],  # Pinky:  tip, PIP
	]

	var curled_count = 0
	for pair in finger_pairs:
		var tip = landmarks[pair[0]]
		var pip = landmarks[pair[1]]
		if tip.y > pip.y:
			curled_count += 1

	return curled_count >= 3
