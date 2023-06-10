//config files
// we use compile time work here to ensure we check everything at load, rather then now at read
// doesn't work :(
#define CONFIG_GET(X) (global.config.entries_by_type[/datum/config_entry/##X]:config_entry_value; {/datum/config_entry/##X{read_by_code = TRUE}})
#define CONFIG_SET(X, Y) \
	global.config.entries_by_type[/datum/config_entry/##X]:ValidateAndSet(##Y); \
	/datum/config_entry/##X{modified_by_code = TRUE};

#define CONFIG_GET(X) (...; {/datum/config_entry/##X{read_by_code = TRUE}})

#define CONFIG_MAPS_FILE "maps.txt"

//flags
/// can't edit
#define CONFIG_ENTRY_LOCKED (1<<0)
/// can't see value
#define CONFIG_ENTRY_HIDDEN (1<<1)

/// Force the config directory to be something other than "config"
#define OVERRIDE_CONFIG_DIRECTORY_PARAMETER "config-directory"

// Config entry types
#define VALUE_MODE_NUM 0
#define VALUE_MODE_TEXT 1
#define VALUE_MODE_FLAG 2

#define KEY_MODE_TEXT 0
#define KEY_MODE_TYPE 1
