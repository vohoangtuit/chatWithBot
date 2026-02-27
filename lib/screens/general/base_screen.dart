import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:robot/network/cloud/cloud_client.dart';

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