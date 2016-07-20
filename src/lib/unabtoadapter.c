#include "unabtoadapter.h"

/********** Platform Random ***************************************************/

unabtoRandomHandler currentRandomHandler = NULL;
int unabtoRegisterRandomHandler(unabtoRandomHandler handler) {
  if (handler == NULL) return -1;
  currentRandomHandler = handler;
  return 0;
}

void nabto_random(uint8_t* buf, size_t len) {
  if (currentRandomHandler != NULL) currentRandomHandler(buf, len);
}

/*********** UDP init/close ***************************************************/

unabtoInitSocketHandler currentInitSocketHandler = NULL;
int unabtoRegisterInitSocketHandler(unabtoInitSocketHandler handler) {
  if (handler == NULL) return -1;
  currentInitSocketHandler = handler;
  return 0;
}

bool nabto_init_socket(uint32_t localAddr, uint16_t* localPort,
                       nabto_socket_t* socket) {
  if (currentInitSocketHandler == NULL) return false;
  return currentInitSocketHandler(localAddr, localPort, socket) == 0;
}

unabtoCloseSocketHandler currentCloseSocketHandler = NULL;
int unabtoRegisterCloseSocketHandler(unabtoCloseSocketHandler handler) {
  if (handler == NULL) return -1;
  currentCloseSocketHandler = handler;
  return 0;
}

void nabto_close_socket(nabto_socket_t* socket) {
  if (currentCloseSocketHandler != NULL) currentCloseSocketHandler(socket);
}

unabtoReadHandler currentReadHandler = NULL;
int unabtoRegisterReadHandler(unabtoReadHandler handler) {
  if (handler == NULL) return -1;
  currentReadHandler = handler;
  return 0;
}

ssize_t nabto_read(nabto_socket_t socket, uint8_t* buf, size_t len,
                   uint32_t* addr, uint16_t* port) {
  if (currentReadHandler == NULL) return 0;
  struct socketAndBuffer sockBuf;
  sockBuf.socket = socket;
  sockBuf.buf = buf;
  sockBuf.len = len;
  return currentReadHandler(&sockBuf, addr, port);
}

unabtoWriteHandler currentWriteHandler = NULL;
int unabtoRegisterWriteHandler(unabtoWriteHandler handler) {
  if (handler == NULL) return -1;
  currentWriteHandler = handler;
  return 0;
}

ssize_t nabto_write(nabto_socket_t socket, const uint8_t* buf, size_t len,
                    uint32_t addr, uint16_t port) {
  if (currentWriteHandler == NULL) return 0;
  struct socketAndBuffer sockBuf;
  sockBuf.socket = socket;
  sockBuf.buf = (uint8_t*)buf;
  sockBuf.len = len;
  return currentWriteHandler(&sockBuf, addr, port);
}

/*************** DNS related functions ***************************************/

unabtoDnsIsResolvedHandler currentDnsIsResolvedHandler = NULL;
int unabtoRegisterDnsIsResolvedHandler(unabtoDnsIsResolvedHandler handler) {
  if (handler == NULL) return -1;
  currentDnsIsResolvedHandler = handler;
  return 0;
}

void nabto_dns_resolve(const char* id) {}

nabto_dns_status_t nabto_dns_is_resolved(const char* id, uint32_t* v4addr) {
  int status = -1;
  if (currentDnsIsResolvedHandler != NULL)
    status = currentDnsIsResolvedHandler(id, v4addr);
  return status == 0 ? NABTO_DNS_OK : NABTO_DNS_ERROR;
}

/*************** Time stamp related functions ********************************/

unabtoGetStampHandler currentGetStampHandler = NULL;
int unabtoRegisterGetStampHandler(unabtoGetStampHandler handler) {
  if (handler == NULL) return -1;
  currentGetStampHandler = handler;
  return 0;
}
nabto_stamp_t nabtoGetStamp() {
  if (currentGetStampHandler != NULL) return currentGetStampHandler();
  return 0;
}

#define MAX_STAMP_DIFF 0x7fffffff;
bool nabtoIsStampPassed(nabto_stamp_t* stamp) {
  return *stamp - nabtoGetStamp() > (uint32_t)MAX_STAMP_DIFF;
}

nabto_stamp_diff_t nabtoStampDiff(nabto_stamp_t* newest,
                                  nabto_stamp_t* oldest) {
  return (*newest - *oldest);
}

int nabtoStampDiff2ms(nabto_stamp_diff_t diff) { return (int)diff; }
