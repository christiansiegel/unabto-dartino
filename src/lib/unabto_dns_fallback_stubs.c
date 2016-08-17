#include <unabto/unabto_dns_fallback.h>

bool unabto_dns_fallback_init() { return false; }

bool unabto_dns_fallback_close() { return false; }

void unabto_dns_fallback_handle_packet(uint8_t* buffer, size_t bufferLength) {}

void unabto_dns_fallback_handle_timeout() {}

void unabto_dns_fallback_next_event(nabto_stamp_t* current_min_stamp) {}

size_t unabto_dns_fallback_recv_socket(uint8_t* buffer, size_t bufferLength) {
  return 0;
}

unabto_dns_fallback_error_code unabto_dns_fallback_create_socket() {
  return UDF_SOCKET_CREATE_FAILED;
}

bool unabto_dns_fallback_close_socket() { return false; }

size_t unabto_dns_fallback_send_to(uint8_t* buf, size_t bufSize, uint32_t addr,
                                   uint16_t port) {
  return 0;
}

size_t unabto_dns_fallback_recv_from(uint8_t* buf, size_t bufferSize,
                                     uint32_t* addr, uint16_t* port) {
  return 0;
}
