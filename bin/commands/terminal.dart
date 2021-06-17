part of 'commands.dart';

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
    String? addressString = argResults!["address"];
    String? dPortString = argResults!["dPort"];
    String? portString = argResults!["port"];

    //Check if address was given. Ask again otherwise
    if (!argResults!.wasParsed("address")) {
      print("Enter Destination Address:");
      addressString = stdin.readLineSync();
    }

    //Lookup the address(in case the user did not specify an IP but any kind of domain)
    InternetAddress address = await resolve(addressString!);
    if (verbose) {
      print("Address is ${address.address}${address.host != address.address ? " resolved from ${address.host}" : ""}");
    }

    //Check if Destination Port was given. Ask again otherwise
    if (!argResults!.wasParsed("dPort")) {
      print("Enter destination port:");
      dPortString = stdin.readLineSync();
    }

    //Check if the Destination Port is a number and in valid range
    int? dPort = int.tryParse(dPortString!);
    if (dPort == null || dPort < 0 || dPort > 65535) {
      usageException("Destination port needs to be a number(Range: 0 to 65535)");
    }

    if (!argResults!.wasParsed("port")) {
      print("Enter local port:");
      portString = stdin.readLineSync();
    }

    //Check if the local Port is a number and in valid range
    int? port = int.tryParse(portString!);
    if (port == null || port < 0 || port > 65535) {
      usageException("Local port needs to be a number(Range: 0 to 65535)");
    }

    //Actually create the Socket and register our Handlers
    RawDatagramSocket socket = await createSocket(port);

    //Inform the User that we are now listening and expecting his input
    print(info("Sending to ${address.address}:${dPort}. Receiving on port $port"));
    print(info("Press ctrl+c ${argResults!["disableExit"] ? "or type '!exit' " : ""}to exit"));

    //Register Listen Handler
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = socket.receive();
        if (dg != null) {
          Uint8List? data = dg.data;
          print("${constructMsgInfo(dg.address.address, dg.port)}${formatReceivedMsg(data)}");
        }
      }
    });

    //Register Sending handler, Exit if !exit was typed
    StreamSubscription subscription = stdin.listen((event) {});
    subscription.onData((data) {
      String message = String.fromCharCodes(data).trim();
      if (message == "!exit" && !argResults!["disableExit"]) {
        socket.close();
        subscription.cancel();
        return;
      }
      print(constructMsgInfo(address.toString(), dPort) + "${sendUDP(socket, address, dPort, message)} Bytes written");
    });
  }

  @override
  String get description => "Read/Write Terminal for UDP Messages";

  @override
  String get name => "terminal";
}