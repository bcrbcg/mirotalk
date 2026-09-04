import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:permission_handler/permission_handler.dart';

const String serverUrl = 'https://your-mirotalk-domain.com';

void main() {
  runApp(const MaterialApp(home: MeetingPage()));
}

class MeetingPage extends StatefulWidget {
  const MeetingPage({super.key});

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  IO.Socket? socket;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    await [Permission.camera, Permission.microphone].request();

    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': {'facingMode': 'user'}
    });
    _localRenderer.srcObject = localStream;

    _connectSocket();
  }

  void _connectSocket() {
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      socket!.emit('join', {'room_id': 'default-room', 'peer_name': 'MobileApp'});
    });

    socket!.on('offer', (data) async {
      await _createPeerConnection();
      await peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
      RTCSessionDescription answer = await peerConnection!.createAnswer();
      await peerConnection!.setLocalDescription(answer);
      socket!.emit('answer', answer.toMap());
    });

    socket!.on('answer', (data) async {
      await peerConnection!.setRemoteDescription(RTCSessionDescription(data['sdp'], data['type']));
    });

    socket!.on('candidate', (data) async {
      var candidate = RTCIceCandidate(data['candidate'], data['sdpMid'], data['sdpMLinesIndex']);
      await peerConnection!.addCandidate(candidate);
    });
  }

  Future<void> _createPeerConnection() async {
    peerConnection = await createPeerConnection({
      'iceServers': [{'urls': 'stun:stun.l.google.com:19302'}]
    });

    localStream?.getTracks().forEach((track) {
      peerConnection!.addTrack(track, localStream!);
    });

    peerConnection!.onIceCandidate = (candidate) {
      if (candidate != null) socket!.emit('candidate', candidate.toMap());
    };

    peerConnection!.onTrack = (event) {
      if (event.track.kind == 'video') {
        setState(() {
          _remoteRenderer.srcObject = event.streams[0];
        });
      }
    };
  }

  @override
  void dispose() {
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    localStream?.dispose();
    socket?.disconnect();
    peerConnection?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MiroTalk åŽŸç”Ÿä¼šè®®å®¤')),
      body: Stack(
        children: [
          Positioned.fill(child: RTCVideoView(_remoteRenderer)),
          Positioned(
            right: 20,
            top: 20,
            width: 120,
            height: 160,
            child: RTCVideoView(_localRenderer, mirror: true),
          ),
        ],
      ),
    );
  }
}