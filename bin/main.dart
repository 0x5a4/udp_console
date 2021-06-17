import 'dart:io';

import 'package:ansicolor/ansicolor.dart';
import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'commands/commands.dart';

final AnsiPen err = AnsiPen()..red();
final AnsiPen info = AnsiPen()..yellow();
bool verbose = false;
bool reusePort = true;
bool raw = false;
TimestampMode timestampMode = TimestampMode.NONE;
BinaryMode binaryMode = BinaryMode.NONE;

void main(List<String> arguments) async {
  //Setup Command Runner
  CommandRunner cmdRnr = CommandRunner("udp", "Send/Receive UDP via Console")
    ..addCommand(SendCommand())
    ..addCommand(ListenCommand())
    ..addCommand(TerminalCommand())
    ..argParser.addFlag(
      "verbose",
      negatable: false,
      defaultsTo: verbose,
      help: "Show additional debug info",
      abbr: "v",
    )
    ..argParser.addFlag(
      "noColor",
      negatable: false,
      defaultsTo: false,
      help: "Disable color",
    )
    ..argParser.addFlag(
      "reusePort",
      negatable: false,
      defaultsTo: reusePort,
      help: "Set the port to be reusable",
    )
    ..argParser.addOption(
      "binMode",
      abbr: "b",
      help: "Helps to display or input binary output",
      allowed: ["none", "in", "out", "both"],
      allowedHelp: {
        "none": "Disabled. displays and interprets messages as strings",
        "in": "Received messages are displayed as binary and hexadecimal",
        "out": "Messages you typed are interpreted as binary or hexadecimal",
        "both": "'in' and 'out' combined",
      },
      defaultsTo: "none",
    )
    ..argParser.addOption(
      "timestamp",
      allowed: ["u", "f"],
      allowedHelp: {
        "u": "Unix timestamp",
        "f": "Formatted as 'hh:mm:ss'",
        "none": "No timestamp will be printed"
      },
      defaultsTo: "none",
      valueHelp: "timestamp format",
      abbr: "t",
      help: "If the current time should be printed when receiving a Message",
    );
  try {
    //Parse for Global Flags and Options
    ArgResults results = cmdRnr.parse(arguments);
    ansiColorDisabled = results["noColor"];
    reusePort = results["reusePort"];
    verbose = results["verbose"];

    binaryMode = () {
      switch(results["binMode"]) {
        case "in": return BinaryMode.IN;
        case "out": return BinaryMode.OUT;
        case "both": return BinaryMode.BOTH;
      }
      return BinaryMode.NONE;
    }();
    if (verbose) print("Binary Mode set to $binaryMode");

    timestampMode = TimestampMode.forID(results["timestamp"]);
    if (verbose) print("timestamp is $timestampMode");
    //Run
    await cmdRnr.run(arguments);
  } catch (e, stackTrace) {
    print(err(e.toString()));
    if (verbose) print(stackTrace);
    //Non-Zero exit code to give some indication that something went wrong other than the printed error
    exit(1);
  }
}

///Timestamp mode of the app. Can either be
///
///[NONE] No timestamp included
///[UNIXTIME] Unixtime will be printed(milliseconds since 1. January 1970 00:00)
///[FORMATTED] Formatted time HH:MM:SS
///
class TimestampMode {
  static const TimestampMode NONE = TimestampMode("none");
  static const TimestampMode UNIXTIME = TimestampMode("u");
  static const TimestampMode FORMATTED = TimestampMode("f");

  final String id;

  const TimestampMode(this.id);

  factory TimestampMode.forID(String id) {
    switch(id) {
      case "u": return UNIXTIME;
      case "f": return FORMATTED;
    }
    return NONE;
  }

  String? get timestamp {
    DateTime time = DateTime.now();
    switch(this.id) {
      case "u": return time.millisecondsSinceEpoch.toString();
      case "f":
        return "${time.hour.toString().padLeft(2, "0")}:"
            "${time.minute.toString().padLeft(2, "0")}:"
            "${time.second.toString().padLeft(2, "0")}";
    }
    return null;
  }


  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TimestampMode && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

///Binary mode of the app
class BinaryMode {

  static const BinaryMode NONE = BinaryMode(false, false);
  static const BinaryMode IN = BinaryMode(true, false);
  static const BinaryMode OUT = BinaryMode(false, true);
  static const BinaryMode BOTH = BinaryMode(true, true);

  final bool input;
  final bool output;

  const BinaryMode(this.input, this.output);

  @override
  String toString() {
    return 'input: $input, output: $output';
  }


}

