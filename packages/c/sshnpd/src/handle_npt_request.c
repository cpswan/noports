#include "sshnpd/params.h"
#include "sshnpd/permitopen.h"
#include "sshnpd/sshnpd.h"
#include <atchops/aes.h>
#include <atchops/base64.h>
#include <atchops/iv.h>
#include <atchops/rsa_key.h>
#include <atclient/cjson.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <sshnpd/handle_ssh_request.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/run_srv_process.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "NPT_REQUEST"

void handle_npt_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_response *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsa_key_private_key signing_key) {
  int res = 0;

  cJSON *envelope = extract_envelope_from_notification(message);
  if (envelope == NULL) {
    return;
  }
  // allocated: envelope

  // log envelope
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received envelope: %s\n", cJSON_Print(envelope));

  char *requesting_atsign = message->notification.from;
  res = verify_envelope_signature_from(envelope, requesting_atsign, atclient);
  if (res != 0) {
    cJSON_Delete(envelope);
    return;
  }

  res = verify_envelope_contents(envelope, payload_type_npt);

  if (res != 0) {
    cJSON_Delete(envelope);
    return;
  }

  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");
  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");
  // cJSON *rvd_host = cJSON_GetObjectItem(payload, "rvdHost");
  // cJSON *rvd_port = cJSON_GetObjectItem(payload, "rvdPort");
  // cJSON *requested_host = cJSON_GetObjectItem(payload, "requestedHost");
  // cJSON *requested_port = cJSON_GetObjectItem(payload, "requestedPort");
  // cJSON *client_ephemeral_pk = cJSON_GetObjectItem(payload, "clientEphemeralPK");
  // cJSON *client_ephemeral_pk_type = cJSON_GetObjectItem(payload, "clientEphemeralPKType");

  cJSON *requested_host = cJSON_GetObjectItem(payload, "requestedHost");
  cJSON *requested_port = cJSON_GetObjectItem(payload, "requestedPort");

  // Don't try optimizing this to reuse the permitopen struct from main.c.
  // none of the memory duplication here is expensive, and it's a surface for bugs
  permitopen_params permitopen;
  permitopen.permitopen_len = params->permitopen_len;
  permitopen.permitopen_hosts = params->permitopen_hosts;
  permitopen.permitopen_ports = params->permitopen_ports;
  permitopen.requested_host = cJSON_GetStringValue(requested_host);
  permitopen.requested_port = cJSON_GetNumberValue(requested_port);

  if (!should_permitopen(&permitopen)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Ignoring request to localhost:%d\n",
                 permitopen.requested_port);
    cJSON_Delete(envelope);
    return;
  }

  // These values do not need to be asserted for v4 compatibility, only for v5
  // NPT ONLY
  // ignore timeout param for now
  // END NPT ONLY

  // temporary buffer used for multiple things:
  // - holding publickey string to populate publickey
  // - holding the signature to verify envelope
  char *buffer = NULL;

  bool authenticate_to_rvd = cJSON_IsTrue(cJSON_GetObjectItem(payload, "authenticateToRvd"));
  bool encrypt_rvd_traffic = cJSON_IsTrue(cJSON_GetObjectItem(payload, "encryptRvdTraffic"));

  char *rvd_auth_string;
  if (authenticate_to_rvd) {
    res = create_rvd_auth_string(envelope, &signing_key, &rvd_auth_string);
    if (res != 0) {
      cJSON_Delete(envelope);
      return;
    }
    // allocated: rvd_auth_string
  }

  // TODO pick up from here moving things into handler_commons
  // TODO pass these into the common handler
  bool free_session_base64 = false;
  unsigned char *session_aes_key, *session_iv; // TODO pass these into the common handler
  unsigned char *session_aes_key_base64, *session_iv_base64;
  if (encrypt_rvd_traffic) {
    // TODO call the common handler
  } else {
    sprintf((char *)session_aes_key, "no");
    sprintf((char *)session_iv, "encrypt");
  }

  // At this point, allocated memory:
  // - envelope (always)
  // - rvd_auth_string (if authenticate_to_rvd == true)
  // - session_aes_key_base64 (if free_session_base64 == true)
  // - session_iv_base64 (if free_session_base64 == true)

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Running fork()...\n");

  pid_t pid = fork();
  int status;
  bool free_envelope = true;

  if (pid == 0) {
    // child process

    // free this immediately, we don't need it on the child fork
    if (free_session_base64) {
      free(session_aes_key_base64);
      free(session_iv_base64);
    }
    char *rvd_host_str = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "rvdHost"));
    uint16_t rvd_port_int = cJSON_GetNumberValue(cJSON_GetObjectItem(payload, "rvdPort"));

    char *requested_host_str = cJSON_GetStringValue(requested_host);
    uint16_t requested_port_int = cJSON_GetNumberValue(requested_port);

    const bool multi = true;

    int res = run_srv_process(rvd_host_str, rvd_port_int, requested_host_str, requested_port_int, authenticate_to_rvd,
                              rvd_auth_string, encrypt_rvd_traffic, multi, session_aes_key, session_iv);
    *is_child_process = true;

    if (authenticate_to_rvd) {
      cJSON_free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    exit(res);
    // end of child process
  } else if (pid > 0) {
    // parent process

    // since we use WNOHANG,
    // waitpid will return -1, if an error occurred
    // waitpid will return 0, if the child process has not exited
    // waitpid will return the pid of the child process if it has exited
    int waitpid_return = waitpid(pid, &status, WNOHANG); // Don't wait for srv - we want it to be running in the bg
    if (waitpid_return > 0) {
      // child process has already exited
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process has already exited\n");
      if (WIFEXITED(status)) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited with status %d\n", status);
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited abnormally\n");
      }
      goto cancel;
    } else if (waitpid_return == -1) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to wait for srv process: %s\n", strerror(errno));
      goto cancel;
    }

    // TODO consolidate this into a common handler
    char *identifier = cJSON_GetStringValue(session_id);
    cJSON *final_res_payload = cJSON_CreateObject();
    cJSON_AddStringToObject(final_res_payload, "status", "connected");
    cJSON_AddItemReferenceToObject(final_res_payload, "sessionId", session_id);
    cJSON_AddStringToObject(final_res_payload, "sessionAESKey", (char *)session_aes_key_base64);
    cJSON_AddStringToObject(final_res_payload, "sessionIV", (char *)session_iv_base64);

    cJSON *final_res_envelope = cJSON_CreateObject();
    cJSON_AddItemToObject(final_res_envelope, "payload", final_res_payload);

    unsigned char *signing_input2 = (unsigned char *)cJSON_PrintUnformatted(final_res_payload);

    unsigned char signature[256];
    memset(signature, 0, 256);
    res = atchops_rsa_sign(&signing_key, ATCHOPS_MD_SHA256, signing_input2, strlen((char *)signing_input2), signature);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to sign the final res payload\n");
      goto clean_json;
    }

    unsigned char base64signature[384];
    memset(base64signature, 0, sizeof(unsigned char) * 384);

    size_t sig_len;
    res = atchops_base64_encode(signature, 256, base64signature, 384, &sig_len);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to base64 encode the final res payload's signature\n");
      goto clean_json;
    }

    cJSON_AddItemToObject(final_res_envelope, "signature", cJSON_CreateString((char *)base64signature));
    cJSON_AddItemToObject(final_res_envelope, "hashingAlgo", cJSON_CreateString("sha256"));
    cJSON_AddItemToObject(final_res_envelope, "signingAlgo", cJSON_CreateString("rsa2048"));
    char *final_res_value = cJSON_PrintUnformatted(final_res_envelope);

    atclient_atkey final_res_atkey;
    atclient_atkey_init(&final_res_atkey);

    size_t keynamelen = strlen(identifier) + strlen(params->device) + 2; // + 1 for '.' +1 for '\0'
    char *keyname = malloc(sizeof(char) * keynamelen);
    if (keyname == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for keyname");
      goto clean_final_res_value;
    }

    snprintf(keyname, keynamelen, "%s.%s", identifier, params->device);
    atclient_atkey_create_shared_key(&final_res_atkey, keyname, params->atsign, requesting_atsign, SSHNP_NS);

    // print final_res_atkey
    char *final_res_atkey_str = NULL;
    atclient_atkey_to_string(&final_res_atkey, &final_res_atkey_str);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Final response atkey: %s\n", final_res_atkey_str);
    free(final_res_atkey_str);

    atclient_atkey_metadata *metadata = &final_res_atkey.metadata;
    atclient_atkey_metadata_set_is_public(metadata, false);
    atclient_atkey_metadata_set_is_encrypted(metadata, true);
    atclient_atkey_metadata_set_ttl(metadata, 10000);

    atclient_notify_params notify_params;
    atclient_notify_params_init(&notify_params);
    if ((res = atclient_notify_params_set_atkey(&notify_params, &final_res_atkey)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set atkey in notify params\n");
      goto clean_res;
    }
    if ((res = atclient_notify_params_set_value(&notify_params, final_res_value)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set value in notify params\n");
      goto clean_res;
    }
    if ((res = atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set operation in notify params\n");
      goto clean_res;
    }

    char *final_keystr = NULL;
    atclient_atkey_to_string(&final_res_atkey, &final_keystr);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Final response atkey: %s\n", final_res_atkey_str);
    free(final_keystr);

    int ret = pthread_mutex_lock(atclient_lock);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to get a lock on atclient for sending a notification\n");
      goto clean_res;
    }

    ret = atclient_notify(atclient, &notify_params, NULL);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to send final response to %s\n",
                   message->notification.from);
    }
    ret = pthread_mutex_unlock(atclient_lock);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
    } else {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
    }

  clean_res: { free(keyname); }
  clean_final_res_value: {
    atclient_atkey_free(&final_res_atkey);
    cJSON_free(final_res_value);
  }
  clean_json: {
    cJSON_Delete(final_res_envelope);
    cJSON_free(signing_input2);
  }

    // end of parent process
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fork the srv process: %s\n", strerror(errno));
  }
cancel:
  if (authenticate_to_rvd) {
    cJSON_free(rvd_auth_string);
  }
  if (free_session_base64) {
    free(session_iv_base64);
    free(session_aes_key_base64);
  }
  cJSON_Delete(envelope);
  return;
}
