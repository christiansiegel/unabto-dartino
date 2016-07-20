// Library is not re-entrant
#ifndef UNABTOADAPTER_H_
#define UNABTOADAPTER_H_

#include <unabto/unabto_external_environment.h>

struct socketAndBuffer {
  nabto_socket_t socket;
  uint8_t* buf;
  uint32_t len;
};

typedef void (*unabtoRandomHandler)(uint8_t* buf, size_t len);
int unabtoRegisterRandomHandler(unabtoRandomHandler handler);

typedef int (*unabtoDnsIsResolvedHandler)(const char* id, uint32_t* v4addr);
int unabtoRegisterDnsIsResolvedHandler(unabtoDnsIsResolvedHandler handler);

typedef int (*unabtoInitSocketHandler)(uint32_t localAddr, uint16_t* localPort,
                                       nabto_socket_t* socket);
int unabtoRegisterInitSocketHandler(unabtoInitSocketHandler handler);

typedef void (*unabtoCloseSocketHandler)(nabto_socket_t* socket);
int unabtoRegisterCloseSocketHandler(unabtoCloseSocketHandler handler);

typedef ssize_t (*unabtoReadHandler)(struct socketAndBuffer* sockBuf,
                                     uint32_t* addr, uint16_t* port);
int unabtoRegisterReadHandler(unabtoReadHandler handler);

typedef ssize_t (*unabtoWriteHandler)(struct socketAndBuffer* sockBuf,
                                      uint32_t addr, uint16_t port);
int unabtoRegisterWriteHandler(unabtoWriteHandler handler);

#endif  // UNABTOADAPTER_H_
