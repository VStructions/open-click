/*
------------------------------------------------------------------------------
MIT License
Copyright (c) 2021 VStructions
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
------------------------------------------------------------------------------
*/

import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

//Global vars

const MaterialColor black = MaterialColor(
  //Because it didn't allow me to use black
  0xFF000000,
  <int, Color>{
    50: Color(0xFF000000),
    100: Color(0xFF000000),
    200: Color(0xFF000000),
    300: Color(0xFF000000),
    400: Color(0xFF000000),
    500: Color(0xFF000000),
    600: Color(0xFF000000),
    700: Color(0xFF000000),
    800: Color(0xFF000000),
    900: Color(0xFF000000),
  },
);

final ThemeData appTheme = ThemeData(
  primarySwatch: black,
  primaryColor: Colors.black,
  backgroundColor: Colors.black,
  dialogBackgroundColor: Colors.black,
  scaffoldBackgroundColor: Colors.black,
);

String? coordinatesStaticallyClocked;
SendPort netThread = ReceivePort().sendPort;
InternetAddress clientAddress = InternetAddress(defaultAddress);
bool connectedToClient = false;
String defaultAddress = "127.0.0.1";

void main() async {
  SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(systemNavigationBarColor: Colors.black));

  runApp(OpenClickApp());
}

class OpenClickApp extends StatelessWidget {
  void initThread() async {
    ReceivePort mainThread = ReceivePort();
    netThread = await createNetworkThread(mainThread);

    getLastClientAddressFromDisk();

    //This periodic timer throttles the frequency of mouse coordinates
    Timer.periodic(Duration(milliseconds: 13), (timerArg) {
      mouseToNet(netThread);
    });
  }

  void getLastClientAddressFromDisk() async {
    final shrdPrefs = await SharedPreferences.getInstance();
    final lastClientAddress = shrdPrefs.getString('lastClientAddress') ?? 0;
    if (lastClientAddress == 0) {
      updateClientAddress(defaultAddress);
    } else {
      updateClientAddress(lastClientAddress.toString());
      connectedToClient = true;
    }
  }

  Future<SendPort> createNetworkThread(ReceivePort mainThread) async {
    Isolate.spawn(networkThread, mainThread.sendPort);
    return await mainThread.first;
  }

  @override
  Widget build(BuildContext context) {
    initThread();

    return MaterialApp(
      title: 'OpenClick',
      theme: appTheme,
      darkTheme: appTheme,
      home: MainScreen(),
    );
  }

