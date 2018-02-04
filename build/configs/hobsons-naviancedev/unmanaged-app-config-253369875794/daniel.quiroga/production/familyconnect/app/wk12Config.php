<?php
/**
 * Naviance, Inc
 *
 * LICENSE
 * This source file is the property Naviance, Inc and may not be redistributed
 * in part or its entirty without the expressed written consent of
 * Naviance, Inc.
 *
 * @category    Naviance
 * @package     WK12
 * @subpackage  Config
 * @copyright   Copyright (c) 2009 Naviance, Inc (www.naviance.com)
 * @license
 * @version     $Id: $
 */
require_once 'dbConfig.php';
/* ENV VALUES*/
DEFINE("BASE_INCLUDES_PATH", "/httpd/k12/wk12/includes"); //Full Path to WK12 includes directory (No Trailing Slash)
DEFINE("FC_SERVER_NAME", $_SERVER['SERVER_NAME']); //Family Connection domain name
DEFINE("CLIENT_PATH", "/clients/");
DEFINE("NAV_ENV", "qa"); //dev, qa,  staging, or production
DEFINE("MC_SERVERS", "%%MEMCACHE_DATA%%"); //Comma separated list

/* Emails */
define('EMAIL_BILLING', 'billing@dev.naviance.com');
define('EMAIL_RENEWALS', 'renewals@dev.naviance.com');
define('EMAIL_PREPME_MANAGER', 'prepme-manager@dev.naviance.com');
define('EMAIL_SALES', 'sales@dev.naviance.com');
