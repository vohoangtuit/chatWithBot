
import 'package:dio/dio.dart';
import 'package:robot/model/chat_model.dart';
import 'package:robot/network/cloud/cloud_config.dart';
import 'package:robot/network/cloud/cloud_response.dart';

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