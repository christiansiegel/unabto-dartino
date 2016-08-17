// uNabto server library.

library unabto;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:dartino';
import 'dart:dartino.ffi';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:os/os.dart' as os;
import 'package:socket/socket.dart';
import 'package:stm32/ethernet.dart' as stm32;

final ForeignLibrary _unabto = Foreign.platform == Foreign.FREERTOS
    ? ForeignLibrary.main
    : new ForeignLibrary.fromName(
        ForeignLibrary.bundleLibraryName('unabtolib-posix'));

final _unabtoVersion = _unabto.lookup('unabtoVersion');
final _unabtoConfigure = _unabto.lookup('unabtoConfigure');
final _unabtoInit = _unabto.lookup('unabtoInit');
final _unabtoClose = _unabto.lookup('unabtoClose');
final _unabtoTick = _unabto.lookup('unabtoTick');
final _unabtoRegisterEventHandler =
    _unabto.lookup('unabtoRegisterEventHandler');
final _unabtoRegisterRandomHandler =
    _unabto.lookup('unabtoRegisterRandomHandler');
final _unabtoRegisterDnsIsResolvedHandler =
    _unabto.lookup('unabtoRegisterDnsIsResolvedHandler');
final _unabtoRegisterInitSocketHandler =
    _unabto.lookup('unabtoRegisterInitSocketHandler');
final _unabtoRegisterCloseSocketHandler =
    _unabto.lookup('unabtoRegisterCloseSocketHandler');
final _unabtoRegisterReadHandler = _unabto.lookup('unabtoRegisterReadHandler');
final _unabtoRegisterWriteHandler =
    _unabto.lookup('unabtoRegisterWriteHandler');
final _unabtoRegisterGetStampHandler =
    _unabto.lookup('unabtoRegisterGetStampHandler');

final _lookupHost = Foreign.platform == Foreign.FREERTOS
    ? ForeignLibrary.main.lookup("network_lookup_host")
    : null;

/// uNabto request event meta data.
class UNabtoRequest {
  /// The foreign `application_request` structure this wraps.
  final Struct _struct;

  /// Returns the ID of the query.
  int get queryId => _struct.getUint32(0);

  /// Returns the ID of the client.
  String get clientId {
    var ptr = new ForeignPointer(_struct.getField(1));
    return cStringToString(ptr);
  }

  /// Returns `true` if the request was issued from within the local network.
  bool get isLocal => _struct.getUint8(2 * _struct.wordSize) != 0;

  /// Returns `true` if the request was issued from within a remote network.
  bool get isLegacy => _struct.getUint8(3 * _struct.wordSize) != 0;

  /// Constructs a new request meta data object with a [pointer] to the foreign
  /// `application_request` structure this should wrap.
  const UNabtoRequest.fromAddress(int pointer)
      : _struct = new Struct.fromAddress(pointer, 4);
}

/// Wrapper for `buffer_read_t` and `buffer_write_t` structures.
///
/// Both `buffer_read_t` and `buffer_write_t` are typedefs for `unabto_abuffer`
/// which holds a pointer to the actual `unabto_buffer` data structure and the
/// current read/write position in the buffer.
class _UNabtoBuffer {
  /// Foreign memory holding the current read/write position in the buffer.
  ForeignMemory _pos;

  /// Foreign memory holding the buffer array.
  ForeignMemory _buffer;

  /// Size of the buffer array.
  int _size;

  /// Returns the current read/write position in the buffer.
  int get _position => _pos.getUint16(0);

  /// Sets the current read/write [position] in the buffer.
  ///
  /// Has no effect if the new [position] isn't within the bounds of the buffer.
  int set _position(int position) {
    if (0 <= position || position < _size) _pos.setUint16(0, position);
    return position;
  }

  /// Returns the unused space in the buffer.
  int get _unused => _size - _position;

  /// Constructs a new buffer wrapper object with a [pointer] to the foreign
  /// `buffer_read_t` or `buffer_write_t` structure this should wrap.
  _UNabtoBuffer.fromAddress(int pointer) {
    _pos = new ForeignMemory.fromAddress(pointer + Foreign.machineWordSize, 2);
    var unabto_buffer = new Struct.fromAddress(
        new Struct.fromAddress(pointer, 2).getField(0), 2);
    _size = unabto_buffer.getUint16(0);
    _buffer = new ForeignMemory.fromAddress(unabto_buffer.getField(1), _size);
  }
}

