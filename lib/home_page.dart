import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:uuid/uuid.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SpeechToText _speechToText = SpeechToText();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _speechEnabled = false;
  bool _isListening = false;
  List<String> _transcripts = [];

  @override
  void initState() {
    super.initState();
    initSpeech();
  }

  void initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
    } catch (e) {
      print('Error initializing speech: $e');
      _speechEnabled = false;
    }
    setState(() {});
  }

  Future<void> _startListening() async {
    _transcripts.clear();
    setState(() => _isListening = true);

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        cancelOnError: true,
        partialResults: false,
      );
    } catch (e) {
      print('Error starting to listen: $e');
      _stopListening();
    }
  }

  Future<void> _stopListening() async {
    setState(() => _isListening = false);
    await _speechToText.stop();
    await _saveTranscriptsToFirebase();
  }

  void _onSpeechResult(result) {
    setState(() {
      if (result.finalResult) {
        _transcripts.add(result.recognizedWords);
      }
    });
  }

  Future<void> _saveTranscriptsToFirebase() async {
    try {
      for (var transcriptText in _transcripts) {
        final transcriptId = Uuid().v4();
        await _firestore.collection('transcripts').doc(transcriptId).set({
          'text': transcriptText,
          'timestamp': FieldValue.serverTimestamp(),
        });
        print('Saved transcript: $transcriptId');
      }
      _transcripts.clear();
      print('All transcripts saved successfully');
    } catch (e) {
      print('Error saving transcripts: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blueAccent,
        title: Text(
          'Speech Demo',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            child: Text(
              _isListening
                  ? "Listening..."
                  : _speechEnabled
                      ? "Tap the microphone to start listening..."
                      : "Speech not available",
              style: TextStyle(fontSize: 20.0),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Container(
              padding: EdgeInsets.all(16),
              child: Text(
                _transcripts.join('\n'),
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: 80,
        height: 80,
        child: FloatingActionButton(
          onPressed: () async {
            if (_isListening) {
              await _stopListening();
            } else {
              await Future.delayed(Duration(milliseconds: 200));
              await _startListening();
            }
          },
          tooltip: 'Listen',
          child: Icon(
            _isListening ? Icons.mic : Icons.mic_off,
            color: Colors.white,
            size: 40,
          ),
          backgroundColor: Colors.blueAccent,
          elevation: 5,
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
