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
 * @package     crm
 * @subpackage  Config
 * @copyright   Copyright (c) 2009 Naviance, Inc (www.naviance.com)
 * @license
 * @version     $Id: $
 */

require_once 'dbConfig.php';
require_once 'mapquestConfig.php';

// color settings
DEFINE("MAIN_COLOR", "#F2D68F");

DEFINE("BASE_INCLUDES_PATH","/httpd/k12/wk12/includes/");  //Full Path to WK12 includes directory
DEFINE("CRM_SERVER_NAME","insite.naviance.com"); //Server full domain name
DEFINE("MC_SERVERS", "10.32.205.10,10.32.205.11,10.32.205.12"); //Comma separated list
DEFINE("NAV_ENV", "production");
