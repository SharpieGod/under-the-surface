extends Node2D

var _js_callback: JavaScriptObject
var hand_landmarks: Array = []

func _ready():
	if not OS.has_feature("web"):
		push_warning("Hand tracking only works in Web export!")
		return
	_inject_mediapipe_js()
	_setup_callback()

func _inject_mediapipe_js():
	JavaScriptBridge.eval("""
        // Load MediaPipe Hands from CDN
        const script = document.createElement('script');
        script.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/hands/hands.js';
        script.crossOrigin = 'anonymous';
        script.onload = () => { window._mediapipeLoaded = true; initHandTracking(); };
        document.head.appendChild(script);

        const camScript = document.createElement('script');
        camScript.src = 'https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js';
        camScript.crossOrigin = 'anonymous';
        document.head.appendChild(camScript);

        window._handData = null;

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

func _setup_callback():
	# Create a JS callable that GDScript will poll OR use a JS->GD callback
	_js_callback = JavaScriptBridge.create_callback(_on_hand_data)
	JavaScriptBridge.eval("""
        window._godotHandCallback = null;
	""", true)
	# Store reference so JS can call back into Godot
	JavaScriptBridge.get_interface("window")["_godotHandCallback"] = _js_callback

	# Modify the onResults to also call Godot directly
	JavaScriptBridge.eval("""
        window._registerGodotCallback = function() {
            // Called after init — patch onResults to trigger Godot
            window._handDataReady = function(data) {
                if (window._godotHandCallback) {
                    window._godotHandCallback(JSON.stringify(data));
                }
            };
        };
        window._registerGodotCallback();
	""", true)

# Called from JS via the callback
func _on_hand_data(args: Array):
	if args.is_empty():
		return
	var json = JSON.new()
	var result = json.parse(args[0])
	if result == OK:
		hand_landmarks = json.get_data()
		_process_hands()

# Fallback: poll every frame if callback isn't firing
func _process(_delta):
	var raw = JavaScriptBridge.eval("JSON.stringify(window._handData || [])", true)
	if raw == null or raw == "null":
		return
	var json = JSON.new()
	if json.parse(raw) == OK:
		hand_landmarks = json.get_data()
		_process_hands()

func _process_hands():
	for i in range(hand_landmarks.size()):
		var landmarks = hand_landmarks[i]
		# landmarks is an array of 21 points: [{x, y, z}, ...]
		# Landmark 8 = index fingertip, 4 = thumb tip
		var index_tip = landmarks[8]
		var thumb_tip = landmarks[4]
		print("Hand %d — Index: (%.2f, %.2f) | Thumb: (%.2f, %.2f)" % [
			i, index_tip.x, index_tip.y, thumb_tip.x, thumb_tip.y
		])
		# Convert normalized (0-1) to screen coords:
		var screen_pos = Vector2(
			index_tip.x * get_viewport().size.x,
			index_tip.y * get_viewport().size.y
		)
		emit_signal("hand_updated", i, screen_pos)

signal hand_updated(hand_index: int, position: Vector2)
