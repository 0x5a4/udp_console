import 'dart:async';
import 'dart:io';
import 'package:args/command_runner.dart';
import 'udp.dart';

///Create a Socket on [port] and [InternetAddress.anyIPv4]
Future<RawDatagramSocket> createSocket(int port) async =>
    await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reusePort: reusePort, reuseAddress: true);

class TerminalCommand extends Command {
  TerminalCommand() {
    argParser
      ..addOption(
        "address",
        help: "Destination Address",
        valueHelp: "Any valid IP Address",
        abbr: "a",
      )
      ..addOption(
        "dPort",
        help: "Destination Port",
        valueHelp: "Valid Port(Range: 0 to 65535)",
        abbr: "d",
      )
      ..addOption(
        "port",
        help: "Local Port. Default is the Same as Destination Port",
        valueHelp: "Valid Port(Range: 0 to 65535)",
        abbr: "p",
      )
      ..addFlag(
        "disableExit",
        help: "Disables typing '!exit' to exit",
        defaultsTo: false,
        negatable: false,
        abbr: "e",
      );
  }

  @override
  void run() async {
    String addressString = argResults["address"];
    String dPortString = argResults["dPort"];
    String portString = argResults["port"];

    //Check if address was given. Ask again otherwise
    if (!argResults.wasParsed("address")) {
      print("Enter Destination Address:");
      addressString = stdin.readLineSync();
    }

    //Lookup the address(in case the user did not specify an IP but any kind of domain)
    InternetAddress address = (await InternetAddress.lookup(addressString)).first; //Just use the first one;
    if (verbose) {
      print("Address is ${address.address}${address.host != address.address ? " resolved from ${address.host}" : ""}");
    }

    //Check if Destination Port was given. Ask again otherwise
    if (!argResults.wasParsed("dPort")) {
      print("Enter Destination Port:");
      dPortString = stdin.readLineSync();
    }

    //Check if the Destination Port is a number and in valid range
    int dPort = int.tryParse(dPortString);
    if (dPort == null || dPort < 0 || dPort > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    //Check if Local Port was given. If not ask if the Destination Port should be used
    if (!argResults.wasParsed("port")) {
      print("Use the Same Port for sending and receiving?(y/n)");
      if (!stdin.readLineSync().trim().toLowerCase().startsWith("y")) {
        print("Enter Local Port:");
        portString = stdin.readLineSync();
      } else {
        portString = dPortString;
      }
    }

    //Check if the local Port is a number and in valid range
    int port = int.tryParse(portString);
    if (port == null || port < 0 || port > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    //Actually create the Socket and register our Handlers
    RawDatagramSocket socket = await createSocket(port);
    //Inform the User that we are now listening and expecting his input
    print(info("Sending to ${address.address}:${dPort}. Receiving on port $port"));
    print(info("Press ctrl+c or type '!exit' to exit"));
    //Register Listen Handler
    socket.listen((event) => handleMessage(socket, event));
    //Register Sending handler, Exit if !exit was typed
    StreamSubscription subscription = stdin.listen((event) {});
    subscription.onData((data) {
      String message = String.fromCharCodes(data).trim();
      if (message == "!exit" && !argResults["disableExit"]) {
        socket.close();
        subscription.cancel();
        return;
      }
      print(info("[${address.address}:$dPort] ") + "${sendUDP(socket, address, dPort, message)} Bytes written");
    });
  }

  @override
  String get description => "Read/Write Terminal for UDP Messages";

  @override
  String get name => "terminal";
}

class ListenCommand extends Command {
  ListenCommand() {
    argParser.addOption(
      "port",
      help: "Port on which to listen for messages",
      valueHelp: "Valid Port(Range: 0 to 65535)",
      abbr: "p",
    );
  }

  @override
  void run() async {
    //Check if port is a number and in valid range
    int port = int.tryParse(argResults["port"]);
    if (port == null || port < 0 || port > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    //Create Socket
    RawDatagramSocket socket = await createSocket(port);
    socket.listen((event) => handleMessage(socket, event));
  }

  @override
  String get description => "Listen for UDP Messages on given port. Messages will be piped to stdout";

  @override
  String get name => "listen";
}

class SendCommand extends Command {
  SendCommand() {
    argParser
      ..addOption(
        "address",
        help: "Destination Address",
        valueHelp: "Any valid IP Address",
        abbr: "a",
      )
      ..addOption(
        "port",
        help: "Destination Port",
        valueHelp: "Valid Port(Range: 0 to 65535)",
        abbr: "p",
      )
      ..addOption(
        "message",
        help: "Message to be send",
        abbr: "m",
      )
      ..addOption(
        "awaitResponses",
        help: "Listen on the responsePort for the specified Number of Responses",
        valueHelp: "Expected amount of Responses",
        defaultsTo: "0",
      )
      ..addOption(
        "responsePort",
        help: "Port used to listen for Responses (only if awaitResponses > 0)",
      );
  }

  @override
  void run() async {
    //Check if Responses should be expected
    int responseCount = int.tryParse(argResults["awaitResponses"]);
    if (responseCount == null) usageException("Response Count needs to be a number");
    if (responseCount < 0) usageException("Response Count cannot be negative");

    //Lookup the address(in case the user did not specify an IP but any kind of domain)
    InternetAddress address = (await InternetAddress.lookup(argResults["address"])).first; //Just use the first one
    if (verbose) {
      print("Address is ${address.address}${address.host != address.address ? " resolved from ${address.host}" : ""}");
    }

    //Check if port is a number and in valid range
    int port = int.tryParse(argResults["port"]);
    if (port == null || port < 0 || port > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    //Setup Response Listener if necessary
    if (responseCount > 0) {
      if (!argResults.wasParsed("responsePort")) {
        usageException("Response Port not specified, although awaitResponses was used");
      }
      //Check if responsePort is valid
      int responsePort = int.tryParse(argResults["responsePort"]);
      if (responsePort == null || responsePort < 0 || responsePort > 65535) {
        usageException("Response Port needs to be a number (Range: 0 to 65535)");
      }

      RawDatagramSocket socket = await createSocket(responsePort);
      int receivedResponses = 0;
      StreamSubscription sub = socket.listen((event) {});
      sub.onData((data) {
        if (data == RawSocketEvent.read) {
          receivedResponses++;
          handleMessage(socket, data);
          if (receivedResponses == responseCount) {
            sub.cancel();
          }
        }
      });
    }

    //Actually send the message
    print(info("${sendUDP(await createSocket(port), address, port, argResults["message"])} Bytes send"));
  }

  @override
  String get description => "Send a UDP Messages to the given address on the given port";

  @override
  String get name => "send";
}
