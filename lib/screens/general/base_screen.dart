import 'package:chat_bot_ai/network/cloud/cloud_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/general_funstions.dart';
import '../../core/general_screen.dart';

abstract class BaseScreen<T extends ConsumerStatefulWidget>
    extends GeneralScreen<T>
    with AppFunctions{
  late CloudClient cloudClient;
  @override
  void initAll() async {
    _initApi();
    super.initAll();
  }
  void _initApi() {
    cloudClient = CloudClient(this);
  }
}