import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(MaterialApp(
  home: MyHomePage(),
));

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File _imageFile;
  bool connected = false;
  final String serverIp = '192.168.1.127';
  Socket client;
  String faceName = '';
  String title = 'Face Recognition';

  void _onImageButtonPressed(ImageSource source, {BuildContext context}) async {
    try {
      _imageFile = await ImagePicker.pickImage(
          source: source, maxHeight: 1000.0, maxWidth: 500.0);
      setState(() {});
    } catch (e) {
      print(e.toString());
    }
  }

  void sendImage(File image) async {
    Uint8List data = await image.readAsBytes();
    String base64Image = base64.encode(data);
    client.write(base64Image + '<EOF>');
  }

  Widget _previewImage() {

    if (_imageFile != null) {
      sendImage(_imageFile);
      return Image.file(_imageFile);
    } else {
      return Text(
        'You have not yet picked an image.',
        textAlign: TextAlign.center,
      );
    }
  }

  Future<void> retrieveLostData() async {
    final LostDataResponse response = await ImagePicker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }

    if (response.file != null) {
      setState(() => _imageFile = response.file);
    } else {
      print(response.exception.code);
    }
  }

  void connectSocket() async {
    print('Connecting to $serverIp...');
    setState(() {
      connected = false;
      title = 'Connecting...';
      faceName = '';
    });
    try {
      client = await Socket.connect(serverIp, 5005, timeout: Duration(seconds: 2));
    } catch (e) {
      print("ERROR CONNECTION: " + e.toString());
      connectSocket();
      return;
    }

    setState(() {
      connected = true;
      title = 'Face Recognition';
    });

    print('CONNECTED!');

    client.listen((List<int> event) {
      String result = ascii.decode(event);
      print('RESULT: $result');
      if (result.contains('=')) {
        String comm = result.substring(0, result.indexOf('='));
        String value = result.substring(result.indexOf('=') + 1);
        if (comm == 'R') {
          setState(() {
            if (value == 'NONE') {
              faceName = 'No match found';
            } else {
              faceName = value;
            }
          });
        } else {
          print('client data error.');
        }
      } else {
        print('client data error.');
      }
    }, onDone: () {
      _imageFile = null;
      print('Client connection done!');
      connectSocket();
    }, onError: (e) {
      _imageFile = null;
      print('Client connection error: ' + e.ToString());
      connectSocket();
    });
  }

  @override
  void initState() {
    super.initState();
    connectSocket();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Stack(
        //alignment: Alignment.center,
        children: <Widget>[
          !connected
              ? Center(
            child: Text(
              'DISCONNECTED',
              style: TextStyle(
                  color: Colors.red,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold),
            ),
          )
              : Center(
            child: FutureBuilder<void>(
              future: retrieveLostData(),
              builder:
                  (BuildContext context, AsyncSnapshot<void> snapshot) {
                switch (snapshot.connectionState) {
                  case ConnectionState.none:
                  case ConnectionState.waiting:
                    return const Text(
                      'You have not yet picked an image.',
                      textAlign: TextAlign.center,
                    );
                  case ConnectionState.done:
                    return _previewImage();
                  default:
                    if (snapshot.hasError) {
                      return Text(
                        'Pick image/video error: ${snapshot.error}}',
                        textAlign: TextAlign.center,
                      );
                    } else {
                      return const Text(
                        'You have not yet picked an image.',
                        textAlign: TextAlign.center,
                      );
                    }
                }
              },
            ),
          ),
          Center(
              child: Text(faceName,
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20.0))),
        ],
      ),
      floatingActionButton: !connected
          ? Container()
          : Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          FloatingActionButton(
            onPressed: () => _onImageButtonPressed(ImageSource.gallery,
                context: context),
            heroTag: 'image0',
            tooltip: 'Pick Image from gallery',
            child: const Icon(Icons.photo_library),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: FloatingActionButton(
              onPressed: () => _onImageButtonPressed(ImageSource.camera,
                  context: context),
              heroTag: 'image1',
              tooltip: 'Take a Photo',
              child: const Icon(Icons.camera_alt),
            ),
          ),
        ],
      ),
    );
  }
}
