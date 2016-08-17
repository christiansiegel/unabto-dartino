#include "unabtolib.h"
#include "unabtoadapter.h"

#include "include/static_ffi.h"

DARTINO_EXPORT_STATIC(unabtoVersion);
DARTINO_EXPORT_STATIC(unabtoConfigure);
DARTINO_EXPORT_STATIC(unabtoInit);
DARTINO_EXPORT_STATIC(unabtoClose);
DARTINO_EXPORT_STATIC(unabtoTick);
DARTINO_EXPORT_STATIC(unabtoRegisterEventHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterRandomHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterDnsIsResolvedHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterInitSocketHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterCloseSocketHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterReadHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterWriteHandler);
DARTINO_EXPORT_STATIC(unabtoRegisterGetStampHandler);
