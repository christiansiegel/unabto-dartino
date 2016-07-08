// Library is not re-entrant
#ifndef UNABTOADAPTER_H_
#define UNABTOADAPTER_H_

#include <unabto/unabto_external_environment.h>

typedef void (*unabtoRandomHandler)(uint8_t* buf, size_t len);
int unabtoRegisterRandomHandler(unabtoRandomHandler handler);

#endif  // UNABTOADAPTER_H_
