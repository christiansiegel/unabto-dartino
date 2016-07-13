#include "unabtolib.h"

#include "unabto/unabto_common_main.h"
#include "unabto_version.h"

// The uNabto main config structure.
nabto_main_setup* nms;

char* unabtoVersion() {
  static char version[21];
  sprintf(version, "%u.%u", RELEASE_MAJOR, RELEASE_MINOR);
  return version;
}

void unabtoConfigure(UnabtoConfig* config) {
  setbuf(stdout, NULL);

  // Set uNabto to default values.
  nms = unabto_init_context();

  // Set the uNabto ID.
  nms->id = strdup(config->id);

  // Enable encryption.
  nms->secureAttach = true;
  nms->secureData = true;
  nms->cryptoSuite = CRYPT_W_AES_CBC_HMAC_SHA256;

  // Set the pre-shared key from a hexadecimal string.
  size_t i, pskLen = strlen(config->presharedKey);
  for (i = 0; i < pskLen / 2 && i < PRE_SHARED_KEY_SIZE; i++)
    sscanf(&config->presharedKey[2 * i], "%02hhx", &nms->presharedKey[i]);
}

int unabtoInit() { return (nms != NULL && unabto_init()) ? 0 : -1; }

void unabtoClose() { unabto_close(); }

void unabtoTick() { unabto_tick(); }

unabtoEventHandler currentEventHandler = NULL;
int unabtoRegisterEventHandler(unabtoEventHandler handler) {
  if (handler == NULL) return -1;
  currentEventHandler = handler;
  return 0;
}

application_event_result application_event(application_request* request,
                                           buffer_read_t* read_buffer,
                                           buffer_write_t* write_buffer) {
  if (currentEventHandler == NULL) return AER_REQ_INV_QUERY_ID;
  return currentEventHandler(request, read_buffer, write_buffer);
}
