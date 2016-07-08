#include "unabtoadapter.h"

unabtoRandomHandler currentRandomHandler = NULL;
int unabtoRegisterRandomHandler(unabtoRandomHandler handler) {
  if (handler == NULL) return -1;
  currentRandomHandler = handler;
  return 0;
}

void nabto_random(uint8_t* buf, size_t len) {
  if (currentRandomHandler != NULL) currentRandomHandler(buf, len);
}
