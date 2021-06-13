part of 'commands.dart';

class SendCommand extends Command {
  SendCommand() {
    argParser
      ..addOption(
        "address",
        help: "Destination address",
        valueHelp: "any valid IP address",
        abbr: "a",
      )
      ..addOption(
        "port",
        help: "Destination port",
        valueHelp: "valid port(Range: 0 to 65535)",
        abbr: "p",
      )
      ..addOption(
        "message",
        help: "Message to be send",
        abbr: "m",
      )
      ..addOption(
        "awaitResponses",
        help: "Listen on the responsePort for the specified number of responses. -1 is infinite",
        valueHelp: "expected amount of responses",
        defaultsTo: "0",
      )
      ..addOption(
        "responsePort",
        help: "Port used to listen for responses (only if awaitResponses > 0)",
      );
  }

  @override
  void run() async {
    //Was a message given?
    if (!argResults!.wasParsed("message")) {
      usageException("message is required");
    }

    //Check if Responses should be expected
    int? responseCount = int.tryParse(argResults!["awaitResponses"]);
    if (responseCount == null) usageException("Response count needs to be a number");

    if (!argResults!.wasParsed("address")) {
      usageException("address is required");
    }
    //Lookup the address(in case the user did not specify an IP but any kind of domain)
    InternetAddress address = (await InternetAddress.lookup(argResults!["address"])).first; //Just use the first one
    if (verbose) {
      print("Address is ${address.address}${address.host != address.address ? " resolved from ${address.host}" : ""}");
    }

    if (!argResults!.wasParsed("port")) {
      usageException("port is required");
    }
    //Check if port is a number and in valid range
    int? port = int.tryParse(argResults!["port"]);
    if (port == null || port < 0 || port > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    final RawDatagramSocket socket;

    //Setup Response Listener if necessary
    if (responseCount != 0) {
      if (!argResults!.wasParsed("responsePort")) {
        usageException("Response Port not specified, although awaitResponses was used");
      }
      //Check if responsePort is valid
      int? responsePort = int.tryParse(argResults!["responsePort"]);
      if (responsePort == null || responsePort < 0 || responsePort > 65535) {
        usageException("Response Port needs to be a number (Range: 0 to 65535)");
      }

      socket = await createSocket(responsePort);
      int receivedResponses = 0;
      StreamSubscription sub = socket.listen((event) {});
      sub.onData((event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = socket.receive();
          if (dg != null) {
            Uint8List? data = dg.data;
            print("${constructMsgInfo(dg.address.address, dg.port)}${formatReceivedMsg(data)}");
          }
          receivedResponses++;
          if (receivedResponses == responseCount) {
            sub.cancel();
          }
        }
      });
    } else {
      socket = await createSocket(0);
    }

    //Actually send the message
    print(info("${sendUDP(socket, address, port, argResults!["message"])} Bytes send"));
  }

  @override
  String get description => "Send a udp message to the given address on the given port";

  @override
  String get name => "send";
}