/// There is not enough data left in the request's read buffer.
class UNabtoRequestTooSmallError extends Error {
  UNabtoRequestTooSmallError() : super();
}

/// uNabto event read buffer.
class UNabtoReadBuffer extends _UNabtoBuffer {
  /// Interprets the binary value of an [unsigned] number with a specific number
  /// of [bits] as two's complement and returns the signed value.
  int _signed(int unsigned, int bits) {
    bool negative = (unsigned & (1 << (bits - 1))) != 0;
    if (negative)
      return unsigned | ~((1 << bits) - 1);
    else
      return unsigned;
  }

  /// Reads an unsigned integer value with a specific number of [bits] from the
  /// buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int _readUint(int bits) {
    if (_unused < (bits / 8)) throw new UNabtoRequestTooSmallError();
    var value = 0;
    for (int i = bits - 8; i >= 0; i -= 8)
      value |= _buffer.getUint8(_position++) << i;
    return value;
  }

  /// Reads an signed integer value with a specific number of [bits] from the
  /// buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int _readInt(int bits) => _signed(_readUint(bits), bits);

  /// Reads a 8-bit signed integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readInt8() => _readInt(8);

  /// Reads a 16-bit signed integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readInt16() => _readInt(16);

  /// Reads a 32-bit signed integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readInt32() => _readInt(32);

  /// Reads a 8-bit unsigned integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readUint8() => _readUint(8);

  /// Reads a 16-bit unsigned integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readUint16() => _readUint(16);

  /// Reads a 32-bit unsigned integer value from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  int readUint32() => _readUint(32);

  /// Reads a list of unsigned integer values from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  List<int> readUint8List() {
    var length = readUint16();
    var list = new List<int>(length);
    _buffer.copyBytesToList(list, _position, _position + length, 0);
    _position += length;
    return list;
  }

  /// Reads a string from the buffer and returns it.
  ///
  /// Throws an [UNabtoRequestTooSmallError] if there is not enough data left in
  /// the buffer.
  String readString() {
    var charCodes = readUint8List();
    return UTF8.decode(charCodes);
  }

  /// Constructs a new read buffer wrapper object with a [pointer] to the
  /// foreign `buffer_read_t` structure this should wrap.
  UNabtoReadBuffer.fromAddress(int ptr) : super.fromAddress(ptr);
}

/// There is not enough space left in the request's response write buffer.
class UNabtoResponseTooLargeError extends Error {
  UNabtoResponseTooLargeError() : super();
}

/// uNabto event write buffer.
class UNabtoWriteBuffer extends _UNabtoBuffer {
  /// Interprets the two's complement binary value of a [signed] number with a
  /// specific number of [bits] as unsigned value and returns it.
  int _unsigned(int signed, int bits) {
    if (signed < 0)
      return signed | ~((1 << bits) - 1);
    else
      return signed;
  }

  /// Writes an unsigned integer [value] with a specific number of [bits] to
  /// the buffer.
  ///
  /// Throws a [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void _writeUint(int value, int bits) {
    if (_unused < (bits / 8)) throw new UNabtoResponseTooLargeError();
    for (int i = bits - 8; i >= 0; i -= 8)
      _buffer.setUint8(_position++, value >> i);
  }

  /// Writes a signed integer [value] with a specific number of [bits] to
  /// the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void _writeInt(value, bits) => _writeUint(_unsigned(value, bits), bits);

  /// Writes a signed 8-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeInt8(int value) => _writeInt(value, 8);

  /// Writes a signed 16-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeInt16(int value) => _writeInt(value, 16);

  /// Writes a signed 32-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeInt32(int value) => _writeInt(value, 32);

  /// Writes an unsigned 8-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeUint8(int value) => _writeUint(value, 8);

  /// Writes an unsigned 16-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeUint16(int value) => _writeUint(value, 16);

  /// Writes an unsigned 32-bit integer [value] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeUint32(int value) => _writeUint(value, 32);

  /// Writes a [list] of unsigned 8-bit integer values to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeUint8List(List<int> list) {
    writeUint16(list.length);
    _buffer.copyBytesFromList(list, _position, _position + list.length, 0);
    _position += list.length;
  }

  /// Writes a [string] to the buffer.
  ///
  /// Throws an [UNabtoResponseTooLargeError] if there is not enough space left
  /// in the buffer.
  void writeString(String string) {
    var charCodes = UTF8.encode(string);
    writeUint8List(charCodes);
  }

  /// Constructs a new write buffer wrapper object with a [pointer] to the
  /// foreign `buffer_write_t` structure this should wrap.
  UNabtoWriteBuffer.fromAddress(int ptr) : super.fromAddress(ptr);
}