  static void networkThread(SendPort mainThread) async {
    ReceivePort netThread = ReceivePort();
    mainThread.send(netThread.sendPort);

    int port = 42069;
    RawDatagramSocket toClient =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

    netThread.listen((data) {
      if (data[0] == "0") {
        //0 code updates clientAddress
        clientAddress = InternetAddress(data.substring(1));
      } else {
        toClient.send(utf8.encode(data), clientAddress, port);
      }
    });
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  //Menu state
  bool menuCollapsed = true,
      remoteKeyboardEnable = true,
      memoryOfOnePointerOnScreen = false,
      memoryOfTwoPointersOnScreen = false;
  int memoryOfTouchPointers = 0;

  final Duration menuAnimationDuration = Duration(milliseconds: 150);
  //Text controllers
  final keyboardController = TextEditingController();
  String keyboardControllerMemory = "";
  final addressController = TextEditingController();
  //Focus controllers
  final FocusNode focusKeyboard = FocusNode();
  final FocusNode focusAddress = FocusNode();
  //Screen properties
  late double width, height;
  var isPortrait;

  @override
  Widget build(BuildContext context) {
    MediaQueryData mediaQuery = MediaQuery.maybeOf(context)!;
    width = mediaQuery.size.width;
    height = mediaQuery.size.height;
    isPortrait = mediaQuery.orientation == Orientation.portrait;

    return WillPopScope(
      //Controls back button behaviour
      onWillPop: () async {
        if (!menuCollapsed) {
          setState(() {
            menuCollapsed = true;
            remoteKeyboardEnable = true;
          });
          return false;
        } else {
          return true;
        } //True pops the context
      },
      child: GestureDetector(
        //Hides the keyboard on the menu widget
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);

          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
          if (addressController.text == "") {
            connectedToClient = true;
          }
        },
        child: Scaffold(
          backgroundColor: black,
          body: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              menu(context),
              dashPad(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget dashPad(context) {
    return AnimatedPositioned(
      duration: menuAnimationDuration,
      top: 0,
      bottom: 0,
      left: isPortrait
          ? (menuCollapsed ? 0 : width - (width / 2))
          : (menuCollapsed ? 0 : width - (width / 1.35)),
      right: isPortrait
          ? (menuCollapsed ? 0 : -(width - (width / 2)))
          : (menuCollapsed ? 0 : -(width - (width / 1.35))),
      child: Material(
        color: Color(0x0),
        //this makes the keyboard overlay and not cause pixel overflow
        child: SingleChildScrollView(
          physics: NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                height: 26,
              ),
              Container(
                width: width,
                height: isPortrait ? height / 1.23 : height / 1.5,
                margin: EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.grey[900],
                ),
                child: Stack(children: [
                  GestureDetector(
                    onTap: () {
                      onTap();
                    },
                    onDoubleTap: () {
                      onTap();
                      onTap();
                    }, //Need this callback in order to use the -//- one
                    onDoubleTapDown: (TapDownDetails details) {
                      onDoubleTapDown();
                    },
                    onScaleStart: (ScaleStartDetails details) {
                      onScaleStart(details);
                    },
                    onScaleEnd: (ScaleEndDetails details) {
                      onScaleEnd(details);
                    },
                    onScaleUpdate: (ScaleUpdateDetails details) {
                      onScaleUpdate(details);
                    },
                  ),
                  IconButton(
                    icon: menuCollapsed
                        ? Icon(Icons.settings)
                        : Icon(Icons.chevron_left),
                    iconSize: 33,
                    splashColor: Color(0), //0 opacity
                    color: Colors.grey[700],
                    onPressed: () {
                      setState(() {
                        FocusScopeNode currentFocus = FocusScope.of(context);
                        if (!currentFocus.hasPrimaryFocus) {
                          currentFocus.unfocus();
                        }

                        if (!menuCollapsed) {
                          if (addressController.text != "") {
                            updateClientAddress(addressController.text);
                            addressController.clear();
                          }
                          connectedToClient = true;
                        }
                        remoteKeyboardEnable = !remoteKeyboardEnable;
                        menuCollapsed = !menuCollapsed;
                      });
                    },
                  )
                ]),
              ),
              Divider(
                height: isPortrait ? width / 130 : width / 300,
              ),
              Row(children: [
                Flexible(
                  child: Container(
                    //Left Click
                    width: width, //-6 look at symmetric edges above
                    height: isPortrait ? height / 11 : height / 7,
                    margin: EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.only(bottomLeft: Radius.circular(20)),
                        color: Colors.grey[800]),
                    child: GestureDetector(
                      onTapUp: (TapUpDetails details) {
                        HapticFeedback.vibrate();
                        HapticFeedback.vibrate();
                        netThread.send("13 ");
                      },
                      onPanDown: (DragDownDetails e) {
                        HapticFeedback.vibrate();
                        netThread.send("13 ");
                      },
                      onPanEnd: (DragEndDetails e) {
                        HapticFeedback.vibrate();
                        HapticFeedback.vibrate();
                        netThread.send("13 ");
                      },
                    ),
                  ),
                ),
                Divider(
                  indent: isPortrait ? width / 130 : width / 300,
                ),
                Flexible(
                  child: Container(
                    //Right Click
                    width: width, //-6 look at symmetric edges above
                    height: isPortrait ? height / 11 : height / 7,
                    margin: EdgeInsets.only(right: 3),
                    decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.only(bottomRight: Radius.circular(20)),
                        color: Colors.grey[800]),
                    child: GestureDetector(
                      onTapUp: (TapUpDetails details) {
                        HapticFeedback.vibrate();
                        HapticFeedback.vibrate();
                        netThread.send("14 ");
                      },
                      onPanDown: (DragDownDetails e) {
                        HapticFeedback.vibrate();
                        netThread.send("14 ");
                      },
                      onPanEnd: (DragEndDetails e) {
                        HapticFeedback.vibrate();
                        HapticFeedback.vibrate();
                        netThread.send("14 ");
                      },
                    ),
                  ),
                ),
              ]),
              Divider(
                height: isPortrait ? width / 30 : width / 100,
              ),
              Container(
                height: 30,
                child: Flex(direction: Axis.vertical, children: [
                  Flexible(
                    child: TextField(
                      onTap: () {
                        keyboardController.text = enablebackspaceOnSoftKeyboard;
                        keyboardControllerMemory =
                            enablebackspaceOnSoftKeyboard;
                        keyboardController.selection =
                            TextSelection.fromPosition(TextPosition(
                                offset: keyboardController.text.length));
                      },
                      enabled: remoteKeyboardEnable,
                      controller: keyboardController,
                      keyboardAppearance: Brightness.dark,
                      onChanged: (String text) {
                        TextSelection.fromPosition(TextPosition(
                            offset: keyboardController.text.length));
                        if (keyboardController.text.length !=
                            keyboardControllerMemory.length + 1) {
                          keyboardControllerMemory =
                              keyboardControllerMemory.substring(
                                  0, keyboardControllerMemory.length - 1);
                          textSend("\b");
                        } else {
                          textSend(text[text.length - 1]);
                          keyboardControllerMemory =
                              keyboardControllerMemory + text[text.length - 1];
                        }
                      },
                      onSubmitted: (String text) {
                        textSend("\n");
                        keyboardController.clear();
                        keyboardControllerMemory = "";
                      }, //It will create an enter button
                      showCursor: false,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.keyboard_arrow_right_outlined,
                            color: Colors.grey[800],
                          ),
                          suffixIcon: Icon(Icons.keyboard_arrow_left_outlined,
                              color: Colors.grey[800])),
                      focusNode: focusKeyboard,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
  //Previous design
  //InputDecoration.collapsed(
  //                        hintStyle: TextStyle(color: Colors.grey[800]),
  //                        hintText: '• Keyboard •')

  Widget menu(context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 3,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 35,
          ),
          Text(
            (clientAddress.address == defaultAddress) || !connectedToClient
                ? "Connect to:"
                : "Connected to:",
            style: TextStyle(color: Colors.grey[800], fontSize: 22),
          ),
          SizedBox(
            height: 0,
          ),
          Container(
            width: width / 2,
            child: TextField(
              onTap: () {
                connectedToClient = false;
              },
              controller: addressController,
              keyboardAppearance: Brightness.dark,
              cursorColor: Color(0x3300FF00),
              style: TextStyle(color: Color(0xBB00FF00), fontSize: 17),
              onSubmitted: (ip) {
                setState(() {
                  updateClientAddress(ip);
                  addressController.clear();
                  connectedToClient = true;
                });
              },
              decoration: InputDecoration(
                  focusedBorder: OutlineInputBorder(
                    gapPadding: 1,
                    borderSide: BorderSide(
                        width: 0.2,
                        color: Color(0x0),
                        style: BorderStyle.solid),
                  ),
                  //When not in focus
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                        width: 0.5,
                        color: Color(0x0),
                        style: BorderStyle.solid),
                  ),
                  hintStyle: TextStyle(color: Color(0x5500FF00)),
                  hintText: clientAddress.address == defaultAddress
                      ? 'E.g. 127.0.0.1'
                      : clientAddress.address),
              focusNode: focusAddress,
            ),
          )
        ],
      ),
    );
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 1) {
      coordinatesStaticallyClocked =
          "12 ${details.focalPoint.toString().substring(6)}";
    } else if (details.pointerCount == 2) {
      coordinatesStaticallyClocked =
          "18 ${details.focalPoint.toString().substring(6)} ${details.scale}";
    }
  }

