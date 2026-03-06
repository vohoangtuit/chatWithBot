import 'dart:io';

import 'package:camera/camera.dart';
import 'package:chat_bot_ai/model/chat_model.dart';
import 'package:chat_bot_ai/screens/general/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:rive/rive.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends BaseScreen<MainScreen> {

  // --- Rive & TTS ---
  late final fileLoader = FileLoader.fromAsset(
    "assets/robot/robot_ai.riv",
    riveFactory: Factory.rive,
  );
  late FlutterTts _tts;

  // --- STT & Hội thoại ---
  final stt.SpeechToText _speech = stt.SpeechToText();
  final List<String> _fillerWords = [
    "Dạ quý khách chờ em chút...",
    "Để em xem ạ...",
    "Dạ...",
    "Vâng ạ...",
  ];

  bool _isConversing = false; // Đánh dấu đang trong cuộc hội thoại
  bool _isSpeaking = false; // BIẾN MỚI: Đánh dấu loa có đang phát ra tiếng không
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
  String _textBotShow ="";
  String _textGuestShow ="";
  bool _isLoading = false;

  late VideoPlayerController _controllerIdle;
  late VideoPlayerController _controllerSpeaking;
  late VideoPlayerController _controllerBow;
  StatusVideo _statusVideo =StatusVideo.idle;
  bool _isVideoInitialized = false;

  @override
  Widget build(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    //logI("isPortrait $isPortrait");
    return SafeArea(
      top: false,
      child: Scaffold(
        backgroundColor: Colors.black54,
        body: SafeArea(
          child: _viewCheckPortrait(isPortrait),
        ),
      ),
    );
  }
  Widget _viewCheckPortrait(bool portrait) {
    return portrait?Column(children: [
     // _viewBot(1),
      _viewVideo(1),
      _viewInfo(1),
      //_viewCamera()
    ],):Row(
      children: [
        //_viewBot(2),
        _viewVideo(2),
        SizedBox(width: 10,),
        _viewInfo(3),
       // _viewCamera()
      ],
    );
  }

  Widget _viewBot(int flex ) {
    return Expanded(
      flex: flex,
      child: Column(
        children: [
          SizedBox(height: 20,),
          Image.asset(
            "assets/logo/logo_vietravel.png",
            width: 150,
            height: 50,
            fit: BoxFit.contain,
          ),
          Expanded(
            child: Container(
              // color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, left: 20, right: 20),
                child: Center(
                  child: RiveWidgetBuilder(
                    fileLoader: fileLoader,
                    builder: (context, state) => switch (state) {
                      RiveLoading() => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      RiveFailed() => ErrorWidget.withDetails(
                       // message: state.error.toString(),
                       // error: FlutterError(state.error.toString()),
                      ),
                      RiveLoaded() => RiveWidget(
                        controller: state.controller,
                        fit: Fit.contain,
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _viewVideo(int flex) {
    String currentAvatarPath = "";

    // Chọn đường dẫn file theo trạng thái
    switch (_statusVideo) {
      case StatusVideo.idle:
        currentAvatarPath = 'assets/webps/idle.webp';
        break;
      case StatusVideo.speaking:
        currentAvatarPath = 'assets/webps/speaking.webp';
        break;
      case StatusVideo.bow:
        currentAvatarPath = 'assets/webps/bow.webp';
        break;
    }

    return Expanded(
      flex: flex,
      child: Column(
        children: [
          Container(
            // Dùng Image.asset thay vì VideoPlayer
            child: Image.asset(
              currentAvatarPath,
              fit: BoxFit.contain, // Hoặc cover tùy khung hình anh thiết kế

              // CHIÊU THỨC QUAN TRỌNG NHẤT:
              // Giữ nguyên khung hình cũ trên màn hình cho đến khi file mới load xong.
              // Loại bỏ 100% hiện tượng chớp đen và giật lag!
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewInfo(int flex ) {
    return Expanded(flex: flex, child: Container(color: Colors.black,child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _viewLoading(),
        _viewTextBot(),
        _viewTextGuest(),
      ],
    ),));
  }
  Widget _viewTextBot() {
    return _textBotShow.isNotEmpty?Container(
      padding: const EdgeInsets.all(10),
      child: Text(
        _textBotShow,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    ):Container();
  }
  Widget _viewTextGuest() {
    return _textGuestShow.isNotEmpty?Container(
      padding: const EdgeInsets.all(10),
      child: Text(
        _textGuestShow,
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    ):Container();
  }

  Widget _viewCamera() {
    return Expanded(
      flex: 1,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(color: Colors.blueGrey),
        child: _isCameraInitialized
            ? CameraPreview(_cameraController!)
            : const Center(
                child: CircularProgressIndicator(color: Colors.green),
              ),
      ),
    );
  }
  Widget _viewLoading(){
    return _isLoading?Center(
      child: SizedBox(
        width: 90,
        child: LoadingAnimationWidget.progressiveDots( // threeRotatingDots ,progressiveDots,threeArchedCircle
          color: Colors.deepOrange,
          size: 50,
        ),
      ),
    ):Container();
  }

  @override
  void initState() {
    super.initState();

    _tts = FlutterTts();
    _initVideo();
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
  void _initVideo()async{
    _controllerIdle = VideoPlayerController.asset('assets/videos/video1.mp4');
    _controllerSpeaking = VideoPlayerController.asset('assets/videos/video2.mp4');
    _controllerBow = VideoPlayerController.asset('assets/videos/video3.mp4');

    await Future.wait([
      _controllerIdle.initialize(),
      _controllerSpeaking.initialize(),
      _controllerBow.initialize(),
    ]);

    // Cài đặt lặp và tắt tiếng
    _controllerIdle.setLooping(true);
    _controllerIdle.setVolume(0);

    _controllerSpeaking.setLooping(true);
    _controllerSpeaking.setVolume(0);

    // Video cúi chào không nên lặp (chỉ chào 1 lần rồi thôi)
    _controllerBow.setLooping(false);
    _controllerBow.setVolume(0);

    // CHO PHÁT NGẦM CẢ 3 CÙNG LÚC NGAY TỪ ĐẦU
   // _controllerIdle.play();
    _controllerSpeaking.play();
  //  _controllerBow.play();

    _isVideoInitialized = true;
    setState(() {});

  }

  Future<void> _setupTts() async {
    await _tts.setLanguage("vi-VN");
    // vi-vn-x-vic-network || vi-vn-x-vid-network || vi-vn-x-vif-network || vi-vn-x-vie-network || vn-x-gft-network
    if (Platform.isAndroid) {
      await _tts.setVoice({"name": "vi-vn-x-vic-network", "locale": "vi-VN"});
    } else if (Platform.isIOS) {
      await _tts.setVoice({"name": "Majed", "locale": "vi-VN"}); // Linh
    }
    await _tts.setSpeechRate(0.54); // toc độ nói
    await _tts.setPitch(1.0);
    // TIỂU XẢO BẺ GIỌNG:
    // pitch = 1.0 (Giọng mặc định, hơi chững chạc)
    // pitch = 1.2 hoặc 1.3 (Giọng thanh hơn, trẻ trung, nhí nhảnh hơn - Hợp với ViVi)
    // pitch = 0.7 hoặc 0.8 (Giọng trầm ấm, chững chạc hơn)
    // BẮT BUỘC: Đợi AI đọc xong 100% thì mới nhả hàm (Tránh việc Micro thu lại tiếng AI)
    await _tts.awaitSpeakCompletion(true);
    var voices = await _tts.getVoices;

    // print("voices: $voices"); // xem danh sách giọng có sẵn
    // THÊM ĐOẠN NÀY ĐỂ TÌM GIỌNG ĐỌC
    List<dynamic> _voices = await _tts.getVoices;
    for (var _voices in voices) {
      // Lọc ra và in các giọng tiếng Việt đang có trong máy
      /// print("Giọng tìm thấy: Tên=${_voices['name']} - Ngôn ngữ=${_voices['locale']}");
      // if (_voices["locale"].toString().contains("vi")) {
      // //  print("Giọng tìm thấy: Tên=${_voices['name']} - Ngôn ngữ=${_voices['locale']}");
      // }
    }
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        logI("Micro status: $status");

        // 1. Thêm 'notListening' để bắt chuẩn mọi dòng máy Android/iOS
        if ((status == 'done' || status == 'notListening') &&
            _currentWords.isNotEmpty &&
            _isConversing) {

          // 2. Chép câu nói ra một biến tạm
          String textToSend = _currentWords;

          // 3. SIÊU QUAN TRỌNG: Xóa sạch biến cũ NGAY LẬP TỨC
          _currentWords = "";

          // 4. Mới tiến hành gửi API
          _sendToFirebase(textToSend);
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


  Future<void> _startListening() async {
    if (!_isConversing) return; // Nếu khách bỏ đi rồi thì không nghe nữa
// BƯỚC CHỐNG DỘI ÂM: Đợi 400 mili-giây cho âm vang trong phòng tản đi hết
    await Future.delayed(const Duration(milliseconds: 400));
    // NẾU AI VẪN ĐANG NÓI (Do có lỗi luồng nào đó) -> TUYỆT ĐỐI KHÔNG BẬT MIC
    if (_isSpeaking) {
      logI("⚠️ Loa đang phát, từ chối bật Mic để tránh dội âm!");
      return;
    }
    _currentWords = ""; // Reset câu cũ
    // Đảm bảo Mic đã được dọn sạch trước khi nghe lại
    _speech.cancel();
    await _speech.listen(
      onResult: (result) {
        _currentWords = result.recognizedWords;
        _updateTextGuestShow(_currentWords);

      },
      localeId: "vi_VN",
      pauseFor: const Duration(
        milliseconds: 1500,
      ),
    );
    logI("🎤 Bắt đầu nghe...");
  }

  Future<void> _speak(String text) async {
    _isSpeaking = true; // KHÓA MIC: Đánh dấu đang nói
    logI("🤖 AI nói: $text");
    // [GỢI Ý] Kích hoạt Rive nhép môi ở đây nếu anh muốn
    // _riveController?.stateMachine?.boolean('isTalking')?.value = true;
    _updateTextBotShow(text);
    String textToRead = text;
    textToRead = textToRead.replaceAll(
      RegExp(r'Vietravel', caseSensitive: false),
      'Việt tra vồ',
    );
    textToRead = textToRead.replaceAll(
      RegExp(r'Tour', caseSensitive: false),
      'Tua',
    );

    _updateStatusVideo(StatusVideo.speaking);
    await _tts.speak(
      textToRead,
    );
    _updateTextBotShow("");

   _updateStatusVideo(StatusVideo.idle);
    _isSpeaking = false; // MỞ KHÓA MIC: Đã nói xong
  }
  void _updateTextBotShow(String text){
    setState(() {
      _textBotShow =text;
    });
  }
  void _updateTextGuestShow(String text){
    setState(() {
      _textGuestShow =text;
    });
  }
  void _updateLoading(bool loading){
    setState(() {
      _isLoading =loading;
    });
  }

  void _updateStatusVideo(StatusVideo status){
    setState(() {
      _statusVideo =status;
    });
  }

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
            if (secondsLooked >= 3 && !_hasGreeted) {
              _hasGreeted = true;
              _isConversing = true; // Bật cờ hội thoại
              logI("🤖 AI: Khách đứng đủ 5s. Tiến hành chào!");

             // await _speak("Xin chào, em có thể hỗ trợ gì cho quý khách ạ?");
              await _speak("Vietravel xin kính chào quý khách, em có thể giúp gì cho anh ạ?");

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
              await _speak("Cảm ơn quý khách đã ghé thăm Vietravel");

              _resetSystem(
                fullReset: true,
              ); // Cắt ngang STT và TTS ngay lập tức
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
    InputImageRotation? rotation = InputImageRotationValue.fromRawValue(
      camera.sensorOrientation,
    );
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

  Future<void> _sendToFirebase(String userText) async {
    if (!_isConversing) return;

    // Tắt Mic liền tay (Không dùng await ở đây để tránh bị kẹt hàm)
    //_speech.stop();
    // SỬA STOP THÀNH CANCEL: Hủy sạch bộ đệm âm thanh, chặn đứng việc xử lý tạp âm
    _speech.cancel();

    logI("🗣️ Khách nói: $userText");
    _updateTextGuestShow(""); // Xóa chữ trên UI

    // Phát từ đệm (Filler words)
    _fillerWords.shuffle();
    // String filler = _fillerWords.first;
    // _updateTextBotShow(filler);
    // await _tts.speak(filler); // Chờ AI đọc xong chữ "Dạ..."
    // _updateTextBotShow('');
    _updateLoading(true); // Bật loading khi chờ API
    try {
      // Gọi API bằng Await chuẩn
      ChatModel data = ChatModel(text: userText,history: [..._chatHistory],);

      // 💡 LƯU Ý NHỎ: Nếu ChatModel của anh có chỗ chứa lịch sử,
      // nhớ nhét cái _chatHistory vào đây nhé để AI nhớ mạch chuyện!
      var response = await cloudClient.chatWithAi(data);
      _updateLoading(false);
      if (response != null && response.success == true) {
        String reply = response.reply ?? "Dạ em chưa nghe rõ ạ.";
        logI("🤖 AI trả lời: $reply");

        // Ghi vào sổ tay
        _chatHistory.add({'role': 'user', 'text': userText});
        _chatHistory.add({'role': 'model', 'text': reply});

        // Bắt mã kết thúc
        if (reply.contains("[END_CONVERSATION]")) {
          reply = reply.replaceAll("[END_CONVERSATION]", "").trim();
          await _speak(reply); // Đọc câu chào tạm biệt
          _resetSystem(fullReset: true); // Reset toàn bộ
          return; // THOÁT HÀM LUÔN -> KHÔNG BẬT LẠI MIC NỮA
        }

        // Đọc câu trả lời bình thường
        await _speak(reply);

      } else {
        await _speak("Dạ hệ thống bên em đang quá tải, anh nói lại giúp em nhé.");
      }

    } catch (e) {
      _updateLoading(false);
      logI("🔥 Lỗi API/Mạng: $e");
      await _speak("Dạ, mạng đang chập chờn, quý khách đợi em chút xíu nhé.");

    } finally {
      // 🛡️ BƯỚC CHỐT SỔ:
      // Chỉ cần cờ _isConversing còn Bật, lập tức gọi Mic dậy nghe tiếp!
      if (_isConversing) {
        logI("🎙️ Mở lại Micro cho lượt tiếp theo...");
        _startListening();
      }
    }
  }
  void _resetSystem({required bool fullReset}) {
    //_speech.stop();
    _speech.cancel(); // SỬA STOP THÀNH CANCEL
    _tts.stop();
    _isConversing = false;
    _hasGreeted = false;
    _isLoading = false;
    _firstSeenTime = null;
    if (fullReset) _lastSeenTime = null;
    _chatHistory.clear();
     _updateTextBotShow("");
     _updateTextGuestShow("");
  }
}
enum StatusVideo{
  idle,
  speaking,
  bow
}

// vi-vn-x-vic-network || vi-vn-x-vid-network || vi-vn-x-vif-network || vi-vn-x-vie-network || vn-x-gft-network
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-VN-language - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-gft-network - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vie-network - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vid-local - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vic-local - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-gft-local - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vie-local - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vif-network - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vif-local - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vid-network - Ngôn ngữ=vi-VN
// I/flutter ( 6319): [MainScreen] ✅ Giọng tìm thấy: Tên=vi-vn-x-vic-network - Ngôn ngữ=vi-VN
