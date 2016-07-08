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
