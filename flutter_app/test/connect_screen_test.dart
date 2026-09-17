import 'package:endpoint_monitor/bloc/connection_bloc.dart';
import 'package:endpoint_monitor/screens/connect_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('connect address card supports its interactive list tile',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final bloc = ConnectionBloc(storage);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: const MaterialApp(home: ConnectScreen()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
