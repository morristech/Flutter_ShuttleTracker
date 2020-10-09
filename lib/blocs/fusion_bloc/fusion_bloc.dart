import 'dart:async';
import 'dart:convert';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../data/fusion/fusion_socket.dart';
import '../../data/models/shuttle_update.dart';

part 'fusion_event.dart';
part 'fusion_state.dart';

class FusionBloc extends Bloc<FusionEvent, FusionState> {
  final FusionSocket fusionSocket;
  Map<ShuttleUpdate, Marker> fusionMap = {};

  FusionBloc({@required this.fusionSocket}) : super(FusionInitial()) {
    fusionSocket.openWS();
    fusionSocket.subscribe("eta");
    fusionSocket.subscribe("vehicle_location");

    fusionSocket.channel.stream.listen((message) {
      fusionSocket.streamController.add(message);

      var response = jsonDecode(message);
      if (response['type'] == 'server_id') {
        fusionSocket.serverID = response['message'];
        print(fusionSocket.serverID);
      } else if (response['type'] == 'vehicle_location') {
        add(GetFusionData(
            shuttleUpdate: fusionSocket.handleVehicleLocations(message)));
      }
    }, onError: (error) {
      print(error);
      fusionSocket.closeWS();
    });
  }

  @override
  Stream<FusionState> mapEventToState(
    FusionEvent event,
  ) async* {
    if (event is GetFusionData) {
      var data = await event.shuttleUpdate;
      data.setColor = Colors.white;
      if (data.routeId != null &&
          data.time.day == DateTime.now().day &&
          data.time.month == DateTime.now().month &&
          data.time.year == DateTime.now().year) {
        fusionMap[data] = data.getMarker();
        print(fusionMap.length);
      }

      var list = <Marker>[];
      fusionMap.forEach((k, v) => list.add(v));

      yield FusionLoaded(updates: list);
    }
  }

  @override
  Future<void> close() {
    fusionSocket.closeWS();
    return super.close();
  }
}
