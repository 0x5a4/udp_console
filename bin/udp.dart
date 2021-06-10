import 'dart:async';
import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'commands.dart';

AnsiPen err = AnsiPen()..red();
AnsiPen info = AnsiPen()..yellow();
bool verbose = false;
bool binaryMode = false;
bool reusePort = true;
String timestampMode = null;

void main(List<String> arguments) async {
  CommandRunner cmdRnr = CommandRunner("udp", "Send/Receive UDP via Console")
    ..addCommand(SendCommand())
    ..addCommand(ListenCommand())
    ..addCommand(TerminalCommand())
    ..argParser.addFlag("verbose", negatable: false, defaultsTo: false, help: "Show additional Debug info", abbr: "v")
    ..argParser.addFlag(
      "noColor",
      negatable: false,
      defaultsTo: false,
      help: "Disable Color",
    )
    ..argParser.addFlag(
      "binMode",
      negatable: false,
      defaultsTo: false,
      help: "Set the Program to Binary Mode. "
          "Messages received will be printed in binary and Stuff you type is also interpreted as binary and not text",
      abbr: "b",
    )
    ..argParser.addOption(
      "timestamp",
      allowed: ["u", "f"],
      allowedHelp: {
        "u": "Unix Timestamp",
        "f": "Formatted as 'hh:mm:ss'",
      },
      valueHelp: "Timestamp format",
      abbr: "t",
      help: "If the current time should be printed when receiving a Message",
    )
    ..argParser.addFlag(
      "reusePort",
      negatable: !reusePort,
      defaultsTo: reusePort,
      help: "Set the port to be reusable so it isn't fully blocked by the application",
    );
  //Should've just used try-catch
  runZonedGuarded(() {
    //Parse for Global Flags and Options
    ArgResults results = cmdRnr.parse(arguments);
    ansiColorDisabled = results["noColor"];
    binaryMode = results["binMode"];
    reusePort = results["reusePort"];
    verbose = results["verbose"];
    timestampMode = results.wasParsed("timestamp") ? results["timestamp"] : timestampMode;

    //Run
    cmdRnr.run(arguments);
  }, (e, stackTrace) {
    print(err(e.toString()));
    if (verbose) print(stackTrace);
    //Non-Zero exit code to give some indication that something went wrong other than the printed error
    exit(1);
  });
}

int sendUDP(RawDatagramSocket socket, InternetAddress address, int port, String message) {
  List<int> bytes;
  if (binaryMode) {
    bytes = [];
    for (String byte in message.split(" ")) {
      //In case you accidentally hit space twice :)
      if (byte.length > 0) {
        if (byte.length == 2) {
          //Hexadecimal
          bytes.add(int.parse(byte, radix: 16));
        } else if (byte.length == 8) {
          //Binary
          bytes.add(int.parse(byte, radix: 2));
        } else {
          print(err("$byte is neither a valid 8-bit Byte or hexadecimal"));
          return 0;
        }
      }
    }
  } else {
    bytes = message.codeUnits;
  }
  return socket.send(bytes, address, port);
}

void handleMessage(RawDatagramSocket socket, RawSocketEvent event) {
      switch (event) {
        case RawSocketEvent.read:
          Datagram dg = socket.receive();
          if (dg != null && dg.data.length > 0) {
            String messageInfo = "";
            if (timestampMode != null) {
              DateTime date = DateTime.now();
              switch (timestampMode) {
                case "u":
                  messageInfo += date.millisecondsSinceEpoch.toString() + " ";
                  break;
                case "f":
                  messageInfo += "${date.hour.toString().padLeft(2, "0")}:"
                      "${date.minute.toString().padLeft(2, "0")}:"
                      "${date.second.toString().padLeft(2, "0")} ";
                  break;
              }
            }
            messageInfo += "[${dg.address.address}:${dg.port}]:";
            if (binaryMode) {
              const int bytesPerLine = 4;
              print(info(messageInfo));
              for (int i = 0; i < (dg.data.length / bytesPerLine).ceil(); i++) {
                int j = 0;
                StringBuffer buffer = StringBuffer();
                String hexString = " |";
                buffer.write(info(i) + ")");
                for (int k = 0; k < bytesPerLine; k++) {
                  j = i * 4 + k;
                  if (j < (dg.data.length)) {
                    hexString += " " + dg.data[j].toRadixString(16).padLeft(2, '0');
                    buffer.write(" " + dg.data[j].toRadixString(2).padLeft(8, '0'));
                  } else {
                    buffer.write("         "); // 9 spaces
                  }
                }
                buffer.write(hexString);
                print(buffer.toString());
              }
            } else {
              print(info(messageInfo) + String.fromCharCodes(dg.data.toList()));
            }
          }
      }
    }