/// Helper class to convert an IPv4 address between integer, string and
/// [InternetAddress] representation.
class _InetAddress {
  /// IP address in 32-bit integer representation.
  int _address;

  /// IP address in 32-bit integer representation.
  int toInt() => _address;

  /// IP address in string representation (e.g. "127.0.0.1").
  String toString() => _toList().join(".");

  /// IP address as [InternetAddress] object.
  os.InternetAddress toInternetAddress() =>
      Foreign.platform == Foreign.FREERTOS
          ? new stm32.InternetAddress(_toList())
          : new os.InternetAddress(_toList());

  /// IP address as list of 4 bytes.
  List<int> _toList() => [
        (_address >> 24) & 0xff,
        (_address >> 16) & 0xff,
        (_address >> 8) & 0xff,
        _address & 0xff
      ];

  /// Construct helper class from IP address in 32-bit int representation.
  _InetAddress.fromInt(this._address);

  /// Construct helper class from IP address in [string] representation (e.g.
  /// "127.0.0.1").
  _InetAddress.fromString(String string) {
    var bytes = string.split(".");
    assert(bytes.length == 4);
    _address = int.parse(bytes[0]) << 24;
    _address |= int.parse(bytes[1]) << 16;
    _address |= int.parse(bytes[2]) << 8;
    _address |= int.parse(bytes[3]);
  }
}

/// Message tuple existing of [Datagram] and socket ID. Used in [UNabto] read
/// and write queues.
class _Message {
  int _socket;
  int get socket => _socket;

  Datagram _datagram;
  Datagram get datagram => _datagram;

  _Message(this._socket, this._datagram);
}

/// The uNabto server.
class UNabto {
  /// Single instance of this.
  static UNabto _instance = null;

  /// Fallback address if DHCP fails.
  static const _fallbackAddress =
      const stm32.InternetAddress(const <int>[192, 168, 0, 10]);

  /// Fallback netmask if DHCP fails.
  static const _fallbackNetmask =
      const stm32.InternetAddress(const <int>[255, 255, 255, 0]);

  /// Fallback gateway if DHCP fails.
  static const _fallbackGateway =
      const stm32.InternetAddress(const <int>[192, 168, 0, 1]);

  /// Fallback dns server if DHCP fails.
  static const _fallbackDnsServer =
      const stm32.InternetAddress(const <int>[8, 8, 8, 8]);

  /// Nabto ID of the server.
  final String _id;

  /// Preshared key for the secure connection.
  final String _presharedKey;

  /// Duration of 2 msec used for the tick timer.
  static const _twoMillis = const Duration(milliseconds: 2);

  /// The tick timer.
  Timer _tickTimer = null;

  /// List of registered event handling functions.
  Map _eventHandlers = new Map<int, dynamic>();

  /// Random generator.
  Random _random;

  /// Maps socket IDs to actual instances of [DatagramSocket].
  Map _sockets = new Map<int, DatagramSocket>();

  /// Queue of UDP messages to write to the network.
  Queue _writeQueue = new Queue<_Message>();

  /// Queue of UDP messages read from the network.
  Queue _readQueue = new Queue<_Message>();

