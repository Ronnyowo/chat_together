import 'dart:math';

import 'package:bale_phone/pages/MainPage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String nickname = "";
  String userId = "";
  String userReceiveId = "";

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: min(364, MediaQuery.of(context).size.width * 0.9),
          child: Column(
            spacing: 8,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Nickname',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    nickname = value;
                  });
                },
              ),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text;
                    if (text.isEmpty) {
                      return newValue;
                    }
                    final intValue = int.tryParse(text);
                    if (intValue == null) {
                      return oldValue;
                    }
                    return newValue;
                  }),
                ],
                decoration: const InputDecoration(
                  labelText: 'User Id',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    userId = value;
                  });
                },
              ),
              TextField(
                keyboardType: TextInputType.number,
                inputFormatters: [
                  TextInputFormatter.withFunction((oldValue, newValue) {
                    final text = newValue.text;
                    if (text.isEmpty) {
                      return newValue;
                    }
                    final intValue = int.tryParse(text);
                    if (intValue == null) {
                      return oldValue;
                    }
                    return newValue;
                  }),
                ],
                decoration: const InputDecoration(
                  labelText: 'User Receive Id',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    userReceiveId = value;
                  });
                },
              ),
              Row(
                spacing: 8,
                children: [
                  IconButton.filled(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final baleToken = prefs.getString('bale_token') ?? '';
                      final TextEditingController controller =
                          TextEditingController(text: baleToken);
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            scrollable: true,
                            title: Text("Information"),
                            content: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "In 8th January 2026 Iran government shutdown internet and start killing people in silence."
                                  "Those people are my family and friends who fighting for their freedom."
                                  "As today 16th January they still don't have any internet"
                                  "But I managed to find a whole in one of their messaging application where you can send messages through websocket even if you are in/out of Iran",
                                ),
                                SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("More explanation on my github "),
                                    GestureDetector(
                                      onTap: () {
                                        // TODO: Open github link
                                      },
                                      child: Text(
                                        "Github",
                                        style: TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 12),
                                Text(
                                  "How this app works",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "1. First you need to login into your Bale account through web with chrome ( if you are outside in Iran and don't have access to an Iranian SIM its impossible to login try to call someone in Iran and ask for their number) ",
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      // TODO open bale
                                    },
                                    child: Text("Open Bale webapp"),
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "2. After you login into your account open chrome devtools with Ctrl+Shift+I (or Cmd+Option+I on Mac) and go to Application tab then Cookies and copy the value of access_token",
                                ),
                                SizedBox(height: 8),
                                Column(
                                  spacing: 8,
                                  children: [
                                    Image.asset("assets/step1_open_cookie.png"),
                                    Image.asset("assets/step2_copy_cookie.png"),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "3. Paste the access_token in settings (the gear icon) and press apply",
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "4. Now the person in/out of Iran should do the same steps and agree on a user id to send messages to each other",
                                ),
                                SizedBox(height: 8),
                                Text(
                                  "5. The receiver user id is the user id of the person you want to send messages to and the user id is your own user id that you agreed before the user ids can be any number you want",
                                ),
                                SizedBox(height: 8),
                                Text("6. Enjoy chatting :)"),
                                SizedBox(height: 8),
                                Image.asset("assets/iran_flag.png"),
                              ],
                            ),

                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text("Close"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.info_outline),
                  ),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      height: 36,
                      child: ElevatedButton(
                        onPressed:
                            userId == "" ||
                                nickname == "" ||
                                userReceiveId == ""
                            ? null
                            : () async {
                                final prefs =
                                    await SharedPreferences.getInstance();
                                final token = prefs.getString("bale_token");
                                if (token == null || token == "") {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        "Please set Bale Token in settings",
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MainPage(
                                      nickname: nickname,
                                      userId: int.parse(userId),
                                      userReceiveId: int.parse(userReceiveId),
                                      baleToken: token,
                                    ),
                                  ),
                                );
                              },
                        child: Text("Login"),
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final baleToken = prefs.getString('bale_token') ?? '';
                      final TextEditingController controller =
                          TextEditingController(text: baleToken);
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: Text("Settings"),
                            content: TextField(
                              controller: controller,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: "Bale Token",
                                border: OutlineInputBorder(),
                              ),
                            ),

                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: Text("Close"),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await prefs.setString(
                                    'bale_token',
                                    controller.text,
                                  );
                                  Navigator.pop(context);
                                },
                                child: Text("Apply"),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    icon: Icon(Icons.settings),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
