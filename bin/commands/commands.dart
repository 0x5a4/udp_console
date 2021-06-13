import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:args/command_runner.dart';
import '../main.dart';
part 'listen.dart';
part 'send.dart';
part 'terminal.dart';

///Create a Socket on [port] and [InternetAddress.anyIPv4]
Future<RawDatagramSocket> createSocket(int port) async =>
    await RawDatagramSocket.bind(InternetAddress.anyIPv4, port, reusePort: reusePort, reuseAddress: true);

String constructMsgInfo(String sender, int port) {
  StringBuffer builder = StringBuffer();
  builder.write("[");
  if (timestampMode != TimestampMode.NONE) {
    builder.write("${timestampMode.timestamp} ");
  }
  builder.write("$sender:$port");
  builder.write("]\n");
  return info(builder.toString());
}

Uint8List parseOutput(String input) {
  if (binaryMode.output) {
    BytesBuilder bytes = new BytesBuilder();
    for (String byte in input.split(" ")) {
      //In case you accidentally hit space twice :)
      if (byte.length > 0) {
        if (byte.length == 2) {
          //Hexadecimal
          bytes.addByte(int.parse(byte, radix: 16));
        } else if (byte.length == 8) {
          //Binary
          bytes.addByte(int.parse(byte, radix: 2));
        } else {
          throw FormatException("$byte is neither a valid 8-bit Byte or hexadecimal");
        }
      }
    }
    return bytes.toBytes();
  }
  return Uint8List.fromList(input.codeUnits);
}

String formatReceivedMsg(Uint8List output) {
  if (binaryMode.input) {
    const int bytesPerLine = 4;
    StringBuffer result = StringBuffer();
    for (int i = 0; i < (output.lengthInBytes / bytesPerLine).ceil(); i++) {
      int j = 0;
      StringBuffer currLine = StringBuffer();
      String hexString = " |";
      currLine.write(info(i) + ")");
      for (int k = 0; k < bytesPerLine; k++) {
        j = i * 4 + k;
        if (j < (output.length)) {
          hexString += " " + output[j].toRadixString(16).padLeft(2, '0');
          currLine.write(" " + output[j].toRadixString(2).padLeft(8, '0'));
        } else {
          currLine.write("         "); // 9 spaces
        }
      }
      currLine.write("$hexString\n");
      result.write(currLine.toString());
    }
    return result.toString();
  }
  return String.fromCharCodes(output.toList());
}

///Sends the given [input] to [address] on [port] using [socket]
///input is interpreted according to [binaryMode]. returns the number of bytes send
int sendUDP(RawDatagramSocket socket, InternetAddress address, int port, String input) {
  return socket.send(parseOutput(input), address, port);
}

