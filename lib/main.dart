import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP32 LED Control',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LEDControlPage(),
    );
  }
}

class LEDControlPage extends StatefulWidget {
  const LEDControlPage({super.key});

  @override
  State<LEDControlPage> createState() => _LEDControlPageState();
}

class _LEDControlPageState extends State<LEDControlPage> {
  late MqttServerClient client;
  bool isConnected = false;
  bool ledState = false;
  String statusText = 'รอเชื่อมต่อ...';

  @override
  void initState() {
    super.initState();
    _connectMQTT();
  }

  Future<void> _connectMQTT() async {
    final client = MqttServerClient('broker.emqx.io', 'flutter-client-001');
client.port = 1883; // สำหรับ TCP
client.keepAlivePeriod = 20;
client.onDisconnected = _onDisconnected;
client.logging(on: true);

final connMessage = MqttConnectMessage()
    .withClientIdentifier('flutter-client-001')
    .startClean()
    .withWillQos(MqttQos.atLeastOnce);
client.connectionMessage = connMessage;

try {
  await client.connect();
} catch (e) {
  print('❌ MQTT connection failed: $e');
}


  }

  void _onConnected() {
    setState(() {
      isConnected = true;
      statusText = 'เชื่อมต่อกับ MQTT แล้ว ✅';
    });

    // ✅ subscribe รับสถานะ LED จาก ESP32
    client.subscribe('esp32-6583/status', MqttQos.atMostOnce);

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final recMess = c[0].payload as MqttPublishMessage;
      final pt = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      debugPrint('📩 รับข้อความ: $pt');

      setState(() {
        ledState = pt.toLowerCase() == 'on';
        statusText = 'สถานะ LED: ${pt.toUpperCase()}';
      });
    });
  }

  void _onDisconnected() {
    setState(() {
      isConnected = false;
      statusText = 'หลุดการเชื่อมต่อ MQTT ❌';
    });
  }

  void _toggleLED() {
    if (!isConnected) return;

    final builder = MqttClientPayloadBuilder();
    final message = ledState ? 'off' : 'on';
    builder.addString(message);

    client.publishMessage('esp32-6583/output', MqttQos.atMostOnce, builder.payload!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ESP32 LED Control')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              ledState ? Icons.lightbulb : Icons.lightbulb_outline,
              color: ledState ? Colors.amber : Colors.grey,
              size: 120,
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: isConnected ? _toggleLED : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: ledState ? Colors.red : Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              ),
              child: Text(
                ledState ? 'ปิดไฟ' : 'เปิดไฟ',
                style: const TextStyle(fontSize: 22),
              ),
            ),
            const SizedBox(height: 30),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 18,
                color: isConnected ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