  void onScaleStart(ScaleStartDetails details) {
    if (!memoryOfOnePointerOnScreen) {
      netThread.send("11 ${details.pointerCount}");
      memoryOfOnePointerOnScreen = true;
    } else if (!memoryOfTwoPointersOnScreen && memoryOfTouchPointers < 3) {
      netThread.send("11 ${details.pointerCount}");
      memoryOfTwoPointersOnScreen = true;
    }
    memoryOfTouchPointers = details.pointerCount;
  }

  void onScaleEnd(ScaleEndDetails details) {
    if (memoryOfOnePointerOnScreen) {
      netThread.send("11 ${details.pointerCount + 1}");
      memoryOfTwoPointersOnScreen = false;
    } else if (memoryOfTwoPointersOnScreen) {
      netThread.send("11 ${details.pointerCount + 1}");
      memoryOfTwoPointersOnScreen = false;
    }
  }

  void onTap() {
    netThread.send("15 ");
  }

  void onDoubleTapDown() {
    netThread.send("17 ");
  }

  void textSend(String text) {
    //TODO Implement string split at 253 characters
    netThread.send("21 $text");
  }

  @override
  void dispose() {
    keyboardController.dispose();
    addressController.dispose();
    super.dispose();
  }
}

void mouseToNet(SendPort netThread) {
  if (coordinatesStaticallyClocked != null) {
    netThread.send(coordinatesStaticallyClocked);
    coordinatesStaticallyClocked = null;
  }
}

void updateClientAddress(String newClientAddress) async {
  newClientAddress = newClientAddress.replaceAll(' ', '');
  if (!isIPv4(newClientAddress)) {
    return;
  }
  clientAddress = InternetAddress(newClientAddress);

  final shrdPrefs = await SharedPreferences.getInstance();
  shrdPrefs.setString('lastClientAddress', newClientAddress);
  netThread.send("0$newClientAddress");
}

bool isIPv4(String suspect) {
  List<String> bytes = suspect.split(".");
  if (bytes.length != 4) return false;
  for (var byte in bytes) {
    int? intByte;
    if ((intByte = int.tryParse(byte)) == null) return false;
    if (intByte! < 0 || intByte > 255) return false;
  }
  return true;
}

//Char count = times backspace can be pressed
String enablebackspaceOnSoftKeyboard =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
