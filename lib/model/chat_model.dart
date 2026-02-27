class ChatModel {
  String? text;
  String? language;
  List<Map<String, String>>? history;

  ChatModel({this.text,this.history, this.language});

  ChatModel.fromJson(Map<String, dynamic> json) {
    text = json['text'] ?? '';
    language = json['language'] ?? '';
  }
 Map<String,dynamic> toJson() {
   Map<String,dynamic> data = <String,dynamic>{};
    data['text'] = text;
    if(history!=null){
      data['history'] = history;
    }
    if(language!=null){
      data['language'] = language;
    }

    return data;

  }

   @override
  String toString() {
    return 'ChatModel{text: $text, language: $language}';
  }
}