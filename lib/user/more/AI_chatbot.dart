import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'water_prediction_service.dart';

class AIChatbotScreen extends StatefulWidget {
  const AIChatbotScreen({super.key});
  @override
  State<AIChatbotScreen> createState() => _AIChatbotScreenState();
}

class _AIChatbotScreenState extends State<AIChatbotScreen> {
  final TextEditingController controller = TextEditingController();
  final SpeechToText _speechToText = SpeechToText();
  final WaterPredictionService _predictionService = WaterPredictionService();

  String responseText =
      "I am your Gemini-powered Smart Water Tank Assistant! Ask me anything about your tank.";
  bool isLoading = false;
  bool _isListening = false;

  static const String _geminiApiKey = 'AQ.Ab8RN6KufLK9G3LSLgdaoAEkwMzzQT9aMGyYfY59vJYdMz0Wbw';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    bool available = await _speechToText.initialize(
      onStatus: (status) => setState(() {}),
      onError: (errorNotification) => print(errorNotification),
    );
    if (!mounted) return;
    setState(() {});
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speechToText.listen(
        onResult: (result) {
          setState(() {
            controller.text = result.recognizedWords;
          });
        },
      );
      if (available) {
        setState(() => _isListening = true);
      }
    } else {
      setState(() => _isListening = false);
      _speechToText.stop();
    }
  }

  void askGemini() async {
    // Stop listening if user hits send while speaking
    if (_isListening) {
      _speechToText.stop();
      setState(() => _isListening = false);
    }

    final userQuery = controller.text.trim();
    if (userQuery.isEmpty) return;

    if (_geminiApiKey == 'PASTE_YOUR_NEW_GEMINI_API_KEY_HERE') {
      setState(() {
        responseText = 'Add your new Gemini API key in AI_chatbot.dart first.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      responseText = "Gemini is analyzing your tank data...";
    });

    try {
      String databaseContext =
          "No real-time sensor data available at the moment.";
      String predictionContext =
          "Water prediction data is currently unavailable.";
      String? databaseWarning;
      double? currentWaterLevel;
      double minPh = 6.5;
      double maxPh = 7.5;

      try {
        final phSettings = await FirebaseFirestore.instance
            .collection('settings')
            .doc('ph_config')
            .get();
        final settings = phSettings.data();
        if (settings != null) {
          minPh =
              double.tryParse(settings['min_ph']?.toString() ?? '') ?? minPh;
          maxPh =
              double.tryParse(settings['max_ph']?.toString() ?? '') ?? maxPh;
        }
        if (minPh >= maxPh) {
          minPh = 6.5;
          maxPh = 7.5;
          databaseWarning =
              'The saved pH range is invalid; using the default range of 6.5 to 7.5.';
        }
      } on FirebaseException catch (e) {
        databaseWarning =
            'Could not load pH settings: ${e.message}. Using the default range of 6.5 to 7.5.';
      }

      try {
        final snapshot =
            await FirebaseDatabase.instance.ref('SensorData').get();
        if (snapshot.value != null) {
          final dataMap = Map<dynamic, dynamic>.from(snapshot.value as Map);
          final latestKey = dataMap.keys.last;
          final sensor = dataMap[latestKey];

          final double? ph = double.tryParse(sensor['ph']?.toString() ?? '');
          double level =
              double.tryParse(sensor['water_level_percent'].toString()) ?? 0.0;
          currentWaterLevel = level;
          double flow1 =
              double.tryParse(sensor['flow_sensor1'].toString()) ?? 0.0;
          double flow2 =
              double.tryParse(sensor['flow_sensor2'].toString()) ?? 0.0;
          final phStatus = ph == null
              ? 'unavailable'
              : ph < minPh || ph > maxPh
              ? 'outside the configured normal range'
              : 'within the configured normal range';

          databaseContext =
              """
        Current Live Water Tank Sensor Data:
        - Water Level: $level%
        - pH Level: ${ph ?? 'unavailable'}
        - Configured normal pH range: $minPh to $maxPh
        - pH Status: $phStatus
        - Water Flow In (Sensor 1): $flow1 L/min
        - Water Flow Out (Sensor 2): $flow2 L/min
        """;
        }
      } on FirebaseException catch (e) {
        final warning =
            'Could not load live Firebase sensor data: ${e.message}';
        databaseWarning = databaseWarning == null
            ? warning
            : '$databaseWarning\n$warning';
      }

      try {
        predictionContext = await _predictionService.getPredictionContext(
          currentWaterLevel: currentWaterLevel,
        );
      } catch (e) {
        predictionContext = 'Water prediction data is unavailable: $e';
      }

      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: _geminiApiKey,
      );

      final prompt =
          """
      You are an expert Smart Water Tank Monitor AI Assistant. 
      Here is the latest real-time system data from the Firebase database:
      $databaseContext

      Here is the latest prediction data from the water forecast engine:
      $predictionContext

      The configured normal pH range is $minPh to $maxPh. Treat readings
      within this inclusive range as normal. A pH reading is abnormal only
      when it is below the configured minimum or above the configured maximum.
      Do not apply any other fixed pH range.
      
      The user is asking this question: "$userQuery"
      
      Instructions:
      - Answer the user's question accurately using the provided sensor data and prediction data.
      - If the user asks about refill timing, finish time, forecast, usage, tank level trend, or pump behavior, use the prediction context as the main evidence.
      - For questions like "When will water come next?", report the estimated refill time from the refill timing data. For "When will the water finish?", report the estimated time until the tank is empty from the water finish timing data.
      - Include the estimated date/time and remaining hours when available. These are forecasts, not guaranteed schedules; never invent a time if prediction data is missing or unavailable.
      - If the water level is dangerously low (e.g., < 20cm) or the provided pH status is outside the configured range, proactively alert them in a helpful tone.
      - Keep the response clear, professional, and easy to understand.
      """;

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      setState(() {
        final answer =
            response.text ?? "Sorry, I couldn't process that response.";
        responseText = databaseWarning == null
            ? answer
            : '$answer\n\n$databaseWarning';
        isLoading = false;
      });

      controller.clear();
    } catch (e) {
      setState(() {
        responseText = "Gemini API request failed: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Gemini Sensor Assistant"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Chat Bubble Area
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blueAccent,
                          child: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.psychology,
                                  color: Colors.white,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.2),
                                  spreadRadius: 2,
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              responseText,
                              style: const TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Input Field Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Microphone Button for Voice-to-Text
                  IconButton(
                    icon: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Colors.red : Colors.blueAccent,
                    ),
                    onPressed: _listen,
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !isLoading,
                      decoration: const InputDecoration(
                        hintText:
                            "Ask Gemini about water level, pH, or flow...",
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onSubmitted: (value) => askGemini(),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: isLoading ? null : askGemini,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
