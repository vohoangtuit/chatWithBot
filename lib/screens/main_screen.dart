import 'dart:io';

import 'package:camera/camera.dart';
import 'package:chat_bot_ai/model/chat_model.dart';
import 'package:chat_bot_ai/screens/general/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:rive/rive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends BaseScreen<MainScreen> {
  // ==========================================
  // 1. KHAI BÁO BIẾN
  // ==========================================

  // --- Rive & TTS ---
  late final fileLoader = FileLoader.fromAsset("assets/robot/robot_ai.riv", riveFactory: Factory.rive);
  late FlutterTts _tts;

  // --- STT & Hội thoại ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isConversing = false; // Đánh dấu đang trong cuộc hội thoại
  String _currentWords = ""; // Lưu câu khách đang nói
  // BIẾN MỚI: Cuốn sổ lưu lịch sử trò chuyện
  final List<Map<String, String>> _chatHistory = [];

  // --- Camera & ML Kit ---
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  bool _isBusy = false;
  bool _hasGreeted = false;
  DateTime? _firstSeenTime;
  DateTime? _lastSeenTime;

  // ==========================================
  // 2. KHỞI TẠO VÀ HỦY (INIT & DISPOSE)
  // ==========================================

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _setupTts();
    _initSpeech(); // Khởi tạo Micro
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _faceDetector.close();
    _speech.cancel(); // Hủy nghe
    _tts.stop();
    super.dispose();
  }

  // ==========================================
  // 3. CẤU HÌNH PHẦN CỨNG (CAMERA, TTS, STT)
  // ==========================================

  Future<void> _setupTts() async {
    await _tts.setLanguage("vi-VN");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    // BẮT BUỘC: Đợi AI đọc xong 100% thì mới nhả hàm (Tránh việc Micro thu lại tiếng AI)
    await _tts.awaitSpeakCompletion(true);
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        logI("Micro status: $status");
        // Khi nhận diện khoảng lặng (pauseFor), status sẽ chuyển thành 'done'
        if (status == 'done' && _currentWords.isNotEmpty && _isConversing) {
          // ĐÂY MỚI LÀ LÚC GỬI API LÊN FIREBASE
          _sendToFirebase(_currentWords); // Gửi câu hoàn chỉnh lên Cloud
        }
      },
      onError: (val) => logI('Lỗi Micro: $val'),
    );
    if (!available) logI("Thiết bị không hỗ trợ nhận diện giọng nói");
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Tìm Camera Trước (Front/Selfie)
    final frontCamera = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    // Cài đặt Controller (Thêm imageFormatGroup chuẩn để ML Kit không lỗi)
    _cameraController = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: true,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _cameraController!.initialize();

    if (mounted) {
      setState(() {
        _isCameraInitialized = true;
      });
      // Bắt đầu đẩy hình ảnh qua cho AI quét
      _cameraController!.startImageStream(_processCameraImage);
    }
  }

  // ==========================================
  // 4. LOGIC HỘI THOẠI (AI CLOUD & GIỌNG NÓI)
  // ==========================================

  Future<void> _startListening() async {
    if (!_isConversing) return; // Nếu khách bỏ đi rồi thì không nghe nữa

    _currentWords = ""; // Reset câu cũ
    await _speech.listen(
      onResult: (result) {
        _currentWords = result.recognizedWords;
      },
      localeId: "vi_VN",
      pauseFor: const Duration(milliseconds: 2500), // Khách ngừng nói 2.5s -> Chốt câu
    );
    logI("🎤 Bắt đầu nghe...");
  }

  Future<void> _sendToFirebase(String userText) async {
    if (!_isConversing) return;

    await _speech.stop(); // Khóa Micro lại khi đang xử lý
    logI("🗣️ Khách nói: $userText");
    ChatModel data = ChatModel(
      text: userText,

    );
    await cloudClient.chatWithAi(data).then((response)async{
      String reply = '';
      if(response!=null){
        reply = response.reply!;
        logI("🤖 AI trả lời: ${response.reply}");
        if(response.success!=null&& response.success!){
       // NẾU THÀNH CÔNG -> GHI VÀO SỔ LỊCH SỬ CHO LẦN SAU
          _chatHistory.add({'role': 'user', 'text': userText});
          _chatHistory.add({'role': 'model', 'text': reply});
        }
      }else{
        reply = "Dạ em bị lỗi kết nối ạ.";
      }

      // 2. KIỂM TRA LỜI TẠM BIỆT
      if (reply.contains("[END_CONVERSATION]")) {
        reply = reply.replaceAll("[END_CONVERSATION]", "").trim();
        await _speak(reply); // Đọc câu tạm biệt
        _resetSystem(fullReset: true); // Kết thúc cuộc gọi
        return;
      }

      // 3. ĐỌC CÂU TRẢ LỜI & LẶP LẠI
      await _speak(reply);

      if (_isConversing) {
        _startListening(); // Đọc xong tự động mở Mic nghe tiếp
      }
    });

  }

  Future<void> _speak(String text) async {
    logI("🤖 AI nói: $text");
    // [GỢI Ý] Kích hoạt Rive nhép môi ở đây nếu anh muốn
    // _riveController?.stateMachine?.boolean('isTalking')?.value = true;

    await _tts.speak(text); // Sẽ dừng ở dòng này cho đến khi AI đọc xong chữ cuối

    // [GỢI Ý] Tắt Rive nhép môi ở đây
    // _riveController?.stateMachine?.boolean('isTalking')?.value = false;
  }

  void _resetSystem({required bool fullReset}) {
    _speech.stop();
    _tts.stop();
    _isConversing = false;
    _hasGreeted = false;
    _firstSeenTime = null;
    if (fullReset) _lastSeenTime = null;
    // BIẾN MỚI: Xóa trí nhớ khi khách đi mất
    _chatHistory.clear();
    logI("🔄 Đã reset luồng hội thoại.");
  }

  // ==========================================
  // 5. LOGIC THỊ GIÁC (AI VISION - ML KIT)
  // ==========================================

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final inputImage = _createInputImage(image);
      if (inputImage != null) {
        final faces = await _faceDetector.processImage(inputImage);
        final now = DateTime.now();

        if (faces.isNotEmpty) {
          _lastSeenTime = now;

          if (_firstSeenTime == null) {
            _firstSeenTime = now;
            logI("🤖 AI: Có người! Đang đếm giây...");
          } else {
            final secondsLooked = now.difference(_firstSeenTime!).inSeconds;

            // KÍCH HOẠT LỜI CHÀO VÀ BẮT ĐẦU HỘI THOẠI
            if (secondsLooked >= 5 && !_hasGreeted) {
              _hasGreeted = true;
              _isConversing = true; // Bật cờ hội thoại
              logI("🤖 AI: Khách đứng đủ 5s. Tiến hành chào!");

              await _speak("Xin chào, em có thể hỗ trợ gì cho quý khách ạ?");

              // Chào xong -> Mở Mic nghe khách trả lời
              _startListening();
            }
          }
        } else {
          // KHÁCH BỎ ĐI
          if (_lastSeenTime != null) {
            final secondsSinceLost = now.difference(_lastSeenTime!).inSeconds;

            if (secondsSinceLost >= 3) {
              logI("🤖 AI: Khách đã rời đi. Dừng mọi hoạt động.");
              await _speak("Cảm ơn quý khách đã ghé thăm");

              _resetSystem(fullReset: true); // Cắt ngang STT và TTS ngay lập tức
            }
          }
        }
      }
    } catch (e) {
      logI("Lỗi ML Kit: $e");
    }

    _isBusy = false;
  }

  InputImage? _createInputImage(CameraImage image) {
    if (_cameraController == null) return null;
    final camera = _cameraController!.description;

    // Tính góc xoay
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(camera.sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }

    // NỐI TOÀN BỘ DỮ LIỆU TỪ CÁC PLANES (Trị dứt điểm lỗi màn đen / không nhận diện)
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes[0].bytesPerRow,
      ),
    );
  }

  // ==========================================
  // 6. GIAO DIỆN (UI)
  // ==========================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _viewBot(),
            _viewCamera()
          ],
        ),
      ),
    );
  }

  Widget _viewBot() {
    return Expanded(
      flex: 1,
      child: Container(
        color: Colors.white,
        child: Center(
          child: RiveWidgetBuilder(
            fileLoader: fileLoader,
            builder: (context, state) => switch (state) {
              RiveLoading() => const Center(child: CircularProgressIndicator()),
              RiveFailed() => ErrorWidget.withDetails(
                message: state.error.toString(),
                error: FlutterError(state.error.toString()),
              ),
              RiveLoaded() => RiveWidget(
                controller: state.controller,
                fit: Fit.contain,
              )
            },
          ),
        ),
      ),
    );
  }

  Widget _viewCamera() {
    return Expanded(
      flex: 1,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.blueGrey,
        ),
        child: _isCameraInitialized
            ? CameraPreview(_cameraController!)
            : const Center(
          child: CircularProgressIndicator(color: Colors.green),
        ),
      ),
    );
  }
}
