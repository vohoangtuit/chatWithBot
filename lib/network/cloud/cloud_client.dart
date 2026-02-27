
import 'package:chat_bot_ai/model/chat_model.dart';
import 'package:chat_bot_ai/network/cloud/cloud_config.dart';
import 'package:chat_bot_ai/network/cloud/cloud_response.dart';
import 'package:dio/dio.dart';


class CloudClient extends CloudApiConfig{
  CloudClient( super.screen) : super.internal();

  Future<CloudResponse?> chatWithAi(ChatModel data) async {
    CloudResponse? response;
    try{
      await apiCloud.chatWithAi(data).then((data) => {
        response = data

      });
    }on DioException catch(_){
      showLoading(false);
      return response;
    }
    showLoading(false);
    return response;
  }

}