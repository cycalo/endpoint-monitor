import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class WatchlistState extends Equatable {
  const WatchlistState({this.names = const []});

  final List<String> names;

  WatchlistState copyWith({List<String>? names}) => WatchlistState(names: names ?? this.names);

  @override
  List<Object?> get props => [names];
}

/// Local-only watchlist UI; server persists flags. We keep names client-side for display.
class WatchlistBloc extends Cubit<WatchlistState> {
  WatchlistBloc() : super(const WatchlistState());

  void addName(String name) {
    if (name.isEmpty) return;
    emit(state.copyWith(names: {...state.names, name}.toList()));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'flag_process', 'name': name}));
  }

  void remove(String name) {
    emit(state.copyWith(names: state.names.where((n) => n != name).toList()));
    FlutterForegroundTask.sendDataToTask(jsonEncode({'type': 'unflag_process', 'name': name}));
  }
}