  /// Creates a new uNabto server with given [id] and [presharedKey].
  UNabto(this._id, this._presharedKey) {
    // Allow only one instance of the uNabto server.
    if (_instance != null)
      throw new StateError("There can only be one instance of UNabto.");

    // If we are running on a dev board, we need to initialize the network.
    if (Foreign.platform == Foreign.FREERTOS)
      _initializeNetwork();

    // Random seed.
    _random = new Random(new DateTime.now().microsecondsSinceEpoch);

    // Register callback handlers.
    _unabtoRegisterEventHandler.icall$1(new ForeignDartFunction(_eventHandler));
    _unabtoRegisterRandomHandler
        .icall$1(new ForeignDartFunction(_randomHandler));
    _unabtoRegisterDnsIsResolvedHandler
        .icall$1(new ForeignDartFunction(_dnsIsResolvedHandler));
    _unabtoRegisterInitSocketHandler
        .icall$1(new ForeignDartFunction(_initSocketHandler));
    _unabtoRegisterCloseSocketHandler
        .icall$1(new ForeignDartFunction(_closeSocketHandler));
    _unabtoRegisterReadHandler.icall$1(new ForeignDartFunction(_readHandler));
    _unabtoRegisterWriteHandler.icall$1(new ForeignDartFunction(_writeHandler));
    _unabtoRegisterGetStampHandler
        .icall$1(new ForeignDartFunction(_getStampHandler));

    // Create a structure that contains the configuration options.
    var configOptions = new Struct.finalized(2);
    ForeignMemory id = new ForeignMemory.fromStringAsUTF8(_id);
    configOptions.setField(0, id.address);
    ForeignMemory presharedKey =
        new ForeignMemory.fromStringAsUTF8(_presharedKey);
    configOptions.setField(1, presharedKey.address);

    // `unabtoConfigure` takes a struct argument, and returns void.
    _unabtoConfigure.vcall$1(configOptions.address);

    // Free allocated foreign memory for the configuration structure.
    id.free();
    presharedKey.free();
    configOptions.free();

    // Save current instance in static `_instance` variable to prevent to throw
    // an error on attempts to create a second instance.
    _instance = this;
  }

  /// Initialize the network stack and wait until the network interface has
  /// either received an IP address using DHCP or given up and used the provided
  /// fallback [address], [netmask], [gateway] and [dnsServer].
  void _initializeNetwork(
      {stm32.InternetAddress address: _fallbackAddress,
      stm32.InternetAddress netmask: _fallbackNetmask,
      stm32.InternetAddress gateway: _fallbackGateway,
      stm32.InternetAddress dnsServer: _fallbackDnsServer}) {
    if (!stm32.ethernet
        .initializeNetworkStack(address, netmask, gateway, dnsServer)) {
      throw "Failed to initialize network stack";
    }
    while (stm32.NetworkInterface.list().first.addresses.isEmpty) {
      sleep(10);
    }
  }

  /// Returns the version of the uNabto server.
  String get version {
    return cStringToString(_unabtoVersion.pcall$0());
  }

  /// Initializes and starts the server.
  ///
  /// Returns `0` on success or `-1` if something went wrong.
  int init() {
    if (_id == null || _presharedKey == null) return -1;
    int result = _unabtoInit.icall$0();
    if (result == 0) {
      // Allow uNabto to process any new incoming telegrams every 2 msec.
      _tickTimer = new Timer.periodic(_twoMillis, (Timer t) => _customTick());
    }
    return result;
  }

  /// Reads incoming messages to a queue, call unabto's tick function and then
  /// writes queued outgoing messages to the network.
  void _customTick() {
    _readAll();
    _unabtoTick.vcall$0();
    _writeAll();
  }

  /// Handles an application event and dispatches it to the registered event
  /// handler with the appropriate query id.
  ///
  /// Furthermore it catches potentual errors in the handler caused for example
  /// by writing to much data to the response buffer and translates it to the
  /// appropriate return value for the callback function.
  _eventHandler(int appRequestPtr, int readBufferPtr, int writeBufferPtr) {
    try {
      var appRequest = new UNabtoRequest.fromAddress(appRequestPtr);
      var readBuffer = new UNabtoReadBuffer.fromAddress(readBufferPtr);
      var writeBuffer = new UNabtoWriteBuffer.fromAddress(writeBufferPtr);
      if (!_eventHandlers.containsKey(appRequest.queryId))
        return 7; // AER_REQ_INV_QUERY_ID
      _eventHandlers[appRequest.queryId](appRequest, readBuffer, writeBuffer);
      return 0; // AER_REQ_RESPONSE_READY
    } on UNabtoRequestTooSmallError catch (e) {
      print("The uNabto request is too small!");
      return 5; // AER_REQ_TOO_SMALL
    } on UNabtoResponseTooLargeError catch (e) {
      print("The uNabto response is larger than the space allocated!");
      return 8; // AER_REQ_RSP_TOO_LARGE
    } catch (e, stackTrace) {
      print("Error '$e' in callback handler!");
      return 10; // AER_REQ_SYSTEM_ERROR
    }
  }

