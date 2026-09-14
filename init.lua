require 'options'
-- Before the plugin manager: language servers and formatters are enabled from
-- whatever the project's direnv environment provides.
require('direnv').setup()
require 'plugin_manager'
require 'keymaps'
