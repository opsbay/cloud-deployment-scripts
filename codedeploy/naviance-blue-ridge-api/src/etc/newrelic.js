'use strict'
/**
 * New Relic agent configuration.
 *
 * See lib/config.defaults.js in the agent distribution for a more complete
 * description of configuration variables and their potential values.
 */
exports.config = {
  /**
   * Array of application names.
   */
  app_name: ['My Application'],
  /**
   * Your New Relic license key.
   */
  license_key: 'license key here',
  logging: {
    /**
     * Level at which to log. 'trace' is most useful to New Relic when diagnosing
     * issues with the agent, 'info' and higher will impose the least overhead on
     * production applications.
     */
    level: 'info'
  },
  /*
   * https://jira.hobsons.com/browse/NAWS-1168
   * Without setting this feature flag to false, we were getting memory leaks
   * in our node process, and stack traces on OOM that centered around the
   * file /opt/naviance-blue-ridge-api/node_modules/newrelic/lib/instrumentation/core/async_hooks.js
   *
   * Support for Node 8 async / await hooks landed in New Relic node.js agent 2.3.0 and is still
   * too raw as of 2.3.2 to include.
   */
  feature_flag: {
    await_support: false
  }
}
