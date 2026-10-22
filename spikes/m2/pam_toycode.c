/* A spike-only PAM module: after the password, ask "Code:" and accept 123456.
 * Shows a PAM_TEXT_INFO first, as pam_mauvely would. Never ship this. */
#define PAM_SM_AUTH
#include <security/pam_modules.h>
#include <security/pam_ext.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)flags;
    char *code = NULL;
    /* "password": stand in for the password, accepting any non-empty answer, so
     * the spike never types a real one. */
    if (argc > 0 && strcmp(argv[0], "password") == 0) {
        int pr = pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &code, "Password: ");
        int got = pr == PAM_SUCCESS && code != NULL && code[0] != '\0';
        pam_syslog(pamh, LOG_NOTICE, "toycode: stand-in password %s", got ? "given" : "missing");
        free(code);
        return got ? PAM_SUCCESS : PAM_AUTH_ERR;
    }
    pam_info(pamh, "Enter the code from your authenticator app.");
    int r = pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &code, "Code:");
    if (r != PAM_SUCCESS || code == NULL) {
        pam_syslog(pamh, LOG_NOTICE, "toycode: no answer (%d)", r);
        return PAM_AUTH_ERR;
    }
    int ok = strcmp(code, "123456") == 0;
    pam_syslog(pamh, LOG_NOTICE, "toycode: %s (len %zu)", ok ? "accepted" : "refused", strlen(code));
    free(code);
    if (!ok) {
        pam_error(pamh, "That code is not right.");
        return PAM_AUTH_ERR;
    }
    return PAM_SUCCESS;
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    (void)pamh; (void)flags; (void)argc; (void)argv;
    return PAM_SUCCESS;
}