  /// Registers a new event [handler] for the [queryId].
  void registerReceiver(
      int queryId,
      void handler(UNabtoRequest request, UNabtoReadBuffer readbuf,
          UNabtoWriteBuffer writeBuffer)) {
    _eventHandlers[queryId] = handler;
  }

  /// Handles `nabto_random` callback.
  void _randomHandler(int bufPtr, int len) {
    ForeignMemory buf = new ForeignMemory.fromAddress(bufPtr, len);
    // Fill buffer with random bytes.
    for (int i = 0; i < len; i++) buf.setUint8(i, _random.nextInt(255));
  }

  /// Handles `nabto_dns_is_resolved` callback.
  ///
  /// Looks up the given hostname and writes the resolved IPv4 address back.
  /// Returns `0` on success or `-1` if something went wrong.
  int _dnsIsResolvedHandler(int idStr, int v4addrPtr) {
    String id = cStringToString(new ForeignPointer(idStr));
    ForeignMemory v4addr = new ForeignMemory.fromAddress(v4addrPtr, 4);

    int address = _dnsLookup(id);
    if (address == -1) return -1;

    v4addr.setUint32(0, address);
    return 0;
  }

  /// Returns an unused socket id.
  int _getFreeSocketId() {
    int i = 0;
    while (_sockets.containsKey(i)) i++;
    return i;
  }

  /// Handles `nabto_init_socket` callback.
  ///
  /// Inits an new [DatagramSocket] and binds it to the given local port.
  /// Returns `0` on success or `-1` if something went wrong.
  int _initSocketHandler(int localAddr, int localPortPtr, int socketPtr) {
    ForeignMemory localPort = new ForeignMemory.fromAddress(localPortPtr, 2);
    ForeignMemory socket = new ForeignMemory.fromAddress(socketPtr, 2);
    DatagramSocket udpSocket;
    try {
      udpSocket = new DatagramSocket.bind(
          new _InetAddress.fromInt(localAddr).toString(), localPort.getUint16(0));
    } on SocketException catch (e) {
      print(e.toString());
      return -1;
    }
    localPort.setUint16(0, udpSocket.port);
    int socketId = _getFreeSocketId();
    socket.setInt16(0, socketId);
    _sockets[socketId] = udpSocket;
    return 0;
  }

  /// Handles `nabto_close_socket` callback.
  void _closeSocketHandler(int socketPtr) {
    int socket = new ForeignMemory.fromAddress(socketPtr, 2).getInt16(0);
    if (_sockets.containsKey(socket)) {
      _sockets[socket].close();
      _sockets.remove(socket);
    }
  }

  /// Handles `nabto_read` callback.
  ///
  /// Instead of reading directly we need to call [_readAll] before calling the
  /// uNabto tick function, and then read from the queue. This is due to dartino
  /// does not allow to call a foreign function (the receive function) from
  /// within a foreign callback.
  int _readHandler(int sockBufPtr, int addrPtr, int portPtr) {
    var sockBuf = new Struct.fromAddress(sockBufPtr, 3);
    int socket = sockBuf.getInt16(0);
    int bufPtr = sockBuf.getField(1);
    int len = sockBuf.getUint32(2 * sockBuf.wordSize);
    ForeignMemory buf = new ForeignMemory.fromAddress(bufPtr, len);
    ForeignMemory addr = new ForeignMemory.fromAddress(addrPtr, 4);
    ForeignMemory port = new ForeignMemory.fromAddress(portPtr, 2);

    if (_readQueue.length > 0 && _readQueue.first.socket == socket) {
      var datagram = _readQueue.removeFirst().datagram;
      var inetAddr = new _InetAddress.fromString(datagram.sender.toString());
      addr.setUint32(0, inetAddr.toInt());
      port.setUint16(0, datagram.port);
      var bytes = datagram.data.asUint8List();
      assert(bytes.length <=
          len); // TODO: split datagram and push it back to queue
      buf.copyBytesFromList(bytes, 0, bytes.length, 0);
      return bytes.length;
    }
    return 0;
  }

