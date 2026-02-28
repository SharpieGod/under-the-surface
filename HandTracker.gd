extends Node

var _js_callback: JavaScriptObject
var hand_landmarks: Array = []

signal hand_updated(hand_index: int, position: Vector2, gesture: String, label: String)

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
        script.onload = () => initHandTracking();
        document.head.appendChild(script);

        const camScript = document.createElement('script');
        camScript.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js';
        camScript.crossOrigin = 'anonymous';
        document.head.appendChild(camScript);

        window._handData = [];

        function detectGesture(landmarks) {
            // Finger tip ids: thumb=4, index=8, middle=12, ring=16, pinky=20
            // Finger pip ids: thumb=3, index=6, middle=10, ring=14, pinky=18
            const tips = [8, 12, 16, 20];
            const pips = [6, 10, 14, 18];
            let extendedCount = 0;
            for (let i = 0; i < tips.length; i++) {
                if (landmarks[tips[i]].y < landmarks[pips[i]].y) extendedCount++;
            }
            // Thumb: compare x instead of y
            const thumbExtended = landmarks[4].x < landmarks[3].x;
            if (thumbExtended) extendedCount++;
            if (extendedCount >= 4) return 'palm';
            if (extendedCount <= 1) return 'fist';
            return 'other';
        }

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
                const data = [];
                if (results.multiHandLandmarks && results.multiHandedness) {
                    for (let i = 0; i < results.multiHandLandmarks.length; i++) {
                        const lm = results.multiHandLandmarks[i];
                        data.push({
                            label: results.multiHandedness[i].classification[0].label,
                            gesture: detectGesture(lm),
                            wrist: lm[0],
                            index_tip: lm[8],
                            thumb_tip: lm[4]
                        });
                    }
                }
                window._handData = data;
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
	var raw = JavaScriptBridge.eval("JSON.stringify(window._handData || [])", true)
	if raw == null or raw == "null" or raw == "[]":
		return
	var json = JSON.new()
	if json.parse(raw) == OK:
		hand_landmarks = json.get_data()
		_process_hands()

func _process_hands():
	var viewport_size = get_viewport().size
	for i in range(hand_landmarks.size()):
		var hand = hand_landmarks[i]
		var wrist = hand["wrist"]
		var gesture: String = hand["gesture"]
		var label: String = hand["label"]  # "Left" or "Right"
		var screen_pos = Vector2(
			wrist["x"] * viewport_size.x,
			wrist["y"] * viewport_size.y
		)
		emit_signal("hand_updated", i, screen_pos, gesture, label)
