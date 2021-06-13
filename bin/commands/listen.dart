part of 'commands.dart';

class ListenCommand extends Command {
  ListenCommand() {
    argParser.addOption(
      "port",
      help: "Port on which to listen for messages",
      valueHelp: "valid port(Range: 0 to 65535)",
      abbr: "p",
    );
  }

  @override
  void run() async {
    if (!argResults!.wasParsed("port")) {
      usageException("port is required");
    }

    int? port = int.tryParse(argResults!["port"]);
    if (port == null || port < 0 || port > 65535) {
      usageException("Port needs to be a number(Range: 0 to 65535)");
    }

    //Create Socket
    RawDatagramSocket socket = await createSocket(port);
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = socket.receive();
        if (dg != null) {
          Uint8List? data = dg.data;
          print("${constructMsgInfo(dg.address.address, dg.port)}${formatReceivedMsg(data)}");
        }
      }
    });
  }

  @override
  String get description => "Listen for udp Messages on the given port. Messages will be piped to stdout";

  @override
  String get name => "listen";
}