  /// Reads from all sockets and writes messages to queue.
  void _readAll() {
    _sockets.forEach((socket, v) => _read(socket));
  }

  /// Reads from socket with [socket] ID and writes message to queue.
  void _read(int socket) {
    if (!_sockets.containsKey(socket)) return;
    try {
      if (_sockets[socket].available <= 0) return;
    } on SocketException catch (e) {
      print(e.toString());
      return;
    }
    var datagram = _sockets[socket].receive();
    if (datagram != null) _readQueue.addLast(new _Message(socket, datagram));
  }

  /// Handles `nabto_write` callback.
  ///
  /// Instead of writing directly we need to call [_writeAll] after calling the
  /// uNabto tick function, and then read from the queue. This is due to dartino
  /// does not allow to call a foreign function (the send function) from within
  /// a foreign callback. Thus this function also always returns successful.
  int _writeHandler(int sockBufPtr, int addr, int port) {
    var sockBuf = new Struct.fromAddress(sockBufPtr, 3);
    int socket = sockBuf.getInt16(0);
    int bufPtr = sockBuf.getField(1);
    int len = sockBuf.getUint32(2 * sockBuf.wordSize);
    ForeignMemory buf = new ForeignMemory.fromAddress(bufPtr, len);

    Uint8List bytes = new Uint8List(len);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = buf.getUint8(i);
    }

    var inetAddr = new _InetAddress.fromInt(addr).toInternetAddress();

    var datagram = new Datagram(inetAddr, port, bytes.buffer);
    _writeQueue.addLast(new _Message(socket, datagram));

    return len; // TODO: is it an issue to assume this?
  }

  /// Writes message queue to the network.
  void _writeAll() {
    while (_writeQueue.length > 0) {
      var msg = _writeQueue.first;

      if (!_sockets.containsKey(msg.socket)) {
        _writeQueue.removeFirst();
        continue;
      }

      var udpSocket = _sockets[msg.socket];
      int sent = udpSocket.send(
          msg.datagram.sender, msg.datagram.port, msg.datagram.data);

      if (sent == msg.datagram.data.lengthInBytes) _writeQueue.removeFirst();
    }
  }

  /// Resolves [host]´s IPv4 address and returns it as integer in host byte
  /// order.
  /// Returns IPv4 address on success or `-1` if something went wrong.
  int _dnsLookup(String host) {
    if (Foreign.platform == Foreign.FREERTOS) {
      ForeignMemory string = new ForeignMemory.fromStringAsUTF8(host);
      int address = 0;
      try {
        address = _lookupHost.icall$1(string.address);
      } finally {
        string.free();
      }
      if (address == 0)
        return -1;
      else
        return _ntohl(address);
    } else {
      var address = os.getSystem().lookup(host);
      if (address == null || !address.isIP4)
        return -1;
      else
        return new _InetAddress.fromString(address.toString()).toInt();
    }
  }

  int _htonl(int value) =>
      (value & 0xFF000000) >> 24 |
      (value & 0x00FF0000) >> 8 |
      (value & 0x0000FF00) << 8 |
      (value & 0x000000FF) << 24;

  int _ntohl(int value) => _htonl(value);

  /// Closes the uNabto server, and frees all resources.
  void close() {
    if (_tickTimer != null) _tickTimer.cancel();
    _unabtoClose.vcall$0();
    _eventHandlers.clear();
  }

  /// Handles the `nabtoGetStamp` callback.
  ///
  /// Returns the milliseconds since the "Unix epoch" 1970-01-01T00:00:00Z (UTC)
  int _getStampHandler() {
    return new DateTime.now().millisecondsSinceEpoch;
  }
}
