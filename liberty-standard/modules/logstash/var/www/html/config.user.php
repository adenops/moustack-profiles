<?php
/*! pimpmylog - 1.7.10 - 65d6f147e509133fc5f09642ba82b149ef750ef2*/
/*
 * pimpmylog
 * http://pimpmylog.com
 *
 * Copyright (c) 2015 Potsky, contributors
 * Licensed under the GPLv3 license.
 */
?>
<?php if(realpath(__FILE__)===realpath($_SERVER["SCRIPT_FILENAME"])){header($_SERVER['SERVER_PROTOCOL'].' 404 Not Found');die();}?>
{
	"globals": {
		"_remove_me_to_set_AUTH_LOG_FILE_COUNT"         : 100,
		"_remove_me_to_set_AUTO_UPGRADE"                : false,
		"_remove_me_to_set_CHECK_UPGRADE"               : true,
		"_remove_me_to_set_EXPORT"                      : true,
		"_remove_me_to_set_FILE_SELECTOR"               : "bs",
		"_remove_me_to_set_FOOTER"                      : "&copy; <a href=\"http:\/\/www.potsky.com\" target=\"doc\">Potsky<\/a> 2007-' . YEAR . ' - <a href=\"http:\/\/pimpmylog.com\" target=\"doc\">Pimp my Log<\/a>",
		"_remove_me_to_set_FORGOTTEN_YOUR_PASSWORD_URL" : "http:\/\/support.pimpmylog.com\/kb\/misc\/forgotten-your-password",
		"_remove_me_to_set_GEOIP_URL"                   : "http:\/\/www.geoiptool.com\/en\/?IP=%p",
		"_remove_me_to_set_GOOGLE_ANALYTICS"            : "UA-XXXXX-X",
		"_remove_me_to_set_HELP_URL"                    : "http:\/\/pimpmylog.com",
		"LOCALE"                      : "en_US",
		"_remove_me_to_set_LOGS_MAX"                    : 50,
		"_remove_me_to_set_LOGS_REFRESH"                : 0,
		"_remove_me_to_set_MAX_SEARCH_LOG_TIME"         : 5,
		"_remove_me_to_set_NAV_TITLE"                   : "",
		"_remove_me_to_set_NOTIFICATION"                : true,
		"_remove_me_to_set_NOTIFICATION_TITLE"          : "New logs [%f]",
		"_remove_me_to_set_PIMPMYLOG_ISSUE_LINK"        : "https:\/\/github.com\/potsky\/PimpMyLog\/issues\/",
		"_remove_me_to_set_PIMPMYLOG_VERSION_URL"       : "http:\/\/demo.pimpmylog.com\/version.js",
		"_remove_me_to_set_PULL_TO_REFRESH"             : true,
		"_remove_me_to_set_SORT_LOG_FILES"              : "default",
		"_remove_me_to_set_TAG_DISPLAY_LOG_FILES_COUNT" : true,
		"_remove_me_to_set_TAG_NOT_TAGGED_FILES_ON_TOP" : true,
		"_remove_me_to_set_TAG_SORT_TAG"                : "default | display-asc | display-insensitive | display-desc | display-insensitive-desc",
		"TITLE"                       : "OpenStack Logs",
		"TITLE_FILE"                  : "OpenStack Logs [%f]",
		"_remove_me_to_set_UPGRADE_MANUALLY_URL"        : "http:\/\/pimpmylog.com\/getting-started\/#update",
		"_remove_me_to_set_USER_CONFIGURATION_DIR"      : "config.user.d",
		"USER_TIME_ZONE"              : "America\/Toronto"
	},

	"badges": {
		"severity": {
			"DEBUG"       : "success",
			"INFO"        : "info",
			"NOTICE"      : "info",
			"WARNING"     : "warning",
			"ERROR"       : "danger",
			"CRIT"        : "danger",
			"ALERT"       : "danger",
			"EMERG"       : "danger"
		}
	},

	"files": {
		"syslog1": {
			"display" : "Docker",
			"path"    : "/openstack/logs/*/*.log",
			"count"   : 100,
			"refresh" : 20,
			"max"     : 50,
			"notify"  : false,
			"format"  : {
				"regex": "|^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2}):([0-9]{2})([^ ]*) ([^ ]*) ([^/]*)/([^:]*): (.*)$|",
				"match": {
					"Date"    : {
						"Y" : 1,
						"m" : 2,
						"d" : 3,
						"H" : 4,
						"i" : 5,
						"s" : 6,
						"z" : 7
					},
					"Severity":8,
					"Host":9,
					"Container":10,
					"Message":11
				},
				"types": {
					"Severity" : "badge:severity",
					"Date"    : "date:Y-m-d H:i:s"
				}
			}
		}
	}
}
